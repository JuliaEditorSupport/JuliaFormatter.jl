module TrailingCommaTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, format_text
using JuliaFormatter.Internal: test_format
using Test

@testset "trailing_comma" begin
    @testset "remove trailing comma" begin
        for str_ in (
            "funccall(arg1, arg2, arg3,)",
            "funccall(arg1, arg2, arg3)",
        )
            str = """
            funccall(
                arg1,
                arg2,
                arg3
            )"""
            test_format(str_, str; margin=1, trailing_comma = false)
        end

        str_ = "funccall(arg1, arg2, arg3,)"
        str = "funccall(arg1, arg2, arg3)"
        test_format(str_, str; trailing_comma = false)
    end

    @testset "doesn't change tuples" begin
        str_ = "(tuple,)"
        str = """
        (
            tuple,
        )"""
        test_format(str_, str; margin=1, trailing_comma = true)
        test_format(str_, str; margin=1, trailing_comma = false)
        test_format(str_, str; indent=4, margin=1, trailing_comma = nothing)
    end

    @testset "trailing_comma=nothing" begin
        str = """
        funccall(
            arg1,
            arg2,
            arg3
        )"""
        str_ = "funccall(arg1, arg2, arg3)"
        test_format(str_, str; indent=4, margin=1, trailing_comma = nothing)

        # last comma is stays
        str_ = "funccall(arg1, arg2, arg3,)"
        str = """
        funccall(
            arg1,
            arg2,
            arg3,
        )"""
        test_format(str_, str; indent=4, margin=1, trailing_comma = nothing)
        test_format(str_, str_; indent=4, margin=100, trailing_comma = nothing)
    end

    @testset "YASStyle" begin
        # Ordinarily with YAS, the closing paren is placed on the same line as the last
        # argument, meaning that there are no trailing commas. But if the last argument is
        # followed by a comment, the closing paren will be on the next line, and a trailing
        # comma should be added (or to be precise, the `trailing_comma` option should be
        # respected).
        s1 = """
        f(aaaaaaa,
          bbbbbbbbb,
          ccccccccc # comment
        )"""
        s1 = """
        f(aaaaaaa,
          bbbbbbbbb,
          ccccccccc, # comment
          )"""
        test_format(s1, s1, YASStyle(); margin=2)

        s2_ = """
        f(aaaaaaa,
          bbbbbbbbb,
          ccccccccc
        )"""
        s2 = """
        f(aaaaaaa,
          bbbbbbbbb,
          ccccccccc)"""
        test_format(s2_, s2, YASStyle(); margin=2)
    end

    @testset "constructs that fail to parse if trailing commas are added" begin
        # see e.g. #1017 and #1269 -- this is a more general version of those issues.
        brackets = (("g(", ")"), ("[", "]"), ("{", "}"), ("T{", "}"))
        statements = ("return xxxxxxx", "local xxxxxxx", "global xxxxxxx", "@m xxxxxxx")
        cases = vcat(
            ["$open$statement$close" for (open, close) in brackets for statement in statements],
            [
                # this is `fff(x -> return (x, y))`, i.e. `return` takes the tuple `x, y`
                "fff(x -> return x, y)",
                "g(return xxxx, yyyy)",
                "g(return (xxxx, yyyy))",
                "[return xxxx, yyyy]",
                "{return xxxx, yyyy}",
                "(aaaa, return xxxx, yyyy)",
                # indexing with a single index is never split over lines, so we need two here
                "a[iiii, return xxxx, yyyy]",
                "g(local xxxx, yyyy)",
                "g(global xxxx, yyyy)",
                "g(const xxxx = 1)",
                "g(aaaa && return bbbb)",
                "g(aaaa; k = return bbbb)",
                "g(x -> @m yyyy)",
            ],
        )
        for s in cases
            for style in ALL_STYLES,
                margin in (8, 12, 20),
                trailing_comma in (true, false, nothing)

                # The trailing comma bug can only happen if the list is nested, so check
                # that it actually was -- otherwise the test is vacuous
                @test occursin('\n', format_text(s; margin))
                test_format(s, nothing, style; margin, trailing_comma, ast=true)
            end
        end

        # BlueStyle turns the ternary into `if ... else ... end` and YASStyle moves the
        # keyword argument after a `;`, so the AST changes and we can't use `ast=true`.
        for s in ("g(cccc ? aaaa : return bbbb)", "g(a = return bbbb)")
            @test occursin('\n', format_text(s; margin=8))
            for style in ALL_STYLES, margin in (8, 12, 20)
                test_format(s, nothing, style; margin)
            end
        end
    end
end

end # module
