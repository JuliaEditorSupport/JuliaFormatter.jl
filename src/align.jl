"""
    align_fst!(fst::FST, opts::Options)

Walk `fst` and apply the alignment passes enabled by `opts`.
"""
function align_fst!(fst::FST, opts::Options)
    if is_leaf(fst)
        return
    end
    assignment_inds = Int[]
    pair_arrow_inds = Int[]

    for (i, n) in enumerate(fst.nodes)
        if is_leaf(n)
            continue
        elseif opts.align_struct_field && (n.typ === Struct || n.typ === Mutable)
            align_struct!(n)
        elseif opts.align_conditional && n.typ === Conditional
            align_conditional!(n)
        elseif opts.align_matrix && (
            n.typ === Vcat || n.typ === TypedVcat || n.typ === Ncat || n.typ === TypedNcat
        )
            align_matrix!(n)
        else
            align_fst!(n, opts)
        end

        if opts.align_assignment && (is_assignment(n) || n.typ === Kw)
            # Gather all assignments within the current code block
            # they will be aligned at the end
            push!(assignment_inds, i)
        elseif opts.align_pair_arrow && n.typ === Binary && op_kind(n) === K"=>"
            push!(pair_arrow_inds, i)
        end
    end

    align_binaryopcalls!(fst, assignment_inds)
    align_binaryopcalls!(fst, pair_arrow_inds)
end

"""
    AlignGroup

Group of FST node indices and required metadata to potentially align them.

- `node_inds`. Indices of FST nodes affected by alignment.
- `nodes`. FST nodes affected by alignment.
- `line_offsets`. Display line offset of the character nodes may be aligned
  to in the source file.
- `lens`. Length of the FST node prior to the alignment character. Used
  to calculate extra whitespace padding.
- `whitespaces`. Number of whitespaces between the alignment character and
  the prior FST node. If this is > 1 it signifies additional whitespace was
  manually added by the user since the formatter would only use 0 or 1 whitespaces.
"""
struct AlignGroup
    nodes::Vector{FST}
    node_inds::Vector{Int}
    line_offsets::Vector{Int}
    lens::Vector{Int}
    whitespaces::Vector{Int}
end
AlignGroup() = AlignGroup(FST[], Int[], Int[], Int[], Int[])

function Base.push!(g::AlignGroup, n::FST, ind::Int, line_offset::Int, len::Int, ws::Int)
    push!(g.nodes, n)
    push!(g.node_inds, ind)
    push!(g.line_offsets, line_offset)
    push!(g.lens, len)
    push!(g.whitespaces, ws)
    return
end

function Base.show(io::IO, g::AlignGroup)
    println(io, "AlignGroup:")
    println(io, "  node_inds: ", g.node_inds)
    println(io, "  line_offsets: ", g.line_offsets)
    println(io, "  lens: ", g.lens)
    println(io, "  whitespaces: ", g.whitespaces)
end

function align_to(g::AlignGroup)::Union{Nothing,Int}
    if !(length(g.lens) > 0)
        return nothing
    end
    # determine whether alignment might be warranted
    max_len, max_ind = findmax(g.lens)
    max_inds = findall(==(g.line_offsets[max_ind]), g.line_offsets)
    if !(length(max_inds) > 1)
        return nothing
    end

    # Is there custom whitespace?
    # Formatter would only add 0 or 1 whitespaces.
    # > 2 implies a manual edit in the source file.
    for i in max_inds
        if g.whitespaces[i] > 1
            return max_len
        end
    end

    return nothing
end

function align_binaryopcall!(fst::FST, diff::Int)
    # insert whitespace before and after operator
    find = findfirst(x -> x.typ === WHITESPACE, fst.nodes)
    lind = findlast(x -> x.typ === WHITESPACE, fst.nodes)

    if find === nothing
        insert!(fst, 2, Whitespace(diff))
    else
        fst[find] = Whitespace(diff)
    end

    if lind === nothing
        insert!(fst, 4, Whitespace(1))
    end
end

function node_align_length(n::FST)
    if is_leaf(n)
        return textwidth(n.val)
    end
    margin = 0
    for nn in n.nodes
        margin += node_align_length(nn)
    end
    return margin
