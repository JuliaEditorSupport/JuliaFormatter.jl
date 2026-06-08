# Nest
#
# If the line exceeds the print width it will be nested.
#
# This is done by replacing `PLACEHOLDER` nodes with `NEWLINE`
# nodes and updating the FST's indent.
#
# `extra_margin` provides additional width to consider from
# the top-level node.
#
# Example:
#
#     LHS op RHS
#
# the length of " op" will be considered when nesting LHS

function nest!(
    ds::AbstractStyle,
    nodes::Vector{FST},
    s::State,
    indent::Int,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}};
    extra_margin::Int = 0,
)
    style = getstyle(ds)
    nested = false

    for (i, n) in enumerate(nodes)
        if n.typ === NEWLINE && nodes[i+1].typ === Block
            s.line_offset = nodes[i+1].indent
        elseif n.typ === NOTCODE && nodes[i+1].typ === Block
            s.line_offset = nodes[i+1].indent
        elseif n.typ === NEWLINE
            s.line_offset = indent
        else
            n.extra_margin = extra_margin
            nested |= nest!(style, n, s, lineage)
        end
    end

    return nested
end

function nest!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    if is_leaf(fst)
        s.line_offset += length(fst)
        return false
    elseif cant_nest(fst)
        walk(increment_line_offset!, fst, s)
        return false
    end

    style = getstyle(ds)
    push!(lineage, (fst.typ, fst.metadata))

    if fst.typ === FunctionN &&
       s.opts.long_to_short_function_def &&
       !isnothing(fst.metadata) &&
       (fst.metadata::Metadata).is_long_form_function
        long_to_short_function_def!(fst, s)
    elseif fst.typ === Binary
        line_margin = s.line_offset + length(fst) + fst.extra_margin
        if s.opts.short_to_long_function_def &&
           (line_margin > s.opts.margin || s.opts.force_long_function_def) &&
           !isnothing(fst.metadata) &&
           (fst.metadata::Metadata).is_short_form_function
            short_to_long_function_def!(fst, s, lineage)
        end
    elseif fst.typ === Conditional
        line_margin = s.line_offset + length(fst) + fst.extra_margin
        if s.opts.conditional_to_if && line_margin > s.opts.margin
            conditional_to_if_block!(fst, s, true)
        end
    end

    nested = if fst.typ === Import
        n_import!(style, fst, s, lineage)
    elseif fst.typ === Export
        n_export!(style, fst, s, lineage)
    elseif fst.typ === Public
        n_public!(style, fst, s, lineage)
    elseif fst.typ === Using
        n_using!(style, fst, s, lineage)
    elseif fst.typ === Where
        n_whereopcall!(style, fst, s, lineage)
    elseif fst.typ === Conditional
        n_conditionalopcall!(style, fst, s, lineage)
    elseif fst.typ === Binary
        n_binaryopcall!(style, fst, s, lineage)
    elseif fst.typ === Curly
        n_curly!(style, fst, s, lineage)
    elseif fst.typ === Call
        n_call!(style, fst, s, lineage)
    elseif fst.typ === MacroCall
        n_macrocall!(style, fst, s, lineage)
    elseif fst.typ === RefN
        n_ref!(style, fst, s, lineage)
        # elseif fst.typ === Row
        #     n_row!(style, fst, s)
    elseif fst.typ === TypedVcat
        n_typedvcat!(style, fst, s, lineage)
    elseif fst.typ === TypedNcat
        n_typedvcat!(style, fst, s, lineage)
    elseif fst.typ === TupleN && length(fst.nodes) > 0
        n_tuple!(style, fst, s, lineage)
    elseif fst.typ === CartesianIterator
        n_cartesian_iterator!(style, fst, s, lineage)
    elseif fst.typ === TupleBlock
        n_tupleblock!(style, fst, s, lineage)
    elseif fst.typ === Parameters
        n_parameters!(style, fst, s, lineage)
    elseif fst.typ === Vect
        n_vect!(style, fst, s, lineage)
    elseif fst.typ === Vcat
        n_vcat!(style, fst, s, lineage)
    elseif fst.typ === Hcat || fst.typ === TypedHcat
        n_hcat!(style, fst, s, lineage)
    elseif fst.typ === Ncat
        n_vcat!(style, fst, s, lineage)
    elseif fst.typ === Braces
        n_braces!(style, fst, s, lineage)
    elseif fst.typ === BracesCat
        n_bracescat!(style, fst, s, lineage)
    elseif fst.typ === Brackets
        n_parens!(style, fst, s, lineage)
    elseif fst.typ === Comprehension
        n_comprehension!(style, fst, s, lineage)
    elseif fst.typ === TypedComprehension
        n_typedcomprehension!(style, fst, s, lineage)
    elseif fst.typ === Do
        n_do!(style, fst, s, lineage)
    elseif fst.typ === Generator
        n_generator!(style, fst, s, lineage)
    elseif fst.typ === Filter
        n_filter!(style, fst, s, lineage)
        # elseif fst.typ === Block && is_closer(fst[end]) # (a;b;c)
        #     n_tuple!(style, fst, s, lineage)
    elseif fst.typ === Block
        n_block!(style, fst, s, lineage)
    elseif fst.typ === Chain
        n_chainopcall!(style, fst, s, lineage)
    elseif fst.typ === Comparison
        n_comparison!(style, fst, s, lineage)
    elseif fst.typ === For
        n_for!(style, fst, s, lineage)
    elseif fst.typ === Let
        n_let!(style, fst, s, lineage)
    elseif fst.typ === Unary && length(fst.nodes::Vector) > 1 && fst[2].typ === OPERATOR
        n_unaryopcall!(style, fst, s, lineage)
    elseif fst.typ === StringN
        n_string!(style, fst, s, lineage)
    elseif fst.typ === FunctionN
        n_functiondef!(style, fst, s, lineage)
    elseif fst.typ === Macro
        n_macro!(style, fst, s, lineage)
    else
        nest!(style, fst.nodes::Vector, s, fst.indent, lineage; extra_margin = fst.extra_margin)
    end

    pop!(lineage)

    return nested
