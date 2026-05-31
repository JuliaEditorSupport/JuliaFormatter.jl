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

## Unnesting

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
