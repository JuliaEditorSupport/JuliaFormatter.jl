# JuliaFormatter.jl

Width-sensitive formatter for Julia code, inspired by gofmt, refmt, black, and prettier.
Built with [`JuliaSyntax.jl`](https://github.com/JuliaLang/JuliaSyntax.jl).

- Provides sane defaults out of the box, with [a number of customisation options](@ref formatting-options).

- Supports [YAS](@ref yas-style), [Blue](@ref blue-style), and [SciML](@ref sciml-style) style guides.

- Admits a [`.JuliaFormatter.toml` configuration file](@ref config) for project-level formatting settings.

- Can be used as [a command-line app](@ref cli).

![](https://user-images.githubusercontent.com/1813121/72941091-0b146300-3d68-11ea-9c95-75ec979caf6e.gif)

## Installation

```julia
]add JuliaFormatter
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
