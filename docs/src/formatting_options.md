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

Note that, although styles each define a different set of options, they are not _just_ collections of options; they also have unique formatting rules that are not captured by the options.

## A note about options

Not all options are created equal.
This section is intended to help you understand the implications of enabling certain options.

### Syntax transformations

**Some of the options below are more dangerous than others, because they perform syntax transformations** (i.e., `Meta.parse(format_text(s))` may not be equal to `Meta.parse(s)`).
These options can therefore change the meaning of the code being formatted depending on the context, and should be used with caution.

To help you identify dangerous options, there is an emoji legend in the 'Kind' column:

- 📐: purely about whitespace
- ♻️: syntax normalisation — this does more than just whitespace as it can insert e.g. parentheses, but it does not change the AST in any way
- ⚠️: syntax transformation — this does change the AST, but the transformations are conservatively scoped and thus should be safe
- 🔥: dangerous syntax transformation — this can change the AST, and it is not actually possible to be conservative because that would defeat the entire purpose of the option.

Currently, only [**`pipe_to_function_call`**](@ref options-pipe-to-function-call) is in the last category.
**Note that YASStyle and BlueStyle both enable `pipe_to_function_call` by default, so if you use either of those styles, you should be aware that this can change the meaning of your code!**

As a guard against unwanted syntax transformations, by default, JuliaFormatter does not perform any syntax transformations inside macros or Exprs.

This can be overly cautious in some cases: many macros, such as `@test` and `@inline`, are completely agnostic to their contents.
If you want to enable selected syntax transformations inside macros, you can [set `transform_syntax_in_macros` to `true`](@ref options-transform-syntax-in-macros).
However, there is no option to enable syntax transformations inside `Expr`s as that changes the literal meaning of the `Expr`.

### Options that can spoil idempotence

Some of the options below additionally have the potential to cause non-idempotent formatting if enabled (or, in the case of [`v2_stable_multiline_strings`](@ref options-v2-stable-multiline-strings), if disabled).
They are marked with a 🪃 emoji.

If you want to ensure idempotence, it is recommended to disable these options.
If you absolutely must enable them, you may need to run the formatter multiple times to reach a fixed point: you can use the [`max_iterations`](@ref options-max-iterations) option to control the number of passes JuliaFormatter will do.

