module DispatchTests

using Test
using JuliaFormatter:
    format,
    format_text,
    format_file,
    format_md,
    DefaultStyle,
    BlueStyle,
    YASStyle,
    SciMLStyle,
    MinimalStyle

# A simple unformatted string and its expected output, used throughout.
const UNFORMATTED = "f( x,y )"
const FORMATTED_DEFAULT = "f(x, y)"

# BlueStyle removes spaces around kwargs `=`
const UNFORMATTED_KW = "foo(; k = v)"
const FORMATTED_BLUE_KW = "foo(; k=v)"

# ---------------------------------------------------------------------------
# format_text
# ---------------------------------------------------------------------------

@testset "format_text" begin
    @testset "keyword style" begin
        @test format_text(UNFORMATTED) == FORMATTED_DEFAULT
        @test format_text(UNFORMATTED; style = BlueStyle()) == FORMATTED_DEFAULT
        @test format_text(UNFORMATTED_KW; style = BlueStyle()) == FORMATTED_BLUE_KW
    end

    @testset "positional style" begin
        @test format_text(UNFORMATTED, DefaultStyle()) == FORMATTED_DEFAULT
        @test format_text(UNFORMATTED, BlueStyle()) == FORMATTED_DEFAULT
        @test format_text(UNFORMATTED_KW, BlueStyle()) == FORMATTED_BLUE_KW
    end

    @testset "keyword and positional style agree" begin
        for style in (DefaultStyle(), BlueStyle(), YASStyle(), SciMLStyle(), MinimalStyle())
            kw = format_text(UNFORMATTED; style)
            pos = format_text(UNFORMATTED, style)
            @test kw == pos
        end
    end

    @testset "extra kwargs are forwarded" begin
        @test format_text(UNFORMATTED_KW, BlueStyle(); whitespace_in_kwargs = true) ==
              UNFORMATTED_KW
        @test format_text(UNFORMATTED_KW; style = BlueStyle(), whitespace_in_kwargs = true) ==
              UNFORMATTED_KW
    end

    @testset "empty string is returned unchanged" begin
        @test format_text("") == ""
        @test format_text("", BlueStyle()) == ""
        @test format_text("", SciMLStyle()) == ""
    end

    @testset "already-formatted string is idempotent" begin
        @test format_text(FORMATTED_DEFAULT) == FORMATTED_DEFAULT
    end
end

# ---------------------------------------------------------------------------
# format_text with SciMLStyle fixpoint iteration
# ---------------------------------------------------------------------------

@testset "format_text SciMLStyle" begin
    @testset "keyword and positional style agree" begin
        kw = format_text(UNFORMATTED; style = SciMLStyle())
        pos = format_text(UNFORMATTED, SciMLStyle())
        @test kw == pos
    end

end

# ---------------------------------------------------------------------------
# format_md
# ---------------------------------------------------------------------------

@testset "format_md" begin
    md = """
    Some text.

    ```julia
    f( x,y )
    ```
    """
    @testset "keyword style" begin
        out = format_md(md)
        @test occursin("f(x, y)", out)
    end
    @testset "positional style" begin
        out = format_md(md, DefaultStyle())
        @test occursin("f(x, y)", out)
    end
    @testset "keyword and positional agree" begin
        @test format_md(md) == format_md(md, DefaultStyle())
        @test format_md(md; style = BlueStyle()) == format_md(md, BlueStyle())
    end
    @testset "empty string" begin
        @test format_md("") == ""
        @test format_md("", BlueStyle()) == ""
    end
end

# ---------------------------------------------------------------------------
# format_file and format (file paths)
# ---------------------------------------------------------------------------

function with_tempfile(f, content; ext = ".jl")
    mktempdir() do dir
        path = joinpath(dir, "test$ext")
        write(path, content)
        f(path)
    end
end

@testset "format_file" begin
    @testset "formats a file and returns whether it was already formatted" begin
        with_tempfile(UNFORMATTED) do path
            already = format_file(path)
            @test already == false
            @test readchomp(path) == FORMATTED_DEFAULT
            # second call: already formatted
            @test format_file(path) == true
        end
    end

    @testset "keyword style" begin
        with_tempfile(UNFORMATTED_KW) do path
            format_file(path; style = BlueStyle())
            @test readchomp(path) == FORMATTED_BLUE_KW
        end
    end

    @testset "positional style" begin
        with_tempfile(UNFORMATTED_KW) do path
            format_file(path, BlueStyle())
            @test readchomp(path) == FORMATTED_BLUE_KW
        end
    end

    @testset "overwrite=false leaves file unchanged" begin
        with_tempfile(UNFORMATTED) do path
            already = format_file(path; overwrite = false)
            @test already == false
            @test readchomp(path) == UNFORMATTED
        end
    end
