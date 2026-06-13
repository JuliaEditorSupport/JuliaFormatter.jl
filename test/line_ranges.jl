module LineRangesTests

using JuliaFormatter
using JuliaFormatter: BlueStyle, format_text, normalize_line_ranges
using JuliaFormatter.Internal: test_format
using Test

# DefaultStyle leaves `a=1` and `x+y` untouched but turns `f(x,y)` into `f(x, y)`, so we use
# comma spacing to force a visible, line-count-preserving change on a targeted line.

@testset "line ranges (`lines` kwarg)" begin
    @testset "normalize_line_ranges" begin
        # `(start, stop)` tuples are converted to sorted UnitRange{Int}
        @test normalize_line_ranges([(1, 3)]) == [1:3]
        # sorting
        @test normalize_line_ranges([(5, 6), (1, 2)]) == [1:2, 5:6]
        # overlapping ranges merge
        @test normalize_line_ranges([(1, 3), (2, 5)]) == [1:5]
        # adjacent ranges merge (touching, gap of 0)
        @test normalize_line_ranges([(1, 2), (3, 4)]) == [1:4]
        # non-adjacent stay separate (gap >= 1 blank line between)
        @test normalize_line_ranges([(1, 2), (4, 5)]) == [1:2, 4:5]
        # duplicates collapse
        @test normalize_line_ranges([(2, 4), (2, 4)]) == [2:4]

        @test_throws ArgumentError normalize_line_ranges([(0, 1)])   # 0 is not 1-based
        @test_throws ArgumentError normalize_line_ranges([(3, 2)])   # empty (start > stop)
    end

    @testset "single range" begin
        # only line 1 is formatted; line 2 kept verbatim (note odd spacing preserved)
        test_format("f(x,y)=1\ng( a ,b )=2\n", "f(x, y) = 1\ng( a ,b )=2\n"; lines = [(1, 1)])
        # only line 2 is formatted; line 1 kept verbatim
        test_format("f( x ,y)=1\ng(a,b)=2\n", "f( x ,y)=1\ng(a, b) = 2\n"; lines = [(2, 2)])
    end

    @testset "multiple ranges" begin
        # lines 1 and 3 formatted, line 2 verbatim
        test_format(
            "f(a,b)=1\ng( x ,y )=2\nh(c,d)=3\n",
            "f(a, b) = 1\ng( x ,y )=2\nh(c, d) = 3\n";
            lines = [(1, 1), (3, 3)],
        )
        # ranges may be given out of order
        test_format(
            "f(a,b)=1\ng( x ,y )=2\nh(c,d)=3\n",
            "f(a, b) = 1\ng( x ,y )=2\nh(c, d) = 3\n";
            lines = [(3, 3), (1, 1)],
        )
    end

    @testset "merged ranges" begin
        # adjacent (1,1)+(2,2) -> 1:2, so lines 1 and 2 formatted, line 3 verbatim
        test_format(
            "f(a,b)=1\ng(c,d)=2\nh( e ,f )=3\n",
            "f(a, b) = 1\ng(c, d) = 2\nh( e ,f )=3\n";
            lines = [(1, 1), (2, 2)],
        )
        # overlapping ranges format the union
        test_format(
            "f(a,b)=1\ng(c,d)=2\nh(e,f)=3\n",
            format_text("f(a,b)=1\ng(c,d)=2\nh(e,f)=3\n");
            lines = [(1, 2), (2, 3)],
        )
    end

    @testset "whole-file range matches plain formatting" begin
        s = "f(a,b)=1\ng(c,d)=2\n"
        test_format(s, format_text(s); lines = [(1, 2)])
    end

    @testset "verbatim out-of-range" begin
        # leading/odd whitespace on out-of-range lines is preserved exactly
        test_format("   x  =  1\nf(a,b)=2\n", "   x  =  1\nf(a, b) = 2\n"; lines = [(2, 2)])
        # comments out of range preserved (including their internal spacing)
        test_format(
            "# keep  me\nf(a,b)=1\n# and  me\n",
            "# keep  me\nf(a, b) = 1\n# and  me\n";
            lines = [(2, 2)],
        )
    end

    @testset "inside a block" begin
        # only the inner statement's line is formatted; the signature stays verbatim
        test_format(
            "function f( a ,b )\n    g(x,y)\nend\n",
            "function f( a ,b )\n    g(x, y)\nend\n";
            lines = [(2, 2)],
        )
    end

    @testset "interaction with #! format: off" begin
        # a user `#! format: off` region outside the requested range stays verbatim
        test_format(
            "f(a,b)=1\n#! format: off\nz  =  2\n#! format: on\n",
            "f(a, b) = 1\n#! format: off\nz  =  2\n#! format: on\n";
            lines = [(1, 1)],
        )
    end

    @testset "trailing newline handling" begin
        # range reaches the final newline-less line: output preserves the missing newline,
        # matching whole-file `format_text` behavior
        @test format_text("f(a,b)=1\ng(c,d)=2"; lines = [(2, 2)]) == "f(a,b)=1\ng(c, d) = 2"
        # range targets an earlier line: the newline-less last line stays verbatim
        @test format_text("f(a,b)=1\ng(c,d)=2"; lines = [(1, 1)]) == "f(a, b) = 1\ng(c,d)=2"
    end

    @testset "trailing newline phantom line" begin
        # Many editors / LSP clients count the position after a file's final newline as an
        # extra (empty) line, so a 2-line file ending in `\n` may be referenced with line 3.
        # `add_line_range_markers` accepts such references by clamping (or skipping) them.
        s = "f(a,b)=1\ng(c,d)=2\n"  # 2 real lines; the phantom line is line 3
        # a range that is *only* the phantom line formats nothing
        @test format_text(s; lines = [(3, 3)]) == s
        # a range spanning into the phantom line is clamped to the last real line
        @test format_text(s; lines = [(1, 3)]) == format_text(s)
        @test format_text(s; lines = [(2, 3)]) == "f(a,b)=1\ng(c, d) = 2\n"
        # without a trailing newline there is no phantom line, so line 3 is out of bounds
        @test_throws ArgumentError format_text("f(a,b)=1\ng(c,d)=2"; lines = [(3, 3)])
    end

    @testset "empty ranges" begin
        # nothing requested -> input returned unchanged
        @test format_text("f(a,b)=1\n"; lines = Tuple{Int,Int}[]) == "f(a,b)=1\n"
    end

    @testset "styles and options thread through" begin
        # `lines` composes with the chosen style and other options
        s = "f(a,b)=1\ng(c,d)=2\n"
        @test format_text(s, BlueStyle(); lines = [(1, 1)]) ==
              format_text("f(a,b)=1\n", BlueStyle()) * "g(c,d)=2\n"
        @test format_text(s; lines = [(1, 1)], whitespace_in_kwargs = false) ==
              "f(a, b) = 1\ng(c,d)=2\n"
    end

    @testset "out-of-bounds errors" begin
        @test_throws ArgumentError format_text("f(a,b)=1\n"; lines = [(1, 99)])
        @test_throws ArgumentError format_text("f(a,b)=1\n"; lines = [(0, 1)])
        @test_throws ArgumentError format_text("f(a,b)=1\n"; lines = [(2, 1)])
    end
end

end # module
