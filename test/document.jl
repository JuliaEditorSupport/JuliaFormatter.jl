module DocumentTests

using JuliaFormatter: slice_source
import JuliaSyntax
using Test

@testset "slice_source" begin
    @testset "ASCII" begin
        code = "x = abc"
        @test slice_source(code, 1:1) == "x"
        @test slice_source(code, 5:7) == "abc"
        @test slice_source(code, 1:7) == code
        # Empty range (e.g. from a zero-width node)
        @test slice_source(code, 3:2) == ""
    end

    @testset "multi-byte characters" begin
        # `α` is 2 bytes (5:6), `∈` is 3 bytes (8:10), `𝐱` is 4 bytes (12:15).
        # Byte positions are shown below. Each character is written at its first byte,
        # and `~` marks the extra bytes that the character takes up.
        #
        #     0        1
        #     123456789012345
        #     x = α~ ∈~~ 𝐱~~~
        code = "x = α ∈ 𝐱"
        @test slice_source(code, 5:6) == "α"
        @test slice_source(code, 8:10) == "∈"
        @test slice_source(code, 12:15) == "𝐱"
        # The end of the range can point to any byte of the final character.
        @test slice_source(code, 5:5) == "α"
        @test slice_source(code, 8:9) == "∈"
        @test slice_source(code, 12:13) == "𝐱"
        # Ranges spanning several characters, ending in a multi-byte one
        @test slice_source(code, 1:6) == "x = α"
        @test slice_source(code, 1:15) == code
        @test slice_source(code, 5:10) == "α ∈"
    end

    @testset "range ending past the end of the string" begin
        # This would indicate a bug elsewhere in the formatter, so it should error rather
        # than silently returning something.
        @test_throws BoundsError slice_source("abc", 1:4)
        @test_throws BoundsError slice_source("abα", 1:5)
    end
end

end
