import .ArgParse:
    ParseArgsError,
    ParsedArgs,
    parse_args,
    parse_raw,
    PARSER,
    StdoutMode,
    InplaceMode,
    CheckMode,
    print_help

# For thread-safe printing
const print_lock = ReentrantLock()

const SUCCESS_EXIT_CODE = 0
# If files were not correctly formatted.
const UNFORMATTED_EXIT_CODE = 1
# If an error occurred during formatting (e.g. parse error, invalid input, etc.)
const ERROR_EXIT_CODE = 2

supports_color(io) = get(io, :color, false)

macro tryx(ex, fallback)
    return :(
        try
            $(esc(ex))
        catch
            $(esc(fallback))
        end
    )
end

# Scan directory for Julia files recursively
function scandir!(files, root)
    # Don't recurse into `.git`
    if occursin(".git", root) && ".git" in splitpath(root)
        @assert endswith(root, ".git")
        return
    end
    @tryx(isdir(root), false) || return
    dirs = Vector{String}()
    for f in @tryx(readdir(root), String[])
        jf = joinpath(root, f)
        if @tryx(isdir(jf), false)
            push!(dirs, f)
        elseif (@tryx(isfile(jf), false) || @tryx(islink(jf), false))
            # Check for .jl, .md, .jmd, .qmd files
            if endswith(jf, ".jl") ||
               endswith(jf, ".md") ||
               endswith(jf, ".jmd") ||
               endswith(jf, ".qmd")
                push!(files, jf)
            end
        end
    end
    for dir in dirs
        scandir!(files, joinpath(root, dir))
    end
    return
end

function panic(
    msg::String,
    err::Union{Exception,Nothing} = nothing,
    bt::Union{Vector{Base.StackFrame},Nothing} = nothing,
)
    printstyled(stderr, "ERROR: "; color = :red, bold = true)
    print(stderr, msg)
    if err !== nothing
        print(stderr, sprint(showerror, err))
    end
    if bt !== nothing
        Base.show_backtrace(stderr, bt)
    end
    println(stderr)
    return ERROR_EXIT_CODE
end

function okln(io::IO, msg::String = "✓")
    printstyled(io, msg; color = :green, bold = true)
    println(io)
    return
end

function errln(io::IO, msg::String = "✗")
    printstyled(io, msg; color = :red, bold = true)
    println(io)
    return
end

function print_version()
    print(stdout, "jlfmt (JuliaFormatter) version ")
    print(stdout, string(pkgversion(JuliaFormatter)))
    print(stdout, ", julia version ")
    print(stdout, VERSION)
    println(stdout)
    return
end

# Type-stable output struct
struct Output{IO}
    which::Symbol
    file::String
    stream::IO
    output_is_file::Bool
    output_is_samefile::Bool
end

function writeo(output::Output, content::String)
    @assert output.which !== :devnull
    if output.which === :file
        write(output.file, content)
    elseif output.which == :stdout
        write(output.stream, content)
    end
    return
end

