# A flag to indicate whether we are inside an `Expr` (in which case all syntax
# transformations should be suppressed), inside a macro (in which case some syntax
# transformations can still be enabled if the user explicitly says so), or neither (in which
# case all syntax transformations can be enabled).
@enum SyntaxTransformsStatus InsideExpr InsideMacro None

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
    syntax_transforms_status::SyntaxTransformsStatus
end
State(doc, opts) = State(doc, 0, 1, 0, true, opts, None)

"""
    can_transform_syntax(s::State, allow_in_macros::Bool)

Check whether according to the current state we are allowed to perform a syntax
transformation. The `allow_in_macros` argument indicates whether the syntax transformation
should be allowed inside macros when `s.opts.transform_syntax_in_macros` is true. Some
syntax transformations are simply not safe to perform inside macros so are disabled even if
`s.opts.transform_syntax_in_macros` is true.
"""
function can_transform_syntax(s::State, allow_in_macros::Bool)
    s.syntax_transforms_status == None || (
        allow_in_macros &&
        s.syntax_transforms_status == InsideMacro &&
        s.opts.transform_syntax_in_macros
    )
end

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
