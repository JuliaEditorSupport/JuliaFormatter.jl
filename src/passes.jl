flattenable(k) = kind(k) in KSet"&& || |>"
flattenable(::Nothing) = false

"""
Flattens a binary operation call tree if the operation repeats 2 or more times.
"`a && b && c`" will be transformed while "`a && b`" will not.
"""
function flatten_binaryopcall(fst::FST; top = true)
    nodes = FST[]
    kind = op_kind(fst)
    always_nest = must_nest(fst)

    lhs = fst[1]
    rhs = fst[end]
    lhs_kind = op_kind(lhs)
    rhs_kind = op_kind(rhs)
    lhs_same_op = lhs_kind === kind
    rhs_same_op = rhs_kind === kind
    idx = findlast(n -> n.typ === PLACEHOLDER, fst.nodes::Vector{FST})

    if (top && !lhs_same_op && !rhs_same_op) || idx === nothing
        return nodes, always_nest
    end

    if lhs_same_op
        lhs_nodes, lhs_always_nest = flatten_binaryopcall(lhs; top = false)
        append!(nodes, lhs_nodes)
        always_nest |= lhs_always_nest
    else
        flatten_fst!(lhs)
        push!(nodes, lhs)
    end
    # everything except the indentation placeholder
    append!(nodes, fst[2:(idx-1)])

    if rhs_same_op
        rhs_nodes, rhs_always_nest = flatten_binaryopcall(rhs; top = false)
        append!(nodes, rhs_nodes)
        always_nest |= rhs_always_nest
    else
        flatten_fst!(rhs)
        push!(nodes, rhs)
    end

    return nodes, always_nest
end

function flatten_conditionalopcall(fst::FST)
    nodes = FST[]
    for n in fst.nodes::Vector{FST}
        if n.typ === Conditional
            append!(nodes, flatten_conditionalopcall(n))
        else
            push!(nodes, n)
        end
    end
    return nodes
end

function flatten_fst!(fst::FST)
    if is_leaf(fst)
        return
    end
    for n in fst.nodes::Vector{FST}
        if is_leaf(n)
            continue
        elseif n.typ === Binary && flattenable(op_kind(n))
            # possibly convert Binary to Chain
            nnodes, always_nest = flatten_binaryopcall(n)
            if length(nnodes) > 0
                n.typ = Chain
                n.nodes = nnodes
                # if any of the child nodes needed to be nested, then this node also needs
                # to be nested to preserve the original nesting structure
                if always_nest
                    n.nest_behavior = AlwaysNest
                end
            else
                flatten_fst!(n)
            end
        else
            flatten_fst!(n)
        end
    end
end

function import_to_usings(fst::FST, s::State)
    nodes = fst.nodes::Vector{FST}
    if !(findfirst(n -> is_colon(n) || n.typ === As, nodes) === nothing)
        return FST[]
    end
    if !(findfirst(n -> n.typ === PUNCTUATION && n.val == ".", fst[3].nodes) === nothing)
        return FST[]
    end

    # handle #723 "import ..f" should not become "using ..f: f"
    if length(nodes) == 3 && nodes[3].typ === ImportPath && length(nodes[3].nodes) > 1
        return FST[]
    end

    usings = FST[]
    idxs = findall(n -> !is_leaf(n), nodes)

    for i in idxs
        n = fst[i]
        sl = n.startline
        el = n.endline
        use = FST(Using, fst.indent)
        use.startline = n.startline
        use.endline = n.endline

        add_node!(use, FST(KEYWORD, -1, sl, el, "using"), s)
        add_node!(use, Whitespace(1), s)

        add_node!(use, n, s; join_lines = true)
        colon = FST(OPERATOR, -1, sl, el, ":")
        colon.metadata = Metadata(K"::")
        add_node!(use, colon, s; join_lines = true)
        add_node!(use, Whitespace(1), s)
        add_node!(use, n[end], s; join_lines = true)

        push!(usings, use)
    end

    return usings
end

