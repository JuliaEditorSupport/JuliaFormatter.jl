module ArgParse

import ..JuliaFormatter:
    AbstractStyle, DefaultStyle, BlueStyle, SciMLStyle, YASStyle, MinimalStyle

struct ParseArgsError <: Exception
    message::String
end

# Enums that are attached to OptSpec that are used purely for help text rendering.
@enum OptKind FlagKind OptionKind NegatableFlagKind
@enum OptGroup GeneralGroup FormattingGroup DeprecatedGroup

"""
    OptionSpec

A declarative (ish) specification of a command-line option, designed to mimic
Haskell's `optparse-applicative`.

These, combined with the actual arguments, are parsed into a `Dict{Symbol,Any}`.
"""
struct OptSpec
    "The prefixes that trigger this option, e.g. `-c` or `--check`."
    names::Vector{String}
    "Help text"
    help::String
    "The key in the result dictionary where the parsed value will be stored."
    dest::Symbol
    "A function that consumes the option from the argument list. Takes the remaining
    arguments (starting with the matched token) and returns `(value, rest)`."
    consume::Function
    "If true, values are collected into a vector instead of overwriting."
    multi::Bool
    "What kind of option this is, for help text rendering."
    kind::OptKind
    "Group for help text output. Options with the same group are displayed together."
    group::OptGroup
    "Placeholder for the value in help text, e.g. `<n>` or `<file>`."
    metavar::String
end

# --- Combinators for building specs ---

# Generic value parser.
function parse_value(::Type{T}, raw::AbstractString, option_name::String) where {T}
    T <: AbstractString && return raw
    try
        return Base.parse(T, raw)
    catch
        throw(ParseArgsError("invalid value `$raw` for option `$option_name`"))
    end
end

# Parse (x, y) where x <= y. Used in --lines.
function parse_value(::Type{Tuple{Int,Int}}, raw::AbstractString, option_name::String)
    m = match(r"^(\d+):(\d+)$", raw)
    if m === nothing
        throw(
            ParseArgsError(
                "invalid value `$raw` for option `$option_name` (expected `<start>:<stop>` with 1-based line numbers)",
            ),
        )
    end
    start_line = Base.parse(Int, m.captures[1]::AbstractString)
    stop_line = Base.parse(Int, m.captures[2]::AbstractString)
    if start_line > stop_line
        throw(
            ParseArgsError(
                "invalid value `$raw` for option `$option_name`: start is greater than stop",
            ),
        )
    end
    return (start_line, stop_line)
end

# Parse styles.
const STYLE_MAP = Dict{String,AbstractStyle}(
    "default" => DefaultStyle(),
    "yas" => YASStyle(),
    "blue" => BlueStyle(),
    "sciml" => SciMLStyle(),
    "minimal" => MinimalStyle(),
)
function parse_value(::Type{AbstractStyle}, raw::AbstractString, option_name::String)
    style = get(STYLE_MAP, raw, nothing)
    if style === nothing
        valid = join(sort!(collect(keys(STYLE_MAP))), ", ")
        throw(
            ParseArgsError(
                "invalid value `$raw` for option `$option_name` (expected one of: $valid)",
            ),
        )
    end
    return style
end

# Flag: `--check` / `-c` sets dest to true.
function flag(names; dest::Symbol, help::String, group::OptGroup = GeneralGroup)
    OptSpec(
        names,
        help,
        dest,
        argv -> (true, @view argv[2:end]),
        false,
        FlagKind,
        group,
        "",
    )
end

# Negatable flag (DEPRECATED): `--always_for_in` / `--no-always_for_in`.
# Deprecated in favour of `--always-for-in=true` / `--always-for-in=false`.
function negatable_flag(name::String; dest::Symbol)
    pos = "--$name"
    neg = "--no-$name"
    OptSpec(
        [pos, neg],
        "",
        dest,
        argv -> (argv[1] == pos, @view argv[2:end]),
        false,
        NegatableFlagKind,
        DeprecatedGroup,
        "",
    )
end

