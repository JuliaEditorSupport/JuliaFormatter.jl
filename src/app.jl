# SPDX-License-Identifier: MIT

# For thread-safe printing
const print_lock = ReentrantLock()

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
        err::Union{Exception, Nothing} = nothing,
        bt::Union{Vector{Base.StackFrame}, Nothing} = nothing,
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
    return 1
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

function print_help()
    io = stdout
    printstyled(io, "NAME"; bold = true)
    println(io)
    println(io, "       jlfmt - An opinionated code formatter for Julia.")
    println(io)
    printstyled(io, "SYNOPSIS"; bold = true)
    println(io)
    println(io, "       jlfmt [<options>] <path>...")
    println(io, "       jlfmt [<options>] -")
    println(io, "       ... | jlfmt [<options>]")
    println(io)
    printstyled(io, "DESCRIPTION"; bold = true)
    println(io)
    println(
        io,
        """
               `jlfmt` formats Julia source code using JuliaFormatter.jl.
               This tool can also be invoked as `julia -m JuliaFormatter`.
        """,
    )
    printstyled(io, "OPTIONS"; bold = true)
    println(io)
    println(
        io,
        """
               <path>...
                   Input path(s) (files and/or directories) to process. For directories,
                   all files (recursively) with the '*.jl' suffix are used as input files
                   (also '*.md', '*.jmd', '*.qmd' if --format-markdown is specified).
                   If no path is given, or if path is `-`, input is read from stdin.

               -c, --check
                   Do not write output and exit with a non-zero code if the input is not
                   formatted correctly.

               -d, --diff
                   Print the diff between the input and formatted output to stderr.
                   Requires `git` to be installed.

               -h, --help
                   Print this message.

               -i, --inplace
                   Format files in place.

               -o <file>, --output=<file>
                   File to write formatted output to. If no output is given, or if the file
                   is `-`, output is written to stdout.

               --stdin-filename=<filename>
                   Assumed filename when formatting from stdin. Used for error messages.

               --config-dir=<path>
                   Directory path to use for .JuliaFormatter.toml config file lookup when
                   formatting from stdin. By default, stdin input does not use config files.
                   With this option, the formatter will search for .JuliaFormatter.toml in
                   the specified directory and its parent directories.

               -v, --verbose
                   Enable verbose output.

               --version
                   Print JuliaFormatter and julia version information.

               --prioritize-config-file
                   Prioritize .JuliaFormatter.toml config file options over command-line options.
                   By default, command-line options override config file options. This flag
                   reverses that precedence, useful for language server integration where
                   project configuration should take precedence over editor settings.

               FORMATTING OPTIONS

               --style=<style>
                   Formatting style: "default", "yas", "blue", "sciml", or "minimal".
                   Default: "default"

               --indent=<n>
                   Indentation width. Default: 4

               --margin=<n>
                   Maximum line width. Default: 92

               --format_markdown
                   Also format code blocks in Markdown files (.md, .jmd, .qmd).

               --ignore=<pattern>
                   Ignore files matching the given pattern. Can be specified multiple times.
                   Patterns use glob-style matching (e.g., "*/test/*", "*.tmp").

               --always_for_in / --no-always_for_in
                   Always use 'for x in' instead of 'for x =' or 'for x '.
                   Default: false

               --whitespace_typedefs / --no-whitespace_typedefs
                   Add whitespace around '::' in type definitions.
                   Default: false

               --remove_extra_newlines / --no-remove_extra_newlines
                   Remove extra newlines.
                   Default: false

               --import_to_using / --no-import_to_using
                   Convert 'import' to 'using'.
                   Default: false

               --pipe_to_function_call / --no-pipe_to_function_call
                   Convert pipe operator to function calls.
                   Default: false

               --short_to_long_function_def / --no-short_to_long_function_def
                   Convert short function definitions to long form.
                   Default: false

               --always_use_return / --no-always_use_return
                   Always add explicit 'return' statements.
                   Default: false

               --whitespace_in_kwargs / --no-whitespace_in_kwargs
                   Add whitespace in keyword arguments.
                   Default: true

               --format_docstrings / --no-format_docstrings
                   Format docstrings.
                   Default: false

               --align_struct_field / --no-align_struct_field
                   Align struct field type annotations.
                   Default: false

               --align_assignment / --no-align_assignment
                   Align assignment operators.
                   Default: false

               --align_conditional / --no-align_conditional
                   Align conditional operators.
                   Default: false

               --align_pair_arrow / --no-align_pair_arrow
                   Align pair arrows (=>).
                   Default: false

               --trailing_comma / --no-trailing_comma
                   Add trailing commas.
                   Default: true

               --trailing_zero / --no-trailing_zero
                   Add trailing zeros to floats.
                   Default: true

               --normalize_line_endings=<mode>
                   Normalize line endings: "auto", "unix", or "windows".
                   Default: "auto"
        """,
    )
    println(io)
    printstyled(io, "EXAMPLES"; bold = true)
    println(io)
    println(
        io,
        """
               Format a file and write to stdout:
                   jlfmt src/file.jl

               Format a file in place:
                   jlfmt --inplace src/file.jl

               Format all files in a directory with the verbose mode:
                   jlfmt --inplace --verbose src/

               Check if a file is formatted:
                   jlfmt --check src/file.jl

               Check if all files in a directory are formatted with multiple threads:
                   jlfmt --threads=4 -- --check src/

               Show diff for formatting wtih 2-space indentations:
                    jlfmt --diff --indent=2 src/file.jl

               Format from stdin (pipe):
                   echo 'f(x,y)=x+y' | jlfmt

               Format from stdin (explicit):
                   jlfmt - < input.jl

               Format from stdin using project config:
                   echo 'f(x,y)=x+y' | jlfmt --config-dir=./src

               Use specific style:
                   jlfmt --style=blue src/file.jl

               Combine options:
                   echo 'for i=1:10; end' | jlfmt --always_for_in
        """,
    )
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
    errno::Cint = 0

    inputfiles = String[]
    outputfile = ""
    stdin_filename = "stdin"
    config_dir = ""
    verbose = false
    inplace = false
    diff = false
    check = false
    input_is_stdin = true
    multiple_inputs = false
    format_markdown = false
    config_priority = false
    style_name = "default"
    format_options = Dict{Symbol, Any}()
    ignore_patterns = String[]

    paths = String[]
    i = 1
    while i <= length(argv)
        x = argv[i]
        if x == "-i" || x == "--inplace"
            inplace = true
            i += 1
        elseif x == "-h" || x == "--help"
            print_help()
            return errno
        elseif x == "--version"
            print_version()
            return errno
        elseif x == "-v" || x == "--verbose"
            verbose = true
            i += 1
        elseif x == "-d" || x == "--diff"
            diff = true
            i += 1
        elseif x == "-c" || x == "--check"
            check = true
            i += 1
        elseif x == "--prioritize-config-file"
            config_priority = true
            i += 1
        elseif startswith(x, "--stdin-filename=")
            m = match(r"^--stdin-filename=(.+)$", x)
            stdin_filename = String(m.captures[1]::AbstractString)
            i += 1
        elseif startswith(x, "--config-dir=")
            m = match(r"^--config-dir=(.+)$", x)
            config_dir = String(m.captures[1]::AbstractString)
            i += 1
        elseif x == "-o"
            if i >= length(argv)
                return panic("expected output file argument after `-o`")
            end
            outputfile = argv[i + 1]
            i += 2
        elseif startswith(x, "--output=")
            m = match(r"^--output=(.+)$", x)
            outputfile = String(m.captures[1]::AbstractString)
            i += 1
        elseif x == "--format_markdown"
            format_markdown = true
            i += 1
        elseif startswith(x, "--ignore=")
            m = match(r"^--ignore=(.+)$", x)
            push!(ignore_patterns, String(m.captures[1]::AbstractString))
            i += 1
        elseif startswith(x, "--style=")
            m = match(r"^--style=(.+)$", x)
            style_name = String(m.captures[1]::AbstractString)
            i += 1
        elseif startswith(x, "--indent=")
            m = match(r"^--indent=(\d+)$", x)
            format_options[:indent] = Base.parse(Int, m.captures[1]::AbstractString)
            i += 1
        elseif startswith(x, "--margin=")
            m = match(r"^--margin=(\d+)$", x)
            format_options[:margin] = Base.parse(Int, m.captures[1]::AbstractString)
            i += 1
        elseif startswith(x, "--normalize_line_endings=")
            m = match(r"^--normalize_line_endings=(.+)$", x)
            format_options[:normalize_line_endings] = String(m.captures[1]::AbstractString)
            i += 1
        elseif x == "--always_for_in"
            format_options[:always_for_in] = true
            i += 1
        elseif x == "--no-always_for_in"
            format_options[:always_for_in] = false
            i += 1
        elseif x == "--whitespace_typedefs"
            format_options[:whitespace_typedefs] = true
            i += 1
        elseif x == "--no-whitespace_typedefs"
            format_options[:whitespace_typedefs] = false
            i += 1
        elseif x == "--remove_extra_newlines"
            format_options[:remove_extra_newlines] = true
            i += 1
        elseif x == "--no-remove_extra_newlines"
            format_options[:remove_extra_newlines] = false
            i += 1
        elseif x == "--import_to_using"
            format_options[:import_to_using] = true
            i += 1
        elseif x == "--no-import_to_using"
            format_options[:import_to_using] = false
            i += 1
        elseif x == "--pipe_to_function_call"
            format_options[:pipe_to_function_call] = true
            i += 1
        elseif x == "--no-pipe_to_function_call"
            format_options[:pipe_to_function_call] = false
            i += 1
        elseif x == "--short_to_long_function_def"
            format_options[:short_to_long_function_def] = true
            i += 1
        elseif x == "--no-short_to_long_function_def"
            format_options[:short_to_long_function_def] = false
            i += 1
        elseif x == "--always_use_return"
            format_options[:always_use_return] = true
            i += 1
        elseif x == "--no-always_use_return"
            format_options[:always_use_return] = false
            i += 1
        elseif x == "--whitespace_in_kwargs"
            format_options[:whitespace_in_kwargs] = true
            i += 1
        elseif x == "--no-whitespace_in_kwargs"
            format_options[:whitespace_in_kwargs] = false
            i += 1
        elseif x == "--format_docstrings"
            format_options[:format_docstrings] = true
            i += 1
        elseif x == "--no-format_docstrings"
            format_options[:format_docstrings] = false
            i += 1
        elseif x == "--align_struct_field"
            format_options[:align_struct_field] = true
            i += 1
        elseif x == "--no-align_struct_field"
            format_options[:align_struct_field] = false
            i += 1
        elseif x == "--align_assignment"
            format_options[:align_assignment] = true
            i += 1
        elseif x == "--no-align_assignment"
            format_options[:align_assignment] = false
            i += 1
        elseif x == "--align_conditional"
            format_options[:align_conditional] = true
            i += 1
        elseif x == "--no-align_conditional"
            format_options[:align_conditional] = false
            i += 1
        elseif x == "--align_pair_arrow"
            format_options[:align_pair_arrow] = true
            i += 1
        elseif x == "--no-align_pair_arrow"
            format_options[:align_pair_arrow] = false
            i += 1
        elseif x == "--trailing_comma"
            format_options[:trailing_comma] = true
            i += 1
        elseif x == "--no-trailing_comma"
            format_options[:trailing_comma] = false
            i += 1
        elseif x == "--trailing_zero"
            format_options[:trailing_zero] = true
            i += 1
        elseif x == "--no-trailing_zero"
            format_options[:trailing_zero] = false
            i += 1
        else
            # Not an option, must be a file or directory
            push!(paths, x)
            i += 1
        end
    end

    for x in paths
        if x == "-"
            # `-` is only allowed once and as the only input
            if length(paths) > 1
                return panic("input `-` can not be combined with other input")
            end
            push!(inputfiles, x)
            input_is_stdin = true
        else
            input_is_stdin = false
            if isdir(x)
                scandir!(inputfiles, x)
                multiple_inputs = true
            else
                push!(inputfiles, x)
            end
        end
    end

    if length(paths) > 1 || (length(paths) == 1 && isdir(paths[1]))
        multiple_inputs = true
    end

    # Insert `-` as the input if there were no input files/directories on the command line
    if input_is_stdin && length(inputfiles) == 0
        @assert !multiple_inputs
        push!(inputfiles, "-")
    end

    # Validate the arguments
    if inplace && check
        return panic("options `--inplace` and `--check` are mutually exclusive")
    end
    if inplace && outputfile != ""
        return panic("options `--inplace` and `--output` are mutually exclusive")
    end
    if check && outputfile != ""
        return panic("options `--check` and `--output` are mutually exclusive")
    end
    if inplace && input_is_stdin
        return panic("option `--inplace` can not be used together with stdin input")
    end
    if outputfile != "" && multiple_inputs
        return panic("option `--output` can not be used together with multiple input files")
    end
    if multiple_inputs && !(inplace || check)
        return panic("option `--inplace` or `--check` required with multiple input files")
    end

    if diff
        if Sys.which("git") === nothing
            return panic("option `--diff` requires `git` to be installed")
        end
    end

    format_options[:style] = if style_name == "default"
        DefaultStyle()
    elseif style_name == "yas"
        YASStyle()
    elseif style_name == "blue"
        BlueStyle()
    elseif style_name == "sciml"
        SciMLStyle()
    elseif style_name == "minimal"
        MinimalStyle()
    else
        return panic("unknown style: \"$style_name\"")
    end

    # Add ignore patterns from command line
    if !isempty(ignore_patterns)
        format_options[:ignore] = ignore_patterns
    end

    # Disable verbose if piping from/to stdin/stdout
    output_is_stdout = !inplace && !check && (outputfile == "" || outputfile == "-")
    print_progress = verbose && !(input_is_stdin || output_is_stdout)

    nfiles_str = string(length(inputfiles))
    options_list = (
        ProcessFileArgs(
                inputfile,
                file_counter,
                nfiles_str,
                print_progress,
                check,
                inplace,
                outputfile,
                input_is_stdin,
                stdin_filename,
                config_dir,
                format_options,
                diff,
                format_markdown,
                config_priority,
            ) for (file_counter, inputfile) in enumerate(inputfiles)
    )

    # Use multithreading for multiple files (only if multiple threads available)
    # Single file or stdin or single thread: process sequentially
    use_threading = length(inputfiles) > 1 && Threads.nthreads() > 1

    if use_threading
        # Parallel processing for multiple files
        # Use Threads.Atomic to track errors across threads
        has_error = Threads.Atomic{Bool}(false)
        Threads.@threads for opts in options_list
            err = process_file(opts)
            if err != 0
                Threads.atomic_or!(has_error, true)
            end
        end
        if has_error[]
            errno = 1
        end
    else
        # Sequential processing
        for opts in options_list
            err = process_file(opts)
            if err != 0
                errno = err
            end
        end
    end

    # Print summary message for check mode
    if check && errno != 0
        printstyled(
            stderr,
            "Some files are not formatted correctly. Run without --check to format them.\n";
            color = :red,
        )
    end

    return errno
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
    format_options::Dict{Symbol, Any}
    diff::Bool
    format_markdown::Bool
    config_priority::Bool
