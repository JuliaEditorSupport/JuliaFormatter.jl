module ShimsTests

import JuliaFormatter.Shims as S
import JuliaSyntax
using Test

cst(s::String) = JuliaSyntax.parseall(JuliaSyntax.GreenNode, s)[1]

@testset "is_function_call" begin
    # True function calls
    @testset "$(func)$(args)" for func in ("f", "f.", "g!", "g!.", "+", ".+", "<:", ".<:"), args in ("()", "(x, y)", "(x, y; kw=1)", "(; kw=1)", "(args...)")
        @test S.is_function_call(cst("$(func)$(args)"))
    end

    # Exclude unary ops
    @testset "$(func)(x)" for func in ("f", "f.", "g!", "g!.", ".<:")
        @test S.is_function_call(cst("$(func)(x)"))
    end
    @testset "$(func)x" for func in ("+", ".+", "<:")
        @test !S.is_function_call(cst("$(func)x"))
        @test !S.is_function_call(cst("$(func)(x)"))
    end

    # Exclude bare operators
    @testset "$(func)" for func in ("+", ".+", "<:", ".<:")
        @test !S.is_function_call(cst("$(func)"))
    end

    # Exclude infix calls
    @testset "a $(op) b" for op in ("+", ".+", "<:", ".<:")
        @test !S.is_function_call(cst("a $(op) b"))
    end

    # Check that it's robust towards whitespace and comments
    @test S.is_function_call(cst("f( <:(x, y))")[3])
    @test S.is_function_call(cst("@m <:(x, y)")[3])
    @test S.is_function_call(cst("<:(#=hi=# x, y)"))
    @test S.is_function_call(cst("<:(x #=hi=#, y)"))
    @test S.is_function_call(cst("<:(x, #=hi=# y)"))
    @test S.is_function_call(cst("<:(x, y#=hi=#)"))
end

@testset "is_valid_nonword_operator" begin
    @test S.is_valid_nonword_operator("+")
    @test S.is_valid_nonword_operator("<")
    @test S.is_valid_nonword_operator("::")
    @test !S.is_valid_nonword_operator("in")
    @test !S.is_valid_nonword_operator("isa")
    @test !S.is_valid_nonword_operator("where")
    @test !S.is_valid_nonword_operator("foo")
end

end
