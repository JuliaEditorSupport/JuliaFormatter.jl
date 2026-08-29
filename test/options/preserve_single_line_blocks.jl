module PreserveSingleLineBlocksTests

using JuliaFormatter: YASStyle, SciMLStyle
using JuliaFormatter.Internal: test_format
using Test

@testset "preserve_single_line_blocks" begin
    @testset "single-line constructs are preserved" begin
        unchanged = [
            "try isfile(x); catch; false end",
            "try; isfile(x); catch; false end",
            "try isfile(x) catch end",
            "try isfile(x) catch e; e else g() finally h() end",
            "let x = 1; x end",
            "let; x end",
            "if x; y end",
            "if x; end",
            "if x; y else z end",
            "if x; y elseif w; z else q end",
            "for i = 1:10; f(i) end",
            "while x; f() end",
            "function f(); 1 end",
            "macro m(); 1 end",
            "foo() do x; x + 1 end",
            "struct A; x::Int end",
            "mutable struct B; x::Int end",
            "module M; f() = 1 end",
            "baremodule Q; f() = 1 end",
            "begin x = 1; y = 2 end",
            "begin end",
            "quote x = 1; y end",
            "quote end",
            # nested single-line constructs
            "let x = 1; if x; 1 end end",
            "quote begin end end",
            "x = :(let a; b end)",
            "y = [begin x end for i = 1:3]",
        ]
        for c in unchanged
            test_format(c, c; preserve_single_line_blocks=true, ast=true)
        end
    end

    @testset "multi-line constructs are still expanded" begin
        str = """
        try
            isfile(x)
        catch
            false
        end"""
        test_format(str, str; preserve_single_line_blocks=true, ast=true)

        # A single-line `elseif`/`else`/`catch` clause inside a multi-line construct is
        # expanded along with the rest of the construct.
        str_ = """
        if x
            f
        elseif y; g else; h; end"""
        str = """
        if x
            f
        elseif y
            g
        else
            h
        end"""
        test_format(str_, str; preserve_single_line_blocks=true, ast=true)

        str_ = """
        try
            f()
        catch e; g(e); end"""
        str = """
        try
            f()
        catch e
            g(e)
        end"""
        test_format(str_, str; preserve_single_line_blocks=true, ast=true)
    end

    @testset "option disabled" begin
        str_ = "try isfile(x); catch; false end"
        str = """
        try
            isfile(x)
        catch
            false
        end"""
        test_format(str_, str; ast=true)
        test_format(str_, str; preserve_single_line_blocks=false, ast=true)
        # YAS and SciML enable join_lines_based_on_source but still expand one-liners.
        test_format(str_, str, YASStyle(); ast=true)
        test_format(str_, str, SciMLStyle(); ast=true)
    end

    @testset "short-form function definition" begin
        # The block on the RHS keeps its single-line form. (The line break after `=` is a
        # separate issue, #594.)
        test_format(
            "safe_isfile(x) = try isfile(x); catch; false end",
            "safe_isfile(x) =\n    try isfile(x); catch; false end";
            preserve_single_line_blocks=true,
            ast=true,
        )
    end

    @testset "comments inside blocks" begin
        unchanged = [
            "if x; #= c =# y end",
            "if x; y #= c =# end",
            "if x; y #= c =# else #= d =# z end",
            "for i = 1:10; #= c =# f(i) end",
            "for i = 1:10; f(i) #= c =# end",
            "while x; f() #= c =# end",
            "function f(); #= c =# 1 end",
            "function f(); 1 #= c =# end",
            "try f() #= c =# catch #= d =# end",
            "try #= c =# f() catch e; #= d =# g(e) end",
            "let x = 1; #= c =# x end",
            "let x = 1; x #= c =# end",
            "begin #= c =# x end",
            "begin x #= c =# end",
            "struct A; #= c =# x::Int end",
            "struct A; x::Int #= c =# end",
            "foo() do x; #= c =# x + 1 end",
        ]
        for c in unchanged
            test_format(c, c; preserve_single_line_blocks=true, ast=true)
        end

        # The `;` before an empty function body is dropped (as without the option), but
        # the comment stays on the line.
        test_format(
            "function f(); #= c =# end",
            "function f() #= c =# end";
            preserve_single_line_blocks=true,
            ast=true,
        )

        # A line comment (`#`) necessarily ends the line, so such constructs are
        # multi-line and are expanded.
        str_ = "if x; y # c\nend"
        str = """
        if x
            y # c
        end"""
        test_format(str_, str; preserve_single_line_blocks=true, ast=true)
    end

    @testset "annotate_untyped_fields_with_any" begin
        # (No `ast=true`: adding `::Any` changes the AST by design.)
        opts = (preserve_single_line_blocks=true, annotate_untyped_fields_with_any=true)
        test_format("struct Foo x end", "struct Foo x::Any end"; opts...)
        test_format("struct Foo; x end", "struct Foo; x::Any end"; opts...)
        test_format(
            "mutable struct Foo; x; y::Int end",
            "mutable struct Foo; x::Any; y::Int end";
            opts...,
        )
        test_format("struct Foo; x::Int end", "struct Foo; x::Int end"; opts...)
    end

    @testset "docstrings force expansion" begin
        # A docstring is always emitted on its own line, so a construct containing one
        # can't be kept on a single line and is expanded as usual.
        str_ = "eval(quote \"Second docstring\" Module29432 end)"
        str = """
        eval(quote
            "Second docstring"
            Module29432
        end)"""
        test_format(str_, str; preserve_single_line_blocks=true, ast=true)

        str_ = "module M; \"doc\" f() = 1 end"
        str = """
        module M
        "doc"
        f() = 1
        end"""
        test_format(str_, str; preserve_single_line_blocks=true, ast=true)
    end

    @testset "idempotence regressions from the integration tests" begin
        # JuliaLang/julia/base/shell.jl: a single-line `else; x; end` clause of a
        # multi-line `if`.
        str_ = """
        if redirect_mode === :stdin; seg_stdin = re
        elseif redirect_mode === :stdout; seg_stdout = re
        else; seg_stderr = re; end"""
        str = """
        if redirect_mode === :stdin
            seg_stdin = re
        elseif redirect_mode === :stdout
            seg_stdout = re
        else
            seg_stderr = re
        end"""
        test_format(str_, str; preserve_single_line_blocks=true, ast=true)

        # JuliaLang/julia/test/syntax.jl: parenthesised block inside a single-line macro.
        str = raw"macro z49984(s); :(let a; $(esc(s)); end); end"
        test_format(str, str; preserve_single_line_blocks=true, ast=true)

        # JuliaStats/StatsModels.jl: empty block nested inside a single-line quote.
        str = "result = quote begin end end"
        test_format(str, str; preserve_single_line_blocks=true, ast=true)
    end
end

end # module