| Option                                                                              | Kind  | Default   | YAS         | Blue        | SciML        | Minimal       |
| :-------                                                                            | ----- | --------- | -----       | ------      | -------      | ---------     |
| [`align_assignment`](@ref options-align-star)                                       | 📐    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`align_conditional`](@ref options-align-star)                                      | 📐    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`align_matrix`](@ref options-align-matrix)                                         | 📐    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`align_pair_arrow`](@ref options-align-star)                                       | 📐    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`align_struct_field`](@ref options-align-star)                                     | 📐    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`always_for_in`](@ref options-always-for-in)                                       | ♻️    | `false`   | **`true`**  | **`true`**  | **`true`**   | **`nothing`** |
| [`always_use_return`](@ref options-always-use-return)                               | ⚠️    | `false`   | **`true`**  | **`true`**  | `false`      | `false`       |
| [`annotate_untyped_fields_with_any`](@ref options-annotate-untyped-fields-with-any) | ⚠️    | `true`    | `true`      | **`false`** | `true`       | **`false`**   |
| [`conditional_to_if`](@ref options-conditional-to-if)                               | 🪃 ♻️ | `false`   | `false`     | **`true`**  | `false`      | `false`       |
| [`disallow_single_arg_nesting`](@ref options-disallow-single-arg-nesting)           | 📐    | `false`   | `false`     | `false`     | **`true`**   | `false`       |
| [`for_in_replacement`](@ref options-for-in-replacement)                             | ♻️    | `"in"`    | `"in"`      | `"in"`      | `"in"`       | `"in"`        |
| [`force_long_function_def`](@ref options-force-long-function-def)                   | ⚠️    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`format_docstrings`](@ref options-format-docstrings)                               | ⚠️    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`import_to_using`](@ref options-import-to-using)                                   | ⚠️    | `false`   | **`true`**  | **`true`**  | `false`      | `false`       |
| [`indent`](@ref options-indent)                                                     | 📐    | `4`       | `4`         | `4`         | `4`          | `4`           |
| [`indent_submodule`](@ref options-indent-submodule)                                 | 📐    | `false`   | `false`     | **`true`**  | `false`      | `false`       |
| [`join_lines_based_on_source`](@ref options-join-lines-based-on-source)             | 📐    | `false`   | **`true`**  | `false`     | **`true`**   | **`true`**    |
| [`long_to_short_function_def`](@ref options-long-to-short-function-def)             | ⚠️    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`margin`](@ref options-margin)                                                     | 📐    | `92`      | `92`        | `92`        | `92`         | **`10_000`**  |
| [`max_iterations`](@ref options-max-iterations)                                     |       | `1`       | `1`         | `1`         | `1`          | `1`           |
| [`normalize_line_endings`](@ref options-normalize-line-endings)                     | 📐    | `"auto"`  | `"auto"`    | `"auto"`    | **`"unix"`** | `"auto"`      |
| [`pipe_to_function_call`](@ref options-pipe-to-function-call)                       | 🪃 🔥 | `false`   | **`true`**  | **`true`**  | `false`      | `false`       |
| [`remove_extra_newlines`](@ref options-remove-extra-newlines)                       | 📐    | `false`   | **`true`**  | **`true`**  | **`true`**   | `false`       |
| [`sciml_margin_overrun`](@ref options-sciml-margin-overrun)                         | 📐    | unused    | unused      | unused      | **`20`**     | unused        |
| [`separate_kwargs_with_semicolon`](@ref options-separate-kwargs-with-semicolon)     | ⚠️    | `false`   | **`true`**  | **`true`**  | `false`      | `false`       |
| [`short_circuit_to_if`](@ref options-short-circuit-to-if)                           | ⚠️    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`short_to_long_function_def`](@ref options-short-to-long-function-def)             | ⚠️    | `false`   | **`true`**  | **`true`**  | **`true`**   | `false`       |
| [`surround_whereop_typeparameters`](@ref options-surround-whereop-typeparameters)   | ♻️    | `true`    | `true`      | `true`      | `true`       | **`false`**   |
| [`trailing_comma`](@ref options-trailing-comma)                                     | ♻️    | `true`    | `true`      | `true`      | **`false`**  | **`nothing`** |
| [`trailing_zero`](@ref options-trailing-zero)                                       | ♻️    | `true`    | `true`      | `true`      | `true`       | **`false`**   |
| [`transform_syntax_in_macros`](@ref options-transform-syntax-in-macros)             | ⚠️    | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`v2_stable_multiline_strings`](@ref options-v2-stable-multiline-strings)           | 🪃 📐 | `false`   | `false`     | `false`     | `false`      | `false`       |
| [`variable_call_indent`](@ref options-variable-call-indent)                         | 📐    | `[]`      | `[]`        | `[]`        | `[]`         | `[]`          |
| [`whitespace_in_kwargs`](@ref options-whitespace-in-kwargs)                         | 📐    | `true`    | **`false`** | **`false`** | `true`       | **`false`**   |
| [`whitespace_ops_in_indices`](@ref options-whitespace-ops-in-indices)               | 📐    | `false`   | **`true`**  | **`true`**  | **`true`**   | `false`       |
| [`whitespace_typedefs`](@ref options-whitespace-typedefs)                           | 📐    | `false`   | `false`     | `false`     | **`true`**   | `false`       |
| [`yas_style_nesting`](@ref options-yas-style-nesting)                               | 📐    | `false`   | `false`     | `false`     | `false`      | `false`       |

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

If `true`, iterators e.g. in `for` loops will always be formatted with `in` instead of `=`.
The default replacement is `in`, but this can be changed with the [`for_in_replacement`](@ref options-for-in-replacement) option.
For example, to replace all `=` and `in` with `∈` in iterators, set `for_in_replacement` to `"∈"`.

