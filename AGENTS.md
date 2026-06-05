# Running Julia code

- If you have a Julia MCP tool, always run code with that.
  Don't invoke julia from bash as that is very slow.

- Avoid using Julia environments that the user has already set up.
  Create a temporary test environment with `Pkg.activate(; temp=true)`, `Pkg.develop(; path=...)` the current checkout of JuliaFormatter, and add any other packages you need.

- Code changes in the local checkout should be immediately visible without having to reload the session (thanks to Revise.jl).
  If you encounter any issues with this, try restarting the MCP session.

# Tracing JuliaFormatter's output

- Always use the `JuliaFormatter.Internal.format_to_stage` function to inspect the output of each stage of the formatting process.
  If `s` is a string containing the code to be formatted, then `format_to_stage(stage, s[, style]; options...)` will give the output of the specified stage, where `stage` is one of:

  - `:cst` gives the CST from JuliaSyntax;
  - `:fst` gives the initial FST that JuliaFormatter constructs from the CST using `pretty()`;
  - `:nest` gives the FST after flattening, alignment, and nesting;
  - `:out` gives the final formatted string;
  - `:print` prints the final formatted string.

  If `format_text` generates invalid Julia code, it will throw, which is unhelpful for debugging.
  In such cases you should use `format_to_stage(:out, ...)` as that will show you the actual invalid code.

# Running tests

- Do not run the full test suite unless explicitly instructed to.
  Only run specific, targeted tests that are relevant to the changes you are making.

- To test formatting, you should always use `JuliaFormatter.Internal.test_format(input_string, expected_output[, style]; options...)`, which checks that formatting `input_string` produces `expected_output`, and also for idempotence.
  This function prints helpful information if it fails so that you can easily debug the issue.

- To test whether a string is valid Julia code, you can use `Meta.parse(s)` or `format_to_stage(:cst, s)`. Both throw if the code is invalid.

# Comment style

JuliaFormatter is a complex codebase with many moving parts.
Do not assume that other developers will understand terse comments as they do not have the same context as you.
For example, when writing function-level comments, it's useful to illustrate your point with a concrete example of code that is being formatted.

# Avoid hacks

Do not use fragile heuristics or hacks to achieve the desired formatting.
Where possible, you should always try to implement formatting logic at the CST stage (i.e. `pretty()`), because the CST has more precise structural information about the code being run.