end

function node_align_length(nodes::Vector{FST})
    margin = 0
    for nn in nodes
        margin += node_align_length(nn)
    end
    return margin
end

"""
    align_binaryopcalls!(fst::FST, op_inds::Vector{Int})

Aligns binary operator expressions.

Additionally handles the case where a keyword such as `const` is used prior to the binary op
call.
"""
function align_binaryopcalls!(fst::FST, op_inds::Vector{Int})
    if !(length(op_inds) > 1)
        return
    end
    prev_endline = fst[op_inds[1]].endline
    groups = AlignGroup[]
    g = AlignGroup()

    for i in op_inds
        n = fst[i]
        if n.startline - prev_endline > 1
            push!(groups, g)
            g = AlignGroup()
        end

        binop, nlen, ws = if n.typ === Binary || n.typ === Kw
            nlen = node_align_length(n[1])
            n, nlen, n[3].line_offset - n.line_offset - nlen
        else
            binop::Union{FST,Nothing} = nothing
            sn = n
            nlen = 0
            ws = 0

            # the binary op may not be at the top level
            # for instance, @call1 @call2 @call3 x = 10
            while sn.nodes !== nothing
                binop_ind = findfirst(nn -> nn.typ === Binary, sn.nodes)
                nlen += node_align_length(sn[1:(end-1)])
                if binop_ind === nothing
                    sn = (sn.nodes::Vector{FST})[end]
                else
                    binop = (sn.nodes::Vector{FST})[binop_ind]
                    nlen += node_align_length(binop[1])
                    ws = binop[3].line_offset - n.line_offset - nlen
                    break
                end
            end
            binop, nlen, ws
        end

        if binop === nothing
            @warn "Binary operator not found in node" n.typ
            continue
        end

        push!(g.nodes, binop)
        push!(g.node_inds, i)
        push!(g.line_offsets, binop[3].line_offset)
        push!(g.lens, nlen)
        push!(g.whitespaces, ws)

        prev_endline = n.endline
    end
    push!(groups, g)

    for g in groups
        align_len = align_to(g)
        if isnothing(align_len)
            continue
        end

        for (i, n) in enumerate(g.nodes)
            diff = align_len - g.lens[i] + 1
            align_binaryopcall!(n, diff)
            n.nest_behavior = NeverNest
        end
    end

    return
end

"""
    align_struct!(fst::FST)

Aligns struct fields.
"""
function align_struct!(fst::FST)
    ind = findfirst(n -> n.typ === Block, fst.nodes)
    if isnothing(ind) || length(fst[ind]) == 0
        return
    end

    block_fst = fst[ind]
    prev_endline = block_fst[1].endline
    groups = AlignGroup[]
    g = AlignGroup()

    for (i, n) in enumerate(block_fst.nodes)
        if n.typ === Binary
            if n.startline - prev_endline > 1
                push!(groups, g)
                g = AlignGroup()
            end

            nlen = node_align_length(n[1])
            ind = findfirst(x -> x.typ === OPERATOR, n.nodes)
            # issue 757
            # "foo
            # """
            # a::B
            #
            # This is parsed as a concatenated string of "foo" and ""
            if ind === nothing
                continue
            end

            ws = n[ind].line_offset - n.line_offset - nlen

            push!(g.nodes, n)
            push!(g.node_inds, i)
            push!(g.line_offsets, n[ind].line_offset)
            push!(g.lens, nlen)
            push!(g.whitespaces, ws)

            prev_endline = n.endline
        elseif n.typ === Const && n[end].typ === Binary
            if n.startline - prev_endline > 1
                push!(groups, g)
                g = AlignGroup()
            end

            nlen = node_align_length(n[1]) + node_align_length(n[2])
            binop = n[end]
            nlen += node_align_length(binop[1])
            ind = findfirst(x -> x.typ === OPERATOR, binop.nodes)
            if ind === nothing
                continue
            end
            ws = binop[ind].line_offset - n.line_offset - nlen

            push!(g.nodes, binop)
            push!(g.node_inds, i)
            push!(g.line_offsets, binop[ind].line_offset)
            push!(g.lens, nlen)
            push!(g.whitespaces, ws)

            prev_endline = n.endline
        end
    end
    push!(groups, g)

    for g in groups
        align_len = align_to(g)
        if align_len === nothing
            continue
        end
        for (i, n) in enumerate(g.nodes)
            diff = align_len - g.lens[i] + 1
            align_binaryopcall!(n, diff)
            n.nest_behavior = NeverNest
        end
    end
