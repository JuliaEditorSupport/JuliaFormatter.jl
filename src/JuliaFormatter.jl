module JuliaFormatter

# reduces compilation time
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

using PrecompileTools: @setup_workload, @compile_workload
using JuliaSyntax
using JuliaSyntax: haschildren, children, span, @K_str, kind, @KSet_str
using TOML: parsefile
using Glob
import CommonMark: block_modifier
import Base: get, pairs, show, push!, @kwdef
using CommonMark:
    AdmonitionRule,
    CodeBlock,
    enable!,
    FootnoteRule,
    markdown,
    MathRule,
    Parser,
    Rule,
    TableRule,
    FrontMatterRule

export format,
    format_text,
    format_file,
    format_md,
    DefaultStyle,
    YASStyle,
    BlueStyle,
    SciMLStyle,
    MinimalStyle

struct Configuration
    args::Dict{String,Any}
    file::Dict{String,Any}
end
Configuration() = Configuration(Dict{String,Any}(), Dict{String,Any}())
Configuration(args) = Configuration(args, Dict{String,Any}())
function get(config::Configuration, s::String, default)
    if haskey(config.args, s)
        return config.args[s]
    end
    if haskey(config.file, s)
        return config.file[s]
    end
    return default
end
function pairs(conf::Configuration)
    pairs(merge(conf.file, conf.args))
end

abstract type AbstractStyle end

options(::AbstractStyle) = NamedTuple()

struct NoopStyle <: AbstractStyle end

"""
    DefaultStyle

The default formatting style. See the [Style](@ref) section of the documentation
for more details.

See also: [`BlueStyle`](@ref), [`YASStyle`](@ref), [`SciMLStyle`](@ref), [`MinimalStyle`](@ref)
"""
struct DefaultStyle <: AbstractStyle
    innerstyle::AbstractStyle
end
DefaultStyle() = DefaultStyle(NoopStyle())

getstyle(s::NoopStyle) = s
getstyle(s::DefaultStyle) = s.innerstyle isa NoopStyle ? s : s.innerstyle

function options(::DefaultStyle)
    return (;
        indent = 4,
        margin = 92,
        always_for_in = false,
        whitespace_typedefs = false,
        whitespace_ops_in_indices = false,
        remove_extra_newlines = false,
        import_to_using = false,
        pipe_to_function_call = false,
        short_to_long_function_def = false,
        long_to_short_function_def = false,
        always_use_return = false,
        whitespace_in_kwargs = true,
        annotate_untyped_fields_with_any = true,
        format_docstrings = false,
        align_struct_field = false,
        align_assignment = false,
        align_conditional = false,
        align_pair_arrow = false,
        conditional_to_if = false,
        normalize_line_endings = "auto",
        align_matrix = false,
        join_lines_based_on_source = false,
        trailing_comma = true,
        trailing_zero = true,
        indent_submodule = false,
        separate_kwargs_with_semicolon = false,
        surround_whereop_typeparameters = true,
        variable_call_indent = [],
        short_circuit_to_if = false,
        disallow_single_arg_nesting = false,
    )
end

include("document.jl")
include("options.jl")
include("state.jl")
include("fst.jl")
include("passes.jl")
include("align.jl")

function list_different_defaults(style)
    options_style = pairs(options(style))
    options_default = pairs(options(DefaultStyle()))
    options_changed = setdiff(options_style, options_default)
    sort!(options_changed; by = first)
    io = IOBuffer()
    for (key, val) in options_changed
        println(io, "- `$key` = $val")
    end
    String(take!(io))
end

include("styles/default/pretty.jl")
include("styles/default/nest.jl")
include("styles/yas/pretty.jl")
include("styles/yas/nest.jl")
include("styles/blue/pretty.jl")
include("styles/blue/nest.jl")
include("styles/sciml/pretty.jl")
include("styles/sciml/nest.jl")
include("styles/minimal/pretty.jl")

include("format_docstring.jl")
include("nest_utils.jl")
include("print.jl")
include("markdown.jl")
include("copied_from_documenter.jl")

const UNIX_TO_WINDOWS = r"\r?\n" => "\r\n"
const WINDOWS_TO_UNIX = "\r\n" => "\n"
function choose_line_ending_replacer(text)
    rn = count("\r\n", text)
    n = count(r"(?<!\r)\n", text)
    n >= rn ? WINDOWS_TO_UNIX : UNIX_TO_WINDOWS
