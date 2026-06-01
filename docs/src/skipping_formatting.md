# Skipping Formatting

By default, formatting is applied to all lines of a file, but this can be toggled with the following comments:

```julia
#! format: off
# Turns off formatting from this point onwards
...

#! format: on
# Turns formatting back on from this point onwards
```

To make an entire file not be formatted, add `#! format: off` at the top of the file:

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

Note that the formatter expects `#! format: on` and `#! format: off` to be on its own line, and the whitespace to be an exact match.

!!! note "Ignoring files"
    You can also ignore entire files and directories by supplying [the `ignore` option](@ref options-ignore) in `.JuliaFormatter.toml`.

### Preventing indentation

Sometimes you may wish for a block of code to not be indented.
You can achieve this with a more targeted approach of `#! format: noindent`.

```julia
begin
@muladd begin
    #! format: noindent
    a = 10
    b = 20
    begin
       # another indent
        z = 33
    end

    a * b
end
        end
```

is formatted to


```julia
begin
    @muladd begin
    #! format: noindent
    a = 10
    b = 20
    begin
        # another indent
        z = 33
    end

    a * b
    end
end
```

Notice the contents of `@muladd begin` are not indented beyond their pre-existing indentation.
Without the `#! format: noindent` comment, the contents of `@muladd begin` would be indented at an additional level:

```julia
begin
    @muladd begin
        a = 10
        b = 20
        begin
            # another indent
            z = 33
        end

        a * b
    end
end
```

`#! format: noindent` can also be nested.
