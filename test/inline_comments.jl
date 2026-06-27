module InlineCommentTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, MinimalStyle, SciMLStyle
using JuliaFormatter.Internal: test_format, ALL_STYLES
using Test

@testset "Inline comments" begin
    @testset "hasheq comment on its own line is not merged into previous line (#1194)" begin
        # Single newline between statement and comment
        s = "x = 42\n#= this is a multi-line comment\n=#\n"
        for style in ALL_STYLES
            test_format(s, s, style)
        end

        # Two newlines between statement and comment
        s = "x = 42\n\n#= this is a multi-line comment\n=#\n"
        for style in ALL_STYLES
            test_format(s, s, style)
        end

        # Multiple statements with own-line hasheq comments
        s = "x = 1\n#= comment 1 =#\ny = 2\n#= comment 2 =#\n"
        for style in ALL_STYLES
            test_format(s, s, style)
        end

        # Standalone hasheq comment before a statement
        s = "#= standalone comment =#\nx = 1\n"
        for style in ALL_STYLES
            test_format(s, s, style)
        end
    end

    @testset "hasheq comment on its own line inside a block (#1194)" begin
        s = "begin\n    x = 1\n    #= comment =#\nend\n"
        for style in ALL_STYLES
            test_format(s, s, style)
        end

        s = "function foo()\n    x = 1\n    #= block comment =#\n    y = 2\nend\n"
        for style in (DefaultStyle(), SciMLStyle(), MinimalStyle())
            test_format(s, s, style)
        end
        # BlueStyle and YASStyle add `return` before the last statement
        s_return = "function foo()\n    x = 1\n    #= block comment =#\n    return y = 2\nend\n"
        for style in (BlueStyle(), YASStyle())
            test_format(s, s_return, style)
        end
    end

    @testset "inline hasheq comment stays on the same line" begin
        s = "x = 42 #= inline comment =#\n"
        for style in ALL_STYLES
            test_format(s, s, style)
        end

        s = "f(x, #= c =# z)\n"
        for style in ALL_STYLES
            test_format(s, s, style)
        end
    end
end

end
