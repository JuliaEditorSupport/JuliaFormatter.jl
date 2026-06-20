mutable struct State
    doc::Document
    indent::Int
    offset::Int
    line_offset::Int

    # If true, output is formatted text otherwise
    # it's source text
    on::Bool
    opts::Options

    # When true, syntax transformations (e.g. import_to_using) are suppressed.
    # Set inside quote, quotenode, and macro nodes, where transforming the code
    # would change the semantics of the expression.
    disable_syntax_transformations::Bool
end
State(doc, opts) = State(doc, 0, 1, 0, true, opts, false)

nspaces(s::State) = s.indent
hascomment(d::Document, line::Integer) = haskey(d.comments, line)

function cursor_loc(s::State, offset::Integer)
    l = JuliaSyntax.source_line(s.doc.srcfile, offset)
    r = JuliaSyntax.source_line_range(s.doc.srcfile, offset)
    code = JuliaSyntax.sourcetext(s.doc.srcfile)
    line_start = first(r)
    display_col = if offset <= line_start
        1
    else
        textwidth(code[line_start:prevind(code, offset)]) + 1
    end
    return (l, display_col)
end
cursor_loc(s::State) = cursor_loc(s, s.offset)

function on_same_line(s::State, offset1::Integer, offset2::Integer)
    l1 = JuliaSyntax.source_line(s.doc.srcfile, offset1)
    l2 = JuliaSyntax.source_line(s.doc.srcfile, offset2)
    return l1 == l2
end

function linerange(s::State, line::Integer)
    f = s.doc.srcfile.line_starts[line]
    r = JuliaSyntax.source_line_range(s.doc.srcfile, f)
    return (first(r), last(r))
end
