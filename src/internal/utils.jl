# This module contains helper functions to run formatting up until a certain point and to
# see the output, as well as some shorthands for test utilities. As the name suggests, these
# are for internal use only, and can break at any time.

module Internal

import JuliaSyntax as JS
import ..JuliaFormatter as JF
using Test

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

 - `:nest`: the nested FST.
 
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
    # :cst
    cst = JS.parseall(JS.GreenNode, text; version = JF.SUPPORTED_SYNTAX_VERSION)
    stage in (:gn, :cst) && return cst[1]

    # :fst
    opts = JF.Options(; merge(JF.options(style), options)...)
    state = JF.State(JF.Document(text), opts)
    fst = JF.pretty(style, cst, state)
    stage === :fst && return fst

    # :nest
    if JF.hascomment(state.doc, fst.endline)
        JF.add_node!(fst, JF.InlineComment(fst.endline), state)
    end
    JF.flatten_fst!(fst)
    if state.opts.short_circuit_to_if
        JF.short_circuit_to_if_pass!(fst, state)
    end
    if JF.needs_alignment(state.opts)
        JF.align_fst!(fst, state.doc, state.opts)
    end
    JF.nest!(style, fst, state)
    if state.opts.join_lines_based_on_source
        JF.remove_superfluous_whitespace!(fst)
    end
    stage === :nest && return fst

    # :out
    state.line_offset = 0
    io = IOBuffer()
    if fst.startline > 1
        JF.format_check(io, JF.Notcode(1, fst.startline - 1), state)
        JF.print_leaf(io, JF.Newline(), state)
    end
    JF.print_tree(io, fst, state)
    nlines = JF.numlines(state.doc)
    if state.on && fst.endline < nlines
        JF.print_leaf(io, JF.Newline(), state)
        JF.format_check(io, JF.Notcode(fst.endline + 1, nlines), state)
    end
    if state.doc.ends_on_nl
        JF.print_leaf(io, JF.Newline(), state)
    end
    out = String(take!(io))
    replacer = if state.opts.normalize_line_endings == "unix"
        JF.WINDOWS_TO_UNIX
    elseif state.opts.normalize_line_endings == "windows"
        JF.UNIX_TO_WINDOWS
    else
        JF.choose_line_ending_replacer(state.doc.srcfile.code)
    end
    out = JF.normalize_line_ending(out, replacer)
    stage === :out && return out

    stage === :print && return print(out)

    throw(ArgumentError("unknown stage: $stage"))
end

function _repro_hint(input, style, options)
    opts_str = if isempty(options)
        ""
    else
        "; " * join(["$k=$(repr(v))" for (k, v) in pairs(options)], ", ")
    end
    style_str = if style isa JF.DefaultStyle
        ""
    else
        ", $(typeof(style))()"
    end
    return "format_text($(repr(input))$(style_str)$(opts_str))"
end

"""
    JuliaFormatter.Internal.test_format(
        input::AbstractString,
        expected::AbstractString,
        [style::AbstractStyle=DefaultStyle();]
        ast::Bool=false,
        options...
    )

Test that formatting `input` produces `expected`, and that `expected` is idempotent under
formatting. If `ast=true` additionally tests that the input text and formatted text parse
to the same AST.
"""
function test_format(
    input::AbstractString,
    expected::AbstractString,
    style::JF.AbstractStyle = JF.DefaultStyle();
    ast::Bool = false,
    options...,
)
    out = JF.format_text(input, style; options...)
    if out != expected
        printstyled("Formatting output did not match expected value.\n\n"; color = :cyan)
        printstyled("Expected:\n$expected\n\n"; color = :green)
        printstyled("Got:\n$out\n\n"; color = :red)
        printstyled("Repro:\n$(_repro_hint(input, style, options))\n"; color = :cyan)
    end
    @test out == expected

    out2 = JF.format_text(out, style; options...)
    if out2 != out
        printstyled("Formatting was not idempotent.\n\n"; color = :cyan)
        printstyled("First pass:\n$out\n\n"; color = :green)
        printstyled("Second pass:\n$out2\n\n"; color = :red)
        printstyled("Repro:\n$(_repro_hint(out, style, options))\n"; color = :cyan)
    end
    @test out2 == out

    if ast
        ast_in = Meta.parse(input)
        ast_out = Meta.parse(out)
        if ast_in != ast_out
            printstyled("AST of input and output did not match.\n\n"; color = :cyan)
            printstyled("Input AST:\n$ast_in\n\n"; color = :green)
            printstyled("Output AST:\n$ast_out\n\n"; color = :red)
            printstyled("Repro:\n$(_repro_hint(input, style, options))\n"; color = :cyan)
        end
        @test ast_in == ast_out
    end
end

end # module
