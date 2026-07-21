# v2.11.0

Added a new formatting option, `enforce_triplequoted_docstrings`, which controls whether single-quoted docstrings are expanded to triple-quoted docstrings.
By default this option is `true`, which is consistent with preexisting behaviour.
This option is only relevant if `format_docstrings` is also `true` (otherwise docstrings will always be ignored). (#1203, #1204)

When encountering invalid Julia code in docstrings JuliaFormatter will avoid formatting the code instead of crashing. (#1206, #1207)

When invalid formatting options are passed to `format_text()` and similar functions, JuliaFormatter now emits an info message.
(Note that for the CLI, specifying invalid arguments will cause an error.) (#1205, #1213)

# v2.10.2

Documentation improvements only.

# v2.10.1

Improve handling of inline comments at the top-level of a block. (#1194, #1195)

# v2.10.0

Added a new formatting option, `max_iterations`, which controls the number of rounds of formatting that JuliaFormatter will apply.
This is a way to suppress non-idempotent formatting, at the cost of poorer performance.
Note that in principle this should not be necessary as ideally JuliaFormatter would produce idempotent formatting in a single pass.
However, depending on the style and options being used, this is not always possible.
This defaults to 1 for most styles, and 4 for SciMLStyle (note that this is pre-existing behaviour, but now it can be configured). (#1181, #1182)

Disabled syntax transformations inside macros and `Expr` objects by default.
Syntax transformations can never happen inside `Expr` objects because that causes the resulting `Expr` to be different from the original.
For macros, JuliaFormatter errs on the side of caution and does not apply syntax transformations inside macros, since macros can inspect and transform the code that is passed to them, and changing this code can lead to the macro performing different things.
There is a new formatting option, `transform_syntax_in_macros`, which can be set to `true` to re-enable syntax transformations inside macros if desired. (#1124, #1187)

Fixed a bug where whitespace around binary operators was not being respected, leading to a change in the meaning of the code. (#788, #1188)

Fixed a bug where Blue and YAS styles would over-aggressively un-nest contents, leading to comments being joined with source code. (#922, #1189)

# v2.9.4

Fixed several instances where JuliaFormatter would use `length()` instead of `textwidth()`, leading to incorrect or non-idempotent formatting when non-ASCII characters were present. (#1166, #1167)

Fixed a bug where array literals inside other array literals would have their meaning changed when formatted. (#1168, #1169)

Fixed a bug where formatting an empty function definition would be non-idempotent or delete comments.
This was a similar bug to #1153, fixed in v2.9.2. (#1170, #1171)

Fixed a bug where if a multiline comment was followed immediately by an end-of-line comment, the end of the multiline comment would be deleted. (#1172, #1173)

Fixed a bug where logical operators inside ternary expressions would be incorrectly formatted when the ternary expression was expanded. (#1177, #1178)

Fixed a bug where `separate_kwargs_with_semicolon` would yield incorrect output if the first line of the function call was a comment. (#1179, #1180)

# v2.9.3

Fixed a bug where even if Windows line endings were specified (either via `normalize_line_endings="windows"` or if the original file had Windows line endings), calling `format()` on the file would still append a final Unix trailing newline to the file. (#1156)

Improved the output of `jlfmt --diff` to show the full name of the file being formatted, instead of just the base name. (#1152, #1157)

Fixed a bug where expansion of chained ternary expressions with BlueStyle would cause incorrect indentation for parenthesised blocks (e.g. `(p; q)`). (#1159, #1158)

Fixed a bug where defining a function such as `-(x) = ...` (where the function is an operator, and there is only one argument) would cause `separate_kwargs_with_semicolon` to _not_ be triggered for the first function call on the RHS of the function definition. (#1161, #1158)

Fixed a bug where macros with dots would be incorrectly formatted, e.g. `Base.@.` would be transformed to `Base..@`. (#1163, #1164)

# v2.9.2

Fixed a bug where `pipe_to_function_call` would remove parentheses from the argument of a function call even if the argument was an assignment, changing the meaning of the code. (#1147, #1148)

Fixed a bug where BlueStyle formatting of array literals which exceeded the margin was not idempotent. (#1149, #1150)

Fixed a bug where `short_to_long_function_def` would not apply the correct indentation to the function body, leading to non-idempotent formatting. (#1127, #1151)

Fixed a bug where formatting a `begin ... end` block that had nothing but whitespace or comments inside it would be non-idempotent, or delete comments inside it. (#1153, #1154)

# v2.9.1

Fixed a bug where `separate_kwargs_with_semicolon` would cause a change in the meaning of function calls such as `f(p, q=r, s)`. (#625, #1141)

Fixed a bug where `separate_kwargs_with_semicolon` would not be triggered in certain cases, for example in the RHS of a short-form function definition, or in the default values of a function definition.
This bug also led to lack of idempotence in a number of cases (e.g. when a short-form function definition `f(x, y) = g(x, y=z)` was expanded to a long-form function definition, the second pass would then reformat the body of the function). (#1133, #1140, #1141)

Fixed a bug where comments in chained ternary expressions were not being handled correctly when expanded with BlueStyle, leading to invalid Julia code. (#1142, #1143)

Fixed a bug where keyword argument names that were operators were not being parenthesised when `whitespace_in_kwargs = false`, leading to invalid Julia code. (#1144, #1145)

Fixed a bug where `short_to_long_function` would trigger even inside macros or `Expr` objects, leading to a change in the meaning of the code. (#1124, #1145)

Fixed a bug where `import_to_using` would be triggered inside macros or `Expr` objects, leading to a change in the meaning of the code. (#1124, #1146)

Fixed a bug where `import_to_using` would be triggered for relative imports (e.g. `import ..x, ..y`), leading to a change in the meaning of the code.
This was previously fixed for single imports (e.g. `import ..x`), but not for multiple imports (e.g. `import ..x, ..y`). (#664, #723, #1146)

# v2.9.0

Improved CLI exit codes (and error messages):

 - if the app errors, returns 2
 - if `--check` is enabled and files are not currently formatted, returns 1
 - if `--check` is enabled and files are already formatted, returns 0
 - otherwise returns 0.

Deprecated `format_file(args...; kwargs...)`; `format(args...; kwargs...)` has exactly the same behaviour and can be used as a drop-in substitute. (#1137)

Added missing formatting options to the CLI app (previously only a subset of these could be specified on the command line). (#1135)

For all old formatting options, added aliases that used hyphens instead of underscores, and expect the actual value on the right-hand side of the `=` sign.
For example, what was previously `--always_use_return` and `--no-always_use_return` should now be specified as `--always-use-return=true` and `--always-use-return=false`.
This is done to improve consistency with `.JuliaFormatter.toml` and also generalisability to other types of options.
The underscore versions are still supported for backwards compatibility, but the hyphenated versions should be preferred going forwards. (#1135)

For all formatting options that require a value (e.g. `--margin=80`), also allow the value to be space-separated (i.e. `--margin 80`). (#1135)

Added an `--ignore-config` option to the CLI app, which will ignore any `.JuliaFormatter.toml` files and use only the options specified on the command line. (#1135)

Added a `throw_on_error` keyword argument to `JuliaFormatter.format()`, which causes any formatting errors to propagate to the caller. (#1130, #1136, #1138)

# v2.8.5

Fixed more bugs where BlueStyle's chained-ternary-to-if conversion would lead to loss of idempotence. (#1131, #1132)

# v2.8.4

Disabled `short_circuit_to_if` for `x && y` and `x || y` statements at the end of a block (since the value of the expression is in fact being used).
This includes if there is a comment at the end of the function. (#887, #1129, #1128)

Fixed a bug where `x && y` would be expanded to `if x; y; end` with `short_circuit_to_if=true` even when the value of `x && y` was being used (e.g. as an argument to a function call), which would change the meaning of the code if `x` was false. (#1123, #1122)

Fixed a bug where indentation of `x && y` and `x || y` expressions were overly context-sensitive, leading to inconsistent and sometimes non-idempotent formatting. (#1121, #1122)

Fixed a bug where `always_use_return` would sometimes cause lack of idempotence.
(Note however that this option can still cause lack of idempotence *if and only if* combined with `short_to_long_function_def`.)
Furthermore, as a consequence of this fix, `return` *will* get prepended to `throw(...)` if that is the final expression in the function.
This differs from previous behaviour: if you do not want this, consider adding `return nothing` at the end of your function after the `throw(...)` statement, or just disable the `always_use_return` option. (#1125, #1128)

# v2.8.3

Fixed a bug where formatting of ranges (e.g. `a:b`) was not idempotent when either side was being parenthesised. (#1118, #1119)

Extended the v2.8.2 bugfix for parenthesised callers to include function definitions with `where` clauses. (#1114, #1119)

# v2.8.2

Fixed a bug where JuliaFormatter would insert newlines around a parenthesised caller in a function definition, causing the function to be parsed differently on Julia 1.12.
This is probably a Julia bug and not really JuliaFormatter's fault, but this patch works around it. (#1114, #1117)

# v2.8.1

Fixed a bug causing line comments inside array literals to be dropped or otherwise cause non-idempotent formatting. (#1113, #1115, #1116)

# v2.8.0

Fixed a bug causing lack of idempotence in typed comprehension expressions (i.e., things like `T[expr for x in y]`). (#1105, #1106)

Fixed a bug causing lack of idempotence when using `surround_whereop_typeparameters=true` (when the `{` and `}` were inserted, line breaks were not initially being allowed next to them, but would be allowed on the second parse). (#1107, #1106)

Fixed a bug causing lack of idempotence when `in` / `=` / `∈` were being converted inside a `for`-expression (the change in character length was not being accounted for in nesting decisions). (#1108, #1106)

Added a new formatting option, `v2_stable_multiline_strings`, which aims to guarantee formatting idempotence with multiline strings.
By default this option is **not** enabled as it will lead to some changes in the formatting of expressions containing multiline strings: you must opt into it.
Please see the [documentation](https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/formatting_options/#options-v2-stable-multiline-strings) for more information. (#1109, #1110)

# v2.7.0

Improved usage messages for the `jlfmt` command-line tool. (#1098)

Added the ability to format only specific lines of a file, either via the `--lines` option to `jlfmt`, or the `lines` keyword argument to `format_text()`. (#191, #1099, #1100)

# v2.6.15

Fixed a bug where the combination of `always_use_return` and `short_circuit_to_if` would silently change the meaning of a programme. (#887, #1096)

Fixed a bug where `short_circuit_to_if` would fire inside the condition of a `while` loop, leading to invalid code. (#940, #1096)

Fixed a bug where if an entire file was sandwiched in `#! format: off` and `#! format: on` comments _but_ contained additional whitespace/comments after the final `#! format: on`, the file's contents would be deleted. (#949, #1097)

# v2.6.14

Fixed a bug where placing a comment after a `do` keyword would cause non-idempotent formatting. (#1088, #1090)

Fixed lack of idempotence on generator expressions that contained block elements. (#897, #941, #1048, #1092)

Fixed a bug where formatting generator expressions that contained block elements with SciMLStyle would cause the `for ... in ...` to be glued to the `end` of the block, leading to unparseable code. (#1092)

# v2.6.13

Fixed a bug where JuliaFormatter would insert trailing commas after expressions that had macros or `global` keywords, leading to syntactically invalid Julia code. (#1017, #1086)

# v2.6.12

Fixed a bug where `;;\n` separators in rows of array literals were being converted to `;;`, leading to invalid Julia code. (#1080, #1083)

Fixed a bug where comments inside array literals caused non-idempotent formatting with SciML and YAS styles. (#1082, #1083)

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
