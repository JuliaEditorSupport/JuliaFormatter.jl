struct BlueStyle <: AbstractStyle
    innerstyle::AbstractStyle
end
BlueStyle() = BlueStyle(NoopStyle())
getstyle(s::BlueStyle) = s.innerstyle isa NoopStyle ? s : s.innerstyle

function options(::BlueStyle)
    return (;
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

@doc """
    BlueStyle()

Formatting style based on [BlueStyle](https://github.com/invenia/BlueStyle)
and [JuliaFormatter#283](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/283).

!!! note
    This style is still work-in-progress, and does not yet implement all of the
    BlueStyle guide.

Configurable options with different defaults to [`DefaultStyle`](@ref) are:
$(list_different_defaults(BlueStyle()))
"""
BlueStyle

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
)
    # Currently ignoring comments for now ... we'll check their behaviour later.

    question_mark_idx = findfirst(c -> kind(c) === K"?" && !haschildren(c), children(cst))
    colon_idx = findfirst(c -> kind(c) === K":" && !haschildren(c), children(cst))
    if question_mark_idx === nothing || colon_idx === nothing
        # Really should not happen unless JuliaSyntax is wacky
        error("expected a ternary operator with a question mark and a colon, but couldn't find one or both")
    end

    # If it's the first time we call this function, then `output_fst` will be empty, and the
    # first thing we add to it is `if`. Subsequent recursive calls should add `elseif`
    # instead.
    is_outermost_ternary = isempty(output_fst)
    
    # JuliaSyntax's CST places #= inline comments =# as top-level children of the `?` node.
    # We want to move them into the relevant blocks. To do that, we'll need to capture them
    # as we go along.
    comment_nodes = []

    for (i, c) in enumerate(children(cst))
        if kind(c) === K"Comment"
            n = pretty(style, c, s, ctx, lineage)
            if n.typ === HASHEQCOMMENT
                # save it for the next block we see
                push!(comment_nodes, n)
            else
                # normal line comment
                add_node!(output_fst, n, s)
            end
        elseif JuliaSyntax.is_whitespace(c)
            add_node!(output_fst, pretty(style, c, s, ctx, lineage), s)
        elseif kind(c) in KSet"? :" && !haschildren(c)
            # Skip over -- not needed -- but need to advance the offset
            s.offset += span(c)
        elseif i < question_mark_idx
            # condition
            # TODO: handle blocks....... see default/pretty p_if
            loc = cursor_loc(s)
            keyword = is_outermost_ternary ? "if" : "elseif"
            add_node!(
                output_fst,
                FST(KEYWORD, loc[2], loc[1], loc[1], keyword),
                s;
                max_padding = 0,
            )
            add_node!(output_fst, Whitespace(1), s)
            add_node!(output_fst, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        elseif i > question_mark_idx && i < colon_idx
            # true branch
            s.indent += s.opts.indent
            # If the expression here is not in a block, we need to enclose it in one. The
            # good news is that we can't legitimately have multiple statements inside a
            # ternary since Julia expects a single expression.
            if is_block(c)
                for n in comment_nodes
                    add_node!(output_fst, n, s)
                end
                comment_nodes = []
                add_node!(
                    output_fst,
                    pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                    s;
                    max_padding = s.opts.indent,
                )
            else
                inner_fst = FST(Block, nspaces(s))
                for n in comment_nodes
                    add_node!(inner_fst, n, s)
                end
                comment_nodes = []
                add_node!(
                    inner_fst,
                    pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                    s;
                    max_padding = s.opts.indent,
                )
                add_node!(output_fst, inner_fst, s; max_padding = s.opts.indent)
            end
            s.indent -= s.opts.indent
        elseif i > colon_idx
            # false branch
            if kind(c) === K"?" && haschildren(c)
                # chained ternary -- recurse
                _ternary_to_ifelse!(output_fst, style, c, s, ctx, lineage)
            else
                # else branch -- we're done!
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
                    comment_nodes = []
                    add_node!(
                        output_fst,
                        pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                        s;
                        max_padding = s.opts.indent,
                    )
                else
                    inner_fst = FST(Block, nspaces(s))
                    for n in comment_nodes
                        add_node!(inner_fst, n, s)
                    end
                    comment_nodes = []
                    add_node!(
                        inner_fst,
                        pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                        s;
                        max_padding = s.opts.indent,
                    )
                    add_node!(output_fst, inner_fst, s; max_padding = s.opts.indent)
                end
                s.indent -= s.opts.indent
                add_node!(output_fst, FST(KEYWORD, loc[2], loc[1], loc[1], "end"), s)
            end
        end
    end
    return nothing

    # for c in children(cst)
    #     if kind(c) in KSet"if elseif else"
    #         if !haschildren(c)
    #             add_node!(t, pretty(style, c, s, ctx, lineage), s; max_padding = 0)
    #         else
    #             # TODO(penelopeysm) how can an if/elseif/else keyword have a child?
    #             len = length(t)
    #             n = pretty(style, c, s, ctx, lineage)
    #             add_node!(t, n, s)
    #             t.len = max(len, length(n))
    #         end
    #         if kind(c) in KSet"if elseif"
    #             # The next non-whitespace node we see is the condition.
    #             is_cond = true
    #         end
    #     elseif kind(c) === K"end"
    #         add_node!(t, pretty(style, c, s, ctx, lineage), s)
    #     elseif kind(c) === K"block"
    #         # This block could either be the condition (if it immediatelly follows an `if`
    #         # or `elseif`, ignoring whitespace), or it could be the actual body. This is
    #         # determined by the `is_cond` flag.
    #         if is_cond
    #             add_node!(t, Whitespace(1), s)
    #             add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    #             # The next block will be the body.
    #             is_cond = false
    #         else
    #             s.indent += s.opts.indent
    #             add_node!(
    #                 t,
    #                 pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
    #                 s;
    #                 max_padding = s.opts.indent,
    #             )
    #             s.indent -= s.opts.indent
    #         end
    #     elseif !JuliaSyntax.is_whitespace(c)
    #         # This branch is hit for non-block conditions (i.e. simple things like the `x`
    #         # in `if x; ...`).
    #         add_node!(t, Whitespace(1), s)
    #         add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    #         if is_cond # should be true, but check just to be safe
    #             is_cond = false
    #         end
    #     else
    #         add_node!(t, pretty(style, c, s, ctx, lineage), s)
    #     end
    # end
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

    # identify rhs of ternary and if it is itself a ternary, generate an if/elseif/else
    # block instead of a chained ternary
    rhs = findlast(c -> !JuliaSyntax.is_whitespace(c), children(cst))
    return if rhs !== nothing && kind(cst[rhs]) == K"?" && haschildren(cst[rhs])
        output_fst = FST(If, nspaces(s))
        _ternary_to_ifelse!(output_fst, style, cst, s, ctx, lineage)
        output_fst
    else
        p_conditionalopcall(DefaultStyle(bs), cst, s, ctx, lineage)
    end
end

