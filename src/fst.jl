@enum(
    FNode,

    # dummy
    NONE,

    # leaf nodes
    NEWLINE,
    SEMICOLON,
    WHITESPACE,
    PLACEHOLDER,
    NOTCODE,
    INLINECOMMENT,
    TRAILINGCOMMA,
    KEYWORD,
    LITERAL,
    OPERATOR,
    PUNCTUATION,
    IDENTIFIER,
    MACRONAME,
    HASHEQCOMMENT,

    # non-leaf nodes
    Accessor,
    MacroBlock,
    MacroCall,
    MacroStr,
    Macroname,
    GlobalRefDoc,
    TupleN,
    CartesianIterator,
    RefN,
    ModuleN,
    Unary,
    Binary,
    Chain,
    Comparison,
    Conditional,
    Where,
    Vect,
    Braces,
    Brackets,
    Curly,
    Call,
    Parameters,
    Kw,
    Vcat,
    Hcat,
    Ncat,
    TypedVcat,
    TypedNcat,
    TypedHcat,
    Row,
    NRow,
    BracesCat,
    TypedComprehension,
    Comprehension,
    Generator,
    Filter,
    Flatten,
    For,
    While,
    If,
    Begin,
    Try,
    Quote,
    Do,
    Let,
    Block,
    BareModule,
    TopLevel,
    StringN,
    Macro,
    FunctionN,
    Struct,
    Mutable,
    Primitive,
    Abstract,
    Return,
    Local,
    Outer,
    Global,
    Const,
    Import,
    Export,
    Public,
    Using,
    File,
    Quotenode,
    Unknown,
    As,
    NonStdIdentifier, # i.e. var"##iv369"
    ImportPath,
    Juxtapose,
    Break,
    Continue,
    Inert,
    TupleBlock,
)

@enum(NestBehavior, AllowNest, AlwaysNest, NeverNest, NeverNestNode, AllowNestButDontRemove)

struct Metadata
    op_kind::JuliaSyntax.Kind
    is_standalone_shortcircuit::Bool
    is_short_form_function::Bool
    is_assignment::Bool
    is_long_form_function::Bool
    has_multiline_argument::Bool
end

function Metadata(k::JuliaSyntax.Kind)
    return Metadata(k, false, false, false, true, false)
end

"""
Formatted Syntax Tree
"""
mutable struct FST
    typ::FNode

    # Start and end lines of the node
    # in the original source file.
    startline::Int
    endline::Int

    # TODO(penelopeysm): This field should be calculated based on display width. I'm not
    # sure that this is consistently obeyed in the codebase, so it's more of an aspirational
    # comment rather than a true invariant right now.
    indent::Int

    # TODO(penelopeysm) This uses length(op.val) which is character count
    # It should really use textwidth.
    len::Int
    val::String
    # Note that nodes = () indicates a leaf node, whereas nodes = [] indicates a tree node
    # with no leaves (yet).
    #
    # TODO(penelopeysm): The former case should probably be `nothing`.
    nodes::Union{Tuple{},Vector{FST}}
    nest_behavior::NestBehavior

    # Extra margin caused by parent nodes.
    # i.e. `(f(arg))`
    #
    # `f(arg)` would have `extra_margin` = 1
    # due to `)` after `f(arg)`.
    extra_margin::Int
    line_offset::Int

    metadata::Union{Nothing,Metadata}
end

function show(io::IO, fst::FST)
    show(io, MIME("text/plain"), fst)
end

COLORS = (:blue, :green, :red, :cyan, :magenta, :yellow)

function _print_prefix(io::IO, prefix::Vector{String})
    for (k, seg) in enumerate(prefix)
        printstyled(io, seg; color = COLORS[mod1(k, length(COLORS))])
    end
end

function show(
    io::IO,
    ::MIME"text/plain",
    fst::FST;
    prefix::Vector{String} = String[],
    level::Int = 1,
)
    color = COLORS[mod1(level, length(COLORS))]
    extra_indent = level > 1 ? "    " : "" # to account for [N] prefix

    if !is_leaf(fst)
        nodes = fst.nodes::Vector{FST}
        n = length(nodes)
        printstyled(io, "$(fst.typ) $n"; color = color, bold = true)
        printstyled(
            io,
            " lines=$(fst.startline)-$(fst.endline) indent=$(fst.indent) len=$(fst.len)\n";
            color = color,
        )
        _print_prefix(io, prefix)
        printstyled(io, "nest_behavior=$(fst.nest_behavior)"; color = color)
        printstyled(io, " extra_margin=$(fst.extra_margin)\n"; color = color)

        for (i, node) in enumerate(nodes)
            is_last = i == n
            connector = is_last ? "└── " : "├── "
            continuation = is_last ? "    " : "│   "
            next_color = COLORS[mod1(level + 1, length(COLORS))]
            child_prefix = [prefix; continuation]

            _print_prefix(io, prefix)
            printstyled(io, connector; color = color)
            printstyled(io, "[$i] "; color = next_color, bold = true)
            show(io, MIME("text/plain"), node; prefix = child_prefix, level = level + 1)
        end
    else
        printstyled(io, "$(fst.typ)"; color = color, bold = true)
        printstyled(
            io,
            " lines=$(fst.startline)-$(fst.endline) val=$(repr(fst.val))\n";
            color = color,
        )
        _print_prefix(io, prefix)
        printstyled(io, "$(extra_indent)line_offset=$(fst.line_offset)"; color = color)
        printstyled(io, " indent=$(fst.indent)\n"; color = color)
    end
