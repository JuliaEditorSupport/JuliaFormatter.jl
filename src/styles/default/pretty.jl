options(::DefaultStyle) = Options()

@kwdef struct PrettyContext
    # If true, ensure that no whitespace is added around binary operators.
    # In general, this can be inferred from the source. However, this is
    # overridden specifically for macro keyword arguments in SciML style.
    # See https://github.com/SciML/SciMLStyle/tree/3f6fa61c6cc6fcf1c23177fab187d0c85197acfc#macros
    nospace::Bool = false

    nonest::Bool = false
    standalone_binary_circuit::Bool = true
    from_typedef::Bool = false
    from_let::Bool = false
    from_ref::Bool = false
    from_colon::Bool = false
    from_for::Bool = false

    # These two flags are used to compensate for weird structure of ncat and nrow
    # nodes in JuliaSyntax. See p_ncat for more info
    #
    # indicates whether newlines inside are semantically meaningful
    from_nrow::Bool = false
    # indicates whether newlines at the end are semantically meaningful
    is_last_ncat_or_nrow_arg::Bool=false

    # indicates whether the caller in a function definition has been parenthesised
    # see p_call for explanation
    is_parenthesised_caller::Bool=false

    ignore_single_line::Bool = false
    from_quote::Bool = false
    join_body::Bool = false
    from_module::Bool = false
    from_docstring::Bool = false

    # Indicates a context in which we are allowed to rewrite f(x, y=z) to f(x; y=z).
    # This is disabled in macros as well as in function definitions.
    can_separate_kwargs::Bool = true
end

function newctx(s::PrettyContext; kwargs...)
    fields = fieldnames(PrettyContext)
    values = map(field -> get(kwargs, field, getfield(s, field)), fields)
    PrettyContext(values...)
end

"""
    source_op_kind_from_offset(s, cst, offset)::Union{Nothing,JuliaSyntax.Kind}

Return the operator kind of `cst`, using the source text at `offset` if necessary to help
determine this. If `cst` is not an operator, returns `nothing`.

Note that this function may still return a K"Identifier"! This is because Julia allows some
weird postfix operators. See the comments in the function for more info.

The check against the source is needed because JuliaSyntax v1 can encode source operators as
Identifier leaves in call forms. For example:

```julia
julia> JuliaSyntax.parseall(JuliaSyntax.GreenNode, "+y")
     1:2      │[toplevel]
     1:2      │  [call]
     1:1      │    Identifier           ✔
     2:2      │    Identifier           ✔
```

See https://github.com/JuliaLang/JuliaSyntax.jl/issues/548 for more information.
"""
function source_op_kind_from_offset(s::State, cst::JuliaSyntax.GreenNode, offset::Integer)
    return if JuliaSyntax.is_operator(cst) && !haschildren(cst)
        # Already have the right kind stored in the GreenNode
        kind(cst)
    elseif kind(cst) === K"Identifier" && !haschildren(cst)
        # The operator was reduced to an Identifier (this happens in JuliaSyntax v1).
        # Attempt to recover the original kind from the source.
        span(cst) == 0 && return nothing
        source_text = getsrcval(s.doc, offset:(offset+span(cst)-1))
        try
            # Parse the source text and check whether it's a valid operator.
            k = JuliaSyntax.Kind(source_text)
            return if JuliaSyntax.is_operator(k)
                # This is the happy path. It's hit for things like e.g. "+x".
                k
            else
                # There are a lot of Identifiers which can be parsed as kinds, but aren't
                # operators. For example, the `string` in `string(x)` will be converted to
                # K"string" here, which is totally not what we want. Hence we return
                # nothing.
                nothing
            end
        catch
            # There are some operators for which JuliaSyntax does not actually have a
            # dedicated kind. For example, `a'ᵀ` is a postfix operator `'ᵀ`, and
            # JuliaSyntax.is_postfix_op_call will correctly return true. Specifically, the '
            # postfix operator can be followed by any Unicode modifier:
            # https://github.com/JuliaLang/julia/pull/37247
            #
            # However, the operator is stored as Identifier and calling Kind("'ᵀ") throws an
            # error. We catch such instances here. Thankfully, Base gives us a function
            # (albeit unexported) to detect these. If this function returns K"Identifier",
            # then we know that it's one of these odd postfix operators.
            return if kind(cst) === K"Identifier" && Base.ispostfixoperator(source_text)
                K"Identifier"
            else
                nothing
            end
        end
    else
        # Can't be an operator at all
        nothing
    end
end

"""
    first_nonws_leaf_and_offset(
        node::JuliaSyntax.GreenNode,
    )::Union{Nothing,Tuple{JuliaSyntax.GreenNode,Int}

Return the first non-whitespace leaf node in `node` plus its offset from the beginning of
`node`, or `nothing` if there are no non-whitespace leaves.
"""
function first_nonws_leaf_and_offset(
    node::JuliaSyntax.GreenNode,
    # Callers should not set _acc, this is only used in this function to recurse
    _acc::Integer = 0,
)::Union{Nothing,Tuple{JuliaSyntax.GreenNode,Int}}
    if JuliaSyntax.is_leaf(node)
        return JuliaSyntax.is_whitespace(node) ? nothing : (node, _acc)
    end
    # Recursively search children
    for c in children(node)
        result = first_nonws_leaf_and_offset(c, _acc)
        if result !== nothing
            return result
        end
        _acc += span(c)
    end
    return nothing
end

"""
   source_begins_with_op_needing_parens(s, cst, offset) 

Check whether the first token of `cst` is an operator. Used in `p_kw`: if the value on the
rhs of `kwarg=value` begins with an operator, then we parenthesise `value` to avoid
ambiguity.

Note that the behaviour of this differs from `unary_info(cst)`: for example,
`unary_info(cst)` does not pick up  expressions such as `>=(1)`, which is interpreted as a
function call, not an application of a unary operator. However, these are exactly the sort
of things that we want to parenthesise in `p_kw` -- hence this function.
"""
function source_begins_with_op_needing_parens(
    s::State,
    cst::JuliaSyntax.GreenNode,
    offset::Integer,
)
    # Get the first leaf of `cst` that isn't whitespace.
    result = first_nonws_leaf_and_offset(cst)
    result === nothing && return false
    # Check if it's an operator and specifically one that we care about putting
    # parentheses around.
    leaf, extra_offset = result
    opkind = source_op_kind_from_offset(s, leaf, offset + extra_offset)
    return (
        opkind !== nothing &&
        JuliaSyntax.is_operator(opkind)
        # is_word_operator filters out things like `isa`.
        &&
        !JuliaSyntax.is_word_operator(opkind)
        # Ignore `K":"` as that indicates the beginning of a symbol, which we don't care
        # about parenthesising.
        &&
        opkind !== K":"
    )
end

function is_source_operator(s::State, cst::JuliaSyntax.GreenNode, offset::Integer)
    # TODO(penelopeysm): do we need to check JuliaSyntax.is_operator as well?
    !isnothing(source_op_kind_from_offset(s, cst, offset))
end

function source_unary_operator_index(is_prefix::Bool, cst::JuliaSyntax.GreenNode, s::State)
    if !haschildren(cst) ||
       !(JuliaSyntax.is_operator(cst) || kind(cst) in KSet"call dotcall")
        return nothing
    end

    childs = children(cst)
    args = findall(n -> !JuliaSyntax.is_whitespace(n), childs)
    isempty(args) && return nothing

    op_arg = if is_prefix
        if (
            kind(cst) === K"dotcall" &&
            length(args) >= 2 &&
            kind(childs[args[1]]) === K"." &&
            !haschildren(childs[args[1]])
        )
            # e.g. `.+x`
            args[2]
        else
            # e.g. `+x`
            args[1]
        end
    else
        # postfix operator
        args[end]
    end
    offset = s.offset + sum(span, childs[1:(op_arg-1)]; init = 0)
    return is_source_operator(s, childs[op_arg], offset) ? op_arg : nothing
end

function source_operator_indices(cst::JuliaSyntax.GreenNode)
    haschildren(cst) || return Int[]

    childs = children(cst)
    args = findall(n -> !JuliaSyntax.is_whitespace(n), childs)
    nonws_args = length(args)
    nonws_args == 0 &&
        error("no non-whitespace children found for operator node; should not happen")

    if kind(cst) === K"op="
        # 4 args for `x += y`, 5 args for `x .+= y` (the dot is preserved as a
        # flag in JuliaSyntax but the kind is the same).
        (nonws_args == 4 || nonws_args == 5) ||
            error("unexpected number of args for op= node", nonws_args, cst)
        return args[2:(end-1)]
    elseif kind(cst) === K"comparison"
        # `x < y < z < ... < w` has `2n - 1` args where `n >= 2`.
        (iseven(nonws_args) || nonws_args < 3) &&
            error("unexpected number of args for comparison node", nonws_args, cst)
        return args[2:2:(end-1)]
    elseif is_short_function_def(cst)
        nonws_args != 3 && error(
            "unexpected number of args for short function definition node",
            nonws_args,
            cst,
        )
        return Int[args[2]]
    elseif JuliaSyntax.is_operator(cst)
        nonws_args != 3 &&
            error("unexpected number of args for operator node", nonws_args, cst)
        return args[2:(end-1)]
    elseif JuliaSyntax.is_prefix_op_call(cst)
        if kind(cst) === K"dotcall" &&
           length(args) >= 2 &&
           kind(childs[args[1]]) === K"." &&
           !haschildren(childs[args[1]])
            return args[1:2]
        else
            return Int[args[1]]
        end
    elseif JuliaSyntax.is_infix_op_call(cst)
        op_indices = Int[]
        i = 2
        while i < length(args)
            push!(op_indices, args[i])
            if kind(cst) === K"dotcall" &&
               i < length(args) &&
               kind(childs[args[i]]) === K"." &&
               !haschildren(childs[args[i]])
                push!(op_indices, args[i+1])
                i += 1
            end
            i += 2
        end
        return op_indices
    elseif JuliaSyntax.is_postfix_op_call(cst)
        return Int[args[end]]
    end

    return Int[]
end

function source_op_kind(s::State, cst::JuliaSyntax.GreenNode)
    opkind = op_kind(cst)
    opkind !== K"None" && opkind !== K"Identifier" && return opkind

    childs = children(cst)
    for i in source_operator_indices(cst)
        c = childs[i]
        offset = Int(s.offset) + sum(span, childs[1:(i-1)]; init = 0)
        k = source_op_kind_from_offset(s, c, offset)
        if !isnothing(k) && !(kind(cst) === K"dotcall" && k === K".")
            return k
        end
    end
    return opkind
end

function do_block_index(childs::Vector{JuliaSyntax.GreenNode{T}}) where {T}
    findfirst(n -> kind(n) === K"do" && haschildren(n), childs)
end

function has_do_block_call(cst::JuliaSyntax.GreenNode)
    kind(cst) in KSet"call dotcall macrocall" && haschildren(cst) || return nothing
    do_block_index(children(cst))
end

function call_args(childs::Vector{JuliaSyntax.GreenNode{T}}) where {T}
    idx = findfirst(n -> kind(n) in KSet"( { [", childs)
    start = isnothing(idx) ? 1 : idx + 1
    get_args(childs[start:end])
end

function last_code_child(cst::JuliaSyntax.GreenNode)
    haschildren(cst) || return nothing
    idx = findlast(n -> !JuliaSyntax.is_whitespace(n), children(cst))
    isnothing(idx) ? nothing : children(cst)[idx]
end

function iteration_rhs(cst::JuliaSyntax.GreenNode)
    rhs = last_code_child(cst)
    if kind(cst) === K"iteration" && !isnothing(rhs) && haschildren(rhs)
        rhs = last_code_child(rhs)
    end
    rhs
end

function iteration_has_comma(cst::JuliaSyntax.GreenNode)
    haschildren(cst) && any(n -> kind(n) === K",", children(cst))
end

"""
    _with_no_transforms(f, s::State, new_status)

Run `f` with a modified state where syntax transformations may be disabled.
"""
function _with_no_transforms(f, s::State, new_status::SyntaxTransformsStatus)
    prev = s.syntax_transforms_status
    s.syntax_transforms_status = new_status
    ret = f()
    s.syntax_transforms_status = prev
    ret
end

