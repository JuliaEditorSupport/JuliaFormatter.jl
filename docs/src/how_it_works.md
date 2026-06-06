# [How It Works](@id how-it-works)

JuliaFormatter works in several stages:

1. Parsing the source code to generate a _concrete syntax tree_ (CST).

2. Generating a _formatted syntax tree_ (FST) from the CST.
   This is not a formal term; it's just a term that's used internally to represent a CST with additional formatting-specific metadata, such as placeholders indicating spots where newlines can be inserted.

3. Nesting the FST, i.e., determining where newlines should be inserted.

4. Printing the FST to text.

These stages are described in more detail below.


## Parsing: `String -> CST`

A [concrete syntax tree](https://en.wikipedia.org/wiki/Parse_tree) differs from the more familiar [_abstract_ syntax tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree) in that it retains all information in the source code that is not semantically relevant, such as whitespace, extra parentheses, and comments.

In particular, JuliaFormatter v2.5 uses [JuliaSyntax.jl v1](https://github.com/JuliaLang/JuliaSyntax.jl) as its CST parser.
Here is an example of a CST:

```@example howitworks
using JuliaSyntax: parseall, GreenNode

text = "x = f(y + z) # comment"
cst = parseall(GreenNode, text)
```

In this example, you can see that JuliaSyntax has generated a tree structure.
The numbers on the left-hand side indicate the byte offsets of each node in the original source code.

Notice that the whitespace and comment in the original source code is preserved in the CST.
In contrast, an AST, generated e.g. using `Meta.parse`, would discard this information.
In principle, we could pretty-print the AST and thus reconstruct "formatted" code with the same semantics.
However, this would not be ideal since we would lose (for example) comments as well as the original parenthesisation of expressions, which a user may have intentionally added for readability.

```@example howitworks
dump(Meta.parse(text))
```

!!! note
    The CST parsing backend has varied across versions.
    JuliaFormatter v2 - v2.4 used JuliaSyntax.jl v0, and JuliaFormatter v1 used [CSTParser.jl](https://github.com/julia-vscode/CSTParser.jl).

## Generating an `FST`

From the CST we transform it into a slightly richer representation, which is internally called an FST.
The FST is very similar to the CST, but it contains additional information that is specific to formatting.

For example, the CST is very lightweight: it actually does not store any strings for the various nodes, only byte offsets.
When generating the FST, we use the byte offsets plus the original source code to extract the relevant substrings and store them in the FST.

```@example howitworks
using JuliaFormatter: State, Document, Options, pretty, DefaultStyle

state = State(Document(text), Options(; margin=10))
fst = pretty(DefaultStyle(), cst, state)
```

In this very simple example here, `margin=10` does not actually affect the FST.
However, in general, the style as well as the options passed in here will affect the structure of the generated FST, either via multiple dispatch, or via the `state.opts` field.

Notice that each node in this tree contains a `val` field, which is the string corresponding to that node in the CST.
On top of that, there are some mysterious `PLACEHOLDER` nodes, which are not present in the CST.
These indicate potential locations where we can insert newlines when we later _nest_ the FST.
For example, in the string `x = f(y + z)` we can insert a newline in several places:

```
x = f( y + z )
   ^  ^   ^ ^
```

Each of these potential newline locations is represented by a `PLACEHOLDER` node in the FST.

Several other transformations happen at this stage:

- Code and comments are indented to match surrounding code blocks.
- Unnecessary whitespace is removed (although newlines in between code blocks are untouched).
- Code is flattened as much as possible. For example, if an expression can be put on a single line, it will be: it doesn't matter if it's over the margin or not at this stage.
  However, if the expression has a block-like structure to it, such as a `try`, `if`, or a `struct` definition, it will be spread across multiple lines appropriately:

The important invariant underpinning a FST is any two strings that are syntactically the same (ignoring whitespace) will produce an identical `FST`.
For example:

```julia
a = 
       foo(a,                     b,           
       c,d)
```

and

```julia
a =                      foo(a,
b,
c,d)
```

will produce the same FST, which when printed would look like `a = foo(a, b, c, d)`.

## Nesting the FST

At this point we have not actually yet decided which of these (if any) need to be converted into newlines.
This depends on, for example, the margin.
We can see how this affects the output here:

```@example howitworks
using JuliaFormatter: format_text

format_text(text; margin=40) |> print
```

```@example howitworks
format_text(text; margin=10) |> print
```

The decision on where to insert newlines is made in the nesting stage, which converts `PLACEHOLDER` nodes to `NEWLINE` nodes as needed.
Recall that above we specified `margin=10`.
This will cause the `nest!` function to insert newlines such that no line exceeds 10 characters.
Just as before, the style and options passed in here will affect the decisions made inside `nest!`.

```@example howitworks
using JuliaFormatter: nest!

nest!(DefaultStyle(), fst, state)
fst
```

## Printing the FST

Once the FST has been nested the rest is straightforward: traverse the tree and print it out into a string!

```@example howitworks
using JuliaFormatter: print_tree

io = IOBuffer()
print_tree(io, fst, state)
String(take!(io)) |> print
```
