struct YASStyle <: AbstractStyle
    innerstyle::AbstractStyle
end
YASStyle() = YASStyle(NoopStyle())
getstyle(s::YASStyle) = s.innerstyle isa NoopStyle ? s : s.innerstyle

function options(::YASStyle)
    return (;
        always_for_in = true,
        whitespace_ops_in_indices = true,
        remove_extra_newlines = true,
        import_to_using = true,
        pipe_to_function_call = true,
        short_to_long_function_def = true,
        long_to_short_function_def = false,
        always_use_return = true,
        whitespace_in_kwargs = false,
        join_lines_based_on_source = true,
        separate_kwargs_with_semicolon = true,
        indent = 4,
        margin = 92,
        whitespace_typedefs = false,
        annotate_untyped_fields_with_any = true,
        format_docstrings = false,
        align_struct_field = false,
        align_assignment = false,
        align_conditional = false,
        align_pair_arrow = false,
        conditional_to_if = false,
        normalize_line_endings = "auto",
        align_matrix = false,
        trailing_comma = true,
        trailing_zero = true,
        indent_submodule = false,
        surround_whereop_typeparameters = true,
        variable_call_indent = [],
        yas_style_nesting = false,
    )
end

function is_binaryop_nestable(::YASStyle, cst::JuliaSyntax.GreenNode)
    return !(defines_function(cst) || is_assignment(cst) || op_kind(cst) in KSet"=> ->")
end
@doc """
    YASStyle()

Formatting style based on [YASGuide](https://github.com/jrevels/YASGuide)
and [JuliaFormatter#198](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/198).

Configurable options with different defaults to [`DefaultStyle`](@ref) are:
$(list_different_defaults(YASStyle()))
"""
YASStyle

function p_import(
    ds::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Import, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for a in children(cst)
        if kind(a) in KSet"import export using public"
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        elseif kind(a) === K":" && haschildren(a)
            nodes = children(a)
            for n in nodes
                add_node!(t, pretty(style, n, s, ctx, lineage), s; join_lines = true)
                if kind(n) in KSet"import export using public :"
                    add_node!(t, Whitespace(1), s)
                elseif kind(n) in KSet","
                    add_node!(t, Placeholder(1), s)
                end
            end
        elseif kind(a) === K","
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Placeholder(1), s)
        elseif kind(a) === K":"
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        else
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
        end
    end
    t
end

