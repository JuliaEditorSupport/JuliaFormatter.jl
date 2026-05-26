@kwdef struct PrettyContext
    nospace::Bool = false
    nonest::Bool = false
    standalone_binary_circuit::Bool = true
    from_typedef::Bool = false
    from_let::Bool = false
    from_ref::Bool = false
    from_colon::Bool = false
    from_for::Bool = false
    ignore_single_line::Bool = false
    from_quote::Bool = false
    join_body::Bool = false
    from_module::Bool = false
    from_docstring::Bool = false
    can_separate_kwargs::Bool = true
end

function newctx(s::PrettyContext; kwargs...)
    fields = fieldnames(PrettyContext)
    values = map(field -> get(kwargs, field, getfield(s, field)), fields)
    PrettyContext(values...)
end

function source_kind(s::State, cst::JuliaSyntax.GreenNode, offset::Integer)
    span(cst) == 0 && return nothing
    offset = Int(offset)
    n = Int(span(cst))
    val = getsrcval(s.doc, offset:(offset+n-1))
    try
        return JuliaSyntax.Kind(val)
    catch
        return nothing
    end
end

# JuliaSyntax v1 can encode source operators as Identifier leaves in call
# forms, e.g. `a + b`, `x .+ y`, `+(x)`, and `>=(x)`. The parent call flags
# describe the shape, but the leaf itself is not `is_operator`, and the exact
# operator kind is only recoverable from the source span.
function source_operator_kind(s::State, cst::JuliaSyntax.GreenNode, offset::Integer)
    if JuliaSyntax.is_operator(cst) && !haschildren(cst)
        return kind(cst)
    elseif kind(cst) === K"Identifier" && !haschildren(cst)
        k = source_kind(s, cst, offset)
        if !isnothing(k) && JuliaSyntax.is_operator(k)
            return k
        end
    end
    return nothing
end

function is_source_operator(s::State, cst::JuliaSyntax.GreenNode, offset::Integer)
    !isnothing(source_operator_kind(s, cst, offset))
end

function source_prefix_operator_index(cst::JuliaSyntax.GreenNode, s::State)
    kind(cst) in KSet"call dotcall" && haschildren(cst) || return nothing
    childs = children(cst)
    args = findall(n -> !JuliaSyntax.is_whitespace(n), childs)
    isempty(args) && return nothing

    op_arg =
        if kind(cst) === K"dotcall" &&
           length(args) >= 2 &&
           kind(childs[args[1]]) === K"." &&
           !haschildren(childs[args[1]])
            args[2]
        else
            args[1]
        end
    offset = s.offset + sum(span, childs[1:(op_arg-1)]; init = 0)
    return is_source_operator(s, childs[op_arg], offset) ? op_arg : nothing
end

