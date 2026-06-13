function format_check(io::IOBuffer, fst::FST, s::State)
    # TODO(penelopeysm) This function is REALLY confusing! The logic really needs to be
    # simplified......

    # `fst.typ` must be NOTCODE -- this means that any text in `fst.startline:fst.endline`
    # doesn't need to be formatted and can just be printed verbatim.
    if fst.typ !== NOTCODE
        error("format_check called with node of type $(fst.typ)")
    end

    # Happy path -- no skipped ranges. Just an ordinary comment and/or blank lines.
    if length(s.doc.format_skips) == 0
        print_notcode(io, fst, s)
        return
    end

    # Some skipped ranges. Check to see if the current lines we're printing overlap with it.
    line_range = (fst.startline):(fst.endline)
    skip = s.doc.format_skips[1]
    nlines = numlines(s.doc)

    if s.on &&
       skip.startline in line_range &&
       (skip.endline in line_range || skip.endline == nlines)
        # Either the skip is fully contained within the range of lines we're printing
        # (skip.endline in line_range). In which case we print all the text up to
        # the `#! format: on` tag.
        #
        # Or the skip is at the end of the file (skip.endline == nlines) in which case
        # we just print the entire file.

        # Dump the text prior to the #! format: off tag.
        l1 = fst.startline
        l2 = skip.startline - 1
        if l1 <= l2
            r1 = linerange(s, l1)
            r2 = linerange(s, l2)
            write(io, JuliaSyntax.sourcetext(s.doc.srcfile)[first(r1):last(r2)])
        end

        output = JuliaSyntax.sourcetext(s.doc.srcfile)[(skip.startoffset):(skip.endoffset)]
        l1 = skip.endline + 1
        l2 = fst.endline

        if l1 <= l2
            # In this branch, there's more stuff in this NOTCODE node after the #! format:
            # on tag.

            # Dump the text from the #! format: off tag to the #! format: on tag.
            write(io, output)

            # Then anything after the #! format: on tag.
            r1 = linerange(s, l1)
            r2 = linerange(s, l2)
            output = JuliaSyntax.sourcetext(s.doc.srcfile)[first(r1):last(r2)]
            if l1 <= nlines && output[end] == '\n'
                output = output[1:prevind(output, end)]
            end
            write(io, output)
        else
            # In this branch, either the #! format: on tag is at the end of the file, or the
            # #! format: on tag is the last line of this NOTCODE node. In either case, we
            # just need to print the text from the #! format: off tag to the #! format: on
            # tag.
            if l1 <= nlines && output[end] == '\n'
                output = output[1:prevind(output, end)]
            end
            write(io, output)
        end

        # If the skip goes to the end of the file, we disable output, otherwise later on
        # format_text() will end up printing the formatted version of the text. All the
        # output we care about has already been generated above.
        if nlines == skip.endline
            popfirst!(s.doc.format_skips)
            s.on = false
        end
    elseif s.on && skip.startline in line_range
        # Formatting disabled midway through the range of lines. Essentially, this covers
        # the case where formatting is being disabled.

        # Print all text up until, but NOT including, the #! format: off tag.
        l1 = fst.startline       # The start of the NOTCODE node we're looking at.
        l2 = skip.startline - 1  # The line before the #! format: off tag.
        if l1 <= l2
            r1 = linerange(s, l1)
            r2 = linerange(s, l2)
            write(io, JuliaSyntax.sourcetext(s.doc.srcfile)[first(r1):last(r2)])
        end
        # Disable printing of formatted output. Later on, when we hit #! format: on, we'll
        # dump the verbatim source text.
        s.on = false
    elseif !s.on && skip.endline in line_range
        # Formatting enabled midway through the range of lines. Essentially, this covers the
        # case where formatting is being re-enabled.

        # The verbatim source text for the range of lines that are skipped (which may
        # include lines prior to line_range). This includes both the `#! format: off` and
        # `#! format: on` tags.
        output = JuliaSyntax.sourcetext(s.doc.srcfile)[(skip.startoffset):(skip.endoffset)]

        l1 = skip.endline + 1  # The line after the #! format: on tag.
        l2 = fst.endline       # The end of the NOTCODE node we're looking at.

        if l1 <= l2
            # This branch covers the case where there's more text in this NOTCODE node after
            # the #! format: on tag.

            # Verbatim source text from the #! format: off tag to the #! format: on tag.
            write(io, output)

            # Then anything after the #! format: on tag.
            r1 = linerange(s, l1)
            r2 = linerange(s, l2)
            output = JuliaSyntax.sourcetext(s.doc.srcfile)[first(r1):last(r2)]
            if l1 <= nlines && output[end] == '\n'
                output = output[1:prevind(output, end)]
            end
            write(io, output)
        else
            # Just the verbatim source text from the #! format: off tag to the #! format: on
            # tag.
            if l1 <= nlines && output[end] == '\n'
                output = output[1:prevind(output, end)]
            end
            write(io, output)
        end
        # We're done with this skip.
        popfirst!(s.doc.format_skips)
        # Re-enable printing of formatted output.
        s.on = true
    else
        # There are skipped ranges, but not part of this NOTCODE node.
        print_notcode(io, fst, s)
    end