# Option with a value: `--margin=92` or `--margin 92` or `-o file`.
# `names` is a vector of names, e.g. `["-o", "--output"]`.
_metavar(::Type{Int}) = "<n>"
_metavar(::Type{Bool}) = "true|false"
_metavar(::Type{String}) = "<value>"
_metavar(::Type) = "<value>"

function option(
    names;
    dest::Symbol,
    type::Type,
    help::String,
    multi::Bool = false,
    group::OptGroup = GeneralGroup,
    metavar::String = _metavar(type),
)
    OptSpec(
        names,
        help,
        dest,
        argv -> begin
            x = argv[1]
            eq = findfirst('=', x)
            if eq !== nothing
                raw = x[(eq+1):end]
                (parse_value(type, raw, x), @view argv[2:end])
            else
                length(argv) < 2 && throw(ParseArgsError("expected value after `$x`"))
                (parse_value(type, argv[2], x), @view argv[3:end])
            end
        end,
        multi,
        OptionKind,
        group,
        metavar,
    )
end

option(name::String; kw...) = option([name]; kw...)

# --- The parser: a list of specs ---

struct ArgParser
    specs::Vector{OptSpec}
    # Map from option name to index in `specs` for fast lookup.
    index::Dict{String,Int}

    function ArgParser(specs::OptSpec...)
        index = Dict{String,Int}()
        for (i, spec) in enumerate(specs)
            for name in spec.names
                haskey(index, name) && throw(ArgumentError("duplicate option name `$name`"))
                index[name] = i
            end
        end
        new(collect(specs), index)
    end
end

function maybe_get_spec(parser::ArgParser, token::String)::Union{OptSpec,Nothing}
    name = first(split(token, '='; limit = 2))
    i = get(parser.index, name, nothing)
    return if i === nothing
        nothing
    else
        parser.specs[i]
    end
end

function parse_raw(parser::ArgParser, argv::Vector{String})
    positional_args = String[]
    options = Dict{Symbol,Any}()

    remaining = @view argv[:]
    while !isempty(remaining)
        token = first(remaining)
        spec = maybe_get_spec(parser, token)
        if spec !== nothing
            if spec.group == DeprecatedGroup
                @warn """Options with underscores (e.g. `--always_for_in`) are deprecated \
                    and will be removed in a future version. \
                    Use hyphens instead (e.g. `--always-for-in=true`).""" maxlog = 1
            end
            value, remaining = spec.consume(remaining)
            if spec.multi
                # append
                if !haskey(options, spec.dest)
                    options[spec.dest] = []
                end
                push!(options[spec.dest], value)
            else
                # overwrite
                options[spec.dest] = value
            end
        else
            push!(positional_args, token)
            remaining = @view remaining[2:end]
        end
    end

    options[:paths] = positional_args
    return options
end

# --- Typed result ---

@enum OutputMode StdoutMode InplaceMode CheckMode

Base.@kwdef struct ParsedArgs
    help::Bool = false
    version::Bool = false
    mode::OutputMode = StdoutMode
    diff::Bool = false
    verbose::Bool = false
    format_markdown::Bool = false
    config_priority::Bool = false
    outputfile::Union{String,Nothing} = nothing
    stdin_filename::String = "stdin"
    config_dir::String = ""
    ignore_patterns::Vector{String} = String[]
    line_ranges::Vector{Tuple{Int,Int}} = Tuple{Int,Int}[]
    format_options::Dict{Symbol,Any} = Dict{Symbol,Any}()
    paths::Vector{String} = String[]
end

# All format option keys — these are collected from the raw dict into format_options.
const FORMAT_OPTION_KEYS = Set{Symbol}([
    :style,
    :indent,
    :margin,
    :sciml_margin_overrun,
    :normalize_line_endings,
    :always_for_in,
    :whitespace_typedefs,
    :remove_extra_newlines,
    :import_to_using,
    :pipe_to_function_call,
    :short_to_long_function_def,
    :always_use_return,
    :whitespace_in_kwargs,
    :format_docstrings,
    :align_struct_field,
    :align_assignment,
    :align_conditional,
    :align_pair_arrow,
    :trailing_comma,
    :trailing_zero,
    :v2_stable_multiline_strings,
    :conditional_to_if,
])

