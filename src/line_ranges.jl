# Line-range formatting (the `lines` keyword / `jlfmt --lines`).
#
# JuliaFormatter formats whole files. To restrict formatting to a set of line ranges (e.g.
# only the lines touched by a PR, or the `Range`s of an LSP `textDocument/rangesFormatting`
# request) we do *not* teach the formatting pipeline about line ranges. Instead, following
# the approach Runic.jl takes (https://github.com/fredrikekre/Runic.jl/pull/120), we keep
# the feature completely orthogonal to the formatting logic:
#
#   1. Insert marker comments around the requested line ranges in the source text.
#   2. Format the whole (marked) source as usual -- the in-range code is therefore formatted
#      in its full surrounding context, so it reflows correctly.
#   3. Splice the result back together line by line: take the formatted lines that fall
#      *between* a begin/end marker pair, take the *original* source verbatim everywhere
#      else, and drop the marker lines themselves.
#
# This means out-of-range lines are emitted byte-for-byte as they appeared in the input,
# which is exactly the "don't churn unrelated lines / git blame" property we want.

# Markers delimiting an in-range block. We deliberately use *line* comments rather than
# `#= ... =#` block comments: JuliaFormatter is known to relocate block comments onto the
# end of the preceding line (https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/571),
# which would break the line-based splice in `remove_line_range_markers`. A standalone line
# comment is reliably kept on its own line. The names are intentionally obscure so they are
# very unlikely to collide with anything a user actually wrote.
const LINE_RANGE_MARKER_BEGIN = "# __JuliaFormatter_line_range_begin__"
const LINE_RANGE_MARKER_END = "# __JuliaFormatter_line_range_end__"

_line_range(r::AbstractUnitRange) = Int(first(r)):Int(last(r))
function _line_range(t)
    # Accept `(start, stop)` tuples (the documented form, `lines = [(1, 10), (42, 47)]`) and
    # any other 2-element collection.
    length(t) == 2 || throw(
        ArgumentError(
            "invalid `lines` entry $(repr(t)): expected a `(start, stop)` pair or a range",
        ),
    )
    a, b = t
    return Int(a):Int(b)
end

"""
    normalize_line_ranges(lines) -> Vector{UnitRange{Int}}

Convert the user-supplied `lines` (a collection of `(start, stop)` tuples and/or ranges,
inclusive and 1-based) into a sorted vector of non-overlapping, non-adjacent
`UnitRange{Int}`s.

Overlapping and *adjacent* ranges are merged rather than rejected: this keeps the core API
robust for callers such as LSP `rangesFormatting`, which may legitimately hand us touching
or overlapping `Range`s. Bounds against the actual file length are checked later, in
[`add_line_range_markers`](@ref).
"""
function normalize_line_ranges(lines)
    ranges = UnitRange{Int}[]
    for x in lines
        r = _line_range(x)
        first(r) >= 1 || throw(
            ArgumentError(
                "invalid `lines` entry $(repr(x)): line numbers are 1-based, got start $(first(r))",
            ),
        )
        first(r) <= last(r) || throw(
            ArgumentError(
                "invalid `lines` entry $(repr(x)): empty range (start $(first(r)) > stop $(last(r)))",
            ),
        )
        push!(ranges, r)
    end
    sort!(ranges; by = first)
    merged = UnitRange{Int}[]
    for r in ranges
        # Merge when this range overlaps or is directly adjacent to the previous one
        # (`first(r) <= last(prev) + 1`), so e.g. `1:3` and `4:6` collapse into `1:6`.
        if !isempty(merged) && first(r) <= last(merged[end]) + 1
            prev = merged[end]
            merged[end] = first(prev):max(last(prev), last(r))
        else
            push!(merged, r)
        end
    end
    return merged
end

