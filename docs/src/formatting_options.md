# [Formatting Options](@id formatting-options)

JuliaFormatter is intended to be configurable and comes with a number of options to control the output of the formatter.
Suggestions for more options are welcome; please open an issue!

All of these [_formatting options_](@ref formatting-options) can be specified as:

- keyword arguments to [`JuliaFormatter.format`](@ref), [`JuliaFormatter.format_text`](@ref) and [`JuliaFormatter.format_file`](@ref)
- entries in a [`.JuliaFormatter.toml`](@ref config) file, or
- command-line arguments to the [`jlfmt`](@ref cli) command.

!!! note "File options"
    `.JuliaFormatter.toml` and `jlfmt` further accept additional options that control which files are to be formatted.
    These options are not passed to `format` and friends, and are thus categorised as _file options_ instead: please see the [File Options](@ref file-options) page for more deatils.

Below is a table of all the currently available formatting options, along with what each style sets each option to.
Values that differ from `DefaultStyle` are shown in **bold**.

!!! note "Styles vs options"
    Note that, although styles each define a different set of options, they are not _just_ collections of options; they also have unique formatting rules that are not captured by the options.

| Option                                                                              | Default   | YAS         | Blue        | SciML        | Minimal       |
| :-------                                                                            | --------- | -----       | ------      | -------      | ---------     |
| [`align_assignment`](@ref options-align-star)                                       | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`align_conditional`](@ref options-align-star)                                      | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`align_matrix`](@ref options-align-matrix)                                         | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`align_pair_arrow`](@ref options-align-star)                                       | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`align_struct_field`](@ref options-align-star)                                     | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`always_for_in`](@ref options-always-for-in)                                       | `false`   | **`true`**  | **`true`**  | **`true`**   | **`nothing`** |
| [`always_use_return`](@ref options-always-use-return)                               | `false`   | **`true`**  | `false`     | `false`      | `false`       |
| [`annotate_untyped_fields_with_any`](@ref options-annotate-untyped-fields-with-any) | `true`    | `true`      | **`false`** | `true`       | **`false`**   |
| [`conditional_to_if`](@ref options-conditional-to-if)                               | `false`   | `false`     | **`true`**  | `false`      | `false`       |
| [`disallow_single_arg_nesting`](@ref options-disallow-single-arg-nesting)           | `false`   | `false`     | `false`     | **`true`**   | `false`       |
| [`for_in_replacement`](@ref options-for-in-replacement)                             | `"in"`    | `"in"`      | `"in"`      | `"in"`       | `"in"`        |
| [`force_long_function_def`](@ref options-force-long-function-def)                   | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`format_docstrings`](@ref options-format-docstrings)                               | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`import_to_using`](@ref options-import-to-using)                                   | `false`   | **`true`**  | **`true`**  | `false`      | `false`       |
| [`indent`](@ref options-indent)                                                     | `4`       | `4`         | `4`         | `4`          | `4`           |
| [`indent_submodule`](@ref options-indent-submodule)                                 | `false`   | `false`     | **`true`**  | `false`      | `false`       |
| [`join_lines_based_on_source`](@ref options-join-lines-based-on-source)             | `false`   | **`true`**  | `false`     | **`true`**   | **`true`**    |
| [`long_to_short_function_def`](@ref options-long-to-short-function-def)             | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`margin`](@ref options-margin)                                                     | `92`      | `92`        | `92`        | `92`         | **`10_000`**  |
| [`normalize_line_endings`](@ref options-normalize-line-endings)                     | `"auto"`  | `"auto"`    | `"auto"`    | **`"unix"`** | `"auto"`      |
| [`pipe_to_function_call`](@ref options-pipe-to-function-call)                       | `false`   | **`true`**  | **`true`**  | `false`      | `false`       |
| [`remove_extra_newlines`](@ref options-remove-extra-newlines)                       | `false`   | **`true`**  | **`true`**  | **`true`**   | `false`       |
| [`sciml_margin_overrun`](@ref options-sciml-margin-overrun)                         | unused    | unused      | unused      | **`20`**     | unused        |
| [`separate_kwargs_with_semicolon`](@ref options-separate-kwargs-with-semicolon)     | `false`   | **`true`**  | **`true`**  | `false`      | `false`       |
| [`short_circuit_to_if`](@ref options-short-circuit-to-if)                           | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`short_to_long_function_def`](@ref options-short-to-long-function-def)             | `false`   | **`true`**  | **`true`**  | **`true`**   | `false`       |
| [`surround_whereop_typeparameters`](@ref options-surround-whereop-typeparameters)   | `true`    | `true`      | `true`      | `true`       | **`false`**   |
| [`trailing_comma`](@ref options-trailing-comma)                                     | `true`    | `true`      | `true`      | **`false`**  | **`nothing`** |
| [`trailing_zero`](@ref options-trailing-zero)                                       | `true`    | `true`      | `true`      | `true`       | **`false`**   |
| [`variable_call_indent`](@ref options-variable-call-indent)                         | `[]`      | `[]`        | `[]`        | `[]`         | `[]`          |
| [`whitespace_in_kwargs`](@ref options-whitespace-in-kwargs)                         | `true`    | **`false`** | **`false`** | `true`       | **`false`**   |
| [`whitespace_ops_in_indices`](@ref options-whitespace-ops-in-indices)               | `false`   | **`true`**  | **`true`**  | **`true`**   | `false`       |
| [`whitespace_typedefs`](@ref options-whitespace-typedefs)                           | `false`   | `false`     | `false`     | **`true`**   | `false`       |
| [`yas_style_nesting`](@ref options-yas-style-nesting)                               | `false`   | `false`     | `false`     | `false`      | `false`       |

