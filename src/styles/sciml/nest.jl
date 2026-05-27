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

function _n_tuple!(
    ss::SciMLStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ss)
    line_margin = s.line_offset + length(fst) + fst.extra_margin
    nodes = fst.nodes::Vector
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
    # Check if this RefN is the LHS of an assignment
    # Look through the lineage to see if we have a Binary assignment parent
    # and this RefN comes before any other Binary operators
    is_lhs_of_assignment = false

    if length(lineage) >= 2
        # Check if we have a Binary assignment in the lineage
        for i in length(lineage):-1:1
            if lineage[i][1] === Binary &&
               !isnothing(lineage[i][2]) &&
               lineage[i][2].is_assignment
                # Check if there are any other Binary nodes between us and the assignment
                has_intermediate_binary = false
                for j in (i+1):length(lineage)
                    if lineage[j][1] === Binary
                        has_intermediate_binary = true
                        break
                    end
                end

                if !has_intermediate_binary
                    is_lhs_of_assignment = true
                end
                break
            end
        end
    end

    if is_lhs_of_assignment
        # Don't break the LHS of an assignment
        # Format children but keep them on the same line
        lo = s.line_offset
        nested = false
        for (i, n) in enumerate(fst.nodes)
            nested |= nest!(ss, n, s, lineage)
            if n.typ !== NEWLINE  # Prevent any newlines
                s.line_offset += length(n)
            end
        end
        s.line_offset = lo + length(fst)
        return nested
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
