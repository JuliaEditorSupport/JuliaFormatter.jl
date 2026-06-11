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
    throw("oops")
end
"""

format_text(s; always_use_return = true) |> println
```

This is intentional and doesn't change either the semantics (`throw()` won't return anything) or type inference.
If you want to avoid this, you can insert a `return nothing` statement at the end of your function:

```@example return
s2 = """
function foo()
    throw("oops")
    return nothing  # unreachable
end
"""

format_text(s2; always_use_return = true) |> println
```
