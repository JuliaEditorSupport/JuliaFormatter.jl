"""
    MinimalStyle()
"""
struct MinimalStyle <: AbstractStyle
    innerstyle::Union{Nothing,AbstractStyle}
end
MinimalStyle() = MinimalStyle(NoopStyle())
getstyle(s::MinimalStyle) = s.innerstyle isa NoopStyle ? s : s.innerstyle

function options(::MinimalStyle)
    return (;
        indent = 4,
        annotate_untyped_fields_with_any = false,
        join_lines_based_on_source = true,
        trailing_comma = nothing,
        trailing_zero = false,
        margin = 10_000,
        always_for_in = nothing,
        whitespace_in_kwargs = false,
        whitespace_typedefs = false,
        whitespace_ops_in_indices = false,
        remove_extra_newlines = false,
        import_to_using = false,
        pipe_to_function_call = false,
        short_to_long_function_def = false,
        long_to_short_function_def = false,
        always_use_return = false,
        format_docstrings = false,
        align_struct_field = false,
        align_assignment = false,
        align_conditional = false,
        align_pair_arrow = false,
        conditional_to_if = false,
        normalize_line_endings = "auto",
        align_matrix = false,
        indent_submodule = false,
        separate_kwargs_with_semicolon = false,
        surround_whereop_typeparameters = false,
        variable_call_indent = [],
        yas_style_nesting = false,
    )
end
