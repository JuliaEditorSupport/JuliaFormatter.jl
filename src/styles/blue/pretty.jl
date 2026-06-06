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
