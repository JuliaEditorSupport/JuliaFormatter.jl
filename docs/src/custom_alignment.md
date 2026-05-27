# Custom Alignment

> Solution for [issue 179](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/179)

Custom alignment is determined by a whitespace heuristic:

A token (typically an operator, i.e. `=, ?, ::, etc`) is custom aligned if there are
`> 1` whitespaces from the previous expression since the formatter only outputs
0 or 1 whitespaces for separation. If custom alignment is determined then all
expressions in the code block will be aligned to the furthest aligned token.

> NOTE: alignment overrides nesting behavior, meaning it ignores the allowed maximum margin

### Example

Suppose the source text is as follows

```julia
const variable1 = 1
const var2      = 2
const var3 = 3
const var4 = 4
const var5          = 5
```

If the `align_assignment` option is enabled the formatter will detect that `var2`
is aligned to `variable1` AND `var2` has several whitespaces (>1) prior to
`=`. Since `var3`,`var4`, and `var5` are part of the same code block (no comments
or newlines separating code) they will also be aligned.

So the output would be

```julia
const variable1 = 1
const var2      = 2
const var3      = 3
const var4      = 4
const var5      = 5
```

Notice how the `=` operator for `var5` is correctly positioned
despite it being located further to the right than other `=` operators.

However, if the source code is

```julia
const variable1 = 1
const variable2 = 2
const var3 = 3
const var4 = 4
const var5 = 5
```

It's now ambiguous whether this is meant to be aligned and so the formatter will
proceed with normal behavior.

## Alignment Options


In order for alignment to occur the option must be set to `true`. Available options:

- `align_assignment`
- `align_struct_field`
- `align_conditional`
- `align_pair_arrow`
- `align_matrix`

!!! warning "Caveat"
    Since nesting is disabled when alignment occurs be careful when adding comments to the RHS expression. This will be fixed in a future release

For example:

```julia
const variable1 = 1
const var2      = foo(10,
    # comment,
    20)
```

This will be formatted to

```julia
const variable1 = 1
const var2      = foo(10, # comment, 20)
```

which causes a parsing error.

### `align_assignment`

Align to `=`-like operators. This covers variable assignments and short definition functions.


```julia
const UTF8PROC_STABLE    = (1 << 1)
const UTF8PROC_COMPAT    = (1 << 2)
const UTF8PROC_COMPOSE   = (1 << 3)
const UTF8PROC_DECOMPOSE = (1 << 4)
const UTF8PROC_IGNORE    = (1 << 5)
const UTF8PROC_REJECTNA  = (1 << 6)
const UTF8PROC_NLF2LS    = (1 << 7)
const UTF8PROC_NLF2PS    = (1 << 8)
const UTF8PROC_NLF2LF    = (UTF8PROC_NLF2LS | UTF8PROC_NLF2PS)
const UTF8PROC_STRIPCC   = (1 << 9)
const UTF8PROC_CASEFOLD  = (1 << 10)
const UTF8PROC_CHARBOUND = (1 << 11)
const UTF8PROC_LUMP      = (1 << 12)
const UTF8PROC_STRIP     = (1 << 13)


vcat(X::T...) where {T}         = T[X[i] for i = 1:length(X)]
vcat(X::T...) where {T<:Number} = T[X[i] for i = 1:length(X)]
hcat(X::T...) where {T}         = T[X[j] for i = 1:1, j = 1:length(X)]
hcat(X::T...) where {T<:Number} = T[X[j] for i = 1:1, j = 1:length(X)]

a  = 1
bc = 2

long_variable = 1
other_var     = 2
```

### `align_struct_field`

Align struct field definitions to `::` or `=` - whichever has higher precedence.

```julia
Base.@kwdef struct Options
    indent::Int                            = 4
    margin::Int                            = 92
    always_for_in::Bool                    = false
    whitespace_typedefs::Bool              = false
    whitespace_ops_in_indices::Bool        = false
    remove_extra_newlines::Bool            = false
    import_to_using::Bool                  = false
    pipe_to_function_call::Bool            = false
    short_to_long_function_def::Bool       = false
    always_use_return::Bool                = false
    whitespace_in_kwargs::Bool             = true
    annotate_untyped_fields_with_any::Bool = true
    format_docstrings::Bool                = false
    align_struct_fields::Bool              = false

    # no custom whitespace so this block is not aligned
    another_field1::BlahBlahBlah = 10
    field2::Foo = 10

    # no custom whitespace but single line blocks are not aligned
    # either way
    Options() = new()
end


mutable struct Foo
    a             :: T
    longfieldname :: T
end
```

### `align_conditional`

Align conditional expressions to either `?`, `:`, or both.

```julia
# This will remain like this if using YASStyle
index = zeros(n <= typemax(Int8)  ? Int8  :
              n <= typemax(Int16) ? Int16 :
              n <= typemax(Int32) ? Int32 : Int64, n)

# Using DefaultStyle
index = zeros(
    n <= typemax(Int8)  ? Int8  :
    n <= typemax(Int16) ? Int16 :
    n <= typemax(Int32) ? Int32 : Int64,
    n,
)

# Note even if the maximum margin is set to 1, the alignment remains intact
index =
    zeros(
        n <= typemax(Int8)  ? Int8  :
        n <= typemax(Int16) ? Int16 :
        n <= typemax(Int32) ? Int32 : Int64,
        n,
    )

```

### `align_pair_arrow`

Align pair arrows (`=>`).

```julia
pages = [
    "Introduction"        => "index.md",
    "How It Works"        => "how_it_works.md",
    "Code Style"          => "style.md",
    "Skipping Formatting" => "skipping_formatting.md",
    "Syntax Transforms"   => "transforms.md",
    "Custom Alignment"    => "custom_alignment.md",
    "Custom Styles"       => "custom_styles.md",
    "YAS Style"           => "yas_style.md",
    "Configuration File"  => "config.md",
    "API Reference"       => "api.md",
]
```


### `align_matrix`

 > TLDR: If you want to align matrix elements yourself set this to `true`

Whitespace surrounding matrix elements in the original source file is maintained. Differs from other alignment options since it does not try to "detect" alignment and then adjust other elements.

```julia-repl
# Elements left-aligned in original source
julia> s = """
       a = [
       100 300 400
       1   eee 40000
       2   α   b
       ]"""
"a = [\n100 300 400\n1   eee 40000\n2   α   b\n]"

julia> format_text(s, align_matrix=true) |> print
a = [
    100 300 400
    1   eee 40000
    2   α   b
]

# Elements right-aligned in original source
julia> s = """
       a = [
       100 300   400
         1  ee 40000
         2   a     b
       ]"""
"a = [\n100 300   400\n  1  ee 40000\n  2   a     b\n]"

julia>

julia> format_text(s, align_matrix=true) |> print
a = [
    100 300   400
      1  ee 40000
      2   a     b
]
```

