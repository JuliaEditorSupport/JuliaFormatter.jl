# [File Options](@id file-options)

These options can be specified either in a [`.JuliaFormatter.toml` configuration file](@ref config), or as extra arguments to the [`jlfmt` command-line tool](@ref cli).

On top of these, you can also add all [formatting options](@ref formatting-options) to the configuration file or CLI arguments.

## [`style`](@id options-style)

To choose another base style, such as `YASStyle` you can write this in your configuration like so:

```toml
style = "yas"
```

Style choices are:

- `"default"` (default choice if nothing is specified)
- `"yas"`
- `"blue"`
- `"sciml"`
- `"minimal"`

## [`overwrite`](@id options-overwrite)

Default: `true`

If `true` the file will be reformatted in-place, overwriting the existing file; if it is `false`, the formatted version will not be written anywhere.

## [`verbose`](@id options-verbose)

Default: `false`

If `true`, extra details about the formatting process are printed to `stdout`.

## [`format_markdown`](@id options-format-markdown)

Default: `false`

If `true`, Markdown files are also formatted.
Julia code blocks will be formatted, in addition to the Markdown being normalized.

## [`ignore`](@id options-ignore)

An array of paths to files and directories (with possible Glob wildcards) which will not be formatted.

For example, if `.JuliaFormatter.toml` contains

```toml
ignore = ["file.jl", "directory", "file_*.jl"]
```

then JuliaFormatter will skip over all of these files:

- `file.jl`
- `directory/something.jl`
- `other_directory/file.jl`
- `file_1.jl`
- `other_directory/file_name.jl`