function pretty(
    ds::AbstractStyle,
    node::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)::FST
    k = kind(node)
    style = getstyle(ds)
    do_block_idx = has_do_block_call(node)
    push!(lineage, (k, is_iterable(node), is_assignment(node)))

    _unaryinfo = unary_info(node)

    ret = if k == K"Identifier" && !haschildren(node)
        p_identifier(style, node, s, ctx, lineage)
        # Example: `try f() catch g() end` has a zero-width Placeholder
        # where a catch binding would appear.
    elseif k === K"Placeholder"
        s.offset += span(node)
        FST(NONE, 0, 0, 0, "")
    elseif JuliaSyntax.is_operator(node) && !haschildren(node)
        p_operator(style, node, s, ctx, lineage)
    elseif k == K"Comment"
        p_comment(style, node, s, ctx, lineage)
    elseif JuliaSyntax.is_whitespace(node)
        p_whitespace(style, node, s, ctx, lineage)
    elseif k == K";"
        p_semicolon(style, node, s, ctx, lineage)
    elseif is_punc(node) && !haschildren(node)
        p_punctuation(style, node, s, ctx, lineage)
    elseif JuliaSyntax.is_keyword(node) && !haschildren(node)
        p_keyword(style, node, s, ctx, lineage)
    elseif k in KSet"string cmdstring char"
        p_stringh(style, node, s, ctx, lineage)
    elseif JuliaSyntax.is_literal(node) || k in KSet"\" \"\"\" ` ```"
        p_literal(style, node, s, ctx, lineage)
    elseif k == K"as"
        p_as(style, node, s, ctx, lineage)
    elseif k === K"." && haschildren(node)
        p_accessor(style, node, s, ctx, lineage)
    elseif k === K"block" && length(children(node)) > 1 && kind(node[1]) === K"begin"
        p_begin(style, node, s, ctx, lineage)
    elseif k === K"block"
        p_block(style, node, s, ctx, lineage)
        # Example: `f(x) = x` is a function node flagged as short-form.
    elseif is_short_function_def(node)
        p_binaryopcall(style, node, s, ctx, lineage)
    elseif k === K"function"
        p_functiondef(style, node, s, ctx, lineage)
    elseif k in KSet"MacroName StringMacroName CmdMacroName"
        p_macroname(style, node, s, ctx, lineage)
    elseif k === K"macro"
        p_macro(style, node, s, ctx, lineage)
    elseif k === K"struct" && !JuliaSyntax.has_flags(node, JuliaSyntax.MUTABLE_FLAG)
        p_struct(style, node, s, ctx, lineage)
    elseif k === K"struct" && JuliaSyntax.has_flags(node, JuliaSyntax.MUTABLE_FLAG)
        p_mutable(style, node, s, ctx, lineage)
    elseif k === K"for"
        p_for(style, node, s, ctx, lineage)
    elseif k === K"while"
        p_while(style, node, s, ctx, lineage)
    elseif k === K"do"
        p_do(style, node, s, ctx, lineage)
    elseif k === K"var"
        p_var(style, node, s, ctx, lineage)
    elseif is_try(node) ||
           # issue #912
           (k === K"else" && !isnothing(lineage) && lineage[end-1][1] === K"try")
        p_try(style, node, s, ctx, lineage)
    elseif is_if(node)
        p_if(style, node, s, ctx, lineage)
    elseif k === K"toplevel"
        p_toplevel(style, node, s, ctx, lineage)
    elseif k === K"quote" && haschildren(node) && kind(node[1]) === K":"
        _with_no_transforms(s, InsideExpr) do
            p_quotenode(style, node, s, ctx, lineage)
        end
    elseif k === K"quote" && haschildren(node)
        _with_no_transforms(s, InsideExpr) do
            p_quote(style, node, s, ctx, lineage)
        end
    elseif k === K"let"
        p_let(style, node, s, ctx, lineage)
    elseif k === K"vect"
        p_vect(style, node, s, ctx, lineage)
    elseif k === K"comprehension"
        p_comprehension(style, node, s, ctx, lineage)
    elseif k === K"typed_comprehension"
        p_typedcomprehension(style, node, s, ctx, lineage)
    elseif k === K"braces"
        p_braces(style, node, s, ctx, lineage)
    elseif k === K"bracescat"
        p_bracescat(style, node, s, ctx, lineage)
    elseif k === K"tuple"
        p_tuple(style, node, s, ctx, lineage)
        # Example: `for x in xs, y in ys` uses an iteration node.
    elseif k === K"iteration"
        p_iteration(style, node, s, ctx, lineage)
    elseif k === K"parens"
        p_parens(style, node, s, ctx, lineage)
    elseif k === K"curly"
        p_curly(style, node, s, ctx, lineage)
    elseif is_macrostr(node)
        p_macrostr(style, node, s, ctx, lineage)
    elseif k === K"doc"
        p_globalrefdoc(style, node, s, ctx, lineage)
    elseif k === K"macrocall"
        _with_no_transforms(s, InsideMacro) do
            if !isnothing(do_block_idx)
                p_do_call(style, node, s, ctx, lineage, do_block_idx)
            else
                p_macrocall(style, node, s, ctx, lineage)
            end
        end
    elseif k === K"where"
        p_whereopcall(style, node, s, ctx, lineage)
    elseif k === K"?" && haschildren(node)
        p_conditionalopcall(style, node, s, ctx, lineage)
    elseif !isnothing(do_block_idx)
        # Example: `map(xs) do x; x + 1; end` is a call node with a do child.
        p_do_call(style, node, s, ctx, lineage, do_block_idx)
    elseif _unaryinfo !== nothing
        # _unaryinfo === nothing means that it's not unary; true/false indicates whether
        # it's a prefix/postfix.
        p_unaryopcall(style, node, s, ctx, lineage, _unaryinfo)
    elseif Shims.is_function_call(node)
        p_call(style, node, s, ctx, lineage)
    elseif is_binary(node)
        # nodes of the exact form `a OP b`
        p_binaryopcall(style, node, s, ctx, lineage)
    elseif is_chain(node)
        p_chainopcall(style, node, s, ctx, lineage)
    elseif k === K"comparison"
        p_comparison(style, node, s, ctx, lineage)
    elseif k in KSet"dotcall call"
        p_binaryopcall(style, node, s, ctx, lineage)
    elseif k === K"parameters"
        p_parameters(style, node, s, ctx, lineage)
    elseif k === K"local"
        p_local(style, node, s, ctx, lineage)
    elseif k === K"global"
        p_global(style, node, s, ctx, lineage)
    elseif k === K"const"
        p_const(style, node, s, ctx, lineage)
    elseif k === K"return"
        p_return(style, node, s, ctx, lineage)
    elseif k === K"outer"
        p_outer(style, node, s, ctx, lineage)
    elseif k === K"import"
        p_import(style, node, s, ctx, lineage)
    elseif k === K"export"
        p_export(style, node, s, ctx, lineage)
    elseif k === K"public"
        p_public(style, node, s, ctx, lineage)
    elseif k === K"using"
        p_using(style, node, s, ctx, lineage)
    elseif k === K"importpath"
        p_importpath(style, node, s, ctx, lineage)
    elseif k === K"abstract"
        p_abstract(style, node, s, ctx, lineage)
    elseif k === K"primitive"
        p_primitive(style, node, s, ctx, lineage)
        # Example: `baremodule A end` is a module node with BARE_MODULE_FLAG.
    elseif k === K"module" && JuliaSyntax.has_flags(node, JuliaSyntax.BARE_MODULE_FLAG)
        p_baremodule(style, node, s, ctx, lineage)
    elseif k === K"module"
        p_module(style, node, s, ctx, lineage)
    elseif k === K"baremodule"
        p_baremodule(style, node, s, ctx, lineage)
    elseif k === K"row"
        p_row(style, node, s, ctx, lineage)
    elseif k === K"nrow"
        p_nrow(style, node, s, ctx, lineage)
    elseif k === K"ncat"
        p_ncat(style, node, s, ctx, lineage)
    elseif k === K"typed_ncat"
        p_typedncat(style, node, s, ctx, lineage)
    elseif k === K"vcat"
        p_vcat(style, node, s, ctx, lineage)
    elseif k === K"typed_vcat"
        p_typedvcat(style, node, s, ctx, lineage)
    elseif k === K"hcat"
        p_hcat(style, node, s, ctx, lineage)
    elseif k === K"typed_hcat"
        p_typedhcat(style, node, s, ctx, lineage)
    elseif k === K"ref"
        p_ref(style, node, s, ctx, lineage)
    elseif k === K"generator"
        p_generator(style, node, s, ctx, lineage)
    elseif k === K"filter"
        p_filter(style, node, s, ctx, lineage)
    elseif k === K"juxtapose"
        p_juxtapose(style, node, s, ctx, lineage)
    elseif k === K"break"
        p_break(style, node, s, ctx, lineage)
    elseif k === K"continue"
        p_continue(style, node, s, ctx, lineage)
    elseif k === K"inert"
        p_inert(style, node, s, ctx, lineage)
    else
        @warn "unknown node" k node cursor_loc(s)
        if is_leaf(node)
            s.offset += span(node)
            FST(NONE, 0, 0, 0, "")
        else
            tt = FST(Unknown, nspaces(s))
            for a in children(node)
                add_node!(tt, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            end
            tt
        end
    end

    pop!(lineage)

    return ret
end
pretty(style::AbstractStyle, node::JuliaSyntax.GreenNode, s::State)::FST =
    pretty(style, node, s, PrettyContext(), Tuple{JuliaSyntax.Kind,Bool,Bool}[])

function p_identifier(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))
    s.offset += span(cst)
    FST(IDENTIFIER, loc[2], loc[1], loc[1], val)
end

function p_whitespace(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))
    s.offset += span(cst)
    FST(NONE, loc[2], loc[1], loc[1], val)
end

function p_comment(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    same_line = on_same_line(s, s.offset, s.offset + span(cst) - 1)
    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))
    s.offset += span(cst)
    return if startswith(val, "#=") && endswith(val, "=#")
        endloc = cursor_loc(s, s.offset - 1)
        FST(HASHEQCOMMENT, loc[2], loc[1], endloc[1], val)
    else
        # Line comments (`# ...`) are ignored for now but will be added back
        # later inside `add_node!`.
        FST(NONE, loc[2], loc[1], loc[1], "")
    end
end

function p_semicolon(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ::PrettyContext,
    ::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    s.offset += span(cst)
    FST(SEMICOLON, loc[2], loc[1], loc[1], ";")
end

function p_macroname(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ::PrettyContext,
    ::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))
    s.offset += span(cst)
    FST(MACRONAME, loc[2], loc[1], loc[1], val)
end

function p_operator(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ::PrettyContext,
    ::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))
    s.offset += span(cst)
    t = FST(OPERATOR, loc[2], loc[1], loc[1], val)
    t.metadata = Metadata(kind(cst))
    return t
end

function p_keyword(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ::PrettyContext,
    ::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))
    s.offset += span(cst)
    FST(KEYWORD, loc[2], loc[1], loc[1], val)
end

function p_punctuation(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ::PrettyContext,
    ::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))
    s.offset += span(cst)
    FST(PUNCTUATION, loc[2], loc[1], loc[1], val)
end

