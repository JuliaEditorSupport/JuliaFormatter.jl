# JuliaFormatter.jl

[![Documenter: stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/)
![Build Status](https://github.com/juliaeditorsupport/JuliaFormatter.jl/actions/workflows/ci.yml/badge.svg)

Width-sensitive formatter for Julia code.
Inspired by gofmt, refmt, and black.

> [!NOTE]
> Recent versions of JuliaFormatter (v2+) still have a number of rough edges!
  I'm putting a lot of effort into fixing these, but if you require absolute stability, please consider pinning the version of JuliaFormatter, and possibly downgrading to v1.
  See also the [Project Status](https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/status) section of the docs for more details.

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

Check out [the docs](https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/) for further description of the formatter and its options.

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

Check out [the CLI docs](https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/cli) for further description of the formatter and its options.
