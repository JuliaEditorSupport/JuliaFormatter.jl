struct FormatRule
    style::AbstractStyle
    opts::Options{Union{}}
end
format_text(text::AbstractString, fr::FormatRule) = _format_text(text, fr.style, fr.opts)

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
                    for (j, line) in enumerate(split(format_text(an_input, rule), '\n'))
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
                string(format_text(String(input), rule), "\n\n# output\n\n", output)
            else
                format_text(code, rule)
            end
        end
    end
end

function format_docstring(style::AbstractStyle, state::State, text::AbstractString)
    state_indent = state.indent
    start_boundary = findfirst(!=('"'), text)
    is_triple_quoted = let
        # Assuming well-formedness, the string is triple-quoted iif
        # the chars after/before (o)pening/(c)losing quotes are also quotes.
        o, c = map(f -> f(==('"'), text), (findfirst, findlast))
        text[o+1] == text[c-1] == '"'
    end
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
                    FormatRule(style, state.opts),
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
    quot = is_triple_quoted ? "\"\"\"" : '"'
    indentation = " "^state_indent
    indent(line) = indentation * line
    clean(line) = all(isspace, line) ? "" : line # don't write empty lines #667
    lines = split(formatted, '\n') # Always contains at least an empty last line.
    if is_triple_quoted
        prep = line -> clean(indent(line)) # All lines are prepared the same way.
        lines = Iterators.map(prep, lines)
        quot * '\n' * join(lines, '\n') * indent(quot)
    else
        # The first line needs no indentation.
        lines = Iterators.Stateful(lines[1:end-1]) # (drop last empty line)
        first = popfirst!(lines) |> clean
        isempty(lines) && return quot * first * quot
        # Upcoming ones do.
        prep = line -> '\n' * indent(line)
        lines = Iterators.map(prep, lines)
        quot * first * join(lines) * quot
    end
end
