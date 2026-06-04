# [SciML Style](@id sciml-style)

!!! warning "SciMLStyle !== 'SciML style' === Runic"

    Note that the SciML Style Guide currently suggests using Runic.jl for formatting instead.

    JuliaFormatter's `SciMLStyle()` represents a collection of styles that predated this recommendation, and is being kept in v2 for compatibility.
    In a future major release this style may be renamed to avoid confusion.

```@docs
SciMLStyle
```

## Configuration File Example

The `.JuliaFormatter.toml` which represents these settings is

```toml
style = "sciml"
```

Or to use `SciMLStyle` except change one of the settings:

```toml
style = "sciml"
remove_extra_newlines = false
```

## Direct Usage

```julia
format("file.jl", SciMLStyle())
```

Or to use `SciMLStyle` except change one of the settings:

```julia
format("file.jl", SciMLStyle(), remove_extra_newlines=false)
```

## Additional Options

The `SciMLStyle` supports the additional options `variable_call_indent` and `yas_style_nesting`.

The option `variable_call_indent` is set to `[]` by default.
It allows calls without aligning to the opening parenthesis:

```julia
# Allowed with and without `Dict in variable_call_indent`
Dict{Int, Int}(1 => 2,
    3 => 4)

# Allowed when `Dict in variable_call_indent`, but
# will be changed to the first example when `Dict ∉ variable_call_indent`.
Dict{Int, Int}(
    1 => 2,
    3 => 4)
```

The option `yas_style_nesting` is set to `false` by default.
Setting it to `true` makes the `SciMLStyle` use the `YASStyle` nesting rules:

```julia
# With `yas_style_nesting = false`
function my_large_function(argument1, argument2,
        argument3, argument4,
        argument5, x, y, z)
    foo(x) + goo(y)
end

# With `yas_style_nesting = true`
function my_large_function(argument1, argument2,
                           argument3, argument4,
                           argument5, x, y, z)
    foo(x) + goo(y)
end
```
