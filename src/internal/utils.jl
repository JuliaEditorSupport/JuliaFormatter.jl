# This module contains helper functions to run formatting up until a certain point and to
# see the output, as well as some shorthands for test utilities. As the name suggests, these
# are for internal use only, and can break at any time.

module Internal

import JuliaSyntax as JS
import ..JuliaFormatter as JF

"""
    JuliaFormatter.Internal.format_to_stage(
        stage::Symbol,
        text::AbstractString,
        [style=DefaultStyle(),]
        options...
    )

Run formatting on a given string up until a certain stage, and return the output of that
stage.

Available stages:

 - `:gn` or `:cst`: the output of the JuliaSyntax parser, which is a
   `JuliaSyntax.GreenNode`. Note that directly calling `JuliaSyntax.parseall` will yield a
   `toplevel` node with the actual tree of interest as its only child. This function will
   directly return the child.

 - `:fst`: the output of prettification.
 
 - `:out`: the string output of the formatter.

 - `:print`: the string output but printed. Saves you having to wrap it in `print()`.

!!! tip
    For a utility that is meant to be convenient to access, typing the full qualified
    name can be a bit of a hassle! If you are using this function a lot, you may want
    to use [BasicAutoloads.jl](https://github.com/LilithHafner/BasicAutoloads.jl) to
    automatically import it, and possibly even with a shorter name. For example, you
    can add something like this to your `~/.julia/config/startup.jl`:

    ```julia
    if isinteractive()
        import BasicAutoloads
        BasicAutoloads.register_autoloads([
            ["fs"] => :(using JuliaFormatter.Internal: format_to_stage as fs),
        ])
    end
    ```

    and then just call `fs(:gn, "1 + 2")` from the REPL without having to import it.
"""
function format_to_stage(
    stage::Symbol,
    text::AbstractString,
    style::JF.AbstractStyle = JF.DefaultStyle();
    options...,
)
    cst = JS.parseall(JS.GreenNode, text)
    stage in (:gn, :greennode, :parse, :cst) && return cst[1]

    opts = JF.Options(; merge(JF.options(style), options)...)
    state = JF.State(JF.Document(text), opts)
    fst = JF.pretty(style, cst, state)
    stage === :fst && return fst

    throw(ArgumentError("unknown stage: $stage"))
end

end # module