end
normalize_line_ending(s::AbstractString, replacer = WINDOWS_TO_UNIX) = replace(s, replacer)

"""
    format_text(
        text::AbstractString;
        style::AbstractStyle = DefaultStyle(),
        indent::Int = 4,
        margin::Int = 92,
        options...,
    )::String

Formats a Julia source passed in as a string, returning the formatted
code as another string.

See [Formatting Options](@ref "Formatting-Options") for details on available options.
"""
function format_text(text::AbstractString; style::AbstractStyle = DefaultStyle(), kwargs...)
    return format_text(text, style; kwargs...)
end

function format_text(text::AbstractString, style::AbstractStyle; kwargs...)
    if isempty(text)
        return text
    end
    opts = Options(; merge(options(style), kwargs)...)
    return format_text(text, style, opts)
end

function format_text(text::AbstractString, style::SciMLStyle; maxiters = 3, kwargs...)
    if isempty(text)
        return text
    end
    opts = Options(; merge(options(style), kwargs)...)
    # We need to iterate to a fixpoint because the result of short to long
    # form isn't properly formatted
    formatted_text = format_text(text, style, opts)
    if maxiters == 0
        return formatted_text
    end
    iter = 1
    while formatted_text != text
        if iter > maxiters
            error("formatted_text hasn't reached to a fixpoint in $iter iterations")
        end
        text = formatted_text
        formatted_text = format_text(text, style, opts)
        iter += 1
    end
    return formatted_text
end

function format_text(text::AbstractString, style::AbstractStyle, opts::Options)
    if opts.always_for_in == true
        @assert valid_for_in_op(opts.for_in_replacement) "`for_in_replacement` is set to an invalid operator \"$(opts.for_in_replacement)\", valid operators are $(VALID_FOR_IN_OPERATORS). Change it to one of the valid operators and then reformat."
    end
    t = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; ignore_warnings = true)
    state = State(Document(text), opts)
    text = format_text(t, style, state)
    return text
end

function format_text(node::JuliaSyntax.GreenNode, style::AbstractStyle, s::State)
    fst::FST = try
        pretty(style, node, s)
    catch e
        loc = cursor_loc(s, s.offset)
        @warn "Error occurred during prettification" line = loc[1] offset = loc[2] goffset =
            s.offset
        rethrow(e)
    end
    if hascomment(s.doc, fst.endline)
        add_node!(fst, InlineComment(fst.endline), s)
    end

    if s.opts.pipe_to_function_call
        pipe_to_function_call_pass!(fst)
    end

    flatten_fst!(fst)

    if s.opts.short_circuit_to_if
        short_circuit_to_if_pass!(fst, s)
    end

    if needs_alignment(s.opts)
        align_fst!(fst, s.doc, s.opts)
    end

    nest!(style, fst, s)

    # ignore maximum width can be extra whitespace at the end of lines
    # remove it all before we print.
    if s.opts.join_lines_based_on_source
        remove_superfluous_whitespace!(fst)
    end

    s.line_offset = 0
    io = IOBuffer()

    # Print comments and whitespace before code.
    if fst.startline > 1
        format_check(io, Notcode(1, fst.startline - 1), s)
        print_leaf(io, Newline(), s)
    end
    print_tree(io, fst, s)
    nlines = numlines(s.doc)
    if s.on && fst.endline < nlines
        print_leaf(io, Newline(), s)
        format_check(io, Notcode(fst.endline + 1, nlines), s)
    end
    if s.doc.ends_on_nl
        print_leaf(io, Newline(), s)
    end
    text = String(take!(io))

    replacer = if s.opts.normalize_line_endings == "unix"
        WINDOWS_TO_UNIX
    elseif s.opts.normalize_line_endings == "windows"
        UNIX_TO_WINDOWS
    else
        choose_line_ending_replacer(s.doc.srcfile.code)
    end
    text = normalize_line_ending(text, replacer)

    try
        _ = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; ignore_warnings = true)
    catch err
        @warn "Formatted text is not parsable ... no change made."
        rethrow(err)
    end

    return text
end