function main(argv::Vector{String})
    args = try
        parse_args(argv)
    catch err
        err isa ParseArgsError || rethrow()
        return panic(err.message)
    end

    if args.help
        print_help(PARSER)
        return Cint(0)
    end
    if args.version
        print_version()
        return Cint(0)
    end

    inplace = args.mode == InplaceMode
    check = args.mode == CheckMode
    outputfile = something(args.outputfile, "")

    errno::Cint = 0

    inputfiles = String[]
    input_is_stdin = true
    # There might be multiple inputs if either more than one path is given, or if a single
    # directory is given. This catches the first case
    multiple_inputs = length(args.paths) > 1

    for x in args.paths
        if x == "-"
            if length(args.paths) > 1
                return panic("input `-` cannot be combined with other input")
            end
        else
            input_is_stdin = false
            if isdir(x)
                # This catches the second case (single-directory)
                scandir!(inputfiles, x)
                multiple_inputs = true
            else
                push!(inputfiles, x)
            end
        end
    end

    # Validate the arguments
    if inplace && input_is_stdin
        return panic("option `--inplace` cannot be used together with stdin input")
    end
    if outputfile != "" && multiple_inputs
        return panic("option `--output` cannot be used together with multiple input files")
    end
    if multiple_inputs && !(inplace || check)
        return panic(
            "multiple input files require either `--inplace` to write changes or `--check` to verify formatting",
        )
    end
    if !isempty(args.line_ranges) && multiple_inputs
        return panic(
            "option `--lines` cannot be used together with multiple input files or directories",
        )
    end
    if args.diff
        if Sys.which("git") === nothing
            return panic("option `--diff` requires `git` to be installed")
        end
    end

    # Disable verbose if piping from/to stdin/stdout
    output_is_stdout = !inplace && !check && (outputfile in ("", "-"))
    print_progress = args.verbose && !(input_is_stdin || output_is_stdout)

    fileargs_to_process = if input_is_stdin
        # Sentinel value representing stdin.
        [
            ProcessFileArgs(
                "",
                1,
                "1",
                print_progress,
                check,
                inplace,
                outputfile,
                true,
                args.stdin_filename,
                args.config_dir,
                args.ignore_config,
                args.config,
                args.line_ranges,
                args.diff,
                args.config_priority,
            ),
        ]
    else
        nfiles_str = string(length(inputfiles))
        [
            ProcessFileArgs(
                inputfile,
                file_counter,
                nfiles_str,
                print_progress,
                check,
                inplace,
                outputfile,
                false,
                args.stdin_filename,
                args.config_dir,
                args.ignore_config,
                args.config,
                args.line_ranges,
                args.diff,
                args.config_priority,
            ) for (file_counter, inputfile) in enumerate(inputfiles)
        ]
    end

    # Use multithreading for multiple files (only if multiple threads available)
    # Single file or stdin or single thread: process sequentially
    use_threading = length(inputfiles) > 1 && Threads.nthreads() > 1

    exit_code = if use_threading
        # Parallel processing for multiple files
        # Use Threads.Atomic to track errors across threads
        has_unformatted = Threads.Atomic{Bool}(false)
        has_error = Threads.Atomic{Bool}(false)
        Threads.@threads for fileargs in fileargs_to_process
            err = process_file(fileargs)
            if err == UNFORMATTED_EXIT_CODE
                Threads.atomic_or!(has_unformatted, true)
            elseif err == ERROR_EXIT_CODE
                Threads.atomic_or!(has_error, true)
            end
        end
        if has_error[]
            ERROR_EXIT_CODE
        elseif has_unformatted[]
            UNFORMATTED_EXIT_CODE
        else
            SUCCESS_EXIT_CODE
        end
    else
        # Sequential processing
        has_unformatted = false
        has_error = false
        for opts in fileargs_to_process
            err = process_file(opts)
            if err == UNFORMATTED_EXIT_CODE
                has_unformatted = true
            elseif err == ERROR_EXIT_CODE
                has_error = true
            end
        end
        if has_error[]
            ERROR_EXIT_CODE
        elseif has_unformatted[]
            UNFORMATTED_EXIT_CODE
        else
            SUCCESS_EXIT_CODE
        end
    end

    # Print summary message for check mode
    if check && exit_code == UNFORMATTED_EXIT_CODE
        printstyled(
            stderr,
            "Some files are not formatted correctly. Run again with `--inplace` instead of `--check` to format them.\n";
            color = :red,
        )
    end

    return exit_code
end

struct ProcessFileArgs
    inputfile::String
    file_counter::Int
    nfiles_str::String
    print_progress::Bool
    check::Bool
    inplace::Bool
    outputfile::String
    input_is_stdin::Bool
    stdin_filename::String
    config_dir::String
    ignore_config::Bool
    config::Configuration
    line_ranges::Vector{Tuple{Int,Int}}
    diff::Bool
    config_priority::Bool