end

function print_leaf(io::IOBuffer, fst::FST, s::State)
    if fst.typ === NOTCODE
        format_check(io, fst, s)
    elseif fst.typ === INLINECOMMENT
        print_inlinecomment(io, fst, s)
    else
        if s.on
            write(io, fst.val)
        end
    end
    s.line_offset += length(fst)
end

function print_tree(io::IOBuffer, fst::FST, s::State)
    notcode_indent = -1
    if (fst.typ === Binary || fst.typ === Conditional || fst.typ === ModuleN)
        notcode_indent = fst.indent
    end
    print_tree(io, fst.nodes::Vector{FST}, s, fst.indent; notcode_indent = notcode_indent)
end

function print_tree(
    io::IOBuffer,
    nodes::Vector{FST},
    s::State,
    indent::Int;
    notcode_indent = -1,
)
    ws = repeat(" ", max(indent, 0))
    for (i, n) in enumerate(nodes)
        if n.typ === NOTCODE
            noindent = has_noindent_block(s.doc, (n.startline, n.endline))
            if notcode_indent > -1
                n.indent = notcode_indent
            elseif i + 1 < length(nodes) && is_end(nodes[i+2])
                n.indent += s.opts.indent
            elseif i + 1 < length(nodes) &&
                   (nodes[i+2].typ === Block || nodes[i+2].typ === Begin)
                if noindent
                    add_indent!(nodes[i+2], s, -s.opts.indent)
                    # this captures the trailing comment is not captured as being part of the block
                    if i + 4 <= length(nodes) && nodes[i+4].typ === NOTCODE
                        nodes[i+4].indent -= s.opts.indent
                    end
                else
                    n.indent = nodes[i+2].indent
                end
            elseif i > 2 && (nodes[i-2].typ === Block || nodes[i-2].typ === Begin)
                if noindent
                    add_indent!(nodes[i-2], s, -s.opts.indent)
                else
                    n.indent = nodes[i-2].indent
                end
            end

            if noindent
                n.indent -= s.opts.indent
            end
        end

        if is_leaf(n)
            print_leaf(io, n, s)
        elseif n.typ === StringN
            print_string(io, n, s)
        else
            print_tree(io, n, s)
        end

        if n.typ === NEWLINE && s.on && i < length(nodes)
            next_node = nodes[i+1]
            if is_closer(next_node) || next_node.typ === Block || next_node.typ === Begin
                if s.on
                    write(io, repeat(" ", max(next_node.indent, 0)))
                end
                s.line_offset = next_node.indent
            elseif !skip_indent(next_node)
                if s.on
                    write(io, ws)
                end
                s.line_offset = indent
            end
        end
    end
end

function print_string(io::IOBuffer, fst::FST, s::State)
    # The indent of StringH is set to the the offset
    # of when the quote is first encountered in the source file.

    # This difference notes the indent change due to formatting.
    diff = s.line_offset - fst.indent

    # The new indent for the string is the index of when a character in
    # the multiline string is FIRST encountered in the source file plus
    # the above difference.
    fst.indent = max(fst[1].indent + diff, 0)
    print_tree(io, fst, s)
end

function print_notcode(io::IOBuffer, fst::FST, s::State)
    if !(s.on)
        return
    end
    for l in (fst.startline):(fst.endline)
        _, v = get(s.doc.comments, l, (0, "\n"))
        ws = fst.indent

        # If the current newline is followed by another newline
        # don't print the current newline.
        if s.opts.remove_extra_newlines
            _, vn = get(s.doc.comments, l + 1, (0, "\n"))
            if vn == "\n" && v == "\n"
                (v = "")
            end
        end

        if v == ""
            continue
        end
        if v == "\n"
            (ws = 0)
        end

        if l == fst.endline && v[end] == '\n'
            v = v[1:prevind(v, end)]
        end

        if ws > 0
            write(io, repeat(" ", ws))
        end
        write(io, v)

        if l != fst.endline && v[end] != '\n'
            write(io, "\n")
        end
    end
end

function print_inlinecomment(io::IOBuffer, fst::FST, s::State)
    if !(s.on)
        return
    end
    ws, v = get(s.doc.comments, fst.startline, (0, ""))
    if isempty(v)
        return
    end
    v = v[end] == '\n' ? v[firstindex(v):prevind(v, end)] : v
    if ws > 0
        write(io, repeat(" ", ws))
    elseif startswith(v, "#=") && endswith(v, "=#")
        # hack to overcome the bug noticed in https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/571#issuecomment-1114446297
        # until multiline comments aren't moved to the end of the line.
        write(io, " ")
    end
    write(io, v)
end
