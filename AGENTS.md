# Running Julia code

- If you have a Julia MCP tool, always run code with that.
  Don't invoke julia from bash as that is very slow.

- Avoid using Julia environments that the user has already set up.
  Create a temporary test environment with `Pkg.activate(; temp=true)`, `Pkg.develop(; path=...)` the current checkout of JuliaFormatter, and add any other packages you need.

- Code changes in the local checkout should be immediately visible without having to reload the session (thanks to Revise.jl).
  If you encounter any issues with this, try restarting the MCP session.

# Tracing JuliaFormatter's output

- Use the `JuliaFormatter.Internal.format_to_stage` function to inspect the output of each stage of the formatting process.
  If `s` is a string containing the code to be formatted, then `format_to_stage(stage, s[, style]; options...)` will give the output of the specified stage, where `stage` is one of:

  - `:cst` gives the CST from JuliaSyntax;
  - `:fst` gives the initial FST that JuliaFormatter constructs from the CST using `pretty()`;
  - `:nest` gives the FST after flattening, alignment, and nesting;
  - `:out` gives the final formatted string;
  - `:print` prints the final formatted string.

# Running tests

- Do not run the full test suite unless explicitly instructed to.
  Only run specific, targeted tests that are relevant to the changes you are making.

- To test whether a string is valid Julia code, you can use `Meta.parse(s)` or `format_to_stage(:cst, s)`. Both throw if the code is invalid.