function p_using(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_import(ys, cst, s, ctx, lineage)
    t.typ = Using
    t
end

function p_export(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_import(ys, cst, s, ctx, lineage)
    t.typ = Export
    t
end

function p_public(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_import(ys, cst, s, ctx, lineage)
    t.typ = Public
    t
end

function p_curly(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    nws = s.opts.whitespace_typedefs ? 1 : 0
    t = FST(Curly, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"{", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, newctx(ctx; from_typedef = true), lineage)

        override = (i == first_arg_idx) || kind(a) === K"}"

        if kind(a) === K","
            if has_more_args_to_come(childs, i + 1, K"}")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(nws), s)
            end
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end
    t
end

function p_braces(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(Braces, nspaces(s))
    if !haschildren(cst)
        return t
    end
    from_typedef = ctx.from_typedef

    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"{", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    nws = from_typedef && !s.opts.whitespace_typedefs ? 0 : 1

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)

        override = (i == first_arg_idx) || kind(a) === K"}"

        if kind(a) === K","
            if has_more_args_to_come(childs, i + 1, K"}")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(nws), s)
            end
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end
    t
end

function p_bracescat(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(BracesCat, nspaces(s))
    if !haschildren(cst)
        return t
    end
    from_typedef = ctx.from_typedef

    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"{", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    nws = from_typedef && !s.opts.whitespace_typedefs ? 0 : 1

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)

        override = (i == first_arg_idx) || kind(a) === K"}"

        if kind(a) === K";"
            if has_more_args_to_come(childs, i + 1, K"}")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(nws), s)
            end
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end
    t
end

function p_tupleblock(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(TupleBlock, nspaces(s))
    if !haschildren(cst)
        return t
    end

    nargs = length(get_args(cst))
    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"(", childs)
    first_arg_idx =
        isnothing(idx) ? -1 : findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        n = if kind(a) === K"=" && haschildren(a)
            p_kw(style, a, s, ctx, lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end

        override = (i == first_arg_idx) || kind(a) === K")"

        if kind(a) in KSet"; ,"
            if nargs == 1
                add_node!(t, n, s; join_lines = true)
            elseif has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end
    t
end

function p_tuple(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(TupleN, nspaces(s))
    if !haschildren(cst)
        return t
    end

    nargs = length(get_args(cst))
    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"(", childs)
    first_arg_idx =
        isnothing(idx) ? -1 : findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        n = if kind(a) === K"=" && haschildren(a)
            p_kw(style, a, s, ctx, lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end

        override = (i == first_arg_idx) || kind(a) === K")"

        if kind(a) === K","
            if nargs == 1
                add_node!(t, n, s; join_lines = true)
            elseif has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end
    t
end

function p_parens(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(Brackets, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    if length(args) > 0
        arg = args[1]
        if is_block(arg) ||
           (kind(arg) === K"generator" && haschildren(arg) && is_block(arg[1]))
            t.nest_behavior = AlwaysNest
        end
    end

    for c in children(cst)
        n = if kind(c) === K"block"
            pretty(style, c, s, newctx(ctx; from_quote = true), lineage)
        else
            pretty(style, c, s, ctx, lineage)
        end
        add_node!(t, n, s; join_lines = true, override_join_lines_based_on_source = true)
    end

    t
end

function p_call(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(Call, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    can_separate_kwargs = ctx.can_separate_kwargs

    # # With `variable_call_indent`, check if the caller is in the list
    # and use `p_call` from `DefaultStyle` instead to allow both
    # `caller(something,...)` and `caller(\n,...)`.
    if length(s.opts.variable_call_indent) > 0
        offset = if kind(childs[1]) === K"curly" && haschildren(childs[1])
            childs2 = children(childs[1])::Vector{JuliaSyntax.GreenNode{JuliaSyntax.SyntaxHead}}
            if length(childs2) > 0
                span(childs2[1]) + span(childs[2]) - 2
            else
                0
            end
        elseif length(childs) > 1
            span(childs[1]) + span(childs[2]) - 2
        else
            0
        end
        val = getsrcval(s.doc, (s.offset):(s.offset+offset))
        if val in s.opts.variable_call_indent
            return p_call(DefaultStyle(style), cst, s, ctx, lineage)
        end
    end

    idx = findfirst(n -> kind(n) === K"(", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        k = kind(a)
        n = if k == K"=" && haschildren(a)
            p_kw(style, a, s, ctx, lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end

        override = (i == first_arg_idx) || k === K")"

        if k === K","
            if has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(1), s)
            end
        else
            # For YAS style, the trailing comma usually won't be seen, because the closing
            # paren should be placed on the same line as the last argument. However, in the
            # case where the last argument is followed by a comment, the closing paren will
            # be placed on the next line, and in that case we want to allow a trailing
            # comma.
            k === K")" && add_node!(t, TrailingComma(), s)
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end

    if s.opts.separate_kwargs_with_semicolon && can_separate_kwargs
        separate_kwargs_with_semicolon!(t)
    end

    t
end

function p_vect(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(Vect, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"[", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        k = kind(a)
        n = pretty(style, a, s, ctx, lineage)

        override = (i == first_arg_idx) || k === K"]"

        if kind(a) === K","
            if has_more_args_to_come(childs, i + 1, K"]")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end
    t
end

function p_vcat(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(Vcat, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"[", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)
        override = i == first_arg_idx || kind(a) === K"]"

        if kind(a) === K"["
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K"]"
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        elseif JuliaSyntax.is_whitespace(a)
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K";"
            add_node!(t, n, s; join_lines = true)
        else
            join_lines = i == first_arg_idx ? true : t.endline == n.startline

            if !isnothing(first_arg_idx) && i > first_arg_idx && join_lines
                add_node!(t, Placeholder(1), s)
            end

            add_node!(
                t,
                n,
                s;
                join_lines = join_lines,
                override_join_lines_based_on_source = override,
            )
        end
    end
    t
end
function p_typedvcat(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_vcat(ys, cst, s, ctx, lineage)
    t.typ = TypedVcat
    t
end

function p_ncat(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_vcat(ys, cst, s, ctx, lineage)
    t.typ = Ncat
    t
end
function p_typedncat(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_ncat(ys, cst, s, ctx, lineage)
    t.typ = TypedNcat
    t
end

function p_ref(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(RefN, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"[", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        n = if is_opcall(a)
            pretty(style, a, s, newctx(ctx; nonest = true), lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end

        override = (i == first_arg_idx) || kind(a) === K"]"

        if kind(a) === K","
            if has_more_args_to_come(childs, i + 1, K"]")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end
    t
end

function p_comprehension(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(Comprehension, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    idx = findfirst(
        n -> !JuliaSyntax.is_whitespace(kind(n)) && !(kind(n) in KSet"[ ]"),
        childs,
    )
    arg = childs[idx]

    if is_block(arg) || (kind(arg) === K"generator" && haschildren(arg) && is_block(arg[1]))
        t.nest_behavior = AlwaysNest
    end

    for c in childs
        n = pretty(style, c, s, ctx, lineage)
        if kind(c) === K"["
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = true,
            )
        end
    end

    t
end

function p_typedcomprehension(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_comprehension(ys, cst, s, ctx, lineage)
    t.typ = TypedComprehension
    t
end

function p_macrocall(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(MacroCall, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    has_closer = is_closer(childs[end])
    is_macroblock = !has_closer

    if is_macroblock
        t.typ = MacroBlock
    end

    idx = findfirst(n -> kind(n) === K"(", childs)
    first_arg_idx =
        isnothing(idx) ? -1 : findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, newctx(ctx; can_separate_kwargs = false), lineage)::FST

        override = (i == first_arg_idx) || kind(a) === K")"

        if JuliaSyntax.is_macro_name(a) || kind(a) === K"("
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K","
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, Placeholder(1), s)
            end
        elseif JuliaSyntax.is_whitespace(a)
            add_node!(t, n, s; join_lines = true)
        elseif is_macroblock
            if n.typ === MacroBlock && t[end].typ === WHITESPACE
                t[end] = Placeholder(length(t[end].val))
            end

            max_padding = is_block(n) ? 0 : -1
            join_lines = t.endline == n.startline

            if join_lines && (i > 1 && kind(childs[i-1]) in KSet"NewlineWs Whitespace") ||
               next_node_is(nn -> kind(nn) in KSet"NewlineWs Whitespace", childs[i])
                add_node!(t, Whitespace(1), s)
            end
            add_node!(t, n, s; join_lines, max_padding)
        else
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )
        end
    end
    # move placement of @ to the end
    #
    # @Module.macro -> Module.@macro
    t[1] = move_at_sign_to_the_end(t[1], s)
    t
end

function p_whereopcall(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ys)
    t = FST(Where, nspaces(s))
    if !haschildren(cst)
        return t
    end

    from_typedef = ctx.from_typedef

    childs = children(cst)
    where_idx = findfirst(c -> kind(c) === K"where" && !haschildren(c), childs)
    curly_ctx = if where_idx === nothing
        from_typedef
    else
        if !(from_typedef)
            any(c -> kind(c) in KSet"curly bracescat braces", childs[(where_idx+1):end])
        else
            true
        end
    end
    add_braces = s.opts.surround_whereop_typeparameters && !curly_ctx

    nws = s.opts.whitespace_typedefs ? 1 : 0

    idx = findfirst(n -> kind(n) === K"{", childs)
    first_arg_idx =
        isnothing(idx) ? -1 : findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    after_where = false
    for (i, a) in enumerate(childs)
        if kind(a) === K"where" && !haschildren(a)
            add_node!(t, Whitespace(1), s)
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Whitespace(1), s)
            after_where = true
        elseif kind(a) === K"{"
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            s.indent += s.opts.indent
        elseif kind(a) === K"}"
            add_node!(
                t,
                pretty(style, a, s, ctx, lineage),
                s;
                join_lines = true,
                override_join_lines_based_on_source = true,
            )
            s.indent -= s.opts.indent
        elseif kind(a) === K","
            if has_more_args_to_come(childs, i + 1, K"}")
                add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
                add_node!(t, Placeholder(nws), s)
            end
        elseif JuliaSyntax.is_whitespace(a)
            add_node!(t, pretty(style, a, s), s; join_lines = true)
        else
            n = pretty(style, a, s, newctx(ctx; from_typedef = after_where), lineage)

            if after_where && add_braces
                brace = FST(PUNCTUATION, -1, n.endline, n.endline, "{")
                add_node!(t, brace, s; join_lines = true)
            end

            override = i == first_arg_idx
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override,
            )

            if after_where && add_braces
                brace = FST(PUNCTUATION, -1, n.endline, n.endline, "}")
                add_node!(t, brace, s; join_lines = true)
            end
        end
    end

    t
end

function p_generator(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}} = Tuple{JuliaSyntax.Kind,Bool,Bool}[],
)
    style = getstyle(ys)
    t = FST(Generator, nspaces(s))
    if !haschildren(cst)
        return t
    end

    has_for_kw = false

    from_iterable = false

    for (kind, is_itr, _) in Iterators.reverse(lineage)
        if kind in KSet"parens generator filter"
            continue
        elseif is_itr
            from_iterable = true
            break
        end
    end

    childs = children(cst)
    has_for_kw = findfirst(n -> kind(n) === K"for", childs) !== nothing
    from_for = has_for_kw || ctx.from_for

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, newctx(ctx; from_for = from_for), lineage)
        if JuliaSyntax.is_keyword(a) && !haschildren(a)
            idx = findprev(n -> !JuliaSyntax.is_whitespace(n), childs, i - 1)
            if !isnothing(idx) && is_block(childs[idx])
                add_node!(t, Newline(), s)
            elseif from_iterable
                add_node!(t, Placeholder(1), s)
            elseif !isnothing(idx)
                add_node!(t, Whitespace(1), s)
            end
            add_node!(t, n, s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        elseif kind(a) === K","
            if has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end

        if from_for && kind(a) === K"iteration"
            eq_to_in_normalization!(n, s.opts.always_for_in, s.opts.for_in_replacement)
        end
    end

    t
end

function p_filter(
    ys::YASStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_generator(ys, cst, s, ctx, lineage)
    t.typ = Filter
    t
end
