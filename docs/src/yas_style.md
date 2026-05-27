# YAS Style

```@docs
YASStyle
```

## Configuration File Example

The `.JuliaFormatter.toml` which represents these settings is

```toml
style = "yas"
```

Or to use `YASStyle` except change one of the settings:

```toml
style = "yas"
remove_extra_newlines = false
```

## Direct Usage

```julia
format("file.jl", YASStyle())
```

Or to use `YASStyle` except change one of the settings:

```julia
format("file.jl", YASStyle(), remove_extra_newlines=false)
```

## Differences from `DefaultStyle`

There are three main differences between `YASStyle` and `DefaultStyle`. They are based
on alignment and line break behaviors.

 1. Arguments are aligned to just after the start of the *opener* `[, {, (, etc`.

    ```julia
    function_call(arg1,
                  arg2)
    ```

 2. As you can see from the above the *closer* sticks to the final argument.

 3. Nesting (line breaks) only occur when the margin of the next argument exceeds
    the maximim limit.

    ```julia
    function_call(arg1, arg2,
                  arg3)
    ```

`arg3` exceeded the margin limit and so it was placed on the following line.

### Nesting `=`

Unlike `DefaultStyle`, assignment operations `=` are not nested. That
is, the following

```julia
my_function(arg1, arg2) = arg1 * arg2
```

Is not nested to

```julia
my_function(arg1, arg2) =
    arg1 * arg2
```

It is highly recommended setting `short_to_long_function_def` to `true`. This option
transforms the above to a long function definition if it exceeds the maximum margin.

```julia
function my_function(arg1, arg2)
    arg1 * arg2
end
```

## Additional Options

The `YASStyle` supports the additional option `variable_call_indent`,
which is set to `[]` by default.
It allows calls without aligning to the opening parenthesis:

```julia
# Allowed with and without `Dict in variable_call_indent`
Dict{Int,Int}(1 => 2,
              3 => 4)

# Allowed when `Dict in variable_call_indent`, but
# will be changed to the first example when `Dict ∉ variable_call_indent`.
Dict{Int,Int}(
    1 => 2,
    3 => 4)
```
