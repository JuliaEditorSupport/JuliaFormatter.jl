module ShimsTests

import JuliaFormatter.Shims as S
import JuliaSyntax
using Test

cst(s::String) = JuliaSyntax.parseall(JuliaSyntax.GreenNode, s)[1]

@testset "is_function_call" begin
    # True function calls
    @testset "$(func)$(args)" for func in ("f", "f.", "g!", "g!.", "+", ".+", "<:", ".<:"), args in ("()", "(x, y)", "(x, y; kw=1)", "(; kw=1)")
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

    # Bare operators
    @testset for func in ("+", ".+", "<:", ".<:")
        @test !S.is_function_call(cst("$(func)"))
    end
end

end
