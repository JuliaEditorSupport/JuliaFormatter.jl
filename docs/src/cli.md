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

Run `jlfmt --help` for a complete list:

```@repl
using JuliaFormatter # hide
JuliaFormatter.main(["--help"]); # hide
```

## Configuration Files

`jlfmt` searches for [`.JuliaFormatter.toml` configuration](@ref config) files starting from each input file's directory and walking up the directory tree.

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
