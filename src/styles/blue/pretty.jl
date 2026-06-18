function options(::BlueStyle)
    return Options(;
        always_use_return = true,
        short_to_long_function_def = true,
        long_to_short_function_def = false,
        whitespace_ops_in_indices = true,
        remove_extra_newlines = true,
        always_for_in = true,
        import_to_using = true,
        pipe_to_function_call = true,
        whitespace_in_kwargs = false,
        annotate_untyped_fields_with_any = false,
        conditional_to_if = true,
        indent_submodule = true,
        separate_kwargs_with_semicolon = true,
        indent = 4,
        margin = 92,
        whitespace_typedefs = false,
        format_docstrings = false,
        align_struct_field = false,
        align_assignment = false,
        align_conditional = false,
        align_pair_arrow = false,
        normalize_line_endings = "auto",
        align_matrix = false,
        join_lines_based_on_source = false,
        trailing_comma = true,
        trailing_zero = true,
        surround_whereop_typeparameters = true,
        variable_call_indent = [],
        yas_style_nesting = false,
    )
end

function is_binaryop_nestable(::BlueStyle, cst::JuliaSyntax.GreenNode)
    if is_assignment(cst) && haschildren(cst) && is_iterable(cst[end])
        return false
    end
    return is_binaryop_nestable(DefaultStyle(), cst)
end

