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

The `SciMLStyle` supports the following additional options, which have no effect on other styles:

- [`sciml_margin_overrun`](@ref options-sciml-margin-overrun)
- [`variable_call_indent`](@ref options-variable-call-indent)
- [`yas_style_nesting`](@ref options-yas-style-nesting)
