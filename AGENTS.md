# Running Julia code

- If you have a Julia MCP tool, always run code with that.
  Don't invoke julia from bash as that is very slow.

- Avoid using Julia environments that the user has already set up.
  Create a temporary test environment with `Pkg.activate(; temp=true)`, `Pkg.develop(; path=...)` the current checkout of JuliaFormatter, and add any other packages you need.

- Code changes in the local checkout should be immediately visible without having to reload the session (thanks to Revise.jl).

# Tracing JuliaFormatter's output

- Use the `JuliaFormatter.Internal.format_to_stage` function to inspect the output of each stage of the formatting process.
  If `s` is a string containing the code to be formatted, then:

  - `format_to_stage(:cst, s[, style]; options...)` gives the CST from JuliaSyntax;
  - `format_to_stage(:fst, s[, style]; options...)` gives the initial FST that JuliaFormatter constructs from the CST using `pretty()`.