"""
    annotate_typefields_with_any!(fst::FST, s::State)

Annotates fields in a type definitions with `::Any` if
no type annotation is provided.
"""
function annotate_typefields_with_any!(fst::FST, s::State)
    if is_leaf(fst)
        return
    end
    for (i, n) in enumerate(fst.nodes::Vector{FST})
        if n.typ === IDENTIFIER
            nn = FST(Binary, n.indent)
            nn.startline = n.startline
            nn.endline = n.endline
            add_node!(nn, n, s)
            line_offset = n.line_offset + length(n)
            op = FST(OPERATOR, line_offset, n.startline, n.endline, "::")
            op.metadata = Metadata(K"::")
            add_node!(nn, op, s; join_lines = true)
            line_offset += 2
            add_node!(
                nn,
                FST(IDENTIFIER, line_offset, n.startline, n.endline, "Any"),
                s;
                join_lines = true,
            )
            fst[i] = nn
        else
            continue
        end
    end
end

"""
    short_to_long_function_def!(fst::FST, s::State)

Transforms a *short* function definition

```julia
f(arg1, arg2) = body
```

to a *long* function definition

```julia
function f(arg2, arg2)
    body
end
```
"""
function short_to_long_function_def!(
    fst::FST,
    s::State,
    lineage::Vector{Tuple{FNode,Union{Nothing,Metadata}}},
)
    if (fst[1].typ !== Call && fst[1].typ !== Where)
        return false
    end
    
    # Do not perform transformation in exprs
    if any(i -> i[1] in (Quotenode, MacroBlock, MacroCall), lineage)
        return false
    end

    for i in (length(lineage)-1):-1:1
        parent = lineage[i]
        # maybe need to know metadata too?
        if parent[1] in (If, Do, Try, Begin, For, While, Quote, Block)
            continue
        elseif parent[1] in (FunctionN, Macro, MacroBlock, MacroCall) ||
               (!isnothing(parent[2]) && parent[2].is_short_form_function)
            return false
        else
            break
        end
    end

    # 3 cases
    #
    # case 1
    #   func(a) = body
    #
    # case 2
    #   func(a::T) where T = body
    #
    # case 3
    #   func(a::T)::R where T = body
    funcdef = FST(FunctionN, fst.indent)
    # function
    kw = FST(KEYWORD, -1, fst[1].startline, fst[1].endline, "function")
    add_node!(funcdef, kw, s)
    add_node!(funcdef, Whitespace(1), s)

    # func(a)
    # OR
    # func(a) where T
    add_node!(funcdef, fst[1], s; join_lines = true)

    # body

    s.opts.always_use_return && prepend_return_fst!(fst[end], s)
    if fst[end].typ === Block
        add_node!(funcdef, fst[end], s; max_padding = s.opts.indent)
    elseif fst[end].typ === Begin
        # case where body is wrapped in a `begin` block
        # which becomes superfluous when converted to a
        # long function definition
        #
        # abc() = begin
        #    body
        # end
        #
        #
        # find Block node in fs[tend]
        idx = findfirst(n -> n.typ === Block, fst[end].nodes)
        if idx === nothing
            return false
        end
        bnode = fst[end][idx]
        add_indent!(bnode, s, -s.opts.indent)
        add_node!(funcdef, bnode, s; max_padding = s.opts.indent)
    else
        # ```
        # function
        #     body
        # end
        # ```
        #
        # `body` is parsed wrapped block node. Wrapping it in
        # a `Block` node ensures the indent is correct.
        bl = FST(Block, fst[end].indent)
        add_node!(bl, fst[end], s)
        add_node!(funcdef, bl, s; max_padding = s.opts.indent)
    end
    add_indent!(funcdef[end], s, s.opts.indent)

    if s.opts.always_use_return
        prepend_return_fst!(funcdef[end], s)
    end

    # end
    kw = FST(KEYWORD, -1, fst[end].startline, fst[end].endline, "end")
    add_node!(funcdef, kw, s)

    fst.typ = funcdef.typ
    fst.nodes = funcdef.nodes
    fst.len = funcdef.len

    return true
end

