module JuliaFormatter

# reduces compilation time
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

using PrecompileTools: @setup_workload, @compile_workload
using JuliaSyntax
using JuliaSyntax: children, span, @K_str, kind, @KSet_str
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

# The Julia syntax version we pass to JuliaSyntax.parseall. This should be kept
# at the latest stable Julia release so that JuliaSyntax can parse all valid
# syntax up to that version.
const SUPPORTED_SYNTAX_VERSION = v"1.12"

abstract type AbstractStyle end
options(style::AbstractStyle) = error("options not implemented for $(typeof(style))")
struct NoopStyle <: AbstractStyle end
getstyle(::NoopStyle) = error("unreachable")
getstyle(s::AbstractStyle) = s.innerstyle isa NoopStyle ? s : s.innerstyle

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

"""
    YASStyle()

Formatting style based on [YASGuide](https://github.com/jrevels/YASGuide) and
[JuliaFormatter#198](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/198).
"""
struct YASStyle <: AbstractStyle
    innerstyle::AbstractStyle
end
YASStyle() = YASStyle(NoopStyle())

"""
    BlueStyle()

Formatting style based on [BlueStyle](https://github.com/invenia/BlueStyle) and
[JuliaFormatter#283](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/283).
"""
struct BlueStyle <: AbstractStyle
    innerstyle::AbstractStyle
end
BlueStyle() = BlueStyle(NoopStyle())

"""
    SciMLStyle()

Formatting style based on [SciMLStyle](https://github.com/SciML/SciMLStyle).
"""
struct SciMLStyle <: AbstractStyle
    innerstyle::AbstractStyle
end
SciMLStyle() = SciMLStyle(NoopStyle())

"""
    MinimalStyle()
"""
struct MinimalStyle <: AbstractStyle
    innerstyle::Union{Nothing,AbstractStyle}
end
MinimalStyle() = MinimalStyle(NoopStyle())

# Used in parsing config files & CLI arguments
const STYLE_MAP = Dict{String,AbstractStyle}(
    "default" => DefaultStyle(),
    "yas" => YASStyle(),
    "blue" => BlueStyle(),
    "sciml" => SciMLStyle(),
    "minimal" => MinimalStyle(),
)

include("document.jl")
include("options.jl")
include("config.jl")
include("state.jl")
include("fst.jl")
include("passes.jl")
include("align.jl")
include("shims.jl")
# TODO(penelopeysm) This is used everywhere. Get rid of it
haschildren(cst::JuliaSyntax.GreenNode) = !JuliaSyntax.is_leaf(cst)

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
include("line_ranges.jl")
include("format.jl")

"""
    JuliaFormatter.format_text(
        text::AbstractString,
        style::AbstractStyle = DefaultStyle();
        lines::Union{Nothing,Vector{Tuple{Int,Int}}} = nothing,
        options...,
    )::String

Formats a string containing Julia code, returning the formatted code as another string. See
[Formatting Options](@ref formatting-options) for details on available options.

## Line-range formatting

Pass `lines` to restrict formatting to a set of line ranges, emitting everything else
verbatim. `lines` is a `Vector{Tuple{Int,Int}}` of inclusive, 1-based `(start, stop)` line
ranges, e.g. `format_text(text; lines = [(1, 10), (42, 47)])`. Overlapping and adjacent
ranges are merged. A range that begins or ends in the middle of a multi-line expression is
formatted on a best-effort basis.

## This function can throw the following errors

- If `text` is not valid Julia code, it will throw a `JuliaSyntax.ParseError`.

- If `opts.always_for_in` is true and `opts.for_in_replacement` is not a valid operator, it
  will throw an `AssertionError`. (NOTE: This check should PROBABLY be moved to the
  `Options` constructor, but it is here for now.)

- If the formatted text is not valid Julia code, it will throw an `InvalidFormattedTextError`.
"""
function format_text(
    text::AbstractString,
    style::AbstractStyle;
    lines::Union{Nothing,Vector{Tuple{Int,Int}}} = nothing,
    kwargs...,
)
    isempty(text) && return text
    opts = merge_options(options(style), Options{_Unset}(; kwargs...))
    # Restrict formatting to the given line ranges (see `line_ranges.jl`). This calls
    # `format_text` without `lines` so the actual formatting doesn't enter an endless loop
    return if lines === nothing
        _format_text(text, style, opts; check_output = true)
    else
        _format_line_ranges(text, style, lines, opts)
    end