end

function FST(typ::FNode, indent::Int)
    FST(typ, 0, 0, indent, 0, "", FST[], AllowNest, 0, -1, nothing)
end

function FST(
    typ::FNode,
    line_offset::Int,
    startline::Int,
    endline::Int,
    val::AbstractString,
)
    FST(
        typ,
        startline,
        endline,
        0,
        length(val),
        val,
        (),
        AllowNest,
        0,
        line_offset,
        nothing,
    )
end

function Base.setindex!(fst::FST, node::FST, ind::Int)
    nodes = fst.nodes::Vector{FST}
    fst.len -= nodes[ind].len
    nodes[ind] = node
    fst.len += node.len
end
Base.getindex(fst::FST, inds...) = (fst.nodes::Vector{FST})[inds...]
Base.lastindex(fst::FST) = length(fst.nodes::Vector{FST})
Base.firstindex(fst::FST) = 1
Base.length(fst::FST) = fst.len
function Base.iterate(fst::FST, state = 1)
    nodes = fst.nodes::Vector{FST}
    if state > length(nodes::Vector{FST})
        return nothing
    end
    return nodes[state], state + 1
end

function Base.insert!(fst::FST, ind::Int, node::FST)
    insert!(fst.nodes::Vector{FST}, ind, node)
    fst.len += node.len
    return
end

# nesting behaviors
must_nest(fst::FST) = fst.nest_behavior === AlwaysNest
cant_nest(fst::FST) = fst.nest_behavior === NeverNest
can_nest(fst::FST) = fst.nest_behavior in (AllowNest, AllowNestButDontRemove)
can_remove(fst::FST) = fst.nest_behavior !== AllowNestButDontRemove

function Newline(; length = 0, nest_behavior = AllowNest)
    FST(NEWLINE, 0, 0, 0, length, "\n", (), nest_behavior, 0, -1, nothing)
end
Semicolon() = FST(SEMICOLON, 0, 0, 0, 1, ";", (), AllowNest, 0, -1, nothing)
TrailingComma() = FST(TRAILINGCOMMA, 0, 0, 0, 0, "", (), AllowNest, 0, -1, nothing)
Whitespace(n) = FST(WHITESPACE, 0, 0, 0, n, " "^n, (), AllowNest, 0, -1, nothing)
Placeholder(n) = FST(PLACEHOLDER, 0, 0, 0, n, " "^n, (), AllowNest, 0, -1, nothing)
function Notcode(startline, endline)
    FST(NOTCODE, startline, endline, 0, 0, "", (), AllowNest, 0, -1, nothing)
end
function InlineComment(line)
    FST(INLINECOMMENT, line, line, 0, 0, "", (), AllowNest, 0, -1, nothing)
end

is_leaf(cst::JuliaSyntax.GreenNode) = !haschildren(cst)
is_leaf(fst::FST) = typeof(fst.nodes) === Tuple{}

function is_punc(cst::JuliaSyntax.GreenNode)
    punctuation = KSet", ( ) [ ] { } @"
    return kind(cst) in punctuation || (kind(cst) === K"." && !haschildren(cst))
end
is_punc(fst::FST) = fst.typ === PUNCTUATION

is_end(x::JuliaSyntax.GreenNode) = kind(x) === K"end"
is_end(x::FST) = x.typ === KEYWORD && x.val == "end"

is_colon(x::FST) = x.typ === OPERATOR && x.val == ":"

is_comma(fst::FST) = fst.typ === TRAILINGCOMMA || (is_punc(fst) && fst.val == ",")
is_comment(fst::FST) = fst.typ in (INLINECOMMENT, NOTCODE, HASHEQCOMMENT)

is_identifier(x) = kind(x) === K"Identifier" && !haschildren(x)

is_ws(x) = JuliaSyntax.is_whitespace(x)

function is_multiline(fst::FST)
    fst.endline > fst.startline &&
        fst.typ in (StringN, Vcat, TypedVcat, Ncat, TypedNcat, MacroStr)
end

is_macrocall(fst::FST) = fst.typ in (MacroCall, MacroBlock)

function is_macrodoc(fst::FST)::Bool
    fst.typ === GlobalRefDoc ||
        (fst.typ === MacroBlock && fst[1].typ === Macroname && fst[1][1].val == "@doc")
end

function is_macrostr(t::JuliaSyntax.GreenNode)::Bool
    kind(t) == K"macrocall" && haschildren(t) && contains_macrostr(t[1])
end

function contains_macrostr(t::JuliaSyntax.GreenNode)::Bool
    if kind(t) in KSet"StringMacroName CmdMacroName"
        return true
    elseif kind(t) === "quote" && haschildren(t)
        return contains_macrostr(t[1])
    elseif kind(t) === K"." && haschildren(t)
        return any(contains_macrostr, reverse(children(t)))
    end
    return false
end

