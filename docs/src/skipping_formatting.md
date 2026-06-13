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

## Preventing indentation

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

## One-off range formatting

Sometimes it is quite useful to only format specific ranges of a file.
This situation can occur e.g. when highlighting a block of code in an editor and formatting only that block.
(Indeed, both LanguageServer.jl and JETLS.jl support this feature.)

It is also useful for minimising diffs: by formatting only the lines that have been newly changed, you can avoid introducing formatting-only diffs in other parts of a file.

Since version 2.7, JuliaFormatter allows you to do this with the `lines` keyword argument in `format_text(...; lines=[(start_line, end_line)], ...)`.
Multiple ranges can be specified; each range must be a tuple of two (1-indexed) integers representing the start and end line of the range to format.

```@example lines
s = """
f(a      , g(b      ,
    h(  12  ),
))"""

# Format only line 2.
using JuliaFormatter
format_text(s; lines=[(2, 2)]) |> println
```

The second line (`h(12)`) is now formatted, but the extra spaces in the first line have not been collapsed.

With the `jlfmt` CLI, you can specify `--lines=2:2` to achieve the same effect.

Note, however, that this works best when the lines to be formatted are a self-contained block of code.
This is because formatting is context-sensitive: it's not possible to format a single line in isolation without considering where it occurs!

This can sometimes lead to odd results, and indeed the example above was chosen to showcase this.
**In general, formatting of partial expressions is performed only on a best-effort basis.**
For example:

```@example lines
# Format only line 2, but with a smaller margin.
format_text(s; lines=[(2, 2)], margin=10) |> println
```

Here, the formatter decided to indent the call `h(12)` by eight spaces, even though based on its position in the file it should have been indented by only four spaces.
Furthermore, as a result of this increased indentation, the formatter also decided to break up `h(12)` into multiple lines, even though `h(12),` with a four-space indent would have fit within the margin.

To understand why, we need to look at what would happen if *all* the text were to be formatted:

```@example lines
format_text(s; margin=10) |> println
```

Because of the small margin, JuliaFormatter decided to break the calls to `f` and `g`, meaning that `h(12)` would now get two levels of indentation.
When formatting only line 2, however, you don't see the changes to the surrounding code: the only visible change is that of `h(12)`.

## A note about other special comments

Note that any comment that begins with `#! __JuliaFormatter` is reserved for internal use.
For example, the option to format only specific lines of a file uses such marker comments.
If you have one of these in your source code, unexpected results may occur.

It is very unlikely that your source code will inadvertently include such a comment, but this is documented here for completeness!
