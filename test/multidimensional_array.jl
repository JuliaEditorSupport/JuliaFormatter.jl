@testset "Multidimensional Arrays" begin
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

    @testset "wrapped hcat with ncat separators" begin
        separators = [";;", ";;;", ";;;;"]
        styles = (DefaultStyle(), YASStyle(), SciMLStyle())

        for sep in separators
            cases = (
                # Source form: hcat rows wrapped before the ncat separator.
                "x = [a\n     b$(sep)\n     c\n     d]",
                "x = T[a\n      b$(sep)\n      c\n      d]",
                # Formatted form: JuliaSyntax reparses this as hcat with separator tokens.
                "x = [a b$(sep)\n     c d]",
                "x = T[a b$(sep)\n      c d]",
            )

            for str in cases
                @test JuliaSyntax.parseall(JuliaSyntax.GreenNode, str) isa
                      JuliaSyntax.GreenNode

                for style in styles
                    formatted = format_text(str, style; join_lines_based_on_source = false)
                    @test JuliaSyntax.parseall(JuliaSyntax.GreenNode, formatted) isa
                          JuliaSyntax.GreenNode
                end
            end
        end
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