end
function nest!(style::AbstractStyle, fst::FST, s::State)
    nest!(style, fst, s, Tuple{FNode,Union{Nothing,Metadata}}[])
end

function n_functiondef!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    nest!(ds, fst.nodes::Vector, s, fst.indent, lineage; extra_margin = fst.extra_margin)
end

function n_macro!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_functiondef!(ds, fst, s, lineage)
end

function n_string!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    # difference in positioning of the string
    # from the source document to the formatted document
    diff = s.line_offset - fst.indent

    nested = false
    for (i, n) in enumerate(fst.nodes::Vector)
        if n.typ === NEWLINE
            s.line_offset = fst[i+1].indent + diff
        else
            nested |= nest!(style, n, s, lineage)
        end
    end
    return nested
end

function n_unaryopcall!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    fst[1].extra_margin = fst.extra_margin + length(fst[2])
    nested = false
    # nest!(style, fst.nodes::Vector{FST}, s, fst.indent)
    nested |= nest!(style, fst[1], s, lineage)
    nested |= nest!(style, fst[2], s, lineage)
    return nested
end

function n_do!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    extra_margin = sum(length.(fst[2:3]))
    # make sure there are nodes after "do"
    if fst[4].typ === WHITESPACE
        extra_margin += length(fst[4])
        extra_margin += length(fst[5])
    end
    fst[1].extra_margin = fst.extra_margin + extra_margin
    nested = false
    nested |= nest!(style, fst[1], s, lineage)
    nested |=
        nest!(style, fst[2:end], s, fst.indent, lineage; extra_margin = fst.extra_margin)
    return nested
end

# Import,Using,Export,Public
function n_using!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    line_margin = s.line_offset + length(fst) + fst.extra_margin
    nodes = fst.nodes::Vector
    idx = findfirst(n -> n.typ === PLACEHOLDER, nodes)
    fst.indent += s.opts.indent

    nested = false
    if idx !== nothing && (line_margin > s.opts.margin || must_nest(fst))
        if can_nest(fst)
            if fst.indent + sum(length.(fst[(idx+1):end])) <= s.opts.margin
                fst[idx] = Newline(; length = fst[idx].len)
                walk(increment_line_offset!, fst, s)
                return nested
            end
        end

        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE
                s.line_offset = fst.indent
            elseif n.typ === PLACEHOLDER
                if s.opts.join_lines_based_on_source
                    si = findnext(n -> n.typ === PLACEHOLDER, nodes, i + 1)
                    nested |= nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
                else
                    fst[i] = Newline(; length = n.len)
                    s.line_offset = fst.indent
                end
            else
                diff = fst.indent - fst[i].indent
                add_indent!(n, s, diff)
                if i < length(nodes)
                    (n.extra_margin = 1)
                else
                    false
                end
                nested |= nest!(style, n, s, lineage)
            end
        end
    else
        nested |=
            nest!(style, nodes, s, fst.indent, lineage; extra_margin = fst.extra_margin)
    end
    return nested
