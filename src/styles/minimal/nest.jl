# MinimalStyle nesting overrides.
#
# The default style aligns the continuation lines of operator chains, comparisons, and
# binary operator calls to the column at which the expression starts (`s.line_offset`).
# For example:
#
#     x = (aaa |>
#          bbb |>       <- aligned to the column of `aaa`
#          ccc)
#
# MinimalStyle instead uses plain indentation -- one indent level relative to the
# indentation of the expression (see issue #592):
#
#     x = (aaa |>
#         bbb |>        <- fst.indent + 4
#         ccc)
#
# This mirrors the BlueStyle overrides in styles/blue/nest.jl, which pass an explicit
# `indent` to the default implementations instead of letting them fall back to
# `s.line_offset`.

function n_chainopcall!(
    ms::MinimalStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    style = getstyle(ms)
    # Standalone short-circuit chains (e.g. a top-level `a && b && c` used only for its
    # side effects) already receive an extra `s.opts.indent` inside `n_block!`; passing
    # the extra indent here as well would double it.
    extra = if !isnothing(fst.metadata) && (fst.metadata::Metadata).is_standalone_shortcircuit
        0
    else
        s.opts.indent
    end
    n_block!(DefaultStyle(style), fst, s, lineage; indent = fst.indent + extra)
end

function n_comparison!(
    ms::MinimalStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    n_block!(
        DefaultStyle(getstyle(ms)),
        fst,
        s,
        lineage;
        indent = fst.indent + s.opts.indent,
    )
end

function n_binaryopcall!(
    ms::MinimalStyle,
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}};
    indent::Int = -1,
)
    # The `indent` keyword only takes effect on the non-`is_indent_nest` branch of the
    # default implementation; assignments, short-form defs, `=>`, and `->` already use
    # indent-based nesting (`fst.indent + s.opts.indent`) and are unaffected by this.
    n_binaryopcall!(
        DefaultStyle(getstyle(ms)),
        fst,
        s,
        lineage;
        indent = fst.indent + s.opts.indent,
    )
end