function is_func_call(t::JuliaSyntax.GreenNode)::Bool
    if kind(t) in KSet"call dotcall"
        # e.g. `f(...)` or `<=(...)` -- these are ordinary functions
        return JuliaSyntax.is_prefix_call(t)
    elseif JuliaSyntax.is_type_operator(t) && haschildren(t)
        # e.g. `<:(...)` or `>:(...)` -- these have the same syntax as function calls
        # but JuliaSyntax parses them into [<:] or [>:] nodes rather than [call]
        #
        # Note that the dotted versions `.<:(...)` are parsed into [call] so go into
        # the first branch 
        return JuliaSyntax.is_prefix_call(t)
    elseif kind(t) in KSet":: where parens" && haschildren(t)
        # `f(...)::T` or `f(...) where T` or `(f(...))`
        # TODO(penelopeysm): Why?
        childs = children(t)
        idx =
            findfirst(n -> !JuliaSyntax.is_whitespace(n) && !(kind(n) in KSet"( )"), childs)
        return !isnothing(idx) && is_func_call(childs[idx])
    end
    return false
end

function defines_function(x::JuliaSyntax.GreenNode)
    if kind(x) in KSet"function macro" && haschildren(x)
        return true
    elseif is_assignment(x) && haschildren(x)
        childs = children(x)
        idx = findfirst(n -> !JuliaSyntax.is_whitespace(n), childs)
        return !isnothing(idx) && is_func_call(childs[idx])
    end
    return false
end

is_if(cst::JuliaSyntax.GreenNode) = kind(cst) in KSet"if elseif else" && haschildren(cst)

function is_try(cst::JuliaSyntax.GreenNode)
    kind(cst) in KSet"try catch finally" && haschildren(cst)
end

function is_custom_leaf(fst::FST)
    fst.typ in
    (NEWLINE, WHITESPACE, PLACEHOLDER, NOTCODE, INLINECOMMENT, TRAILINGCOMMA, HASHEQCOMMENT)
end

contains_comment(nodes::Vector{FST}) = findfirst(is_comment, nodes) !== nothing
function contains_comment(fst::FST)
    !is_leaf(fst) && contains_comment(fst.nodes::Vector{FST})
end

function get_args(t::JuliaSyntax.GreenNode)
    nodes = JuliaSyntax.GreenNode[]
    !haschildren(t) && return nodes
    childs = children(t)
    childs isa Tuple{} && return nodes

    k = kind(t)
    ret = if k == K"where"
        if is_leaf(childs[end])
            JuliaSyntax.GreenNode[childs[end]]
        else
            get_args(childs[end])
        end
    else
        _idx = findfirst(n -> kind(n) in KSet"( { [", childs)
        idx = isnothing(_idx) ? 1 : _idx + 1
        get_args(childs[idx:end])
    end
    append!(nodes, ret)
    return nodes
end

function get_args(args::Vector{JuliaSyntax.GreenNode{T}}) where {T}
    result = JuliaSyntax.GreenNode[]
    for c in args
        if !(
            is_punc(c) ||
            kind(c) == K";" ||
            JuliaSyntax.is_whitespace(c) ||
            kind(c) in KSet"` ``` \" \"\"\""
        )
            if kind(c) === K"parameters"
                append!(result, get_args(c))
            else
                push!(result, c)
            end
        end
    end
    return result
end

get_args(_) = ()
n_args(x) = length(get_args(x))

is_arg(fst::FST) = !(fst.typ in (PUNCTUATION, SEMICOLON) || is_custom_leaf(fst))

function n_args(fst::FST)
    is_leaf(fst) && return 0
    nodes = fst.nodes::Vector{FST}
    idx = findfirst(is_opener, nodes) |> x -> isnothing(x) ? 1 : x
    count(is_arg, nodes[idx:end])
end

function is_prev_newline(fst::FST)
    return if fst.typ === NEWLINE
        true
    elseif is_leaf(fst) || length(fst.nodes::Vector) == 0
        false
    else
        is_prev_newline(fst[end])
    end
end
function remove_prev_newline!(fst::FST)
    if is_leaf(fst) || length(fst.nodes::Vector) == 0
        error("Cannot remove previous newline from a leaf node or empty FST")
    elseif fst[end].typ === NEWLINE
        pop!(fst.nodes::Vector{FST})
        # no need to decrement fst.len because Newline nodes have len 0
    else
        remove_prev_newline!(fst[end])
        # likewise no need to decrement fst.len
    end
    return nothing
end

"""
    length_to(x::FST, ntyps; start::Int = 1)

Returns the length to any node type in `ntyps` based off the `start` index.
"""
function length_to(fst::FST, ntyps; start::Int = 1)
    if fst.typ in ntyps
        return 0, true
    end
    if is_leaf(fst)
        return length(fst), false
    end
    len = 0
    nodes = fst.nodes::Vector
    for i in start:length(nodes)
        l, found = length_to(nodes[i], ntyps)
        len += l
        if found
            return len, found
        end
    end
    return len, false
end

function is_closer(fst::FST)
    fst.typ === PUNCTUATION && (fst.val == "}" || fst.val == ")" || fst.val == "]")
end
is_closer(t::JuliaSyntax.GreenNode) = kind(t) in KSet"} ) ]"

function is_opener(fst::FST)
    fst.typ === PUNCTUATION && (fst.val == "{" || fst.val == "(" || fst.val == "[")
end
is_opener(t::JuliaSyntax.GreenNode) = kind(t) in KSet"{ ( ["

function is_iterable(t::JuliaSyntax.GreenNode)
    if !(
        kind(t) in
        KSet"parens tuple vect vcat braces curly comprehension typed_comprehension macrocall ref typed_vcat import using export public"
    )
        is_func_call(t)
    else
        true
    end
end

function is_iterable(x::FST)
    is_named_iterable(x) || is_unnamed_iterable(x) || is_import_expr(x)