const PARSER = ArgParser(
    flag(["-h", "--help"]; dest = :help, help = "Print this message."),
    flag(["--version"]; dest = :version, help = "Print version information."),
    flag(["-c", "--check"]; dest = :check, help = "Check formatting without writing."),
    flag(["-i", "--inplace"]; dest = :inplace, help = "Format files in place."),
    flag(["-d", "--diff"]; dest = :diff, help = "Print diff to stderr."),
    option(
        ["-o", "--output"];
        dest = :outputfile,
        type = String,
        metavar = "<file>",
        help = "File to write formatted output to.",
    ),
    flag(["-v", "--verbose"]; dest = :verbose, help = "Enable verbose output."),
    flag(
        ["--format_markdown"];
        dest = :format_markdown,
        help = "Also format code blocks in Markdown files.",
    ),
    flag(
        ["--prioritize-config-file"];
        dest = :config_priority,
        help = "Prioritize config file options over command-line options.",
    ),
    option(
        "--stdin-filename";
        dest = :stdin_filename,
        type = String,
        metavar = "<name>",
        help = "Assumed filename when formatting from stdin.",
    ),
    option(
        "--config-dir";
        dest = :config_dir,
        type = String,
        metavar = "<dir>",
        help = "Directory path for .JuliaFormatter.toml config lookup.",
    ),
    option(
        "--ignore";
        dest = :ignore,
        type = String,
        multi = true,
        metavar = "<pattern>",
        help = "Ignore files matching the given pattern. Can be repeated.",
    ),
    option(
        "--lines";
        dest = :lines,
        type = Tuple{Int,Int},
        multi = true,
        metavar = "<start:stop>",
        help = "Only format the given range of lines. Can be repeated.",
    ),
    # --- Formatting options ---
    option(
        "--style";
        dest = :style,
        type = AbstractStyle,
        metavar = "default|blue|sciml|yas|minimal",
        help = "Formatting style.",
        group = FormattingGroup,
    ),
    option(
        "--align-assignment";
        dest = :align_assignment,
        type = Bool,
        help = "Align assignment operators.",
        group = FormattingGroup,
    ),
    option(
        "--align-conditional";
        dest = :align_conditional,
        type = Bool,
        help = "Align conditional operators.",
        group = FormattingGroup,
    ),
    option(
        "--align-pair-arrow";
        dest = :align_pair_arrow,
        type = Bool,
        help = "Align pair arrows (=>).",
        group = FormattingGroup,
    ),
    option(
        "--align-struct-field";
        dest = :align_struct_field,
        type = Bool,
        help = "Align struct field type annotations.",
        group = FormattingGroup,
    ),
    option(
        "--always-for-in";
        dest = :always_for_in,
        type = Bool,
        help = "Normalise `in` to/from `=` in for loops.",
        group = FormattingGroup,
    ),
    option(
        "--always-use-return";
        dest = :always_use_return,
        type = Bool,
        help = "Add explicit 'return' statements to function definitions.",
        group = FormattingGroup,
    ),
    option(
        "--conditional-to-if";
        dest = :conditional_to_if,
        type = Bool,
        help = "Convert ternary expressions to if/else blocks when over margin.",
        group = FormattingGroup,
    ),
    option(
        "--format-docstrings";
        dest = :format_docstrings,
        type = Bool,
        help = "Format docstrings.",
        group = FormattingGroup,
    ),
    option(
        "--import-to-using";
        dest = :import_to_using,
        type = Bool,
        help = "Convert 'import' to 'using'.",
        group = FormattingGroup,
    ),
    option(
        "--indent";
        dest = :indent,
        type = Int,
        help = "Indentation width.",
        group = FormattingGroup,
    ),
    option(
        "--margin";
        dest = :margin,
        type = Int,
        help = "Maximum line width.",
        group = FormattingGroup,
    ),
    option(
        "--normalize-line-endings";
        dest = :normalize_line_endings,
        type = String,
        metavar = "auto|unix|windows",
        help = "Normalize line endings.",
        group = FormattingGroup,
    ),
    option(
        "--pipe-to-function-call";
        dest = :pipe_to_function_call,
        type = Bool,
        help = "Convert pipe operator to function calls.",
        group = FormattingGroup,
    ),
    option(
        "--remove-extra-newlines";
        dest = :remove_extra_newlines,
        type = Bool,
        help = "Remove extra newlines.",
        group = FormattingGroup,
    ),
    option(
        "--sciml-margin-overrun";
        dest = :sciml_margin_overrun,
        type = Int,
        help = "Additional columns SciMLStyle may use.",
        group = FormattingGroup,
    ),
    option(
        "--short-to-long-function-def";
        dest = :short_to_long_function_def,
        type = Bool,
        help = "Convert short function definitions to long form.",
        group = FormattingGroup,
    ),
    option(
        "--trailing-comma";
        dest = :trailing_comma,
        type = Bool,
        help = "Add trailing commas.",
        group = FormattingGroup,
    ),
    option(
        "--trailing-zero";
        dest = :trailing_zero,
        type = Bool,
        help = "Add trailing zeros to floats.",
        group = FormattingGroup,
    ),
    option(
        "--v2-stable-multiline-strings";
        dest = :v2_stable_multiline_strings,
        type = Bool,
        help = "Use stable multiline string length calculation.",
        group = FormattingGroup,
    ),
    option(
        "--whitespace-in-kwargs";
        dest = :whitespace_in_kwargs,
        type = Bool,
        help = "Add whitespace in keyword arguments.",
        group = FormattingGroup,
    ),
    option(
        "--whitespace-typedefs";
        dest = :whitespace_typedefs,
        type = Bool,
        help = "Add whitespace around '::' in type definitions.",
        group = FormattingGroup,
    ),
    # Deprecated options (for backward compatibility)
    option(
        "--sciml_margin_overrun";
        dest = :sciml_margin_overrun,
        type = Int,
        help = "",
        group = DeprecatedGroup,
    ),
    option(
        "--normalize_line_endings";
        dest = :normalize_line_endings,
        type = String,
        help = "",
        group = DeprecatedGroup,
    ),
    negatable_flag("always_for_in"; dest = :always_for_in),
    negatable_flag("whitespace_typedefs"; dest = :whitespace_typedefs),
    negatable_flag("remove_extra_newlines"; dest = :remove_extra_newlines),
    negatable_flag("import_to_using"; dest = :import_to_using),
    negatable_flag("pipe_to_function_call"; dest = :pipe_to_function_call),
    negatable_flag("short_to_long_function_def"; dest = :short_to_long_function_def),
    negatable_flag("always_use_return"; dest = :always_use_return),
    negatable_flag("whitespace_in_kwargs"; dest = :whitespace_in_kwargs),
    negatable_flag("format_docstrings"; dest = :format_docstrings),
    negatable_flag("align_struct_field"; dest = :align_struct_field),
    negatable_flag("align_assignment"; dest = :align_assignment),
    negatable_flag("align_conditional"; dest = :align_conditional),
    negatable_flag("align_pair_arrow"; dest = :align_pair_arrow),
    negatable_flag("trailing_comma"; dest = :trailing_comma),
    negatable_flag("trailing_zero"; dest = :trailing_zero),
    negatable_flag("v2_stable_multiline_strings"; dest = :v2_stable_multiline_strings),
    negatable_flag("conditional_to_if"; dest = :conditional_to_if),
)

