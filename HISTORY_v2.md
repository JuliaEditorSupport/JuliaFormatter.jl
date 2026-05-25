# v2.4.0

Added a new pre-commit hook which uses the `jlfmt` executable.
To use this, you will need to first install `jlfmt` with

```julia
] app add JuliaFormatter
```

# v2.3.2

Added compatibility with CommonMark@1.

# v2.3.1

Fixed a bug which caused `jlfmt --threads=N` to fail for `N > 1`.

Fixed a bug with alignment of `=` characters in lines with zero-width characters.
