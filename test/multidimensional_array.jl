module MultidimensionalArrayTests

using JuliaFormatter
using JuliaFormatter.Internal: test_format
using Test

ALL_STYLES = (DefaultStyle(), YASStyle(), BlueStyle(), MinimalStyle(), SciMLStyle())

@testset "array literal examples" begin
    # Don't really care how it formats, but make sure that it parses to the same AST. Some
    # of these are probably redundant; that's fine, we can just be safe.
    for T in ("", "T")
        for s in (
            # These are taken from the docs:
            # https://docs.julialang.org/en/v1/manual/arrays/#man-array-literals
            "$(T)[1, 2, 3]",
            "$(T)[1, 2.3, 4//5]",
            "$(T)[1:2, 4:5]",
            "$(T)[1:2\n 4:5\n 6]",
            "$(T)[1:2  4:5  7:8]",
            "$(T)[[1,2]  [4,5]  [7,8]]",
            "$(T)[1 2 3]",
            "$(T)[1;; 2;; 3;; 4]",
            "$(T)[1 2\n 3 4]",
            "$(T)[zeros(Int, 2, 2) [1; 2]\n [3 4]            5]",
            "$(T)[[1 1]; 2 3; [4 4]]",
            "$(T)[zeros(Int, 2, 2) ; [3 4] ;; [1; 2] ; 5]",
            "$(T)[1:2; 4;; 1; 3:4]",
            "$(T)[1; 2;; 3; 4;; 5; 6;;;\n 7; 8;; 9; 10;; 11; 12]",
            "$(T)[1 3 5\n 2 4 6;;;\n 7 9 11\n 8 10 12]",
            "$(T)[1 2;;; 3 4;;;; 5 6;;; 7 8]",
            "$(T)[[1 2;;; 3 4];;;; [5 6];;; [7 8]]",
            "$(T)[1 2 ;;\n 3 4]",
            "$(T)[1;;]",
            "$(T)[2; 3;;;]",
            "$(T)[[1 2] [3 4]]",

            # These are supplements, not from the docs
            "$(T)[1\n2;;\n3\n4]",
            "$(T)[f(a)\n f(a);;\n f(a)\n f(a)]",
        )
            for style in ALL_STYLES
                @testset let style = style
                    out1 = format_text(s, style)
                    out2 = format_text(out1, style)
                    @test out1 == out2
                    @test Meta.parse(out1) == Meta.parse(s)
                end
            end
        end
    end
end

@testset "hcat and typed_hcat nodes" begin
    # hcat nodes are the ones without T; typed_hcat nodes are the ones with T. Both
    # should more or less be formatted the same way.
    for T in ("", "T")
        @testset "spaces only" begin
            # Additionally check that superfluous whitespace is removed.
            for s in ("x = $(T)[a b]", "x = $(T)[a      b     ]")
                for style in ALL_STYLES
                    test_format(s, "x = $(T)[a b]", style)
                end
                test_format(s, "x = $(T)[\n    a b\n]"; margin = 5+length(T))

                # TODO(penelopeysm): The indentation for other styles is all over the
                # place. But we can at least check for now that it parses to the same
                # AST (meaning that at worst, it's ugly, but not wrong), and that it's
                # idempotent.
                for style in ALL_STYLES,
                    kwargs in
                    ((;), (; margin = 5+length(T)), (; join_lines_based_on_source = false))

                    out1 = format_text(s, style; kwargs...)
                    out2 = format_text(out1, style; kwargs...)
                    @test out1 == out2
                    @test Meta.parse(out1) == Meta.parse(s)
                end
            end
        end

        @testset ";;\\n only" begin
            for s in ("x = $(T)[a;;\n b]", "x = $(T)[a    ;;\n   b   ]")
                # because the original matrix is already split across a newline,
                # the formatter will insert more newlines
                expected_default = "x = $(T)[\n    a;;\n    b\n]"
                test_format(s, expected_default)
                test_format(s, expected_default; margin = 5+length(T))

                ws = " " ^ (5 + length(T))
                expected_sciml = "x = $(T)[a;;\n$(ws)b]"
                test_format(s, expected_sciml, SciMLStyle())
                test_format(s, expected_sciml, SciMLStyle(); margin = 5+length(T))
                test_format(s, expected_sciml, YASStyle())
                test_format(s, expected_sciml, YASStyle(); margin = 5+length(T))
            end
        end

        @testset "mixture of space and ;;\\n" begin
            for s in ("x = $(T)[a b;;\n c d]", "x = $(T)[a    b   ;;\n   c    d   ]")
                # because the original matrix is already split across a newline,
                # the formatter will insert more newlines
                expected = "x = $(T)[\n    a b;;\n    c d\n]"
                test_format(s, expected)
                test_format(s, expected; margin = 5+length(T))

                # TODO(penelopeysm): The indentation for other styles is all over the
                # place. But we can at least check for now that it parses to the same
                # AST (meaning that at worst, it's ugly, but not wrong), and that it's
                # idempotent.
                for style in ALL_STYLES,
                    kwargs in
                    ((;), (; margin = 5+length(T)), (; join_lines_based_on_source = false))

                    out1 = format_text(s, style; kwargs...)
                    out2 = format_text(out1, style; kwargs...)
                    @test out1 == out2
                    @test Meta.parse(out1) == Meta.parse(s)
                end
            end
        end
    end
end

@testset "#490" begin
    @testset "DefaultStyle" begin
        str = "[1;; 2]"
        test_format(str, str)

        str_ = """
        [
            1;;
            2
        ]"""
        test_format(str, str_; margin = 1)

        str = "T[1;; 2]"
        test_format(str, str)

        str_ = """
        T[
            1;;
            2
        ]"""
        test_format(str, str_; margin = 1)
    end

    @testset "YASStyle" begin
        str = "[1;; 2]"
        test_format(str, str, YASStyle())

        str_ = """
        [1;;
         2]"""
        test_format(str, str_, YASStyle(); margin = 1)

        str = "T[1;; 2]"
        test_format(str, str, YASStyle())

        str_ = """
        T[1;;
          2]"""
        test_format(str, str_, YASStyle(); margin = 1)
    end
end

@testset "#620" begin
    s = "[1; 0;;]"
    test_format(s, s)
    test_format(s, s, YASStyle())
end

@testset "#582" begin
    test_format("[a;b;;]", "[a; b;;]", YASStyle())
end

@testset "#608" begin
    s1 = """
    hcat([zeros(1); ones(3)], [zeros(2); ones(2)], [zeros(3); ones(1)], [zeros(1); ones(3)], [zeros(2); ones(2)], [zeros(3); ones(1)])
    """
    s2 = """
    hcat([zeros(1); ones(3)], [zeros(2); ones(2)], [zeros(3); ones(1)], [zeros(1); ones(3)],
         [zeros(2); ones(2)], [zeros(3); ones(1)])
    """
    test_format(s1, s2, YASStyle())
end

@testset "#532" begin
    s = "(; a = [1;;], b = cos[2;;])"
    s_nospace = "(; a=[1;;], b=cos[2;;])"
    for style in (DefaultStyle(), SciMLStyle())
        test_format(s, s, style)
    end
    # whitespace_around_kwarg = false
    for style in (BlueStyle(), YASStyle(), MinimalStyle())
        test_format(s, s_nospace, style)
    end
end

end # module