end
is_iterable(::Nothing) = false

function is_unnamed_iterable(x::FST)
    return x.typ in (TupleN, Vect, Vcat, Ncat, Braces, Comprehension, Brackets)
end

function is_named_iterable(x::FST)
    return x.typ in (Call, Curly, TypedComprehension, MacroCall, RefN, TypedVcat, TypedNcat)
end

function is_import_expr(x::FST)
    return x.typ in (Import, Using, Export, Public)
end

"""
Returns whether `fst` can be an iterable argument. For example in
the case of a function call, which is of type `Call`:

```julia
(a, b, c; k1=v1)
```

This would return `true` for `a`, `b`, `c` and `k1=v1` and `false` for all other nodes.
"""
function is_iterable_arg(fst::FST)
    !(fst.typ in (PUNCTUATION, KEYWORD, OPERATOR, SEMICOLON) || is_custom_leaf(fst))
end

function is_comprehension(x::JuliaSyntax.GreenNode)
    kind(x) in KSet"comprehension typed_comprehension"
end

function is_comprehension(x::FST)
    x.typ in (Comprehension, TypedComprehension)
end

function first_nontrivial_child_is_block(cst::JuliaSyntax.GreenNode)
    if !haschildren(cst)
        return false
    end
    for c in children(cst)
        if JuliaSyntax.is_whitespace(c)
            continue
        else
            return is_block(c)
        end
    end
    return false
end

function is_block(x::JuliaSyntax.GreenNode)
    is_if(x) ||
        kind(x) in KSet"do try for while let" ||
        (kind(x) == K"block" && haschildren(x)) ||
        (kind(x) == K"quote" && haschildren(x) && is_block(x[1]))
end

function is_block(x::FST)
    x.typ in (Block, If, Do, Try, Begin, For, While, Let) ||
        (x.typ === Quote && x[1].val == "quote")
end

function is_typedef(fst::FST)
    fst.typ in (Struct, Mutable, Primitive, Abstract)
end

function is_opcall(x::JuliaSyntax.GreenNode)
    if is_binary(x) || kind(x) == K"comparison" || is_chain(x) || unary_info(x) !== nothing
        return true
    end
    if kind(x) === K"parens" && haschildren(x)
        childs = children(x)
        idx = findfirst(
            n -> !JuliaSyntax.is_whitespace(kind(n)) && !(kind(n) in KSet"( )"),
            childs,
        )
        if isnothing(idx)
            return false
        end
        return is_opcall(childs[idx])
    end
    return false
end

function is_gen(x::JuliaSyntax.GreenNode)
    kind(x) in KSet"generator filter"
end

function is_gen(x::FST)
    x.typ in (Generator, Filter, Flatten)
end

function _callinfo(x::JuliaSyntax.GreenNode)
    if !haschildren(x)
        return 0, 0
    end
    k = kind(x)
    if k === K"call" && JuliaSyntax.is_infix_op_call(x)
        args = count(n -> !JuliaSyntax.is_whitespace(n), children(x))
        return div(args - 1, 2), div(args + 1, 2)
    elseif k === K"dotcall" && JuliaSyntax.is_infix_op_call(x)
        args = count(n -> !JuliaSyntax.is_whitespace(n), children(x))
        nops = div(args - 1, 3)
        return nops, nops + 1
    elseif k === K"op="
        return 1, 2
    elseif JuliaSyntax.is_operator(x) && haschildren(x)
        args = count(n -> !JuliaSyntax.is_whitespace(n), children(x))
        if args >= 3
            return div(args - 1, 2), div(args + 1, 2)
        end
    end
    n_operators = 0
    n_args = 0

    for c in children(x)
        if JuliaSyntax.is_whitespace(c) || is_punc(c)
            continue
        elseif haschildren(c) || (!haschildren(c) && !JuliaSyntax.is_operator(c))
            n_args += 1
        elseif k == K"dotcall" && JuliaSyntax.is_operator(c) && kind(c) == K"."
            continue
        elseif JuliaSyntax.is_operator(c)
            n_operators += 1
        end
    end
    return n_operators, n_args
end

"""
    unary_info(x::JuliaSyntax.GreenNode)::Union{Bool,Nothing}

Returns:

- `true` if `x` is a prefix unary operator application, such as `+x` or `<:x`

- `false` if `x` is a postfix unary operator application, such as `x'` or `x...`;

- `nothing` if `x` is not an application of a unary operator.
"""
function unary_info(x::JuliaSyntax.GreenNode)
    return if JuliaSyntax.is_prefix_op_call(x)
        # `+x`
        true
    elseif JuliaSyntax.is_postfix_op_call(x)
        # `x'` or `x'ᵀ`
        false
    elseif JuliaSyntax.is_operator(x) && haschildren(x)
        # `<:x` or `x...`
        childs_no_whitespace = filter(c -> !JuliaSyntax.is_whitespace(c), children(x))
        if length(childs_no_whitespace) != 2
            # Not unary at all
            nothing
        elseif JuliaSyntax.is_operator(childs_no_whitespace[1])
            # `<:x`
            true
        elseif JuliaSyntax.is_operator(childs_no_whitespace[end])
            # `x...`
            false
        else
            error("unreachable: unary operation node with no child operator")
        end
    else
        # Not unary at all
        nothing
    end
end

