module OptionsForToInTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, format_text
using JuliaFormatter.Internal: test_format, ALL_STYLES
using Test

@testset "for_to_in normalization" begin
    @testset "always convert `=` to `in` (for loops)" begin
        str_ = """
        for i = 1:n
            println(i)
        end"""
        str = """
        for i in 1:n
            println(i)
        end"""
        for style in ALL_STYLES
             test_format(str_, str, style; always_for_in = true)
        end

        str_ = """
        for i = I1, j in I2
            println(i, j)
        end"""
        str = """
        for i in I1, j in I2
            println(i, j)
        end"""
        for style in ALL_STYLES
            if style isa SciMLStyle
                @test_broken false
            else
                test_format(str_, str, style; always_for_in = true)
            end
        end

        str_ = """
        for i = 1:30, j = 100:-2:1
            println(i, j)
        end"""
        str = """
        for i in 1:30, j in 100:-2:1
            println(i, j)
        end"""
        for style in ALL_STYLES
            test_format(str_, str; always_for_in = true)
            test_format(str_, str_; always_for_in = nothing)
            test_format(str, str; always_for_in = nothing)
        end

        str_ = "[(i,j) for i=I1,j=I2]"
        str = "[(i, j) for i in I1, j in I2]"
        for style in ALL_STYLES
             test_format(str_, str, style; always_for_in = true)
        end

        str_ = "((i,j) for i=I1,j=I2)"
        str = "((i, j) for i in I1, j in I2)"
        for style in ALL_STYLES
             test_format(str_, str, style; always_for_in = true)
        end

        str_ = "[(i, j) for i = 1:2:10, j = 100:-1:10]"
        str = "[(i, j) for i in 1:2:10, j in 100:-1:10]"
        for style in ALL_STYLES
             test_format(str_, str, style; always_for_in = true)
        end

        str_ = "[i for i = 1:10 if i == 2]"
        str = "[i for i in 1:10 if i == 2]"
        for style in ALL_STYLES
             test_format(str_, str, style; always_for_in = true)
        end
    end

    @testset "for_in_replacement" begin
        str_ = """
        for a = b
        end
        """
        str = """
        for a ∈ b
        end
        """
        for style in ALL_STYLES
             test_format(str_, str, style; always_for_in = true, for_in_replacement = "∈")
        end

        # generator
        str_ = "[(i, j) for i = 1:2:10, j = 100:-1:10]"
        str = "[(i, j) for i ∈ 1:2:10, j ∈ 100:-1:10]"
        for style in ALL_STYLES
             test_format(str_, str, style; always_for_in = true, for_in_replacement = "∈")
        end

        str_ = "[i for i = 1:10 if i == 2]"
        str = "[i for i ∈ 1:10 if i == 2]"
        for style in ALL_STYLES
             test_format(str_, str, style; always_for_in = true, for_in_replacement = "∈")
        end

        @test_throws ArgumentError format_text(
            str_;
            always_for_in = true,
            for_in_replacement = "ni!",
        )
    end

    @testset "default" begin
        # non-range: = → in
        test_format("for i = xs\nend", "for i in xs\nend"; ast=true)
        test_format("[x for i = xs]", "[x for i in xs]"; ast=true)
        # range: in → =
        test_format("for i = 1:10\nend", "for i = 1:10\nend"; ast=true)
        test_format("[x for i in 1:2, j in 3:4]", "[x for i = 1:2, j = 3:4]"; ast=true)
    end

    @testset "always_for_in = true" begin
        for style in ALL_STYLES
            test_format("for i = 1:10\nend", "for i in 1:10\nend", style; always_for_in=true, ast=true)
            test_format("[x for i = 1:10]", "[x for i in 1:10]", style; always_for_in=true, ast=true)
        end
    end

    @testset "always_for_in = nothing (disabled)" begin
        for style in ALL_STYLES
            test_format("[x for i = xs]", "[x for i = xs]", style; always_for_in=nothing, ast=true)
            test_format("for i = xs\nend", "for i = xs\nend", style; always_for_in=nothing, ast=true)
        end
    end

    @testset "for_in_replacement" begin
        test_format("[x for i = xs]", "[x for i ∈ xs]"; always_for_in=true, for_in_replacement="∈", ast=true)
        test_format("[x for i = xs]", "[x for i = xs]"; always_for_in=true, for_in_replacement="=", ast=true)
    end

    @testset "multi-variable iteration" begin
        test_format("[x for i = xs, j = ys]", "[x for i in xs, j in ys]"; ast=true)
    end

    @testset "nested for" begin
        test_format("[x for i = xs for j = ys]", "[x for i in xs for j in ys]"; ast=true)
    end

    @testset "filter" begin
        test_format("[x for i = xs if i > 0]", "[x for i in xs if i > 0]"; ast=true)
    end

    @testset "body `=` is preserved" begin
        for T in ("", "T")
            # non-range iteration
            test_format("$(T)[x = f() for i = xs]", "$(T)[x = f() for i in xs]"; ast=true)
            test_format("$(T)[x = f() for i = xs]", "$(T)[x = f() for i in xs]"; always_for_in=true, ast=true)
            # range iteration
            test_format("$(T)[x = f() for i = 1:10]", "$(T)[x = f() for i = 1:10]"; ast=true)
            test_format("$(T)[x = f() for i = 1:10]", "$(T)[x = f() for i in 1:10]"; always_for_in=true, ast=true)
        end
    end

    @testset "body `in`/`∈` is preserved" begin
        test_format("[x in S for i = xs]", "[x in S for i in xs]"; ast=true)
        test_format("[x ∈ S for i = xs]", "[x ∈ S for i in xs]"; always_for_in=true, ast=true)
        # body `in` must not become `=` even with for_in_replacement = "="
        test_format(
            "[x in S for i in xs]",
            "[x in S for i = xs]";
            always_for_in=true,
            for_in_replacement="=",
            ast=true,
        )
    end

    @testset "body `=` with multi-variable iteration and filter" begin
        test_format(
            "[x = f(i, j) for i = xs, j = ys if g(i, j)]",
            "[x = f(i, j) for i in xs, j in ys if g(i, j)]";
            always_for_in=true,
            ast=true,
        )
        test_format("[x = y for i = xs for j = ys]", "[x = y for i in xs for j in ys]"; ast=true)
    end

    @testset "generator in function call" begin
        test_format("sum(x = f(i) for i = xs)", "sum(x = f(i) for i in xs)"; ast=true)
        test_format(
            "Iterators.flatten(x = y for y = zs if y in allowed for zs = xss)",
            "Iterators.flatten(x = y for y in zs if y in allowed for zs in xss)";
            ast=true,
        )
    end

    @testset "nested comprehensions" begin
        test_format(
            "[[x = f() for j = ys] for i = xs]",
            "[[x = f() for j in ys] for i in xs]";
            ast=true,
        )
        test_format(
            "collect(x = y for y = (a = b for a = xs))",
            "collect(x = y for y in (a = b for a in xs))";
            ast=true,
        )
    end

    @testset "BlueStyle (always_for_in = true by default)" begin
        test_format("[x = f() for i = xs]", "[x = f() for i in xs]", BlueStyle(); ast=true)
        test_format("[x in S for i = xs]", "[x in S for i in xs]", BlueStyle(); ast=true)
    end

    @testset "SciMLStyle (always_for_in = true by default)" begin
        test_format("[x = f() for i = xs]", "[x = f() for i in xs]", SciMLStyle(); ast=true)
    end
end

end