"""
    long_to_short_function_def!(fst::FST, s::State)

Transforms a *long* function definition

```julia
function f(arg2, arg2)
    body
end
```

to a *short* function definition

```julia
f(arg1, arg2) = body
```
"""
function long_to_short_function_def!(fst::FST, s::State)
    nodes = fst.nodes::Vector{FST}
    if any(is_comment, nodes)
        return false
    end

    I = findall(n -> n.typ === Block, nodes)
    if !(length(I) == 1)
        return false
    end

    block = nodes[first(I)]
    if !(length(block.nodes::Vector{FST}) == 1)
        return false
    end

    I = findfirst(n -> n.typ === Call || n.typ === Where, nodes)
    if I === nothing
        return false
    end
    lhs = nodes[I]

    rhs = first(block.nodes)

    if rhs.typ === Return
        rhs = (rhs.nodes::Vector{FST})[end]
    end

    # length(Whitespace(1) * "=" * Whitespace(1)) = 3
    line_margin = s.line_offset + length(lhs) + 3 + length(rhs) + fst.extra_margin
    if line_margin > s.opts.margin
        return false
    end

    if rhs.indent > 0
        add_indent!(rhs, s, -s.opts.indent)
    end

    funcdef = FST(Binary, fst.indent)
    funcdef.metadata = Metadata(K"=", false, true, false, false, false)
    kw = (join_lines = true, override_join_lines_based_on_source = true)

    add_node!(funcdef, lhs, s; kw...)
    add_node!(funcdef, Whitespace(1), s; kw...)
    op = FST(OPERATOR, 0, 0, 0, "=")
    op.metadata = Metadata(K"=")
    add_node!(funcdef, op, s; kw...)
    add_node!(funcdef, Placeholder(1), s; kw...)
    add_node!(funcdef, Placeholder(0), s; kw...)
    add_node!(funcdef, rhs, s; kw...)

    if rhs.typ in (If, Do, Try, For, While, Let)
        funcdef.nest_behavior = AlwaysNest
    end

    fst.typ = funcdef.typ
    fst.nodes = funcdef.nodes
    fst.len = funcdef.len
    fst.metadata = funcdef.metadata
    fst.nest_behavior = funcdef.nest_behavior
    return true
end

# TODO: revisit this
"""
    binaryop_to_whereop(fst::FST, s::State)

Handles the case of a function def defined as:

```julia
foo(a::A)::R where A = body
```

In this case instead of it being parsed as (1):

```
Binary
 - Where
 - OP
 - RHS
```

It's parsed as (2):

```
Binary
 - Binary
  - LHS
  - OP
  - Where
   - R
   - ...
 - OP
 - RHS
```

(1) is preferrable since it's the same parsed result as:

```julia
foo(a::A) where A = body
```

This transformation converts (2) to (1).

ref <https://github.com/julia-vscode/CSTParser.jl/issues/93>
"""
function binaryop_to_whereop!(fst::FST, s::State)
    # transform fst[1] to a Where
    oldbinop = fst[1]
    oldwhereop = fst[1][end]

    # get everything up to the where
    binop = FST(Binary, fst[1].indent)
    binop.metadata = oldbinop.metadata
    for n in oldbinop.nodes
        if n.typ === Where
            break
        end
        add_node!(binop, n, s; join_lines = true)
    end
    # # foo(a::A)::R gets the "R"
    add_node!(binop, oldwhereop[1], s; join_lines = true)

    whereop = FST(Where, fst[1].indent)
    add_node!(whereop, binop, s)

    # "foo(a::A)::R where A"
    for n in oldwhereop[2:end]
        add_node!(whereop, n, s; join_lines = true)
    end

    fst[1] = whereop
end