## [`align_...`](@id options-align-star)

Default: `false`

The `align_assignment`, `align_conditional`, `align_pair_arrow`, and `align_struct_field` options allow you to vertically align operators on consecutive lines.
See the [`Custom Alignment`](@ref custom-alignment) page for more details and examples.

## [`align_matrix`](@id options-align-matrix)

Default: `false`

If enabled, this option preserves pre-existing whitespace surrounding matrix elements in the original source file.
If you want to align matrix elements yourself, you should set this to `true`.

```@example align-matrix
using JuliaFormatter: format_text

# Elements left-aligned in original source
s = """
a = [
100 300 400
1   eee 40000
2   α   b
]"""

format_text(s, align_matrix=true) |> print
```

```@example align-matrix
# Elements right-aligned in original source
s = """
a = [
100 300   400
  1  ee 40000
  2   a     b
]"""

format_text(s, align_matrix=true) |> print
```

## [`always_for_in`](@id options-always-for-in)

Default: `false`

If true, `=` is always replaced with `in` if part of a `for` loop condition.
For example, `for i = 1:10` will be transformed to `for i in 1:10`. Set
this to `nothing` to leave the choice to the user.

## [`always_use_return`](@id options-always-use-return)

Default: `false`

If true, `return` will be prepended to the last expression where
applicable in function definitions, macro definitions, and do blocks.

Example:

```julia
function foo()
    expr1
    expr2
end
```

to

```julia
function foo()
    expr1
    return expr2
end
```

## [`annotate_untyped_fields_with_any`](@id options-annotate-untyped-fields-with-any)

Default: `true`

Annotates fields in a type definitions with `::Any` if no type annotation is provided:

```julia
struct A
    arg1
end
```

to

```julia
struct A
    arg1::Any
end
```

## [`conditional_to_if`](@id options-conditional-to-if)

Default: `false`

If the conditional `E ? A : B` exceeds the maximum margin converts it into the equivalent `if` block:

```julia
if E
    A
else
    B
end
```

## [`disallow_single_arg_nesting`](@id options-disallow-single-arg-nesting)

Prevents the nesting of a single argument `arg` in parenthesis, brackets, and curly braces.

```julia
# Without `disallow_single_arg_nesting`:
function_call(
    "String argument"
)
[array_item(
    10
)]
{key => value(
    "String value"
)}

# With `disallow_single_arg_nesting` enabled:
function_call("String argument")
[array_item(10)]
{key => value("String value")}
```

## [`for_in_replacement`](@id options-for-in-replacement)

Can be used when [`always_for_in`](@ref options-always-for-in) is `true` to replace the default `in` with `∈` (`\\in`),
or `=` instead. The replacement options are `("in", "=", "∈")`.

```julia
for a = 1:10
end

# formatted with always_for_in = true, for_in_replacement = "∈"
for a ∈ 1:10
end
```

## [`force_long_function_def`](@id options-force-long-function-def)
Default: `false`

If `true` tweaks the behavior of [`short_to_long_function_def`](@ref options-short-to-long-function-def) to force the transformation no matter how short the function definition is.

