using TOML: TOML

const CONFIG_FILE_NAME = ".JuliaFormatter.toml"

"""
    Configuration

A `Configuration` represents a collection of both formatting options and file options.

`Configuration`s can be constructed from:

- default values.
- keyword arguments passed to `format()`;
- a `$CONFIG_FILE_NAME` configuration file; or

The CLI app can in principle also use this but it hasn't been wired up yet.
"""
struct Configuration
    options::Options{_Unset}
    # In `Configuration`, we use `nothing` to indicate that these fields were not specified.
    # We could in principle use the same `_Unset` trick as in Options, but that feels a bit
    # over-engineered for five fields.
    style::Union{Nothing,AbstractStyle}
    ignore::Union{Nothing,Vector{String}}
    verbose::Union{Nothing,Bool}
    overwrite::Union{Nothing,Bool}
    format_markdown::Union{Nothing,Bool}
end

function Configuration()
    return Configuration(Options{_Unset}(), DefaultStyle(), [], false, true, false)
end

function configuration_from_kwargs(; style=nothing, ignore=nothing, verbose=nothing, overwrite=nothing, format_markdown=nothing, formatting_options...)
    options = Options{_Unset}(; formatting_options...)
    return Configuration(options, style, ignore, verbose, overwrite, format_markdown)
end

function configuration_from_file(tomlfile::AbstractString)
    config_dict::Dict{String,Any} = TOML.parsefile(tomlfile)

    options_kws = Dict{Symbol,Any}()
    for field in fieldnames(Options)
        val = get(config_dict, string(field), _Unset())
        # TOML doesn't have a null value, so we use the string "nothing" to represent
        # it.
        if val == "nothing"
            val = nothing
        end
        options_kws[field] = val
    end
    options = Options{_Unset}(; options_kws...)

    style = get(config_dict, "style", nothing)
    if style !== nothing
        if haskey(STYLE_MAP, style)
            style = STYLE_MAP[style]
        else
            error("Unknown style: $style. Valid styles are: $(keys(STYLE_MAP))")
        end
    end

    ignore = get(config_dict, "ignore", nothing)
    verbose = get(config_dict, "verbose", nothing)
    overwrite = get(config_dict, "overwrite", nothing)
    format_markdown = get(config_dict, "format_markdown", nothing)
    return Configuration(options, style, ignore, verbose, overwrite, format_markdown)
end

"""
    find_config_file(path::AbstractString)::Union{Nothing,AbstractString}

Search for a `.JuliaFormatter.toml` configuration file in the directory of `path` and its
ancestors. Returns the path to the configuration file if found, or `nothing` if not found.
"""
function find_config_file(path::AbstractString)::Union{Nothing,AbstractString}
    # Convert to absolute path
    path = realpath(path)
    # dirname(path) == path indicates filesystem root.
    while dirname(path) != path
        maybe_config_path = joinpath(path, CONFIG_FILE_NAME)
        if isfile(maybe_config_path)
            return maybe_config_path
        end
        path = dirname(path)
    end
    # Failed to find
    return nothing
end

"""
    isignored(path::AbstractString, config::Configuration)::Bool

Determine if the given `path` should be ignored based on the ignore patterns in the
`config`. Returns `true` if the path matches any of the ignore patterns.
"""
function isignored(path, config::Configuration)
    @assert config.ignore !== nothing "Configuration ignore patterns are not set. This is a bug in JuliaFormatter."
    # Glob.jl only matches paths that have '/' as the pathsep, so we need to normalise to
    # that before matching, otherwise ignore patterns won't work on Windows
    path_posix = replace(path, Base.Filesystem.path_separator => "/")
    return any(x -> occursin(Glob.FilenameMatch("*$x"), path_posix), config.ignore)
end

"""
    merge_config(config1::Configuration, config2::Configuration)::Configuration

Merge two sources of configurations.
"""
function merge_config(config1::Configuration, config2::Configuration)::Configuration
    merged_options = merge_options(config1.options, config2.options)
    merged_style = config2.style === nothing ? config1.style : config2.style
    merged_ignore = config2.ignore === nothing ? config1.ignore : config2.ignore
    merged_verbose = config2.verbose === nothing ? config1.verbose : config2.verbose
    merged_overwrite = config2.overwrite === nothing ? config1.overwrite : config2.overwrite
    merged_format_markdown = config2.format_markdown === nothing ? config1.format_markdown : config2.format_markdown
    return Configuration(
        merged_options,
        merged_style,
        merged_ignore,
        merged_verbose,
        merged_overwrite,
        merged_format_markdown,
    )
end

function get_formatting_options(config::Configuration)::Options
    config.style === nothing && error("Configuration style is not set. This is a bug in JuliaFormatter.")
    return merge_options(options(config.style), config.options)
end
