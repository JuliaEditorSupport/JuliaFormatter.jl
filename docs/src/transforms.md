# Syntax Tree Transformations

## `for in` vs. `for =`

By default if the RHS is a range, i.e. `1:10` then `for in` is converted to `for =`. Otherwise `for =` is converted to `for in`. See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/34) for the rationale and further explanation.

Alternative to the above - setting `always_for_in` to `true`, i.e. `format_text(..., always_for_in = true)` will always convert `=` to `in` even if the RHS is a range.
`always_for_in=nothing` will leave the choice of `in` vs `=` up to the user.

## Trailing Commas

If the node is _iterable_, for example a function call or list and is nested, a trailing comma is added to the last argument. The trailing comma is removed if unnested:

```julia
func(a, b, c)

->

func(
    a,
    b,
    c,
)
```

See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/44) for more details.

## Trailing Semicolons

If a matrix node is nested the semicolons are removed.

```julia
A = [1 0; 0 1]

->

A = [
    1 0
    0 1
]
```

See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/77) for more details.

## Leading and trailing 0s for float literals

If a float literal is missing a *trailing* 0 it is added:

```julia
a = 1.

->

a = 1.0
```

If a float literal is missing a *leading* 0 it is added:

```julia
a = .1

->

a = 0.1
```

For `Float32` if there is no decimal point, `.0` is added:

```julia
a = 1f0

->

a = 1.0f0
```

See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/66) for more details.

## Surround `where` arguments with curly brackets

If the arguments of a `where` call are not surrounded by curly brackets, they are added:

```julia
foo(x::T) where T = ...

->

foo(x::T) where {T} = ...
```

See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/53) for more details.

## Annotate unannotated type fields with `Any`

```julia
struct Foo
    field
end

->

struct Foo
    field::Any
end
```

## Move `@` in macro calls to the final identifier

```julia
@Module.macro

->

Module.@macro
```