## [`format_docstrings`](@id options-format-docstrings)

Default: `false`

Format code docstrings with the same options used for the code source.

Markdown is formatted with [`CommonMark`](https://github.com/MichaelHatherly/CommonMark.jl) alongside Julia code.

## [`import_to_using`](@id options-import-to-using)

Default: `false`

If true, `import` expressions are rewritten to `using` expressions
in the following cases:

```julia
import A

import A, B, C
```

is rewritten to:

```julia
using A: A

using A: A
using B: B
using C: C
```

There are some exceptions to this:

- If `as` is found in the import expression, `using` *cannot* be used in this context.
  The following example will not be rewritten:

  ```julia
  import Base.Threads as th
  ```

- If `import` is used in the following context it is *not* rewritten.
  This may change in a future patch.

  ```julia
  @everywhere import A, B
  ```

## [`indent`](@id options-indent)

Default: `4`

The number of spaces used for one level of indentation.

There is at present no option to use tabs for indentation: please open an issue if you want this feature.

## [`indent_submodule`](@id options-indent-submodule)

Default: `false`

When set to `true`, submodule(s) appearing in the same file will be indented.

```julia
module A
a = 1

module B
b = 2
module C
c = 3
end
end

d = 4

end
```

will be formatted to:

```julia
module A
a = 1

module B
    b = 2
    module C
        c = 3
    end
end

d = 4

end
```

## [`join_lines_based_on_source`](@id options-join-lines-based-on-source)

Default: `false`

When `true` lines are joined as they appear in the original source file.

```julia
function foo(arg1,
                       arg2, arg3
                       )
       body
end
```

When `false` and the maximum margin is > than the length of `"function foo(arg1, arg2, arg3)"`
this is formatted to

```julia
function foo(arg1, arg2, arg3)
    body
end
```

When `true`, `arg1` and `arg2, arg3` will remain on separate lines even if they can fit on the
same line since it's within maximum margin. The indentation is dependent on the style.

```julia
function foo(arg1,
    arg2, arg3,
)
end
```

There are exceptions to this:

```julia
if a body1 elseif b body2 else body3 end
```

will be formatted to the following, even if this option is set to `true`:

```julia
if a
    body1
elseif b
    body2
else
    body3
end
```

!!! warning

    The maximum margin still applies even when this option is set to `true`.

## [`long_to_short_function_def`](@id options-long-to-short-function-def)

Default: `false`

Transforms a *long* function definition

```julia
function f(arg2, arg2)
    body
end
```

to a *short* function definition if the short function definition does not exceed the maximum margin.

```julia
f(arg1, arg2) = body
```

See also: [`short_to_long_function_def`](@ref options-short-to-long-function-def).

## [`margin`](@id options-margin)

Default: `92`

The maximum length of a line.
Code exceeding this margin will, in general, be formatted across multiple lines.

## [`normalize_line_endings`](@id options-normalize-line-endings)

Default: `"auto"`

One of `"unix"` (normalize all `\r\n` to `\n`), `"windows"` (normalize all `\n` to `\r\n`), `"auto"` (automatically choose based on which line ending is more common in the file).

## [`pipe_to_function_call`](@id options-pipe-to-function-call)

Default: `false`

If true, `x |> f` is rewritten to `f(x)`, and `x .|> f` to `f.(x)`.

!!! danger "Semantics may be changed"

    **Note that this transformation may change the semantics of the code in
    some cases:**

    1. If `Base.:(|>)` is overloaded to have a different meaning for a given
       `f` and `x`.

    2. If the call to `x |> f` is intercepted by a macro that transforms it to 
       something other than `f(x)`. For example,
       [Pipe.jl](https://github.com/oxinabox/Pipe.jl).

    To avoid (2), JuliaFormatter refuses to apply this transformation within the
    body of a macro. However, there is no way to detect (1). As such,
    JuliaFormatter will emit a warning if this transformation is applied during
    formatting, to alert the user to the potential of unwanted changes.

    It is recommended to set this option to `true` only if you are confident
    that there are no such cases. **Note:** `pipe_to_function_call` is set to
    `true` by default for Blue and YAS styles, so in such cases you have to opt
    out manually!


## [`remove_extra_newlines`](@id options-remove-extra-newlines)

Default: `false`

If true, superfluous newlines will be removed. For example:

```julia
module M



a = 1

function foo()


    return nothing

end


b = 2


end
```

is rewritten as

```julia
module M

a = 1

function foo()
    return nothing
end

b = 2

end
```

Modules are the only type of code block where it is permissible to keep a single newline prior to the initial or after the final piece of code.

## [`sciml_margin_overrun`](@id options-sciml-margin-overrun)

Default: `20`

Additional columns `SciMLStyle` may use when a slightly over-margin line is
more readable than an aggressive line break.
Set this to `0` to make SciML soft-margin checks strict.

This option has no effect for other styles.

## [`separate_kwargs_with_semicolon`](@id options-separate-kwargs-with-semicolon)

Default: `false`

When set to `true`, keyword arguments in a function call will be separated with a semicolon.

```julia
f(a, b=1)

->

f(a; b=1)
```

## [`short_circuit_to_if`](@id options-short-circuit-to-if)

If `truer`, converts shortcircuiting expressions to the equivalent if-expression.

```julia
function foo(a, b)
    a || return "bar"

    "hello"

    b && return "ooo"
end
```

becomes

```julia
function foo(a, b)
    if !(a)
        return "bar"
    end

    "hello"

    if b
        return "ooo"
    else
        false
    end
end
```

## [`short_to_long_function_def`](@id options-short-to-long-function-def)

Default: `false`

Transforms a *short* function definition

```julia
f(arg1, arg2) = body
```

to a *long* function definition if the short function definition exceeds the maximum margin, or if [`force_long_function_def`](@ref options-force-long-function-def) is set to `true`.

```julia
function f(arg2, arg2)
    body
end
```

See also: [`long_to_short_function_def`](@ref options-long-to-short-function-def).

## [`surround_whereop_typeparameters`](@id options-surround-whereop-typeparameters)

Default: `true`

If `true`, surrounds type parameters with curly braces if the braces are not already present.

```julia
function func(...) where TPARAM
end
```

becomes

```julia
function func(...) where {TPARAM}
end
```

## [`trailing_comma`](@id options-trailing-comma)

Default: `true`

One of `true`, `false`, or `nothing`.

Trailing commas are added after the final argument when nesting occurs and the closing punctuation appears on the next line.

For example when the following is nested (assuming `DefaultStyle`):

```julia
funccall(arg1, arg2, arg3)
```

it turns into:

```julia
funccall(
    arg1,
    arg2,
    arg3, # trailing comma added after `arg3` (final argument) !!!
)
```

* When set to `true`, the trailing comma is always added during nesting.
* When set to `false`, the trailing comma is always removed during nesting.
* When set to `nothing`, the trailing comma appears as it does in the original source.

## [`trailing_zero`](@id options-trailing-zero)

Default: `true`

Add a trailing zero, if needed.

## [`variable_call_indent`](@id options-variable-call-indent)

Default: `[]`

The `SciMLStyle` supports the additional option `variable_call_indent`.
It permits continuation lines in calls to not align with the opening parenthesis:

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

## [`whitespace_in_kwargs`](@id options-whitespace-in-kwargs)

Default: `true`

If true, `=` in keyword arguments will be surrounded by whitespace.

```julia
f(; a=4)
```

to

```julia
f(; a = 4)
```

Note that if this option is false, the arguments on either side of the equals may sometimes be parenthesised to avoid parsing ambiguities.
For example, `f(s! = x)` will be transformed to `f((s!)=x)`, and `f(t = >=(1))` will be transformed to `f(t=(>=(1)))`.

## [`whitespace_ops_in_indices`](@id options-whitespace-ops-in-indices)

Default: `false`

If true, whitespace is added for binary operations in indices. Make this
`true` if you prefer `arr[a + b]` to `arr[a+b]`. Additionally, if there's
a colon `:` involved, parenthesis will be added to the LHS and RHS.

Example: `arr[(i1 + i2):(i3 + i4)]` instead of `arr[i1+i2:i3+i4]`.

## [`whitespace_typedefs`](@id options-whitespace-typedefs)

Default: `false`

If true, whitespace is added for type definitions. Make this `true`
if you prefer `Union{A <: B, C}` to `Union{A<:B,C}`.

## [`yas_style_nesting`](@id options-yas-style-nesting)

Default: `false`

The option `yas_style_nesting` is set to `false` by default.
Setting it to `true` makes the `SciMLStyle` use the `YASStyle` nesting rules.
For other styles, this option has no effect.

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