"""
    prepend_return_fst!(fst::FST, s::State)

Prepends `return` to the last expression of a block if applicable.

*Note*: This function is only called when a short-form function definition is converted to a
long-form one, AND `always_use_return` is true. For ordinary, pre-existing long-form
function definitions, the implementation of `always_use_return` is in `p_block` in
`default/pretty.jl`. This is done to avoid post-FST passes which tend to cause idempotence
issues.

```julia
function foo()
    a = 2 * 3
    a / 3
end
```

to

```julia
function foo()
    a = 2 * 3
    return a / 3
end
```
"""
function prepend_return_fst!(fst::FST, s::State)
    if fst.typ !== Block || length(fst.nodes::Vector{FST}) == 0
        return
    end

    # Skip trailing inline block comments (`#= … =#`) and whitespace to find the
    # actual last expression.  Inline line comments are already placed outside the
    # Block by `add_node!`, but block comments live inside it as siblings.
    nodes = fst.nodes::Vector{FST}
    last_idx = findlast(
        n -> n.typ !== HASHEQCOMMENT && n.typ !== WHITESPACE && n.typ !== PLACEHOLDER,
        nodes,
    )
    if last_idx === nothing
        return
    end

    ln = fst[last_idx]
    if is_block(ln) || ln.typ in (Return, MacroCall, MacroBlock, MacroStr)
        return
    end
    if last_idx > 2 && (fst[last_idx-2].typ === MacroStr || is_macrodoc(fst[last_idx-2]))
        return
    end
    # check to see if the last node already has a return
    found_return = false
    f = (fst::FST, ::State) -> begin
        if fst.typ === Return
            found_return = true
        end
        return
    end
    lo = s.line_offset
    walk(f, ln, s)
    s.line_offset = lo
    if found_return
        return
    end

    ret = FST(Return, fst.indent)
    kw = FST(KEYWORD, -1, ln.startline, ln.startline, "return")
    add_node!(ret, kw, s; join_lines = true)
    add_node!(ret, Whitespace(1), s)
    add_node!(ret, ln, s; join_lines = true)
    fst[last_idx] = ret
    return
end

"""
    move_at_sign_to_the_end(fst::FST, s::State)

NOTE: Assumes `fst` is the caller name of a macrocall such as
`@macro` or `Module.@macro`.

Moves `@` to the last identifier.

Example:

```julia
@Module.macro
```

to

```julia
Module.@macro
```
"""
function move_at_sign_to_the_end(fst::FST, s::State)
    val = ""
    has_at = false
    f = (n::FST, _) -> begin
        if n.typ === MACRONAME && n.line_offset == -33
            val *= gettreeval(n)
            return false
        elseif is_leaf(n)
            v = gettreeval(n)
            has_at = has_at || contains(v, "@")
            v = replace(v, "@" => "")
            val *= v
        end
    end
    walk(f, fst, s)

    if !has_at
        return fst
    end

    # Find the last occurrence of . and insert @ after it
    last_dot_index = findlast('.', val)
    if last_dot_index !== nothing
        val = val[1:last_dot_index] * "@" * val[(last_dot_index+1):end]
    else
        # If there's no dot, add @ to the beginning
        val = "@" * val
    end

    return FST(MACRONAME, -33, fst.startline, fst.startline, val)
end

function conditional_to_if_block!(fst::FST, s::State, top::Bool)
    t = FST(If, fst.indent)
    kw = FST(KEYWORD, -1, fst.startline, fst.startline, top ? "if" : "elseif")
    add_node!(t, kw, s; max_padding = 0)
    add_node!(t, Whitespace(1), s; join_lines = true)
    add_node!(t, fst[1], s; join_lines = true)

    nodes = fst.nodes::Vector{FST}
    idx1 = findfirst(n -> n.typ === OPERATOR && n.val == "?", nodes)::Int
    idx2 = findfirst(n -> n.typ === OPERATOR && n.val == ":", nodes)::Int

    block1 = FST(Block, fst.indent + s.opts.indent)
    for n in nodes[(idx1+1):(idx2-1)]
        if n.typ === PLACEHOLDER ||
           n.typ === WHITESPACE ||
           n.typ === NEWLINE ||
           is_comment(n)
            continue
        end
        add_node!(block1, n, s)
    end
    add_node!(t, block1, s; max_padding = s.opts.indent)

    block2 = FST(Block, fst.indent)
    padding = 0
    if fst[end].typ === Conditional
        conditional_to_if_block!(fst[end], s, false)
    else
        block2.indent += s.opts.indent
        padding = s.opts.indent
        kw = FST(KEYWORD, 0, 0, -1, "else")
        add_node!(t, kw, s; max_padding = 0)
    end
    add_node!(block2, fst[end], s)
    add_node!(t, block2, s; max_padding = 0)

    if top
        kw = FST(KEYWORD, 0, 0, -1, "end")
        add_node!(t, kw, s; max_padding = 0)
    end

    fst.typ = t.typ
    fst.nodes = t.nodes
    fst.len = t.len

    return nothing
