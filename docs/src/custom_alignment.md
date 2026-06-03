# [Custom Alignment](@id custom-alignment)

Custom alignment is a scenario where extra whitespace is inserted into the formatted output to make sure that tokens (typically operators, such as `=`, `?`, and `::`) on contiguous lines are vertically aligned.
This was implemented as a solution for [issue 179](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/179).

Custom alignment is determined by a whitespace heuristic.
Since JuliaFormatter usually only outputs either 0 or 1 spaces as separations between tokens, the presence of more than one space between tokens is used as a signal to trigger custom alignment.
If a formatter detects that a token is custom-aligned, then all tokens in the same code block (i.e., contiguous lines, not separated by comments or empty lines) will be aligned to the furthest aligned token.

!!! warning
    If active, custom alignment will override pre-existing nesting behaviour.
    This means that lines can exceed the maximum margin.

Custom alignment must be opted into via [the configuration options](@ref formatting-options) `align_assignment`, `align_conditional`, `align_matrix`, `align_pair_arrow`, and `align_struct_field`.

### Example

Suppose the source text is as follows:

```julia
const variable1 = 1
const var2      = 2
const var3 = 3
const var4 = 4
const var5          = 5
```

If the option `align_assignment=true` is set, the formatter will detect that `var2` is aligned to `variable1` *and* that `var2` has more than 1 space prior to its `=`.
Since `var3`,`var4`, and `var5` are part of the same code block (no comments or newlines separating code) their `=` operators will then be aligned to `var2`'s `=`, which is the furthest aligned token.

The resulting output would be

```julia
const variable1 = 1
const var2      = 2
const var3      = 3
const var4      = 4
const var5      = 5
```

Notice how the `=` operator for `var5` is correctly positioned despite it being located further to the right than other `=` operators in the original source.

However, if the source code is

```julia
const variable1 = 1
const variable2 = 2
const var3 = 3
const var4 = 4
const var5 = 5
```

it is now not clear whether the user intended for this to be aligned and so the formatter will not inject any custom behaviour.

## Alignment Options

In order for custom alignment to occur, the corresponding option must be set to `true`. Available options:

- `align_assignment`
- `align_struct_field`
- `align_conditional`
- `align_pair_arrow`
- `align_matrix`

### `align_assignment`

Align `=`-like operators.
This covers variable assignments and short definition functions.

Here are some examples of code formatted with `align_assignment=true`:

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

Align struct field definitions to `::` or `=`, whichever has higher precedence.

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
