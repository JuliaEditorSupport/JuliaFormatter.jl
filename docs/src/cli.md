# [Command Line Interface](@id cli)

JuliaFormatter provides a command-line executable `jlfmt` for formatting Julia source code.
This is a [Pkg app](https://pkgdocs.julialang.org/v1/apps/), and therefore requires Julia v1.12 or later.

## Installation

The app can be installed using Julia's app manager:

```julia
# Install the latest available version
import Pkg; Pkg.Apps.add("JuliaFormatter")

# Or a specific version. Note that the version must be >= v2.2.0 since that is
# when the `jlfmt` app was introduced.
import Pkg; Pkg.Apps.add(; name = "JuliaFormatter", version = v"2.3.0")
```

This should create a new binary, called `jlfmt`, inside the Julia depot's `bin` directory (usually `~/.julia/bin`; but you can check with the `DEPOT_PATH` variable in Julia).

Alternatively, you can invoke the app directly without installation:

```bash
julia -m JuliaFormatter [<options>] <path>...
```

!!! note "Runic Compatibility"
    The CLI interface is designed to be compatible with [Runic.jl](https://github.com/fredrikekre/Runic.jl)'s CLI where possible, making it easier to switch between formatters. This includes the repeatable `--lines=<start>:<stop>` option for formatting only specific line ranges (e.g. `jlfmt --lines=1:10 --lines=42:47 src/file.jl`).

## Quick Start

```bash
# Preview formatted output
jlfmt src/file.jl

# Check if files are already formatted with verbose mode
jlfmt --check -v src/

# Format files in-place with multiple threads
jlfmt --threads=6 -- --inplace -v src/

# Show diff without modifying
jlfmt --diff src/file.jl
```

## Options

All formatting options can be passed to `jlfmt` as command-line arguments, e.g. `--indent=2 --always-use-return=true`.

In general the way that CLI options are specified are exactly the same as in `.JuliaFormatter.toml`, with some exceptions:

- When specified on the CLI options are hyphenated (e.g. `--always-use-return`), while in the config file they are underscored (e.g. `always_use_return`).
- To set an option to `nothing`, use `--option=nothing` (in the config file it would have to be `option = "nothing"`).
- To pass a list of strings for `variable_call_indent`, specify the option multiple times on the CLI, e.g. `--variable-call-indent=foo --variable-call-indent=bar` (in the config file it would be `variable_call_indent = ["foo", "bar"]`).

`jlfmt --help` provides a complete list:

```@repl
using JuliaFormatter # hide
JuliaFormatter.main(["--help"]); # hide
```

!!! note "Deprecated options"

    In previous versions of `jlfmt`, some (but not all) Boolean options could be specified using `--option_name` or `--no-option_name` flags (e.g. `--always-use-return` or `--no-always-use-return`).
    This is now deprecated in favor of `--option-name=true` or `--option-name=false` (note hyphens instead of underscores, and the value must be explicitly supplied!), and will be removed in a future release.

## Configuration Files

`jlfmt` searches for [`.JuliaFormatter.toml` configuration](@ref config) files starting from each input file's directory and walking up the directory tree.

A specific directory containing a configuration file can be specified with `--config-dir`:

```bash
# Search upwards from home directory for a config file
jlfmt --config-dir=~ src/file.jl
```

By default, command-line options override configuration file settings:

```bash
# Use indent=2 even if config file specifies indent=4
jlfmt --indent=2 src/file.jl
```

Use `--prioritize-config-file` to make configuration file settings take precedence (might be useful for language server integration):

```bash
jlfmt --prioritize-config-file --indent=2 src/file.jl
```

### Configuration with stdin

When formatting from stdin, no configuration file is used by default.
Use `--config-dir` to specify a directory for configuration file lookup:

```bash
# Format stdin using config from ./src directory
echo 'f(x,y)=x+y' | jlfmt --config-dir=./src

# Useful in editor integrations to respect project config
cat file.jl | jlfmt --config-dir=$(dirname file.jl)
```

The formatter will search for `.JuliaFormatter.toml` in the specified directory and its parent directories, just like it does for regular file inputs.

## Conventions

`jlfmt` follows standard CLI conventions:
- Exit code 0 on success
- Exit code 1 on formatting errors or when `--check` detects unformatted files
- Formatted output to stdout (default) or in-place with `--inplace`
- Error messages to stderr
