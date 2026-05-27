for f in [
    :n_import!,
    :n_using!,
    :n_export!,
    :n_public!,
    :n_vcat!,
    :n_ncat!,
    :n_typedvcat!,
    :n_typedncat!,
    :n_row!,
    :n_nrow!,
    :n_hcat!,
    :n_comprehension!,
    :n_typedcomprehension!,
    :n_generator!,
    :n_filter!,
]
    @eval function $f(
        ss::SciMLStyle,
        fst::FST,
        s::State,
        lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
    )
        $f(YASStyle(getstyle(ss)), fst, s, lineage)
    end
end

# function n_binaryopcall!(ss::SciMLStyle, fst::FST, s::State, lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}}; indent::Int = -1)
#     style = getstyle(ss)
#     line_margin = s.line_offset + length(fst) + fst.extra_margin
#     if line_margin > s.opts.margin && !isnothing(fst.metadata) && fst.metadata.is_short_form_function
#         transformed = short_to_long_function_def!(fst, s)
#         transformed && nest!(style, fst, s, lineage)
#         return
#     end
#
#     if findfirst(n -> n.typ === PLACEHOLDER, fst.nodes) !== nothing
#         n_binaryopcall!(DefaultStyle(style), fst, s, lineage; indent = indent)
#         return
#     end
#
#     start_line_offset = s.line_offset
#     walk(increment_line_offset!, (fst.nodes::Vector)[1:end-1], s, fst.indent)
#     nest!(style, fst[end], s, lineage)
# end

