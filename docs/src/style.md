```@meta
CurrentModule = JuliaFormatter
```

# Style

This is meant to give an impression of how the output of a formatted file looks like.
Additional examples can be found in the [test files](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/tree/master/test/files).

## Initial `FST`

> All examples assume indentation of **4 spaces**

Functions, macros, structs with no arguments are placed on a single line:

```julia
function  foo
end

->

function foo end
```

This also applies to abstract and primitive types:

```julia
abstract type
AbstractFoo
end

->

abstract type AbstractFoo end
```

Functions calls `foo(args...)`, tuples `(args...)`, arrays `[args...]`, braces `{args...}`, struct or where definitions `Foo{args...}` are placed on a single line. This applies to any code which has opening and closing punctuation: `(...)`, `{...}`, `[...]`.

```julia
f(

a,b

,c )

->

f(a, b, c)
```

By default type definitions have no whitespace after commas:

```julia
Foo{
a,b
,c }

->

Foo{a,b,c}
```

Blocks and their bodies are spread across multiple lines properly indented.

Example 1:

```julia
begin
  a
    b; c
       end

->

begin
    a
    b
    c
end
```

Example 2:

```julia
struct Foo{A, B}
 a::A
  b::B
end

->

struct Foo{A,B}
    a::A
    b::B
end
```

Binary calls are placed on a single line and separated by whitespace.
The exception to this are colon operations and operations inside an indexing expression.
The latter being optional.

Example 1:

```julia
a+b

-> 

a + b
```

Example 2:

```julia
a : a : c

->

a:b:c
```

Example 3:

```julia
list[a + b]

->

list[a+b]
```

Conditionals are placed on a single line and separated by whitespace.

```julia
cond1 ?
expr1 :     expr2

->

cond1 ? expr1 : expr2
```

Comments are aligned to surrounding code blocks.

```julia
# comment
if a
# comment
elseif b
# comment
elseif c
# comment
else
# comment
end
# comment

->

# comment
if a
    # comment
elseif b
    # comment
elseif c
    # comment
else
    # comment
end
# comment
```

## Nesting `FST`

Binary operations and conditionals are nested back-to-front.

Example 1:

```julia
arg1 + arg2

->

arg1 + 
arg2
```

Example 2:

```julia
cond ? e1 : e2

->

cond ? e1 :
e2

->

cond ? 
e1 :
e2
```

If nesting is required for a `=` binary operation, the RHS is placed on the following line and indented.

```julia
foo() = body

->

foo() =
    body
```

All arguments of a function call (applies to any opening/closing punctuation type) are nested
if the expression exceeds the margin. The arguments are indented one level.

```julia
function longfunctionname_that_is_long(lots, of, args, even, more, args)
    body
end

->

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

->

function f(
    arg1::A,
    key1 = val1;
    key2 = val2,
) where {A,B,C}
    body
end

-> 

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

->

var = foo(
    a,
    b, # comment
    c,
)
```

## Unnesting `FST`

In certain cases it's desirable to unnest parts of a `FST`.

Example 1:

```julia
# short function def
function foo(arg1, arg2, arg3) = body

-> 

function foo(arg1, arg2, arg3) =
    body

->

function foo(
    arg1,
    arg2,
    arg3,
) =
    body

# If the margin allows it, `body` will be joined back
# with the previous line.

function foo(
    arg1,
    arg2,
    arg3,
) = body
```

Example 2:

```julia
var = funccall(arg1, arg2, arg3)

-> 

var =
    funccall(arg1, arg2, arg3)

->

var =
    funccall(
        arg1,
        arg2,
        arg3,
    )

# If the margin allows it, the RHS will be joined back
# with the previous line.

var = funccall(
    arg1,
    arg2,
    arg3,
)
```
