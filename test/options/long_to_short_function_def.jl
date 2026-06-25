module LongToShortFunctionDefTests

using JuliaFormatter.Internal: test_format, ALL_STYLES
using Test

@testset "long_to_short_function_def" begin
    @testset "basic" begin
        str_ = """
        function foo(a)
            bodybodybody
        end"""
        str = "foo(a) = bodybodybody"
        test_format(str_, str_; indent=4, margin=length(str) - 1, long_to_short_function_def=true)
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def=true)

        str_ = """
        function foo(a::T) where {T}
            bodybodybodybodybodybodyb
        end"""
        str = "foo(a::T) where {T} = bodybodybodybodybodybodyb"
        test_format(str_, str_; indent=4, margin=length(str) - 1, long_to_short_function_def=true)
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def=true)

        str_ = """
        function foo(a::T)::R where {T}
            bodybodybodybodybodybodybody
        end"""
        str = "foo(a::T)::R where {T} = bodybodybodybodybodybodybody"
        test_format(str_, str_; indent=4, margin=length(str) - 1, long_to_short_function_def=true)
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def=true)

        str_ = """
        function foo(a)
            return a + 1
        end"""
        str = "foo(a) = a + 1"
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def=true)

        str = """
        function foo()
            expr1
            expr2
        end"""
        test_format(str, str; indent=4, margin=length(str), long_to_short_function_def=true)

        str_ = """
        function foo(a)
            return if a > 1
                2
            else
                nothing
            end
        end"""

        str = """
        foo(a) =
            if a > 1
                2
            else
                nothing
            end"""
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def=true)
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def=true)
    end

    @testset "not in macros and exprs" begin
        s1 = """
        @macro function foo()
            return 1
        end"""
        s2 = """
        quote
            function foo()
                return 1
            end
        end"""
        s3 = """
        :(function foo()
            return 1
        end)"""
        for s in (s1, s2, s3)
            for style in ALL_STYLES
                # YAS has slightly different indentation, so don't test the exact output--
                # but we can use ast=true to check that the function hasn't been collapsed
                test_format(s, nothing, style; ast=true, long_to_short_function_def=true)
            end
        end
    end
end

end # module