end

"""
    separate_kwargs_with_semicolon!(fst::FST)

Ensures keyword arguments are separated by a "`;`".

### Examples

Replace "`,`" with "`;`".

```julia
a = f(x, y = 3)

->

a = f(x; y = 3)
```

Move ";" to the prior to the first positional argument.

```julia
a = f(x = 1; y = 2)

->

a = f(; x = 1, y = 2)
```
"""
function separate_kwargs_with_semicolon!(fst::FST)
    nodes = fst.nodes::Vector{FST}
    first_kw_idx = findfirst(n -> n.typ === Kw, nodes)
    # who knows if this list is exhaustive... would be much easier at the CST level
    last_nonkw_idx = findlast(
        n -> !(
            n.typ in (
                Kw,
                PUNCTUATION,
                SEMICOLON,
                WHITESPACE,
                PLACEHOLDER,
                TRAILINGCOMMA,
                NEWLINE,
                INLINECOMMENT,
                HASHEQCOMMENT,
            )
        ),
        nodes,
    )
    # No keyword arguments
    isnothing(first_kw_idx) && return

    semicolon_index = findfirst(n -> n.typ === SEMICOLON, nodes)
    # first "," prior to a kwarg
    last_comma_idx = findprev(is_comma, nodes, first_kw_idx - 1)
    last_ph_idx = findprev(n -> n.typ === PLACEHOLDER, nodes, first_kw_idx - 1)

    if !isnothing(semicolon_index) && semicolon_index > first_kw_idx
        # move ; prior to first kwarg
        fst[semicolon_index].val = ","
        fst[semicolon_index].typ = PUNCTUATION
        if isnothing(last_comma_idx)
            if !isnothing(last_ph_idx)
                fst[last_ph_idx] = Placeholder(1)
                insert!(fst, last_ph_idx, Semicolon())
            else
                insert!(fst, first_kw_idx, Placeholder(1))
                insert!(fst, first_kw_idx, Semicolon())
            end
        else
            fst[last_comma_idx].val = ";"
            fst[last_comma_idx].typ = SEMICOLON
        end
    elseif isnothing(semicolon_index) && isnothing(last_comma_idx)
        if !isnothing(last_ph_idx)
            fst[last_ph_idx] = Placeholder(1)
            insert!(fst, last_ph_idx, Semicolon())
        else
            insert!(fst, first_kw_idx, Placeholder(1))
            insert!(fst, first_kw_idx, Semicolon())
        end
    elseif isnothing(semicolon_index)
        # Don't convert f(x, y=z, q) to f(x; y=z, q); i.e., if there is any positional
        # argument after the first keyword argument, don't convert it
        if last_nonkw_idx > first_kw_idx
            return
        end
        fst[last_comma_idx].val = ";"
        fst[last_comma_idx].typ = SEMICOLON
    end

    return
end

"""
    remove_superfluous_whitespace!(fst::FST)

Soft deletes `WHITESPACE` or `PLACEHOLDER` that's directly followed by a `NEWLINE` or `INLINECOMMENT` node.
"""
function remove_superfluous_whitespace!(fst::FST)
    if is_leaf(fst)
        return
    end
    nodes = fst.nodes::Vector{FST}
    for (i, n) in enumerate(nodes)
        if (n.typ === WHITESPACE || n.typ === PLACEHOLDER || n.typ === NEWLINE) &&
           can_remove(n) &&
           i < length(nodes) &&
           (fst[i+1].typ === NEWLINE || fst[i+1].typ === INLINECOMMENT)
            fst[i] = Whitespace(0)
        else
            remove_superfluous_whitespace!(n)
        end
    end
    return
end