end

function n_export!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_using!(ds, fst, s, lineage)
end

function n_public!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_using!(ds, fst, s, lineage)
end

function n_import!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_using!(ds, fst, s, lineage)
end

function n_tuple!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    line_margin = s.line_offset + length(fst) + fst.extra_margin
    nodes = fst.nodes::Vector
    idx = findlast(n -> n.typ === PLACEHOLDER, nodes)
    has_closer = is_closer(fst[end])

    if has_closer
        fst[end].indent = fst.indent
    end
    if !(fst.typ in (TupleN, CartesianIterator, Parameters)) || has_closer
        fst.indent += s.opts.indent
    end

    # "foo(a, b, c)" is true if "foo" and "c" are on different lines
    src_diff_line = if s.opts.join_lines_based_on_source && length(nodes) > 1
        last_arg_idx = findlast(is_iterable_arg, nodes)
        last_arg = isnothing(last_arg_idx) ? fst[end] : fst[last_arg_idx]
        fst[1].endline != last_arg.startline
    else
        false
    end

    nested = false

    if idx !== nothing && (line_margin > s.opts.margin || must_nest(fst) || src_diff_line)
        nested = true
        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE
                s.line_offset = fst.indent
            elseif n.typ === PLACEHOLDER
                if src_diff_line
                    si = findnext(
                        n -> n.typ === PLACEHOLDER || n.typ === NEWLINE,
                        nodes,
                        i + 1,
                    )
                    nested2 = nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
                    if has_closer && !nested2 && n.startline == fst[end].startline
                        # trailing types are automatically converted, undo this if
                        # there is no nest and the closer is on the same in the
                        # original source.
                        if fst[i-1].typ === TRAILINGCOMMA
                            fst[i-1].val = ""
                            fst[i-1].len = 0
                        end
                    end
                else
                    fst[i] = Newline(; length = n.len)
                    s.line_offset = fst.indent
                end
            elseif n.typ === TRAILINGCOMMA
                n.val = ","
                n.len = 1
            elseif has_closer && (i == 1 || i == length(nodes))
                nest!(style, n, s, lineage)
            else
                diff = fst.indent - fst[i].indent
                add_indent!(n, s, diff)
                n.extra_margin = 1
                nest!(style, n, s, lineage)
            end
        end

        if has_closer
            s.line_offset = fst[end].indent + 1
        end
    else
        extra_margin = fst.extra_margin
        if has_closer
            (extra_margin += 1)
        else
            false
        end
        nested |= nest!(style, nodes, s, fst.indent, lineage; extra_margin = extra_margin)
    end

    return nested
end

function n_cartesian_iterator!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_tupleblock!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_vect!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_vcat!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_hcat!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_braces!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_bracescat!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_parameters!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_parens!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_call!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_curly!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_macrocall!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_ref!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_row!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_typedvcat!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_tuple!(ds, fst, s, lineage)
end

function n_comprehension!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    if s.opts.join_lines_based_on_source
        n_tuple!(ds, fst, s, lineage)
    else
        _n_comprehension!(ds, fst, s, lineage)
    end
end