function p_return(
    bs::BlueStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(bs)
    t = FST(Return, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    n_args = 0
    for c in childs
        if !JuliaSyntax.is_whitespace(c)
            n_args += 1
        end
    end

    if n_args > 1
        return p_return(DefaultStyle(bs), cst, s, ctx, lineage)
    end

    for c in childs
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end
    add_node!(t, Whitespace(1), s)
    no = FST(KEYWORD, -1, t.endline, t.endline, "nothing")
    add_node!(t, no, s; join_lines = true)
    t
end

function _ternary_to_ifelse!(
    # output_fst is mutated
    output_fst::FST,
    style::AbstractStyle,
    # cst must be a ternary operator with a ternary operator as its rhs
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
    # The outermost call emits "if" and appends "end"; recursive calls emit "elseif" and
    # produce a nested If sub-tree (mirroring JuliaSyntax's output).
    is_outermost::Bool,
    comment_nodes_from_parent::Vector{FST},
)
    question_mark_idx = findfirst(c -> kind(c) === K"?" && !haschildren(c), children(cst))
    colon_idx = findfirst(c -> kind(c) === K":" && !haschildren(c), children(cst))
    if question_mark_idx === nothing || colon_idx === nothing
        error(
            "expected a ternary operator with a question mark and a colon, but couldn't find one or both",
        )
    end

    # JuliaSyntax's CST places #= inline comments =# as top-level children of the `?` node.
    # We want to move them into the relevant blocks. To do that, we'll need to capture them
    # as we go along.
    comment_nodes = FST[]

    for (i, c) in enumerate(children(cst))
        if kind(c) === K"Comment"
            n = pretty(style, c, s, ctx, lineage)
            if n.typ === HASHEQCOMMENT
                push!(comment_nodes, n)
            else
                add_node!(output_fst, n, s)
            end
        elseif JuliaSyntax.is_whitespace(c)
            add_node!(output_fst, pretty(style, c, s, ctx, lineage), s)
        elseif kind(c) in KSet"? :" && !haschildren(c)
            s.offset += span(c)
        elseif i < question_mark_idx
            # Condition — emit "if" (outermost) or "elseif" (recursive).
            loc = cursor_loc(s)
            keyword = is_outermost ? "if" : "elseif"
            add_node!(
                output_fst,
                FST(KEYWORD, loc[2], loc[1], loc[1], keyword),
                s;
                max_padding = 0,
            )
            add_node!(output_fst, Whitespace(1), s)
            # If the condition begins with a line comment, we need to parenthesise it...
            # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1142
            if JuliaSyntax.is_leaf(c)
                add_node!(output_fst, pretty(style, c, s, ctx, lineage), s; join_lines = true)
            else
                first_nonws_idx = findfirst(cc -> !JuliaSyntax.is_whitespace(cc), children(c))
                node = if any(cc -> kind(cc) === K"Comment", children(c)[1:first_nonws_idx])
                    paren_fst = FST(Brackets, nspaces(s))
                    add_node!(paren_fst, FST(PUNCTUATION, loc[2], loc[1], loc[1], "("), s; join_lines = true)
                    add_node!(paren_fst, Placeholder(0), s)
                    add_node!(paren_fst, pretty(style, c, s, ctx, lineage), s; join_lines = true)
                    add_node!(paren_fst, Placeholder(0), s)
                    add_node!(paren_fst, FST(PUNCTUATION, loc[2], loc[1], loc[1], ")"), s; join_lines = true)
                    paren_fst
                else
                    pretty(style, c, s, ctx, lineage)
                end
                add_node!(output_fst, node, s; join_lines = true)
            end
        elseif i > question_mark_idx && i < colon_idx
            # True branch — wrap in a Block if not already one.
            s.indent += s.opts.indent
            if is_block(c)
                for n in [comment_nodes_from_parent..., comment_nodes...]
                    add_node!(output_fst, n, s)
                end
                comment_nodes = FST[]
                add_node!(
                    output_fst,
                    pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                    s;
                    max_padding = s.opts.indent,
                )
            else
                block_fst = FST(Block, nspaces(s))
                for n in [comment_nodes_from_parent..., comment_nodes...]
                    add_node!(block_fst, n, s)
                end
                comment_nodes = FST[]
                add_node!(
                    block_fst,
                    pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                    s;
                    max_padding = s.opts.indent,
                )
                add_node!(output_fst, block_fst, s; max_padding = s.opts.indent)
            end
            s.indent -= s.opts.indent
        elseif i > colon_idx
            # False branch.
            if kind(c) === K"?" && haschildren(c)
                # Chained ternary: build a nested If sub-tree for the elseif part, then add
                # it with the same max-len pattern that p_if uses for elseif subtrees.
                # 
                # TODO(penelopeysm): Why does p_if generate a nested tree anyway??
                inner_if = FST(If, nspaces(s))
                _ternary_to_ifelse!(
                    inner_if,
                    style,
                    c,
                    s,
                    ctx,
                    lineage,
                    false,
                    comment_nodes,
                )
                comment_nodes = FST[]
                len_before = length(output_fst)
                add_node!(output_fst, inner_if, s)
                output_fst.len = max(len_before, length(inner_if))
            else
                # Terminal else branch.
                loc = cursor_loc(s)
                add_node!(
                    output_fst,
                    FST(KEYWORD, loc[2], loc[1], loc[1], "else"),
                    s;
                    max_padding = 0,
                )
                s.indent += s.opts.indent
                if is_block(c)
                    for n in comment_nodes
                        add_node!(output_fst, n, s)
                    end
                    comment_nodes = FST[]
                    add_node!(
                        output_fst,
                        pretty(
                            style,
                            c,
                            s,
                            newctx(ctx; ignore_single_line = true),
                            lineage,
                        ),
                        s;
                        max_padding = s.opts.indent,
                    )
                else
                    block_fst = FST(Block, nspaces(s))
                    for n in comment_nodes
                        add_node!(block_fst, n, s)
                    end
                    comment_nodes = FST[]
                    add_node!(
                        block_fst,
                        pretty(
                            style,
                            c,
                            s,
                            newctx(ctx; ignore_single_line = true),
                            lineage,
                        ),
                        s;
                        max_padding = s.opts.indent,
                    )
                    add_node!(output_fst, block_fst, s; max_padding = s.opts.indent)
                end
                s.indent -= s.opts.indent
            end
        end
    end

    # Only the outermost call appends "end" — inner elseif sub-trees don't have their own
    # "end", matching the structure that p_if produces from real if/elseif/else source.
    if is_outermost
        loc = cursor_loc(s)
        add_node!(output_fst, FST(KEYWORD, loc[2], loc[1], loc[1], "end"), s)
    end

    return nothing
end

# Overload so that chained ternaries are always converted to if/elseif/else, regardless of
# the `conditional_to_if` option.
function p_conditionalopcall(
    bs::BlueStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(bs)
    if !haschildren(cst)
        return FST(Conditional, nspaces(s))
    end

    return if is_chained_ternary(cst)
        output_fst = FST(If, nspaces(s))
        _ternary_to_ifelse!(output_fst, style, cst, s, ctx, lineage, true, FST[])
        output_fst
    else
        p_conditionalopcall(DefaultStyle(bs), cst, s, ctx, lineage)
    end
end
