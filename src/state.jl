mutable struct State
    doc::Document
    indent::Int
    offset::Int
    line_offset::Int

    # If true, output is formatted text otherwise
    # it's source text
    on::Bool
    opts::Options

    # TODO(penelopeysm): This is a hack, required to make
    # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/pull/997 work correctly.
    # Long-term, it really shouldn't live here, but that will have to wait for a larger
    # refactoring of state/lineage etc.
    is_lhs_of_binary::Bool
end
State(doc, opts) = State(doc, 0, 1, 0, true, opts, false)

nspaces(s::State) = s.indent
hascomment(d::Document, line::Integer) = haskey(d.comments, line)

function cursor_loc(s::State, offset::Integer)
    l = JuliaSyntax.source_line(s.doc.srcfile, offset)
    r = JuliaSyntax.source_line_range(s.doc.srcfile, offset)
    return (l, offset - first(r) + 1, length(r))
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
