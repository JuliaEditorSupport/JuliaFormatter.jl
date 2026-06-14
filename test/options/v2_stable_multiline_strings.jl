module V2StableMultilineStringsTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, format_text, JuliaFormatter
using JuliaFormatter.Internal: test_format, format_to_stage, ALL_STYLES
using Test

@testset "v2_stable_multiline_strings" begin
    @testset "length calculation" begin
        s = """
        s = \"""
            1234567890
        \"""
        """

        # 10 characters past the column before the opening quote
        fst = format_to_stage(:fst, s)
        stringn = fst[1][end]
        @test stringn.typ == JuliaFormatter.StringN
        @test stringn.len == 10

        # Opening quote only
        fst = format_to_stage(:fst, s; v2_stable_multiline_strings=true)
        stringn = fst[1][end]
        @test stringn.typ == JuliaFormatter.StringN
        @test stringn.len == 3
    end

    @testset "an example of differing behaviour" begin
        s = """
        throw(ArgumentError(\"""
                            ooohhhhhh a very long thing
                            \"""))
        """
        for style in ALL_STYLES
            test_format(s, s, style; margin=46, v2_stable_multiline_strings=true)
        end
    end
end

end # module
