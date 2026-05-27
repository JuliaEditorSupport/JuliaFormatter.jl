function skip_indent(fst::FST)
    if fst.typ == LITERAL && fst.val == ""
        return true
    elseif fst.typ === NEWLINE || fst.typ === NOTCODE
        return true
    end
    false
end

function walk(f::Function, nodes::Vector{FST}, s::State, indent::Int)
    for (i, n) in enumerate(nodes)
        if n.typ === NEWLINE && i < length(nodes)
            if is_closer(nodes[i+1])
                s.line_offset = nodes[i+1].indent
            elseif !skip_indent(nodes[i+1])
                s.line_offset = indent
            end
        else
            walk(f, n, s)
        end
    end
end

"""
    walk(f, fst::FST, s::State)

Walks `fst` calling `f` on each node.

In situations where descending further into a subtree is not desirable `f`
should return a value other than `nothing`.

!!! note
    This function mutates the State's (`s`) `line_offset`. If this is not desired
    you should save the value before calling this function and restore it after.
"""
function walk(f::Function, fst::FST, s::State)
    stop = f(fst, s)
    if (stop !== nothing || is_leaf(fst))
        return
    end
    walk(f, fst.nodes::Vector, s, fst.indent)
end

function increment_line_offset!(fst::FST, s::State)
    if !(is_leaf(fst))
        return
    end
    s.line_offset += length(fst)
    return nothing
end

function add_indent!(fst::FST, s::State, indent::Int)
    if indent == 0
        return
    end
    f = (fst::FST, _::State) -> begin
        fst.indent += indent
        return nothing
    end
    lo = s.line_offset
    walk(f, fst, s)
    s.line_offset = lo
end

function gettreeval(fst::FST)::String
    if is_leaf(fst)
        return fst.val
    end
    ss = ""
    for n in fst.nodes
        ss *= gettreeval(n)
    end
    return ss
end

# unnest, converts newlines to whitespace
function nl_to_ws!(fst::FST, nl_inds::Vector{Int})
    for (i, ind) in enumerate(nl_inds)
        fst[ind] = Whitespace(fst[ind].len)
        if !(i == length(nl_inds))
            continue
        end
        pn = fst[ind-1]
        if pn.typ === TRAILINGCOMMA
            pn.val = ""
            pn.len = 0
        elseif fst.typ === Binary && fst[ind+1].typ === WHITESPACE
            # remove additional indent
            fst[ind+1] = Whitespace(0)
        end
    end
end

function nl_to_ws!(fst::FST, s::State)
    nl_inds = findall(n -> n.typ === NEWLINE && can_nest(n), fst.nodes)
    if !(length(nl_inds) > 0)
        return
    end
    margin = s.line_offset + fst.extra_margin + length(fst)
    if margin <= s.opts.margin
        nl_to_ws!(fst, nl_inds)
    end
    return
end

function dedent!(::AbstractStyle, fst::FST, s::State)
    if is_closer(fst) || fst.typ === NOTCODE
        fst.indent -= s.opts.indent
    elseif is_leaf(fst) || fst.typ === StringN
        return
    else
        fst.indent -= s.opts.indent
    end
end

function dedent!(::YASStyle, fst::FST, s::State)
    if is_closer(fst) || fst.typ === NOTCODE
        fst.indent -= s.opts.indent
    elseif is_leaf(fst) || fst.typ === StringN
        return
    elseif is_unnamed_iterable(fst)
        fst.indent = s.line_offset
        if is_opener(fst[1])
            fst.indent += 1
        end
    elseif is_named_iterable(fst)
        fst.indent = s.line_offset + length(fst[1]) + length(fst[2])
    else
        fst.indent = s.line_offset
    end
end

function unnest!(style::AbstractStyle, fst::FST, s::State; dedent::Bool)
    if is_leaf(fst)
        s.line_offset += length(fst)
    end

    if dedent
        dedent!(style, fst, s)
    end

    if is_leaf(fst) || fst.typ === StringN || !can_nest(fst)
        return
    end

    nl_to_ws!(fst, s)

    return
end

function unnest!(style::AbstractStyle; dedent::Bool)
    (fst::FST, s::State) -> begin
        unnest!(style, fst, s; dedent = dedent)
    end
end

