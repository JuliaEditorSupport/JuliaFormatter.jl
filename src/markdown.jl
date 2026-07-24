"""
    JuliaFormatter.format_md(
        text::AbstractString,
        style::AbstractStyle = DefaultStyle();
        formatting_options...
    )

Normalizes the Markdown source and formats Julia code blocks.

See [Formatting Options](@ref formatting-options) for a list of available formatting options.
"""
function format_md(text::AbstractString; style::AbstractStyle = DefaultStyle(), kwargs...)
    return format_md(text, style; kwargs...)
end
function format_md(text::AbstractString, style::AbstractStyle; kwargs...)
    isempty(text) && return text
    opts = merge_options(options(style), Options{_Unset}(; kwargs...))
    return _format_md(text, style, opts)
end

function _format_md(text::AbstractString, style::AbstractStyle, opts::Options{Union{}})
    markdown(
        enable!(
            Parser(),
            [
                AdmonitionRule(),
                FootnoteRule(),
                MathRule(),
                TableRule(),
                FrontMatterRule(),
                FormatRule(style, opts, MarkdownFile),
            ],
        )(
            text,
        ),
    )
end
