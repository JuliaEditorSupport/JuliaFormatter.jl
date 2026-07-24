struct FormatRule
    style::AbstractStyle
    opts::Options{Union{}}
    is_triple_quoted::Bool
end

const _REPLACEMENT_PAIRS = (
    # Not sure what other replacements are needed?
    "\\\\" => "\\",
    "\\\$" => "\$",
    "\\\"" => "\"",
)
function unescape_docstring_code(text::AbstractString)
    return replace(text, (k => v for (k, v) in _REPLACEMENT_PAIRS)...)
end
function escape_docstring_code(text::AbstractString, is_triple_quoted::Bool)
    # If the output is within a triple-quoted docstring, then we don't need to
    # fully escape `"""`: we can get away with just doing `\\"""`.
    return if is_triple_quoted
        text_chunks = split(text, "\"\"\"")
        text_chunks = map(x -> escape_docstring_code(x, false), text_chunks)
        join(text_chunks, "\\\"\"\"")
    else
        replace(text, (v => k for (k, v) in _REPLACEMENT_PAIRS)...)
    end
end

function format_docstring_code(text::AbstractString, fr::FormatRule)
    try
        # Julia code within docstrings may contain escape sequences. For example if we want
        # to write `A \ b` in a docstring, it has to be written as (for example)
        # 
        #     """
        #     [...]
        #     julia> A \\ b
        #
        #     [...]
        #     """
        #     function foo end
        #
        # However, this means that the `text` we receive here is actually doubly
        # escaped because it's the literal contents of the docstring:
        #
        #     text = "A \\\\ b"
        #
        # which is not the same thing as the code we want to format, which is
        #
        #     code = "A \\ b"
        #
        # So we need to unescape it before formatting, and then re-escape it afterwards.
        # Note that docstrings have to be `"""..."""`: prefixed strings (e.g.
        # `raw"""..."""`) are not valid docstrings, so we don't have to worry about them.
        #
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1224
        escape_docstring_code(
            _format_text(unescape_docstring_code(text), fr.style, fr.opts),
            fr.is_triple_quoted,
        )
    catch e
        if e isa JuliaSyntax.ParseError
            # Original code was invalid Julia (not through any fault of ours). Just pass it
            # through.
            return text
        else
            rethrow(e)
        end
    end
end

function block_modifier(rule::FormatRule)
    Rule(1) do _, block
        if block.t isa CodeBlock &&
           startswith(block.t.info, r"@example|@repl|@eval|julia|{julia}|jldoctest")
            code = block.literal::String

            block.literal = if occursin(r"^julia> "m, code)
                doctests = IOBuffer()
                chunks = repl_splitter(code)
                for (i, (an_input, output)) in enumerate(chunks)
                    write(doctests, "julia> ")
                    for (j, line) in
                        enumerate(split(format_docstring_code(an_input, rule), '\n'))
                        if j > 1
                            if line == ""
                                write(doctests, "\n")
                            else
                                write(doctests, "\n       ")
                            end
                        end
                        write(doctests, line)
                    end
                    write(doctests, '\n')
                    write(doctests, output)

                    if i < length(chunks)
                        if output == ""
                            write(doctests, "\n")
                        else
                            write(doctests, "\n\n")
                        end
                    end
                end
                write(doctests, '\n')
                String(take!(doctests))
            elseif occursin(r"\n+# output\n+", code)
                input, output = split(code, r"\n+# output\n+"; limit = 2)
                string(
                    format_docstring_code(String(input), rule),
                    "\n\n# output\n\n",
                    output,
                )
            else
                format_docstring_code(code, rule)
            end
        end
    end
end

function format_docstring(style::AbstractStyle, state::State, text::AbstractString)
    is_triple_quoted =
        state.opts.enforce_triplequoted_docstrings ||
        (startswith(text, "\"\"\"") && endswith(text, "\"\"\""))
    start_boundary = findfirst(!=('"'), text)
    # if the docstring is non-empty
    if !isnothing(start_boundary)
        _end_boundary = findlast(!=('"'), text)
        end_boundary = isnothing(_end_boundary) ? length(text) : _end_boundary
        # first, we need to remove any user indent
        # only some lines will "count" towards increasing the user indent
        # start at a very big guess
        user_indent = typemax(Int)
        user_indented = text[start_boundary:end_boundary]
        deindented = IOBuffer()
        user_lines = split(user_indented, '\n')
        for (index, line) in enumerate(user_lines)
            # the first line doesn't count
            if index != 1
                num_spaces = 0
                for c in line
                    if !(isspace(c))
                        break
                    else
                        true
                    end
                    num_spaces += 1
                end
                # if the line is only spaces, it only counts if it is the last line
                if num_spaces < length(line) || index == length(user_lines)
                    user_indent = min(user_indent, num_spaces)
                end
            end
        end
        deindented_string =
        # if there are no lines at all, or if the user indent is zero, we don't have to change anything
            if user_indent == typemax(Int) || user_indent == 0
                user_indented
            else
                # else, deindent non-first lines
                first_line = true
                for line in split(user_indented, '\n')
                    if first_line
                        first_line = false
                        write(deindented, line)
                    else
                        write(deindented, '\n')
                        write(deindented, chop(line; head = user_indent, tail = 0))
                    end
                end
                String(take!(deindented))
            end

        # then, we format
        formatted = markdown(
            enable!(
                Parser(),
                [
                    AdmonitionRule(),
                    FootnoteRule(),
                    MathRule(),
                    TableRule(),
                    FrontMatterRule(),
                    FormatRule(style, state.opts, is_triple_quoted),
                ],
            )(
                deindented_string,
            ),
        )
    else
        # the docstring is empty
        formatted = ""
    end
    # Render into text lines, taking care of original indentation,
    quot = is_triple_quoted ? "\"\"\"" : "\""
    indentation = " "^state.indent
    indent(line) = indentation * line
    clean(line) = all(isspace, line) ? "" : line # don't write empty lines #667
    lines = split(formatted, '\n')
    last(lines) == "" || # Legacy guarantee.
        error("unreachable: `formatted` should end in empty string. Please report this at \
               https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues!")
    if is_triple_quoted
        prep = line -> clean(indent(line)) # All lines are prepared the same way.
        lines = Iterators.map(prep, lines)
        quot * '\n' * join(lines, '\n') * indent(quot)
    else
        # The first line needs no indentation.
        first = clean(lines[1])
        prep = line -> '\n' * indent(line)
        lines = Iterators.map(prep, lines[2:(end-1)]) # (drop last empty line)
        quot * first * join(lines) * quot
    end
end