function is_binary(x)
    # TODO(penelopeysm): There is a bug in `is_binary` in that it returns true for
    # `<:(args...)` and `>:(args...)` as well. This is currently papered over in pretty() by
    # checking Shims.is_function_call(x) first, which will catch those cases, before
    # checking is_binary.
    #
    if !JuliaSyntax.is_infix_op_call(x) && !(JuliaSyntax.is_operator(x) && haschildren(x))
        # "Genuine" operators are caught by is_infix_op_call.
        #
        # The second predicate catches things like:
        #   - assignments `x = y`
        #   - field access `x.y`
        #   - logic operators `x && y` or `x || y`
        #   - membership `x in y`
        #   - anonymous functions `x -> y`
        return false
    end
    nops, nargs = _callinfo(x)
    return nops == 1 && nargs == 2
end

function is_chain(x::JuliaSyntax.GreenNode)
    if !(kind(x) in KSet"call dotcall")
        return false
    end
    nops, nargs = _callinfo(x)
    return nops > 1 && nargs > 2
end

function is_assignment(x::FST)
    if x.typ === Binary
        if isnothing(x.metadata)
            return false
        else
            return (x.metadata::Metadata).is_assignment
        end
    end

    if (
        x.typ === Const ||
        x.typ === Local ||
        x.typ === Global ||
        x.typ === Outer ||
        x.typ === MacroBlock
    ) && is_assignment(x[end])
        return true
    end

    return false
end

function is_assignment(t::JuliaSyntax.GreenNode)
    return JuliaSyntax.is_syntactic_assignment(t) && haschildren(t)
end
is_assignment(::Nothing) = false

function is_pairarrow(cst::JuliaSyntax.GreenNode)::Bool
    op = get_op(cst)
    isnothing(op) ? false : kind(op) === K"=>"
end

function is_function_or_macro_def(cst::JuliaSyntax.GreenNode)
    if !haschildren(cst)
        return false
    end
    k = kind(cst)
    if k in KSet"function macro"
        return true
    end

    if JuliaSyntax.is_operator(cst) && k === K"="
        idx = findfirst(n -> !JuliaSyntax.is_whitespace(n), children(cst))
        if isnothing(idx)
            return false
        end
        return is_function_like_lhs(cst[idx])
    end

    return false
end

function is_short_function_def(cst::JuliaSyntax.GreenNode)
    kind(cst) === K"function" &&
        JuliaSyntax.has_flags(cst, JuliaSyntax.SHORT_FORM_FUNCTION_FLAG)
end

function is_function_like_lhs(node::JuliaSyntax.GreenNode)
    k = kind(node)
    if k in KSet"call dotcall"
        return true
    elseif k == K"where" || k == K"::"
        return haschildren(node) && is_function_like_lhs(node[1])
    end
    return false
end

function has_leading_whitespace(n::JuliaSyntax.GreenNode)
    if kind(n) === K"Whitespace"
        return true
    end
    if haschildren(n) && length(children(n)) > 0
        return has_leading_whitespace(n[1])
    end
    return false
end

function remove_empty_notcode(fst::FST)
    fst.typ in (Binary, Conditional, Comparison, Chain) || is_iterable(fst)
end

"""
    has_delimiters(cst::JuliaSyntax.GreenNode)

`cst` is assumed to be a single child node. Returns true if the node is of the syntactic
form `{...}, [...], or (...)`.
"""
function has_delimiters(cst::JuliaSyntax.GreenNode)
    kind(cst) in KSet"tuple vect braces bracescat comprehension parens"
end

function should_allow_nesting_call_args(args, disallow_single_arg_nesting::Bool)
    return length(args) > 0 && !(length(args) == 1 &&
             # If the argument has delimiters, it can itself be nested, so we
             # don't need to nest the call expression.
             (has_delimiters(args[1]) || disallow_single_arg_nesting))
end

function is_binaryop_nestable(::AbstractStyle, cst::JuliaSyntax.GreenNode)
    if (is_assignment(cst) || is_pairarrow(cst) || defines_function(cst)) &&
       haschildren(cst)
        childs = children(cst)
        idx = findlast(n -> !JuliaSyntax.is_whitespace(n), childs)::Int
        return !is_str_or_cmd(childs[idx])
    end
    true
end

function nest_rhs(cst::JuliaSyntax.GreenNode)::Bool
    if defines_function(cst) && haschildren(cst)
        for c in children(cst)
            if is_if(c) || kind(c) in KSet"do try for while let" && haschildren(c)
                return true
            end
        end
    end
    false
end

function get_op(cst::JuliaSyntax.GreenNode)::Union{JuliaSyntax.GreenNode,Nothing}
    if JuliaSyntax.is_operator(cst)
        return cst
    end
    if (
        is_binary(cst) ||
        kind(cst) in KSet"comparison dotcall call" ||
        is_chain(cst) ||
        unary_info(cst) !== nothing
    ) && haschildren(cst)
        for c in children(cst)
            if kind(cst) === K"dotcall" && kind(c) === K"."
                continue
            elseif JuliaSyntax.is_operator(c) && !haschildren(c)
                return c
            end
        end
    end
    return nothing
end

function op_kind(cst::JuliaSyntax.GreenNode)::JuliaSyntax.Kind
    op = get_op(cst)
    isnothing(op) ? K"None" : kind(op)
end

function op_kind(fst::FST)::JuliaSyntax.Kind
    return isnothing(fst.metadata) ? K"None" : (fst.metadata::Metadata).op_kind
end

