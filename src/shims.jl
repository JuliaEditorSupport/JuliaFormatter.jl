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
- `.<:(x)`  ->   K"call" (with a dotted caller)
- `<:(x)`   ->   K"<:", caught by is_type_operator
- `.<:(x)`  ->   K"call" (with a dotted caller)

`<:` and `>:` are special-cased by JuliaSyntax to return K"<:" and K">:" nodes but from a
syntax perspective we want to treat them the same as any other function.

We then need to exclude two things:

- applications of unary operators, for example, `+x`, `-x`, and `<:x`. These are still
  parsed as K"call" but these can be identified by the fact that
  `JuliaSyntax.is_prefix_op_call` returns `true` for these.

- bare operators, easily identified by `is_leaf`.

Note: `JuliaSyntax.is_prefix_call` *sounds* like the right thing to check, but for some
reason this returns `true` for tons of things we don't care about. For example:

```julia
julia> JS.is_prefix_call(JS.parseall(JS.GreenNode, "1")[1])
true
```
"""
function is_function_call(cst::JS.GreenNode)
    return (
        (kind(cst) in KSet"call dotcall" || JS.is_type_operator(cst)) &&
        !JuliaSyntax.is_leaf(cst) &&
        !JuliaSyntax.is_prefix_op_call(cst)
    )
end

end # module