"""
    nest_if_over_margin!(
        style,
        fst::FST,
        s::State,
        idx::Int;
        stop_idx::Union{Int,Nothing} = nothing,
    )::Bool

Converts the node at `idx` to a `NEWLINE` if the current margin plus the additional margin
from `fst[idx:stop_idx-1]` is greater than the allowed margin.

If `stop_idx == nothing` the range is `fst[idx:end]`.

Returns whether nesting occurred.
"""
function nest_if_over_margin!(
    style::AbstractStyle,
    fst::FST,
    s::State,
    idx::Int,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}};
    stop_idx::Union{Int,Nothing} = nothing,
)::Bool
    @assert fst[idx].typ == PLACEHOLDER
    margin = s.line_offset
    if stop_idx === nothing
        margin += sum(length.(fst[idx:end])) + fst.extra_margin
    else
        margin += sum(length.(fst[idx:(stop_idx-1)]))
    end

    if margin > s.opts.margin ||
       (idx < length(fst.nodes::Vector) && is_comment(fst[idx+1])) ||
       (idx > 1 && is_comment(fst[idx-1]))
        fst[idx] = Newline(; length = fst[idx].len)
        s.line_offset = fst.indent
        return true
    end

    nest!(style, fst[idx], s, lineage)
    return false
end

# TOOD: further improve the runtime of this function
function find_all_segment_splits(dp::Matrix{Int}, k::Int, max_margin::Int)
    res = Vector{Int}[]
    n = size(dp, 1)

    if n == k
        return Vector{Int}[fill(1, k)]
    elseif k == 1
        return Vector{Int}[[n]]
    end

    # Maximum recursion depth to prevent infinite loops
    max_recursions = 100

    function _backtrack(t::Vector{Int}, current_sum::Int, recursion_count::Int)
        # Check recursion limit
        if recursion_count > max_recursions
            # Early exit if we've recursed too many times
            return
        end

        if length(t) == k
            if current_sum == n
                push!(res, t)
            end
            return
        elseif current_sum >= n
            return
        end

        for i in 1:(n-k+1)
            if current_sum + i > n
                break
            end
            if dp[current_sum+1, current_sum+i] > max_margin
                break
            end
            _backtrack([t; i], current_sum + i, recursion_count + 1)
        end
    end

    for i in 1:(n-k+1)
        cm = dp[1, i]
        if cm > max_margin
            break
        end
        _backtrack([i], i, 1)
    end

    if length(res) == 0
        return [[n]]
    end

    return res
end

"""
Finds the optimal placeholders to turn into a newlines such that the length of the arguments on each line is as close as possible while following margin constraints.
"""
function find_optimal_nest_placeholders(
    fst::FST,
    start_line_offset::Int,
    max_margin::Int,
)::Vector{Int}
    placeholder_inds = findall(n -> n.typ === PLACEHOLDER, fst.nodes)
    if length(placeholder_inds) <= 1 || length(placeholder_inds) >= 500
        return placeholder_inds
    end

    # For certain expression types, be more conservative about line breaking
    # to avoid breaking readable expressions across multiple lines
    total_length = start_line_offset + length(fst) + fst.extra_margin

    if (fst.typ === RefN && length(placeholder_inds) <= 4)
        # Don't break short array indexing expressions like II[i, j, 1]
        return Int[]
    elseif (fst.typ === MacroCall && length(placeholder_inds) <= 10)
        # Don't break macro calls like @unpack a, b, c = struct or @time ts, us = func()
        # unless they're significantly over the margin
        if total_length <= max_margin + 60
            return Int[]
        end
    elseif (fst.typ === Call && length(placeholder_inds) <= 5)
        # Be more conservative with function calls to avoid awkward breaks
        if total_length <= max_margin + 20
            return Int[]
        end
    elseif (fst.typ === Curly && length(placeholder_inds) <= 4)
        # Don't break short type parameter lists like Type{A, B, C}
        # unless the margin is extremely tight
        if total_length <= max_margin + 10
            return Int[]
        end
    elseif (fst.typ === Vect && length(placeholder_inds) <= 4)
        # Don't break short vector literals like [a, b, c] unless necessary
        if total_length <= max_margin + 10
            return Int[]
        end
    elseif (fst.typ === Binary || fst.typ === Chain || fst.typ === Comparison)
        # Special handling for assignments - don't break LHS
        if fst.typ === Binary &&
           !isnothing(fst.metadata) &&
           (fst.metadata::Metadata).is_assignment
            # For assignments, find the operator position
            # Assignment structure: LHS placeholder op placeholder RHS
            # We want to avoid breaking before the operator
            if length(placeholder_inds) >= 2
                # Skip the first placeholder (which comes after LHS)
                return placeholder_inds[2:end]
            end
        end

        # For mathematical expressions, be conservative about breaking
        # Only break if significantly over margin or has many operations
        if length(placeholder_inds) <= 3 && total_length <= max_margin + 20
            return Int[]
        elseif length(placeholder_inds) <= 6 && total_length <= max_margin
            return Int[]
        end
    elseif (fst.typ === Conditional)
        # For ternary operators, avoid breaking unless necessary
        if length(placeholder_inds) <= 2 && total_length <= max_margin + 10
            return Int[]
        end
    end
    newline_inds = findall(n -> n.typ === NEWLINE, fst.nodes)

    placeholder_groups = Vector{Int}[]
    i = 1
    current_group = Int[]
    for ind in placeholder_inds
        if i > length(newline_inds) || ind < newline_inds[i]
            push!(current_group, ind)
        else
            push!(placeholder_groups, current_group)
            current_group = Int[ind]
            i += 1
        end
    end
    push!(placeholder_groups, current_group)

    optimal_placeholders = Int[]
    for (i, g) in enumerate(placeholder_groups)
        optinds = find_optimal_nest_placeholders(
            fst,
            g,
            start_line_offset,
            max_margin;
            last_group = i == length(placeholder_groups),
        )
        push!(optimal_placeholders, optinds...)
    end

    # @info "optimal_placeholders" optimal_placeholders
    return optimal_placeholders
