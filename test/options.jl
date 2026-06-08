module OptionsTests

using JuliaFormatter
using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, Options, format_text
using JuliaFormatter.Internal: test_format
using JuliaSyntax
using Test

function run_pretty(text::String; style = DefaultStyle(), opts = Options())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; version=JuliaFormatter.SUPPORTED_SYNTAX_VERSION)
    t = JuliaFormatter.pretty(style, g, s)
    t
end

@testset "Formatting Options" begin
    @testset "remove extra newlines" begin
        str_ = """
        a = 10

        # foo1
        # ooo



        # aooo


        # aaaa
        b = 20



        # hello
        """
        str = """
        a = 10

        # foo1
        # ooo

        # aooo

        # aaaa
        b = 20

        # hello
        """
        test_format(str_, str; remove_extra_newlines = true)
        test_format(str_, str_; remove_extra_newlines = false)

        str_ = """
        module M


        function foo(bar::Int64, baz::Int64)


            return bar + baz
        end

        function foo(bar::In64, baz::Int64)
            return bar + baz


        end


        end
        """
        str = """
        module M

        function foo(bar::Int64, baz::Int64)
            return bar + baz
        end

        function foo(bar::In64, baz::Int64)
            return bar + baz
        end

        end
        """
        test_format(str_, str; remove_extra_newlines = true)
        test_format(str_, str_; remove_extra_newlines = false)
    end

    @testset "whitespace in typedefs" begin
        str_ = "Foo{A,B,C}"
        str = "Foo{A, B, C}"
        test_format(str_, str; whitespace_typedefs = true)

        str_ = """
        struct Foo{A<:Bar,Union{B<:Fizz,C<:Buzz},<:Any}
            a::A
        end"""
        str = """
        struct Foo{A <: Bar, Union{B <: Fizz, C <: Buzz}, <:Any}
            a::A
        end"""
        test_format(str_, str; whitespace_typedefs = true)

        str_ = """
        function foo() where {A,B,C{D,E,F{G,H,I},J,K},L,M<:N,Y>:Z}
            body
        end
        """
        str = """
        function foo() where {A, B, C{D, E, F{G, H, I}, J, K}, L, M <: N, Y >: Z}
            body
        end
        """
        test_format(str_, str; whitespace_typedefs = true)

        str_ = "foo() where {A,B,C{D,E,F{G,H,I},J,K},L,M<:N,Y>:Z} = body"
        str = "foo() where {A, B, C{D, E, F{G, H, I}, J, K}, L, M <: N, Y >: Z} = body"
        test_format(str_, str; whitespace_typedefs = true)
    end

    @testset "whitespace ops in indices" begin
        str = "arr[1 + 2]"
        test_format("arr[1+2]", str; margin = 1, whitespace_ops_in_indices = true)

        str = "arr[(1 + 2)]"
        test_format("arr[(1+2)]", str; margin = 1, whitespace_ops_in_indices = true)

        str_ = "arr[1:2*num_source*num_dump-1]"
        str = "arr[1:(2 * num_source * num_dump - 1)]"
        test_format(str_, str; margin = 1, whitespace_ops_in_indices = true)

        str_ = "arr[2*num_source*num_dump-1:1]"
        str = "arr[(2 * num_source * num_dump - 1):1]"
        test_format(str_, str; margin = 1, whitespace_ops_in_indices = true)

        str = "arr[(a + b):c]"
        test_format("arr[(a+b):c]", str; margin = 1, whitespace_ops_in_indices = true)

        str = "arr[a in b]"
        test_format(str, str; margin = 1, whitespace_ops_in_indices = true)

        # In v1
        str_ = "a:b+c:d-e"
        str = "a:(b + c):(d - e)"
        test_format(str_, str; margin = 1, whitespace_ops_in_indices = true)
        str = "a:(b+c):(d-e)"
        test_format(str_, str; margin = 1, whitespace_ops_in_indices = false)

        str_ = "s[m+i+1]"
        # issue 180
        str = "s[m+i+1]"
        test_format(str, str; margin = 1, whitespace_ops_in_indices = false)

        str = "s[m + i + 1]"
        test_format(str_, str; margin = 1, whitespace_ops_in_indices = true)
    end

    @testset "rewrite import to using" begin
        str_ = "import A"
        str = "using A: A"
        test_format(str_, str; import_to_using = true)

        str_ = """
        import A,

        B, C"""
        str = """
        using A: A

        using B: B
        using C: C"""
        test_format(str_, str; import_to_using = true)

        str_ = """
        import A,
               # comment
        B, C"""
        str = """
        using A: A
        # comment
        using B: B
        using C: C"""
        test_format(str_, str; import_to_using = true)

        str_ = """
        import A, # inline
               # comment
        B, C # inline"""
        str = """
        using A: A # inline
        # comment
        using B: B
        using C: C # inline"""
        test_format(str_, str; import_to_using = true)

        str_ = """
        import ..A, .B, ...C"""
        str = """
        using ..A: A
        using .B: B
        using ...C: C"""
        test_format(str_, str; import_to_using = true)
        t = run_pretty(str_; opts = Options(; margin = 80, import_to_using = true))
        @test t.len == 13

        # issue 232
        str = """import A.b"""
        test_format(str, str; import_to_using = true)

        str = """import A.b: c"""
        test_format(str, str; import_to_using = true)

        str = """import A.b.c"""
        test_format(str, str; import_to_using = true)

        str = """import A.b.c: d"""
        test_format(str, str; import_to_using = true)

        str = "import ..A"
        test_format(str, str; import_to_using = true)
    end

    @testset "rewrite x |> f to f(x)" begin
        @testset "basic cases" begin
            for dot in ("", ".")
                test_format("x $dot|> f", "f$dot(x)"; pipe_to_function_call = true)
                test_format("x $dot|> f()", "f()$dot(x)"; pipe_to_function_call = true)
                test_format("x $dot|> f(a)", "f(a)$dot(x)"; pipe_to_function_call = true)
                test_format("x $dot|> M.f", "M.f$dot(x)"; pipe_to_function_call = true)
                test_format("x $dot|> T{x}", "T{x}$dot(x)"; pipe_to_function_call = true)
                # Check that callable is parenthesised if necessary
                test_format("x $dot|> y -> y + 1", "(y -> y + 1)$dot(x)"; pipe_to_function_call = true)
                test_format("x $dot|> f ∘ g", "(f ∘ g)$dot(x)"; pipe_to_function_call = true)
            end
        end

        @testset "operators on rhs" begin
            test_format("x |> !", "!(x)"; pipe_to_function_call = true)
            test_format("x .|> !", ".!(x)"; pipe_to_function_call = true)
        end

        @testset "elision of extra argument parentheses" begin
            test_format("(x) |> f", "f(x)"; pipe_to_function_call = true)
            test_format("(x) .|> f", "f.(x)"; pipe_to_function_call = true)
            test_format("(a for a in x) |> f()", "f()(a for a in x)"; pipe_to_function_call = true)
            # make sure that genuine tuples don't get de-parenthesised
            test_format("(x, y) |> f()", "f()((x, y))"; pipe_to_function_call = true)
            test_format("(x,) |> f()", "f()((x,))"; pipe_to_function_call = true)
            test_format("(; x) |> f()", "f()((; x))"; pipe_to_function_call = true)
        end

        @testset "chained pipes" begin
            str_ = "var = func1(arg1) |> func2 |> func3 |> func4 |> func5"
            str = "var = func5(func4(func3(func2(func1(arg1)))))"
            test_format(str_, str; pipe_to_function_call = true)
            str_nested = format_text(str; margin = 1)
            test_format(str_, str_nested; pipe_to_function_call = true, margin = 1)
            test_format("x .|> f .|> g", "g.(f.(x))"; pipe_to_function_call = true)
            test_format("(x |> f) |> g", "g(f(x))"; pipe_to_function_call = true)
            test_format("x |> f .|> g", "g.(f(x))"; pipe_to_function_call = true)
            test_format("x .|> f |> g", "g(f.(x))"; pipe_to_function_call = true)
            test_format("x |> y -> y |> f", "(y -> f(y))(x)"; pipe_to_function_call = true)
        end

        @testset "expressions on lhs" begin
            test_format("f(a, b) |> g", "g(f(a, b))"; pipe_to_function_call = true)
            test_format("a + b |> f", "f(a + b)"; pipe_to_function_call = true)
            test_format("[1...] |> f", "f([1...])"; pipe_to_function_call = true)
            test_format("1:10 |> collect", "collect(1:10)"; pipe_to_function_call = true)
        end

        @testset "nesting" begin
            for dot in ("", ".")
                f = "some_long_function_name"
                x = "very_long_variable_name"
                str_ = "$x $(dot)|> $f"
                str = "$f$(dot)($x)"
                str_nested = format_text(str; margin = 1)
                test_format(str_, str_nested; pipe_to_function_call = true, margin = 1)
            end

            @testset "extra idempotence test" begin
                # Make sure that nesting decisions are made correctly the first time
                # see https://github.com/JuliaEditorSupport/JuliaFormatter.jl/pull/1023
                # Formatting the string below used to not be idempotent.
                str_ = """
                function f()
                    ps_mods = map(
                        layer_mods -> (
                            layer_mods === nothing ? () :
                                map(l -> initialparameters(rng, l), layer_mods) |> Tuple
                        ),
                        mods
                    ) |> Tuple
                end"""
                str = """
                function f()
                    ps_mods = Tuple(
                        map(
                            layer_mods -> (
                                layer_mods === nothing ? () :
                                Tuple(map(l -> initialparameters(rng, l), layer_mods))
                            ),
                            mods,
                        ),
                    )
                end"""
                test_format(str_, str; pipe_to_function_call = true)
                test_format(str, str; pipe_to_function_call = true)
            end
        end

        @testset "block argument" begin
            for dot in ("", ".")
                str_ = """begin
                    f
                end $dot|> g"""
                str = """g$dot(begin
                    f
                end)"""
                test_format(str_, str; pipe_to_function_call = true)
            end
        end

        @testset "function with do block" begin
            for dot in ("", ".")
                str_ = """
                x $dot|> f(a) do a
                    g(a)
                end
                """
                str = """
                (f(a) do a
                    g(a)
                end)$dot(x)
                """
                test_format(str_, str; pipe_to_function_call = true)
            end
        end

        @testset "cases where transformation should not happen" begin
            # inside macro
            smacro = "@macro x |> f"
            test_format(smacro, smacro; pipe_to_function_call = true)
            smacro2 = "@macro function f()\n    x |> g\nend"
            test_format(smacro2, smacro2; pipe_to_function_call = true)

            # inside Expr
            sexpr = ":(x |> f)"
            test_format(sexpr, sexpr; pipe_to_function_call = true)
            squote = "quote\n    x |> f\nend"
            test_format(squote, squote; pipe_to_function_call = true)

            # dotted tuple of functions
            # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/647
            sdotcall = "x .|> (f, g)"
            test_format(sdotcall, sdotcall; pipe_to_function_call = true)
        end
    end

    @testset "function shortdef to longdef" begin
        str_ = "foo(a) = bodybodybody"
        str = """
        function foo(a)
            bodybodybody
        end"""
        test_format(str_, str_; indent=4, margin=length(str_), short_to_long_function_def = true)
        test_format(str_, str; indent=4, margin=length(str_) - 1, short_to_long_function_def = true)

        str_ = "foo(a::T) where {T} = bodybodybodybodybodybodyb"
        str = """
        function foo(a::T) where {T}
            bodybodybodybodybodybodyb
        end"""
        test_format(str_, str_; indent=4, margin=length(str_), short_to_long_function_def = true)
        test_format(str_, str; indent=4, margin=length(str_) - 1, short_to_long_function_def = true)

        str_ = "foo(a::T)::R where {T} = bodybodybodybodybodybodybody"
        str = """
        function foo(a::T)::R where {T}
            bodybodybodybodybodybodybody
        end"""
        test_format(str_, str_; indent=4, margin=length(str_), short_to_long_function_def = true)
        test_format(str_, str; indent=4, margin=length(str_), short_to_long_function_def = true,
            force_long_function_def = true)
        test_format(str_, str_; indent=4, margin=length(str_), short_to_long_function_def = false,
            force_long_function_def = false)
        test_format(str_, str; indent=4, margin=length(str_) - 1, short_to_long_function_def = true)
    end

    @testset "function longdef to shortdef" begin
        str_ = """
        function foo(a)
            bodybodybody
        end"""
        str = "foo(a) = bodybodybody"
        test_format(str_, str_; indent=4, margin=length(str) - 1, long_to_short_function_def = true)
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def = true)

        str_ = """
        function foo(a::T) where {T}
            bodybodybodybodybodybodyb
        end"""
        str = "foo(a::T) where {T} = bodybodybodybodybodybodyb"
        test_format(str_, str_; indent=4, margin=length(str) - 1, long_to_short_function_def = true)
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def = true)

        str_ = """
        function foo(a::T)::R where {T}
            bodybodybodybodybodybodybody
        end"""
        str = "foo(a::T)::R where {T} = bodybodybodybodybodybodybody"
        test_format(str_, str_; indent=4, margin=length(str) - 1, long_to_short_function_def = true)
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def = true)

        str_ = """
        function foo(a)
            return a + 1
        end"""
        str = "foo(a) = a + 1"
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def = true)

        str = """
        function foo()
            expr1
            expr2
        end"""
        test_format(str, str; indent=4, margin=length(str), long_to_short_function_def = true)

        str_ = """
        function foo(a)
            return if a > 1
                2
            else
                nothing
            end
        end"""

        str = """
        foo(a) =
            if a > 1
                2
            else
                nothing
            end"""
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def = true)
        test_format(str_, str; indent=4, margin=length(str), long_to_short_function_def = true)
    end

    @testset "always use return" begin
        str_ = "foo(a) = bodybodybody"
        str = """
        function foo(a)
            return bodybodybody
        end"""
        test_format(str_, str; indent=4, margin=length(str_) - 1, short_to_long_function_def = true,
            always_use_return = true)

        str_ = """
        function foo()
            expr1
            expr2
        end"""
        str = """
        function foo()
            expr1
            return expr2
        end"""
        test_format(str_, str; indent=4, margin=length(str_) - 1, always_use_return = true)

        str_ = """
        macro foo()
            expr1
            expr2
        end"""
        str = """
        macro foo()
            expr1
            return expr2
        end"""
        test_format(str_, str; indent=4, margin=length(str_) - 1, always_use_return = true)

        str_ = """
        map(arg1, arg2) do x, y
            expr1
            expr2
        end"""
        str = """
        map(arg1, arg2) do x, y
            expr1
            return expr2
        end"""
        test_format(str_, str; indent=4, margin=length(str_) - 1, always_use_return = true)

        str = """
        function foo()
            @macrocall(expr2)
        end"""
        test_format(str, str; indent=4, margin=92, always_use_return = true)

        str = """
        function foo()
            @macroblock expr2
        end"""
        test_format(str, str; indent=4, margin=92, always_use_return = true)

        str = """
        function foo()
            for i = 1:10
                println(i)
            end
        end"""
        test_format(str, str; indent=4, margin=92, always_use_return = true)

        str = """
        function f(a)
            if a > 0
                return -1
            else
                return 1
            end
        end"""
        test_format(str, str; indent=4, margin=92, always_use_return = true)

        @testset "426" begin
            # throw function heuristic
            str = """
            function f(x)
                x == 1 && return "a"
                x == 2 && return "b"
                throw(ArgumentError("x must be 1 or 2"))
            end
            """
            test_format(str, str; always_use_return = true)
        end

        @testset "507" begin
            # detect return
            str = """
            function f()
                (1 + 1; return 2)
            end
            """
            test_format(str, str; always_use_return = true)
        end
    end

    @testset "whitespace in keyword arguments" begin
        str_ = "f(; a = b)"
        str = "f(; a=b)"
        test_format(str_, str; indent=4, margin=92, whitespace_in_kwargs = false)

        str = "f(; a!) = a!"
        test_format(str, str; indent=4, margin=92, whitespace_in_kwargs = false)

        # issue 242
        str_ = "f(a, b! = 1; c! = 2, d = 3, e! = 4)"
        str = "f(a, (b!)=1; (c!)=2, d=3, (e!)=4)"
        test_format(str_, str; indent=4, margin=92, whitespace_in_kwargs = false)

        str_ = "( k1 =v1,  k2! = v2)"
        str = "(k1=v1, (k2!)=v2)"
        test_format(str_, str, YASStyle(); indent=4, margin=80, whitespace_in_kwargs = false)
        test_format(str_, str; indent=4, margin=80, whitespace_in_kwargs = false)

        str_ = "( k1 =v1,  k2! = v2)"
        str = "(k1 = v1, k2! = v2)"
        test_format(str_, str, YASStyle(); indent=4, margin=80, whitespace_in_kwargs = true)
        test_format(str_, str; indent=4, margin=80, whitespace_in_kwargs = true)

        str_ = "(; g = >=(1))"
        str = "(; g=(>=(1)))"
        test_format(str_, str; indent=4, margin=92, whitespace_in_kwargs = false)

        s = "C(; Vt=Ȳ')"
        test_format(s, s; indent=4, margin=100, whitespace_in_kwargs = false)
    end

    @testset "annotate untyped fields with `Any`" begin
        str = """
        struct name
            arg::Any
        end"""

        str_ = """
        struct name
            arg
        end"""
        test_format(str_, str)

        str_ = """
        struct name
        arg
        end"""
        test_format(str_, str)

        str_ = """
        struct name
                arg
            end"""
        test_format(str_, str)

        t = run_pretty(
            str_;
            opts = Options(; margin = 80)
        )
        @test length(t) == 12

        str = """
        mutable struct name
            reallylongfieldname::Any
        end"""

        str_ = """
        mutable struct name
            reallylongfieldname
        end"""
        test_format(str_, str)

        str_ = """
        mutable struct name
        reallylongfieldname
        end"""
        test_format(str_, str)

        str_ = """
        mutable struct name
                reallylongfieldname
            end"""
        test_format(str_, str)

        t = run_pretty(
            str_;
            opts = Options(; margin = 80)
        )
        @test length(t) == 28

        str = """
        struct name
            arg
        end"""

        str_ = """
        struct name
            arg
        end"""
        test_format(str_, str; annotate_untyped_fields_with_any = false)

        str_ = """
        struct name
        arg
        end"""
        test_format(str_, str; annotate_untyped_fields_with_any = false)

        str_ = """
        struct name
                arg
            end"""
        test_format(str_, str; annotate_untyped_fields_with_any = false)

        t = run_pretty(
            str_;
            opts = Options(; margin = 80, annotate_untyped_fields_with_any = false),
        )
        @test length(t) == 11

        str = """
        mutable struct name
            reallylongfieldname
        end"""

        str_ = """
        mutable struct name
            reallylongfieldname
        end"""
        test_format(str_, str; annotate_untyped_fields_with_any = false)

        str_ = """
        mutable struct name
        reallylongfieldname
        end"""
        test_format(str_, str; annotate_untyped_fields_with_any = false)

        str_ = """
        mutable struct name
                reallylongfieldname
            end"""
        test_format(str_, str; annotate_untyped_fields_with_any = false)

        t = run_pretty(
            str_;
            opts = Options(; margin = 80, annotate_untyped_fields_with_any = false),
        )
        @test length(t) == 23
    end

    @testset "format docstrings" begin
        @testset "basic" begin
            str = """
            \"""
            doc
            \"""
            function f()
                20
            end"""
            t = run_pretty(str; opts = Options(; margin = 80))
            @test length(t) == 12

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
            t = run_pretty(str; opts = Options(; margin = 80))
            @test length(t) == 11

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

        @testset "issue 597" begin
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
    end

    @testset "align struct fields" begin
        str_ = """
        struct Foo
            a::T
        end"""
        str = """
        struct Foo
            a::T
        end"""
        test_format(str_, str; align_struct_field = true)

        str = """
        struct Foo
            a             :: T
            longfieldname :: B
        end"""
        str_ = """
        struct Foo
            a::T
            longfieldname::B
        end"""
        test_format(str, str; align_struct_field = true)
        test_format(str, str_; align_struct_field = false)

        str_ = """
        Base.@kwdef struct Options
            indent_size::Int                       = 4
            margin::Int                            = 92
            always_for_in::Bool                 = false
            whitespace_typedefs::Bool          = false
            whitespace_ops_in_indices::Bool        = false
            remove_extra_newlines::Bool            = false
            import_to_using::Bool                  = false
            pipe_to_function_call::Bool            = false
            short_to_long_function_def::Bool      = false
            always_use_return::Bool           = false
            whitespace_in_kwargs::Bool          = true
            annotate_untyped_fields_with_any::Bool = true
            format_docstrings::Bool             = false
            align_struct_fields::Bool           = false

            another_field1::BlahBlahBlah = 10
            field2::Foo                          = 10

            Options() = new()
        end"""
        str = """
        Base.@kwdef struct Options
            indent_size::Int                       = 4
            margin::Int                            = 92
            always_for_in::Bool                    = false
            whitespace_typedefs::Bool              = false
            whitespace_ops_in_indices::Bool        = false
            remove_extra_newlines::Bool            = false
            import_to_using::Bool                  = false
            pipe_to_function_call::Bool            = false
            short_to_long_function_def::Bool       = false
            always_use_return::Bool                = false
            whitespace_in_kwargs::Bool             = true
            annotate_untyped_fields_with_any::Bool = true
            format_docstrings::Bool                = false
            align_struct_fields::Bool              = false

            another_field1::BlahBlahBlah = 10
            field2::Foo = 10

            Options() = new()
        end"""
        test_format(str_, str; align_struct_field = true)

        str_ = """
        Base.@kwdef struct Options
            indent_size::Int = 4
            margin::Int = 92
            always_for_in::Bool = false
            whitespace_typedefs::Bool = false
            whitespace_ops_in_indices::Bool = false
            remove_extra_newlines::Bool = false
            import_to_using::Bool = false
            pipe_to_function_call::Bool = false
            short_to_long_function_def::Bool = false
            always_use_return::Bool = false
            whitespace_in_kwargs::Bool = true
            annotate_untyped_fields_with_any::Bool = true
            format_docstrings::Bool = false
            align_struct_fields::Bool = false

            another_field1::BlahBlahBlah = 10
            field2::Foo = 10

            Options() = new()
        end"""
        test_format(str, str; align_struct_field = true)
        test_format(str, str_; align_struct_field = false)

        str = """
        Base.@kwdef struct Options
            indent_size::Int                       = 4
            margin::Int                            = 92
            always_for_in::Bool                    = false
            whitespace_typedefs::Bool              = false
            whitespace_ops_in_indices::Bool        = false
            remove_extra_newlines::Bool            = false
            import_to_using::Bool                  = false
            pipe_to_function_call::Bool            = false
            short_to_long_function_def::Bool       = false
            always_use_return::Bool                = false
            whitespace_in_kwargs::Bool             = true
            annotate_untyped_fields_with_any::Bool = true
            format_docstrings::Bool                = false
            align_struct_fields::Bool              = false

            another_field1::BlahBlahBlah =
                10
            field2::Foo =
                10

            Options() =
                new()
        end"""
        test_format(str, str; indent=4, margin=1, align_struct_field = true)
    end

    @testset "align assignment" begin
        str_ = """
        const variable1 = 1
        const var2      = 2
        const var3 = 3
        const var4 = 4"""
        str = """
        const variable1 = 1
        const var2      = 2
        const var3      = 3
        const var4      = 4"""
        test_format(str_, str; align_assignment = true)

        str = """
        const variable1 = 1
        const variable2 = 2
        const var3 = 3
        const var4 = 4"""
        test_format(str, str; align_assignment = true)

        str_ = """
        module Foo

        const UTF8PROC_STABLE    = (1<<1)
        const UTF8PROC_COMPAT    = (1<<2)
        const UTF8PROC_COMPOSE   = (1<<3)
        const UTF8PROC_DECOMPOSE = (1<<4)
        const UTF8PROC_IGNORE    = (1<<5)
        const UTF8PROC_REJECTNA  = (1<<6)
        const UTF8PROC_NLF2LS    = (1<<7)
        const UTF8PROC_NLF2PS    = (1<<8)
        const UTF8PROC_NLF2LF    = (UTF8PROC_NLF2LS | UTF8PROC_NLF2PS)
        const UTF8PROC_STRIPCC   = (1<<9)
        const UTF8PROC_CASEFOLD  = (1<<10)
        const UTF8PROC_CHARBOUND = (1<<11)
        const UTF8PROC_LUMP=(1<<12)
        const UTF8PROC_STRIP         = (1<<13) # align this

        const FOOBAR = 0
        const FOO = 1

        end"""

        str = """
        module Foo

        const UTF8PROC_STABLE    = (1<<1)
        const UTF8PROC_COMPAT    = (1<<2)
        const UTF8PROC_COMPOSE   = (1<<3)
        const UTF8PROC_DECOMPOSE = (1<<4)
        const UTF8PROC_IGNORE    = (1<<5)
        const UTF8PROC_REJECTNA  = (1<<6)
        const UTF8PROC_NLF2LS    = (1<<7)
        const UTF8PROC_NLF2PS    = (1<<8)
        const UTF8PROC_NLF2LF    = (UTF8PROC_NLF2LS | UTF8PROC_NLF2PS)
        const UTF8PROC_STRIPCC   = (1<<9)
        const UTF8PROC_CASEFOLD  = (1<<10)
        const UTF8PROC_CHARBOUND = (1<<11)
        const UTF8PROC_LUMP      = (1<<12)
        const UTF8PROC_STRIP     = (1<<13) # align this

        const FOOBAR = 0
        const FOO = 1

        end"""
        test_format(str_, str; align_assignment = true)
        test_format(str_, str; align_assignment = true, join_lines_based_on_source = true)

        # the aligned consts will NOT be nestable
        str = """
        module Foo

        const UTF8PROC_STABLE    = (1<<1)
        const UTF8PROC_COMPAT    = (1<<2)
        const UTF8PROC_COMPOSE   = (1<<3)
        const UTF8PROC_DECOMPOSE = (1<<4)
        const UTF8PROC_IGNORE    = (1<<5)
        const UTF8PROC_REJECTNA  = (1<<6)
        const UTF8PROC_NLF2LS    = (1<<7)
        const UTF8PROC_NLF2PS    = (1<<8)
        const UTF8PROC_NLF2LF    = (UTF8PROC_NLF2LS | UTF8PROC_NLF2PS)
        const UTF8PROC_STRIPCC   = (1<<9)
        const UTF8PROC_CASEFOLD  = (1<<10)
        const UTF8PROC_CHARBOUND = (1<<11)
        const UTF8PROC_LUMP      = (1<<12)
        const UTF8PROC_STRIP     = (1<<13) # align this

        const FOOBAR =
            0
        const FOO =
            1

        end"""
        test_format(str_, str; indent=4, margin=1, align_assignment = true)
        test_format(str_, str; indent=4, margin=1, align_assignment = true, join_lines_based_on_source = true)

        str = """
        a  = 1
        bc = 2

        long_variable = 1
        other_var     = 2
        """
        test_format(str, str; indent=4, margin=1, align_assignment = true)

        str = """
        eclipse  = true
        s̄_b      = SVector{3,T}(0, 0, 0)
        css_axes = :css_axes_eclipse
        """
        test_format(str, str; align_assignment = true)

        str = """
        vcat(X::T...) where {T}         = T[X[i] for i = 1:length(X)]
        vcat(X::T...) where {T<:Number} = T[X[i] for i = 1:length(X)]
        hcat(X::T...) where {T}         = T[X[j] for i = 1:1, j = 1:length(X)]
        hcat(X::T...) where {T<:Number} = T[X[j] for i = 1:1, j = 1:length(X)]
        """
        test_format(str, str; indent=4, margin=1, align_assignment = true)
        test_format(str, str; indent=4, margin=1, align_assignment = true, join_lines_based_on_source = true)

        # ambiguous ordering
        str = """
        μs, ns = divrem(ns, 1000)
        ms, μs = divrem(μs, 1000)
        s, ms = divrem(ms, 1000)
        """
        test_format(str, str; align_assignment = true)

        str = """
        run = wandb.init(
            name      = name,
            project   = project,
            config    = config,
            notes     = notes,
            tags      = tags,
            dir       = dir,
            job_type  = job_type,
            entity    = entity,
            group     = group,
            id        = id,
            reinit    = reinit,
            resume    = resume,
            anonymous = anonymous ? "allow" : "never",
        )
        """
        test_format(str, str; indent=4, margin=100, align_assignment = true, whitespace_in_kwargs = false)
        test_format(str, str; indent=4, margin=100, align_assignment = true,
            whitespace_in_kwargs = false,
            join_lines_based_on_source = true)

        str_ = """
        s           = model.sys
        @unpack A,K = s
        C           = s.C
        poles       = eigvals(A - K * C)
        """
        str = """
        s            = model.sys
        @unpack A, K = s
        C            = s.C
        poles        = eigvals(A - K * C)
        """
        test_format(str_, str; indent=4, margin=100, align_assignment = true)
        test_format(str_, str; indent=4, margin=100, align_assignment = true,
            join_lines_based_on_source = true)

        str_ = """
        s             = model.sys
        @unpack A,K   = s
        C             = s.C
        const polesss = eigvals(A - K * C)
        """
        str = """
        s             = model.sys
        @unpack A, K  = s
        C             = s.C
        const polesss = eigvals(A - K * C)
        """
        test_format(str_, str; indent=4, margin=100, align_assignment = true)

        str = """
        function stabilize(model)
            s            = model.sys
            @unpack A, K = s
            C            = s.C
            poles        = eigvals(A - K * C)
            newpoles     = map(poles) do p
                ap = abs(p)
                ap <= 1 && (return p)
                p / (ap + sqrt(eps()))
            end
            K2           = ControlSystems.acker(A', C', newpoles)' .|> real
            all(abs(p) <= 1 for p in eigvals(A - K * C)) || @warn("Failed to stabilize predictor")
            s.K .= K2
            model
        end
        """
        test_format(str, str; indent=4, margin=100, align_assignment = true)
        test_format(str, str; indent=4, margin=100, align_assignment = true,
            join_lines_based_on_source = true)
    end

    @testset "align conditionals" begin
        str_ = """
        index = zeros(n <= typemax(Int8)  ? Int8  :
                      n <= typemax(Int16) ? Int16 :
                      n <= typemax(Int32) ? Int32 : Int64, n)
        """

        str = """
        index = zeros(
            n <= typemax(Int8)  ? Int8  :
            n <= typemax(Int16) ? Int16 :
            n <= typemax(Int32) ? Int32 : Int64,
            n,
        )
        """
        test_format(str_, str; align_conditional = true)

        str = """
        index =
            zeros(
                n <= typemax(Int8)  ? Int8  :
                n <= typemax(Int16) ? Int16 :
                n <= typemax(Int32) ? Int32 : Int64,
                n,
            )
        """
        test_format(str_, str; indent=4, margin=1, align_conditional = true)

        str_ = """
        index = zeros(n <= typemax(Int8)  ? Int8 :   # inline
                        #comment 1
                      n <= typemax(Int16) ? Int16 :   # inline 2
                              # comment 2
                      n <= typemax(Int32) ? Int32 : # inline 3
                      Int64, n)
        """
        str = """
        index =
            zeros(
                n <= typemax(Int8)  ? Int8 :   # inline
                #comment 1
                n <= typemax(Int16) ? Int16 :   # inline 2
                # comment 2
                n <= typemax(Int32) ? Int32 : # inline 3
                Int64,
                n,
            )
        """
        test_format(str_, str; indent=4, margin=1, align_conditional = true)
        test_format(str_, str; indent=4, margin=1, align_conditional = true,
            join_lines_based_on_source = true)

        str_ = """
        index = zeros(n <= typemax(Int8)  ? Int8  :    # inline
                      n <= typemax(Int16) ? Int16 : n <= typemax(Int32) ? Int32 : Int64, n)
        """

        str = """
        index =
            zeros(
                n <= typemax(Int8)  ? Int8  :    # inline
                n <= typemax(Int16) ? Int16 : n <= typemax(Int32) ? Int32 : Int64,
                n,
            )
        """
        test_format(str_, str; indent=4, margin=1, align_conditional = true)
        test_format(str_, str; indent=4, margin=1, align_conditional = true,
            join_lines_based_on_source = true)

        str_ = """
        index =
            zeros(
                n <= typemax(Int8)     ? Int8  :
                n <= typemax(Int16A) ? Int16  :
                n <= typemax(Int32)  ? Int322 : Int64,
                n,
            )
        """
        str = """
        index =
            zeros(
                n <= typemax(Int8)   ? Int8   :
                n <= typemax(Int16A) ? Int16  :
                n <= typemax(Int32)  ? Int322 : Int64,
                n,
            )
        """
        test_format(str_, str; indent=4, margin=1, align_conditional = true)

        str_ = """
        val = cst.kind === Tokens.ABSTRACT ? "abstract" :
            cst.kind === Tokens.BAREMODULE ? "baremodule" : ""
        """
        str = """
        val = cst.kind === Tokens.ABSTRACT ? "abstract" : cst.kind === Tokens.BAREMODULE ? "baremodule" : ""
        """
        test_format(str_, str; indent=4, margin=100, align_conditional = true)

        str_ = """
        val = cst.kind === Tokens.ABSTRACT ? "abstract" :
            cst.kind === Tokens.BAREMODUL  ? "baremodule" : ""
        """
        str = """
        val = cst.kind === Tokens.ABSTRACT  ? "abstract" :
              cst.kind === Tokens.BAREMODUL ? "baremodule" : ""
        """
        test_format(str_, str; indent=4, margin=100, align_conditional = true)
        test_format(str_, str; indent=4, margin=100, align_conditional = true,
            join_lines_based_on_source = true)

        str = """
        val =
            cst.kind === Tokens.ABSTRACT  ? "abstract" :
            cst.kind === Tokens.BAREMODUL ? "baremodule" : ""
        """
        test_format(str_, str; indent=4, margin=1, align_conditional = true)
        test_format(str_, str; indent=4, margin=1, align_conditional = true,
            join_lines_based_on_source = true)
    end

    @testset "align pair arrow `=>`" begin
        str_ = """
        pages = [
            "Introduction" => "index.md",
            "How It Works" => "how_it_works.md",
            "Code Style"          => "style.md",
            "Skipping Formatting" => "skipping_formatting.md",
            "Syntax Transforms" => "transforms.md",
            "Custom Alignment" => "custom_alignment.md",
            "Custom Styles" => "custom_styles.md",
            "YAS Style" => "yas_style.md",
            "Configuration File" => "config.md",
            "API Reference" => "api.md",
        ]
        """
        str = """
        pages = [
            "Introduction"        => "index.md",
            "How It Works"        => "how_it_works.md",
            "Code Style"          => "style.md",
            "Skipping Formatting" => "skipping_formatting.md",
            "Syntax Transforms"   => "transforms.md",
            "Custom Alignment"    => "custom_alignment.md",
            "Custom Styles"       => "custom_styles.md",
            "YAS Style"           => "yas_style.md",
            "Configuration File"  => "config.md",
            "API Reference"       => "api.md",
        ]
        """
        test_format(str_, str; indent=4, margin=100, align_pair_arrow = true)

        str = """
        pages =
            [
                "Introduction"        => "index.md",
                "How It Works"        => "how_it_works.md",
                "Code Style"          => "style.md",
                "Skipping Formatting" => "skipping_formatting.md",
                "Syntax Transforms"   => "transforms.md",
                "Custom Alignment"    => "custom_alignment.md",
                "Custom Styles"       => "custom_styles.md",
                "YAS Style"           => "yas_style.md",
                "Configuration File"  => "config.md",
                "API Reference"       => "api.md",
            ]
        """
        test_format(str_, str; indent=4, margin=1, align_pair_arrow = true)
        test_format(str_, str; indent=4, margin=1, align_pair_arrow = true, join_lines_based_on_source = true)
    end

    @testset "conditional to `if` block" begin
        str_ = """
        E ? A : B
        """
        test_format(str_, str_; indent=2, margin=9, conditional_to_if = true)

        str = """
        if E
          A
        else
          B
        end
        """
        test_format(str_, str; indent=2, margin=8, conditional_to_if = true)

        str_ = """
        begin
            E1 ? A : E2 ? B : foo(E333, E444) ? D : E
        end
        """
        test_format(str_, str_; indent=4, margin=45, conditional_to_if = true)

        str = """
        begin
            if E1
                A
            elseif E2
                B
            elseif foo(E333, E444)
                D
            else
                E
            end
        end
        """
        test_format(str_, str; indent=4, margin=44, conditional_to_if = true)
        test_format(str_, str; indent=4, margin=26, conditional_to_if = true)

        str = """
        begin
            if E1
                A
            elseif E2
                B
            elseif foo(
                E333,
                E444,
            )
                D
            else
                E
            end
        end
        """
        test_format(str_, str; indent=4, margin=25, conditional_to_if = true)

        str_ = """
        foobar = some_big_long_thing * 10_000 == 2 ?
            #comment
            bar :
            #comment
            another_big_long_thing * 10^300 / this_things_here
        """

        str = """
        foobar = if some_big_long_thing * 10_000 == 2
            #comment
            bar
        else
            #comment
            another_big_long_thing * 10^300 / this_things_here
        end
        """
        test_format(str_, str; conditional_to_if = true)
    end

    @testset "normalize_line_endings" begin
        windows_str = "a\r\nb\r\nc\r\nd"
        unix_str = "a\nb\nc\nd"
        mixed_windows_str = "a\r\nb\r\nc\nd"
        mixed_unix_str = "a\r\nb\nc\nd"

        test_format(windows_str, windows_str; normalize_line_endings = "auto")
        test_format(unix_str, unix_str; normalize_line_endings = "auto")
        test_format(mixed_windows_str, windows_str; normalize_line_endings = "auto")
        test_format(mixed_unix_str, unix_str; normalize_line_endings = "auto")

        test_format(windows_str, unix_str; normalize_line_endings = "unix")
        test_format(unix_str, unix_str; normalize_line_endings = "unix")
        test_format(mixed_windows_str, unix_str; normalize_line_endings = "unix")
        test_format(mixed_unix_str, unix_str; normalize_line_endings = "unix")

        test_format(windows_str, windows_str; normalize_line_endings = "windows")
        test_format(unix_str, windows_str; normalize_line_endings = "windows")
        test_format(mixed_windows_str, windows_str; normalize_line_endings = "windows")
        test_format(mixed_unix_str, windows_str; normalize_line_endings = "windows")
    end

    @testset "align matrix" begin
        # default formatting
        str = """
        a = [
            100 300 400
            1 eee 40000
            2 α b
        ]
        """
        test_format(str, str; align_matrix = true)
        str_ = """
        a = [100 300 400
             1 eee 40000
             2 α b]
        """
        test_format(str, str_, YASStyle(); align_matrix = true)

        # left-aligned
        str = """
        a = [
            100 300 400
            1   eee 40000
            2   α   b
        ]
        """
        test_format(str, str; align_matrix = true)
        str_ = """
        a = [100 300 400
             1   eee 40000
             2   α   b]
        """
        test_format(str, str_, YASStyle(); align_matrix = true)

        # right-aligned
        str = """
        a = [
            100 3000   400
              1  eee     b
              2    α 40000
        ]
        """
        test_format(str, str; align_matrix = true)
        str_ = """
        a = [100 3000   400
               1  eee     b
               2    α 40000]
        """
        test_format(str, str_, YASStyle(); align_matrix = true)
    end

    @testset "ignore maximum width" begin
        @testset "maintain original structure" begin
            for m in (:module, :baremodule)
                str_ = "$m M body end"
                test_format(str_, format_text(str_); join_lines_based_on_source = true)
            end

            str_ = "struct S body end"
            test_format(str_, format_text(str_; annotate_untyped_fields_with_any = false); join_lines_based_on_source = true,
                annotate_untyped_fields_with_any = false)

            str_ = "mutable struct S body end"
            test_format(str_, format_text(str_; annotate_untyped_fields_with_any = false); join_lines_based_on_source = true,
                annotate_untyped_fields_with_any = false)

            str_ = """
            abstract type
            foo

              end"""
            test_format(str_, format_text(str_); join_lines_based_on_source = true)

            str_ = """
            primitive type
            foo

            64

              end"""
            test_format(str_, format_text(str_); join_lines_based_on_source = true)

            str_ = """
            function foo

              end"""
            test_format(str_, format_text(str_); join_lines_based_on_source = true)

            for f in (:function, :macro)
                str_ = "$f foo() body end"
                test_format(str_, format_text(str_); join_lines_based_on_source = true)
            end

            str_ = "try a catch e finally c end"
            test_format(str_, format_text(str_); join_lines_based_on_source = true)

            str_ = "if a body1 elseif b body2 elseif c body3 else body4 end"
            test_format(str_, format_text(str_); join_lines_based_on_source = true)

            str_ = "begin a;b;c end"
            test_format(str_, format_text(str_); join_lines_based_on_source = true)

            str_ = "function foo() a;b;c end"
            test_format(str_, format_text(str_); join_lines_based_on_source = true)
        end

        @testset "misc" begin
            str = raw"""
            @testset "T=$T, m=$m, n=$n" for T in (Float64, ComplexF64), m in (2, 3), n in (1, 3)
                body
            end
            """
            test_format(str, str; indent=4, margin=84, join_lines_based_on_source = true)

            str_ = """
            function foo(
                arg1,
                arg2,)

                body
            end
            """
            str = """
            function foo(
                arg1,
                arg2)

                body
            end
            """
            test_format(str_, str; join_lines_based_on_source = true)
            str = """
            function foo(
                arg1,
                arg2)

                return body
            end
            """
            # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1045
            @test_broken false
            # test_format(str_, str, BlueStyle(); join_lines_based_on_source = true)
        end

        @testset "binary op" begin
            str_ = """
            a =
            b
            """
            str = """
            a =
                b
            """
            test_format(str_, str; join_lines_based_on_source = true)
            test_format(str_, str, BlueStyle(); join_lines_based_on_source = true)

            str = """
            a = b
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            a =
            (b,c)
            """
            str = """
            a =
                (b, c)
            """
            test_format(str_, str; join_lines_based_on_source = true)

            str = """
            a = (b, c)
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)
            test_format(str_, str, BlueStyle(); join_lines_based_on_source = true)

            str_ = """
            a =
            "hello"
            """
            str = """
            a = "hello"
            """
            test_format(str_, str; join_lines_based_on_source = true)
            test_format(str_, str, BlueStyle(); join_lines_based_on_source = true)
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)
        end

        @testset "blue style" begin
            str = """
            function foo(
                arg1, arg2
            )
                return body
            end
            """
            test_format(str, str, BlueStyle(); indent=4, margin=1000, join_lines_based_on_source = true)
            test_format(str, str, BlueStyle(); indent=4, margin=15)

            str = """
            function foo(
                arg1,
                arg2,
            )
                return body
            end
            """
            test_format(str, str, BlueStyle(); indent=4, margin=1000, join_lines_based_on_source = true)
        end

        @testset "yas style" begin
            str_ = """
            function foo(
                arg1,
                arg2,
            ) where {
            T1,
            T2,
            }
                body
            end
            """
            @test format_text(str_, YASStyle(); join_lines_based_on_source = true) ==
                  format_text(str_, YASStyle(); indent=4, margin=1, join_lines_based_on_source = false)

            str_ = """
            @foo(
                arg1,
                arg2,
            )
            """
            str = """
            @foo(arg1,
                 arg2,)
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            (
                arg1,
                arg2,
            )
            """
            str = """
            (arg1,
             arg2)
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            [
                arg1,
                arg2,
            ]
            """
            str = """
            [arg1,
             arg2]
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            A[
                arg1,
                arg2,
            ]
            """
            str = """
            A[arg1,
              arg2]
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            {
                arg1,
                arg2,
            }
            """
            str = """
            {arg1,
             arg2}
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            A{
                arg1,
                arg2,
            }
            """
            str = """
            A{arg1,
              arg2}
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            (
                invisbrackets
            )
            """
            str = """
            (invisbrackets)
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            [
                row1;
                row2;
            ]
            """
            str = """
            [row1;
             row2;]
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            T[
                row1;
                row2;
            ]
            """
            str = """
            T[row1;
              row2;]
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)

            str_ = """
            [
            a for a = 1:10
            ]
            """
            str = """
            [a for a in 1:10]
            """
            test_format(str_, str, YASStyle(); join_lines_based_on_source = true)
        end

        @testset "imports" begin
            str_ = """
            using A,  #inline
                      # comment
            B, C#inline"""
            str = """
            using A,  #inline
              # comment
              B, C#inline"""
            test_format(str_, str; indent=2, margin=80, join_lines_based_on_source = true)

            str_ = """
            using CommonMark:
                AdmonitionRule,
                CodeBlock, enable!, FootnoteRule,
                markdown,
                MathRule,
                Parser,
                Rule, TableRule
            """
            str = """
            using CommonMark:
                AdmonitionRule,
                CodeBlock, enable!,
                FootnoteRule,
                markdown,
                MathRule,
                Parser,
                Rule, TableRule
            """
            test_format(str_, str_; indent=4, margin=37, join_lines_based_on_source = true)
            test_format(str_, str; indent=4, margin=36, join_lines_based_on_source = true)

            str = """
            using CommonMark:
                              AdmonitionRule,
                              CodeBlock, enable!, FootnoteRule,
                              markdown,
                              MathRule,
                              Parser,
                              Rule, TableRule
            """
            test_format(str_, str, YASStyle(); indent=4, margin=51, join_lines_based_on_source = true)

            str = """
            using CommonMark:
                              AdmonitionRule,
                              CodeBlock, enable!,
                              FootnoteRule,
                              markdown,
                              MathRule,
                              Parser,
                              Rule, TableRule
            """
            test_format(str_, str, YASStyle(); indent=4, margin=50, join_lines_based_on_source = true)
        end

        # NOTE: not sure since test makes sense anymore.
        # It is generally not a great idea to remove the semicolons here since
        # it can be potentially change the semantics or lead to code errors.
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/745
        @testset "matrices" begin
            str_ = """
            T[ a b Expr();
            d e Expr();]"""
            str = """
            T[a b Expr();
                d e Expr();]"""
            test_format(str_, str; join_lines_based_on_source = true)
        end

        @testset "function defs" begin
            s = """
            function foo()
            end
            """
            test_format(s, s; join_lines_based_on_source = true)

            s = """
            function foo
            end
            """
            test_format(s, s; join_lines_based_on_source = true)
        end

        @testset "macro defs" begin
            s = """
            macro foo()
            end
            """
            test_format(s, s; join_lines_based_on_source = true)

            s = """
            macro foo
            end
            """
            test_format(s, s; join_lines_based_on_source = true)
        end

        @testset "typedefs" begin
            s = """
            struct S
            end
            """
            test_format(s, s; join_lines_based_on_source = true)

            s = """
            mutable struct S
            end
            """
            test_format(s, s; join_lines_based_on_source = true)
        end

        @testset "modules" begin
            s = """
            module M
            end
            """
            test_format(s, s; join_lines_based_on_source = true)

            s = """
            baremodule BM
            end
            """
            test_format(s, s; join_lines_based_on_source = true)
        end
    end

    @testset "`indent_submodule`" begin
        str_ = """
        "doc"
        module Foo

        function foo(arg)
        body
        end

        module Bar
        x = 2
        y = 4
        baremodule C
                     foo = (arg1, arg2)
            end
        end

        z = 5

        end
        """
        str = """
        "doc"
        module Foo

        function foo(arg)
          body
        end

        module Bar
          x = 2
          y = 4
          baremodule C
            foo = (arg1, arg2)
          end
        end

        z = 5

        end
        """
        test_format(str_, str; indent=2, margin=22, indent_submodule = true)

        str = """
        "doc"
        module Foo

        function foo(arg)
          body
        end

        module Bar
          x = 2
          y = 4
          baremodule C
            foo =
              (arg1, arg2)
          end
        end

        z = 5

        end
        """
        test_format(str_, str; indent=2, margin=21, indent_submodule = true)
    end

    @testset "`separate_kwargs_with_semicolon`" begin
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

    @testset "`surround_whereop_typeparameters`" begin
        s = """
        function NotificationType(method::AbstractString, ::Type{TPARAM}) where TPARAM
            foo
        end
        """
        test_format(s, s; surround_whereop_typeparameters = false)

        s = """
        function NotificationType(method::AbstractString, ::Type{TPARAM})::R where TPARAM
            foo
        end
        """
        test_format(s, s; surround_whereop_typeparameters = false, margin = 100)

        s = """
        NotificationType(method::AbstractString, ::Type{TPARAM}) where TPARAM = foo
        """
        test_format(s, s; surround_whereop_typeparameters = false)

        s = """
        NotificationType(method::AbstractString, ::Type{TPARAM})::R where TPARAM = foo
        """
        test_format(s, s; surround_whereop_typeparameters = false)
    end

    @testset "trailing zero" begin
        test_format("1e-2", "1e-2"; trailing_zero = true)
        test_format("1f0", "1.0f0"; trailing_zero = true)
        test_format("1.", "1.0"; trailing_zero = true)
        test_format("0x1.fp0", "0x1.fp0"; trailing_zero = true)

        test_format("1e-2", "1e-2"; trailing_zero = false)
        test_format("1f0", "1f0"; trailing_zero = false)
        test_format("1.", "1."; trailing_zero = false)
        test_format("0x1.fp0", "0x1.fp0"; trailing_zero = false)
    end

    @testset "noindent blocks" begin
        s = raw"""
        begin
        @muladd begin
            #! format: noindent
            # dawdawdaw comment
            a = 10
            b = 20

            a * b
        end
                end
        """
        s_ = raw"""
        begin
            @muladd begin
            #! format: noindent
            # dawdawdaw comment
            a = 10
            b = 20

            a * b
            end
        end
        """
        test_format(s, s_)

        s = raw"""
        begin
        @muladd begin
            #! format: noindent
            # dawdawdaw comment
            a = 10
            b = 20
            begin
               # another indent
                z = 33
            end

            a * b
        end
                end
        """
        s_ = raw"""
        begin
            @muladd begin
            #! format: noindent
            # dawdawdaw comment
            a = 10
            b = 20
            begin
                # another indent
                z = 33
            end

            a * b
            end
        end
        """
        test_format(s, s_)

        # recursive
        s = raw"""
        begin
        @muladd begin
            #! format: noindent
            # dawdawdaw comment
            a = 10
            b = 20
            begin
               # another indent
                z = 33
                        begin
                #! format: noindent
                        s = "oh shit here we go again"
                end
            end

            a * b
        end
                end
        """
        s_ = raw"""
        begin
            @muladd begin
            #! format: noindent
            # dawdawdaw comment
            a = 10
            b = 20
            begin
                # another indent
                z = 33
                begin
                #! format: noindent
                s = "oh shit here we go again"
                end
            end

            a * b
            end
        end
        """
        test_format(s, s_)
    end

    @testset "short/lazy circuit to if" begin
        s_ = """
            begin
            a && b
            end
        """
        s = """
        begin
            if a
                b
            else
                false
            end
        end
        """
        test_format(s_, s; indent=4, margin=92, short_circuit_to_if = true)

        s_ = """
            begin
            a || b
            end
        """
        s = """
        begin
            if !(a)
                b
            else
                true
            end
        end
        """
        test_format(s_, s; indent=4, margin=11, short_circuit_to_if = true)

        s = """
        begin
            if !(
                a
            )
                b
            else
                true
            end
        end
        """
        test_format(s_, s; indent=4, margin=10, short_circuit_to_if = true)

        # > 1
        s_ = """
            begin
            a && b && c && d
            end
        """
        s = """
        begin
            if a && b && c
                d
            else
                false
            end
        end
        """
        test_format(s_, s; indent=4, margin=92, short_circuit_to_if = true)

        s_ = """
            begin
            a && b && c || d
            end
        """
        s1 = """
        begin
            if !(a && b && c)
                d
            else
                true
            end
        end
        """
        test_format(s_, s1; indent=4, margin=21, short_circuit_to_if = true)

        s2 = """
        begin
            if !(
                a && b && c
            )
                d
            else
                true
            end
        end
        """
        test_format(s_, s2; indent=4, margin=20, short_circuit_to_if = true)

        s_ = """
            begin
            (a && b && c) || d
            end
        """
        test_format(s_, s1; indent=4, margin=21, short_circuit_to_if = true)
        test_format(s_, s2; indent=4, margin=20, short_circuit_to_if = true)

        s_ = """
        function foo()
            a && (b || c || d)
        end
        """
        s = """
        function foo()
            if a
                (b || c || d)
            else
                false
            end
        end
        """
        test_format(s_, s; indent=4, margin=92, short_circuit_to_if = true)

        s_ = """
        function foo(a)
            a || return "bar"

            "hello"
        end
        """
        s = """
        function foo(a)
            if !(a)
                return "bar"
            end

            "hello"
        end
        """
        test_format(s_, s; indent=4, margin=92, short_circuit_to_if = true)

        s_ = """
        function foo(a, b)
            a || return "bar"

            "hello"

            b && return "ooo"
        end
        """
        s = """
        function foo(a, b)
            if !(a)
                return "bar"
            end

            "hello"

            if b
                return "ooo"
            else
                false
            end
        end
        """
        test_format(s_, s; indent=4, margin=92, short_circuit_to_if = true)
    end

    @testset "disallow single arg nesting" begin
        s1 = raw"""
        function_call(
            "String argument"
        )
        [array_item(
            10
        )]
        {key => value(
            "String value"
        )}
        """
        s2 = raw"""
        function_call("String argument")
        [array_item(10)]
        {key =>
          value("String value")}
        """
        test_format(s1, s2; indent=2, margin=1, disallow_single_arg_nesting = true)
    end
end

end