function source_operator_indices(cst::JuliaSyntax.GreenNode)
    haschildren(cst) || return Int[]

    childs = children(cst)
    args = findall(n -> !JuliaSyntax.is_whitespace(n), childs)
    isempty(args) && return Int[]

    if kind(cst) === K"op="
        length(args) < 4 && return Int[]
        return args[2:(end-1)]
    elseif kind(cst) === K"comparison"
        length(args) < 3 && return Int[]
        return args[2:2:(end-1)]
    elseif is_short_function_def(cst)
        length(args) < 3 && return Int[]
        return Int[args[2]]
    elseif JuliaSyntax.is_operator(cst)
        length(args) < 3 && return Int[]
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
        k = source_operator_kind(s, c, offset)
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
    kind(cst) in KSet"call dotcall" && haschildren(cst) || return nothing
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
        p_quotenode(style, node, s, ctx, lineage)
    elseif k === K"quote" && haschildren(node)
        p_quote(style, node, s, ctx, lineage)
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
        p_invisbrackets(style, node, s, ctx, lineage)
    elseif k === K"curly"
        p_curly(style, node, s, ctx, lineage)
    elseif is_macrostr(node)
        p_macrostr(style, node, s, ctx, lineage)
    elseif k === K"doc"
        p_globalrefdoc(style, node, s, ctx, lineage)
    elseif k === K"macrocall"
        p_macrocall(style, node, s, ctx, lineage)
    elseif k === K"where"
        p_whereopcall(style, node, s, ctx, lineage)
    elseif k === K"?" && haschildren(node)
        p_conditionalopcall(style, node, s, ctx, lineage)
    # Example: `map(xs) do x; x + 1; end` is a call node with a do child.
    elseif !isnothing(do_block_idx)
        p_do_call(style, node, s, ctx, lineage, do_block_idx)
    # Example: `+(x)` parses as a prefix-op call.
    elseif JuliaSyntax.is_prefix_op_call(node)
        p_unaryopcall(style, node, s, ctx, lineage)
    elseif is_binary(node)
        p_binaryopcall(style, node, s, ctx, lineage)
    elseif is_chain(node)
        p_chainopcall(style, node, s, ctx, lineage)
    elseif is_unary(node)
        p_unaryopcall(style, node, s, ctx, lineage)
    elseif is_func_call(node)
        p_call(style, node, s, ctx, lineage)
    elseif k === K"comparison"
        p_comparison(style, node, s, ctx, lineage)
    elseif JuliaSyntax.is_operator(node) && haschildren(node)
        p_binaryopcall(style, node, s, ctx, lineage)
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
    if same_line && startswith(val, "#=") && endswith(val, "=#")
        s.offset += span(cst)
        return FST(HASHEQCOMMENT, loc[2], loc[1], loc[1], val)
    end
    s.offset += span(cst)
    FST(NONE, loc[2], loc[1], loc[1], "")
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
    t.metadata = Metadata(kind(cst), JuliaSyntax.is_dotted(cst))
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
    loc2 = cursor_loc(s, s.offset+span(cst)-1)

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

    t = FST(StringN, loc[2] - 1)
    t.line_offset = loc[2]

    lines = split(val, "\n")
    sidx = loc[2]
    for l in lines[2:end]
        fc = findfirst(c -> !isspace(c), l)
        if !isnothing(fc)
            sidx = min(sidx, fc)
        end
    end

    for (i, l) in enumerate(lines)
        ln = startline + i - 1
        l = i == 1 ? l : l[sidx:end]
        n = FST(LITERAL, ln, ln, sidx - 1, length(l), l, (), AllowNest, 0, -1, nothing)
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
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(MacroCall, nspaces(s))

    if !haschildren(cst)
        return t
    end

    args = get_args(cst)
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )
    childs = children(cst)

    has_closer = is_closer(childs[end])
    is_macroblock = !has_closer

    if is_macroblock
        t.typ = MacroBlock
    end

    ctx = newctx(ctx; can_separate_kwargs = false)
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
            if needs_placeholder(childs, i + 1, K")")
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
        if is_ws(a)
            s.offset += span(a)
            continue
        end
        n = pretty(style, a, s, ctx, lineage)

        if from_quote && !single_line
            if kind(a) in KSet"; ) ("
                add_node!(t, n, s; join_lines = true)
            elseif kind(a) === K","
                add_node!(t, n, s; join_lines = true)
                if needs_placeholder(childs, i + 1, K")")
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
            if kind(a) in KSet", ;"
                add_node!(t, n, s; join_lines = true)
                if needs_placeholder(childs, i+1, K")")
                    add_node!(t, Placeholder(1), s)
                end
            else
                add_node!(t, n, s; join_lines = true)
            end
        else
            if kind(a) === K","
                add_node!(t, n, s; join_lines = true)
                if join_body && needs_placeholder(childs, i + 1, K")")
                    add_node!(t, Placeholder(1), s)
                end
            elseif kind(a) === K";"
                add_node!(t, n, s; join_lines = true)
            elseif join_body
                add_node!(t, n, s; join_lines = true)
            else
                add_node!(t, n, s; max_padding = 0)
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
        if is_ws(a)
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
            if s.opts.always_use_return
                prepend_return!(n, s)
            end
            add_node!(t, n, s; max_padding = s.opts.indent)
            s.indent -= s.opts.indent
        elseif is_func_call(c)
            n = pretty(style, c, s, newctx(ctx; can_separate_kwargs = false), lineage)
            add_node!(t, n, s; join_lines = true)
        else
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
        end
    end
    t.metadata = Metadata(kind(cst), false, false, false, false, true, false)
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
            if s.opts.annotate_untyped_fields_with_any
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
            if s.opts.annotate_untyped_fields_with_any
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
    empty_body = length(filter(n -> !JuliaSyntax.is_whitespace(n), childs)) == 2

    if empty_body
        for c in childs[2:(end-1)]
            pretty(style, c, s, ctx, lineage)
        end
        add_node!(t, Whitespace(1), s)
        add_node!(t, pretty(style, cst[end], s), s; join_lines = true)
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

    for c in children(cst)
        if kind(c) in KSet"for while" && !haschildren(c)
            add_node!(t, pretty(style, c, s), s)
        elseif kind(c) === K"end"
            add_node!(t, pretty(style, c, s), s)
        elseif kind(c) === K"block"
            s.indent += s.opts.indent
            n = pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage)
            add_node!(t, n, s; max_padding = s.opts.indent)
            s.indent -= s.opts.indent

            if !ends_in_iterable && (t.nodes::Vector{FST})[end-2].typ !== NOTCODE
                insert!(t, length(t.nodes) - 1, Placeholder(0))
            end
        elseif JuliaSyntax.is_whitespace(c)
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        else
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
            if needs_placeholder(childs, i + 1, K")")
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
            if !next_node_is(K"NewlineWs", childs[i+1])
                add_node!(t, Whitespace(1), s)
            end
        elseif kind(c) === K"end"
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        elseif kind(c) === K"block"
            s.indent += s.opts.indent
            n = pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage)
            if s.opts.always_use_return
                prepend_return!(n, s)
            end
            add_node!(t, n, s; max_padding = s.opts.indent)
            s.indent -= s.opts.indent
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

    add_node!(
        t,
        p_call(ds, cst, s, ctx, lineage; do_block_idx = do_block_idx),
        s;
        join_lines = true,
    )

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
        elseif kind(c) in KSet"end"
            s.indent -= s.opts.indent
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        elseif kind(c) === K"block"
            s.indent += s.opts.indent
            add_node!(
                t,
                pretty(style, c, s, newctx(ctx; ignore_single_line = false), lineage),
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

    for c in children(cst)
        if kind(c) in KSet"if elseif else"
            if !haschildren(c)
                add_node!(t, pretty(style, c, s, ctx, lineage), s; max_padding = 0)
            else
                len = length(t)
                n = pretty(style, c, s, ctx, lineage)
                add_node!(t, n, s)
                t.len = max(len, length(n))
            end
        elseif kind(c) === K"end"
            add_node!(t, pretty(style, c, s, ctx, lineage), s)
        elseif kind(c) === K"block"
            s.indent += s.opts.indent
            add_node!(
                t,
                pretty(style, c, s, newctx(ctx; ignore_single_line = true), lineage),
                s;
                max_padding = s.opts.indent,
            )
            s.indent -= s.opts.indent
        elseif !JuliaSyntax.is_whitespace(c)
            add_node!(t, Whitespace(1), s)
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
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

    for c in children(cst)
        if kind(c) === K"=" && s.opts.whitespace_in_kwargs
            add_node!(t, Whitespace(1), s)
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        else
            # Need to explicitly check source_prefix rather than relying on
            # JuliaSyntax.is_prefix_op_call, as the latter doesn't identify e.g.
            # `>=(x)` as operators.
            source_prefix = !isnothing(source_prefix_operator_index(c, s))
            n = pretty(style, c, s, ctx, lineage)
            if !s.opts.whitespace_in_kwargs && (
                (n.typ === IDENTIFIER && endswith(n.val, "!")) ||
                source_prefix
            )
                add_node!(
                    t,
                    FST(PUNCTUATION, -1, n.startline, n.startline, "("),
                    s;
                    join_lines = true,
                )
                add_node!(t, n, s; join_lines = true)
                add_node!(
                    t,
                    FST(PUNCTUATION, -1, n.startline, n.startline, ")"),
                    s;
                    join_lines = true,
                )
            else
                add_node!(t, n, s; join_lines = true)
            end
        end
    end

    pop!(lineage)

    t
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

    nonest = ctx.nonest || opkind === K":"

    nrhs = nest_rhs(cst)
    if nrhs
        (t.nest_behavior = AlwaysNest)
    end
    nest = (is_binaryop_nestable(style, cst) && !nonest) || nrhs
    if opkind === K"=>" && haschildren(cst)
        rhs_idx = findlast(n -> !JuliaSyntax.is_whitespace(n), childs)
        if !isnothing(rhs_idx) && is_str_or_cmd(childs[rhs_idx])
            nest = false
        end
    end

    is_short_form_function = defines_function(cst) && !ctx.from_let
    op_dotted = kind(cst) === K"dotcall"
    standalone_binary_circuit = ctx.standalone_binary_circuit
    can_separate_kwargs = ctx.can_separate_kwargs && !is_function_or_macro_def(cst)

    lazy_op = is_lazy_op(opkind)
    # check if expression is a lazy circuit
    if lazy_op && standalone_binary_circuit
        for i in (length(lineage)-1):-1:1
            tt, _, is_assign = lineage[i]
            if tt in KSet"parens macrocall return if elseif else" || is_assign
                standalone_binary_circuit = false
                break
            elseif tt in KSet"block"
                break
            end
        end
    end

    t.metadata = Metadata(
        opkind,
        op_dotted,
        lazy_op && standalone_binary_circuit,
        is_short_form_function,
        is_assignment(cst) || defines_function(cst),
        false,
        false,
    )

    has_ws = false

    for (i, c) in enumerate(childs)
        if i > 1 && kind(c) in KSet"Whitespace NewlineWs"
            has_ws = true
            break
        end
    end

    from_colon = ctx.from_colon
    from_typedef = ctx.from_typedef
    parent_kind = length(lineage) > 1 ? lineage[end-1][1] : K"None"
    preserve_assignment_spacing =
        ctx.from_let || ctx.nospace || parent_kind in KSet"global local outer macrocall"

    nospace = ctx.nospace
    if opkind === K":"
        nospace = true
        from_colon = true
    elseif opkind in KSet"::"
        nospace = true
    elseif is_short_form_function && opkind === K"="
        nospace = false
        has_ws = true
    elseif is_assignment(cst) && !preserve_assignment_spacing
        nospace = false
        has_ws = true
    elseif kind(cst) === K"comparison"
        nospace = false
    elseif opkind in KSet"in ∈ isa ."
        nospace = false
    elseif opkind in KSet"=> ->" || (opkind === K"|>" && !(ctx.from_ref || from_colon))
        nospace = false
        has_ws = true
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
        if kind(cst) === K"op=" && !isempty(op_indices) && i == first(op_indices)
            loc = cursor_loc(s)
            op_span = sum(span, childs[first(op_indices):last(op_indices)]; init = 0)
            val = getsrcval(s.doc, (s.offset):(s.offset+op_span-1))
            s.offset += op_span
            n = FST(OPERATOR, loc[2], loc[1], loc[1], val)
            n.metadata = Metadata(K"op=", startswith(val, "."))
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
                Metadata(source_operator_kind(s, c, offset)::JuliaSyntax.Kind, is_dot)
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
            # elseif (kind(c) === opkind || kind(c) === K".") && !haschildren(c)
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
            if opkind === K":" &&
               # !s.whitespace_ops_in_indices &&
               is_opcall(c) &&
               kind(c) !== K"parens"
                add_node!(
                    t,
                    FST(PUNCTUATION, -1, n.startline, n.startline, "("),
                    s;
                    join_lines = true,
                )
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
                add_node!(
                    t,
                    FST(PUNCTUATION, -1, n.startline, n.startline, ")"),
                    s;
                    join_lines = true,
                )
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
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

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
            if needs_placeholder(childs, i + 1, K"}")
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

            add_node!(t, n, s; join_lines = true)

            if after_where && add_braces
                brace = FST(PUNCTUATION, -1, n.endline, n.endline, "}")
                add_node!(t, brace, s; join_lines = true)
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
)
    style = getstyle(ds)
    t = FST(Unary, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    first_idx = findfirst(n -> !JuliaSyntax.is_whitespace(n), childs)
    op_idx = source_prefix_operator_index(cst, s)
    if isnothing(op_idx)
        op_idx = first_idx
    end
    opkind = isnothing(op_idx) ? op_kind(cst) : source_op_kind(s, cst)
    op_dotted = kind(cst) === K"dotcall"

    t.metadata = Metadata(opkind, op_dotted)

    for (i, c) in enumerate(childs)
        offset = s.offset
        if i > 1 && kind(c) in KSet"Whitespace"
            add_node!(t, Whitespace(1), s)
        end
        n = pretty(style, c, s, ctx, lineage)
        if i == op_idx && n.typ === IDENTIFIER
            k = source_operator_kind(s, c, offset)
            if !isnothing(k)
                n.typ = OPERATOR
                n.metadata = Metadata(k, false)
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
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

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
            if needs_placeholder(childs, i + 1, K"}")
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

    childs = children(cst)
    if !isnothing(do_block_idx)
        if !checkbounds(Bool, childs, do_block_idx) ||
           kind(childs[do_block_idx]) !== K"do" ||
           !haschildren(childs[do_block_idx])
            error("p_call called with an invalid do block index")
        end
        childs = childs[1:(do_block_idx - 1)]
    end

    args = call_args(childs)
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

    for (i, a) in enumerate(childs)
        k = kind(a)
        n = if k == K"=" && haschildren(a)
            p_kw(style, a, s, ctx, lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end

        if k === K"("
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            end
        elseif k === K")"
            if nest
                add_node!(t, TrailingComma(), s)
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif k === K","
            add_node!(t, n, s; join_lines = true)

            # figure out if we need to put a placeholder
            if needs_placeholder(childs, i + 1, K")")
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end

    if s.opts.separate_kwargs_with_semicolon && ctx.can_separate_kwargs
        separate_kwargs_with_semicolon!(t)
    end

    t
end

function p_invisbrackets(
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
        if is_block(arg) ||
           (kind(arg) === K"generator" && haschildren(arg) && is_block(arg[1]))
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

    for c in children(cst)
        if kind(c) === K"("
            add_node!(t, pretty(style, c, s, ctx, lineage), s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
            end
        elseif kind(c) === K")"
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
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
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

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
            if needs_placeholder(childs, i + 1, K")")
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
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

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
            else
                false
            end
        elseif kind(a) === K")"
            # An odd case but this could occur if there are no keyword arguments.
            # In which case ";," is invalid syntax.
            #
            # no trailing comma since (arg) is semantically different from (arg,) !!!
            if nest
                if t[end].typ !== SEMICOLON && length(args) > 1
                    add_node!(t, TrailingComma(), s)
                end
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) in KSet", ;"
            add_node!(t, n, s; join_lines = true)
            if needs_placeholder(childs, i + 1, K")")
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
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

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
                add_node!(t, TrailingComma(), s)
                add_node!(t, Placeholder(0), s)
            end
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K","
            add_node!(t, n, s; join_lines = true)
            if needs_placeholder(childs, i + 1, K"}")
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
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

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
            if needs_placeholder(childs, i + 1, K"}")
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
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

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
            if needs_placeholder(childs, i + 1, K"]")
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
    idx = findfirst(
        n -> !JuliaSyntax.is_whitespace(kind(n)) && !(kind(n) in KSet"[ ]"),
        childs,
    )
    arg = childs[idx]

    if is_block(arg)
        t.nest_behavior = AlwaysNest
    elseif kind(arg) === K"generator" && haschildren(arg)
        idx = findfirst(n -> !JuliaSyntax.is_whitespace(kind(n)), children(arg))
        if !isnothing(idx) && is_block(arg[idx])
            t.nest_behavior = AlwaysNest
        end
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
            if needs_placeholder(childs, i + 1, K")")
                add_node!(t, Placeholder(nws), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end
    end
    t
end

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
        if kind(a) in KSet"import export public using"
            add_node!(t, pretty(style, a, s, ctx, lineage), s; join_lines = true)
            add_node!(t, Whitespace(1), s)
        elseif kind(a) === K":" && haschildren(a)
            nodes = children(a)
            for n in nodes
                add_node!(t, pretty(style, n, s, ctx, lineage), s; join_lines = true)
                if kind(n) in KSet"import export public using"
                    add_node!(t, Whitespace(1), s)
                elseif kind(n) in KSet", :"
                    add_node!(t, Placeholder(1), s)
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
    t = p_import(ds, cst, s, ctx, lineage)
    t.typ = Export
    t
end

function p_public(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_import(ds, cst, s, ctx, lineage)
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
    nest =
        length(args) > 1 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )

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
            if needs_placeholder(childs, i + 1, K"]")
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
    nest =
        length(args) > 0 && !(
            length(args) == 1 &&
            (unnestable_node(args[1]) || s.opts.disallow_single_arg_nesting)
        )
    childs = children(cst)
    idx = findfirst(n -> kind(n) === K"[", childs)::Int
    first_arg_idx = findnext(n -> !JuliaSyntax.is_whitespace(n), childs, idx + 1)

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)
        diff_line = t.endline != t.startline
        # If arguments are on different lines then always nest
        if diff_line
            (t.nest_behavior = AlwaysNest)
        else
            false
        end

        if kind(a) === K"["
            add_node!(t, n, s; join_lines = true)
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
            end
        elseif kind(a) === K"]"
            if nest
                add_node!(t, Placeholder(0), s)
            else
                false
            end
            add_node!(t, n, s; join_lines = true)
        elseif JuliaSyntax.is_whitespace(a)
            add_node!(t, n, s; join_lines = true)
        elseif kind(a) === K";"
            add_node!(t, n, s; join_lines = true)
        else
            # TODO: maybe we need to do something here?
            # [a b c d e f] is semantically different from [a b c; d e f]
            # child_has_semicolon = any(c -> kind(c) === K";", children(a))
            # if !child_has_semicolon
            #     add_node!(t, n, s, join_lines = false)
            # else
            #     add_node!(t, n, s, join_lines = true)
            # end
            if !isnothing(first_arg_idx) && i > first_arg_idx
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
    # st = kind(cst) === K"hcat" ? 1 : 2
    st = findfirst(n -> kind(n) === K"[", childs)::Int

    for (i, a) in enumerate(childs)
        n = pretty(style, a, s, ctx, lineage)
        if JuliaSyntax.is_whitespace(a)
            add_node!(t, n, s; join_lines = true)
        elseif i > st
            add_node!(t, n, s; join_lines = true)
            if needs_placeholder(childs, i + 1, K"]")
                add_node!(t, Whitespace(1), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
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

function p_row(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    style = getstyle(ds)
    t = FST(Row, nspaces(s))
    if !haschildren(cst)
        return t
    end

    childs = children(cst)
    first_arg_idx = findfirst(n -> !JuliaSyntax.is_whitespace(n), childs)

    for (i, a) in enumerate(childs)
        n = if is_opcall(a)
            pretty(style, a, s, newctx(ctx; nonest = true), lineage)
        else
            pretty(style, a, s, ctx, lineage)
        end

        if kind(a) === K";"
            add_node!(t, n, s; join_lines = true)
        elseif JuliaSyntax.is_whitespace(a)
            add_node!(t, n, s; join_lines = true)
        else
            if !isnothing(first_arg_idx) && i > first_arg_idx
                add_node!(t, Whitespace(1), s; join_lines = true)
            end
            add_node!(t, n, s; join_lines = true)
        end
    end
    t.nest_behavior = NeverNest
    t
end

function p_nrow(
    ds::AbstractStyle,
    cst::JuliaSyntax.GreenNode,
    s::State,
    ctx::PrettyContext,
    lineage::Vector{Tuple{JuliaSyntax.Kind,Bool,Bool}},
)
    t = p_row(ds, cst, s, ctx, lineage)
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

    past_if = false
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
            if needs_placeholder(childs, i + 1, K")")
                add_node!(t, Placeholder(1), s)
            end
        else
            add_node!(t, n, s; join_lines = true)
        end

        if from_for && !past_if
            eq_to_in_normalization!(n, s.opts.always_for_in, s.opts.for_in_replacement)
        end
        if kind(a) === K"if" && JuliaSyntax.is_keyword(a) && !haschildren(a)
            past_if = true
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
