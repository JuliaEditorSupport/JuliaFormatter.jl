module OptionsFormatDocstringsTests

using JuliaFormatter.Internal: test_format
using Test

@testset "format_docstrings" begin
    @testset "basic" begin
        normalized = """
        \"""
        doc
        \"""
        function f()
            20
        end"""

        str = """
        \"""doc
        \"""
        function f()
            20
        end"""
        test_format(str, str)
        test_format(str, normalized; format_docstrings = true)

        str = """
        \"""
        doc\"""
        function f()
            20
        end"""
        test_format(str, str)
        test_format(str, normalized; format_docstrings = true)

        str = """
        \"""doc\"""
        function f()
            20
        end"""
        test_format(str, str)
        test_format(str, normalized; format_docstrings = true)

        str = """
        "doc
        "
        function f()
            20
        end"""
        test_format(str, str)
        test_format(str, normalized; format_docstrings = true)

        str = """
        "
        doc"
        function f()
            20
        end"""
        test_format(str, str)
        test_format(str, normalized; format_docstrings = true)

        str = """
        "doc"
        function f()
            20
        end"""
        test_format(str, str)
        test_format(str, normalized; format_docstrings = true)

        # test aligning to function identation
        str_ = """
            "doc"
        function f()
            20
        end"""
        str = """
        "doc"
        function f()
            20
        end"""
        test_format(str_, str)
        test_format(str_, normalized; format_docstrings = true)

        str = """\"""
                 doc for Foo
                 \"""
                 Foo"""
        test_format(str, str)

        str = """
        \"""
        doc
        \"""
        function f()    #  comment
            20
        end"""
        test_format(str, str)
        test_format(str, str; format_docstrings = true)

        # Issue 157
        str = raw"""
        @doc \"""
           foo()
        \"""
        foo() = bar()"""
        test_format(str, str)
        test_format(str, str; format_docstrings = true)

        str = raw"""
        @doc docϵ\"""
           foo()
        \"""
        foo() = bar()"""
        test_format(str, str)
        test_format(str, str; format_docstrings = true)

        str = raw"""@doc "doc for foo" foo"""
        test_format(str, str)
        test_format(str, str; format_docstrings = true)

        str = raw"""@doc \"""doc for foo\""" foo"""
        test_format(str, str)
        test_format(str, str; format_docstrings = true)

        str = raw"""@doc doc\"""doc for foo\""" foo()"""
        test_format(str, str)
        test_format(str, str; format_docstrings = true)

        str = raw"""@doc foo"""
        test_format(str, str)
        test_format(str, str; format_docstrings = true)

        # issue 160
        str = raw"""
        module MyModule

        import Markdown: @doc_str

        @doc doc\"""
            foo()
        \"""
        foo() = bar()

        end # module"""
        test_format(str, str)
        test_format(str, str; format_docstrings = true)
    end

    @testset "with code" begin
        unformatted = """
        \"""
        This is a docstring

        ```@example
        a =  1
         b  = 2
         a + b
        ```

        ```jldoctest
        a =  1
        b  = 2
        a + b

        # output

        3
        ```

        ```jldoctest
        julia> a =  1
        1

        julia> b  = 2;

        julia>  a + b
        3

        julia> function test(x)
               x + 1
               x + 2
               end;
        ```
        \"""
        function test(x) x end"""

        formatted = """
        \"""
        This is a docstring

        ```@example
        a = 1
        b = 2
        a + b
        ```

        ```jldoctest
        a = 1
        b = 2
        a + b

        # output

        3
        ```

        ```jldoctest
        julia> a = 1
        1

        julia> b = 2;

        julia> a + b
        3

        julia> function test(x)
                   x + 1
                   x + 2
               end;

        ```
        \"""
        function test(x)
            x
        end"""
        test_format(unformatted, formatted; format_docstrings = true)
    end

    @testset "issue 602" begin
        s = """
        \"""
        ```jldoctest
        julia> foo()

        julia> 1
        1
        ```
        \"""
        foo() = nothing
        """
        test_format(s, s; format_docstrings = true)
    end

    @testset "Multi-line indented code-blocks" begin
        unformatted = """
        \"""
            fmt(
            )
        \"""
        function fmt() end"""

        formatted = """
        \"""
            fmt(
            )
        \"""
        function fmt() end"""
        test_format(unformatted, formatted; format_docstrings = true)
    end

    @testset "Empty line in docstring" begin
        unformatted = """
        \"""

        \"""
        function test() end"""

        formatted = """
        \"""
        \"""
        function test() end"""
        test_format(unformatted, formatted; format_docstrings = true)
        test_format(unformatted, unformatted; format_docstrings = false)
    end

    @testset "Indented docstring" begin
        unformatted = """
        begin
            \"""
            Indented docstring

            with multiple paragraphs
            \"""
            indented_item
        end"""
        formatted = """
        begin
            \"""
            Indented docstring

            with multiple paragraphs
            \"""
            indented_item
        end"""
        test_format(unformatted, formatted; format_docstrings = true)

        short = """
        begin
            "Short docstring"
            item
        end
        """
        short_formatted = """
        begin
            \"""
            Short docstring
            \"""
            item
        end
        """
        test_format(short, short_formatted; format_docstrings = true)
    end

    @testset "597 printing to stdout" begin
        str_ = """
        \"""
        ```julia
        julia>  foo()
        hello world
        ```
        \"""
        foo() = println("hello world")
        """

        str = """
        \"""
        ```julia
        julia> foo()
        hello world
        ```
        \"""
        foo() = println("hello world")
        """
        test_format(str_, str; format_docstrings = true)

        s = """
        \"\"\"
        ```jldoctest
        foo()

        # output

        1-element Vector{Int64}:
         1
        ```
        \"\"\"
        foo() = [1]
        """
        test_format(str, str; format_docstrings = true)
    end

    @testset "812 empty jldoctest" begin
        s = """
        \"""
        ```jldoctest foo
        ```
        \"""
        function foo end
        """
        test_format(s, s; format_docstrings=true)
    end

    @testset "812 triple quotes in jldoctest" begin
        s = """
        \"""
        ```jldoctest
        \\\"""
        ```
        \"""
        f() = 1
        """
        test_format(s, s; format_docstrings=true)
    end

    @testset "1206 doesn't attempt to format invalid code" begin
        for prefix in ("julia", "{julia}", "@example")
            str = """
            \"""
                foo(a::MySpecialArg)

            Do foo to a special arg. Example:

            ```$(prefix)
            a = MySpecialArg(...) # set up your arg
            foo(a)
            ```
            \"""
            foo(a::MySpecialArg) = a
            """
            test_format(str, str; format_docstrings = true)
        end
    end

    @testset "1224 escape sequences" begin
        for escaped_julia_code in (
            raw"@macro a.\$s",
        )
            s = """
            \"""
            ```julia
            $(escaped_julia_code)
            ```
            \"""
            f
            """
            test_format(s, s)
        end
    end
end

end # module OptionsFormatDocstringsTests
