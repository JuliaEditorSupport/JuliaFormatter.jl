# v2.5.4

Fixed a bug where `jlfmt` would not use the style set in a `.JuliaFormatter.toml` configuration file (unless `--prioritize-config-file` was specified) (#951, #1021).

# v2.5.3

Fixed a bug where postfix operators (e.g. transpose) were not being recognised as unary operators, causing formatting to output unparseable code in some circumstances (#1011).

Improved consistency when parenthesising the value of a keyword argument with `whitespace_in_kwargs=false`, e.g., `(; x=-pi/2)` is now formatted as `(; x=(-pi/2))` (#1011).

# v2.5.2

Fixed a bug where, under SciML style, indentations of bracketed expressions on the RHS of assignments were being removed for anything on the second line onwards (#935, #1006).

# v2.5.1

Fix some formatting regressions introduced in v2.5.0 (#1002, #996).
In particular, this version:

- no longer aggressively adds spaces around `x=>y` and `x->y` (unless spaces are already present).
  This matches the behaviour of other operators e.g. `x+y`.
- no longer adds spaces around assignments in square brackets, for example `a[b=1]` is now left unchanged, rather than being changed to `a[b = 1]`.
- no longer adds parentheses around field access in ranges, for example `[1:a.b]` is now left unchanged, rather than being changed to `[1:(a.b)]`.

Some of these may be configurable in the future.

# v2.5.0

Added compatibility with JuliaSyntax@1.

# v2.4.0

Added the `--threads=auto` option to the old `julia-formatter` pre-commit hook, which should speed up invocations of JuliaFormatter.

Added a new pre-commit hook which uses the `jlfmt` executable.
To use this, you will need to first install `jlfmt` with

```julia
] app add JuliaFormatter
```

Please see [the docs](https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/integrations/) for more information.

# v2.3.3

Fixed a bug with alignment of multiline strings when the first line contains characters whose display width is not equal to the number of bytes.

# v2.3.2

Added compatibility with CommonMark@1.

# v2.3.1

Fixed a bug which caused `jlfmt --threads=N` to fail for `N > 1`.

Fixed a bug with alignment of `=` characters in lines with zero-width characters.