function _n_comprehension!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    line_margin = s.line_offset + length(fst) + fst.extra_margin
    nested = false

    line_margin = s.line_offset + length(fst) + fst.extra_margin
    closer = is_closer(fst[end])
    nodes = fst.nodes::Vector

    if closer && (line_margin > s.opts.margin || must_nest(fst))
        idx = findfirst(n -> n.typ === PLACEHOLDER, nodes)
        if idx !== nothing
            fst[idx] = Newline(; length = fst[idx].len)
        end
        idx = findlast(n -> n.typ === PLACEHOLDER, nodes)
        if idx !== nothing
            fst[idx] = Newline(; length = fst[idx].len)
        end

        add_indent!(fst, s, s.opts.indent)
        fst[end].indent = fst.indent - s.opts.indent
        nested = true
    end

    for (i, n) in enumerate(nodes)
        if n.typ === NEWLINE
            s.line_offset = fst.indent
        elseif n.typ === PLACEHOLDER
            if must_nest(fst)
                fst[i] = Newline(; length = n.len)
                s.line_offset = fst.indent
            else
                nest_if_over_margin!(style, fst, s, i, lineage)
            end
        elseif i == length(nodes) && !closer
            nest!(style, n, s, lineage)
        else
            n.extra_margin = nested ? 0 : 1
            nest!(style, n, s, lineage)
        end
    end

    if closer
        s.line_offset = fst[end].indent + 1
    end

    return nested
end

function n_typedcomprehension!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_comprehension!(ds, fst, s, lineage)
end

function n_generator!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    line_margin = s.line_offset + length(fst) + fst.extra_margin
    line_offset = s.line_offset
    fst.indent = s.line_offset

    nodes = fst.nodes::Vector

    src_diff_line = if s.opts.join_lines_based_on_source && length(nodes) > 1
        last_arg_idx = findlast(is_iterable_arg, nodes)
        last_arg = isnothing(last_arg_idx) ? fst[end] : fst[last_arg_idx]
        fst[1].endline != last_arg.startline
    else
        false
    end

    nested = false

    if line_margin > s.opts.margin || must_nest(fst) || src_diff_line
        nested = true
        phs = reverse(findall(n -> n.typ === PLACEHOLDER, nodes))
        if s.opts.join_lines_based_on_source
            phs = filter(idx -> fst[idx+1].typ !== NEWLINE, phs)
        end
        for (i, idx) in enumerate(phs)
            if i == 1
                fst[idx] = Newline(; length = fst[idx].len)
            else
                nidx = phs[i-1]
                l1 = sum(length.(fst[1:(idx-1)]))
                l2 = sum(length.(fst[idx:(nidx-1)]))
                width = line_offset + l1 + l2
                if must_nest(fst) || width > s.opts.margin
                    fst[idx] = Newline(; length = fst[idx].len)
                end
            end
        end

        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE
                s.line_offset = fst.indent
            elseif i == length(nodes)
                nest!(style, n, s, lineage)
            else
                n.extra_margin = 1
                nest!(style, n, s, lineage)
            end
        end

        s.line_offset = line_offset
        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE &&
               !is_comment(fst[i+1]) &&
               !is_comment(fst[i-1]) &&
               i in phs
                # +1 for newline to whitespace conversion
                width = s.line_offset + 1
                w, _ = length_to(fst, (NEWLINE,); start = i + 1)
                width += w
                if width <= s.opts.margin
                    fst[i] = Whitespace(1)
                    s.line_offset += length(fst[i])
                else
                    s.line_offset = fst.indent
                end
            elseif n.typ === NEWLINE
                s.line_offset = fst.indent
            else
                walk(increment_line_offset!, fst[i], s)
            end
        end

        s.line_offset = line_offset
        walk(increment_line_offset!, fst, s)
    else
        nested |=
            nest!(style, nodes, s, fst.indent, lineage; extra_margin = fst.extra_margin)
    end
    return nested
end

function n_filter!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_generator!(ds, fst, s, lineage)
end

