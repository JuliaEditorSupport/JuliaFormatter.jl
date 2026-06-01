# JuliaFormatter.jl

Width-sensitive formatter for Julia code, inspired by gofmt, refmt, black, and prettier.
Built with [`JuliaSyntax.jl`](https://github.com/JuliaLang/JuliaSyntax.jl).

- Provides sane defaults out of the box, with [a number of customisation options](@ref formatting-options).

- Supports [YAS](@ref yas-style), [Blue](@ref blue-style), and [SciML](@ref sciml-style) style guides.

- Admits a [`.JuliaFormatter.toml` configuration file](@ref config) for project-level formatting settings.

- Can be used as [a command-line app](@ref cli).

## Quickstart

Traditionally, JuliaFormatter is invoked from the Julia REPL.
(However, you may well find that [the command-line `jlfmt` app](@ref cli) is more convenient!)

To use JuliaFormatter from the REPL, install with:

```julia
]add JuliaFormatter
```

Then you can do:

```julia
julia> using JuliaFormatter

# Recursively formats all Julia files in the current directory
julia> format(".")

# Formats an individual file
julia> format_file("foo.jl")

# Formats a string
julia> format_text(str)
```