"""
    add_line_range_markers(text, ranges) -> String

Return a copy of `text` with `LINE_RANGE_MARKER_BEGIN` / `LINE_RANGE_MARKER_END`
comment lines inserted just before and just after each range in `ranges` (a normalized
vector of `UnitRange{Int}`). Throws an `ArgumentError` if a range is out of bounds.
"""
function add_line_range_markers(text::AbstractString, ranges::Vector{UnitRange{Int}})
    lines = collect(eachline(IOBuffer(text); keep = true))
    isempty(lines) && return text
    # Insert from the back so that the indices of earlier ranges are unaffected by the
    # insertions made for later ones.
    for r in sort(ranges; by = first, rev = true)
        a, b = first(r), last(r)
        # Some tooling treats a trailing newline as the start of a new (empty) line. Allow a
        # range to reference that phantom line by clamping `b` back onto the last real line
        # (and skipping the range entirely if it is *only* that phantom line).
        if endswith(lines[end], "\n") && b == length(lines) + 1
            a == length(lines) + 1 && continue
            b = length(lines)
        end
        if a < 1 || b > length(lines)
            throw(
                ArgumentError(
                    "`lines` range $a:$b is out of bounds (input has $(length(lines)) lines)",
                ),
            )
        end
        # If the file's final line has no trailing newline and the range reaches it, add one
        # so that the END marker we insert after it lands on its own line instead of being
        # glued onto the final line of code.
        if b == length(lines) && !endswith(lines[end], "\n")
            lines[end] *= "\n"
        end
        insert!(lines, b + 1, LINE_RANGE_MARKER_END * "\n")
        insert!(lines, a, LINE_RANGE_MARKER_BEGIN * "\n")
    end
    return join(lines)
end

"""
    remove_line_range_markers(marked_src, formatted) -> String

Splice the formatted in-range blocks back into the original source. `marked_src` is the
marker-annotated source produced by [`add_line_range_markers`](@ref) and `formatted` is the
result of formatting it. The two streams are walked line by line in lockstep:

  - outside a marker pair we keep the (verbatim) `marked_src` line,
  - inside a marker pair we keep the `formatted` line,
  - marker lines themselves are dropped.

Both streams contain the same markers in the same order, so the begin/end markers act as
synchronization points between them.
"""
function remove_line_range_markers(marked_src::AbstractString, formatted::AbstractString)
    src_lines = collect(eachline(IOBuffer(marked_src); keep = true))
    fmt_lines = collect(eachline(IOBuffer(formatted); keep = true))
    nsrc, nfmt = length(src_lines), length(fmt_lines)
    io = IOBuffer()
    si = fi = 1
    while true
        # Emit source (out-of-range) lines until the next begin marker, dropping any marker
        # lines we pass (the leading line here may be an end marker left over from the
        # previous iteration).
        while si <= nsrc && !occursin(LINE_RANGE_MARKER_BEGIN, src_lines[si])
            if !occursin(LINE_RANGE_MARKER_END, src_lines[si])
                write(io, src_lines[si])
            end
            si += 1
        end
        si > nsrc && break
        # `src_lines[si]` is a begin marker: skip the original in-range source up to its end
        # marker (we use the formatted version of those lines instead).
        while si <= nsrc && !occursin(LINE_RANGE_MARKER_END, src_lines[si])
            si += 1
        end
        @assert si <= nsrc "unbalanced line-range markers in source"
        # Advance the formatted stream to its matching begin marker, dropping the formatted
        # out-of-range lines (we already emitted those from the source).
        while fi <= nfmt && !occursin(LINE_RANGE_MARKER_BEGIN, fmt_lines[fi])
            fi += 1
        end
        @assert fi <= nfmt "begin marker did not survive formatting"
        # Emit formatted in-range lines until the end marker.
        while fi <= nfmt && !occursin(LINE_RANGE_MARKER_END, fmt_lines[fi])
            if !occursin(LINE_RANGE_MARKER_BEGIN, fmt_lines[fi])
                write(io, fmt_lines[fi])
            end
            fi += 1
        end
        @assert fi <= nfmt "end marker did not survive formatting"
    end
    return String(take!(io))
end

"""
    format_line_ranges(text, style, lines; kwargs...) -> String

Format only the lines of `text` covered by `lines` (a collection of inclusive, 1-based
`(start, stop)` tuples and/or ranges), emitting all other lines verbatim. See the comment at
the top of this file for the overall strategy.
"""
function format_line_ranges(text::AbstractString, style::AbstractStyle, lines; kwargs...)
    ranges = normalize_line_ranges(lines)
    isempty(ranges) && return text  # nothing requested -> nothing formatted
    marked = add_line_range_markers(text, ranges)
    formatted = format_text(marked, style; kwargs...)
    spliced = remove_line_range_markers(marked, formatted)
    # When the range reaches the final line, `add_line_range_markers` may have appended a
    # trailing newline (so the END marker lands on its own line). Match the input's
    # trailing-newline state, just as whole-file `format_text` preserves it, rather than
    # gaining a stray newline.
    if !endswith(text, "\n") && endswith(spliced, "\n")
        spliced = String(chomp(spliced))
    end
    return spliced
end
