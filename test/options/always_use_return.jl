module AlwaysUseReturnTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, format_text
using JuliaFormatter.Internal: test_format
using Test

@testset "always_use_return" begin
    @testset "option disabled: no return added" begin
        str = """
        function foo()
            expr1
            expr2
        end
        """
        test_format(str, str; always_use_return = false)
    end

    @testset "not in function/macro/do body: no return added" begin
        str = """
        begin
            expr1
            expr2
        end
        """
        test_format(str, str; always_use_return = true)
    end

    @testset "last statement is already return" begin
        str = """
        function foo()
            expr1
            return expr2
        end
        """
        test_format(str, str; always_use_return = true)
    end

    @testset "docstring-preceded statement is left alone (#405)" begin
        str = """
        function foo()
            \"\"\"docstring\"\"\"
            bar
        end
        """
        test_format(str, str; always_use_return = true)
    end

    @testset "short-to-long function def" begin
        # NOTE(penelopeysm): This is cursed because it uses prepend_return_fst!.
        # Very easy to trigger idempotence failures!
        str_ = "foo(a) = bodybodybody"
        str = """
        function foo(a)
            return bodybodybody
        end"""
        test_format(
            str_,
            str;
            short_to_long_function_def = true,
            always_use_return = true,
        )
    end

    @testset "function body" begin
        str_ = """
        function foo()
            expr1
            expr2
        end"""
        str = """
        function foo()
            expr1
            return expr2
        end"""
        test_format(str_, str; always_use_return = true)
    end

    @testset "macro body" begin
        str_ = """
        macro foo()
            expr1
            expr2
        end"""
        str = """
        macro foo()
            expr1
            return expr2
        end"""
        test_format(str_, str; always_use_return = true)
    end

    @testset "do block" begin
        str_ = """
        map(arg1, arg2) do x, y
            expr1
            expr2
        end"""
        str = """
        map(arg1, arg2) do x, y
            expr1
            return expr2
        end"""
        test_format(str_, str; always_use_return = true)
    end

    @testset "cases where we don't want to insert return" begin
        @testset "already has return" begin
            # Technically the idempotence tests already catch this, but may as well be
            # explicit
            str = """
            function foo()
                expr1
                return expr2
            end"""
            test_format(str, str; always_use_return = true)
        end

        @testset "macros" begin
            str = """
            function foo()
                @macrocall(expr2)
            end"""
            test_format(str, str; always_use_return = true)

            str = """
            function foo()
                @macroblock expr2
            end"""
            test_format(str, str; always_use_return = true)
        end

        @testset "blocks" begin
            str = """
            function foo()
                for i = 1:10
                    println(i)
                end
            end"""
            test_format(str, str; always_use_return = true)

            str = """
            function f(a)
                if a > 0
                    return -1
                else
                    return 1
                end
            end"""
            test_format(str, str; always_use_return = true)
        end

        @testset "expressions containing returns" begin
            str = """
            function f()
                (1 + 1; return 2)
            end
            """
            test_format(str, str; always_use_return = true)

            str = """
            function foo(x)
                x > 0 ? (return 1) : (return 2)
            end
            """
            test_format(str, str; always_use_return = true)

            str = """
            function foo(x)
                x > 0 ? (return 1) : 2
            end
            """
            test_format(str, str; always_use_return = true)

            for op in ("&&", "||")
                str = """
                function foo(x)
                    x > 0 $op (return 1)
                end
                """
                test_format(str, str; always_use_return = true)
            end
        end
    end
end

end
