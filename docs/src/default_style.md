```@meta
CurrentModule = JuliaFormatter
```

# [Default style](@id default-style)

JuliaFormatter has a default style.
This page is intended to give a rough overview of how the output of a formatted file looks like when using the default style.
Additional examples can be found in [JuliaFormatter's codebase itself](https://github.com/JuliaEditorSupport/JuliaFormatter.jl).

All examples assume indentation of 4 spaces.

## Nesting decisions

Where possible JuliaFormatter's default style attempts to keep code on a single line.

### With no arguments

Functions, macros, and structs with no arguments are placed on a single line.
This also applies to abstract and primitive types:

```julia
function  foo
end
abstract type
AbstractFoo
end
```

is formatted to

```julia
function foo end
abstract type AbstractFoo end
```

### With arguments

Functions calls `foo(args...)`, tuples `(args...)`, arrays `[args...]`, braces `{args...}`, and type parameter definitions `Foo{args...}` are placed on a single line.
This applies to any code which has opening and closing punctuation: `(...)`, `{...}`, `[...]`.

Whitespace is inserted after commas, but not for type definitions:

```julia
f(

a,b

,c )

Foo{
a,b
,c }
```

is formatted to

```julia
f(a, b, c)
Foo{a,b,c}
```

### Blocks

Blocks and their bodies are spread across multiple lines and properly indented.

Example 1:

```julia
begin
  a
    b; c
       end

struct Foo{A, B}
 a::A
  b::B
end
```

is formatted to

```julia
begin
    a
    b
    c
end

struct Foo{A,B}
    a::A
    b::B
end
```

### Binary operators (without nesting)

Binary calls are placed on a single line where possible.
Their operands are separated by whitespace, except for `:` operators (i.e. ranges), and for operators which are inside indexing brackets.

Example 1:

```julia
a+b
a : a : c
list[a + b]
```

```julia
a + b
a:b:c
list[a+b]
```

Ternary expressions are placed on a single line and separated by whitespace:

```julia
cond1 ?
expr1 :     expr2
```

is formatted to

```julia
cond1 ? expr1 : expr2
```

Comments are aligned with surrounding code blocks.

```julia
# comment
if a
# comment
else
# comment
end
# comment
```

is formatted to

```julia
# comment
if a
    # comment
else
    # comment
end
# comment
```

## Binary operators (with nesting)

If a binary operation exceeds the margin, they are nested back-to-front:

```julia
arg1 + arg2
```

becomes (with a small margin)

```julia
arg1 + 
arg2
```

For the ternary operator, as the margin decreases, the `:` is first moved to the next line, and then the `?`:

```julia
cond ? e1 : e2
```

becomes (with a small margin)

```julia
cond ? e1 :
e2
```

and with an even smaller margin

```julia
cond ? 
e1 : e2
```

and with a _yet_ smaller margin

```julia
cond ? 
e1 :
e2
```

If nesting is required for an assignment (i.e., a binary operation with `=` as the operator), the RHS is placed on the following line and indented.

```julia
foo() = body
```

is formatted to

```julia
foo() =
    body
```

All arguments of a function call (applies to any opening/closing punctuation type) are nested if the expression exceeds the margin.
The arguments are indented one level.

```julia
function longfunctionname_that_is_long(lots, of, args, even, more, args)
    body
end
```

becomes

```julia
function longfunctionname_that_is_long(
    lots, 
    of, 
    args,
    even, 
    more, 
    args,
)
    body
end
```

With `where` operations (`A where B`), `A` is nested prior to `B`.

```julia
function f(arg1::A, key1 = val1; key2 = val2) where {A,B,C}
    body
end
```

becomes

```julia
function f(
    arg1::A,
    key1 = val1;
    key2 = val2,
) where {A,B,C}
    body
end
```

and if the margin is shrunk even more,

```julia
function f(
    arg1::A,
    key1 = val1;
    key2 = val2,
) where {
    A,
    B,
    C,
}
    body
end
```

If a comment is detected inside of an expression, that expression is automatically nested:

```julia
var = foo(
    a, b, # comment
    c,
)
```

becomes

```julia
var = foo(
    a,
    b, # comment
    c,
)
```

### Unnesting

In certain cases it is desirable to _unnest_ parts of a `FST` to avoid excessive whitespace.
For example, the following

```julia
var =
    funccall(
        arg1,
        arg2,
        arg3,
    )
```

will be un-nested to

```julia
var = funccall(arg1, arg2, arg3)
```

or 

```julia
var = funccall(
    arg1,
    arg2,
    arg3,
)
```

## Syntax transformations

### `for in` vs. `for =`

By default if the RHS is a range, e.g. `1:10`, then `for ... in ...` is converted to `for ... = ...`.
Otherwise `for ... = ...` is converted to `for ... in ...`.
See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/34) for the rationale and further explanation.

This behaviour can be controlled using the [`always_for_in` option](@ref options-always-for-in).
Setting `always_for_in=true` will always convert `=` to `in` even if the RHS is a range.
`always_for_in=nothing` will leave the choice of `in` vs `=` up to the user.

### Trailing Commas

If the node is _iterable_, for example a function call or list and is nested, a trailing comma is added to the last argument.
The trailing comma is removed if unnested:

```julia
func(a, b, c)
```

becomes

```julia
func(
    a,
    b,
    c,
)
```

See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/44) for more details.

### Trailing Semicolons

If a matrix node is nested, the semicolons are removed.

```julia
A = [1 0; 0 1]

->

A = [
    1 0
    0 1
]
```

See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/77) for more details.

### Leading and trailing 0s for float literals

If a float literal is missing a trailing or leading 0, it is added:

```julia
a = 1.
b = .1
```

becomes

```julia
a = 1.0
b = 0.1
```

For `Float32` literals, if there is no decimal point, `.0` is added:

```julia
a = 1f0

->

a = 1.0f0
```

See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/66) for more details.

### Surround `where` arguments with curly brackets

If the arguments of a `where` call are not surrounded by curly brackets, they are added:

```julia
foo(x::T) where T = ...
```

becomes

```julia
foo(x::T) where {T} = ...
```

This can be controlled with the [`surround_whereop_typeparameters` option](@ref options-surround-whereop-typeparameters).

See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/53) for more details.

### Annotate unannotated type fields with `Any`

In structs, if a field is unannotated, it is annotated with `Any`:

```julia
struct Foo
    field
end
```

becomes

```julia
struct Foo
    field::Any
end
```

This can be controlled with the [`annotate_untyped_fields_with_any` option](@ref options-annotate-untyped-fields-with-any).

### Move `@` in macro calls to the final identifier

```julia
@Module.macro
```

becomes

```julia
Module.@macro
```
