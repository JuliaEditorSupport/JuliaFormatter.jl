# Skipping Formatting

By default formatting is always on but can be toggled with the following comments:

```julia
#! format: off
# Turns off formatting from this point onwards
...

#! format: on
# Turns formatting back on from this point onwards
```

These can be used throughout a file, or, for an entire file not be formatted add "format: off" at the top of the file:

```julia
#! format: off
#
# It doesn't actually matter if it's on
# the first line of the line but anything
# onwards will NOT be formatted.

module Foo
...
end
```

!!! note "Ignoring files"
    You can also ignore entire files and directories by supplying
    [the `ignore` option](@ref config-ignore) in `.JuliaFormatter.toml`.

Note the formatter expects `#! format: on` and `#! format: off` to be on its own line and the whitespace to be an exact match.