function _is_for_tuple_binding(
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    length(lineage) >= 2 &&
        lineage[end-1][1] === CartesianIterator &&
        op_kind(fst) in KSet"in ∈" &&
        fst[1].typ === TupleN &&
        s.line_offset + length(fst[1]) <= s.opts.margin
end

function _nearest_binary_is_assignment(
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    i = findlast(x -> x[1] === Binary, lineage)
    i === nothing && return false

    metadata = lineage[i][2]
    return !isnothing(metadata) && metadata.is_assignment
end

function _align_tuple_comments!(fst::FST)
    for n in fst.nodes::Vector
        n.typ === NOTCODE && (n.indent = fst.indent)
    end
end

function _is_dict_call(fst::FST)
    fst.typ === Call &&
        length(fst.nodes::Vector) > 0 &&
        fst[1].typ === IDENTIFIER &&
        fst[1].val == "Dict"
end

function _is_tuple_pair(fst::FST)
    fst.typ === Binary && op_kind(fst) === K"=>" && fst[end].typ === TupleN
end

function _align_dict_tuple_pair_arrows!(fst::FST)
    pair_inds = findall(_is_tuple_pair, fst.nodes::Vector)
    length(pair_inds) > 1 || return

    align_len = maximum(node_align_length(fst[i][1]) for i in pair_inds)
    for i in pair_inds
        pair = fst[i]
        ws = align_len - node_align_length(pair[1]) + 1
        align_binaryopcall!(pair, ws)
    end
end

function _tuple_rhs_line_fits(rhs::FST, indent::Int, s::State)
    nodes = rhs.nodes::Vector
    idx = findfirst(
        n ->
            !(n.typ in (PUNCTUATION, WHITESPACE, PLACEHOLDER, NEWLINE, TRAILINGCOMMA)) && !is_closer(n),
        nodes,
    )
    isnothing(idx) && return true

    width, _ = length_to(rhs, (NEWLINE, PLACEHOLDER); start = idx)
    return indent + width + rhs.extra_margin <= s.opts.margin
end

function _align_pair_tuple_rhs!(
    fst::FST,
    s::State;
    align_to_pair::Bool = true,
    fallback_indent::Int = fst.indent + s.opts.indent,
)
    rhs = fst[end]
    rhs.typ === TupleN || return

    desired_indent = if !align_to_pair
        fallback_indent
    elseif length(rhs.nodes::Vector) > 1 && rhs[2].typ === NEWLINE
        rhs.indent - 1
    else
        fst.indent + node_align_length(fst[1:(end-1)]) + 1
    end
    add_indent!(rhs, s, desired_indent - rhs.indent)
    _align_tuple_comments!(rhs)
end

function _unnest_pair_tuple_body!(style::AbstractStyle, rhs::FST, s::State)
    lo = s.line_offset
    s.line_offset = rhs.indent
    for n in rhs.nodes::Vector
        n.typ === NEWLINE && (s.line_offset = rhs.indent; continue)
        walk(unnest!(style; dedent = false), n, s)
    end
    s.line_offset = lo
end

function _preserve_pair_tuple_newlines!(fst::FST; closer_indent::Int = fst.indent)
    rhs = fst[end]
    nodes = rhs.nodes::Vector
    length(nodes) > 2 || return

    nodes[2].typ !== NEWLINE && (nodes[2] = Newline(; length = nodes[2].len))
    if is_closer(nodes[end]) && nodes[end-1].typ !== NEWLINE
        nodes[end-1] = Newline(; length = nodes[end-1].len)
        nodes[end].indent = closer_indent
    end
end

function _preserve_multiline_closer!(fst::FST)
    nodes = fst.nodes::Vector
    length(nodes) > 2 && is_closer(nodes[end]) || return

    nodes[end-1].typ !== NEWLINE && (nodes[end-1] = Newline(; length = nodes[end-1].len))
end

function _unnest_short_binary_lines!(fst::FST, s::State)
    is_leaf(fst) && return

    if fst.typ === Binary && !contains_comment(fst) && fst.line_offset >= 0
        nl_inds = findall(n -> n.typ === NEWLINE, fst.nodes::Vector)
        if length(nl_inds) > 0 &&
           fst.line_offset + fst.extra_margin + node_align_length(fst) <= s.opts.margin
            nl_to_ws!(fst, nl_inds)
        end
    end

    for n in fst.nodes::Vector
        _unnest_short_binary_lines!(n, s)
    end
end

function n_binaryopcall!(
    ss::SciMLStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}};
    indent::Int = -1,
)
    if op_kind(fst) === K"=>" &&
       fst[end].typ === TupleN &&
       fst[1].endline == fst[end].startline
        style = getstyle(ss)
        rhs_style = YASStyle(style)
        nodes = fst.nodes::Vector
        oplen = sum(length.(fst[2:end]))
        line_offset = s.line_offset
        fallback_indent = line_offset + s.opts.indent
        nested = false
        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE
                s.line_offset = fst.indent
            elseif i == 1
                n.extra_margin = oplen + fst.extra_margin
                nested |= nest!(style, n, s, lineage)
            elseif i == length(nodes)
                n.extra_margin = fst.extra_margin
                align_to_pair = _tuple_rhs_line_fits(n, s.line_offset, s)
                n.indent = align_to_pair ? s.line_offset : fallback_indent
                nested |= nest!(rhs_style, n, s, lineage)
                _align_pair_tuple_rhs!(fst, s; align_to_pair, fallback_indent)
                if align_to_pair
                    lo = s.line_offset
                    walk(unnest!(rhs_style; dedent = false), n, s)
                    s.line_offset = lo
                    _unnest_short_binary_lines!(n, s)
                else
                    _unnest_pair_tuple_body!(rhs_style, n, s)
                    _preserve_pair_tuple_newlines!(fst; closer_indent = line_offset)
                end
                _align_tuple_comments!(n)
            else
                nested |= nest!(style, n, s, lineage)
            end
        end
        return nested
    end

    if _is_for_tuple_binding(fst, s, lineage)
        lhs = fst[1]
        nest_behavior = lhs.nest_behavior
        lhs.nest_behavior = NeverNest
        try
            return n_binaryopcall!(DefaultStyle(getstyle(ss)), fst, s, lineage; indent)
        finally
            lhs.nest_behavior = nest_behavior
        end
    end

    n_binaryopcall!(DefaultStyle(getstyle(ss)), fst, s, lineage; indent)
end

function n_functiondef!(
    ss::SciMLStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ss)
    nested = false
    if s.opts.yas_style_nesting
        nested |= nest!(
            YASStyle(style),
            fst.nodes::Vector,
            s,
            fst.indent,
            lineage;
            extra_margin = fst.extra_margin,
        )
    else
        base_indent = fst.indent
        add_indent!(fst[3], s, s.opts.indent)

        nested |= nest!(
            ss,
            fst.nodes::Vector,
            s,
            fst.indent,
            lineage;
            extra_margin = fst.extra_margin,
        )

        f =
            (fst::FST, s::State) -> begin
                if is_closer(fst) && fst.indent == base_indent + s.opts.indent
                    fst.indent -= s.opts.indent
                end
            end
        lo = s.line_offset
        walk(f, fst[3], s)
        s.line_offset = lo
    end
    return nested