function print_help(parser::ArgParser; io::IO = stdout)
    function section(title)
        printstyled(io, title; bold = true)
        println(io)
    end

    section("NAME")
    println(io, "       jlfmt - An opinionated code formatter for Julia\n")

    section("SYNOPSIS")
    println(
        io,
        """
       jlfmt [<julia_options> --] [<options>] <path>...
       jlfmt [<julia_options> --] [<options>] -
       ... | jlfmt [<julia_options> --] [<options>]

       where <julia_options> are options passed to the Julia
       interpreter (e.g. --threads=auto), and <options> are
       options for JuliaFormatter.
""",
    )

    section("DESCRIPTION")
    println(
        io,
        """
       `jlfmt` formats Julia source code using JuliaFormatter.jl.
       This tool can also be invoked as `julia -m JuliaFormatter`.
""",
    )

    section("OPTIONS")
    println(
        io,
        """
       <path>...
           Input path(s) (files and/or directories) to process. For directories,
           all files (recursively) with the '*.jl' suffix are used as input files
           (also '*.md', '*.jmd', '*.qmd' if --format-markdown is specified).
           If no path is given, or if path is `-`, input is read from stdin.
""",
    )

    for group in instances(OptGroup)
        group == DeprecatedGroup && continue
        if group == FormattingGroup
            section("FORMATTING OPTIONS")
            println(
                io,
                """
           These options control the formatting style. They can also be set in
           a `.JuliaFormatter.toml` config file.

           Note that options are merged from the config file and command-line
           arguments. If the same option is specified both a config file and
           command-line options are specified, the CLI arguments take priority
           by default. With `--prioritize-config-file`, the config file takes
           priority instead.

           If the same option is specified multiple times on the command line,
           the last value is used.
    """,
            )
        end
        for spec in parser.specs
            spec.group != group && continue
            label = if spec.kind == FlagKind
                join(spec.names, ", ")
            elseif spec.kind == OptionKind
                m = spec.metavar
                join([startswith(n, "--") ? "$n=$m" : "$n $m" for n in spec.names], ", ")
            else
                join(spec.names, " / ")
            end
            println(io, "       ", label)
            println(io, "           ", spec.help, "\n")
        end
    end

    section("EXAMPLES")
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

       Format only lines 1-10 and 42-47 of a file:
           jlfmt --lines=1:10 --lines=42:47 src/file.jl

       Check if all files in a directory are formatted with multiple threads:
           jlfmt --threads=4 -- --check src/

       Show diff for formatting with 2-space indentations:
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
           echo 'for i=1:10; end' | jlfmt --always-for-in=true
