# Shims that provide higher-level functionality for JuliaFormatter to use.

module Shims

using JuliaSyntax
using JuliaSyntax: @KSet_str, @K_str, JuliaSyntax as JS

"""
Determine if a CST represents a function call, i.e., `F(X1, X2, ...)` syntactically.

This covers, for example:

- `f(x)`    ->   K"call"
- `f.(x)`   ->   K"dotcall"
- `<=(x)`   ->   K"call"
- `.<=(x)`  ->   K"call" (with a dotted caller)
- `<:(x)`   ->   K"<:", caught by is_type_operator
- `.<:(x)`  ->   K"call" (with a dotted caller)

`<:` and `>:` are special-cased by JuliaSyntax to return K"<:" and K">:" nodes rather than
K"call", but from a syntax perspective we want to treat them the same as any other function.

We then need to exclude a few things:

- applications of unary operators, for example, `+x`, `-x`, and `<:x`. These are still
  parsed as K"call" but these can be identified by the fact that
  `JuliaSyntax.is_prefix_op_call` returns `true` for these. BUT, we don't want to exclude
  the parenthesised versions +(x), -(x) since these do *look* like function calls (and we
  only care about the syntax, not the semantics)! So need some custom logic to identify
  these...

- bare operators, easily identified by `is_leaf`.

- infix operators, for which `JuliaSyntax.is_infix_op_call` USUALLY returns `true` (but
  not for `a <: b` --- hence why we instead do a check for K"(").

Note: `JuliaSyntax.is_prefix_call` *sounds* like the right thing to check, but for some
reason this returns `true` for tons of things we don't care about. For example:

```julia
julia> JS.is_prefix_call(JS.parseall(JS.GreenNode, "1")[1])
true
```
"""
function is_function_call(cst::JS.GreenNode)
    JS.is_leaf(cst) && return false
    return if JS.is_type_operator(cst)
        any(c -> kind(c) in KSet"( parens", JS.children(cst))
    elseif kind(cst) in KSet"call dotcall"
        if JS.is_infix_op_call(cst)
            false
        elseif JS.is_prefix_op_call(cst)
            # reject +x but not +(x)
            non_ws_idxs = findall(n -> !JS.is_whitespace(n), JS.children(cst))
            if kind(cst) == K"call"
                length(non_ws_idxs) < 2 &&
                    error("unreachable: prefix call with not enough things")
                kind(cst[non_ws_idxs[2]]) in KSet"( parens"
            elseif kind(cst) == K"dotcall"
                length(non_ws_idxs) < 3 &&
                    error("unreachable: prefix call with not enough things")
                kind(cst[non_ws_idxs[3]]) in KSet"( parens"
            end
        else
            true
        end
    else
        false
    end
end

"""
    is_caller_in_function_def(t::JuliaSyntax.GreenNode) -> Bool

Identify the caller in a function definition, i.e., the `f(...)` part in

    function f(...)
        body
    end

This may be more complicated than just `is_function_call`, because the caller may be
`f(...)::T`, `f(...) where T`, or (f(...)) (or combinations thereof).
"""
function is_caller_in_function_def(t::JuliaSyntax.GreenNode)::Bool
    return if is_function_call(t)
        true
    elseif kind(t) in KSet":: where parens" && !JS.is_leaf(t)
        childs = JS.children(t)
        idx = findfirst(n -> !JS.is_whitespace(n) && !(kind(n) in KSet"( )"), childs)
        !isnothing(idx) && is_caller_in_function_def(childs[idx])
    else
        false
    end
end

"""
    is_valid_nonword_operator(s::AbstractString) -> Bool

Check whether the string `s` is a valid operator in Julia, via JuliaSyntax.

Excludes word operators (i.e., `in`, `isa`, and `where`)..
"""
function is_valid_nonword_operator(s::AbstractString)
    try
        k = JS.Kind(s)
        return JS.is_operator(k) && !JS.is_word_operator(k)
    catch
        return false
    end
end

end # module
