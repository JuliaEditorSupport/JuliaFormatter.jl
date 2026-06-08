function n_call!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ys)

    # With `variable_call_indent`, check if the caller is in the list
    if caller_in_list(fst, s.opts.variable_call_indent) &&
       length(fst.nodes::Vector{FST}) > 5
        # Check if the call is of the form `caller(something,...)`
        # or of the form `caller(\n...)`.
        # There may be a comment or both an inline comment and a comment in a separate line
        # before the first argument, so check for that as well.
        notcode(n) = n.typ === NOTCODE || n.typ === INLINECOMMENT || n.typ === PLACEHOLDER
        linebreak_definition =
            fst[4].typ === NEWLINE ||
            notcode(fst[4]) && fst[5].typ === NEWLINE ||
            notcode(fst[4]) && notcode(fst[5]) && fst[6].typ === NEWLINE

        if linebreak_definition
            # With a line break in the definition, don't align with the opening parenthesis
            return n_call!(DefaultStyle(ys), fst, s, lineage)
        end
    end

    function find_next_ph_or_nl(nodes::Vector{FST}, idx::Int)
        while idx < length(nodes)
            n = nodes[idx]
            if n.typ === PLACEHOLDER || n.typ === NEWLINE
                return idx
            elseif n.typ === Parameters
                return find_next_ph_or_nl(n.nodes, 1)
            end
            idx += 1
        end
        return nothing
    end

    nodes = fst.nodes::Vector

    nested = false
    for (i, n) in enumerate(nodes)
        if is_opener(n)
            # The indent is set here to handle the edge
            # case where the first argument of Call is
            # nestable.
            # ref https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/387
            fst.indent = s.line_offset + 1
        end

        if n.typ === NEWLINE
            s.line_offset = fst.indent
        elseif n.typ === PLACEHOLDER
            # si = findnext(find_next_ph_or_nl, nodes, i + 1)
            si = find_next_ph_or_nl(nodes, i + 1)
            nested |= nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
        elseif is_gen(n)
            n.indent = fst.indent
            n.extra_margin = 1
            nested |= nest!(style, n, s, lineage)
        else
            diff = fst.indent - fst[i].indent
            add_indent!(n, s, diff)
            n.extra_margin = 1
            nested |= nest!(style, n, s, lineage)
        end
    end
    return nested
end

function n_curly!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_call!(ys, fst, s, lineage)
end
function n_ref!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_call!(ys, fst, s, lineage)
end
function n_macrocall!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_call!(ys, fst, s, lineage)
end
function n_typedcomprehension!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_call!(ys, fst, s, lineage)
end
function n_typedvcat!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_call!(ys, fst, s, lineage)
end

function n_tuple!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}};
    indent::Int = -1,
)
    style = getstyle(ys)
    # SciML can opt into YAS nesting, but the tuple-binding margin overrun is
    # still SciML-specific. Plain YASStyle should keep its existing behavior.
    for_tuple_binding_lhs = style isa SciMLStyle && _is_for_tuple_binding_lhs(fst, lineage)
    if for_tuple_binding_lhs
        optimal_placeholders = find_optimal_nest_placeholders(
            fst,
            fst.indent,
            s.opts;
            margin_line_offset = s.line_offset,
            for_tuple_binding_lhs,
        )
        if isempty(optimal_placeholders)
            walk(increment_line_offset!, fst, s)
            return false
        end
    end

    if indent > -1
        fst.indent = indent
    else
        fst.indent = s.line_offset
    end
    nodes = fst.nodes::Vector
    if length(nodes) > 0 && is_opener(fst[1])
        (fst.indent += 1)
    else
        false
    end

    f = n -> n.typ === PLACEHOLDER || n.typ === NEWLINE

    nested = false
    for (i, n) in enumerate(nodes)
        if n.typ === NEWLINE
            s.line_offset = fst.indent
        elseif n.typ === PLACEHOLDER
            si = findnext(f, nodes, i + 1)
            nested |= nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
        elseif is_gen(n)
            n.indent = fst.indent
            n.extra_margin = 1
            nested |= nest!(style, n, s, lineage)
        else
            diff = fst.indent - fst[i].indent
            add_indent!(n, s, diff)
            n.extra_margin = 1
            nested |= nest!(style, n, s, lineage)
        end
    end
    return nested
