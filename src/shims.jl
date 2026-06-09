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

`<:` and `>:` are special-cased by JuliaSyntax to return K"<:" and K">:" nodes but from a
syntax perspective we want to treat them the same as any other function.

We then need to exclude a few things:

- applications of unary operators, for example, `+x`, `-x`, and `<:x`. These are still
  parsed as K"call" but these can be identified by the fact that
  `JuliaSyntax.is_prefix_op_call` returns `true` for these.

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
        # Distinguish `<:(a, b)` (prefix call -- has a bare K"(" child) from `a <: b` (infix
        # -- no `(`) and `<:x` / `<:(a)` (unary -- if the argument is parenthesised, then
        # it's a K"parens" node rather than K"(").
        #
        # The first child will be `<:` and if there is a paren, it must be the second child.
        length(JS.children(cst)) >= 2 && kind(cst[2]) == K"("
    elseif kind(cst) in KSet"call dotcall"
        # For K"call" nodes the flags can be reliably used.
        !JS.is_prefix_op_call(cst) && !JS.is_infix_op_call(cst)
    else
        false
    end
end

end # module
