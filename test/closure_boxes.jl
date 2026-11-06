module ClosureBoxesTests

using Test
import JuliaFormatter

@testset "No boxed closure captures" begin
    if isdefined(Test, :detect_closure_boxes)  # Julia 1.14+
        @test isempty(Test.detect_closure_boxes(JuliaFormatter))
    end
end

end