end

"""
    align_conditional!(fst::FST)

Aligns a conditional expression.
"""
function align_conditional!(fst::FST)
    nodes = flatten_conditionalopcall(fst)

    cond_group = AlignGroup()
    cond_prev_endline = 0

    colon_group = AlignGroup()
    colon_prev_endline = 0

    for (i, n) in enumerate(nodes)
        if n.typ === OPERATOR && n.val == "?"
            if cond_prev_endline != n.endline
                nlen = node_align_length(nodes[i-2])
                ws = n.line_offset - nodes[i-2].line_offset - nlen

                push!(cond_group.nodes, n)
                push!(cond_group.node_inds, i)
                push!(cond_group.line_offsets, n.line_offset)
                push!(cond_group.lens, nlen)
                push!(cond_group.whitespaces, ws)
            end
            cond_prev_endline = n.endline
        elseif n.typ === OPERATOR && n.val == ":"
            if colon_prev_endline != n.endline
                nlen = node_align_length(nodes[i-2])
                ws = n.line_offset - nodes[i-2].line_offset - nlen

                push!(colon_group.nodes, n)
                push!(colon_group.node_inds, i)
                push!(colon_group.line_offsets, n.line_offset)
                push!(colon_group.lens, nlen)
                push!(colon_group.whitespaces, ws)
            end
            colon_prev_endline = n.endline
        end
    end
    if !(length(cond_group.lens) > 1)
        return
    end

    cond_len = align_to(cond_group)
    colon_len = align_to(colon_group)

    if cond_len === nothing && colon_len === nothing
        return
    end

    if cond_len !== nothing
        for (i, ind) in enumerate(cond_group.node_inds)
            diff = cond_len - cond_group.lens[i] + 1
            nodes[ind-1] = Whitespace(diff)
        end
    end

    for (i, ind) in enumerate(colon_group.node_inds)
        # the placeholder would be i+1 if not for a possible inline comment
        nind = findnext(n -> n.typ === PLACEHOLDER, nodes, ind + 1)::Int
        if nodes[nind+1].startline != nodes[nind].startline
            nodes[nind] = Newline(; nest_behavior = AlwaysNest)
        end

        if colon_len !== nothing
            diff = colon_len - colon_group.lens[i] + 1
            nodes[ind-1] = Whitespace(diff)
        end
    end

    fst.nodes = nodes
    fst.nest_behavior = NeverNest
    fst.indent = fst.line_offset - 1

    return
end

"""
    align_matrix!(fst::FST)

Adjust whitespace between matrix elements so it matches the original source layout.
"""
function align_matrix!(fst::FST)
    rows = filter(n -> n.typ === Row, fst.nodes::Vector{FST})
    if length(rows) == 0
        return
    end

    min_offset = minimum(r -> r[1].line_offset, rows)

    line = 0
    # add whitespace prior to initial element if elements are aligned to the right and
    # it's the first row on that line.
    for r in rows
        row_offset = r[1].line_offset
        if row_offset > min_offset && line != r.startline
            diff = row_offset - min_offset
            if diff > 0
                insert!(r.nodes::Vector{FST}, 1, Whitespace(diff))
            end
        end
        line = r.startline
    end

    for r in rows
        for (i, n) in enumerate(r.nodes)
            # skip whitespace nodes appearing before initial element
            if i > 1 && n.typ === WHITESPACE
                n1 = r[i-1]
                n2 = r[i+1]

                diff = n2.line_offset - n1.line_offset - node_align_length(n1)

                # fix #694 and #713
                if diff > 0
                    r[i] = Whitespace(diff)
                end
            end
        end
    end

    return
end