function _format_file(
    filename::AbstractString;
    overwrite::Bool = true,
    verbose::Bool = false,
    format_markdown::Bool = false,
    format_options...,
)::Bool
    path, ext = splitext(filename)
    shebang_pattern = r"^#!\s*/.*\bjulia[0-9.-]*\b"
    formatted_str = if match(r"^\.[jq]*md$", ext) ≠ nothing
        if !(format_markdown)
            return true
        end
        if verbose
            println("Formatting $filename")
        end
        str = String(read(filename))
        format_md(str; format_options...)
    elseif ext == ".jl" || match(shebang_pattern, readline(filename)) !== nothing
        if verbose
            println("Formatting $filename")
        end
        str = String(read(filename))
        format_text(str; format_options...)
    else
        error("$filename must be a Julia (.jl) or Markdown (.md, .jmd or .qmd) source file")
    end
    formatted_str = replace(formatted_str, r"\n*$" => "\n")
    already_formatted = (formatted_str == str)
    if overwrite && !already_formatted
        write(filename, formatted_str)
    end
    return already_formatted
end

function _format_file(filename::AbstractString, style::AbstractStyle; kwargs...)
    return _format_file(filename; style = style, kwargs...)
end

const CONFIG_FILE_NAME = ".JuliaFormatter.toml"

"""
    format_file(
        filename::AbstractString;
        overwrite::Bool = true,
        verbose::Bool = false,
        format_markdown::Bool = false,
        format_options...,
    )::Bool

Formats the contents of `filename` assuming it's a `.jl`, `.md`, `.jmd` or `.qmd` file.

See [File Options](@ref "File-Options") for details on available options.

## Output

Returns a boolean indicating whether the file was already formatted (`true`) or not (`false`).
"""
function format_file(
    filename::AbstractString;
    overwrite::Bool = true,
    verbose::Bool = false,
    format_markdown::Bool = false,
    format_options...,
)
    format(
        filename;
        overwrite = overwrite,
        verbose = verbose,
        format_markdown = format_markdown,
        format_options...,
    )
end

function format_file(filename::AbstractString, style::AbstractStyle; kwargs...)
    return format_file(filename; style = style, kwargs...)
end

"""
    format(
        paths; # a path or collection of paths
        options...,
    )::Bool

Recursively descend into files and directories, formatting any `.jl`, `.md`, `.jmd`,
or `.qmd` files.

See [`format_file`](@ref) and [`format_text`](@ref) for a description of the options.

This function will look for `.JuliaFormatter.toml` in the location of the file being
formatted, and searching *up* the file tree until a config file is (or isn't) found.
When found, the configurations in the file will overwrite the given `options`.
See [Configuration File](@ref config) for more details.

### Output

Returns a boolean indicating whether the file was already formatted (`true`)
or not (`false`).
"""
function format(paths; options...)
    format(paths, Configuration(Dict{String,Any}(String(k) => v for (k, v) in options)))
end
function format(paths, options::Configuration)::Bool
    already_formatted = true
    # Don't parallelize this, since there could be a race condition on a
    # subdirectory that is included in both paths
    for path in paths
        already_formatted &= format(path, options)
    end
    return already_formatted
end

function format(path::AbstractString; verbose::Bool = false, options...)
    config = Dict{String,Any}(String(k) => v for (k, v) in options)
    config["verbose"] = verbose
    formatted = format(path, Configuration(config))
    if verbose && formatted
        println("Well done! ✨ 🍰 ✨")
    end
    return formatted
end

function format(path::AbstractString, options::Configuration)
    path = realpath(path)
    if !get(options, "config_applied", false)
        # Run recursive search upward *once*
        options =
            Configuration(copy(options.args), Dict{String,Any}(find_config_file(path)))
        options.args["config_applied"] = true
    end
    if isignored(path, options)
        return true
    end
    if isdir(path)
        configpath = joinpath(path, CONFIG_FILE_NAME)
        if isfile(configpath)
            options = Configuration(copy(options.args), parse_config(configpath))
        end
        formatted = Threads.Atomic{Bool}(true)
        Threads.@threads for subpath in readdir(path)
            subpath = joinpath(path, subpath)
            if !ispath(subpath) || islink(subpath)
                continue
            end
            is_formatted = format(subpath, options)
            Threads.atomic_and!(formatted, is_formatted)
        end
        return formatted.value
    end
    # `path` is not a directory but a file
    _, ext = splitext(path)
    if !in(ext, (".jl", ".md", ".jmd", ".qmd"))
        return true
    end
    try
        formatted = _format_file(path; [Symbol(k) => v for (k, v) in pairs(options)]...)
        return formatted
    catch err
        if err isa JuliaSyntax.ParseError
            @warn "Failed to format file $path due to a parsing error, skipping file" error =
                err
            return true
        end
        @info "Error in formatting file $path"
        @debug "formatting failed due to" exception = (err, catch_backtrace())
        return _format_file(path; [Symbol(k) => v for (k, v) in pairs(options)]...)
    end
