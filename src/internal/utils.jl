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

 - (:gn, :greennode, :parse): the output of the JuliaSyntax parser, which is a
   `JuliaSyntax.GreenNode`.

This is the only stage currently implemented, but more will be added in the future.

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
"""
function format_to_stage(
    stage::Symbol,
    text::AbstractString,
    style::JF.AbstractStyle = JF.DefaultStyle();
    options...,
)
    parsed = JS.parseall(JS.GreenNode, text)
    stage in (:gn, :greennode, :parse) && return parsed

    throw(ArgumentError("unknown stage: $stage"))
end

end # module
