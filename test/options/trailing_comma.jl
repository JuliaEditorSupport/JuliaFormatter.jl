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
end

end # module