# """
#     is_standalone_shortcircuit(cst::JuliaSyntax.GreenNode)
#
# Returns `true` if the `cst` is a short-circuit expression (uses `&&`, `||`)
# and is *standalone*, meaning it's not directly associated with another statement or
# expression.
#
# ### Examples
#
# ```julia
# # this IS a standalone short-circuit
# a && b
#
# # this IS NOT a standalone short-circuit
# if a && b
# end
#
# # this IS NOT a standalone short-circuit
# var = a && b
#
# # this IS NOT a standalone short-circuit
# @macro a && b
#
# # operation inside parenthesis IS NOT a standalone short-circuit
# # operation outside parenthesis IS a standalone short-circuit
# (a && b) && c
# ```
# """

"""
    eq_to_in_normalization!(fst::FST, always_for_in::Bool, for_in_replacement::String)
    eq_to_in_normalization!(fst::FST, always_for_in::Nothing, for_in_replacement::String)

Transforms

```julia
for i = iter body end

=>

for i in iter body end
```

AND

```julia
for i in 1:10 body end

=>

for i = 1:10 body end
```

`always_for_in=nothing` disables this normalization behavior.

- <https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/34>
"""
function eq_to_in_normalization!(fst::FST, always_for_in::Bool, for_in_replacement::String)
    if fst.typ === Binary
        idx = findfirst(n -> n.typ === OPERATOR, fst.nodes::Vector)
        if isnothing(idx)
            return
        end
        op = fst[idx]
        if !(valid_for_in_op(op.val))
            return
        end

        # surround op with ws
        if for_in_replacement != "=" && fst[idx-1].typ !== WHITESPACE
            insert!(fst, idx, Whitespace(1))
            insert!(fst, idx + 2, Whitespace(1))
        end

        if always_for_in
            op.val = for_in_replacement
            op.len = length(op.val)
        elseif op.val == "=" && op_kind(fst[end]) !== K":"
            op.val = "in"
            op.len = length(op.val)
        elseif op.val == "in" && op_kind(fst[end]) === K":"
            op.val = "="
            op.len = length(op.val)
        end
        if !isnothing(fst.metadata)
            metadata = fst.metadata::Metadata
            opkind = JuliaSyntax.Kind(op.val)
            fst.metadata = Metadata(
                opkind,
                metadata.is_standalone_shortcircuit,
                metadata.is_short_form_function,
                opkind === K"=",
                metadata.is_long_form_function,
                metadata.has_multiline_argument,
            )
        end
    elseif fst.typ === Block || fst.typ === Brackets || fst.typ === Filter
        past_if = false
        for n in fst.nodes::Vector
            if n.typ === KEYWORD && n.val == "if"
                # [x for x in xs if x in 1:length(ys)]
                # we do not want to convert the binary operations after an "if" keyword.
                past_if = true
            end
            if past_if
                break
            end
            eq_to_in_normalization!(n, always_for_in, for_in_replacement)
        end
    end
end
eq_to_in_normalization!(::FST, ::Nothing, ::String) = nothing

# Check if the caller of a call is in `list`
# Note that this also works for JuliaSyntax.GreenNode
function caller_in_list(fst::FST, list::Vector{String})
    if is_leaf(fst[1]) && (fst[1].val) in list
        return true
    elseif !is_leaf(fst[1]) && is_leaf(fst[1][1]) && (fst[1][1].val) in list
        return true
    end

    return false
end

function caller_in_list(caller::AbstractString, list::Vector{String})
    return caller in list
end

function is_str_or_cmd(t::JuliaSyntax.GreenNode)
    kind(t) in KSet"doc string cmdstring String CmdString"
end

function is_lazy_op(t::Union{JuliaSyntax.GreenNode,JuliaSyntax.Kind})
    kind(t) in KSet"|| &&"
end

function has_more_args_to_come(::Tuple{}, _, _)
    return false
end

"""
    has_more_args_to_come

Searches `childs[start_index:end]` for the first non-whitespace node and returns whether it
is not of kind `stop_kind`.

If the first non-whitespace node is of kind `stop_kind`, that implies that there are no more
arguments to process in the current argument list / indexing expression / etc.
"""
function has_more_args_to_come(
    childs::Vector{JuliaSyntax.GreenNode{T}},
    start_index::Int,
    stop_kind::JuliaSyntax.Kind,
) where {T}
    j = start_index
    while j <= length(childs)
        if !JuliaSyntax.is_whitespace(childs[j])
            return kind(childs[j]) !== stop_kind
        end
        j += 1
    end
    return false
end

function next_node_is(k::JuliaSyntax.Kind, nn::JuliaSyntax.GreenNode)
    kind(nn) === k || (haschildren(nn) && next_node_is(k, nn[1]))
end

function next_node_is(f::Function, nn::JuliaSyntax.GreenNode)
    f(nn) || (haschildren(nn) && next_node_is(f, nn[1]))
end

function ends_with_macro_or_global(fst::FST)
    # Detects constructs such as
    #    @macro foo
    #    arg = @macro foo
    #    arg => @macro foo
    #    () -> global x = true
    # which cause parse errors if a comma is inserted after them.
    return if fst.typ === MacroCall || fst.typ === MacroBlock || fst.typ === Global
        true
    elseif is_leaf(fst)
        false
    elseif fst.typ === Kw || fst.typ === Binary
        length(fst.nodes) > 0 && ends_with_macro_or_global(fst[end])
    else
        false
    end