function n_whereopcall!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    line_margin = s.line_offset + length(fst) + fst.extra_margin
    # "B"
    has_braces = is_closer(fst[end])
    if has_braces
        fst[end].indent = fst.indent
    end

    nested = false

    if line_margin > s.opts.margin || must_nest(fst)
        nested = true
        line_offset = s.line_offset
        Blen = sum(length.(fst[2:end]))

        fst[1].extra_margin = Blen + fst.extra_margin
        nest!(style, fst[1], s, lineage)

        over = (s.line_offset + Blen + fst.extra_margin > s.opts.margin) || must_nest(fst)
        fst.indent += s.opts.indent
        for (i, n) in enumerate(fst[2:end])
            if n.typ === NEWLINE
                s.line_offset = fst.indent
            elseif is_opener(n)
                if fst.indent - s.line_offset > 1
                    fst.indent = s.line_offset + 1
                    fst[end].indent = s.line_offset
                end
                nest!(style, n, s, lineage)
            elseif n.typ === PLACEHOLDER && over
                fst[i+1] = Newline(; length = length(n))
                s.line_offset = fst.indent
            elseif n.typ === TRAILINGCOMMA && over
                n.val = ","
                n.len = 1
                nest!(style, n, s, lineage)
            elseif has_braces
                n.extra_margin = 1 + fst.extra_margin
                nest!(style, n, s, lineage)
            else
                n.extra_margin = fst.extra_margin
                nest!(style, n, s, lineage)
            end
        end

        s.line_offset = line_offset
        walk(increment_line_offset!, fst, s)
        return nested
    end

    nested |= nest!(
        style,
        fst.nodes::Vector,
        s,
        fst.indent,
        lineage;
        extra_margin = fst.extra_margin,
    )
    return nested
end

function n_conditionalopcall!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)
    line_margin = s.line_offset + length(fst) + fst.extra_margin
    line_offset = s.line_offset
    fst.indent = s.line_offset

    nodes = fst.nodes::Vector
    src_diff_line = if s.opts.join_lines_based_on_source && length(nodes) > 1
        last_arg_idx = findlast(is_iterable_arg, nodes)
        last_arg = isnothing(last_arg_idx) ? fst[end] : fst[last_arg_idx]
        fst[1].endline != last_arg.startline
    else
        false
    end
    nested = false

    if line_margin > s.opts.margin || must_nest(fst) || src_diff_line
        nested = true
        phs = reverse(findall(n -> n.typ === PLACEHOLDER, nodes))
        if s.opts.join_lines_based_on_source
            phs = filter(idx -> fst[idx+1].typ !== NEWLINE, phs)
        end
        for (i, idx) in enumerate(phs)
            if i == 1
                fst[idx] = Newline(; length = fst[idx].len)
            else
                nidx = phs[i-1]
                l1 = sum(length.(fst[1:(idx-1)]))
                l2 = sum(length.(fst[idx:(nidx-1)]))
                width = line_offset + l1 + l2
                if must_nest(fst) || width > s.opts.margin
                    fst[idx] = Newline(; length = fst[idx].len)
                end
            end
        end

        for (i, n) in enumerate(nodes)
            if i == length(nodes)
                n.extra_margin = fst.extra_margin
                nest!(style, n, s, lineage)
            elseif fst[i+1].typ === WHITESPACE
                n.extra_margin = length(fst[i+1]) + length(fst[i+2])
                nest!(style, n, s, lineage)
            elseif n.typ === NEWLINE
                s.line_offset = fst.indent
            else
                nest!(style, n, s, lineage)
            end
        end

        s.line_offset = line_offset
        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE &&
               !is_comment(fst[i+1]) &&
               !is_comment(fst[i-1]) &&
               i in phs
                # +1 for newline to whitespace conversion
                width = s.line_offset + 1
                if i == length(nodes) - 1
                    width += sum(length.(fst[(i+1):end])) + fst.extra_margin
                else
                    width += sum(length.(fst[(i+1):(i+3)]))
                end
                if width <= s.opts.margin
                    fst[i] = Whitespace(1)
                    s.line_offset += length(fst[i])
                else
                    s.line_offset = fst.indent
                end
            elseif n.typ === NEWLINE
                s.line_offset = fst.indent
            else
                walk(increment_line_offset!, n, s)
            end
        end

        s.line_offset = line_offset
        walk(increment_line_offset!, fst, s)
    else
        nested |=
            nest!(style, nodes, s, fst.indent, lineage; extra_margin = fst.extra_margin)
    end
    return nested
end

function no_unnest(fst::FST)
    if fst.typ === Binary ||
       fst.typ === Conditional ||
       fst.typ === Chain ||
       fst.typ === Comparison
        return contains_comment(fst)
    end
    return false
end