end
function n_braces!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_vect!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_parameters!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_parens!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_comprehension!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_vcat!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_hcat!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_bracescat!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_cartesian_iterator!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end
function n_tupleblock!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ys, fst, s, lineage)
end

function n_generator!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ys)
    diff = s.line_offset - fst[1].indent

    # if the first argument is not a leaf
    # aligns it to be inside the generator
    # expression
    add_indent!(fst[1], s, diff)

    nodes = fst.nodes::Vector
    nested = false
    for (i, n) in enumerate(nodes)
        if n.typ === NEWLINE
            s.line_offset = fst.indent
        elseif n.typ === PLACEHOLDER
            si = findnext(n -> n.typ === PLACEHOLDER, nodes, i + 1)
            nested |= nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
        elseif is_gen(n)
            n.indent = fst.indent
            n.extra_margin = 1
            nested |= nest!(style, n, s, lineage)
        else
            n.extra_margin = 1
            nested |= nest!(style, n, s, lineage)
        end
    end
    return nested
end
function n_filter!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_generator!(ys, fst, s, lineage)
end

function n_whereopcall!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ys)
    fst.indent = s.line_offset
    # after "A where "
    Blen = sum(length.(fst[2:end]))
    fst[1].extra_margin = Blen + fst.extra_margin

    nodes = fst.nodes::Vector

    nested = false
    for (i, n) in enumerate(nodes)
        if n.typ === NEWLINE
            s.line_offset = fst.indent
        elseif n.typ === PLACEHOLDER
            si = findnext(n -> n.typ === PLACEHOLDER, nodes, i + 1)
            nested |= nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
        elseif is_opener(n) && n.val == "{"
            fst.indent = s.line_offset + 1
            nested |= nest!(style, n, s, lineage)
        elseif i == 1 || i == length(nodes)
            nested |= nest!(style, n, s, lineage)
        else
            n.extra_margin = 1
            nested |= nest!(style, n, s, lineage)
        end
    end
    return nested
end

function n_using!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ys)
    nodes = fst.nodes::Vector
    idx = findfirst(n -> n.val == ":", nodes)
    fst.indent = s.line_offset
    if idx === nothing
        fst.indent += sum(length.(fst[1:2]))
    else
        fst.indent += sum(length.(fst[1:(idx+1)]))
    end
    nested = false
    for (i, n) in enumerate(nodes)
        if n.typ === PLACEHOLDER
            si = findnext(n -> n.typ === PLACEHOLDER, nodes, i + 1)
            nested |= nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
        elseif n.typ === NEWLINE
            s.line_offset = fst.indent
        else
            nested |= nest!(style, n, s, lineage)
        end
    end
    return nested
end
function n_export!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_using!(ys, fst, s, lineage)
end
function n_public!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_using!(ys, fst, s, lineage)
end
function n_import!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_using!(ys, fst, s, lineage)
end

function n_chainopcall!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ys)
    n_block!(DefaultStyle(style), fst, s, lineage; indent = s.line_offset)
end

function n_comparison!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ys)
    n_block!(DefaultStyle(style), fst, s, lineage; indent = s.line_offset)
end

function n_binaryopcall!(
    ys::YASStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}};
    indent::Int = -1,
)
    style = getstyle(ys)
    nodes = fst.nodes::Vector
    if findfirst(n -> n.typ === PLACEHOLDER, nodes) !== nothing
        return n_binaryopcall!(DefaultStyle(style), fst, s, lineage; indent = indent)
    end

    walk(increment_line_offset!, nodes[1:(end-1)], s, fst.indent)
    nest!(style, fst[end], s, lineage)
end
