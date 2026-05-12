function format_check(io::IOBuffer, fst::FST, s::State)
    if length(s.doc.format_skips) == 0
        print_notcode(io, fst, s)
        return
    end

    line_range = (fst.startline):(fst.endline)
    skip = s.doc.format_skips[1]
    nlines = numlines(s.doc)

    if s.on &&
       skip.startline in line_range &&
       (skip.endline in line_range || skip.endline == nlines)
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
            r1 = linerange(s, l1)
            r2 = linerange(s, l2)
            write(io, output)
            output = JuliaSyntax.sourcetext(s.doc.srcfile)[first(r1):last(r2)]
            if l1 <= nlines && output[end] == '\n'
                output = output[1:prevind(output, end)]
            end
            write(io, output)
        else
            if l1 <= nlines && output[end] == '\n'
                output = output[1:prevind(output, end)]
            end
            write(io, output)
        end

        if nlines == skip.endline
            s.on = false
        end
    elseif s.on && skip.startline in line_range
        l1 = fst.startline
        l2 = skip.startline - 1
        if l1 <= l2
            r1 = linerange(s, l1)
            r2 = linerange(s, l2)
            write(io, JuliaSyntax.sourcetext(s.doc.srcfile)[first(r1):last(r2)])
        end
        s.on = false
    elseif !s.on && skip.endline in line_range
        output = JuliaSyntax.sourcetext(s.doc.srcfile)[(skip.startoffset):(skip.endoffset)]
        l1 = skip.endline + 1
        l2 = fst.endline

        if l1 <= l2
            r1 = linerange(s, l1)
            r2 = linerange(s, l2)
            write(io, output)
            output = JuliaSyntax.sourcetext(s.doc.srcfile)[first(r1):last(r2)]
            if l1 <= nlines && output[end] == '\n'
                output = output[1:prevind(output, end)]
            end
            write(io, output)
        else
            if l1 <= nlines && output[end] == '\n'
                output = output[1:prevind(output, end)]
            end
            write(io, output)
        end
        popfirst!(s.doc.format_skips)
        s.on = true
    else
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
            if is_closer(nodes[i+1]) || nodes[i+1].typ === Block || nodes[i+1].typ === Begin
                if s.on
                    write(io, repeat(" ", max(nodes[i+1].indent, 0)))
                end
                s.line_offset = nodes[i+1].indent
            elseif !skip_indent(nodes[i+1])
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
        # hack to overcome the bug noticed in https://github.com/domluna/JuliaFormatter.jl/issues/571#issuecomment-1114446297
        # until multiline comments aren't moved to the end of the line.
        write(io, " ")
    end
    write(io, v)
end