end

function process_file(args::ProcessFileArgs)
    local_errno = 0

    # Build progress message if needed
    progress_prefix = if args.print_progress
        @assert args.inputfile != "-"
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

    # Check if we should skip markdown files
    inputfile_pretty = args.inputfile == "-" ? args.stdin_filename : args.inputfile
    _, ext = splitext(inputfile_pretty)
    is_markdown = ext in (".md", ".jmd", ".qmd")
    if is_markdown && !args.format_markdown
        if args.print_progress
            @lock print_lock begin
                buf = IOBuffer()
                io = IOContext(buf, :color => supports_color(stderr))
                printstyled(io, progress_prefix; color = :blue)
                okln(io, "skipped (markdown)")
                print(stderr, String(take!(buf)))
            end
        end
        return 0
    end

    # Read the input
    sourcetext = if args.inputfile == "-"
        @assert args.input_is_stdin
        try
            read(stdin, String)
        catch err
            if args.print_progress
                @lock print_lock begin
                    buf = IOBuffer()
                    io = IOContext(buf, :color => supports_color(stderr))
                    printstyled(io, progress_prefix; color = :blue)
                    errln(io, "✗ read failed")
                    print(stderr, String(take!(buf)))
                end
            end
            panic("could not read input from stdin: ", err)
            return 1
        end
    elseif isfile(args.inputfile)
        @assert !args.input_is_stdin
        try
            read(args.inputfile, String)
        catch err
            if args.print_progress
                @lock print_lock begin
                    buf = IOBuffer()
                    io = IOContext(buf, :color => supports_color(stderr))
                    printstyled(io, progress_prefix; color = :blue)
                    errln(io, "✗ read failed")
                    print(stderr, String(take!(buf)))
                end
            end
            panic("could not read input from file `$(args.inputfile)`: ", err)
            return 1
        end
    else
        if args.print_progress
            @lock print_lock begin
                buf = IOBuffer()
                io = IOContext(buf, :color => supports_color(stderr))
                printstyled(io, progress_prefix; color = :blue)
                errln(io, "✗ not found")
                print(stderr, String(take!(buf)))
            end
        end
        panic("input path is not a file or directory: `$(args.inputfile)`")
        return 1
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
            if args.print_progress
                @lock print_lock begin
                    buf = IOBuffer()
                    io = IOContext(buf, :color => supports_color(stderr))
                    printstyled(io, progress_prefix; color = :blue)
                    errln(io, "✗ invalid output")
                    print(stderr, String(take!(buf)))
                end
            end
            panic(
                "can not use same file for input and output, use `-i` to modify a file in place",
            )
            return 1
        else
            Output(:file, args.outputfile, stdout, true, false)
        end
    end

    # For files (not stdin), merge with .JuliaFormatter.toml config if it exists
    # Also merge config if --config-dir is specified for stdin input
    effective_options = if args.inputfile != "-"
        # Find and load .JuliaFormatter.toml config
        config_nt = find_config_file(args.inputfile)
        config_dict = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in pairs(config_nt))
        # Merge: by default, command line options override config file
        # If --prioritize-config-file is set, config file options override command line
        if args.config_priority
            merge(args.format_options, config_dict)
        else
            merge(config_dict, args.format_options)
        end
    elseif args.config_dir != ""
        # For stdin input with --config-dir specified, use the directory for config lookup
        config_path = joinpath(args.config_dir, ".JuliaFormatter.toml")
        config_nt = if isfile(config_path)
            parse_config(config_path)
        else
            # Try to find config file recursively from the directory
            find_config_file(args.config_dir)
        end
        config_dict = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in pairs(config_nt))
        if args.config_priority
            merge(args.format_options, config_dict)
        else
            merge(config_dict, args.format_options)
        end
    else
        args.format_options
    end

    # Check if file should be ignored (based on .JuliaFormatter.toml ignore patterns)
    if args.inputfile != "-"
        ignore_patterns = get(effective_options, :ignore, String[])
        if any(
                pattern -> occursin(Glob.FilenameMatch("*$pattern"), args.inputfile),
                ignore_patterns,
            )
            # Skip ignored files
            if args.print_progress
                @lock print_lock begin
                    buf = IOBuffer()
                    io = IOContext(buf, :color => supports_color(stderr))
                    printstyled(io, progress_prefix; color = :blue)
                    okln(io, "skipped (ignored)")
                    print(stderr, String(take!(buf)))
                end
            end
            return 0
        end
    end

    formatted_str = try
        if is_markdown
            format_md(sourcetext; effective_options...)
        else
            format_text(sourcetext; effective_options...)
        end
    catch err
        if err isa JuliaSyntax.ParseError
            if args.print_progress
                @lock print_lock begin
                    buf = IOBuffer()
                    io = IOContext(buf, :color => supports_color(stderr))
                    printstyled(io, progress_prefix; color = :blue)
                    errln(io, "✗ parse error")
                    print(stderr, String(take!(buf)))
                end
            end
            panic(string("failed to parse input from ", inputfile_pretty, ": "), err)
            return 1
        end
        if args.print_progress
            @lock print_lock begin
                buf = IOBuffer()
                io = IOContext(buf, :color => supports_color(stderr))
                printstyled(io, progress_prefix; color = :blue)
                errln(io, "✗ format failed")
                print(stderr, String(take!(buf)))
            end
        end
        msg = string("failed to format input from ", inputfile_pretty, ": ")
        bt = stacktrace(catch_backtrace())
        bt = bt[1:min(5, length(bt))]
        panic(msg, err, bt)
        return 1
    end

    formatted_str = replace(formatted_str, r"\n*$" => "\n")

    changed = (formatted_str != sourcetext)
    if args.check
        if changed
            if args.print_progress
                @lock print_lock begin
                    buf = IOBuffer()
                    io = IOContext(buf, :color => supports_color(stderr))
                    printstyled(io, progress_prefix; color = :blue)
                    errln(io, "✗ needs formatting")
                    print(stderr, String(take!(buf)))
                end
            end
            local_errno = 1
        else
            if args.print_progress
                @lock print_lock begin
                    buf = IOBuffer()
                    io = IOContext(buf, :color => supports_color(stderr))
                    printstyled(io, progress_prefix; color = :blue)
                    okln(io, "✓ already formatted")
                    print(stderr, String(take!(buf)))
                end
            end
        end
    elseif changed || !args.inplace
        @assert output.which !== :devnull
        try
            writeo(output, formatted_str)
        catch err
            if args.print_progress
                @lock print_lock begin
                    buf = IOBuffer()
                    io = IOContext(buf, :color => supports_color(stderr))
                    printstyled(io, progress_prefix; color = :blue)
                    errln(io, "✗ write failed")
                    print(stderr, String(take!(buf)))
                end
            end
            panic("could not write to output file `$(output.file)`: ", err)
            return 1
        end
        if args.print_progress
            @lock print_lock begin
                buf = IOBuffer()
                io = IOContext(buf, :color => supports_color(stderr))
                printstyled(io, progress_prefix; color = :blue)
                if args.inplace
                    okln(io, "✓ formatted")
                else
                    okln(io)
                end
                print(stderr, String(take!(buf)))
            end
        end
    else
        # inplace && !changed
        if args.print_progress
            @lock print_lock begin
                buf = IOBuffer()
                io = IOContext(buf, :color => supports_color(stderr))
                printstyled(io, progress_prefix; color = :blue)
                okln(io, "no changes")
                print(stderr, String(take!(buf)))
            end
        end
    end

    if changed && args.diff
        mktempdir() do dir
            a = mkdir(joinpath(dir, "a"))
            b = mkdir(joinpath(dir, "b"))
            file = basename(args.inputfile == "-" ? args.stdin_filename : args.inputfile)
            A = joinpath(a, file)
            B = joinpath(b, file)
            write(A, sourcetext)
            write(B, formatted_str)
            color = supports_color(stderr) ? "always" : "never"
            git_argv = String[
                Sys.which("git"),
                "--no-pager",
                "diff",
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