If `false`, JuliaFormatter still performs a very specific normalisation: for *range iterators*, e.g. `for i = 1:10`, JuliaFormatter uses `=`.
For all other iterators, `in` is used.

If `nothing`, the choice between `in` and `=` is left to the user, and no normalisation is performed.

!!! Setting an option to `nothing` in .JuliaFormatter.toml
    TOML does not have a null value. To specify a `nothing` value in a `.JuliaFormatter.toml` file, set the option to the string `"nothing"`, e.g. `always_for_in = "nothing"`.

## [`always_use_return`](@id options-always-use-return)

Default: `false`

If true, `return` will be prepended to the last expression in function definitions, macro definitions, and do blocks.

For example:

```@example always-use-return
s = """
function foo()
    expr1
    expr2
end"""

using JuliaFormatter: format_text
format_text(s; always_use_return=true) |> println
```

A number of cases are skipped over:

- If the final expression is (already) `return`.
- If the final expression is a macro.
- If the final expression is a multiline block expression (e.g. `if...end`, `begin...end`, etc.). This includes calls with do blocks.
- If the final expression contains a `return` statement somewhere in it (e.g. `cond ? (return 1) : (return 2)`).
- If the final expression has a docstring attached to it.

Note that `return` *is* prepended to calls to functions such as `throw(...)`  and `error()`.
If you don't want this behaviour, add a `return nothing` at the end of the function (or just disable this option!).
Click the "Show explanation" toggle below for a more detailed explanation of why I choose *not* to do this.
(You may also be interested in [the corresponding discussion on Runic.jl](https://github.com/fredrikekre/Runic.jl/issues/202), which has the same behaviour.)

!!! details "Show explanation for always_use_return"

    There are several reasons why I don't want to carve out an exception for `throw(...)`.

    The first is pragmatic.
    Previous versions of JuliaFormatter implemented `always_use_return` at the FST level, that is to say, it would construct an `FST` and *then* insert `return` in (usually...) the right place.
    This, however, causes idempotence issues because the formatting of the return value can depend on whether it is prepended with `return` or not.
    In other words, formatting choices are already baked into the FST before the `return` is inserted, and on the second formatting pass, the formatting choices may be different, which can lead to non-idempotence!

    To fix these bugs I moved the return insertion one stage prior, so that the FST is constructed *with* the `return` keyword from the start.
    However, this means that we don't have easy access to the identifier `throw`, not without a lot of incredibly finicky code to extract the CST node and then count the offsets carefully to find the identifier in the source text.

    While I *could* have implemented this, I'm unwilling to because of the second reason, which is more philosophical.
    I don't even really agree that `throw()` should be exempt from `return`.
    Firstly, `throw()` *does* have a type: it's `Union{}`, which is [a bottom type](https://en.wikipedia.org/wiki/Bottom_type).
    Sure, that type cannot be inhabited, i.e., there's no actual value that belongs to that type.

    However, from a theoretical point of view there's absolutely nothing wrong with "return"ing something that has type `Union{}`.
    It is vacuous, much like saying "select an element from an empty set", but that doesn't mean it's *wrong*; it's just *meaningless*.

    Furthermore, Julia's semantics are that the last statement in a block is the value it evaluates to.
    (This is not unique to Julia: see e.g. Haskell / OCaml / Rust.)
    If `throw(...)` could not be treated as a value, then following that logic, `throw()` should not even be *allowed* to be the last statement in a block.
    But clearly it can be!
    Correspondingly, there's no reason why returning it is wrong.

    The last reason is that it is impossible at the syntax level to determine what expressions are guaranteed to throw an exception (or more generally, what expressions are guaranteed to not return a value).
    For example, if we special-case `throw`, then one could argue that we should also special-case qualified calls like `Base.throw`, and other functions like `error` and `exit`, and then user-defined functions like

    ```julia
    mythrow(x) = throw("error: \$x")
    ```

    or constructs like

    ```julia
    function f()
        do_other_stuff()
        f()  # This never returns, so maybe we shouldn't add return?!
    end
    ```

    Obviously it doesn't make any sense to special-case any of that, so the only *principled* approach is not to special-case anything.
    I don't believe that JuliaFormatter should have an exception list that claims to do the right thing but cannot.

    Indeed, even if we could perform semantic analysis on the programme, it's not possible to determine such cases, because answering the question 'does this expression return a value' amounts to solving the halting problem.

## [`annotate_untyped_fields_with_any`](@id options-annotate-untyped-fields-with-any)

Default: `true`

Annotates fields in a type definitions with `::Any` if no type annotation is provided:

```@example annotate-untyped-fields-with-any
s = """
struct A
    arg1
end
"""

using JuliaFormatter: format_text
format_text(s; annotate_untyped_fields_with_any=true) |> println
```

## [`conditional_to_if`](@id options-conditional-to-if)

Default: `false`

If a ternary expression exceeds the margin, convert it into the equivalent `if` block:

```@example conditional-to-if
s = "cond ? trueval : falseval"

using JuliaFormatter: format_text
format_text(s; margin=20, conditional_to_if=true) |> println
```

!!! warning "Enabling this can cause lack of idempotence"
    
    Enabling `conditional_to_if` can cause non-idempotent formatting, because the `if` block may trigger different formatting choices compared to the ternary.

    For more details, click on the "Show explanation" toggle below.

!!! details "Show explanation for conditional_to_if"

    Here is an example of non-idempotence.
    As you can see it is very easy to trigger!

    ```@example conditional-to-if
    s = "foo(cond ? trueval : falseval)"
    length(s)
    ```

    Let's format this with a margin of 28.
    (Obviously, this is smaller than typical real-world margins; but this is chosen for the purposes of simplicity.
    With a margin of 92, you can still hit such cases easily with longer expressions, variable names, or indentation—basically, with real-world code!)

    On the first pass, two things happen:

    1. The function call's arguments are nested because the length of the arguments (including the ternary) exceeds the line margin.

    2. This at first leads to something like

       ```julia
       foo(
           cond ? trueval : falseval,
       )
       ```

       (this string itself is never materialised, but there is an intermediate data structure that essentially represents this).
       Now, because the ternary itself is still over the margin, the ternary is converted to `if...end`.

    Collectively, these steps give us the formatting of the first pass:

    ```@example conditional-to-if
    out1 = format_text(s; margin=28, conditional_to_if=true)
    println(out1)
    ```

    On the second time we format, the function call `foo(...)` sees that it has only one argument which is a block, and thus collapses the nesting (the logic being that the argument can handle the line-breaking itself):

    ```@example conditional-to-if
    out2 = format_text(out1; margin=28, conditional_to_if=true)
    println(out2)
    ```

    Fundamentally, the issue is that formatting choices for the function call `foo(...)` depend on whether or not the ternary is expanded or not, but by the time the ternary is expanded, the function call has already been formatted.

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

If `true`, tweaks the behavior of [`short_to_long_function_def`](@ref options-short-to-long-function-def) to force the transformation no matter how short the function definition is.

## [`format_docstrings`](@id options-format-docstrings)

Default: `false`

Format code docstrings with the same options used for the code source.

Markdown is formatted with [`CommonMark`](https://github.com/MichaelHatherly/CommonMark.jl) alongside Julia code.

## [`import_to_using`](@id options-import-to-using)

Default: `false`

If true, `import` expressions are rewritten to equivalent `using` expressions:

```@example import-to-using
s = """
import A
import B, C, D"""

using JuliaFormatter: format_text
format_text(s; import_to_using=true) |> println
```

There are some exceptions to this, which makes this transformation quite conservative:

- This transformation is disabled inside macros or `Expr`s.

- `import X as Y` cannot be rewritten in a semantically equivalent way, so is skipped.

- `import A.b` cannot be properly resolved (it may either be `using A: b` or `using A.b: b`), so is skipped.

- `import ..X` cannot be rewritten because `X` may not necessarily be a module.
  See e.g. [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/723).

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

## [`max_iterations`](@id options-max-iterations)

Default: `1`

JuliaFormatter is *intended* to be idempotent, meaning that formatted code should not change if formatted again.
However, with certain options enabled, this may not be the case.
(Please see the top of this page for more information!)

This option exists in order to allow you to perform multiple rounds of formatting, if you wish to.
Note that this will cause formatting to be slower.
JuliaFormatter will format the code up to `max_iterations` times, stopping if the code is unchanged after a formatting pass.

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

!!! warning "This option may cause non-idempotent formatting"

    Enabling `pipe_to_function_call` can cause non-idempotent formatting, because the function call may trigger different formatting choices compared to the pipe.
    See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1175) for an example.

    *In principle*, this can be fixed, since we can determine ahead of time when the pipe will be transformed into the function call.
    However, my current judgment is that this is not really worth it since it would make the codebase more complex and brittle.
    On top of that, it's probably not a good idea to enable `pipe_to_function_call` anyway.

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

```@example separate-kwargs-with-semicolon
s = "f(a, b = 1)"

using JuliaFormatter: format_text
format_text(s; separate_kwargs_with_semicolon=true) |> println
```

This transformation is disabled in several cases:

- Inside macros or `Expr`s.
- In the signature of a function definition. For example, these are different:

  ```julia
  function f(a, b = 1)  # b is an optional positional argument
      body
  end

  function f(a; b = 1)  # b is a keyword argument
      body
  end
  ```

- When the function call does not have a semicolon, but has positional arguments after keyword arguments.
  For example, `f(p, q=r, s)` is not transformed.
  See [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/625) for details.

## [`short_circuit_to_if`](@id options-short-circuit-to-if)

If `true`, converts logical operators to the equivalent if-expression, if it is clear that the value is not used.

In particular, `a && f()` is converted to `if a; f(); end`, and `a || f()` is converted to `if !a; f(); end`.

```@example short-circuit-to-if
s = """
function foo(a, b)
    a || return "bar"
    b && return "ooo"
    return 5
end"""

using JuliaFormatter: format_text
format_text(s; short_circuit_to_if=true) |> println
```

In general these are only converted if they are a top-level statement inside a block.
If the value of the logical operator is in any way used, it will not be converted.
These include:

- Conditions in `if`, `elseif`, and `while` statements.
- The value being assigned to a variable or otherwise being part of some expression.
- The value being returned (including implicitly, by being the last statement in a block).

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

This transformation is disabled inside macros or `Expr`s.

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

!!! Setting an option to `nothing` in .JuliaFormatter.toml
    TOML does not have a null value. To specify a `nothing` value in a `.JuliaFormatter.toml` file, set the option to the string `"nothing"`, e.g. `always_for_in = "nothing"`.

## [`trailing_zero`](@id options-trailing-zero)

Default: `true`

Add a trailing zero, if needed.

## [`transform_syntax_in_macros`](@id options-transform-syntax-in-macros)

Default: `false`

If `true`, the following syntax transformations will be permitted inside macros (if the corresponding option has been enabled):

- [`always_use_return`](@ref options-always-use-return)
- [`annotate_untyped_fields_with_any`](@ref options-annotate-untyped-fields-with-any)
- [`import_to_using`](@ref options-import-to-using)
- [`long_to_short_function_def`](@ref options-long-to-short-function-def)
- [`short_circuit_to_if`](@ref options-short-circuit-to-if)
- [`short_to_long_function_def`](@ref options-short-to-long-function-def)

The following syntax transformations will *not* be permitted inside macros, even if `transform_syntax_in_macros` is true:

- [`pipe_to_function_call`](@ref options-pipe-to-function-call)
- [`separate_kwargs_with_semicolon`](@ref options-separate-kwargs-with-semicolon)

For example, `always_use_return` does not fire inside a macro by default:

```@example transform-syntax-in-macros
s = """
@macro function f()
    1
end"""

using JuliaFormatter: format_text
format_text(s; always_use_return=true) |> println
```

However, if `transform_syntax_in_macros` is set to `true`, then it does:

```@example transform-syntax-in-macros
format_text(s; always_use_return=true, transform_syntax_in_macros=true) |> println
```

## [`v2_stable_multiline_strings`](@id options-v2-stable-multiline-strings)

Default: `false`

If `true`, changes the nesting behaviour for multiline strings to guarantee idempotence on formatting.

In general, setting this option to `true` will cause multiline strings to be indented more to the right; equivalently, setting it to `false` will cause multiline strings to be shifted onto new lines more easily.
**However, note that this option is not intended to primarily be used as a way to control indentation of multiline strings.**
Its primary purpose is to guarantee idempotence; the indentation differences are a side effect which are documented here for users' awareness.

Here is an example of the different output that can be produced by the two settings.
This is with the default value of `false`:

```@example stable-multiline
s = """
throw(ArgumentError(\"""
                    ooohhhhhh a very long thing
                    \"""))
"""

using JuliaFormatter: format_text
format_text(s; margin=46, v2_stable_multiline_strings=false) |> println
```

But when `v2_stable_multiline_strings` is set to `true`, the output is:

```@example stable-multiline
format_text(s; margin=46, v2_stable_multiline_strings=true) |> println
```

If that description is enough for you, feel free to not read on.

However, a rather long explanation (it is a complicated issue!) is included for the curious reader.
Click on the "Show explanation" toggle below to read it.

!!! details "Show explanation for v2_stable_multiline_strings"

    We begin by introducing an example of non-idempotence:

    ```@example stable-multiline
    s = """
    foooo((\"""
    12345\""", g),
        a, b)
    """
        
    s |> println
    ```

    Formatting once:

    ```@example stable-multiline
    using JuliaFormatter: format_text
    format_text(s; margin=21) |> println
    ```

    And formatting twice:

    ```@example stable-multiline
    format_text(format_text(s; margin=21); margin=21) |> println
    ```

    What on earth is going on here?!
    When JuliaFormatter decides whether or not to insert line breaks between arguments, it does so based on the _sum of the 'length's of the arguments_.
    That is, for example, `f(a, b, c)` is ten characters long.
    If `margin < 10`, then JuliaFormatter will opt to move `a`, `b`, and `c` onto their own lines.

    'Length's of most arguments are calculated very straightforwardly by calling `length()`. (Note that this should **really** be `textwidth()`: this is a known issue with JuliaFormatter, which will be fixed in a future version.)

    The 'length' of a multiline string, with `v2_stable_multiline_strings = false`, is the _greatest extent to which any line extends past the column before the opening quote of the string_.
    For example, in the string below, the opening `"""` begins at column 6, so the column before it is 5.
    The "length" of the string is the greatest extent to which any line extends past column 5.
    From the numbers below we can see that this is 7.

    ```
         """4
    000001234
        01234567
       """
    ```

    Cool.
    Now returning to our input text

    ```@example stable-multiline
    s |> println
    ```

    the second line ends _before_ the end of the opening `"""`, so the 'length' of the multiline string is 3 (which corresponds to the triple quotes in the _first_ line).
    If you sum the lengths up you should find that the total length of the arguments is 21 — exactly equal to the margin we used.
    So when JuliaFormatter looks at the **outer** call to `foooo(...)`, it decides that it *doesn't* need to nest its arguments, in other words we can do `foooo((...), a, b)` instead of `foooo(\n    (...),\n    a,\n    b,\n)`:

    ```@example stable-multiline
    format_text(s; margin=21) |> println
    ```

    As expected, `a` and `b` are also kept on the same line.

    To be honest, this logic doesn't really make a lot of sense to me.
    The total 'length' being 21 here is not really a meaningful metric because the arguments to `foooo(...)` would never go on the same line anyway!
    The treatment of multiline strings will probably be reworked a future version.

    Okay, so far so good.
    The problem begins with the fact that for the **inner** tuple, it sees that it has a multiline string as an argument, and because of this it will force line breaks *inside* the tuple.
    (In general, any block-like argument, e.g. `if...else...end` or `begin...end` will force nesting.)
    That's why the first output causes the multiline string and `g` to be moved onto separate lines.

    So far so good, but if we now look at that output, the opening triple quotes have been moved down into a new line.
    **The line below it, `12345"""`, now extends *beyond* the opening triple quote!**
    And so the 'length' of the multiline string is now 4, which causes the entire expression to be over the margin, and the next formatting pass will cause the outer `foooo(...)` call to also be nested.

    ```@example stable-multiline
    format_text(format_text(s; margin=21); margin=21) |> println
    ```

    `v2_stable_multiline_strings = true` fixes this by changing the way the 'length' of a multiline string is calculated.
    With this option enabled, the 'length' is always simply the length of the first line.
    In the example above, this is 3, i.e., just the triple quotes.
    Because of this, the outer call is never nested, and the output looks like:

    ```@example stable-multiline
    kw = (margin=21, v2_stable_multiline_strings=true)
    format_text(s; kw...) |> println
    ```

    Importantly, though, this option means that regardless of how the multiline string is indented, the 'length' will always be constant.
    So, the decision of whether or not to nest the arguments will be consistent across multiple formatting passes.

    ```@example stable-multiline
    format_text(s; kw...) == format_text(format_text(s; kw...); kw...)
    ```

    From the description above, it follows that the 'length' of the multiline string with `v2_stable_multiline_strings = true` is always less than or equal to the 'length' with `v2_stable_multiline_strings = false` (since the former only inspects the first line, whereas the latter takes a maximum over all lines).

    This means that `v2_stable_multiline_strings = true` will reduce the amount of line breaks, at the cost of subsequent lines of the multiline string potentially extending past the margin.
    Returning to the example at the start of this section:

    ```@example stable-multiline
    s = """
    throw(ArgumentError(\"""
                        ooohhhhhh a very long thing
                        \"""))
    """

    # multiline string's 'length' is 27, hence over margin
    format_text(s; margin=46, v2_stable_multiline_strings=false) |> println
    ```

    ```@example stable-multiline
    # multiline string's 'length' is 3, hence under margin
    format_text(s; margin=46, v2_stable_multiline_strings=true) |> println
    ```

    I will happily admit that this is *not* principled either!
    In general, the decision of whether or not to nest arguments when a multiline string is present is more complicated than just looking at the 'length' of the arguments.

    If we take a step back, the broader problem is that the outer call to `foooo(...)` is making formatting decisions without any knowledge of how its children are going to be nested, which could itself change the decisions that `foooo(...)` makes.
    This means that instead of exploring the full space of possible formatting outputs, where nesting decisions in parent and child nodes are coupled, JuliaFormatter is decomposing this into two 'local' decisions: one for the parent and one for the child.
    In many cases these can be fully decoupled, but in this case it can't; furthermore, even though decoupling does not actually ruin idempotence in many other cases, it can still lead to suboptimal formatting (which makes sense -- after all we're trying fewer possibilities).
    *Fixing this properly therefore requires a complete rethink of the formatting algorithm.*
    If you're interested in *that*, see e.g. [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1104).

## [`variable_call_indent`](@id options-variable-call-indent)

Default: `[]`

The `SciMLStyle` supports the additional option `variable_call_indent`.
It permits continuation lines in calls to not align with the opening parenthesis.

For example, if `variable_call_indent = ["Dict"]`, the following is allowed:

```julia
Dict{Int, Int}(
    1 => 2,
    3 => 4)
```

(Note that in the configuration, `"Dict"` must be passed as a string: this is because JuliaFormatter matches it against the name of the function being called.)

If `variable_call_indent` is empty, the above will be formatted to

```julia
Dict{Int, Int}(1 => 2,
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
