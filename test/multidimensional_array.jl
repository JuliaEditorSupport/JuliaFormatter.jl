@testset "Multidimensional Arrays" begin
    @testset "hcat and typed_hcat nodes" begin
        # hcat nodes are the ones without T; typed_hcat nodes are the ones with T. Both
        # should more or less be formatted the same way.
        for T in ("", "T")
            @testset "spaces only" begin
                # Additionally check that superfluous whitespace is removed.
                for s in (
                    "x = $(T)[a b]",
                    "x = $(T)[a      b     ]",
                    )
                    @test fmt(s) == "x = $(T)[a b]"
                    @test fmt(s, 4, 5+length(T)) == "x = $(T)[\n    a b\n]"
                end
            end

            @testset ";;\\n only" begin
                for s in (
                    "x = $(T)[a;;\n b]",
                    "x = $(T)[a    ;;\n   b   ]",
                    )
                    # because the original matrix is already split across a newline,
                    # the formatter will insert more newlines
                    expected = "x = $(T)[\n    a;;\n    b\n]"
                    @test fmt(s) == expected
                    @test fmt(s, 4, 5+length(T)) == expected
                end
            end

            @testset "mixture of space and ;;\\n" begin
                for s in (
                    "x = $(T)[a b;;\n c d]",
                    "x = $(T)[a    b   ;;\n   c    d   ]",
                    )
                    # because the original matrix is already split across a newline,
                    # the formatter will insert more newlines
                    expected = "x = $(T)[\n    a b;;\n    c d\n]"
                    @test fmt(s) == expected
                    @test fmt(s, 4, 5+length(T)) == expected
                end
            end
        end
    end

    @testset "#490" begin
        @testset "DefaultStyle" begin
            str = "[1;; 2]"
            @test fmt(str) == str

            str_ = """
            [
                1;;
                2
            ]"""
            @test fmt(str, 4, 1) == str_

            str = "T[1;; 2]"
            @test fmt(str) == str

            str_ = """
            T[
                1;;
                2
            ]"""
            @test fmt(str, 4, 1) == str_
        end

        @testset "YASStyle" begin
            str = "[1;; 2]"
            @test yasfmt(str) == str

            str_ = """
            [1;;
             2]"""
            @test yasfmt(str, 4, 1) == str_

            str = "T[1;; 2]"
            @test yasfmt(str) == str

            str_ = """
            T[1;;
              2]"""
            @test yasfmt(str, 4, 1) == str_
        end
    end

    @testset "#620" begin
        s = "[1; 0;;]"
        @test fmt(s) == s
        @test yasfmt(s) == s
    end

    @testset "#582" begin
        @test yasfmt("[a;b;;]") == "[a; b;;]"
    end

    @testset "#608" begin
        s1 = """
        hcat([zeros(1); ones(3)], [zeros(2); ones(2)], [zeros(3); ones(1)], [zeros(1); ones(3)], [zeros(2); ones(2)], [zeros(3); ones(1)])
        """
        s2 = """
        hcat([zeros(1); ones(3)], [zeros(2); ones(2)], [zeros(3); ones(1)],
             [zeros(1); ones(3)], [zeros(2); ones(2)], [zeros(3); ones(1)])
        """
        @test yasfmt(s1) == s2
    end

    @testset "#532" begin
        s = "(; a = [1;;], b = cos[2;;])"
        @test fmt(s) == s
        @test bluefmt(s) == s
        @test yasfmt(s) == s
        @test format_text(s, SciMLStyle()) == s
        @test minimalfmt(s) == s
    end
end