function p_juxtapose(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Juxtapose, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end

    return t
end

function p_continue(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Continue, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end

    return t
end

function p_break(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Break, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end

    return t
end

# $
function p_inert(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Inert, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end

    return t
end

function p_macrostr(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(MacroStr, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end

    return t
end

# what mean
#
# julia> t = parseall(JuliaSyntax.GreenNode, """r"hello"x""")
#      1:9      │[toplevel]
#      1:9      │  [macrocall]
#      1:1      │    StringMacroName      ✔
#      2:8      │    [string]
#      2:2      │      "
#      3:7      │      String             ✔
#      8:8      │      "
#      9:9      │    String               ✔
#
# if cst.head === :FLOAT && !startswith(val, "0x")
#     if (fidx = findlast(==('f'), val)) === nothing
#         float_suffix = ""
function p_literal(
    ::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    loc = cursor_loc(s)
    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))

    if !is_str_or_cmd(cst)
        if kind(cst) in KSet"Float Float32" && !startswith(val, r"[+-]?0x")
            float_suffix = if (fidx = findlast(==('f'), val)) === nothing
                ""
            else
                fs = val[fidx:end]
                val = val[1:(fidx-1)]
                fs
            end
            if findfirst(c -> c == 'e' || c == 'E', val) === nothing
                if (dotidx = findlast(==('.'), val)) === nothing
                    val *= s.opts.trailing_zero ? ".0" : ""  # append a trailing zero prior to the suffix
                elseif dotidx == length(val)
                    val *= s.opts.trailing_zero ? "0" : ""  # if a float literal ends in `.`, add trailing zero.
                elseif dotidx == 1
                    val = '0' * val  # leading zero
                elseif dotidx == 2 && (val[1] == '-' || val[1] == '+')
                    val = val[1] * '0' * val[2:end]  # leading zero on signed numbers
                end
            end
            val *= float_suffix
        end
    end

    s.offset += span(cst)
    return FST(LITERAL, loc[2], loc[1], loc[1], val)
end

function p_accessor(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Accessor, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end
    t
end

# StringH
function p_stringh(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    ::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    loc = cursor_loc(s)
    if !haschildren(cst)
        return FST(StringN, loc[2] - 1)
    end
    loc2 = cursor_loc(s, s.offset + span(cst) - 1)

    val = getsrcval(s.doc, (s.offset):(s.offset+span(cst)-1))
    startline = loc[1]
    endline = loc2[1]

    s.offset += span(cst)

    if ctx.from_docstring && s.opts.format_docstrings
        val = format_docstring(style, s, val)
    end

    if isnothing(findfirst('\n', val))
        return FST(LITERAL, loc[2], startline, startline, val)
    end

    # The indent for the StringN FST should be the display width of the first line prior
    # to the opening quote. loc[2] is already a display column (1-indexed).
    t = FST(StringN, loc[2] - 1)
    t.line_offset = loc[2]

    lines = split(val, "\n")
    # Calculate the display column of the first non-whitespace character in the string
    # literal.
    sidx = loc[2]  # Display column of the opening quote.
    for l in lines[2:end]
        # Note that `fc` is actually a byte index, not a display column. This works only
        # insofar as all whitespace characters (as defined by isspace(c)) have the same
        # display width and byte width (for example, for a regular space both are 1). This
        # is not, in general, true: for example, for U+3000 IDEOGRAPHIC SPACE we have that
        #    isspace('\u3000')     ==>  true
        #    ncodeunits('\u3000')  ==>  3
        #    textwidth('\u3000')   ==>  2
        # However, this is pathological enough to not worry about.
        fc = findfirst(c -> !isspace(c), l)
        if !isnothing(fc)
            sidx = min(sidx, fc)
        end
    end

    for (i, l) in enumerate(lines)
        ln = startline + i - 1
        l = i == 1 ? l : l[sidx:end]
        n = FST(LITERAL, ln, ln, sidx - 1, textwidth(l), l, (), AllowNest, 0, -1, nothing)
        add_node!(t, n, s)
    end

    # we need to maintain the start and endlines of the original source
    t.startline = startline
    t.endline = endline

    t
end

# GlobalRefDoc (docstring)
function p_globalrefdoc(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(GlobalRefDoc, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    for (i, c) in enumerate(childs)
        if i == 1
            add_node!(
                t,
                pretty(style, c, s, newctx(ctx; from_docstring = true), lineage),
                s;
                max_padding = 0,
            )
        elseif i == length(childs)
            add_node!(t, pretty(style, c, s, ctx, lineage), s; max_padding = 0)
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        end
    end

    return t
end

# MacroCall
function p_macrocall(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}};
    do_block_idx::Union{Int,Nothing} = nothing,
)
    style = getstyle(ds)
    t = FST(MacroCall, nspaces(s))
    JuliaSyntax.is_leaf(cst) && return t

    args = get_args(cst)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)
    childs = children(cst)

    # A macrocall may be followed by a do-block, e.g. `@modify(x) do y ... end`.
    # `p_do_call` formats the head here (truncating the do-block) and wraps the
    # result in a `Do` node. Without this the do-block's closer is mistaken for
    # the macrocall closer, the args are treated as a macroblock, and extraneous
    # whitespace is emitted (e.g. `@modify(x)  do`).
    if !isnothing(do_block_idx)
        if !checkbounds(Bool, childs, do_block_idx) ||
           kind(childs[do_block_idx]) !== K"do" ||
           !haschildren(childs[do_block_idx])
            error("p_macrocall called with an invalid do block index")
        end
        childs = childs[1:(do_block_idx-1)]
    end

    has_closer = is_closer(childs[end])
    is_macroblock = !has_closer

    if is_macroblock
        t.typ = MacroBlock
    end

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)::FST
        if JuliaSyntax.is_macro_name(a)
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K"("
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
            end
        elseif kind(a) === K")"
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
            end
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

            if join_lines && (i > 1 && Shims.is_really_whitespace(childs[i-1])) ||
               next_node_is(Shims.is_really_whitespace, childs[i])
                add_node!(t, Whitespace(1), s)
            end
            add_node!(t, n, s; join_lines, max_padding)
        else
            if has_closer
                add_node!(t, n, s; join_lines = true)
            else
                padding = is_block(n) ? 0 : -1
                add_node!(t, n, s; join_lines = true, max_padding = padding)
            end
        end
    end

    # move placement of @ to the end
    #
    # @Module.macro -> Module.@macro
    t[1] = move_at_sign_to_the_end(t[1], s)
    t
end

# `#= ... =#` comments are reported as whitespace by JuliaSyntax, so block
# handlers that skip whitespace would otherwise drop them. Append the comment
# (keeping it on the current line when it trails code) instead of losing it.
#
# Returns true if the comment was added, false otherwise.
function add_hasheq_comment!(t::FST, n::FST, s::State)
    n.typ === HASHEQCOMMENT || return false
    tnodes = t.nodes::Vector{FST}
    if isempty(tnodes)
        # A leading comment establishes the block's line tracking. Without this
        # the custom-leaf path in `add_node!` copies `t.endline` (still 0), and
        # the next code node computes a bogus NOTCODE range spanning the whole
        # preceding source, duplicating unrelated comments.
        t.startline = n.startline
        t.endline = n.endline
    elseif !(tnodes[end].typ in (NEWLINE, WHITESPACE, PLACEHOLDER, NOTCODE))
        add_node!(t, Whitespace(1), s)
    end
    add_node!(t, n, s; join_lines = true)
    return true
end

"""
Recursively check whether a CST node contains a `return` node anywhere inside it.
Used to avoid prepending `return` to expressions like `x > 0 ? (return 1) : (return 2)`.
"""
function _contains_return(cst::JuliaSyntax.GreenNode)::Bool
    kind(cst) === K"return" && return true
    haschildren(cst) && return any(_contains_return, children(cst))
    return false
end

"""
    should_add_return_to_last_statement(cst, s, style, lineage)

For a block `cst`, determine whether we should add a `return` to the last statement in the block.
"""
function should_add_return_to_last_statement(
    cst::JuliaSyntax.GreenNode,
    s::State,
    style::AbstractStyle,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    kind(cst) === K"block" ||
        error("should_add_return_to_last_statement called on a non-block node")

    # If the option is not enabled, don't add return.
    s.opts.always_use_return || return false
    can_transform_syntax(s, true) || return false

    # If the block is empty, don't add return.
    last_stmt_idx =
        findlast(n -> !JuliaSyntax.is_whitespace(n) && kind(n) !== K";", children(cst))
    last_stmt_idx === nothing && return false

    # Only add return if the block is the body of a function/macro definition or a do-block
    # in a function/macro call.
    if !(
        length(lineage) >= 2 && lineage[end-1][1] in KSet"function macro" ||
        length(lineage) >= 3 &&
        lineage[end-1][1] === K"do" &&
        lineage[end-2][1] in KSet"call macrocall"
    )
        return false
    end

    # Need to check the children carefully now.
    last_stmt = children(cst)[last_stmt_idx]
    # If the last statement is already a return or a macro, don't add return.
    if kind(last_stmt) in KSet"return macrocall"
        return false
    end
    # If the last statement is a block, don't add return.
    if is_block(last_stmt, style)
        return false
    end
    # Do-blocks don't get caught by `is_block()` because they have K"call" or K"macrocall",
    # so we search for them separately here and disable them here too.
    if has_do_block_call(last_stmt) !== nothing
        return false
    end

    # If the last statement already contains a `return` somewhere inside it (e.g.
    # `x > 0 ? (return 1) : (return 2)`), don't add another one.
    if _contains_return(last_stmt)
        return false
    end

    # If the last statement is something that has a docstring attached to it, don't add
    # return. See https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/405
    #
    # There are several cases we have to deal with here:
    #
    #     @doc """string"""\n f -- in this case the last statement is the entire macrocall
    #                              and so will be skipped by the previous branch, we don't
    #                              need to worry about it here.
    #     raw"""string"""\n f   -- [macrocall] -> NewlineWS -> Identifier
    #     """string"""\n f      -- [string] -> NewlineWS -> Identifier
    if last_stmt_idx >= 3
        preceded_by_newline = kind(cst[last_stmt_idx-1]) === K"NewlineWs"
        maybe_docstring = cst[last_stmt_idx-2]
        then_preceded_by_docstring =
            kind(maybe_docstring) === K"string" || (
                kind(maybe_docstring) === K"macrocall" &&
                haschildren(maybe_docstring) &&
                kind(maybe_docstring[1]) === K"StringMacroName"
            )
        if preceded_by_newline && then_preceded_by_docstring
            return false
        end
    end

    return true
end

# Block
# length Block is the length of the longest expr
function p_block(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Block, nspaces(s))
    if !haschildren(cst)
        return t
    end

    # We might want to add return to the last statement.
    add_return_to_last_statement =
        should_add_return_to_last_statement(cst, s, style, lineage)
    # Technically this doesn't need to be computed if add_return_to_last_statement is false,
    # but it's cheap.
    last_stmt_idx =
        findlast(n -> !JuliaSyntax.is_whitespace(n) && kind(n) !== K";", children(cst))

    join_body = ctx.join_body
    ignore_single_line = ctx.ignore_single_line
    from_quote = ctx.from_quote

    childs = children(cst)
    has_paren = !isnothing(findfirst(n -> kind(n) === K"(", childs))

    if has_paren && !from_quote
        return p_tupleblock(style, cst, s, ctx, lineage)
    end

    single_line =
        ignore_single_line ? false : on_same_line(s, s.offset, s.offset + span(cst) - 1)

    before_first_arg = true

    # TODO: fix this so we can pass it through
    ctx = newctx(ctx; ignore_single_line = false, join_body = false, from_quote = false)

    for (i, a) in enumerate(childs)
        if kind(a) === K"Comment"
            add_hasheq_comment!(t, pretty(style, a, s, ctx, lineage), s)
            continue
        elseif is_ws(a)
            s.offset += span(a)
            continue
        end

        if from_quote && !single_line
            n = pretty(style, a, s, ctx, lineage)
            if kind(a) in KSet"; ) ("
                add_node!(t, n, s; join_lines = true)
            elseif kind(a) === K","
                add_node!(t, n, s; join_lines = true)
                if has_more_args_to_come(childs, i + 1, K")")
                    add_node!(t, Whitespace(1), s)
                end
            elseif JuliaSyntax.is_whitespace(a)
                add_node!(t, n, s; join_lines = true)
            elseif before_first_arg
                add_node!(t, n, s; join_lines = true)
                before_first_arg = false
            else
                add_node!(t, n, s; max_padding = 0)
            end
        elseif single_line
            n = pretty(style, a, s, ctx, lineage)
            if kind(a) in KSet", ;"
                add_node!(t, n, s; join_lines = true)
                if has_more_args_to_come(childs, i + 1, K")")
                    add_node!(t, Placeholder(1), s)
                end
            else
                add_node!(t, n, s; join_lines = true)
            end
        else
            if kind(a) === K","
                n = pretty(style, a, s, ctx, lineage)
                add_node!(t, n, s; join_lines = true)
                if join_body && has_more_args_to_come(childs, i + 1, K")")
                    add_node!(t, Placeholder(1), s)
                end
            elseif kind(a) === K";"
                n = pretty(style, a, s, ctx, lineage)
                add_node!(t, n, s; join_lines = true)
            elseif join_body
                n = pretty(style, a, s, ctx, lineage)
                add_node!(t, n, s; join_lines = true)
            else
                # Other statements.
                node_to_add = if i === last_stmt_idx && add_return_to_last_statement
                    # Add a return statement to the last statement in the block.
                    c = cursor_loc(s)
                    return_fst = FST(Return, nspaces(s))
                    add_node!(
                        return_fst,
                        FST(KEYWORD, c[2], c[1], c[1], "return"),
                        s;
                        join_lines = true,
                    )
                    add_node!(return_fst, Whitespace(1), s; join_lines = true)
                    # have to push to lineage to make sure that the return value node is
                    # formatted properly. See #1125.
                    push!(lineage, (K"return", false, false))
                    n = pretty(style, a, s, ctx, lineage)
                    pop!(lineage)
                    add_node!(return_fst, n, s; join_lines = true)
                    return_fst
                else
                    pretty(style, a, s, ctx, lineage)
                end
                add_node!(t, node_to_add, s; max_padding = 0)
            end
        end
    end

    t
end

function p_block(
    ds::AbstractStyle,
    nodes::Vector{JuliaSyntax.GreenNode{T}},
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
) where {T}
    style = getstyle(ds)
    t = FST(Block, nspaces(s))

    ctx = newctx(ctx; ignore_single_line = false, join_body = false, from_quote = false)
    for (i, a) in enumerate(nodes)
        if kind(a) === K"Comment"
            add_hasheq_comment!(t, pretty(style, a, s, ctx, lineage), s)
            continue
        elseif is_ws(a)
            s.offset += span(a)
            continue
        end
        n = pretty(style, a, s, ctx, lineage)
        if i < length(nodes) && kind(a) === K"," && is_punc(nodes[i+1])
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K"," && i != length(nodes)
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K";"
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(t, n, s; max_padding = 0)
        end
    end
    t
end

# Abstract
function p_abstract(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Abstract, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        if !JuliaSyntax.is_whitespace(c) && kind(c) !== K"end"
            add_node!(t, Whitespace(1), s)
        end
    end
    t
end

# Primitive
function p_primitive(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Primitive, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        if !JuliaSyntax.is_whitespace(c) && kind(c) !== K"end"
            add_node!(t, Whitespace(1), s)
        end
    end
    t
end

function p_var(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(NonStdIdentifier, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end
    t
end

# function/macro
function p_functiondef(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(FunctionN, nspaces(s))
    JuliaSyntax.is_leaf(cst) && return t

    function_or_macro_keyword_idx = findfirst(
        n -> kind(n) in KSet"function macro" && JuliaSyntax.is_leaf(n),
        children(cst),
    )

    # We might want to disable separate_kwargs_with_semicolon for the initial
    # call in a function/macro definition.
    caller_idx = findnext(
        n -> !JuliaSyntax.is_whitespace(n),
        children(cst),
        function_or_macro_keyword_idx + 1,
    )
    if !Shims.is_caller_in_function_def(cst[caller_idx])
        # If that child doesn't look like a function call, then it's an anonymous function.
        # In that case we can disable the check.
        caller_idx = nothing
    end

    block_has_contents = false
    childs = children(cst)
    for (i, c) in enumerate(childs)
        if i == function_or_macro_keyword_idx
            n = pretty(style, c, s, ctx, lineage)
            add_node!(t, n, s)
            add_node!(t, Whitespace(1), s)
        elseif kind(c) === K"end"
            n = pretty(style, c, s, ctx, lineage)
            if block_has_contents
                add_node!(t, n, s)
            else
                # Empty block
                if s.opts.join_lines_based_on_source
                    join_lines = t.endline == n.startline
                    if join_lines
                        add_node!(t, Whitespace(1), s)
                    end
                    add_node!(t, n, s; join_lines = join_lines)
                else
                    # Force the end keyword to go onto the same line as the definition.
                    add_node!(t, Whitespace(1), s)
                    # Override n.startline so that the `end` keyword ends up on the same
                    # line as the rest of the function def. But don't override n.endline,
                    # otherwise extra newlines will be inserted after the `end`.
                    n.startline = t.endline
                    add_node!(t, n, s; join_lines = true)
                end
            end
        elseif kind(c) === K"block" && haschildren(c)
            block_has_contents = any(cc -> !Shims.is_really_whitespace(cc), children(c))
            s.indent += s.opts.indent
            n = pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage)
            add_node!(t, n, s; max_padding = s.opts.indent)
            s.indent -= s.opts.indent
        elseif i === caller_idx
            n = pretty(style, c, s, newctx(ctx; can_separate_kwargs = false), lineage)
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        end
    end
    t.metadata = Metadata(
        kind(cst),
        false,
        false,
        false,
        false,
        can_transform_syntax(s, true),
        false,
    )
    t
end

function p_macro(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_functiondef(ds, cst, s, ctx, lineage)
    t.typ = Macro
    t
end

# struct
function p_struct(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Struct, nspaces(s))
    if !haschildren(cst)
        return t
    end

    block_has_contents = false
    childs = children(cst)
    for (i, c) in enumerate(childs)
        if i == 1
            n = pretty(style, c, s, ctx, lineage)
            add_node!(t, n, s)
            add_node!(t, Whitespace(1), s)
        elseif kind(c) === K"end"
            n = pretty(style, c, s, ctx, lineage)
            if s.opts.join_lines_based_on_source && !block_has_contents
                join_lines = t.endline == n.startline
                if join_lines
                    (add_node!(t, Whitespace(1), s))
                else
                    false
                end
                add_node!(t, n, s; join_lines = join_lines)
            elseif block_has_contents
                add_node!(t, n, s)
            else
                add_node!(t, Whitespace(1), s)
                add_node!(t, n, s; join_lines = true)
            end
        elseif kind(c) === K"block" && haschildren(c)
            block_has_contents =
                length(filter(cc -> !JuliaSyntax.is_whitespace(cc), children(c))) > 0
            s.indent += s.opts.indent
            n = pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage)
            if s.opts.annotate_untyped_fields_with_any && can_transform_syntax(s, true)
                annotate_typefields_with_any!(n, s)
            end
            add_node!(t, n, s; max_padding = s.opts.indent)
            s.indent -= s.opts.indent
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        end
    end
    t
end

# mutable
function p_mutable(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Mutable, nspaces(s))
    if !haschildren(cst)
        return t
    end

    block_has_contents = false
    childs = children(cst)
    for c in childs
        if kind(c) in KSet"struct mutable"
            n = pretty(style, c, s, ctx, lineage)
            add_node!(t, n, s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        elseif kind(c) === K"end"
            n = pretty(style, c, s, ctx, lineage)
            if s.opts.join_lines_based_on_source && !block_has_contents
                join_lines = t.endline == n.startline
                if join_lines
                    (add_node!(t, Whitespace(1), s))
                else
                    false
                end
                add_node!(t, n, s; join_lines = join_lines)
            elseif block_has_contents
                add_node!(t, n, s)
            else
                add_node!(t, Whitespace(1), s)
                add_node!(t, n, s; join_lines = true)
            end
        elseif kind(c) === K"block" && haschildren(c)
            block_has_contents =
                length(filter(cc -> !JuliaSyntax.is_whitespace(cc), children(c))) > 0
            s.indent += s.opts.indent
            n = pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage)
            if s.opts.annotate_untyped_fields_with_any && can_transform_syntax(s, true)
                annotate_typefields_with_any!(n, s)
            end
            add_node!(t, n, s; max_padding = s.opts.indent)
            s.indent -= s.opts.indent
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        end
    end
    t
end

# module/baremodule
function p_module(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(ModuleN, nspaces(s))
    if !haschildren(cst)
        return t
    end

    from_module = ctx.from_module
    block_has_contents = false
    childs = children(cst)
    indent_module = s.opts.indent_submodule && from_module

    for c in childs
        if kind(c) in KSet"module baremodule" && !haschildren(c)
            n = pretty(style, c, s, ctx, lineage)
            add_node!(t, n, s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        elseif kind(c) === K"end"
            n = pretty(style, c, s)
            if s.opts.join_lines_based_on_source && !block_has_contents
                join_lines = t.endline == n.startline
                if join_lines
                    (add_node!(t, Whitespace(1), s))
                else
                    false
                end
                add_node!(t, n, s; join_lines = join_lines)
            elseif block_has_contents
                add_node!(t, n, s)
            else
                add_node!(t, Whitespace(1), s)
                add_node!(t, n, s; join_lines = true)
            end
        elseif kind(c) === K"block" && haschildren(c)
            block_has_contents =
                length(filter(cc -> !JuliaSyntax.is_whitespace(cc), children(c))) > 0

            if indent_module
                s.indent += s.opts.indent
            end
            n = pretty(
                style,
                c,
                s,
                newctx(ctx; from_module = true, ignore_single_line = true),
                lineage,
            )
            if indent_module
                add_node!(t, n, s; max_padding = s.opts.indent)
                s.indent -= s.opts.indent
            else
                add_node!(t, n, s; max_padding = 0)
            end
        else
            add_node!(
                t,
                pretty(style, c, s, newctx(ctx; from_module = true), lineage),
                s;
                join_lines = true,
            )
        end
    end
    t
end

function p_baremodule(
    style::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_module(style, cst, s, ctx, lineage)
    t.typ = BareModule
    t
end

function p_return(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_const(ds, cst, s, ctx, lineage)
    t.typ = Return
    t
end

# const/local/global/outer/return
function p_const(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Const, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        if kind(c) === K","
        elseif !JuliaSyntax.is_whitespace(c) && !JuliaSyntax.is_keyword(c)
            add_node!(t, Whitespace(1), s)
        elseif !JuliaSyntax.is_whitespace(c) && JuliaSyntax.is_keyword(c) && haschildren(c)
            add_node!(t, Whitespace(1), s)
        end
        add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
    end
    t
end

function p_local(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_const(ds, cst, s, ctx, lineage)
    t.typ = Local
    t
end

function p_global(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_const(ds, cst, s, ctx, lineage)
    t.typ = Global
    t
end

function p_outer(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_const(ds, cst, s, ctx, lineage)
    t.typ = Outer
    t
end

function p_toplevel(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(TopLevel, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for a in children(cst)
        n = pretty(style, a, s, ctx, lineage)
        if kind(a) === K";"
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(t, n, s; max_padding = 0)
        end
    end
    t
end

function p_begin(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Begin, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    add_node!(t, pretty(style, childs[1], s, ctx, lineage), s)
    empty_body = length(filter(n -> !Shims.is_really_whitespace(n), childs)) == 2

    if empty_body && !s.opts.join_lines_based_on_source
        for c in childs[2:(end-1)]
            pretty(style, c, s, ctx, lineage)
        end
        add_node!(t, Whitespace(1), s)
        # Override the `end` keyword's startline to match `begin`, so that
        # add_node! doesn't detect a source line gap and insert a NEWLINE.
        # Without this, `begin\n\nend` → `begin\nend` (pass 1) → `begin end`
        # (pass 2), i.e. non-idempotent.
        end_node = pretty(style, cst[end], s)
        end_node.startline = t.endline
        # but don't override endline or else that inserts extra newlines at the end
        add_node!(t, end_node, s; join_lines = true)
    else
        push!(lineage, (K"block", false, false))
        s.indent += s.opts.indent
        add_node!(
            t,
            p_block(style, childs[2:(end-1)], s, ctx, lineage),
            s;
            max_padding = s.opts.indent,
        )
        s.indent -= s.opts.indent
        pop!(lineage)
        add_node!(t, pretty(style, cst[end], s), s)
    end
    t
end

function p_quote(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Quote, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    if kind(childs[1]) === K"block"
        add_node!(t, p_begin(style, childs[1], s, ctx, lineage), s; join_lines = true)
        for i in 2:length(childs)
            add_node!(t, pretty(style, childs[i], s, ctx, lineage), s; join_lines = true)
        end
    else
        for c in childs
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        end
    end

    return t
end

function p_quotenode(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Quotenode, nspaces(s))
    if !haschildren(cst)
        return t
    end

    ctx = newctx(ctx; from_quote = true)
    for a in children(cst)
        add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
    end
    t
end

# Let
#
# two forms:
#
# let var1 = value1, var2
#     body
# end
#
# y, back = let
#     body
# end
# #
#
# let
# [block]
# ...
# [block]
# end
function p_let(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Let, nspaces(s))
    if !haschildren(cst)
        return t
    end
    block_id = 1

    has_let_args = false

    childs = children(cst)
    for (i, c) in enumerate(childs)
        if kind(c) === K"block"
            s.indent += s.opts.indent
            if block_id == 1
                has_let_args =
                    haschildren(c) &&
                    any(n -> kind(n) === K"," || is_iterable(n), children(c))
                add_node!(
                    t,
                    pretty(
                        style,
                        c,
                        s,
                        newctx(ctx; join_body = true, from_let = true),
                        lineage,
                    ),
                    s;
                    join_lines = true,
                )
            else
                add_node!(
                    t,
                    pretty(
                        style,
                        c,
                        s,
                        newctx(ctx; ignore_single_line = true, from_let = true),
                        lineage,
                    ),
                    s;
                    max_padding = s.opts.indent,
                )
                if has_let_args && (t.nodes::Vector{FST})[end-2].typ !== NOTCODE
                    insert!(t, length(t.nodes) - 1, Placeholder(0))
                end
            end
            s.indent -= s.opts.indent
            block_id += 1
        elseif kind(c) === K"let"
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
            if block_id == 1 &&
               kind(childs[i+1]) === K"block" &&
               length(children(childs[i+1])) > 0
                add_node!(t, Whitespace(1), s)
            end
        elseif kind(c) === K"end"
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        else
            add_node!(
                t,
                pretty(style, c, s, newctx(ctx; from_let = true), lineage),
                s;
                join_lines = true,
            )
        end
    end
    t
end

# For/While
function p_for(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(For, nspaces(s))
    if !haschildren(cst)
        return t
    end

    ends_in_iterable = false
    is_while_cond = false

    for c in children(cst)
        if kind(c) in KSet"for while" && !haschildren(c)
            add_node!(t, pretty(style, c, s), s)
            if kind(c) === K"while"
                is_while_cond = true
            end
        elseif kind(c) === K"end"
            add_node!(t, pretty(style, c, s), s)
        elseif kind(c) === K"block"
            # We need `is_while_cond` to determine whether the block we see is the body of
            # the loop, or the condition of a while loop such as `while (a; b; c) ... end`.
            # See also `p_if` for similar considerations.
            if is_while_cond
                is_while_cond = false
                add_node!(t, Whitespace(1), s)
                add_node!(t, pretty(style, c, s), s; join_lines = true)
            else
                # The body of the for/while loop.
                s.indent += s.opts.indent
                n = pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage)
                add_node!(t, n, s; max_padding = s.opts.indent)
                s.indent -= s.opts.indent

                if !ends_in_iterable && (t.nodes::Vector{FST})[end-2].typ !== NOTCODE
                    insert!(t, length(t.nodes) - 1, Placeholder(0))
                end
            end
        elseif JuliaSyntax.is_whitespace(c)
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        else
            # Non-block while conditions or for loop iterables fall here.
            is_while_cond = false
            add_node!(t, Whitespace(1), s)
            n = if kind(c) === K"iteration"
                rhs_is_iterable = !iteration_has_comma(c) && is_iterable(iteration_rhs(c))
                if !rhs_is_iterable
                    s.indent += s.opts.indent
                end
                n = pretty(style, c, s, newctx(ctx; from_for = true), lineage)
                if !rhs_is_iterable
                    s.indent -= s.opts.indent
                end
                if rhs_is_iterable
                    ends_in_iterable = true
                end
                n
            else
                n = pretty(style, c, s, newctx(ctx; from_for = true), lineage)
                if !is_leaf(n::FST) && length(n.nodes) > 1 && is_iterable(n[end])
                    ends_in_iterable = true
                end
                n
            end
            if kind(cst) === K"for"
                eq_to_in_normalization!(n, s.opts.always_for_in, s.opts.for_in_replacement)
            end
            add_node!(t, n, s; join_lines = true)
        end
    end

    t
end

function p_iteration(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(CartesianIterator, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    for (i, c) in enumerate(childs)
        n = pretty(style, c, s, ctx, lineage)
        if kind(c) === K","
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, Placeholder(1), s)
            end
        elseif !JuliaSyntax.is_whitespace(c)
            if ctx.from_for
                eq_to_in_normalization!(n, s.opts.always_for_in, s.opts.for_in_replacement)
            end
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(t, n, s; join_lines = true)
        end
    end

    t
end

function p_while(
    style::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_for(style, cst, s, ctx, lineage)
    t.typ = While
    t
end

function append_do_nodes!(
    t::FST,
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    for (i, c) in enumerate(childs)
        if kind(c) === K"do" && !haschildren(c)
            add_node!(t, Whitespace(1), s)
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        elseif kind(c) === K"end"
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        elseif kind(c) === K"block"
            s.indent += s.opts.indent
            n = pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage)
            add_node!(t, n, s; max_padding = s.opts.indent)
            s.indent -= s.opts.indent
        elseif kind(c) === K"tuple"
            # the thing immediately after the do.
            n = pretty(style, c, s, ctx, lineage)
            if !isempty(n.nodes)
                # if it's a nontrivial tuple then we need to separate it from the do.
                add_node!(t, Whitespace(1), s)
            end
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        end
    end
    t
end

# Do
# node [nodes] do [nodes] node node end
function p_do(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = FST(Do, nspaces(s))
    append_do_nodes!(t, ds, cst, s, ctx, lineage)
end

function p_do_call(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
    do_block_idx::Int,
)
    t = FST(Do, nspaces(s))
    childs = children(cst)
    if !checkbounds(Bool, childs, do_block_idx) ||
       kind(childs[do_block_idx]) !== K"do" ||
       !haschildren(childs[do_block_idx])
        error("p_do_call called without a do block")
    end

    head = if kind(cst) === K"macrocall"
        p_macrocall(ds, cst, s, ctx, lineage; do_block_idx = do_block_idx)
    else
        p_call(ds, cst, s, ctx, lineage; do_block_idx = do_block_idx)
    end
    add_node!(t, head, s; join_lines = true)

    do_node = childs[do_block_idx]
    push!(lineage, (kind(do_node), is_iterable(do_node), is_assignment(do_node)))
    append_do_nodes!(t, ds, do_node, s, ctx, lineage)
    pop!(lineage)

    t
end

# Try
function p_try(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Try, nspaces(s))
    if !haschildren(cst)
        return t
    end

    # With JuliaSyntax this is now a tree structure instead of being linear
    # since we're still picking up comments in add_node! if the comment is at
    # the end of block it will be added as a comment in the parent node and hence
    # have a lower indentation than the rest of the block. To counteract that we reduce
    # the indent when we encounter "catch finally end" keywords.
    #
    # Apparently "try catch else end" is also valid.

    childs = children(cst)
    for c in childs
        if kind(c) in KSet"try catch finally else"
            if !haschildren(c)
                if kind(c) in KSet"catch finally else"
                    s.indent -= s.opts.indent
                end
                add_node!(t, pretty(style, c, s, ctx, lineage), s; max_padding = 0)
            else
                len = length(t)
                n = pretty(style, c, s, ctx, lineage)
                add_node!(t, n, s; max_padding = 0)
                t.len = max(len, length(n))
            end
        elseif kind(c) === K"end"
            s.indent -= s.opts.indent
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        elseif kind(c) === K"block"
            s.indent += s.opts.indent
            add_node!(
                t,
                pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                s;
                max_padding = s.opts.indent,
            )
        elseif !JuliaSyntax.is_whitespace(c)
            # "catch" vs "catch ..."
            if !(kind(cst) === K"catch" && any(n -> kind(n) === K"Placeholder", childs))
                add_node!(t, Whitespace(1), s)
            end
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        end
    end
    t
end

# If
function p_if(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(If, nspaces(s))
    if !haschildren(cst)
        return t
    end

    # Flag to indicate when we are processing the condition of an if or elseif.
    is_cond = false

    for c in children(cst)
        if kind(c) in KSet"if elseif else"
            if !haschildren(c)
                add_node!(t, pretty(style, c, s, ctx, lineage), s; max_padding = 0)
            else
                # TODO(penelopeysm) how can an if/elseif/else keyword have a child?
                len = length(t)
                n = pretty(style, c, s, ctx, lineage)
                add_node!(t, n, s)
                t.len = max(len, length(n))
            end
            if kind(c) in KSet"if elseif"
                # The next non-whitespace node we see is the condition.
                is_cond = true
            end
        elseif kind(c) === K"end"
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        elseif kind(c) === K"block"
            # This block could either be the condition (if it immediatelly follows an `if`
            # or `elseif`, ignoring whitespace), or it could be the actual body. This is
            # determined by the `is_cond` flag.
            if is_cond
                add_node!(t, Whitespace(1), s)
                add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
                # The next block will be the body.
                is_cond = false
            else
                s.indent += s.opts.indent
                add_node!(
                    t,
                    pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                    s;
                    max_padding = s.opts.indent,
                )
                s.indent -= s.opts.indent
            end
        elseif !JuliaSyntax.is_whitespace(c)
            # This branch is hit for non-block conditions (i.e. simple things like the `x`
            # in `if x; ...`).
            add_node!(t, Whitespace(1), s)
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
            if is_cond # should be true, but check just to be safe
                is_cond = false
            end
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        end
    end

    return t
end

# Chain/Comparison
function p_chainopcall(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_binaryopcall(ds, cst, s, ctx, lineage)
    t.typ = Chain
    t
end

function p_comparison(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_binaryopcall(ds, cst, s, ctx, lineage)
    t.typ = Comparison
    t
end

# Kw
# this is only called on it's own so we need to add the lineage
function p_kw(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Kw, nspaces(s))
    if !haschildren(cst)
        return t
    end

    push!(lineage, (kind(cst), false, true))

    # We need to process the LHS and RHS slightly differently in the loop below.
    equal_idx = findfirst(n -> kind(n) === K"=", children(cst))
    equal_idx === nothing && error("unreachable: kw node without an equal sign")
    immediate_rhs_idx =
        findnext(n -> !Shims.is_really_whitespace(n), children(cst), equal_idx + 1)
    immediate_lhs_idx =
        findprev(n -> !Shims.is_really_whitespace(n), children(cst), equal_idx - 1)
    immediate_rhs_idx === nothing && error("unreachable: kw node without a RHS")
    immediate_lhs_idx === nothing && error("unreachable: kw node without a LHS")

    for (i, c) in enumerate(children(cst))
        if kind(c) === K"="
            s.opts.whitespace_in_kwargs && add_node!(t, Whitespace(1), s)
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
            s.opts.whitespace_in_kwargs && add_node!(t, Whitespace(1), s)
        else
            child_offset = s.offset
            n = pretty(style, c, s, ctx, lineage)
            # Check if the name of the kwarg ends with an exclamation mark, or if the name
            # of the kwarg is an op (note that the name has to be a single identifier so
            # checking that it begins with an op is equivalent to checking that is an op),
            # or if the value of the kwarg begins with an op.
            #
            # In all of these cases, we need to parenthesise it to avoid ambiguity.
            parenthesise =
                !s.opts.whitespace_in_kwargs && begin
                    if i == immediate_rhs_idx && kind(c) !== K"Comment"
                        source_begins_with_op_needing_parens(s, c, child_offset)
                    elseif i === immediate_lhs_idx && kind(c) === K"Identifier"
                        endswith(n.val, "!") || Shims.is_valid_nonword_operator(n.val)
                    else
                        false
                    end
                end

            node = if parenthesise
                paren_fst = FST(Brackets, nspaces(s))
                add_node!(
                    paren_fst,
                    FST(PUNCTUATION, -1, n.startline, n.startline, "("),
                    s;
                    join_lines = true,
                )
                add_node!(paren_fst, Placeholder(0), s)
                add_node!(paren_fst, n, s; join_lines = true)
                add_node!(paren_fst, Placeholder(0), s)
                add_node!(
                    paren_fst,
                    FST(PUNCTUATION, -1, n.startline, n.startline, ")"),
                    s;
                    join_lines = true,
                )
                paren_fst
            else
                n
            end
            add_node!(t, node, s; join_lines = true)
        end
    end

    pop!(lineage)

    t
end

"""
    p_pipe_to_call

Take a CST of the form `x |> y` or `x .|> y`, but return a FST with the equivalent function
call `y(x)` or `y.(x)` instead.

Note that this function is only called for certain pipe-applications. See the call site in
`p_binaryopcall` for details.
"""
function p_pipe_to_call(
    style::AbstractStyle,
    # cst here must be a binary op call with |> as the operator (possibly dotted).
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    # WARNING: This transformation can lead to semantic changes. See e.g.
    # - https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/439
    # - https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/647
    # 
    # This should really be removed in a future version of JuliaFormatter.
    @warn (
        "JuliaFormatter transformed one or more expressions with the form `x |> f` into" *
        " the equivalent function call `f(x)`.\n\nNote that that this can lead to" *
        " semantic changes if `|>` has been overloaded or otherwise has a custom meaning!" *
        "\n\nYou can disable this behaviour by setting the `pipe_to_function_call` option" *
        " to `false`. Note that this option is `true` by default for Blue and YAS styles," *
        " meaning that you must explicitly opt out. Alternatively, you can use" *
        " `#! format: off` and `#! format: on` to disable formatting for specific" *
        " sections of code that use `|>`."
    ) maxlog = 1

    call_node = FST(Call, nspaces(s))
    childs = children(cst)

    # Identify the operator LHS (callee) and RHS (caller).
    lhs_idx = findfirst(n -> !JuliaSyntax.is_whitespace(n), childs)
    rhs_idx = findlast(n -> !JuliaSyntax.is_whitespace(n), childs)
    if isnothing(lhs_idx) || isnothing(rhs_idx) || lhs_idx >= rhs_idx
        error(
            "pipe operator with lhs_idx=$(lhs_idx) and rhs_idx=$(rhs_idx): should not happen",
        )
    end

    # Convert each node to an FST, storing references to the LHS and RHS nodes for later.
    lhs, rhs = nothing, nothing
    for (i, c) in enumerate(childs)
        if i == lhs_idx
            if kind(c) === K"parens" && haschildren(c) && !any(is_assignment, children(c))
                # If the lhs is a parenthesised expression, we can strip the parentheses.
                # For example
                #     (x) |> f
                # can just become f(x) rather than f((x)). However, we need to make sure
                # we don't do this for assignments, because
                #     (x = y) |> f
                # is not the same as f(x = y)!
                for pc in children(c)
                    if kind(pc) in KSet"( )" || JuliaSyntax.is_whitespace(pc)
                        s.offset += span(pc)
                    else
                        lhs = pretty(style, pc, s, ctx, lineage)
                    end
                end
            else
                lhs = pretty(style, c, s, ctx, lineage)
            end
        elseif i == rhs_idx
            rhs = pretty(style, c, s, ctx, lineage)
        else
            s.offset += span(c)
        end
    end

    # Handle the caller.
    #
    # Some things need to be wrapped in parens. We behave conservatively here and only opt
    # out of wrapping for the following callers:
    #
    #   - a plain identifier               arg |> f     -> f(arg)
    #   - a field access                   arg |> obj.f -> obj.f(arg)
    #   - something already parenthesised  arg |> (f)   -> (f)(arg)
    #   - a function call                  arg |> f()   -> f()(arg)
    #   - a parametrised type constructor  arg |> F{x}  -> F{x}(arg)
    #
    # There are two edge cases (of course there are).
    #
    # 1. For the function call case, we need to parenthesise a function call with a
    #    do-block:
    #
    #     arg |> f() do           (f() do
    #         g()          --->        g()
    #     end                     end)(arg)
    #
    # 2. For the identifier case, if it's a dotted operator, we need to store a flag,
    #    `is_dotted_operator`. This is because
    #
    #        arg .|> ! 
    #
    #    should become `.!(arg)` rather than `!.(arg)` which is a parse error.
    #    (Alternatively, (!).(arg) would work too, but looks uglier.)
    rhs_cst = childs[rhs_idx]
    is_dotted_operator = if kind(cst) === K"dotcall" && kind(rhs_cst) === K"Identifier"
        try
            k = JuliaSyntax.Kind(rhs.val)
            JuliaSyntax.is_operator(k) && !JuliaSyntax.is_word_operator(k)
        catch
            false
        end
    else
        false
    end
    caller_needs_parens = if kind(rhs_cst) in KSet"Identifier . parens curly"
        false
    elseif kind(rhs_cst) === K"call" && haschildren(rhs_cst)
        # In JuliaSyntax, infix operators are also parsed as `call`, so we need to really
        # check that it is a function call with parentheses.
        has_parens = any(n -> kind(n) === K"(", children(rhs_cst))
        has_do = any(n -> kind(n) === K"do", children(rhs_cst))
        if has_parens
            has_do
        else
            true # infix operator
        end
    else
        true
    end

    # Add a dot *before* the function if needed.
    if kind(cst) === K"dotcall" && is_dotted_operator
        add_node!(
            call_node,
            FST(PUNCTUATION, -1, rhs.startline, rhs.startline, "."),
            s;
            join_lines = true,
        )
    end

    # Add the function, parenthesising if needed.
    maybe_parenthesised_caller_node = if caller_needs_parens
        parens_fst = FST(Brackets, nspaces(s))
        add_node!(
            parens_fst,
            FST(PUNCTUATION, -1, rhs.startline, rhs.startline, "("),
            s;
            join_lines = true,
        )
        add_node!(parens_fst, Placeholder(0), s; join_lines = true)
        add_node!(parens_fst, rhs, s; join_lines = true)
        add_node!(parens_fst, Placeholder(0), s; join_lines = true)
        add_node!(
            parens_fst,
            FST(PUNCTUATION, -1, rhs.startline, rhs.startline, ")"),
            s;
            join_lines = true,
        )
        parens_fst
    else
        rhs
    end
    add_node!(call_node, maybe_parenthesised_caller_node, s; join_lines = true)

    # Add a dot *after* the function if needed.
    if kind(cst) === K"dotcall" && !is_dotted_operator
        add_node!(
            call_node,
            FST(PUNCTUATION, -1, rhs.startline, rhs.startline, "."),
            s;
            join_lines = true,
        )
    end

    # Handle the callee.
    nest =
        should_allow_nesting_call_args([cst[lhs_idx]], s.opts.disallow_single_arg_nesting)
    add_node!(
        call_node,
        FST(PUNCTUATION, -1, rhs.startline, rhs.startline, "("),
        s;
        join_lines = true,
    )
    if nest
        add_node!(call_node, Placeholder(0), s)
    end
    add_node!(call_node, lhs, s; join_lines = true)
    if nest
        add_node!(call_node, TrailingComma(), s)
        add_node!(call_node, Placeholder(0), s)
    end
    add_node!(
        call_node,
        FST(PUNCTUATION, -1, rhs.startline, rhs.startline, ")"),
        s;
        join_lines = true,
    )

    return call_node
end

function p_binaryopcall(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Binary, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    op_indices = source_operator_indices(cst)
    opkind = source_op_kind(s, cst)

    # Intercept piped function calls and construct a normal function call FST instead. NOTE:
    # If overloading `p_binaryopcall` for a custom style you will have to make sure to
    # include this logic!
    if opkind === K"|>" && s.opts.pipe_to_function_call && can_transform_syntax(s, false)
        # We purposely exclude one more case: `x .|> (f1, f2)`. This is a very weird Julia
        # quirk where you can broadcast over the _caller_ rather than the callee. There's no
        # equivalent way to express this in function call form, so we shouldn't try to
        # transform it.
        # See https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/647
        rhs_cst = childs[findlast(n -> !JuliaSyntax.is_whitespace(n), childs)]
        dotted_tuple = kind(cst) === K"dotcall" && kind(rhs_cst) === K"tuple"
        if !dotted_tuple
            return p_pipe_to_call(ds, cst, s, ctx, lineage)
        end
    end

    nonest = ctx.nonest || opkind === K":"

    nrhs = nest_rhs(cst, style)
    if nrhs
        t.nest_behavior = AlwaysNest
    end
    nest = (is_binaryop_nestable(style, cst) && !nonest) || nrhs
    if opkind === K"=>" && haschildren(cst)
        rhs_idx = findlast(n -> !JuliaSyntax.is_whitespace(n), childs)
        if !isnothing(rhs_idx) && is_str_or_cmd(childs[rhs_idx])
            nest = false
        end
    end

    # Catches e.g. `f(x) = x + 1`; but _not_ `let f(x) = x + 1; body; end` since expanding
    # that would lead to invalid Julia code, and also disable it if it's in a macro/Expr.
    is_short_func = defines_function(cst)
    is_expandable_short_func =
        is_short_func && !ctx.from_let && can_transform_syntax(s, true)
    standalone_binary_circuit = ctx.standalone_binary_circuit

    # For the lhs of a short-form function, we can't enable separate_kwargs_with_semicolon.
    # Find its index now.
    lhs_of_short_func_idx = if is_short_func
        findfirst(Shims.is_caller_in_function_def, childs)
    else
        nothing
    end

    lazy_op = is_lazy_op(opkind)
    # Check if expression is a lazy circuit. If it is, this does two things: first it causes
    # the indentation to be increased for subsequent lines -- for example
    #
    #    aaaaa ||        rather than      aaaaa ||
    #        bbbbb                        bbbbb
    #
    # Secondly if `short_circuit_to_if` is true, then this allows the expression to be
    # expanded to if/elseif/else.
    #
    # cf. https://github.com/JuliaEditorSupport/JuliaFormatter.jl/pull/224
    if lazy_op && standalone_binary_circuit
        if length(lineage) >= 2
            parent_node, _, is_assign = lineage[end-1]
            # Disable if the binary expression is "used" in a certain context --
            # for example
            #
            # parens      (a && b)
            # macrocall   @foo a && b
            # return      return a && b
            # while       while a && b  (see also #940)
            # if          if a && b
            # elseif      elseif a && b
            # ternary     a && b ? c : d
            if parent_node in KSet"parens macrocall return while if elseif ?" || is_assign
                standalone_binary_circuit = false
            end
        end
    end

    is_standalone_shortcircuit = lazy_op && standalone_binary_circuit
    t.metadata = Metadata(
        opkind,
        is_standalone_shortcircuit,
        is_standalone_shortcircuit && can_transform_syntax(s, true),
        is_expandable_short_func,
        is_assignment(cst) || defines_function(cst),
        false,
        false,
    )

    has_ws = false

    for (i, c) in enumerate(childs)
        if i > 1 && Shims.is_really_whitespace(c)
            has_ws = true
            break
        end
    end

    from_colon = ctx.from_colon
    from_typedef = ctx.from_typedef

    nospace = ctx.nospace
    if opkind === K":"
        nospace = true
        from_colon = true
    elseif opkind === K"::"
        nospace = true
    elseif is_short_func && opkind === K"="
        nospace = false
        has_ws = true
    elseif kind(cst) === K"comparison"
        nospace = false
    elseif opkind in KSet"in ∈ isa ."
        nospace = false
    elseif from_typedef && opkind in KSet"<: >:"
        if s.opts.whitespace_typedefs
            nospace = false
            has_ws = true
        else
            nospace = true
            has_ws = false
        end
    elseif ctx.from_ref || from_colon
        if s.opts.whitespace_ops_in_indices
            nospace = false
            has_ws = true
        else
            nospace = true
            has_ws = false
        end
    elseif from_colon
        nospace = true
    end
    nws = !nospace && has_ws ? 1 : 0

    has_dot = false
    if kind(cst) === K"dotcall"
        nospace = false
        nws = 1
        has_dot = true
    end

    nlws_count = 0
    after_op = false
    skip_until = 0
    for (i, c) in enumerate(childs)
        i <= skip_until && continue

        # Determine whether we can separate kwargs with a semicolon.
        can_separate_kwargs = if opkind === K"::"
            # Pass through to children, since `::` might be used in function definitions.
            ctx.can_separate_kwargs
        elseif is_short_func && i === lhs_of_short_func_idx
            # Not for the lhs of a function definition.
            false
        else
            # Everywhere else is fine.
            true
        end

        if kind(cst) === K"op=" && !isempty(op_indices) && i == first(op_indices)
            loc = cursor_loc(s)
            op_span = sum(span, childs[first(op_indices):last(op_indices)]; init = 0)
            val = getsrcval(s.doc, (s.offset):(s.offset+op_span-1))
            s.offset += op_span
            n = FST(OPERATOR, loc[2], loc[1], loc[1], val)
            n.metadata = Metadata(K"op=")
            if nws > 0 && i > 1
                add_node!(t, Whitespace(nws), s)
            end
            add_node!(t, n, s; join_lines = true)
            if nws > 0
                if nest
                    add_node!(t, Placeholder(nws), s)
                else
                    add_node!(t, Whitespace(nws), s)
                end
            end
            after_op = true
            skip_until = last(op_indices)
            continue
        end

        offset = s.offset
        n = pretty(
            style,
            c,
            s,
            newctx(
                ctx;
                standalone_binary_circuit = standalone_binary_circuit &&
                                            !(is_lazy_op(c) && kind(c) !== opkind),
                can_separate_kwargs = can_separate_kwargs,
                nonest = nonest,
                from_colon = from_colon,
            ),
            lineage,
        )

        is_dot = kind(c) === K"."
        is_op = i in op_indices && is_source_operator(s, c, offset)
        if is_op && n.typ === IDENTIFIER
            n.typ = OPERATOR
            n.metadata =
                Metadata(source_op_kind_from_offset(s, c, offset)::JuliaSyntax.Kind)
        end
        if is_dot && haschildren(c) && length(children(c)) == 2
            # [.]
            #   .
            #   <=
            ns = is_dot ? 1 : nws

            # Add whitespace before the operator, unless it's a dot in a dotted operator
            if ns > 0
                add_node!(t, Whitespace(ns), s)
            end
            add_node!(t, n, s; join_lines = true)
            # Add whitespace after the operator
            if ns > 0
                if nest
                    add_node!(t, Placeholder(ns), s)
                else
                    add_node!(t, Whitespace(ns), s)
                end
            end
            after_op = true
        elseif is_op && !haschildren(c)
            # there are some weird cases where we can assign an operator a value so that
            # the arguments are operators as well.
            #
            # a .* %
            ns = is_dot ? 1 : nws

            # Add whitespace before the operator, unless it's a dot in a dotted operator
            if ns > 0 && i > 1
                if kind(childs[i-1]) !== K"."  # Don't add space if previous was a dot
                    add_node!(t, Whitespace(ns), s)
                elseif kind(childs[i-1]) === K"." && haschildren(childs[i-1])  # Don't add space if previous was a dot
                    add_node!(t, Whitespace(ns), s)
                end
            end

            add_node!(t, n, s; join_lines = true)

            # Add whitespace after the operator
            if !is_dot && ns > 0
                if nest
                    add_node!(t, Placeholder(ns), s)
                else
                    add_node!(t, Whitespace(ns), s)
                end
            end

            after_op = true
        elseif JuliaSyntax.is_whitespace(c)
            add_node!(t, n, s; join_lines = true)
        else
            if (opkind === K":" && is_opcall(c) && !(kind(c) in KSet"parens ."))
                # Add parentheses around expressions on either side of a range. We manually
                # exclude field access to avoid parenthesising e.g. [1:a.b] -> [1:(a.b)].
                # TODO(penelopeysm): Add a config option for this parenthesisation (false
                # should preserve the original parens, true should add parens if there are
                # none).
                bracket_fst = FST(Brackets, nspaces(s))
                add_node!(
                    bracket_fst,
                    FST(PUNCTUATION, -1, n.startline, n.startline, "("),
                    s;
                    join_lines = true,
                )
                if after_op
                    add_node!(
                        bracket_fst,
                        n,
                        s;
                        join_lines = true,
                        override_join_lines_based_on_source = !nest,
                    )
                else
                    add_node!(bracket_fst, n, s; join_lines = true)
                end
                add_node!(
                    bracket_fst,
                    FST(PUNCTUATION, -1, n.startline, n.startline, ")"),
                    s;
                    join_lines = true,
                )
                add_node!(t, bracket_fst, s; join_lines = true)
            else
                if after_op
                    add_node!(
                        t,
                        n,
                        s;
                        join_lines = true,
                        override_join_lines_based_on_source = !nest,
                    )
                else
                    add_node!(t, n, s; join_lines = true)
                end
            end
        end

        if kind(c) === K"NewlineWs"
            nlws_count += 1
        end
    end

    if nest && (
        kind(cst) === K"op=" ||
        length(op_indices) == 1 ||
        (length(op_indices) == 2 && has_dot)
    )
        # for indent, will be converted to `indent` if needed
        insert!(t.nodes::Vector{FST}, length(t.nodes::Vector{FST}), Placeholder(0))
    end

    t
end

function p_whereopcall(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Where, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)

    childs = children(cst)
    where_idx = findfirst(c -> kind(c) === K"where" && !haschildren(c), childs)
    curly_ctx = if where_idx === nothing
        ctx.from_typedef
    else
        if !(ctx.from_typedef)
            any(c -> kind(c) in KSet"curly bracescat braces", childs[(where_idx+1):end])
        else
            true
        end
    end
    add_braces = s.opts.surround_whereop_typeparameters && !curly_ctx

    nws = s.opts.whitespace_typedefs ? 1 : 0

    after_where = false
    for (i, a) in enumerate(childs)
        if kind(a) === K"where" && !haschildren(a)
            add_node!(t, Whitespace(1), s)
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Whitespace(1), s)
            after_where = true
        elseif kind(a) === K"{" && nest
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Placeholder(0), s)
            s.indent += s.opts.indent
        elseif kind(a) === K"}" && nest
            add_node!(t, TrailingComma(), s)
            add_node!(t, Placeholder(0), s)
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            s.indent -= s.opts.indent
        elseif kind(a) === K","
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K"}")
                add_node!(t, Placeholder(nws), s)
            end
        elseif JuliaSyntax.is_whitespace(a)
            add_node!(t, pretty(style, a, s), s; join_lines = true)
        else
            n = pretty(style, a, s, newctx(ctx; from_typedef = after_where), lineage)
            if after_where && add_braces
                # Essentially, here we're doing the same thing as in p_braces, because we
                # want to make sure that it generates the same FST. This is another case
                # where it would be really useful to have an IR where we can make such
                # transformations prior to generating the FST.
                brace_fst = FST(Braces, nspaces(s))
                nest_braces =
                    should_allow_nesting_call_args([a], s.opts.disallow_single_arg_nesting)
                lbrace = FST(PUNCTUATION, -1, n.endline, n.endline, "{")
                add_node!(brace_fst, lbrace, s; join_lines = true)
                nest_braces && add_node!(brace_fst, Placeholder(0), s)
                add_node!(brace_fst, n, s; join_lines = true)
                nest_braces && add_node!(brace_fst, TrailingComma(), s)
                nest_braces && add_node!(brace_fst, Placeholder(0), s)
                rbrace = FST(PUNCTUATION, -1, n.endline, n.endline, "}")
                add_node!(brace_fst, rbrace, s; join_lines = true)
                add_node!(t, brace_fst, s; join_lines = true)
            else
                add_node!(t, n, s; join_lines = true)
            end
        end
    end

    t
end

function p_conditionalopcall(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Conditional, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        if kind(c) in KSet"? :" && !haschildren(c)
            add_node!(t, Whitespace(1), s)
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Placeholder(1), s)
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        end
    end

    t
end

function p_unaryopcall(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
    is_prefix::Bool,
)
    style = getstyle(ds)
    t = FST(Unary, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    first_idx = findfirst(n -> !JuliaSyntax.is_whitespace(n), childs)
    op_idx = source_unary_operator_index(is_prefix, cst, s)
    if isnothing(op_idx)
        op_idx = first_idx
    end
    opkind = isnothing(op_idx) ? op_kind(cst) : source_op_kind(s, cst)

    t.metadata = Metadata(opkind)

    for (i, c) in enumerate(childs)
        offset = s.offset
        if i > 1 && kind(c) === K"Whitespace"
            add_node!(t, Whitespace(1), s)
        end
        n = pretty(style, c, s, ctx, lineage)
        if i == op_idx && n.typ === IDENTIFIER
            k = source_op_kind_from_offset(s, c, offset)
            if !isnothing(k)
                n.typ = OPERATOR
                n.metadata = Metadata(k)
            end
        end
        add_node!(t, n, s; join_lines = true)
    end
    t
end

function p_curly(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Curly, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)

    nws = s.opts.whitespace_typedefs ? 1 : 0

    childs = children(cst)
    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, newctx(ctx; from_typedef = true), lineage)

        if kind(a) === K"{"
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            end
        elseif kind(a) === K"}"
            if nest
                add_node!(t, TrailingComma(), s)
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K","
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K"}")
                add_node!(t, Placeholder(nws), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

function p_call(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}};
    do_block_idx::Union{Int,Nothing} = nothing,
)
    style = getstyle(ds)
    t = FST(Call, nspaces(s))
    if !haschildren(cst)
        return t
    end

    # If `ctx.can_separate_kwargs` is false, we don't want to modify the semicolon in this
    # particular call expression; but we CAN re-enable it for its children. For example, in
    #
    #     function foo(
    #         a,
    #         b=goo(x, y=z)
    #     )
    #         body
    #     end
    #
    # we don't want to change the comma between `a` and `b`, but we can change the comma
    # between `x` and `y=z`. So we reset `can_separate_kwargs` to true for the children of
    # this call expression.
    can_separate_kwargs_for_this_call = ctx.can_separate_kwargs
    ctx = newctx(ctx; can_separate_kwargs = true)

    childs = children(cst)
    if !isnothing(do_block_idx)
        if !checkbounds(Bool, childs, do_block_idx) ||
           kind(childs[do_block_idx]) !== K"do" ||
           !haschildren(childs[do_block_idx])
            error("p_call called with an invalid do block index")
        end
        childs = childs[1:(do_block_idx-1)]
    end

    caller_idx = findfirst(n -> !JuliaSyntax.is_whitespace(n), childs)
    args = call_args(childs)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)

    for (i, a) in enumerate(childs)
        k = kind(a)
        if k === K"("
            n = pretty(style, a, s, ctx, lineage)
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            end
        elseif k === K")"
            n = pretty(style, a, s, ctx, lineage)
            if nest
                add_node!(t, TrailingComma(), s)
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif k === K","
            n = pretty(style, a, s, ctx, lineage)
            add_node!(t, n, s; join_lines = true)

            # figure out if we need to put a placeholder
            if has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, Placeholder(1), s)
            end
        elseif k == K"=" && haschildren(a)
            n = p_kw(style, a, s, ctx, lineage)
            add_node!(t, n, s; join_lines = true)
        else
            # If the caller is parenthesised (usually callable struct, but not necessarily),
            # avoid inserting placeholders after ( and before ), because that causes
            # JuliaSyntax@1.0.2 to parse it wrongly. Hopefully this will be fixed one day
            # https://github.com/JuliaLang/julia/issues/62124 but we have to keep it in
            # for now since it's already broken on Julia 1.12.6.
            ctx2 = if i == caller_idx && k === K"parens" && haschildren(a)
                newctx(ctx; is_parenthesised_caller = true)
            else
                ctx
            end
            n = pretty(style, a, s, ctx2, lineage)
            add_node!(t, n, s; join_lines = true)
        end
    end

    if (
        s.opts.separate_kwargs_with_semicolon &&
        can_separate_kwargs_for_this_call &&
        can_transform_syntax(s, false)
    )
        separate_kwargs_with_semicolon!(t)
    end

    t
end

function p_parens(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Brackets, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = if length(args) > 0
        arg = args[1]
        if is_block(arg, style) || (
            # this branch covers something like (BLOCK for x in y)
            kind(arg) === K"generator" && first_nontrivial_child_is_block(arg, style)
        )
            t.nest_behavior = AlwaysNest
        end
        if !ctx.nonest && !s.opts.disallow_single_arg_nesting
            !is_iterable(arg)
        else
            false
        end
    else
        false
    end

    # This is a workaround for 
    # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1114
    # https://github.com/JuliaLang/julia/issues/62124
    #
    # For a construct like
    #
    #     function (expr)(args...) [where S [where T ...]]
    #         body
    #     end
    #
    # we can't put newlines around `expr` as that causes JuliaSyntax to
    # parse the resulting code incorrectly.
    #
    # The case we want to catch is K"function" [-> K"where"]* -> K"call" -> K"parens"
    function is_from_function_def(lineage)
        length(lineage) >= 3 || return false
        lineage[end][1] === K"parens" || return false
        lineage[end-1][1] === K"call" || return false
        # any number of `where`s
        i = length(lineage) - 2
        while i > 0 && lineage[i][1] === K"where"
            i -= 1
        end
        return i > 0 && lineage[i][1] === K"function"
    end
    disable_nesting = (ctx.is_parenthesised_caller && is_from_function_def(lineage))
    nest = nest && !disable_nesting
    # turn off the is_parenthesised_caller flag so that it's not propagated to children.
    ctx = newctx(ctx; is_parenthesised_caller = false)

    for c in children(cst)
        if kind(c) === K"("
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            end
        elseif kind(c) === K")"
            if nest
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        elseif kind(c) === K"block"
            add_node!(
                t,
                pretty(style, c, s, newctx(ctx; from_quote = true), lineage),
                s;
                join_lines = true,
            )
        elseif is_opcall(c)
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        end
    end

    t
end

function p_tupleblock(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(TupleBlock, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)

    childs = children(cst)
    for (i, a) in enumerate(childs)
        n = if kind(a) === K"=" && haschildren(a)
            p_kw(style, a, s, ctx, lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end
        if kind(a) === K"("
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            end
        elseif kind(a) === K")"
            if nest
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) in KSet", ;"
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

function p_tuple(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(TupleN, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    allow_nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)

    childs = children(cst)
    for (i, a) in enumerate(childs)
        n = if kind(a) === K"=" && haschildren(a)
            p_kw(style, a, s, ctx, lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end

        if kind(a) === K"("
            add_node!(t, n, s; join_lines = true)
            if allow_nest
                add_node!(t, Placeholder(0), s)
            end
        elseif kind(a) === K")"
            # An odd case but this could occur if there are no keyword arguments.
            # In which case ";," is invalid syntax.
            #
            # no trailing comma since (arg) is semantically different from (arg,) !!!
            if allow_nest
                if t[end].typ !== SEMICOLON && length(args) > 1
                    add_node!(t, TrailingComma(), s)
                end
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) in KSet", ;"
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

function p_braces(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Braces, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)

    nws = ctx.from_typedef && !s.opts.whitespace_typedefs ? 0 : 1

    childs = children(cst)
    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)

        if kind(a) === K"{"
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            end
        elseif kind(a) === K"}"
            if nest
                add_node!(t, TrailingComma(), s)
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K","
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K"}")
                add_node!(t, Placeholder(nws), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

function p_bracescat(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(BracesCat, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)

    nws = ctx.from_typedef && !s.opts.whitespace_typedefs ? 0 : 1
    childs = children(cst)

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)

        if kind(a) === K"{"
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
            end
        elseif kind(a) === K"}"
            if nest
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K";"
            if has_more_args_to_come(childs, i + 1, K"}")
                add_node!(t, n, s; join_lines = true)
                add_node!(t, Placeholder(nws), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

function p_vect(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Vect, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)

    childs = children(cst)
    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)

        if kind(a) === K"["
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
            end
        elseif kind(a) === K"]"
            if nest
                add_node!(t, TrailingComma(), s)
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K","
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K"]")
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

function p_comprehension(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Comprehension, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)

    opening_brace_idx = findfirst(n -> kind(n) === K"[", childs)
    body_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, opening_brace_idx + 1)
    body_arg = childs[body_idx]

    if is_block(body_arg, style) || (
        # this branch covers something like [BLOCK for x in y]
        kind(body_arg) === K"generator" && first_nontrivial_child_is_block(body_arg, style)
    )
        t.nest_behavior = AlwaysNest
    end

    for c in childs
        n = pretty(style, c, s, ctx, lineage)
        if kind(c) === K"["
            add_node!(t, n, s; join_lines = true)
            add_node!(t, Placeholder(0), s)
        elseif kind(c) === K"]"
            add_node!(t, Placeholder(0), s)
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(t, n, s; join_lines = true)
        end
    end

    t
end

function p_typedcomprehension(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_comprehension(ds, cst, s, ctx, lineage)
    t.typ = TypedComprehension
    t
end

function p_parameters(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Parameters, nspaces(s))
    if !haschildren(cst)
        return t
    end

    nws = ctx.from_typedef && !s.opts.whitespace_typedefs ? 0 : 1

    childs = children(cst)
    for (i, a) in enumerate(childs)
        n = if kind(a) === K"=" && haschildren(a)
            p_kw(style, a, s, ctx, lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end

        if kind(a) in KSet", ;"
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K")")
                add_node!(t, Placeholder(nws), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

_maybe_linebreak_after_import_colon(::AbstractStyle) = true
function p_import(
    ds::AbstractStyle,
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
        if kind(a) in KSet"import using"
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        elseif kind(a) === K":" && haschildren(a)
            nodes = children(a)
            for n in nodes
                add_node!(t, pretty(style, n, s, ctx, lineage), s; join_lines = true)
                if kind(n) in KSet"import using"
                    add_node!(t, Whitespace(1), s)
                elseif kind(n) === K","
                    add_node!(t, Placeholder(1), s)
                elseif kind(n) === K":"
                    if _maybe_linebreak_after_import_colon(style)
                        # true for most but false for YAS
                        add_node!(t, Placeholder(1), s)
                    else
                        add_node!(t, Whitespace(1), s)
                    end
                end
            end
        elseif kind(a) in KSet", :"
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Placeholder(1), s)
        else
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
        end
    end
    t
end

function p_export(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Export, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for a in children(cst)
        add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
        if kind(a) in KSet"export public"
            add_node!(t, Whitespace(1), s)
        elseif kind(a) === K","
            add_node!(t, Placeholder(1), s)
        end
    end
    t
end

function p_public(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_export(ds, cst, s, ctx, lineage)
    t.typ = Public
    t
end

function p_using(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_import(ds, cst, s, ctx, lineage)
    t.typ = Using
    t
end

function p_importpath(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(ImportPath, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for a in children(cst)
        n = pretty(style, a, s, ctx, lineage)
        add_node!(t, n, s; join_lines = true)
    end
    t
end

function p_as(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(As, nspaces(s))
    if !haschildren(cst)
        return t
    end

    for c in children(cst)
        n = pretty(style, c, s, ctx, lineage)
        if kind(c) === K"as"
            add_node!(t, Whitespace(1), s)
            add_node!(t, n, s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        else
            add_node!(t, n, s; join_lines = true)
        end
    end

    t
end

function p_ref(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(RefN, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = length(args) > 1

    childs = children(cst)
    for (i, a) in enumerate(childs)
        if kind(a) === K"]"
            if nest
                add_node!(t, TrailingComma(), s)
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
        elseif kind(a) === K"["
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
            end
        elseif kind(a) === K","
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K"]")
                add_node!(t, Placeholder(1), s)
            end
        elseif is_opcall(a)
            n = pretty(style, a, s, newctx(ctx; from_ref = true, nonest = true), lineage)
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
        end
    end
    t
end

function p_vcat(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Vcat, nspaces(s))
    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest = should_allow_nesting_call_args(args, s.opts.disallow_single_arg_nesting)
    childs = children(cst)
    opening_idx = findfirst(n -> kind(n) === K"[", childs)::Int
    closing_idx = findlast(n -> kind(n) === K"]", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, opening_idx + 1)
    last_arg_idx = findprev(n -> !JuliaSyntax.is_whitespace(n), childs, closing_idx - 1)

    for (i, a) in enumerate(childs)
        n = if i == last_arg_idx
            ctx2 = newctx(ctx; is_last_ncat_or_nrow_arg = true)
            pretty(style, a, s, ctx2, lineage)
        else
            pretty(style, a, s)
        end

        diff_line = t.endline != t.startline
        # If arguments are on different lines then always nest
        if diff_line
            t.nest_behavior = AlwaysNest
        end

        if kind(a) === K"["
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            end
        elseif kind(a) === K"]"
            if nest
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif JuliaSyntax.is_whitespace(a)
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K";"
            add_node!(t, n, s; join_lines = true)
        else
            if !isnothing(first_arg_idx) && i > first_arg_idx
                # Remove newline from **inside** the last argument if present. That newline
                # might be semantically significant, so this seems dangerous.
                #
                # However, we are going to add a Placeholder back right after this, and
                # because the presence of a newline indicates that there was one in the
                # source, `diff_line` above will be true, and we can guarantee that the
                # Placeholder will eventually be converted into a newline.
                #
                # Using the Placeholder over the Newline ensures that subsequent nodes in
                # the FST will be indented correctly.
                #
                # This is 100% a hack, but undoing this requires rewriting the structure of
                # the CST so that the newlines between arguments are part of the top-level
                # structure rather than being buried inside the arguments themselves.
                if is_prev_newline(t)
                    remove_prev_newline!(t)
                end
                add_node!(t, Placeholder(1), s)
            end

            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

function p_typedvcat(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_vcat(ds, cst, s, ctx, lineage)
    t.typ = TypedVcat
    t
end

"""
    is_newline_after_2semicolons(cst::JuliaSyntax.GreenNode, i::Int)

Detect if child node `i` of `cst` is a newline that follows two semicolons. For example,
this will detect the newline in constructs such as

    [a b;;
     c d]
"""
function is_newline_after_2semicolons(cst::JuliaSyntax.GreenNode, i::Int)
    return i >= 3 &&
           kind(cst[i]) === K"NewlineWs" &&
           kind(cst[i-1]) === K";" &&
           kind(cst[i-2]) === K";"
end

"""
    hcat_allow_boundary_newlines(style::AbstractStyle)

Determine whether newlines are allowed immediately after the opening `[` and immediately
before the closing `]` of an hcat node.

Most styles allow this, but YAS doesn't (and SciML too, since it dispatches to YAS).

In principle this can be generalised to vcat and ncat as well; I just haven't done so.
"""
hcat_allow_boundary_newlines(::AbstractStyle) = true

function p_hcat(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Hcat, nspaces(s))
    if !haschildren(cst)
        return t
    end
    childs = children(cst)

    # Identify the first argument inside the square brackets
    idx = findfirst(n -> kind(n) === K"[", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    # Handling newlines in hcat nodes
    # -------------------------------
    #
    # hcat is very sensitive towards newlines. There are several potential separators that
    # *semantically*, lead to horizontal concatenation of the arguments:
    #
    #  (A) spaces, e.g. `[1 2 3]`
    #  (B) double semicolon, e.g. `[1;; 2;; 3;; 4]`
    #  (C) double semicolon followed by newline, e.g. `[1;;\n 2;;\n 3;;\n 4]`
    #
    # However, *syntactically*, an expression is only parsed as a `hcat` if it contains **at
    # least one** space separator (i.e., (A)). That means that 
    #
    #    `[1 2 3]`         -> parsed as hcat
    #    `[1 2;;\n3]`      -> parsed as hcat
    #
    # but anything _without_ space separators is parsed as `ncat`, even if semantically
    # it means the same thing as `hcat`.
    #
    #    `[1;; 2;; 3]`     -> parsed as ncat
    #    `[1;;\n2;;\n3]`   -> parsed as ncat
    #
    # Now, the catch (see the Julia docs:)
    # https://docs.julialang.org/en/v1/manual/arrays/#man-array-concatenation)
    # is that (A) and (B) *cannot* be mixed, but (A) and (C) can be mixed.
    #
    # Given that in this function we *must* have at least one (A) separator, this implies
    # that if we have a (C) ";;\\n", we *must not* remove the newline to make a (B) ";;".
    # Otherwise, this would lead to a mixture of (A) and (B), which is disallowed.
    #
    # Furthermore, it's otherwise illegal to have a newline separator between hcat
    # arguments. The meaning of newline is 'vertical concatenation', and any vertical concat
    # would turn the hcat node into ncat, so a hcat node itself can't have newline
    # separators. This implies that we *must not* add newline separators on our own accord
    # as that would change the semantics.
    #
    # The only other place where newlines are allowed to be present are after the opening
    # `[` and before the closing `]`. Let's call these 'boundary newlines'. We are allowed
    # to decide whether to place boundary newlines. In other words, we can safely insert
    # Placeholder nodes at these positions.

    prev_comment_was_dropped = false
    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)
        if kind(a) === K"["
            add_node!(t, n, s; join_lines = true)
            if hcat_allow_boundary_newlines(style)
                add_node!(t, Placeholder(0), s)
            end
        elseif kind(a) === K"]"
            if !hcat_allow_boundary_newlines(style)
                # Always join ] to the last argument: remove the newline from the last
                # argument if it exists
                if is_prev_newline(t)
                    remove_prev_newline!(t)
                end
                add_node!(
                    t,
                    n,
                    s;
                    join_lines = true,
                    override_join_lines_based_on_source = true,
                )
            else
                # Let the nesting algo decide whether to insert a newline
                add_node!(t, Placeholder(0), s)
                add_node!(t, n, s; join_lines = true)
            end
        elseif kind(a) === K";"
            add_node!(t, n, s; join_lines = true)
        elseif JuliaSyntax.is_whitespace(a)
            if kind(a) === K"Comment"
                prev_comment_was_dropped = !add_hasheq_comment!(t, n, s)
            elseif is_newline_after_2semicolons(cst, i)
                # See above: we cannot convert ';;\n' to ';;'
                add_node!(t, Newline(; nest_behavior = AlwaysNest), s)
                # Additionally, because the contents of the hcat will be on different lines
                # and there's no way to later un-nest it without breaking semantics, we can
                # set the nest behaviour of the entire hcat to AlwaysNest. This means that
                # later on, `n_tuple!` will insert newlines after the `[` and before the
                # `].`
                t.nest_behavior = AlwaysNest
                prev_comment_was_dropped = false
            elseif !(kind(cst[i+1]) in KSet"; ] Comment") && !(kind(cst[i-1]) in KSet"; [")
                # Whitespace is generally important to retain, because it can be a separator
                # -- but we should omit it in a few cases:
                # 1. If it's followed by / before a ';;' separator, since it's not needed.
                # 2. Directly after the opening bracket.
                # 3. Directly before the closing bracket.
                #
                # There's also some special logic for comments, because the current way that
                # JuliaFormatter deals with comments is crazily hacky.
                if !isnothing(first_arg_idx) &&
                   i < first_arg_idx &&
                   prev_comment_was_dropped
                    # Before the first argument, after a dropped regular # comment.
                    # Suppress whitespace so NOTCODE gap detection can reconstruct
                    # the comment at the parent level.
                elseif prev_comment_was_dropped
                    # After a dropped regular # comment, past the first argument.
                    # Remove the preceding forced NEWLINE (e.g. from ;;) so that
                    # add_node!'s gap detection is not short-circuited by
                    # is_prev_newline, and can insert NOTCODE for the comment.
                    if is_prev_newline(t)
                        remove_prev_newline!(t)
                    end
                else
                    add_node!(t, Whitespace(1), s)
                end
                prev_comment_was_dropped = false
            else
                prev_comment_was_dropped = false
            end
        elseif i == 1 && kind(a) !== K"["
            # Type preceding the `[`, e.g. `T` in `T[1 2 3]`.
            add_node!(t, n, s; join_lines = true)
        else
            # Argument that is being hcatted. Annoyingly, the CST doesn't always place
            # whitespace between hcat arguments (see e.g. `[1:2 3:4 5:6]`), so sometimes we
            # have to manually add some ourselves.
            # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1038
            if !JuliaSyntax.is_whitespace(childs[i-1]) && kind(childs[i-1]) !== K"["
                add_node!(t, Whitespace(1), s)
            end
            # If this is the first argument, and we don't want to allow boundary newlines,
            # then we have to force-join it to the opening [, even if the source had a
            # newline after it.
            override_join_lines =
                (i == first_arg_idx) && !hcat_allow_boundary_newlines(style)
            add_node!(
                t,
                n,
                s;
                join_lines = true,
                override_join_lines_based_on_source = override_join_lines,
            )
        end
    end
    t
end

function p_typedhcat(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_hcat(ds, cst, s, ctx, lineage)
    t.typ = TypedHcat
    t
end

function p_ncat(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    # Unfortunately `ncat` nodes cover a diverse range of syntax and the way the parser
    # groups it can be somewhat inconsistent at times.
    #
    # It's very lucky that we can simply delegate to `p_vcat` and have it Just Work; but
    # it's still worth documenting and understanding this. The main reason why `p_vcat`
    # handles it correctly is because the main separator is a sequence of semicolons (see
    # (1)), and newlines inserted after those separators have no effect on the semantics.
    # This is the same as for a vcat node which has single semicolons as separators.
    #
    # (1) In general, arguments to `ncat` are separated by 2 or more semicolons. The 'main'
    #     separator is the longest contiguous sequence of semicolons.
    #
    #        `[1;; 2]` is ncat with main separator ';;'
    #                           and arguments `1` and `2`
    #
    #        `[1; 2;; 3; 4]` is ncat with main separator ';;'
    #                                 and arguments `1; 2` and `3; 4`
    #
    #        `[1; 2;; 3;;; 4]` is ncat with main separator ';;;'
    #                                   and arguments `1; 2;; 3` and `4`
    #
    # (2) When the arguments don't contain semicolons, they are placed at the top level of
    #     the `ncat` node. The semicolon separators that follow them are also placed at the
    #     top level of the `ncat` node.
    #
    # (3) When the arguments themselves contain semicolons, they are further grouped into `nrow`
    #     nodes. In the above examples, the arguments `1; 2`, `3; 4`, and `1; 2;; 3` are all
    #     parsed as `nrow` nodes.
    #
    # (4) Main separators that follow `nrow` nodes are placed *inside* the `nrow` node, NOT
    #     at the top level of the `ncat` node.
    #
    # (5) When `nrow` nodes contain different *levels* of semicolons, they themselves will
    #     contain `nrow` nodes. Just like for `ncat` nodes, the 'main' separator for the
    #     `nrow` node will be the longest contiguous sequence of semicolons. In the above
    #     examples, the `nrow` node `1; 2;; 3` has main separator ';;' and arguments `1; 2`
    #     `3`.
    t = p_vcat(ds, cst, s, ctx, lineage)
    t.typ = Ncat
    return t
end

function p_typedncat(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_ncat(ds, cst, s, ctx, lineage)
    t.typ = TypedNcat
    t
end

"""
    is_semantically_important_newline

Checks whether the `i`-th child of `row_cst` is a newline that is semantically important.
See comment in `p_row` for details.
"""
function is_semantically_important_newline(
    row_cst::JuliaSyntax.GreenNode,
    i::Int,
    is_last_arg_of_parent::Bool,
)
    kind(row_cst[i]) === K"NewlineWs" || return false
    n = length(children(row_cst))
    # Start of the row - not important
    i == 1 && return false
    # A newline is not important if it's adjacent to a comment and all the children
    # between the comment and the boundary of the row (start or end) are whitespace.
    #
    # Trailing comment case: all children after this newline are whitespace, and at least
    # one is a comment. Example: `3 4\n # bar\n` — the newline before `# bar` is not a row
    # separator. We don't need to include it.
    if all(j -> JuliaSyntax.is_whitespace(row_cst[j]), (i+1):n) &&
       any(j -> kind(row_cst[j]) === K"Comment", (i+1):n)
        return false
    end
    # Leading comment case: all children before this newline are whitespace, and at least
    # one is a comment. Example: `\n # foo\n 1 2` — the newline after `# foo` is not a row
    # separator. We can drop all newlines after the comment, because the insertion of the
    # newline after the comment is handled by the NOTCODE mechanism later on.
    if all(j -> JuliaSyntax.is_whitespace(row_cst[j]), 1:(i-1)) &&
       any(j -> kind(row_cst[j]) === K"Comment", 1:(i-1))
        return false
    end
    # End of the row -- might be important
    i == n && return (!is_last_arg_of_parent && kind(row_cst[i-1]) !== K";")
    # Otherwise it's important
    return true
end

# `nrow` and `row` nodes both delegate to this function, and the underlying logic is the
# same, but newlines need to be handled differently, which motivates the `ctx.from_nrow`
# and `ctx.is_last_ncat_or_nrow_arg` flags.
#
# There are two kinds of newlines:
#
#  - Those that are semantically *necessary*, because they are used to indicate vertical
#    concatenation. These can be:
#
#    (1) Newlines in the middle of the row: [1\n2;; 3\n4]
#    (2) Newlines at the end of a row: [1 2 3\n4 5 6]. In general, all newlines at the end
#        of a row are considered semantically important, with the exceptions listed below.
#    (3) `hcat` or `row` node that contains at least one space separator. For example:
#        [1 2 ;;\n 3 4] (which is a hcat) or [1 2 ;;\n 3 4 ;;; 5 6 7 8] (which is a row
#        inside an ncat).
#
#  - Those that are semantically *unnecessary*. These could be:
#
#    (4) Newlines at the start of the row, e.g. [\n1 2;; 3 4].
#    (5) Newlines at the end of the row but preceded by a semicolon, e.g. [1; 2;;;\n 3; 4].
#    (6) Newlines at the end of the row but before the closing brace, e.g. [1 2;; 3 4\n].
#
# The annoying thing about JuliaSyntax's parser is that all the newlines are placed inside
# the child nodes rather than the parent nodes. For example, in the last example
#
#     [1 2;; 3 4\n]
#
# the newline is a child of the last row, rather than a child of the ncat. (If it were
# the latter, then this would be trivial to handle since we could just check if it's the
# last child before the closing brace!) This means that we have to thread this information
# into each recursive pretty() call to tell us whether we are allowed to remove the newline
# or not.
function p_row(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    is_last_arg_of_parent = ctx.is_last_ncat_or_nrow_arg

    style = getstyle(ds)
    t = FST(Row, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    first_arg_idx = findfirst(n -> !JuliaSyntax.is_whitespace(n), childs)
    last_arg_idx = findlast(n -> !JuliaSyntax.is_whitespace(n), childs)

    # To detect the final newline i.e. (6) above, we need to handle two cases:
    #
    # (a) Either the newline is part of this node, in which case it will be the last child
    #     of this node.
    # (b) Or this node will have an nrow/row child that ends with a newline.

    for (i, a) in enumerate(childs)
        nonest = is_opcall(a)
        # Threading is_last_ncat_or_nrow_arg through here handles case (b).
        is_last_ncat_or_nrow_arg =
            is_last_arg_of_parent && i == last_arg_idx && kind(a) in KSet"nrow row"
        n = pretty(
            style,
            a,
            s,
            newctx(
                ctx;
                nonest = nonest,
                is_last_ncat_or_nrow_arg = is_last_ncat_or_nrow_arg,
            ),
            lineage,
        )
        if kind(a) === K";"
            add_node!(t, n, s; join_lines = true)
        elseif JuliaSyntax.is_whitespace(a)
            # is_semantically_important_newline handles case (a)
            if is_semantically_important_newline(cst, i, is_last_arg_of_parent)
                # Must force this newline!
                add_node!(t, Newline(; nest_behavior = AlwaysNest), s)
            else
                add_node!(t, n, s; join_lines = true)
            end
        else
            if !isnothing(first_arg_idx) && i > first_arg_idx && !is_prev_newline(t)
                # Insert whitespace before starting a new argument
                add_node!(t, Whitespace(1), s; join_lines = true)
            end
            add_node!(t, n, s; join_lines = true)
        end
    end

    # Prevent the Row *and* its child elements from being nested, unless any of them NEED
    # to be nested. This is very subtle!
    #
    # The problem with unconditionally putting NeverNest is that it actually gets propagated
    # to the children, so if a parent node has NeverNest the children can't nest either,
    # even if the children are set to AlwaysNest. (See the opening lines of `nest!` in
    # src/styles/default/nest.jl.) This can change the meaning of things inside the row's
    # elements if they don't get nested. See
    # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1168
    #
    # This behaviour of NeverNest is arguably too aggressive, but apparently it is intended.
    # For example, changing that breaks the `align_...` series of options, so we can't
    # really change that without introducing other regressions.
    #
    # The alternative option is to never put NeverNest, just allowing its descendants to
    # nest as they please. The issue with this is that it means that array elements like
    # `f(1, 2)` might end up being nested, which is really ugly.
    if !any_descendant(must_nest, t)
        t.nest_behavior = NeverNest
    end
    t
end

function p_nrow(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_row(ds, cst, s, newctx(ctx; from_nrow = true), lineage)
    t.typ = NRow
    t
end

function p_generator(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Generator, nspaces(s))
    JuliaSyntax.is_leaf(cst) && return t

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
            # for keyword can only be on the following line
            # if this expression is within an iterable expression
            if kind(a) === K"for" && from_iterable
                add_node!(t, Placeholder(1), s)
            else
                add_node!(t, Whitespace(1), s)
            end

            add_node!(t, n, s; join_lines = true)
            add_node!(t, Placeholder(1), s)
        elseif kind(a) === K","
            add_node!(t, n, s; join_lines = true)
            if has_more_args_to_come(childs, i + 1, K")")
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
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_generator(ds, cst, s, ctx, lineage)
    t.typ = Filter
    t
end