function n_binaryopcall!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}};
    indent::Int = -1,
)
    style = getstyle(ds)

    line_offset = s.line_offset
    line_margin = line_offset + length(fst) + fst.extra_margin

    # If there are no top-level placeholders in the FST, the binary call itself is not
    # nestable (although its children, i.e. the operands, might be).
    nodes = fst.nodes::Vector
    idxs = findall(n -> n.typ === PLACEHOLDER, nodes)

    rhs = fst[end]
    if rhs.typ === Block
        (rhs = rhs[1])
    else
        false
    end

    # is the LHS on a different line than the RHS ?
    src_diff_line =
        s.opts.join_lines_based_on_source && fst[1].endline != fst[end].startline

    nested = false

    if length(idxs) == 2 &&
       (line_margin > s.opts.margin || must_nest(fst) || must_nest(rhs) || src_diff_line)
        i1 = idxs[1]
        i2 = idxs[2]
        fst[i1] = Newline(; length = fst[i1].len)
        nested = true

        indent_nest =
            (!isnothing(fst.metadata) && (fst.metadata::Metadata).is_short_form_function) ||
            is_assignment(fst) ||
            op_kind(fst) in KSet"=> ->" ||
            (
                !isnothing(fst.metadata) &&
                (fst.metadata::Metadata).is_standalone_shortcircuit
            )

        if indent_nest
            s.line_offset = fst.indent + s.opts.indent
            fst[i2] = Whitespace(s.opts.indent)

            # reset the indent of the RHS
            if fst[end].indent > fst.indent
                fst[end].indent = fst.indent
            end
            add_indent!(fst[end], s, s.opts.indent)
        else
            if indent >= 0
                fst.indent = indent
            else
                fst.indent = s.line_offset
            end
        end

        # rhs
        fst[end].extra_margin = fst.extra_margin
        nest!(style, fst[end], s, lineage)

        # "lhs op" rhs
        s.line_offset = line_offset

        # extra margin for " op"
        fst[1].extra_margin = length(fst[2]) + length(fst[3])
        nest!(style, fst[1], s, lineage) # lhs
        for n in fst[2:i1]
            nest!(style, n, s, lineage)
        end

        # Undo nest if possible
        if can_nest(fst) && !no_unnest(rhs) && !src_diff_line
            line_margin = s.line_offset

            # replace IN with all of precedence level 6
            if (rhs.typ === Binary && !(op_kind(rhs) in KSet"in ::")) ||
               rhs.typ === Unary && rhs[end].typ !== Brackets ||
               rhs.typ === Chain ||
               rhs.typ === Comparison ||
               rhs.typ === Conditional
                line_margin += length(fst[end])
            elseif rhs.typ === Do && is_iterable(rhs[1])
                rw, _ = length_to(fst, (NEWLINE,); start = i2 + 1)
                line_margin += rw
            elseif is_block(rhs)
                idx = findfirst(n -> n.typ === NEWLINE, rhs.nodes)
                if idx === nothing
                    line_margin += length(fst[end])
                else
                    line_margin += sum(length.(rhs[1:(idx-1)]))
                end
            else
                rw, _ = length_to(fst, (NEWLINE,); start = i2 + 1)
                line_margin += rw
            end

            if line_margin + fst.extra_margin <= s.opts.margin
                fst[i1] = Whitespace(1)
                if indent_nest || style isa YASStyle
                    fst[i2] = Whitespace(0)
                    walk(unnest!(style; dedent = true), rhs, s)
                end
            end
        end

        s.line_offset = line_offset
        walk(increment_line_offset!, fst, s)
        return nested
    end

    # When we nest the LHS, we have to do so with some knowledge of how much space the RHS
    # will take up. However, we don't need to account for the _full_ RHS, because the RHS
    # could itself be nested, and in general nesting the RHS is preferable to nesting the
    # LHS as it's prettier. That means we only need to account for the RHS up to the first
    # point where it could be nested.
    #
    # Since node 1 is the LHS, we start looking for the first placeholder from node 2
    # onwards.
    len_to_first_placeholder, found = length_to(fst, (PLACEHOLDER, NEWLINE); start = 2)
    lhs_extra_margin_needed = if found && op_kind(fst) !== K"::"
        len_to_first_placeholder
    else
        # Can't nest the op or RHS. That means that we need to account for the entire RHS,
        # plus anything that comes after the binary expression as well.
        sum(length, fst[2:end]) + fst.extra_margin
    end

    for (i, n) in enumerate(nodes)
        if n.typ === NEWLINE
            s.line_offset = fst.indent
        elseif i == 1
            n.extra_margin = lhs_extra_margin_needed
            nested |= nest!(style, n, s, lineage)
        elseif i == length(nodes)
            # rhs
            n.extra_margin = fst.extra_margin
            nested |= nest!(style, n, s, lineage)
        else
            nested |= nest!(style, n, s, lineage)
        end
    end

    return nested