end
function skip_trailing_comma(fst::FST)
    prev_node = fst[end]
    return if is_comma(prev_node) && fst.typ === TupleN && n_args(fst) == 1
        # e.g. `(x,)` -- removing the comma changes the meaning
        true
    elseif (
        prev_node.typ === Generator ||
        prev_node.typ === Filter ||
        prev_node.typ === Flatten ||
        prev_node.typ === SEMICOLON ||
        prev_node.typ === HASHEQCOMMENT ||
        # Things that end with macros can't have a trailing comma inserted after them
        # as that causes Julia to fail to parse.
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1017
        ends_with_macro_or_global(prev_node)
    )
        true
    else
        false
    end
end

"""
    add_node!(
        t::FST,
        n::FST,
        s::State;
        join_lines::Bool = false,
        max_padding::Int = -1,
        override_join_lines_based_on_source::Bool = false,
    )

Appends `n` to `t`.

- `join_lines` if `false` a NEWLINE node will be added and `n` will appear
  on the next line, otherwise it will appear on the same line as the previous
  node (when printing).
- `max_padding` >= 0 indicates margin of `t` should be based on whether the margin
  of `n` + `max_padding` is greater than the current margin of `t`. Otherwise the margin
  `n` will be added to `t`.
- `override_join_lines_based_on_source` is only used when `join_lines_based_on_source` option is `true`.
  In which `n` is added to `t` as if `join_lines_based_on_source` was false.
"""
function add_node!(
    t::FST,
    n::FST,
    s::State;
    join_lines::Bool = false,
    max_padding::Int = -1,
    override_join_lines_based_on_source::Bool = false,
)
    tnodes = t.nodes::Vector{FST}

    if n.typ === NONE
        if length(tnodes::Vector{FST}) == 0
            t.startline = n.startline
            t.endline = n.endline
        end
        return
    end

    if n.typ === TRAILINGCOMMA
        en = (tnodes::Vector{FST})[end]
        if skip_trailing_comma(t)
            # do not insert trailing comma
            false
        elseif s.opts.trailing_comma === nothing
            # preserve original source code
            false
        elseif !s.opts.trailing_comma::Bool
            # remove preexisting comma in FST
            if is_comma(en)
                t[end] = Whitespace(0)
            end
        elseif is_comma(en)
            t[end] = n
        elseif en.typ === Parameters && length(en.nodes) > 0 && is_comma(en[end])
            en[end] = n
        elseif en.typ === Parameters && length(en.nodes) > 0 && en[end].typ === SEMICOLON
            # do nothing
        else
            t.len += length(n)
            n.startline = t.endline
            n.endline = t.endline
            push!(tnodes::Vector{FST}, n)
        end
        return
    elseif n.typ === NOTCODE
        n.indent = s.indent
        push!(tnodes::Vector{FST}, n)
        return
    elseif n.typ === INLINECOMMENT
        push!(tnodes::Vector{FST}, n)
        return
    elseif is_custom_leaf(n) && n.typ !== HASHEQCOMMENT
        t.len += length(n)
        # Treat the node as extending the line of the previous node (...?)
        n.startline = t.endline
        n.endline = t.endline
        push!(tnodes::Vector{FST}, n)
        return
    end

    if n.typ === Block && length(n) == 0
        push!(tnodes::Vector{FST}, n)
        return
    elseif s.opts.import_to_using && n.typ === Import && t.typ !== MacroBlock
        usings = import_to_usings(n, s)
        if length(usings) > 0
            for nn in usings
                add_node!(t, nn, s; join_lines = false, max_padding = 0)
            end
            return
        end
    elseif n.typ === Binary && n[1].typ === Binary && n[1][end].typ === Where
        # normalize FST representation for Where
        binaryop_to_whereop!(n, s)
    end

    # Handle whitespace around HASHEQCOMMENT nodes.
    if n.typ === HASHEQCOMMENT && !isempty(tnodes)
        # If join_lines = false, then a newline will be inserted before the HASHEQCOMMENT
        # node. This will cause (for example) `a #= hi =#` to be formatted to `a \n #= hi
        # =#`, which is undesirable. So we manually set join_lines = true.
        join_lines = true
        # Add a space before a `#= =#` comment to avoid it being
        # glued to the previous node when printed.
        #
        # TODO(penelopeysm): The PLACEHOLDER check catches cases where there is a
        # Placeholder(1) before the comment, which can be turned into a Whitespace(1).
        # I'm not sure if this check is therefore overly broad since it also catches
        # Placeholder(0) nodes.
        nt = (tnodes[end]::FST).typ
        if nt !== WHITESPACE &&
           nt !== NEWLINE &&
           nt !== PLACEHOLDER &&
           !is_opener(tnodes[end])
            add_node!(t, Whitespace(1), s)
        end
    end

    if length(tnodes::Vector{FST}) == 0
        t.startline = n.startline
        t.endline = n.endline
        t.len += length(n)
        t.line_offset = n.line_offset
        push!(tnodes, n)
        return
    end

    # if `max_padding` >= 0 `n` should appear on the next line
    # even if it's contrary to the original source.
    if s.opts.join_lines_based_on_source &&
       !override_join_lines_based_on_source &&
       max_padding == -1 &&
       !(
           n.typ === SEMICOLON ||
           is_comma(n) ||
           is_block(t) ||
           t.typ === FunctionN ||
           t.typ === Macro ||
           is_typedef(t) ||
           t.typ === ModuleN ||
           t.typ === BareModule ||
           is_end(n)
       )
        # join based on position in original file
        join_lines = t.endline == n.startline
    end

    # Keep a space after an inline `#= =#` comment when the following code stays on the
    # same line (e.g. `f(x, #= c =# z)`), instead of gluing them together.
    if join_lines &&
       (tnodes[end]::FST).typ === HASHEQCOMMENT &&
       !is_closer(n) &&
       !is_comma(n) &&
       n.typ !== SEMICOLON
        add_node!(t, Placeholder(1), s)
    end

    if !is_prev_newline(tnodes[end]::FST)
        current_line = t.endline
        notcode_startline = current_line + 1
        notcode_endline = n.startline - 1
        nt = (tnodes[end]::FST).typ

        if notcode_startline <= notcode_endline
            # If there are comments in between node elements
            # nesting is forced in an effort to preserve them.

            rm_block_nl =
                s.opts.remove_extra_newlines &&
                t.typ !== ModuleN &&
                (n.typ === Block || is_end(n))

            # Force nesting
            nest = true
            # Unless it's not worth nesting (e.g., inside a function call, or binary op)
            if remove_empty_notcode(t) || rm_block_nl
                nest = false
                # ... Unless there are comments, in which case we can't nest
                for l in notcode_startline:notcode_endline
                    if hascomment(s.doc, l)
                        nest = true
                        break
                    end
                end
            end
            if nest || hascomment(s.doc, current_line)
                t.nest_behavior = AlwaysNest
            end

            # If the previous node type is WHITESPACE - reset it.
            # This fixes cases similar to the one shown in issue #51.
            if nt === WHITESPACE
                tnodes[end]::FST = Whitespace(0)
            end

            if hascomment(s.doc, current_line)
                add_node!(t, InlineComment(current_line), s)
            end

            if nt !== PLACEHOLDER
                add_node!(t, Newline(; nest_behavior = AlwaysNest), s)
            elseif hascomment(s.doc, current_line) && nt === PLACEHOLDER
                # swap PLACEHOLDER (will be NEWLINE) with INLINECOMMENT node
                idx = length(tnodes::Vector{FST})
                tnodes[idx-1], tnodes[idx] = tnodes[idx], tnodes[idx-1]
            end

            if nest
                add_node!(t, Notcode(notcode_startline, notcode_endline), s)
                add_node!(t, Newline(; nest_behavior = AlwaysNest), s)
            end
        elseif !join_lines
            if hascomment(s.doc, current_line) && current_line != n.startline
                add_node!(t, InlineComment(current_line), s)
            end
            add_node!(t, Newline(; nest_behavior = AlwaysNest), s)
        elseif nt === PLACEHOLDER &&
               current_line != n.startline &&
               hascomment(s.doc, current_line)
            t.nest_behavior = AlwaysNest
            add_node!(t, InlineComment(current_line), s)
            # swap PLACEHOLDER (will be NEWLINE) with INLINECOMMENT node
            idx = length(tnodes)
            tnodes[idx-1], tnodes[idx] = tnodes[idx], tnodes[idx-1]
        elseif hascomment(s.doc, current_line) && current_line != n.startline
            if nt === WHITESPACE
                # Avoid printing excess whitespace before the comment, since
                # print_inlinecomment will handle the spacing before the comment.
                tnodes[end] = Whitespace(0)
            end
            add_node!(t, InlineComment(current_line), s)
            add_node!(t, Newline(; nest_behavior = AlwaysNest), s)
        end
    end

    if n.startline < t.startline || t.startline == 0
        t.startline = n.startline
    end
    if n.endline > t.endline || t.endline == 0
        t.endline = n.endline
    end

    if !join_lines && is_end(n)
        # end keyword isn't useful w.r.t margin lengths
    elseif t.typ === StringN
        # The length of this node is the length of
        # the longest string. The length of the string is
        # only considered "in the positive" when it's past
        # the hits the initial """ offset, i.e. `t.indent`.
        t.len = max(t.len, n.indent + length(n) - t.indent)
    elseif is_multiline(n) ||
           (!isnothing(t.metadata) && (t.metadata::Metadata).has_multiline_argument)
        if isnothing(t.metadata)
            t.metadata = Metadata(K"None", false, false, false, true, true)
        else
            metadata = t.metadata::Metadata
            t.metadata = Metadata(
                metadata.op_kind,
                metadata.is_standalone_shortcircuit,
                metadata.is_short_form_function,
                metadata.is_assignment,
                metadata.is_long_form_function,
                true,
            )
        end
        if is_iterable(t) && n_args(t) > 1
            t.nest_behavior = AlwaysNest
        end
        t.len += length(n)
    elseif max_padding >= 0
        t.len = max(t.len, length(n) + max_padding)
    else
        t.len += length(n)
    end

    if n.typ === Parameters
        if n.nest_behavior === AlwaysNest
            t.nest_behavior = n.nest_behavior
        end
        # no args before kwargs
        placeholder_ind = findfirst(n -> n.typ === PLACEHOLDER, tnodes)
        if placeholder_ind == length(tnodes)
            t[placeholder_ind] = Whitespace(0)
        end
        for nn in n.nodes
            push!(tnodes, nn)
            if n.startline < t.startline || t.startline == 0
                t.startline = n.startline
            end
            if n.endline > t.endline || t.endline == 0
                t.endline = n.endline
            end
        end
        return
    end

    push!(tnodes, n)
    return
end
