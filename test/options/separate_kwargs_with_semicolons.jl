module SeparateKwargsWithSemicolonsTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, format_text
using JuliaFormatter.Internal: test_format
using Test

@testset "separate_kwargs_with_semicolon" begin
    str_ = "f(a, b = 10)"
    str = "f(a; b = 10)"
    test_format(str_, str; separate_kwargs_with_semicolon = true)
    str = "f(a; b=10)"
    test_format(str_, str, YASStyle(); separate_kwargs_with_semicolon = true)

    str_ = "xy = f(x, y=3)"
    str = "xy = f(x; y = 3)"
    test_format(str_, str; separate_kwargs_with_semicolon = true)
    str = "xy = f(x; y=3)"
    test_format(str_, str, YASStyle(); separate_kwargs_with_semicolon = true)

    for str_ in ("xy = f(x=1, y=2)", "xy = f(x = 1; y = 2)")
        str = "xy = f(; x = 1, y = 2)"
        test_format(str_, str; separate_kwargs_with_semicolon = true)
        str = "xy = f(; x=1, y=2)"
        test_format(str_, str, YASStyle(); separate_kwargs_with_semicolon = true)
    end

    str = """
    function g(x, y = 1)
        return x + y
    end
    macro h(x, y = 1)
        nothing
    end
    shortdef1(MatrixT, VectorT = nothing) = nothing
    shortdef2(MatrixT, VectorT = nothing) where {T} = nothing
    """
    test_format(str, str; separate_kwargs_with_semicolon = true)
    str = """
    function g(x, y=1)
        return x + y
    end
    macro h(x, y=1)
        return nothing
    end
    shortdef1(MatrixT, VectorT=nothing) = nothing
    shortdef2(MatrixT, VectorT=nothing) where {T} = nothing
    """
    test_format(str, str, YASStyle(); separate_kwargs_with_semicolon = true)

    str = """
    function g(x::T, y = 1) where {T}
        return x + y
    end
    function g(x::T, y = 1)::Int where {T}
        return x + y
    end
    """
    test_format(str, str; separate_kwargs_with_semicolon = true)
    stryas = """
    function g(x::T, y=1) where {T}
        return x + y
    end
    function g(x::T, y=1)::Int where {T}
        return x + y
    end
    """
    test_format(str, stryas, YASStyle(); separate_kwargs_with_semicolon = true)

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

end # module