end
function format_text(text::AbstractString; style::AbstractStyle = DefaultStyle(), kwargs...)
    return format_text(text, style; kwargs...)
end

"""
    JuliaFormatter.format_file(args...; kwargs...)

!!! warning "Deprecated"
    `format_file` is deprecated. Use [`format`](@ref) instead, which has the same behaviour
    but handles both files and directories.
"""
JuliaFormatter.format_file
Base.@deprecate format_file(args...; kwargs...) format(args...; kwargs...)

"""
    JuliaFormatter.format(
        path,
        style::Union{Nothing,AbstractStyle} = nothing;
        format_markdown::Union{Nothing,Bool} = nothing,
        ignore::Union{Nothing,Vector{String}} = nothing,
        overwrite::Union{Nothing,Bool} = nothing,
        verbose::Union{Nothing,Bool} = nothing,
        formatting_options...,
    )::Bool

Recursively traverse `path` and format all Julia source files inside, or format `path` if it
is itself a Julia source file.

Returns `true` if no files were modified (**NOTE**: this can include the case where
formatting errorred, in which case files will not be modified!), and `false` if any files
were modified.

See [Formatting Options](@ref formatting-options) for details on the formatting options.
Extra keyword arguments are the following. Note that the default values documented here are
only used if they are not specified in either a configuration file or as keyword arguments
to `format()`.

- `format_markdown`: If `true`, additionally formats Julia code blocks inside `.md`, `.jmd`,
  and `.qmd` files. Defaults to `false`.

- `ignore`: A vector of glob patterns to ignore. Default is `String[]`.

- `overwrite`: If `true`, overwrite the original files with the formatted code. Default is
  `true`.

- `verbose`: If `true`, print the names of files being formatted. Default is `false`.

## Errors

`format()` does not throw errors. It is intended for "batch" use where you just want to
format a bunch of files at a go.

Warnings will be issued in lieu of any errors.

## Configuration files

`format()` will automatically search for `$CONFIG_FILE_NAME` configuration files upwards
from the directory of each file being formatted.

Options specified as keyword arguments to `format()` will *override* any options specified
in configuration files. Likewise if the `style` positional argument is specified, it will
override any style specified in configuration files.

### Output

Returns a boolean indicating whether the files were already formatted (`true`) or not
(`false`).
"""
function format(path::AbstractString, style::Union{Nothing,AbstractStyle}; options...)
    # Set up configuration.
    config = Configuration()
    # Merge in .JuliaFormatter.toml configs.
    config_filename = find_config_file(path)
    config = if config_filename !== nothing
        file_config = configuration_from_file(config_filename)
        merge_config(config, file_config)
    else
        config
    end
    # Merge in keyword arguments.
    kw_config = configuration_from_kwargs(; style = style, options...)
    config = merge_config(config, kw_config)

    # If the path is ignored, then the file is considered trivially formatted.
    isignored(path, config) && return true

    return if isdir(path)
        formatted = Threads.Atomic{Bool}(true)
        Threads.@threads for subpath in readdir(path; join = true)
            if !ispath(subpath) || islink(subpath)
                continue
            end
            is_formatted = format(subpath, style; options...)
            Threads.atomic_and!(formatted, is_formatted)
        end
        formatted.value
    elseif isfile(path)
        try
            _format_file(path, config)
        catch err
            if !(err isa InvalidFileError)
                @warn "Failed to format file $path" error = err
            end
            true
        end
    else
        true
    end
end
function format(
    path::AbstractString;
    style::Union{Nothing,AbstractStyle} = nothing,
    options...,
)
    format(path, style; options...)
end
function format(mod::Module, args...; options...)
    path = pkgdir(mod)
    if path === nothing
        throw(ArgumentError("couldn't find a directory of module `$mod`"))
    end
    format(path, args...; options...)
end
function format(paths, style::Union{Nothing,AbstractStyle} = nothing; options...)
    already_formatted = true
    for path in paths
        # Avoid infinite recursion by checking the type of `path`.
        if path isa AbstractString || path isa Module
            already_formatted &= format(path, style; options...)
        else
            throw(ArgumentError("`paths` must be a collection of strings or modules"))
        end
    end
    return already_formatted
end

include("argparse.jl")
include("app.jl")
include("internal/utils.jl")

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
