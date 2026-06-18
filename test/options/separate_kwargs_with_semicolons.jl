module SeparateKwargsWithSemicolonsTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, format_text
using JuliaFormatter.Internal: test_format, ALL_STYLES
using Test

@testset "separate_kwargs_with_semicolon" begin
    @testset "basic" begin
        str_ = "f(a, b = 10)"
        str_space = "f(a; b = 10)"
        test_format(str_, str_space, DefaultStyle(); separate_kwargs_with_semicolon = true)
        test_format(str_, str_space, SciMLStyle(); separate_kwargs_with_semicolon = true)
        str_nospace = "f(a; b=10)"
        test_format(str_, str_nospace, MinimalStyle(); separate_kwargs_with_semicolon = true)
        test_format(str_, str_nospace, BlueStyle(); separate_kwargs_with_semicolon = true)
        test_format(str_, str_nospace, YASStyle(); separate_kwargs_with_semicolon = true)
    end

    # Now that we've explicitly tested the spacing, we're just going to use
    # whitespace_in_kwargs=true for everything

    @testset "in assignment" begin
        str_ = "xy = f(x, y=3)"
        str = "xy = f(x; y = 3)"
        for style in ALL_STYLES
            test_format(str_, str, style; separate_kwargs_with_semicolon = true, whitespace_in_kwargs = true)
        end
    end

    @testset "addition of semicolon at start" begin
        for str_ in ("xy = f(x=1, y=2)", "xy = f(x = 1; y = 2)")
            str = "xy = f(; x = 1, y = 2)"
            for style in ALL_STYLES
                test_format(str_, str, style; separate_kwargs_with_semicolon = true, whitespace_in_kwargs = true)
            end
        end
    end

    @testset "function definitions are untouched" begin
        for str in (
            """function g(x, y = 1)
                return x + y
            end""",
            """function g(x, y = 1) where {T}
                return x + y
            end""",
            """function (g)(x, y = 1)
                return x + y
            end""",
            """function g(x, y = 1)::Int
                return x + y
            end""",
            """function g(x, y = 1)::Int where T
                return x + y
            end""",
            """function g(x, y = 1)::Int where T where S
                return x + y
            end""",
            """function g(x, y = 1)::Int where {T,S}
                return x + y
            end""",
            """macro h(x, y = 1)
                return nothing
            end""",
            "shortdef1(MatrixT, VectorT = nothing) = nothing",
            "shortdef2(MatrixT, VectorT = nothing) where {T} = nothing",
        )
            for style in ALL_STYLES
                # need some extra options to stop other unrelated changes
                test_format(str, str, style; separate_kwargs_with_semicolon = true, whitespace_in_kwargs = true, whitespace_typedefs = false, surround_whereop_typeparameters = false)
            end
        end
    end

    @testset "nesting" begin
        str_ = """
        x = foo(var = "some really really really really really really really really really really long string")
        """
        str = """
        x = foo(;
            var = "some really really really really really really really really really really long string",
        )
        """
        test_format(str_, str; separate_kwargs_with_semicolon = true)

        str_ = """
        x = foo(var = "some really really really really really really really really really really long string")
        """
        str = """
        x = foo(;
                var="some really really really really really really really really really really long string")
        """
        test_format(str_, str, YASStyle(); separate_kwargs_with_semicolon = true)
    end

    @testset "calls as default values are changed" begin
        # g should be changed but not f
        s_ = """
        function f(x, y=g(a, b=1))
            return foo
        end"""
        s = """
        function f(x, y = g(a; b = 1))
            return foo
        end"""
        for style in ALL_STYLES
            test_format(s_, s, style; separate_kwargs_with_semicolon = true, whitespace_in_kwargs = true)
        end
    end

    @testset "rhs of short function def is not changed" begin
        # g should be changed but not f
        s_ = "f(x, y=z) = g(p, q=r)"
        s = "f(x, y = z) = g(p; q = r)"
        for style in ALL_STYLES
            test_format(s_, s, style; separate_kwargs_with_semicolon = true, whitespace_in_kwargs = true)
        end
    end

    @testset "#1133: idempotence with short_to_long_function_def" begin
        s_= "_get_isoband_levels(levels::Int, mi, ma) = collect(range(Float32(mi), nextfloat(Float32(ma)), length = levels + 1))"
        s = """
        function _get_isoband_levels(levels::Int, mi, ma)
            return collect(range(Float32(mi), nextfloat(Float32(ma)); length=levels + 1))
        end"""
        test_format(s_, s, BlueStyle())

        s_ = "foo(x) = goo(x, k=v)"
        s = """
        function foo(
            x
        )
            return goo(
                x;
                k=v,
            )
        end"""
        test_format(s_, s, BlueStyle(); margin=10)
    end
end

end # module
