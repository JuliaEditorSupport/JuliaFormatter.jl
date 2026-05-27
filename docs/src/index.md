```@meta
CurrentModule = JuliaFormatter
```

# JuliaFormatter.jl

Width-sensitive formatter for Julia code. Inspired by gofmt, refmt, black, and prettier. Built with [`CSTParser.jl`](https://github.com/julia-vscode/CSTParser.jl).

- Sane defaults out of the box with options to customize.
- Supports [YAS](https://github.com/jrevels/YASGuide), [Blue](https://github.com/invenia/BlueStyle) and [SciML](https://github.com/SciML/SciMLStyle) style guides.
- `.JuliaFormatter.toml` configuration file to store options.

![](https://user-images.githubusercontent.com/1813121/72941091-0b146300-3d68-11ea-9c95-75ec979caf6e.gif)

## Installation

```julia
]add JuliaFormatter
```

## Quick Start

```julia
julia> using JuliaFormatter

# Recursively formats all Julia files in the current directory
julia> format(".")

# Formats an individual file
julia> format_file("foo.jl")

# Formats a string (contents of a Julia file)
julia> format_text(str)
```

Check out the docs for further description of the formatter and its options.

[Use With GitHub Actions](https://github.com/julia-actions/julia-format)

## Formatting Options

### `indent`

Default: `4`

The number of spaces used for an indentation.

### `margin`

Default: `92`

The maximum length of a line. Code exceeding this margin will
be formatted across multiple lines.

### `always_for_in`

Default: `false`

If true, `=` is always replaced with `in` if part of a `for` loop condition.
For example, `for i = 1:10` will be transformed to `for i in 1:10`. Set
this to `nothing` to leave the choice to the user.

### `whitespace_typedefs`

Default: `false`

If true, whitespace is added for type definitions. Make this `true`
if you prefer `Union{A <: B, C}` to `Union{A<:B,C}`.

### `whitespace_ops_in_indices`

Default: `false`

If true, whitespace is added for binary operations in indices. Make this
`true` if you prefer `arr[a + b]` to `arr[a+b]`. Additionally, if there's
a colon `:` involved, parenthesis will be added to the LHS and RHS.

Example: `arr[(i1 + i2):(i3 + i4)]` instead of `arr[i1+i2:i3+i4]`.

### `remove_extra_newlines`

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

Modules are the only type of code block allowed to keep a single newline
prior to the initial or after the final piece of code.

### `import_to_using`

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

Exceptions:

If `as` is found in the import expression. `using` CANNOT be used in this context. The following example will NOT BE rewritten.

```julia
import Base.Threads as th
```

If `import` is used in the following context it is NOT rewritten. This may change in a future patch.

```julia
@everywhere import A, B
```

### `pipe_to_function_call`

Default: `false`

If true, `x |> f` is rewritten to `f(x)`.

### `short_to_long_function_def`

Default: `false`

Transforms a *short* function definition

```julia
f(arg1, arg2) = body
```

to a *long* function definition if the short function definition exceeds the maximum margin. Or
if `force_long_function_def` is set to `true`.

```julia
function f(arg2, arg2)
    body
end
```

### `force_long_function_def`
Default: `false`

If `true` tweaks the behavior of `short_to_long_function_def` to force the transformation no matter
how short the function definition is.

### `long_to_short_function_def`

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

### `always_use_return`

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

### `whitespace_in_kwargs`

Default: `true`

If true, `=` in keyword arguments will be surrounded by whitespace.

```julia
f(; a=4)
```

to

```julia
f(; a = 4)
```

An exception to this is if the LHS ends with "!" then even if `whitespace_in_kwargs` is
false, `=` will still be surrounded by whitespace. The logic behind this intervention being
on the following parse the `!` will be treated as part of `=`, as in a "not equal" binary
operation. This would change the semantics of the code and is therefore disallowed.

### `annotate_untyped_fields_with_any`

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

### `format_docstrings`

Default: `false`

Format code docstrings with the same options used for the code source.

Markdown is formatted with [`CommonMark`](https://github.com/MichaelHatherly/CommonMark.jl) alongside Julia code.

### `align_*`

Default: `false`

See `Custom Alignment` documentation.

### `conditional_to_if`

Default: `false`

If the conditional `E ? A : B` exceeds the maximum margin converts it into the equivalent `if` block:

```julia
if E
    A
else
    B
end
```

### `normalize_line_endings`

Default: `"auto"`

One of `"unix"` (normalize all `\r\n` to `\n`), `"windows"` (normalize all `\n` to `\r\n`), `"auto"` (automatically
choose based on which line ending is more common in the file).

### `trailing_comma`

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

### `trailing_zero`

Default: `true`

Add a trailing zero, if needed.

### `join_lines_based_on_source`

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

### `indent_submodule`

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

### `separate_kwargs_with_semicolon`

Default: `false`

When set to `true`, keyword arguments in a function call will be separated with a semicolon.

```julia
f(a, b=1)

->

f(a; b=1)
```

### `surround_whereop_typeparameters`

Default: `true`

Surrounds type parameters with curly brackets when set to `true` if the brackets are not
already present.

```julia
function func(...) where TPARAM
end

->

function func(...) where {TPARAM}
end
```

### `for_in_replacement`

Can be used when `always_for_in` is `true` to replace the default `in` with `∈` (`\\in`),
or `=` instead. The replacement options are `("in", "=", "∈")`.

```julia
for a = 1:10
end

# formatted with always_for_in = true, for_in_replacement = "∈"
for a ∈ 1:10
end
```

### `variable_call_indent` && `yas_style_nesting`

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

### `short_circuit_to_if`

You can convert short circuit expressions to the equivalent if expression.

```julia
function foo(a, b)
    a || return "bar"

    "hello"

    b && return "ooo"
end

BECOMES

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

### `disallow_single_arg_nesting`

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

## File Options

### `overwrite`

Default: `true`

If `true` the file will be reformatted in place, overwriting the existing file;
if it is `false`, the formatted version of foo.jl will not be written anywhere.

### `verbose`

Default: `false`

If `true` details related to formatting the file will be printed to `stdout`.

### `format_markdown`

Default: `false`

If `true`, Markdown files are also formatted. Julia code blocks will be formatted in
addition to the Markdown being normalized.

### `ignore`

An array of paths to files and directories (with possible Glob wildcards)
which will not be formatted.

## Special Format Comments

### Turn off/on formatting

You can skip sections of code by using the `#! format: off` and `#! format: on` comments.

```julia

# this should be formatted
a = f(aaa, bbb, ccc)

# this should not be formatted
#! format: off
a = f(aaa,
    bbb,ccc)

c = 102000

d = @foo 10 20

e = "what the foocho"
#! format: on

# this should be formatted
a = f(aaa, bbb, ccc)

# ok
```

If you wish to not format an entire file just add `#! format: off` to the top of the file.

### Stopping a block of code from indenting

Sometimes you may wish for a block of code to not be indented. You can achieve this with `#! format: noindent`.

```julia
begin
@muladd begin
    #! format: noindent
    a = 10
    b = 20
    begin
       # another indent
        z = 33
    end

    a * b
end
        end
```

is formatted to


```julia
begin
    @muladd begin
    #! format: noindent
    a = 10
    b = 20
    begin
        # another indent
        z = 33
    end

    a * b
    end
end
```

Notice the contents of `@muladd begin` is not indented.

`#! format: noindent` can also be nested.

## Editor Plugins

For integration with other editors:

  - [VSCode](https://github.com/singularitti/vscode-julia-formatter/)
  - [Emacs](https://codeberg.org/FelipeLema/julia-formatter.el)
  - [Vim](https://github.com/kdheepak/JuliaFormatter.vim)
  - [Atom (deprecated)](https://github.com/JunoLab/Atom.jl)
