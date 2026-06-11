# [Known Issues](@id known-issues)

This page tries to collate a list of things that are known to be broken or otherwise unexpected.

## Importing operators

The following syntax

```julia
import Base: :+
```

is valid on Julia 1.10 and 1.11, but not on Julia 1.9 or 1.12 (the removal of this syntax in Julia 1.12 is [a bugfix in Julia, i.e., an intentional change](https://github.com/JuliaLang/julia/issues/62045)).
JuliaFormatter will refuse to format this code (because JuliaSyntax.jl doesn't parse it).

You should change your code to either of the following, which both format fine:

```julia
import Base: +
import Base: (+)
```

## Insertion of `return`

When using [`always_use_return = true`](@ref options-always-use-return) (or any style that sets that, e.g. BlueStyle), JuliaFormatter will add `return` statements to things that aren't really a meaningful return value:

```@example return
using JuliaFormatter: format_text

s = """
function foo()
    error("oops")
end
"""

format_text(s; always_use_return = true) |> println
```

!!! note "throw"
    Currently, JuliaFormatter special-cases `throw(...)` in that a `return` is not inserted before it. I personally dislike this heuristic because it's not provably *correct*: the cases that are special-cased are not the same as the cases that do not return. I intend to remove it in v3.

This is intentional and doesn't change any semantics (note that even though `error(...)` doesn't evaluate to an actual value, it is still an expression and has a type of `Union{}`, which is [the bottom type](https://en.wikipedia.org/wiki/Bottom_type)).
If you want to avoid this, you can insert a `return nothing` statement at the end of your function:

```@example return
s2 = """
function foo()
    error("oops")
    return nothing  # unreachable
end
"""

format_text(s2; always_use_return = true) |> println
```

## Inline comments

JuliaFormatter is _quite buggy_ with inline comments of the form `#= ... =#`, especially because they aren't thoroughly tested.
For example, sometimes they get inadvertently deleted, or formatting can be non-idempotent when they are present.

If you come across such problems please don't hesitate to [open an issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues), but I wanted to document this because it is specifically known to be a bit of a pain point.
`# ...` comments are likely to be much more reliable.
