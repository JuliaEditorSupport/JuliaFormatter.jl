# JuliaFormatter.jl

[![Documenter: stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/)
[![Documenter: dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaeditorsupport.github.io/JuliaFormatter.jl/dev)
![Build Status](https://github.com/juliaeditorsupport/JuliaFormatter.jl/actions/workflows/ci.yml/badge.svg)

> **If you're having issues with v2 outputs use the latest v1. `add JuliaFormatter@v1` should install 1.0.62**


> I don't have the time to commit large changes regarding v2. JuliaSyntax v1 broke a bunch of things again and it is a large undertaking fix everything needed to upgrade and then also fix previous issues. If you would like to contribute via PRs they would be welcomed.

Width-sensitive formatter for Julia code. Inspired by gofmt, refmt, and black.

![Screencast](https://user-images.githubusercontent.com/1813121/72941091-0b146300-3d68-11ea-9c95-75ec979caf6e.gif)

## Installation

```julia
pkg> add JuliaFormatter
```

## Quick Start

```julia
julia> using JuliaFormatter

# Recursively formats all Julia files in the current directory
julia> format(".")

# Formats an individual file
julia> format_file("foo.jl")

# Formats a string (contents of a Julia file)
julia> format_text(str)
```

Check out [the docs](https://domluna.github.io/JuliaFormatter.jl/stable/) for further description of the formatter and its options.

## Command Line Tool

Starting from version 2.2.0, JuliaFormatter provides a command-line executable `jlfmt`.

To install:

```julia
pkg> app add JuliaFormatter
```

Usage:

```bash
# Format a file and write to stdout
jlfmt src/file.jl

# Format a file in place
jlfmt --inplace src/file.jl

# Check if all files in a directory are already formatted with verbose mode
jlfmt --check -v src/

# Format all files in a directory with multiple threads
jlfmt --threads=6 -- --inplace -v src/

# Show diff without modifying files
jlfmt --diff src/file.jl
```

Run `jlfmt --help` for more options.

Check out [the CLI docs](https://juliaeditorsupport.github.io/JuliaFormatter.jl/dev/cli) for further description of the formatter and its options.

## Github Actions

[Use With GitHub Actions](https://github.com/julia-actions/julia-format)

## Editor Plugins

For integration with other editors:

  - [VSCode](https://github.com/singularitti/vscode-julia-formatter/)
  - [Emacs](https://codeberg.org/FelipeLema/julia-formatter.el)
  - [Vim](https://github.com/kdheepak/JuliaFormatter.vim)
  - [Atom (deprecated)](https://github.com/JunoLab/Atom.jl)