end

function find_optimal_nest_placeholders(
    fst::FST,
    placeholder_inds::Vector{Int},
    initial_offset::Int,
    max_margin::Int;
    last_group::Bool = false,
)::Vector{Int}
    # Function to calculate the length of a segment
    segment_length =
        (start_idx::Int, end_idx::Int) -> begin
            if placeholder_inds[end] == end_idx && last_group
                sum(length.(fst[start_idx:end])) + fst.extra_margin
            else
                sum(length.(fst[start_idx:(end_idx-1)]))
            end
        end

    n = length(placeholder_inds)
    dp = fill(0, n - 1, n - 1)

    # Initialize the lengths of segments with single placeholders
    for i in 1:(n-1)
        for j in (i+1):n
            len = segment_length(placeholder_inds[i], placeholder_inds[j])
            dp[i, j-1] = len
        end
    end

    # @info "" dp placeholder_inds

    N = size(dp, 1)

    function find_best_segments(s::Int)
        if s == 1
            return [(1, N)]
        elseif s == N
            return [(i, i) for i in 1:N]
        end

        _f = (t::Vector{Int}) -> begin
            local ranges = UnitRange{Int}[]
            local s = 1
            for tt in t
                push!(ranges, s:(s+tt-1))
                s += tt
            end
            ranges
        end

        all_splits = find_all_segment_splits(dp, s, max_margin)

        best_split = UnitRange{Int}[]
        min_diff = 1_000_000 # big number!
        # @info "all_splits" s all_splits
        for split in all_splits
            ranges = _f(split)
            # @info "" split ranges
            lens = [dp[r[1], r[end]] for r in ranges]
            diff = maximum(lens) - minimum(lens)
            if diff < min_diff
                min_diff = diff
                best_split = ranges
            end
        end
        return best_split
    end

    # Calculate best splits for each number of segments s
    segments = Tuple{Int,Int}[]
    for s in 1:N
        segments = find_best_segments(s)
        fits = true
        for (i, s) in enumerate(segments)
            if i == 1
                fits &= initial_offset + dp[first(s), last(s)] <= max_margin
            else
                fits &= initial_offset + dp[first(s), last(s)] <= max_margin
            end
        end
        if fits
            break
        end
    end
    # @info "segments" segments placeholder_inds

    # if it's one segment it means it all fits.
    if length(segments) <= 1
        return Int[]
    end

    # ex: (ph, arg, ph, arg, ph, arg, ph)
    # Convert segments to placeholder indices
    optimal_placeholders = Int[]
    for i in 1:(length(segments)-1)
        s2 = segments[i+1]
        i1 = first(s2)
        push!(optimal_placeholders, placeholder_inds[i1])
    end
    return optimal_placeholders
end