end

"""
    format(path, style::AbstractStyle; options...)::Bool
"""
function format(path::AbstractString, style::AbstractStyle; options...)
    formatted = format(path; style = style, options...)
    formatted
end

"""
    format(mod::Module, args...; options...)
"""
format(mod::Module; options...) = _format_module(mod; options...)
function format(mod::Module, style::AbstractStyle; options...)
    _format_module(mod, style; options...)
end
function format(mod::Module, config::Configuration; options...)
    _format_module(mod, config; options...)
end

# This separate is needed to remove ambiguity in `format` without code duplication
function _format_module(mod::Module, args...; options...)
    path = pkgdir(mod)
    if path === nothing
        throw(ArgumentError("couldn't find a directory of module `$mod`"))
    end
    format(path, args...; options...)
end

function kwargs(dict)
    ns = (Symbol.(keys(dict))...,)
    vs = (collect(values(dict))...,)
    return pairs(NamedTuple{ns}(vs))
end

fieldnts(T::Type) = ((fieldname(T, i), fieldtype(T, i)) for i in 1:fieldcount(T))

function parse_config(tomlfile)
    config_dict = parsefile(tomlfile)
    for (field, type) in fieldnts(Options)
        if type == Union{Bool,Nothing}
            field = string(field)
            if get(config_dict, field, "") == "nothing"
                config_dict[field] = nothing
            end
        end
    end
    if (style = get(config_dict, "style", nothing)) !== nothing
        if style ∉ ("default", "yas", "blue", "sciml", "minimal")
            error(
                "currently $(CONFIG_FILE_NAME) accepts only \"default\" or \"yas\", \"blue\", \"sciml\", or \"minimal\" for the style configuration",
            )
        end
        config_dict["style"] = if style == "yas"
            YASStyle()
        elseif style == "blue"
            BlueStyle()
        elseif style == "sciml"
            SciMLStyle()
        elseif style == "minimal"
            MinimalStyle()
        else
            DefaultStyle()
        end
    end
    return config_dict
end

function find_config_file(path)
    dir = dirname(path)
    if (path == dir || isempty(path))
        return NamedTuple()
    end
    configpath = joinpath(dir, CONFIG_FILE_NAME)
    if isfile(configpath)
        return parse_config(configpath)
    end
    return find_config_file(dir)
end

function isignored(path, options)
    ignore = get(options, "ignore", String[])
    return any(x -> occursin(Glob.FilenameMatch("*$x"), path), ignore)
end

include("app.jl")

@setup_workload let
    dir = joinpath(@__DIR__, "..")
    sandbox_dir = joinpath(tempdir(), join(rand('a':'z', 24)))
    mkdir(sandbox_dir)
    cp(dir, sandbox_dir; force = true)
    chmod(sandbox_dir, 0o777; recursive = true)
    str = """
    true
    false
    10.0
    "hello"
    a + b
    a == b == c
    a^10
    !cond
    f(a,b,c)
    @f(a,b,c)
    (a,b,c)
    [a,b,c]
    begin
        a
        b
    end
    quote
        a
        b
    end
    :(a+b+c+d)
    """

    @compile_workload begin
        format(sandbox_dir)
        for style in [DefaultStyle(), BlueStyle(), SciMLStyle(), YASStyle(), MinimalStyle()]
            format_text(str, style)
        end

        redirect_stdout(devnull) do
            redirect_stderr(devnull) do
                main(String["--help"])
                main(String["--check", "--verbose", sandbox_dir])
            end
        end
    end
end

end # module JuliaFormatter