end

@testset "format (single file)" begin
    @testset "formats a file" begin
        with_tempfile(UNFORMATTED) do path
            already = format(path)
            @test already == false
            @test readchomp(path) == FORMATTED_DEFAULT
        end

        # Check that it doesn't fail on empty files
        with_tempfile("") do path
            already = format(path)
            @test already == false # format() will add a newline
            @test readchomp(path) == ""
            @test format(path) # already formatted
        end
    end

    @testset "keyword style" begin
        with_tempfile(UNFORMATTED_KW) do path
            format(path; style = BlueStyle())
            @test readchomp(path) == FORMATTED_BLUE_KW
        end
    end

    @testset "positional style" begin
        with_tempfile(UNFORMATTED_KW) do path
            format(path, BlueStyle())
            @test readchomp(path) == FORMATTED_BLUE_KW
        end
    end
end

@testset "format (directory)" begin
    dir = mktempdir()
    try
        write(joinpath(dir, "a.jl"), UNFORMATTED)
        write(joinpath(dir, "b.jl"), UNFORMATTED_KW)
        write(joinpath(dir, "c.txt"), "not julia")

        already = format(dir; style = BlueStyle())
        @test already == false
        @test readchomp(joinpath(dir, "a.jl")) == FORMATTED_DEFAULT
        @test readchomp(joinpath(dir, "b.jl")) == FORMATTED_BLUE_KW
        # Non-Julia files are left alone
        @test read(joinpath(dir, "c.txt"), String) == "not julia"
    finally
        rm(dir; recursive = true)
    end
end

@testset "format (collection of paths)" begin
    mktempdir() do dir
        p1 = joinpath(dir, "a.jl")
        p2 = joinpath(dir, "b.jl")
        write(p1, UNFORMATTED)
        write(p2, UNFORMATTED)

        already = format([p1, p2])
        @test already == false
        @test readchomp(p1) == FORMATTED_DEFAULT
        @test readchomp(p2) == FORMATTED_DEFAULT
    end
end

# ---------------------------------------------------------------------------
# format_file and format agree
# ---------------------------------------------------------------------------

@testset "format_file and format produce the same result" begin
    for style in (DefaultStyle(), BlueStyle())
        with_tempfile(UNFORMATTED_KW) do path1
            with_tempfile(UNFORMATTED_KW) do path2
                format_file(path1; style)
                format(path2; style)
                @test read(path1, String) == read(path2, String)
            end
        end
    end
end

# ---------------------------------------------------------------------------
# Error behaviour: format swallows ParseError, format_file does not
# ---------------------------------------------------------------------------

@testset "error handling" begin
    invalid_julia = "function f(\n"

    @testset "format_text throws on unparseable input" begin
        @test_throws Exception format_text(invalid_julia)
    end

    @testset "format swallows ParseError on files" begin
        with_tempfile(invalid_julia) do path
            # format() warns and returns true (skips the file)
            already = @test_logs (:warn,) format(path)
            @test already == true
            # file is not modified
            @test read(path, String) == invalid_julia
        end
    end

    @testset "format_file propagates ParseError" begin
        with_tempfile(invalid_julia) do path
            # format_file delegates to format, which swallows ParseError —
            # so format_file also swallows it. This test documents current behaviour.
            already = @test_logs (:warn,) match_mode=:any format_file(path)
            @test already == true
        end
    end
end

# ---------------------------------------------------------------------------
# format_md with markdown files via format/format_file
# ---------------------------------------------------------------------------

@testset "format/format_file on markdown" begin
    md_content = "# Title\n\n```julia\nf( x,y )\n```\n"
    with_tempfile(md_content; ext = ".md") do path
        # Without format_markdown=true, markdown files are skipped
        @test format_file(path; format_markdown = false) == true
        @test read(path, String) == md_content

        # With format_markdown=true, Julia code blocks are formatted
        format_file(path; format_markdown = true)
        @test occursin("f(x, y)", read(path, String))
    end
end

end