end

function n_for!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ds)

    nested = false
    nodes = fst.nodes::Vector{FST}
    for (i, n) in enumerate(nodes)
        if n.typ === NEWLINE && nodes[i+1].typ === Block
            s.line_offset = nodes[i+1].indent
        elseif n.typ === NOTCODE && nodes[i+1].typ === Block
            s.line_offset = nodes[i+1].indent
        elseif n.typ === NEWLINE
            s.line_offset = fst.indent
        elseif n.typ === PLACEHOLDER && nested
            fst[i] = Newline(; length = n.len, nest_behavior = AllowNestButDontRemove)
            s.line_offset = fst.indent
        else
            n.extra_margin = fst.extra_margin
            nested |= nest!(style, n, s, lineage)
        end
    end

    return nested
end

function n_let!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_for!(ds, fst, s, lineage)
end

function n_block!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}};
    indent::Int = -1,
)
    style = getstyle(ds)

    line_margin = s.line_offset + length(fst) + fst.extra_margin
    nodes = fst.nodes::Vector
    idx = findfirst(n -> n.typ === PLACEHOLDER, nodes)
    has_nl = false
    if indent >= 0
        (fst.indent = indent)
    else
        false
    end

    if fst.typ === Chain &&
       !isnothing(fst.metadata) &&
       (fst.metadata::Metadata).is_standalone_shortcircuit
        fst.indent += s.opts.indent
    end

    src_diff_line = if s.opts.join_lines_based_on_source && length(nodes) > 1
        last_arg_idx = findlast(is_iterable_arg, nodes)
        last_arg = isnothing(last_arg_idx) ? fst[end] : fst[last_arg_idx]
        fst[1].endline != last_arg.startline
    else
        false
    end

    nested = false

    if idx !== nothing && (line_margin > s.opts.margin || must_nest(fst) || src_diff_line)
        nested = true

        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE
                s.line_offset = fst.indent
                has_nl = true
            elseif n.typ === PLACEHOLDER
                # NOTE:
                #
                # Placeholder at the end of a block is the separator
                # to the body. For example:
                #
                # for x in (a, b), y in (c, d)
                #     body
                # end
                #
                # If "x in (a, b), y in (c, d)" is nested then a newline
                # is inserted to separte "y in (c, d)" from "body":
                #
                # for x in (a, b),
                #     y in (c, d)
                #
                #     body
                # end
                #
                if s.opts.join_lines_based_on_source
                    if i < length(nodes)
                        si = findnext(
                            n -> n.typ === PLACEHOLDER || n.typ === NEWLINE,
                            nodes,
                            i + 1,
                        )
                        nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
                    elseif has_nl
                        fst[i] = Newline(; length = n.len)
                        s.line_offset = fst.indent
                    else
                        nest!(style, n, s, lineage)
                    end
                else
                    fst[i] = Newline(; length = n.len)
                    s.line_offset = fst.indent
                    has_nl = true
                end
            elseif n.typ === TRAILINGCOMMA
                n.val = ","
                n.len = 1
                nest!(style, n, s, lineage)
            else
                diff = fst.indent - fst[i].indent
                add_indent!(n, s, diff)
                if i < length(nodes) - 1 && fst[i+2].typ === OPERATOR
                    # chainopcall / comparison
                    n.extra_margin = 1 + length(fst[i+2])
                elseif i < length(nodes)
                    if !(i == length(nodes) - 1 && fst[i+1].typ === PLACEHOLDER)
                        n.extra_margin = 1
                    end
                end
                nest!(style, n, s, lineage)
            end
        end
    else
        nested |=
            nest!(style, nodes, s, fst.indent, lineage; extra_margin = fst.extra_margin)
    end
    return nested
end

function n_comparison!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_block!(ds, fst, s, lineage; indent = s.line_offset)
end

function n_chainopcall!(
    ds::AbstractStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_block!(ds, fst, s, lineage; indent = s.line_offset)
end