""",
    )
    return
end

function parse_args(argv::Vector{String})::ParsedArgs
    raw = parse_raw(PARSER, argv)

    # --- Output mode (mutually exclusive) ---
    has_check = get(raw, :check, false)
    has_inplace = get(raw, :inplace, false)
    has_output = haskey(raw, :outputfile)
    if has_check && has_inplace
        throw(ParseArgsError("options `--check` and `--inplace` are mutually exclusive"))
    end
    if has_inplace && has_output
        throw(ParseArgsError("options `--inplace` and `--output` are mutually exclusive"))
    end
    if has_check && has_output
        throw(ParseArgsError("options `--check` and `--output` are mutually exclusive"))
    end
    mode = if has_check
        CheckMode
    elseif has_inplace
        InplaceMode
    else
        StdoutMode
    end

    # --- Collect format options ---
    format_options = Dict{Symbol,Any}()
    for key in FORMAT_OPTION_KEYS
        if haskey(raw, key)
            format_options[key] = raw[key]
        end
    end

    return ParsedArgs(;
        help = get(raw, :help, false),
        version = get(raw, :version, false),
        mode,
        diff = get(raw, :diff, false),
        verbose = get(raw, :verbose, false),
        format_markdown = get(raw, :format_markdown, false),
        config_priority = get(raw, :config_priority, false),
        outputfile = get(raw, :outputfile, nothing),
        stdin_filename = get(raw, :stdin_filename, "stdin"),
        config_dir = get(raw, :config_dir, ""),
        ignore_patterns = get(raw, :ignore, String[]),
        line_ranges = get(raw, :lines, Tuple{Int,Int}[]),
        format_options,
        paths = raw[:paths],
    )
end

end # module