end

function process_file(args::ProcessFileArgs)
    local_errno = SUCCESS_EXIT_CODE

    # Build progress message if needed
    progress_prefix = if args.print_progress
        @assert !args.input_is_stdin
        input_pretty = relpath(args.inputfile)
        if Sys.iswindows()
            input_pretty = replace(input_pretty, "\\" => "/")
        end
        prefix = string(
            "[",
            lpad(string(args.file_counter), textwidth(args.nfiles_str), " "),
            "/",
            args.nfiles_str,
            "] ",
        )
        verb = args.check ? "Checking" : "Formatting"
        str = string(prefix, verb, " `", input_pretty, "` ")
        ndots = 80 - textwidth(str) - 1 - 1
        dots = ndots > 0 ? "."^ndots : ""
        string(str, dots, " ")
    else
        ""
    end

    # Emit a single progress line -- the dotted prefix followed by whatever `f` writes to its
    # `io` argument -- to stderr under the print lock. A no-op unless progress printing is on.
    report_status = function (f)
        args.print_progress || return
        @lock print_lock begin
            buf = IOBuffer()
            io = IOContext(buf, :color => supports_color(stderr))
            printstyled(io, progress_prefix; color = :blue)
            f(io)
            print(stderr, String(take!(buf)))
        end
        return
    end

    # Check if we should skip markdown files
    inputfile_pretty = args.input_is_stdin ? args.stdin_filename : args.inputfile
    _, ext = splitext(inputfile_pretty)
    is_markdown = ext in (".md", ".jmd", ".qmd")
    if is_markdown && !isempty(args.line_ranges)
        # Line-range formatting is not (yet) wired through the Markdown path.
        return panic("option `--lines` is not supported for Markdown input")
    end

    # Read the input
    sourcetext = if args.input_is_stdin
        try
            read(stdin, String)
        catch err
            report_status() do io
                errln(io, "✗ read failed")
            end
            return panic("could not read input from stdin: ", err)
        end
    elseif isfile(args.inputfile)
        try
            read(args.inputfile, String)
        catch err
            report_status() do io
                errln(io, "✗ read failed")
            end
            return panic("could not read input from file `$(args.inputfile)`: ", err)
        end
    else
        report_status() do io
            errln(io, "✗ not found")
        end
        return panic("input path is not a file or directory: `$(args.inputfile)`")
    end

    output = if args.inplace
        @assert args.outputfile == ""
        @assert isfile(args.inputfile)
        @assert !args.input_is_stdin
        Output(:file, args.inputfile, stdout, true, true)
    elseif args.check
        @assert args.outputfile == ""
        Output(:devnull, "", stdout, false, false)
    else
        if args.outputfile == "" || args.outputfile == "-"
            Output(:stdout, "", stdout, false, false)
        elseif isfile(args.outputfile) &&
               !args.input_is_stdin &&
               samefile(args.outputfile, args.inputfile)
            report_status() do io
                errln(io, "✗ invalid output")
            end
            return panic(
                "cannot use same file for input and output, use `--inplace` to modify a file in place",
            )
        else
            Output(:file, args.outputfile, stdout, true, false)
        end
    end

    # Look up .JuliaFormatter.toml config
    file_config = if args.ignore_config
        Configuration()
    else
        config_path = try
            if args.config_dir != ""
                find_config_file(args.config_dir)
            elseif !args.input_is_stdin
                find_config_file(args.inputfile)
            else
                nothing
            end
        catch e
            # find_config_file returns `nothing` if there isn't a config file,
            # but it can still throw (for example if --config-dir doesn't exist).
            if e isa ArgumentError
                return panic(e.msg)
            else
                rethrow()
            end
        end
        config_path !== nothing ? configuration_from_file(config_path) : Configuration()
    end
    # Merge: defaults < file config < CLI args (or defaults < CLI < file with
    # --prioritize-config-file)
    defaults = Configuration()
    config = if args.config_priority
        merge_config(merge_config(defaults, args.config), file_config)
    else
        merge_config(merge_config(defaults, file_config), args.config)
    end

    # Skip markdown files unless format_markdown is enabled
    if is_markdown && !something(config.format_markdown, false)
        report_status() do io
            okln(io, "skipped (markdown)")
        end
        return 0
    end

    # Check if file should be ignored (based on .JuliaFormatter.toml ignore patterns)
    if !args.input_is_stdin &&
       config.ignore !== nothing &&
       isignored(args.inputfile, config)
        report_status() do io
            okln(io, "skipped (ignored)")
        end
        return 0
    end

    style = config.style
    merged_options = get_formatting_options(config)

    formatted_str = try
        _formatted_str = if is_markdown
            _format_md(sourcetext, style, merged_options)
        elseif !isempty(args.line_ranges)
            _format_line_ranges(sourcetext, style, args.line_ranges, merged_options)
        else
            _format_text(sourcetext, style, merged_options; check_output = true)
        end
        # Since it's a file, presumably we only want one trailing newline, so
        # we normalise it here.
        replace(_formatted_str, r"\n*$" => "\n")
    catch err
        if err isa JuliaSyntax.ParseError
            report_status() do io
                errln(io, "✗ parse error")
            end
            return panic(string("failed to parse input from ", inputfile_pretty, ": "), err)
        end
        if err isa ArgumentError
            # User input error (e.g. an out-of-bounds `--lines` range). Report it cleanly,
            # without a backtrace, just like a parse error.
            report_status() do io
                errln(io, "✗ invalid input")
            end
            return panic(
                string("failed to format input from ", inputfile_pretty, ": "),
                err,
            )
        end
        report_status() do io
            errln(io, "✗ format failed")
        end
        msg = string("failed to format input from ", inputfile_pretty, ": ")
        bt = stacktrace(catch_backtrace())
        bt = bt[1:min(5, length(bt))]
        return panic(msg, err, bt)
    end

    changed = (formatted_str != sourcetext)
    if args.check
        if changed
            report_status() do io
                errln(io, "✗ needs formatting")
            end
            local_errno = UNFORMATTED_EXIT_CODE
        else
            report_status() do io
                okln(io, "✓ already formatted")
            end
        end
    elseif changed || !args.inplace
        @assert output.which !== :devnull
        try
            writeo(output, formatted_str)
        catch err
            report_status() do io
                errln(io, "✗ write failed")
            end
            panic("could not write to output file `$(output.file)`: ", err)
            return 1
        end
        report_status() do io
            if args.inplace
                okln(io, "✓ formatted")
            else
                okln(io)
            end
        end
    else
        # inplace && !changed
        report_status() do io
            okln(io, "no changes")
        end
    end

    if changed && args.diff
        mktempdir() do dir
            a = mkdir(joinpath(dir, "a"))
            b = mkdir(joinpath(dir, "b"))
            file = basename(inputfile_pretty)
            A = joinpath(a, file)
            B = joinpath(b, file)
            write(A, sourcetext)
            write(B, formatted_str)
            color = supports_color(stderr) ? "always" : "never"
            git_argv = String[
                Sys.which("git"),
                "--no-pager",
                "diff",
                "--diff-algorithm=patience",
                "--color=$(color)",
                "--no-index",
                "--no-prefix",
                relpath(A, dir),
                relpath(B, dir),
            ]
            cmd = Cmd(git_argv)
            # `ignorestatus` because --no-index implies --exit-code
            cmd = setenv(ignorestatus(cmd); dir = dir)
            cmd = pipeline(cmd; stdout = stderr, stderr = stderr)
            run(cmd)
        end
    end

    return local_errno
end

@static if isdefined(Base, Symbol("@main"))
    @main
end