function _short_circuit_to_if!(fst::FST, s::State, value_is_needed::Bool)
    # change it into an if
    t = FST(If, fst.indent)
    kw = FST(KEYWORD, -1, fst.startline, fst.startline, "if")
    add_node!(t, kw, s; max_padding = 0)
    add_node!(t, Whitespace(1), s; join_lines = true)

    nodes = fst.nodes::Vector{FST}
    idx = findlast(n -> n.typ === OPERATOR && (n.val == "||" || n.val == "&&"), nodes)::Int
    is_or = nodes[idx].val == "||"

    wrap_with_parens = !(nodes[1].typ === Brackets)

    if is_or
        call = FST(Unary, fst.indent)
        add_node!(call, FST(OPERATOR, -1, fst.startline, fst.startline, "!"), s)

        if wrap_with_parens
            brackets = FST(Brackets, fst.indent)
            add_node!(
                brackets,
                FST(PUNCTUATION, -1, fst.startline, fst.startline, "("),
                s;
                join_lines = true,
            )
            add_node!(brackets, Placeholder(0), s)
            # inner
            lhs = FST(Chain, fst.indent)
            for n in nodes[1:(idx-1)]
                add_node!(lhs, n, s; join_lines = true)
            end
            # remove extra ws
            if lhs[end].typ === WHITESPACE
                lhs[end] = Whitespace(0)
            end

            add_node!(brackets, lhs, s; join_lines = true)
            add_node!(brackets, Placeholder(0), s)
            add_node!(
                brackets,
                FST(PUNCTUATION, -1, nodes[idx-2].startline, nodes[idx-2].startline, ")"),
                s;
                join_lines = true,
            )
            add_node!(call, brackets, s; join_lines = true)
        else
            add_node!(call, fst[1], s; join_lines = true)
        end

        add_node!(t, call, s; join_lines = true)
    else
        # from idx-1 go backwards until we find a node that's not a
        lhs = FST(Chain, fst.indent)
        for n in nodes[1:(idx-1)]
            add_node!(lhs, n, s; join_lines = true)
        end
        # remove extra ws
        if lhs[end].typ === WHITESPACE
            lhs[end] = Whitespace(0)
        end
        add_node!(t, lhs, s; join_lines = true)
    end

    block1 = FST(Block, fst.indent + s.opts.indent)
    for n in nodes[(idx+1):end]
        if n.typ === PLACEHOLDER ||
           n.typ === WHITESPACE ||
           n.typ === NEWLINE ||
           is_comment(n)
            continue
        end
        add_node!(block1, n, s)
    end
    add_node!(t, block1, s; max_padding = s.opts.indent)

    if value_is_needed
        # Add the 'else' branch
        else_kw = FST(KEYWORD, 0, 0, -1, "else")
        add_node!(t, else_kw, s; max_padding = 0)
        # add second block is this is not a return
        block2 = FST(Block, fst.indent + s.opts.indent)

        # Determine the default return value based on the operator
        default_val =
            is_or ? FST(KEYWORD, -1, 0, -1, "true") : FST(KEYWORD, -1, 0, -1, "false")
        add_node!(block2, default_val, s; join_lines = true)
        add_node!(t, block2, s; max_padding = s.opts.indent)
    end

    # Close the if statement
    end_kw = FST(KEYWORD, 0, 0, -1, "end")
    add_node!(t, end_kw, s; max_padding = 0)

    fst.typ = t.typ
    fst.nodes = t.nodes
    fst.len = t.len

    return nothing
end

function short_circuit_to_if_pass!(fst::FST, s::State)
    if is_leaf(fst)
        return
    end
    for (i, n) in enumerate(fst.nodes::Vector{FST})
        if is_leaf(n)
            continue
        elseif (n.typ === Binary || n.typ === Chain) &&
               !isnothing(n.metadata) &&
               (n.metadata::Metadata).is_standalone_shortcircuit &&
               fst.typ in (Block, TopLevel, Return)
            # Only expand short-circuit expressions that appear as statements in a block
            # (e.g. function body, loop body) or at the top level. Don't expand inside
            # calls, tuples, etc. where the value is being used -- `a && b` and
            # `if a; b; end` have different return values when `a` is falsy.
            last_expr_idx = findlast(
                n ->
                    n.typ !== HASHEQCOMMENT &&
                    n.typ !== WHITESPACE &&
                    n.typ !== PLACEHOLDER,
                fst.nodes::Vector{FST},
            )
            value_is_needed =
                i == last_expr_idx && (fst.typ === Block || fst.typ === Return)
            if !value_is_needed
                _short_circuit_to_if!(n, s, false)
            end
        else
            short_circuit_to_if_pass!(n, s)
        end
    end
end
