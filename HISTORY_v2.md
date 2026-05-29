# v2.5.1

Fix some formatting regressions introduced in v2.5.0.
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