end

function n_macro!(
    ss::SciMLStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_functiondef!(ss, fst, s, lineage)
end

function _is_multiline_typed_ref(fst::FST)
    fst.typ === RefN &&
        length(fst.nodes::Vector) > 1 &&
        fst[1].typ === Curly &&
        any(n -> n.typ === NEWLINE, fst.nodes::Vector)
end

function _has_multiline_do_args(fst::FST)
    length(fst.nodes::Vector) >= 5 &&
        fst[4].typ === WHITESPACE &&
        !is_leaf(fst[5]) &&
        any(n -> n.typ === NEWLINE, fst[5].nodes::Vector)
end

function n_do!(
    ss::SciMLStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ss)
    extra_margin = sum(length.(fst[2:3]))
    if fst[4].typ === WHITESPACE
        extra_margin += length(fst[4])
        if !_has_multiline_do_args(fst)
            extra_margin += length(fst[5])
        end
    end
    fst[1].extra_margin = fst.extra_margin + extra_margin

    nested = false
    nested |= nest!(style, fst[1], s, lineage)
    nested |=
        nest!(style, fst[2:end], s, fst.indent, lineage; extra_margin = fst.extra_margin)
    return nested
end

function _n_tuple!(
    ss::SciMLStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ss)
    nodes = fst.nodes::Vector
    _is_dict_call(fst) &&
        fst.startline != fst.endline &&
        _align_dict_tuple_pair_arrows!(fst)

    line_margin = s.line_offset + length(fst) + fst.extra_margin
    has_closer = is_closer(fst[end])
    start_line_offset = s.line_offset

    if has_closer
        fst[end].indent = fst.indent
    end
    if !(fst.typ in (TupleN, CartesianIterator, Parameters)) || has_closer
        fst.indent += s.opts.indent
    end

    # "foo(a, b, c)" is true if "foo" and "c" are on different lines
    src_diff_line = if s.opts.join_lines_based_on_source
        last_arg_idx = findlast(is_iterable_arg, nodes)
        last_arg = last_arg_idx === nothing ? fst[end] : fst[last_arg_idx]
        fst[1].endline != last_arg.startline
    else
        false
    end

    nested = false
    optimal_placeholders = find_optimal_nest_placeholders(fst, fst.indent, s.opts.margin)
    if length(optimal_placeholders) > 0
        nested = true
    end

    for i in optimal_placeholders
        fst[i] = Newline(; length = fst[i].len)
    end

    placeholder_inds = findall(n -> n.typ === PLACEHOLDER, fst.nodes)
    for (i, ph) in enumerate(placeholder_inds)
        if i == 1 ||
           i == length(placeholder_inds) ||
           (ph < length(fst) && is_comment(fst[ph+1])) ||
           (ph > 1 && is_comment(fst[ph-1]))
            continue
        end
        fst[ph] = Whitespace(fst[ph].len)
    end

    # macrocall doesn't have a placeholder before the closing parenthesis
    if fst.typ !== MacroCall && has_closer && length(placeholder_inds) > 0
        fst[placeholder_inds[end]] = Whitespace(0)
    end
    idx = findlast(n -> n.typ === PLACEHOLDER, nodes)

    # Check if we should apply conservative nesting rules
    should_nest = line_margin > s.opts.margin || must_nest(fst) || src_diff_line

    # For certain types, be more conservative about nesting
    if should_nest && !must_nest(fst) && !src_diff_line
        total_length = line_margin
        if (
            fst.typ === Call &&
            length(placeholder_inds) <= 5 &&
            total_length <= s.opts.margin + 20
        )
            should_nest = false
        elseif (fst.typ === Binary || fst.typ === Chain) &&
               length(placeholder_inds) <= 6 &&
               total_length <= s.opts.margin + 20
            should_nest = false
        elseif (
            fst.typ === RefN &&
            length(placeholder_inds) <= 4 &&
            total_length <= s.opts.margin + 30
        )
            # Keep array indexing together when reasonable (e.g., du[i, j, 1])
            should_nest = false
        end
    end

    if idx !== nothing && should_nest
        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE
                s.line_offset = fst.indent
            elseif n.typ === PLACEHOLDER
                si = findnext(n -> n.typ === PLACEHOLDER || n.typ === NEWLINE, nodes, i + 1)
                nested2 = nest_if_over_margin!(style, fst, s, i, lineage; stop_idx = si)
                nested |= nested2
                if has_closer && !nested2 && n.startline == fst[end].startline
                    # trailing types are automatically converted, undo this if
                    # there is no nest and the closer is on the same in the
                    # original source.
                    if fst[i-1].typ === TRAILINGCOMMA
                        fst[i-1].val = ""
                        fst[i-1].len = 0
                    end
                end
            elseif n.typ === TRAILINGCOMMA
                n.val = ","
                n.len = 1
                nested |= nest!(style, n, s, lineage)
            elseif has_closer && (i == 1 || i == length(nodes))
                nested |= nest!(style, n, s, lineage)
            else
                diff = fst.indent - fst[i].indent
                add_indent!(n, s, diff)
                n.extra_margin = 1

                nested |= nest!(style, n, s, lineage)
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

    s.line_offset = start_line_offset
    walk(unnest!(style; dedent = false), fst, s)
    _is_dict_call(fst) && fst.startline != fst.endline && _preserve_multiline_closer!(fst)
    s.line_offset = start_line_offset
    walk(increment_line_offset!, fst, s)

    return nested
end

# Custom implementation for n_ref! to prevent breaking LHS of assignments
function n_ref!(
    ss::SciMLStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    if _nearest_binary_is_assignment(lineage) && fst.extra_margin > 0
        # Don't break the LHS of an assignment
        # Format children but keep them on the same line
        nodes = fst.nodes::Vector{FST}
        for (i, n) in enumerate(nodes)
            if n.typ === NEWLINE &&
               (i == 1 || !is_comment(nodes[i-1])) &&
               (i == length(nodes) || !is_comment(nodes[i+1]))
                nodes[i] = Whitespace(n.len)
            end
        end

        lo = s.line_offset
        nested = false
        for n in nodes
            nested |= nest!(ss, n, s, lineage)
            if n.typ !== NEWLINE  # Prevent any newlines
                s.line_offset += length(n)
            end
        end
        s.line_offset = lo + length(fst)
        return nested
    end

    if _is_multiline_typed_ref(fst)
        return n_ref!(YASStyle(getstyle(ss)), fst, s, lineage)
    end

    # Otherwise use the default behavior
    if s.opts.yas_style_nesting
        return n_ref!(YASStyle(getstyle(ss)), fst, s, lineage)
    else
        return _n_tuple!(getstyle(ss), fst, s, lineage)
    end
end

for f in [
    :n_tuple!,
    :n_call!,
    :n_curly!,
    :n_macrocall!,
    :n_braces!,
    :n_parameters!,
    :n_invisbrackets!,
    :n_bracescat!,
]
    @eval function $f(
        ss::SciMLStyle,
        fst::FST,
        s::State,
        lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
    )
        if s.opts.yas_style_nesting
            $f(YASStyle(getstyle(ss)), fst, s, lineage)
        else
            _n_tuple!(getstyle(ss), fst, s, lineage)
        end
    end
end

function n_vect!(
    ss::SciMLStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    if s.opts.yas_style_nesting
        # Allow a line break after the opening brackets without aligning
        n_vect!(DefaultStyle(getstyle(ss)), fst, s, lineage)
    else
        _n_tuple!(getstyle(ss), fst, s, lineage)
    end
end

for f in [:n_chainopcall!, :n_comparison!, :n_for!]
    @eval function $f(
        ss::SciMLStyle,
        fst::FST,
        s::State,
        lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
    )
        if s.opts.yas_style_nesting
            $f(YASStyle(getstyle(ss)), fst, s, lineage)
        else
            $f(DefaultStyle(getstyle(ss)), fst, s, lineage)
        end
    end
end
