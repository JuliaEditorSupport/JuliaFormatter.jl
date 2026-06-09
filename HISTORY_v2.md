# v2.6.12

Fixed a bug where a `;;` line continuation inside a space-separated row of a `vcat` or `ncat` expression (e.g. `[1 2 ;;\n 3 4 ; 2 3 4 5]`) had its newline removed, producing invalid code that mixed `;;` with space separators.

# v2.6.11

Fixed a bug where linebreaks were not preserved in the middle of a chain of binary operators when a comment was present (e.g. `a + # comment\n b + c`), causing any part of the chain after the comment to be lost. (#1076, #1077)

Fixed a bug where formatting `<:(X, Y)`, `<:(args...)`, or the equivalent with `>:` would fail. (#1078, #1079, #1077)

# v2.6.10

Fixed a bug where formatting `export` or `public` colon operators (e.g., `export +, :, -`) failed (DefaultStyle) or yielded incorrect indentation (YASStyle/SciMLStyle). (#1072, #1073, #1075)

# v2.6.9

Fixed a bug where formatting inline comments on their own line caused extra blank lines to be added. (#1070, #1071)

Slightly improved the separation of inline comments from code. (#1071)

# v2.6.8

Fixed a bug where end-of-line comments were being silently dropped in YASStyle. (#690, #1046, #1068)

Fixed a bug where the `trailing_comma` option was being ignored with YASStyle.
Prior to #1068 there was never a need for trailing commas at the end of a function argument list, since the closing parenthesis would always follow the final argument (and silently delete any comments in the way).
However, if the last argument has a comment after it, the closing parenthesis is forced to the next line.
This fix ensures that a trailing comma is inserted. (#1068)

# v2.6.7

Improve separation of inline comments from code. (#1064, #1065)

# v2.6.6

Fixed a bug where inline comments (e.g. `#= comment =#`) were being removed from source code. (#946, #1061)

Fixed a bug where `always_for_in` would convert tokens that were outside of its scope, silently changing the meaning of the code. (#905, #944, #1061)

Fixed a bug where macro invocations with do-blocks were formatted incorrectly. (#1018, #1061)

Improved documentation for the `always_for_in` and `trailing_comma` options, specifically around how to specify a value of `nothing` in `.JuliaFormatter.toml`. (#1061)

# v2.6.5

Fixed a bug where short-form function definitions which had string literals on the RHS were being incorrectly indented. (#1062, #1063)

Improved pretty-printing of `FST` struct. (#1063)

# v2.6.4

Fixed a bug where running JuliaFormatter on Julia v1.10 would error on syntax that was only valid in Julia v1.11, such as the `public` keyword. (#890, #1055)

# v2.6.3

Fixed a bug where formatting binary expressions with extraneous blank lines was not idempotent. (#1049, #1050)

Fixed a bug where formatting expressions with semicolons (e.g. `a1; a2`) inside a `try`/`catch` block was not idempotent. (#1051, #1050)

Improved the error message emitted when calling `JuliaFormatter.format()` with an invalid argument. (#830, #1047)

# v2.6.2

Re-enabled `always_use_return=true` for BlueStyle, in line with the Blue style guide. (#906, #1041)

# v2.6.1

Fixed a number of bugs where newlines in array literals were not being correctly handled, which caused JuliaFormatter to output invalid code (or worse!) silently different code. (#1029, #1037, #1038, #1039)

# v2.6.0

Fixed a number of cases where the left-hand operand of binary operators would be aggressively nested.
(In general, it is better to nest the right-hand operand as that keeps as much of the operation as possible on the same line.)
These fixes were applied to DefaultStyle and thus should propagate to other styles as well.
On top of this, SciMLStyle goes slightly further and also allows expressions to extend beyond the stated margin in the interests of not nesting the LHS. (#998, #1012)

Added a new formatting option, `sciml_margin_overrun`, which controls the extent to which SciMLStyle allows expressions to extend beyond the margin in order to avoid nesting the LHS of binary operators.
The default is 20, but it can be set to 0 to prevent this behaviour if undesired.
This option has no effect for styles apart from SciML. (#998)

# v2.5.6

Fixed a bug where JuliaFormatter would emit invalid code when parsing an `if`/`elseif` with a block condition (e.g. `(a; b)` or `begin ... end`). (#1025, #1026)

The same bug was present for `while` loops with similar block conditions.
Although Julia would still parse the code correctly, the output was ugly.
This PR therefore also fixes this. (#1026)

# v2.5.5

Fixed a number of issues with `pipe_to_function_call=true`:

- Various constructions such as `x .|> f()`, `x .|> !`, and `x |> a + b` were being transformed into code that had a different meaning from the original. (#927, #1023)

- Transforming pipes inside macros was fundamentally dangerous.
  This patch conservatively refuses to transform pipes inside macros. (#439, #1023)

- Transforming pipes inside an `Expr` changes the `Expr`.
  This patch prevents this. (#1023)

- The expression `1 .|> (sin, cos)` cannot be transformed into a function call as there is no equivalent syntax for this. This patch leaves such expressions unchanged. (#647, #1023)

- For the transformations that do happen, this patch elides unnecessary parentheses. For example `(x) |> f` is now transformed into `f(x)` rather than `f((x))`. (#1023)

- Fixed cases where newly transformed function calls would be generated with the wrong nesting, leading to a loss of idempotency. (#1023)

Finally, this patch also causes a warning to be emitted whenever a pipe is transformed into a function call. (#1023)

This is because `|>` is an ordinary Julia function, and can be overloaded by users such that `x |> f` may not always be equivalent to `f(x)`.
A formatter should _never_ change the meaning of code.
Thus, it is possible, or even likely, that this option will be completely removed in the future (it could be turned into a _linter_ rule, for example, where the user can be alerted to the presence of `|>` in their code; but the _formatter_ should not change it).

# v2.5.4

Fixed a bug where `jlfmt` would not use the style set in a `.JuliaFormatter.toml` configuration file (unless `--prioritize-config-file` was specified). (#951, #1021)

Fixed a bug where JuliaFormatter (both the library and app) would not correctly ignore files in subdirectories on Windows due to path separator differences. (#898, #1021)

# v2.5.3

Fixed a bug where postfix operators (e.g. transpose) were not being recognised as unary operators, causing formatting to output unparseable code in some circumstances. (#1011)

Improved consistency when parenthesising the value of a keyword argument with `whitespace_in_kwargs=false`, e.g., `(; x=-pi/2)` is now formatted as `(; x=(-pi/2))`. (#1011)

# v2.5.2

Fixed a bug where, under SciML style, indentations of bracketed expressions on the RHS of assignments were being removed for anything on the second line onwards. (#935, #1006)

# v2.5.1

Fix some formatting regressions introduced in v2.5.0. (#1002, #996)
In particular, this version:

- no longer aggressively adds spaces around `x=>y` and `x->y` (unless spaces are already present).
  This matches the behaviour of other operators e.g. `x+y`.
- no longer adds spaces around assignments in square brackets, for example `a[b=1]` is now left unchanged, rather than being changed to `a[b = 1]`.
- no longer adds parentheses around field access in ranges, for example `[1:a.b]` is now left unchanged, rather than being changed to `[1:(a.b)]`.

Some of these may be configurable in the future.

# v2.5.0

Added compatibility with JuliaSyntax@1.

# v2.4.0

Added the `--threads=auto` option to the old `julia-formatter` pre-commit hook, which should speed up invocations of JuliaFormatter.

Added a new pre-commit hook which uses the `jlfmt` executable.
To use this, you will need to first install `jlfmt` with

```julia
] app add JuliaFormatter
```

Please see [the docs](https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/integrations/) for more information.

# v2.3.3

Fixed a bug with alignment of multiline strings when the first line contains characters whose display width is not equal to the number of bytes.

# v2.3.2

Added compatibility with CommonMark@1.

# v2.3.1

Fixed a bug which caused `jlfmt --threads=N` to fail for `N > 1`.

Fixed a bug with alignment of `=` characters in lines with zero-width characters.
