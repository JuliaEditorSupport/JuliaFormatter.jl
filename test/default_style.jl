module DefaultTests

using Test
using JuliaSyntax
using JuliaFormatter: JuliaFormatter, DefaultStyle, Options, format_file
using JuliaFormatter.Internal: test_format

function run_pretty(text::String; style = DefaultStyle(), opts = Options())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; version=JuliaFormatter.SUPPORTED_SYNTAX_VERSION)
    t = JuliaFormatter.pretty(style, g, s)
    t
end
run_pretty(text::String, margin::Int) = run_pretty(text, opts = Options(margin = margin))

function run_nest(text::String; opts = Options(), style = DefaultStyle())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; version=JuliaFormatter.SUPPORTED_SYNTAX_VERSION)
    t = JuliaFormatter.pretty(style, g, s)
    JuliaFormatter.nest!(style, t, s)
    t, s
end
run_nest(text::String, margin::Int) = run_nest(text, opts = Options(margin = margin))

@testset "Default Style" begin
    @testset "basic" begin
        test_format("", "")
        test_format("a", "a")
        test_format("a  #foo", "a  #foo")
        test_format("#foo", "#foo")

        str = """
        begin
            #=
               Hello, world!
             =#
        end
        """
        test_format(str, str)

        str = """
        #=
        Hello, world!
        =#
        a"""
        test_format(str, str)
    end

    @testset "format toggle" begin
        str = "#! format: off\n module Foo a \n end"
        test_format(str, str)

        str = "#! format: off\n#! format: on"
        test_format(str, str)

        str = """
        begin
            #! format: off
            don't
                  format
                         this
            #! format: on
        end"""
        test_format(str, str)

        str = """
        begin
            #! format: off
            # don't
            #     format
            #            this
            #! format: on
        end"""
        test_format(str, str)

        str = """
        # this should be formatted
        a = f(aaa, bbb, ccc)

        #! format: off
        # anything past this point should not be formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        d = @foo 10 20
        #! format: onono

        e = "what the foocho"

        # comment"""
        str_ = """
        # this should be formatted
        a = f(aaa,
            bbb,ccc)

        #! format: off
        # anything past this point should not be formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        d = @foo 10 20
        #! format: onono

        e = "what the foocho"

        # comment"""
        test_format(str_, str)

        str = """
        # this should be formatted
        a = f(aaa, bbb, ccc)

        #! format: off
        # this section is not formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        d = @foo 10 20
        # turning formatting back on
        #! format: on
        # back in business !!!

        e = "what the foocho"
        a = f(aaa, bbb, ccc)

        #! format: off
        b = 10*20
        #! format: on
        b = 10 * 20

        # comment"""

        str_ = """
        # this should be formatted
        a = f(aaa, bbb, ccc)

        #! format: off
        # this section is not formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        d = @foo 10 20
        # turning formatting back on
        #! format: on
        # back in business !!!

        e = "what the foocho"
        a = f(aaa,
            bbb,      ccc)

        #! format: off
        b = 10*20
        #! format: on
        b = 10 *20

        # comment"""
        test_format(str_, str)

        str = """
        # this should be formatted
        a = f(aaa, bbb, ccc)

        #! format: off
        # this section is not formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        #=
        α
        =#
        x =      1

        d = @foo 10 20"""
        test_format(str, str)
    end

    @testset "dot op" begin
        test_format("10 .^ a", "10 .^ a")
        test_format("10.0 .^ a", "10.0 .^ a")
        test_format("a.^b", "a .^ b")
        test_format("a.^10.", "a .^ 10.0")
        test_format("a.//10", "a .// 10")

        test_format("a .^ b", "a .^ b")
        test_format("a .^ 10.", "a .^ 10.0")
        test_format("a .// 10", "a .// 10")
    end

    @testset "toplevel" begin
        str = """

        hello = "string";

        a = 10;


        c = 50;

        #comment"""
        str_ = """

        hello = "string";

        a = 10        ;


        c = 50;

        #comment"""
        test_format(str_, str)
        t = run_pretty(str, 80)
        @test length(t) == 17
    end

    @testset "for = vs in normalization" begin
        str = """
        for i = 1:n
            println(i)
        end"""
        test_format(str, str)

        str = """
        for i in itr
            println(i)
        end"""
        test_format(str, str)

        str = """
        for i = 1:n
            println(i)
        end"""
        str_ = """
        for i in 1:n
            println(i)
        end"""
        test_format(str_, str)

        str = """
        for i in itr
            println(i)
        end"""
        str_ = """
        for i = itr
            println(i)
        end"""
        test_format(str_, str)

        str_ = """
        for i = I1, j in I2
            println(i, j)
        end"""
        str = """
        for i in I1, j in I2
            println(i, j)
        end"""
        test_format(str_, str)

        str_ = """
        for i = 1:30, j in 100:-2:1
            println(i, j)
        end"""
        str = """
        for i = 1:30, j = 100:-2:1
            println(i, j)
        end"""
        test_format(str_, str)

        str_ = "[(i,j) for i=I1,j=I2]"
        str = "[(i, j) for i in I1, j in I2]"
        test_format(str_, str)

        str_ = "((i,j) for i=I1,j=I2)"
        str = "((i, j) for i in I1, j in I2)"
        test_format(str_, str)

        str_ = "[(i,j) for i in 1:2:10,j  in 100:-1:10]"
        str = "[(i, j) for i = 1:2:10, j = 100:-1:10]"
        test_format(str_, str)

        str_ = "((i,j) for i in 1:2:10,j  in 100:-1:10)"
        str = "((i, j) for i = 1:2:10, j = 100:-1:10)"
        test_format(str_, str)
    end

    @testset "tuples" begin
        test_format("(a,)", "(a,)")
        test_format("a,b", "a, b")
        test_format("a ,b", "a, b")
        test_format("(a,b)", "(a, b)")
        test_format("(a ,b)", "(a, b)")
        test_format("( a, b)", "(a, b)")
        test_format("(a, b )", "(a, b)")
        test_format("(a, b ,)", "(a, b)")
        test_format("(a,    b ,\nc)", "(a, b, c)")
    end

    @testset "curly" begin
        test_format("X{a,b}", "X{a,b}")
        test_format("X{ a,b}", "X{a,b}")
        test_format("X{a ,b}", "X{a,b}")
        test_format("X{a, b}", "X{a,b}")
        test_format("X{a,b }", "X{a,b}")
        test_format("X{a,b }", "X{a,b}")

        str = """
        mutable struct Foo{A<:Bar,Union{B<:Fizz,C<:Buzz},<:Any}
            a::A
        end"""
        test_format(str, str)
        t = run_pretty(str, 80)
        @test length(t) == 55

        str = """
        struct Foo{A<:Bar,Union{B<:Fizz,C<:Buzz},<:Any}
            a::A
        end"""
        test_format(str, str)
        t = run_pretty(str, 80)
        @test length(t) == 47
    end

    @testset "where op" begin
        str = "Atomic{T}(value) where {T<:AtomicTypes} = new(value)"
        str_ = "Atomic{T}(value) where T <: AtomicTypes = new(value)"
        test_format(str, str)
        test_format(str_, str)

        str = "Vector{Vector{T} where T}"
        test_format(str, str)

        str_ = "Vector{Vector{T}} where T"
        str = "Vector{Vector{T}} where {T}"
        test_format(str_, str)
        test_format(str, str)
    end

    @testset "unary ops" begin
        test_format("! x", "! x")
        test_format("x ...", "x ...")
        test_format("!x", "!x")
        test_format("x...", "x...")

        # Issue 110
        str = raw"""
        if x
            if y
                :(
                    $lhs = fffffffffffffffffffffff(
                        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,
                        yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy,
                    )
                )
            end
        end"""
        test_format(str, str)

        str_ = "foo(args...)"
        str = """
        foo(
            args...,
        )"""
        test_format(str_, str; margin = 1)
        test_format(str, str; margin = 1)
    end

    @testset ": op" begin
        test_format("a:b:c", "a:b:c")
        test_format("a :b:c", "a:b:c")
        test_format("a: b:c", "a:b:c")
        test_format("a:b :c", "a:b:c")
        test_format("a:b: c", "a:b:c")
        test_format("a:b:c ", "a:b:c")
    end

    @testset "binary ops" begin

        @testset "whitespace addition" begin
            # For these 'operators' whitespace should only be added if there is already some
            # whitespace around the operator. (Note that the word 'operator' is used here
            # lightly, because many of these are parsed as infix _function calls_ rather
            # than infix _operators_ per se -- IMO we need clearer nomenclature.) There are
            # probably more that we need to test...
            for op in ("+", "*", "/", "-", "^", "%", "<", ">", "<=", ">=", "=>", "->", "-->", "<--", "~", "<:", ">:", "=", "==", "+=", "-=", "&&", "||")
                # see typedef section below also for <: and >:
                for (a, b) in (("a", "b"), ("[a", "b]"), ("(a", "b)"))
                    test_format("$a$(op)$b", "$a$(op)$b")
                    test_format("$a$(op) $b", "$a $(op) $b")
                    test_format("$a $(op) $b", "$a $(op) $b")
                    test_format("$a  $(op)  $b", "$a $(op) $b")

                    # Some of these are unary operators, so [a <op>b] means a 1x2 matrix
                    # with `a` and `<op>b` as elements, rather than a length-1 vector with
                    # `a<op>b` as its element. We skip those tests.
                    if !(op in ("+", "-", "~") && a == "[a")
                        test_format("$a $(op)$b", "$a $(op) $b")
                    end
                end
            end
            # For these ops there should never be whitespace
            for op in (":", "::")
                for (a, b) in (("a", "b"), ("[a", "b]"), ("(a", "b)"))
                    target = "$a$(op)$b"
                    test_format("$a$(op)$b", target)
                    test_format("$a$(op) $b", target)
                    test_format("$a $(op) $b", target)
                    test_format("$a  $(op)  $b", target)

                    # Just like above, `[a :b]` means a 1x2 matrix wtih with `a` and `:b`
                    # (i.e. a symbol) as elements, rather than a length-1 vector with `a:b`
                    # as its element. We skip those tests.
                    if !(op == ":" && a == "[a")
                        test_format("$a $(op)$b", target)
                    end

                end
            end
            # Supertypes / subtypes have special behaviour within typedefs
            for op in ("<:", ">:")
                target = "function f() where {a$(op)b} end"
                test_format("function f() where {a$(op)b} end", target)
                test_format("function f() where {a $(op)b} end", target)
                test_format("function f() where {a$(op) b} end", target)
                test_format("function f() where {a $(op) b} end", target)
                test_format("function f() where {a  $(op)  b} end", target)
            end
        end

        test_format("a+b*c", "a+b*c")
        test_format("a +b *c", "a + b * c")
        test_format("a + b      *c", "a + b * c")
        test_format("a +b*c", "a + b*c")
        test_format("a + b*c", "a + b*c")
        test_format("a+b *c", "a+b * c")
        test_format("a+b* c", "a+b * c")
        test_format("a+b*c ", "a+b*c")
        test_format("a:b", "a:b")
        test_format("a : b", "a:b")
        test_format("a: b", "a:b")
        test_format("a :b", "a:b")
        test_format("a +1 :b -1", "(a+1):(b-1)")
        test_format("a.b:c.d", "a.b:c.d") # shouldn't add parens

        test_format("a::b:: c", "a::b::c")
        test_format("a :: b::c", "a::b::c")
        test_format("a      :: b   :: c", "a::b::c")
        # issue 74
        test_format("0:1/3:2", "0:(1/3):2")
        test_format("2a", "2a")
        # issue 251
        test_format("2(a   + 1)", "2(a + 1)")
        test_format("2(a+1)", "2(a+1)")
        test_format("1 / 2a^2", "1 / 2a^2")

        str_ = "a[1:2 * num_source * num_dump-1]"
        str = "a[1:(2*num_source*num_dump-1)]"
        test_format(str_, str; indent=4, margin=1)

        str_ = "a[2 * num_source * num_dump-1:1]"
        str = "a[(2*num_source*num_dump-1):1]"
        test_format(str_, str; indent=4, margin=1)

        str = "!(typ <: ArithmeticTypes)"
        test_format(str, str)

        text = "a + b"
        d = JuliaFormatter.Document(text)
        s = JuliaFormatter.State(d, Options())
        g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; version=JuliaFormatter.SUPPORTED_SYNTAX_VERSION)
        op = JuliaSyntax.children(only(JuliaSyntax.children(g)))[3]
        @test JuliaFormatter.source_op_kind_from_offset(s, op, UInt32(3)) ===
              JuliaSyntax.Kind("+")

        test_format("1 // 2 + 3^4", "1 // 2 + 3^4")
        test_format("1 // 2 + 3 ^ 4", "1 // 2 + 3 ^ 4")

        # Function def

        str_ = """foo() = if cond a else b end"""
        str = """
        foo() =
            if cond
                a
            else
                b
            end"""
        test_format(str_, str)

        str_ = """
        foo() = begin
            body
        end"""
        str = """
        foo() =
            begin
                body
            end"""
        test_format(str, str_)
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        foo() = quote
            body
        end"""
        str = """
        foo() =
            quote
                body
            end"""
        test_format(str, str_)
        test_format(str_, str; indent=4, margin=1)

        str = """foo() = :(Union{})"""
        test_format(str, str)

        str_ = """foo() = for i=1:10 body end"""
        str = """
        foo() =
            for i = 1:10
                body
            end"""
        test_format(str_, str)

        str_ = """foo() = for outer i=1:10 body end"""
        str = """
        foo() =
            for outer i = 1:10
                body
            end"""
        test_format(str_, str)

        str_ = """foo() = while cond body end"""
        str = """
        foo() =
            while cond
                body
            end"""
        test_format(str_, str)

        str_ = """foo() = try body1 catch e body2 finally body3 end"""
        str = """
        foo() =
            try
                body1
            catch e
                body2
            finally
                body3
            end"""
        test_format(str_, str)

        # Assignment op

        str_ = """foo = if cond a else b end"""
        str = """
        foo =
          if cond
            a
          else
            b
          end"""
        test_format(str_, str; indent=2, margin=1)

        str_ = """foo = begin body end"""
        str = """
        foo = begin
          body
        end"""
        test_format(str_, str; indent=2, margin=11)
        str = """
        foo =
          begin
            body
          end"""
        test_format(str_, str; indent=2, margin=10)

        str_ = """foo = quote body end"""
        str = """
        foo = quote
          body
        end"""
        test_format(str_, str; indent=2, margin=11)
        str = """
        foo =
          quote
            body
          end"""
        test_format(str_, str; indent=2, margin=10)

        str_ = """foo = for i=1:10 body end"""
        str = """
        foo = for i = 1:10
          body
        end"""
        test_format(str_, str; indent=2, margin=18)
        str = """
        foo =
          for i = 1:10
            body
          end"""
        test_format(str_, str; indent=2, margin=17)

        str_ = """foo = while cond body end"""
        str = """
        foo =
          while cond
            body
          end"""
        test_format(str_, str; indent=2, margin=1)

        str_ = """foo = try body1 catch e body2 finally body3 end"""
        str = """
        foo =
          try
            body1
          catch e
            body2
          finally
            body3
          end"""
        test_format(str_, str; indent=2, margin=1)

        str_ = """
        foo = let
          body
        end"""
        test_format(str_, str_; indent=2, margin=9)
        str = """
        foo =
          let
            body
          end"""
        test_format(str_, str; indent=2, margin=8)
        str = """
        foo =
          let
            body
          end"""
        test_format(str_, str; indent=2, margin=1)

        str_ = """a, b = cond ? e1 : e2"""

        str = """
        a, b =
            cond ? e1 : e2"""
        test_format(str_, str; indent=4, margin=length(str_) - 1)
        test_format(str_, str; indent=4, margin=18)

        str = """
        a, b =
            cond ? e1 :
            e2"""
        test_format(str_, str; indent=4, margin=17)
        test_format(str_, str; indent=4, margin=15)

        str = """
        a, b =
            cond ?
            e1 : e2"""
        test_format(str_, str; indent=4, margin=14)
        test_format(str_, str; indent=4, margin=11)

        str = """
        a, b =
            cond ?
            e1 :
            e2"""
        test_format(str_, str; indent=4, margin=10)

        str = """
        begin
            variable_name =
                argument1 + argument2
        end"""
        test_format(str, str; indent=4, margin=40)

        str = """
        begin
            variable_name =
                argument1 +
                argument2
        end"""
        test_format(str, str; indent=4, margin=28)

        str = """
        begin
            variable_name =
                conditional ? expression1 : expression2
        end"""
        test_format(str, str; indent=4, margin=58)

        str = """
        begin
            variable_name =
                conditional ? expression1 :
                expression2
        end"""
        test_format(str, str; indent=4, margin=46)

        str = """
        begin
            variable_name =
                conditional ?
                expression1 : expression2
        end"""
        test_format(str, str; indent=4, margin=34)
        test_format(str, str; indent=4, margin=33)

        str = """
        begin
            variable_name =
                conditional ?
                expression1 :
                expression2
        end"""
        test_format(str, str; indent=4, margin=32)

        str = "shmem[pout*rows+row] += shmem[pin*rows+row] + shmem[pin*rows+row-offset]"

        str_ = """
        shmem[pout*rows+row] +=
               shmem[pin*rows+row] + shmem[pin*rows+row-offset]"""
        test_format(str, str_; indent=7, margin=71)
        str_ = """
        shmem[pout*rows+row] +=
               shmem[pin*rows+row] +
               shmem[pin*rows+row-offset]"""
        test_format(str, str_; indent=7, margin=54)

        str = """
        begin
           var = func(arg1, arg2, arg3) * num
        end"""
        test_format(str, str; indent=3, margin=37)

        str_ = """
        begin
           var =
              func(arg1, arg2, arg3) * num
        end"""
        test_format(str, str_; indent=3, margin=36)
        test_format(str, str_; indent=3, margin=34)

        str_ = """
        begin
           var =
              func(arg1, arg2, arg3) *
              num
        end"""
        test_format(str, str_; indent=3, margin=33)
        test_format(str, str_; indent=3, margin=30)

        str_ = """
        begin
           var =
              func(
                 arg1,
                 arg2,
                 arg3,
              ) * num
        end"""
        test_format(str, str_; indent=3, margin=29)

        str_ = """
        begin
           var =
              func(
                 arg1,
                 arg2,
                 arg3,
              ) *
              num
        end"""
        test_format(str, str_; indent=3, margin=1)

        str = """
        begin
            foo() =
                (one, x -> (true, false))
        end"""
        test_format(str, str; indent=4, margin=36)
        test_format(str, str; indent=4, margin=33)

        str = """
        begin
            foo() = (
                one,
                x -> (true, false),
            )
        end"""
        test_format(str, str; indent=4, margin=32)
        test_format(str, str; indent=4, margin=27)
        str = """
        begin
            foo() = (
                one,
                x -> (
                    true,
                    false,
                ),
            )
        end"""
        test_format(str, str; indent=4, margin=26)

        str = """
        ignored_f(f) = f in (
            GlobalRef(Base, :not_int),
            GlobalRef(Core.Intrinsics, :not_int),
            GlobalRef(Core, :(===)),
            GlobalRef(Core, :apply_type),
            GlobalRef(Core, :typeof),
            GlobalRef(Core, :throw),
            GlobalRef(Base, :kwerr),
            GlobalRef(Core, :kwfunc),
            GlobalRef(Core, :isdefined),
        )"""
        test_format(str, str)

        str = """
        ignored_f(f) = f in foo([{
            GlobalRef(Base, :not_int),
            GlobalRef(Core.Intrinsics, :not_int),
            GlobalRef(Core, :(===)),
            GlobalRef(Core, :apply_type),
            GlobalRef(Core, :typeof),
            GlobalRef(Core, :throw),
            GlobalRef(Base, :kwerr),
            GlobalRef(Core, :kwfunc),
            GlobalRef(Core, :isdefined),
        }])"""
        test_format(str, str)

        str = """
        ignored_f(f) = f in foo(((
            GlobalRef(Base, :not_int),
            GlobalRef(Core.Intrinsics, :not_int),
            GlobalRef(Core, :(===)),
            GlobalRef(Core, :apply_type),
            GlobalRef(Core, :typeof),
            GlobalRef(Core, :throw),
            GlobalRef(Base, :kwerr),
            GlobalRef(Core, :kwfunc),
            GlobalRef(Core, :isdefined),
        )))"""
        test_format(str, str)

        str = "var = \"a_long_function_stringggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg\""
        test_format(str, str; indent=4, margin=1)
    end

    @testset "op chain" begin
        test_format("a+b+c+d", "a+b+c+d")
        test_format("a + b + c +d", "a + b + c + d")
    end

    @testset "comparison chain" begin
        test_format("a<b==c≥d", "a<b==c≥d")
        test_format("a<b == c≥d", "a < b == c ≥ d")
    end

    @testset "single line block" begin
        test_format("(a;b;c)", "(a; b; c)")
    end

    @testset "func call" begin
        test_format("func(a, b, c)", "func(a, b, c)")
        test_format("func(a,b,c)", "func(a, b, c)")
        test_format("func(a,b,c,)", "func(a, b, c)")
        test_format("func(a,b,c, )", "func(a, b, c)")
        test_format("func( a,b,c    )", "func(a, b, c)")
        test_format("func(a, b, c) ", "func(a, b, c)")
        test_format("func(a, b; c)", "func(a, b; c)")
        test_format("func(  a, b; c)", "func(a, b; c)")
        test_format("func(a  ,b; c)", "func(a, b; c)")
        test_format("func(a=1,b; c=1)", "func(a = 1, b; c = 1)")

        str = """
        func(;
          c = 1,
        )"""
        test_format("func(; c = 1)", str; indent=2, margin=1)

        test_format("func(; c = 1,)", "func(; c = 1)")
        test_format("func(a;)", "func(a;)")

        str = """
        func(;
            a,
            b,
        )"""
        test_format(str, str; indent=4, margin=1)

        str = """
        func(
            x;
            a,
            b,
        )"""
        test_format(str, str; indent=4, margin=1)
    end

    @testset "macro call" begin
        str = """
        @f(
            a,
            b;
            x
        )"""
        str_ = "@f(a, b; x)"
        test_format(str_, str_)
        test_format(str_, str; indent=4, margin=1)

        str = """
        @f(
            a;
            x
        )"""
        str_ = "@f(a; x)"
        test_format(str_, str_)
        test_format(str_, str; indent=4, margin=1)

        str = """
        @f(;
          x
        )"""
        str_ = "@f(; x)"
        test_format(str_, str_)
        test_format(str_, str; indent=2, margin=1)

        str = """
        @f(;
            a,
            b
        )"""
        test_format(str, str; indent=4, margin=1)

        str = """
        @f(
            x;
            a,
            b
        )"""
        test_format(str, str; indent=4, margin=1)

        str = """@warn("Text")"""
        test_format(str, str)

        str_ = "@Module.macro"
        str = "Module.@macro"
        test_format(str_, str)
        test_format(str, str)

        str_ = "\$Module.@macro"
        str = "\$Module.@macro"
        test_format(str_, str)
        test_format(str, str)

        # @doc here should not be parsed as a macro string
        str = raw"push!(docs, :(@doc($meta, $(each.args[end]), $define)))"
        test_format(str, str)
    end

    @testset "macro block" begin
        str = raw"""
        @spawn begin
            acc = acc′′
            for _ in _
                a
                b
                ccc = dddd(ee, fff, gggggggggggg)
            end
            return
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 41

        str_ = "__module__ == Main || @warn \"Replacing docs for `\$b :: \$sig` in module `\$(__module__)`\""
        str = """
        __module__ == Main ||
            @warn \"Replacing docs for `\$b :: \$sig` in module `\$(__module__)`\""""
        test_format(str_, str; indent=4, margin=length(str_) - 1)
    end

    @testset "begin" begin
        str = """
        begin
            arg
        end"""
        test_format("""
                    begin
                    arg
                    end""", str)
        test_format("""
                    begin
                        arg
                    end""", str)
        test_format("""
                    begin
                        arg
                    end""", str)
        test_format("""
                    begin
                            arg
                    end""", str)
        str = """
        begin
            begin
                arg
            end
        end"""
        test_format("""
                    begin
                    begin
                    arg
                    end
                    end""", str)
        test_format("""
                    begin
                                begin
                    arg
                    end
                    end""", str)
        test_format("""
                    begin
                                begin
                    arg
                            end
                    end""", str)

        str = """
        begin
            s = foo(aaa, bbbb, cccc)
            s = foo(
                aaaa,
                bbbb,
                cccc,
            )
        end"""
        test_format(str, str; indent=4, margin=28)
    end

    @testset "quote" begin
        str = """
        quote
            arg
        end"""
        test_format("""
        quote
            arg
        end""", str)
        test_format("""
        quote
        arg
        end""", str)
        test_format("""
        quote
                arg
            end""", str)

        str = """:(a = 10; b = 20; c = a * b)"""
        test_format(":(a = 10; b = 20; c = a * b)", str)

        str = """
        :(endidx = ndigits;
        while endidx > 1 && digits[endidx] == UInt8('0')
            endidx -= 1
        end;
        if endidx > 1
            print(out, '.')
            unsafe_write(out, pointer(digits) + 1, endidx - 1)
        end)"""

        str_ = """
    :(endidx = ndigits;
                while endidx > 1 && digits[endidx] == UInt8('0')
                    endidx -= 1
                end;
                if endidx > 1
                    print(out, '.')
                    unsafe_write(out, pointer(digits) + 1, endidx - 1)
                end)"""
        test_format(str_, str)
        test_format(str, str)

        str = """
        quote
            s = foo(aaa, bbbb, cccc)
            s = foo(
                aaaa,
                bbbb,
                cccc,
            )
        end"""
        test_format(str, str; indent=4, margin=28)
    end

    @testset "do" begin
        str = """
        map(args) do x
            y = 20
            return x * y
        end"""

        test_format("""
        map(args) do x
          y = 20
                            return x * y
            end""", str)

        str = """
        map(1:10, 11:20) do x, y
            x + y
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 24

        str = """
        map(1:10, 11:20) do x, y
            z = reallylongvariablename
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 30

        # issue 58

        str_ = """
        model = SDDP.LinearPolicyGraph(stages = 2, lower_bound = 1, direct_mode = false) do (subproblem1, subproblem2, subproblem3, subproblem4, subproblem5, subproblem6, subproblem7, subproblem8)
            body
        end"""
        str = """
        model = SDDP.LinearPolicyGraph(
            stages = 2,
            lower_bound = 1,
            direct_mode = false,
        ) do (
            subproblem1,
            subproblem2,
            subproblem3,
            subproblem4,
            subproblem5,
            subproblem6,
            subproblem7,
            subproblem8,
        )
            body
        end"""
        test_format(str_, str)

        str_ = """
        model = SDDP.LinearPolicyGraph(stages = 2, lower_bound = 1, direct_mode = false) do subproblem1, subproblem2
            body
        end"""
        str = """
        model = SDDP.LinearPolicyGraph(
            stages = 2,
            lower_bound = 1,
            direct_mode = false,
        ) do subproblem1, subproblem2
            body
        end"""
        test_format(str_, str)
    end

    @testset "for" begin
        str = """
        for iter in I
            arg
        end"""
        test_format("""
        for iter in I
            arg
        end""", str)
        test_format("""
        for iter in I
        arg
        end""", str)
        test_format("""
        for iter in I
          arg
        end""", str)

        str = """
        for iter in I, iter2 in I2
            arg
        end"""
        test_format("""
        for iter = I, iter2= I2
            arg
        end""", str)
        test_format("""
        for iter= I, iter2=I2
        arg
        end""", str)
        test_format("""
        for iter    = I, iter2 = I2
                arg
            end""", str)

        str = """
        a = 10000
        for i = 1:10
            body
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 12

        str = """
        a = 1
        for i in 1:10
            bodybodybodybody
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 20
    end

    @testset "while" begin
        str = """
        while cond
            arg
        end"""
        test_format("""
        while cond
            arg
        end""", str)
        test_format("""
        while cond
        arg
        end""", str)
        test_format("""
        while cond
                arg
            end""", str)

        # This will be a FileH header
        # with no blocks
        str = """
        a = 1
        while a < 100
            a += 1
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 13

        str = """
        a = 1
        while a < 100
            a += 1
            thisisalongnameforabody
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 27

        @testset "block conditions" begin
            s1 = """while (a; b)
                c
            end"""
            test_format(s1, s1)
            s2 = """while begin
                a
                b
            end
                c
            end"""
            test_format(s2, s2)
            s3_ = """while (prettylong; prettylongtoo)
                c
            end"""
            s3 = """while (
                prettylong;
                prettylongtoo
            )
                c
            end"""
            test_format(s3_, s3; indent=4, margin=20)
        end
    end

    @testset "let" begin
        str = """
        let x=X
            arg
        end"""
        test_format("""
        let x=X
            arg
        end""", str)
        test_format("""
        let x=X
        arg
        end""", str)
        test_format("""
        let x=X
            arg
        end""", str)

        str = """
        let x = X, y = Y
            arg
        end"""
        test_format("""
        let x = X, y = Y
            arg
        end""", str)
        test_format("""
        let x = X, y = Y
        arg
        end""", str)

        str = """
        y, back = let
            body
        end"""
        test_format("""
        y,back = let
          body
        end""", str)

        str = """
        let x = a,
            # comment
            b,
            c

            body
        end"""
        test_format("""
        let x = a,
            # comment
               b,
              c
           body
           end""", str)

        str = """
        let x = X, y = Y
            body
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 16

        str = """
        let x = X, y = Y
        letthebodieshitthefloor
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 27
    end

    @testset "try" begin
        str = """
        try
            arg
        catch
            arg
        end"""
        test_format("""
        try
            arg
        catch
            arg
        end""", str)

        test_format("""
        try
        arg
        catch
        arg
        end""", str)

        test_format("""
        try
                arg
            catch
                arg
            end""", str)

        str = """
        try
            arg
        catch
            arg
        end"""
        test_format("""
        try
            arg
        catch
            arg
        end""", str)

        test_format("""
        try
        arg
        catch
        arg
        end""", str)

        test_format("""
        try
                arg
            catch
                arg
            end""", str)

        str = """
        try
            arg
        catch err
            arg
        end"""

        test_format("""
        try
            arg
        catch err
            arg
        end""", str)

        test_format("""
        try
        arg
        catch err
        arg
        end""", str)

        test_format("""
        try
                arg
            catch err
                arg
            end""", str)

        str = """
        try
            a111111
            a2
        catch error123
            b1
            b2
        finally
            c1
            c2
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """
        try
            a111111
            a2
        catch erro
            b1
            b2
        finally
            c1
            c2
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 11
    end

    @testset "if" begin
        str = """
        if cond1
            e1
            e2
        elseif cond2
            e3
            e4
        elseif cond33
            e5
            e6
        else
            e7
            e88888
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 13

        str = """
        if cond1
            e1
            e2
        elseif cond2
            e3
            e4
        elseif cond33
            e5
            e6
        else
            e7
            e888888888
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 14

        @testset "block conditions" begin
            # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1025
            for block in (
                "(a; b)",
                "begin\n    a\n    b\nend\n",
            )
                str = """
                if $block
                    foo
                end
                """
                test_format(str, str)

                str = """
                if x
                    foo
                elseif $block
                    bar
                end
                """
                test_format(str, str)

                str = """
                if $block
                    foo
                elseif $block
                    bar
                end
                """
                test_format(str, str)

                str = """
                if $block
                    foo
                else
                    bar
                end
                """
                test_format(str, str)
            end

            # Nesting
            str_ = """if (veryverylong; veryverylongtoo)
                f
            end"""
            str = """if (
                veryverylong;
                veryverylongtoo
            )
                f
            end"""
            test_format(str_, str; indent=4, margin=20)
        end

    end

    @testset "strings" begin
        str = """
        \"""
        Interpolate using `\\\$`
        \"""
        a"""
        test_format(str, str)

        str = """error("foo\\n\\nbar")"""
        test_format(str, str)

        str = """
        \"""
        \\\\
        \"""
        x"""
        test_format(str, str)

        str = """
        begin
            s = \"\"\"This is a multiline string.
                    This is another line.
                          Look another 1 that is indented a bit.

                          cool!\"\"\"
        end"""
        str_ = """
        begin
        s = \"\"\"This is a multiline string.
                This is another line.
                      Look another 1 that is indented a bit.

                      cool!\"\"\"
        end"""
        test_format(str_, str)

        @testset "multiline string starting on line with display width != bytes" begin
            # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/974
            #
            # Anonymous function form. Test both the case where the second line begins
            # after the starting quote of the first line, and the opposite.
            s1a = raw"""
            error_str = Δa -> "Change in activity must be within the valid range: \
                                Δa ∈ [1, 2], but Δa = $Δa"
            """
            s1b = raw"""
            error_str = Δa -> "Change in activity must be within the valid range: \
                  Δa ∈ [1, 2], but Δa = $Δa"
            """
            # Explicit function definition
            s2a = raw"""
            error_str(Δa) = "Change in activity must be within the valid range: \
                                Δa ∈ [1, 2], but Δa = $Δa"
            """
            s2b = raw"""
            error_str(Δa) = "Change in activity must be within the valid range: \
              Δa ∈ [1, 2], but Δa = $Δa"
            """
            # Using triple quoted strings
            s3a = raw"""
            error_str(Δa) = \"""Change in activity must be within the valid range: \
                                Δa ∈ [1, 2], but Δa = $Δa\"""
            """
            s3b = raw"""
            error_str(Δa) = \"""Change in activity must be within the valid range: \
              Δa ∈ [1, 2], but Δa = $Δa\"""
            """
            for s in (s1a, s1b, s2a, s2b, s3a, s3b)
                # Need to normalise line endings because \ at the end of a raw_str behaves
                # weirdly on Windows causing CI to fail.
                # https://github.com/JuliaLang/julia/issues/38908
                s = replace(s, "\r\n" => "\n")
                test_format(s, s)
            end
        end

        str_ = """
        begin
        begin
           throw(ErrorException(\"""An error occured formatting \$filename. :-(

                                Please file an issue at https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues
                                with a link to a gist containing the contents of the file. A gist
                                can be created at https://gist.github.com/.\"""))
           end
        end"""
        str = """
        begin
            begin
                throw(ErrorException(\"""An error occured formatting \$filename. :-(

                                     Please file an issue at https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues
                                     with a link to a gist containing the contents of the file. A gist
                                     can be created at https://gist.github.com/.\"""))
            end
        end"""
        test_format(str_, str; indent=4, margin=120)

        str = raw"""
        begin
            begin
                throw(
                    ErrorException(
                        \"""An error occured formatting $filename. :-(

                        Please file an issue at https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues
                        with a link to a gist containing the contents of the file. A gist
                        can be created at https://gist.github.com/.\""",
                    ),
                )
            end
        end"""
        test_format(str_, str; indent=4, margin=1)

        str = """
        foo() = llvmcall(\"""
                         llvm1
                         llvm2
                         \""")"""
        test_format(str, str)
        # nests and then unnests
        test_format(str, str; indent=2, margin=20)

        str_ = """
        foo() =
          llvmcall(\"""
                   llvm1
                   llvm2
                   \""")"""
        test_format(str, str_; indent=2, margin=19)

        # the length calculation is kind of wonky here
        # but it's still a worthwhile test
        str_ = """
        foo() =
            llvmcall(\"""
                     llvm1
                     llvm2
                     \""")"""
        test_format(str, str_; indent=4, margin=19)

        str_ = """
        foo() = llvmcall(
            \"""
            llvm1
            llvm2
            \""",
        )"""
        test_format(str, str_; indent=4, margin=18)

        str_ = """
        foo() =
          llvmcall(
            \"""
            llvm1
            llvm2
            \""",
          )"""
        test_format(str, str_; indent=2, margin=10)

        str = """
        str = \"""
        begin
            arg
        end\"""
        """
        test_format(str, str)

        str = """
        str = \"""
              begin
                  arg
              end\"""
        """
        test_format(str, str)

        str = raw"""@test :(x`s`flag) == :(@x_cmd "s" "flag")"""
        test_format(str, str)

        str = raw"""
        if free < min_space
            throw(ErrorException(\"""
            Free space: \$free Gb
            Please make sure to have at least \$min_space Gb of free disk space
            before downloading the $database_name database.
            \"""))
        end"""
        str_ = raw"""
        if free <
           min_space
            throw(
                ErrorException(
                    \"""
        Free space: \$free Gb
        Please make sure to have at least \$min_space Gb of free disk space
        before downloading the $database_name database.
        \""",
                ),
            )
        end"""
        test_format(str, str)
        test_format(str, str_; indent=4, margin=1)

        str_ = """foo(r"hello"x)"""
        str = """
        foo(
            r"hello"x,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """foo(r`hello`x)"""
        str = """
        foo(
            r`hello`x,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """foo(r\"""hello\"""x)"""
        str = """
        foo(
            r\"""hello\"""x,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """foo(r```hello```x)"""
        str = """foo(
            r```hello```x,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """foo(\"""hello\""")"""
        str = """foo(
            \"""hello\""",
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """foo(```hello```)"""
        str = """foo(
            ```hello```,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = raw"""
        occursin(r"^#!\s*format\s*:\s*off\s*$", t.val)
        """
        test_format(str_, str_)

        str = raw"""
        occursin(
            r"^#!\s*format\s*:\s*off\s*$",
            t.val,
        )
        """
        test_format(str_, str; indent=4, margin=1)
    end

    @testset "comments" begin
        str = """
        module Foo
        # comment 0
        # comment 1
        begin

            # comment 2
            # comment 3

            begin



                # comment 4
                # comment 5
                a = 10
                # comment 6
            end

        end

        end"""
        test_format(str, str)
        t = run_pretty(str, 80)
        @test length(t) == 14

        str_ = """
        module Foo
        # comment 0
        # comment 1
        begin

        # comment 2
        # comment 3

        begin



        # comment 4
        # comment 5
        a = 10
        # comment 6
        end

        end

        end"""
        str = """
        module Foo
        # comment 0
        # comment 1
        begin

            # comment 2
            # comment 3

            begin



                # comment 4
                # comment 5
                a = 10
                # comment 6
            end

        end

        end"""
        test_format(str_, str)

        str = "# comment 0\n\n\n\n\na = 1\n\n# comment 1\n\n\n\n\nb = 2\n\n\nc = 3\n\n# comment 2\n\n"
        test_format(str, str)

        str = """
        #=
        hello
        world
        =#
        const a = \"hi there\""""
        test_format(str, str)

        str = """
        if a
            # comment above var
            var = 10
            # comment below var
        else
            something_else()
        end"""
        test_format(str, str)

        str = """
        begin
            a = 10 # foo
            b = 20           # foo
        end    # trailing comment"""
        str_ = """
        begin
        a = 10 # foo
        b = 20           # foo
        end    # trailing comment"""
        test_format(str_, str)

        str = """
        function bar(x, y)
            # single comment ending in a subscriptₙ
            x - y
        end"""
        test_format("""
        function bar(x, y)
            # single comment ending in a subscriptₙ
            x- y
        end""", str)

        str_ = """
        var = foo(      # eat
            a, b, # comment 1
            c, # comment 2
            # in between comment
            d # comment 3
        )        # pancakes"""
        str = """
        var = foo(      # eat
            a,
            b, # comment 1
            c, # comment 2
            # in between comment
            d, # comment 3
        )        # pancakes"""
        test_format(str_, str)

        str_ = """
        var = foo(      # eat
            a, b, # comment 1
            c, # comment 2
            d # comment 3
        )        # pancakes"""
        str = """
        var = foo(      # eat
            a,
            b, # comment 1
            c, # comment 2
            d, # comment 3
        )        # pancakes"""
        test_format(str_, str)

        str = """
        A ? # foo
        # comment 1

        B :    # bar
        # comment 2
        C"""
        test_format(str, str)

        str = """
        A ? B :
        # comment

        C"""
        test_format(str, str)

        str_ = """
        foo = A ?
            # comment 1

            B : C"""

        str = """
        foo =
            A ?
            # comment 1

            B : C"""
        test_format(str_, str)

        str = """
        foo =
           A ?
           # comment 1

           B :
           C"""
        test_format(str_, str; indent=3, margin=1)

        str_ = """
        foo = A +
            # comment 1

            B + C"""

        str = """
        foo =
           A +
           # comment 1

           B +
           C"""
        test_format(str_, str; indent=3, margin=100)
        test_format(str_, str; indent=3, margin=1)

        str = """
        begin
            var =
                a +
                # comment
                b
        end
        """
        test_format(str, str)

        str = """
        begin
            var() =
                a +
                # comment
                b
        end
        """
        test_format(str, str)

        str_ = """
        begin
            var = a +  # inline
                  # comment

                  b
        end
        """
        str = """
        begin
            var =
                a +  # inline
                # comment

                b
        end
        """
        test_format(str_, str)

        str_ = """
        begin
            var = a +  # inline
                  b
        end
        """
        str = """
        begin
          var =
            a +  # inline
            b
        end
        """
        test_format(str_, str; indent=2, margin=92)

        str = """
        foo() = 10 where {
            # comment
            A,
            # comment
            B,
            # comment
        }"""
        test_format(str, str)

        str = """
        foo() = 10 where Foo{
            # comment
            A,
            # comment
            B,
            # comment
        }"""
        test_format(str, str)

        str = """
        foo() = Foo(
            # comment
            A,
            # comment
            B,
            # comment
        )"""
        test_format(str, str)

        str = """
        foo(
            # comment
            ;
            # comment
            a = b, # comment
            c = d,
            # comment
        )"""
        test_format(str, str)

        str = """
        foo(;
            a = b, # comment
            c = d,
            # comment
        )"""

        str_ = """
        foo(
            ;
            a = b, # comment
            c = d,
            # comment
        )"""
        test_format(str_, str)

        str = """
        foo(;;
            a = b, # comment
            c = d,
            # comment
        )"""

        str_ = """
        foo(
            ;
            ;a = b, # comment
            c = d,
            # comment
        )"""
        test_format(str_, str)

        str_ = """
        foo( ;
            ;a = b, # comment
            c = d,
            # comment
        )"""
        test_format(str_, str)

        # Issue #51
        # NOTE: `str_` has extra whitespace after
        # keywords on purpose
        str_ = "begin \n # comment\n end"
        str = """
        begin
          # comment
        end"""
        test_format(str_, str; indent=2, margin=92)

        str_ = "try \n # comment\n catch e\n # comment\nbody\n # comment\n finally \n # comment\n end"
        str = """
        try
              # comment
        catch e
              # comment
              body
              # comment
        finally
              # comment
        end"""
        test_format(str_, str; indent=6, margin=92)

        str_ = "if a \n # comment\n body \n# comment\n elseif b\n # comment\nbody\n #comment\n else\n # comment\n body \n #comment\n end"
        str = """
        if a
              # comment
              body
              # comment
        elseif b
              # comment
              body
              #comment
        else
              # comment
              body
              #comment
        end"""
        test_format(str_, str; indent=6, margin=92)

        str = """a = "hello ##" # # # α"""
        test_format(str, str)

        # issue #65
        str = "1 # α"
        test_format(str, str)

        str = "# α"
        test_format(str, str)

        str = """
        #=
        α
        =#
        x = 1
        """
        test_format(str, str)

        str_ = """
          \"\"\"
          - ΩCL
          - ΩVc
          -  ΩKa
          - ΩVp
          - ΩQ
          \"\"\"
          f
        """
        str = """
        \"\"\"
          - ΩCL
          - ΩVc
          - ΩKa
          - ΩVp
          - ΩQ
        \"\"\"
        f
        """
        test_format(str_, str; format_docstrings = true)

        str = """
        # comments
        # before
        # code

        #comment
        if a
            #comment
        elseif b
            #comment
        elseif c
            #comment
            if aa
                #comment
            elseif bb
                #comment
                #comment
            else
                #comment
            end
            #comment
        elseif cc
            #comment
        elseif dd
            #comment
            if aaa
                #comment
            elseif bbb
                #comment
            else
                #comment
            end
            #comment
        end
        #comment
        """
        test_format(str, str)

        str = """
        foo = [
            # comment
            1,
            2,
            3,
        ]"""
        test_format(str, str)

        # issue 152
        str = """
        try
            ;
        catch
            ;
        end   # comment"""
        str_ = """try; catch;  end   # comment"""
        test_format(str_, str)

        str = """
        try
            ;
        catch
            ;
        end   # comment
        a = 10"""
        str_ = """
        try; catch;  end   # comment
        a = 10"""
        test_format(str_, str)
    end

    @testset "pretty" begin
        str = """function foo end"""
        test_format("""
            function  foo
            end""", str)
        t = run_pretty(str, 80)
        @test length(t) == 16

        str = """function foo() end"""
        test_format("""
                     function  foo()
            end""", str)
        t = run_pretty(str, 80)
        @test length(t) == 18

        str = """function foo()
                     10;
                     20
                 end"""
        test_format("""function foo() 10;  20 end""", str)
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """abstract type AbstractFoo end"""
        test_format("""abstract type
                     AbstractFoo
                end""", str)

        str = "primitive type A <: B 32 end"
        test_format("""primitive type
                     A   <: B
                     32
                end""", str)

        str = """for i = 1:10
                     1;
                     2;
                     3
                 end"""
        test_format("""for i=1:10 1; 2; 3 end""", str)

        str = """while true
                     1;
                     2;
                     3
                 end"""
        test_format("""while true 1; 2; 3 end""", str)

        str = """try
                     a
                 catch e
                     b
                 end"""
        test_format("""try a catch e b end""", str)

        str = """try
                     a1;
                     a2
                 catch e
                     b1;
                     b2
                 finally
                     c1;
                     c2
                 end"""
        test_format("""try a1;a2 catch e b1;b2 finally c1;c2 end""", str)

        str = """map(a) do b, c
                     e
                 end"""
        test_format("""map(a) do b,c
                     e end""", str)

        str = """let a=b, c = d
                     e1;
                     e2;
                     e3
                 end"""
        test_format("""let a=b,c  =  d  \ne1; e2; e3 end""", str)

        str = """let a, b
                     e
                 end"""
        test_format("""let a,b
                     e end""", str)

        str = """return a, b, c"""
        test_format("""return a,b,
                     c""", str)

        str = """begin
                     a;
                     b;
                     c
                 end"""
        test_format("""begin a; b; c end""", str)

        str = """begin end"""
        test_format("""begin \n            end""", str)

        str = """quote
                     a;
                     b;
                     c
                 end"""
        test_format("""quote a; b; c end""", str)

        str = """quote end"""
        test_format("""quote \n end""", str)

        str = """if cond1
                     e1;
                     e2
                 end"""
        test_format("if cond1 e1;e2 end", str)

        str = """if cond1
                     e1;
                     e2
                 else
                     e3;
                     e4
                 end"""
        test_format("if cond1 e1;e2 else e3;e4 end", str)

        str = """begin
                     if cond1
                         e1;
                         e2
                     elseif cond2
                         e3;
                         e4
                     elseif cond3
                         e5;
                         e6
                     else
                         e7;
                         e8
                     end
                 end"""
        test_format(
            "begin if cond1 e1; e2 elseif cond2 e3; e4 elseif cond3 e5;e6 else e7;e8  end end",
            str)

        str = """if cond1
                     e1;
                     e2
                 elseif cond2
                     e3;
                     e4
                 end"""
        test_format("if cond1 e1;e2 elseif cond2 e3; e4 end", str)

        str = """
        [a b c]"""
        test_format("[a   b         c   ]", str)

        str = """
        [a; b; c;]"""
        test_format("[a;   b;         c;   ]", str)
        str = """
        [a; b; c]"""
        test_format("[a;   b;         c   ]", str)

        str = """
        T[a b c]"""
        test_format("T[a   b         c   ]", str)

        str = """T[a; b; c]"""
        test_format("T[a;   b;         c   ]", str)
        str = """T[a; b; c;]"""
        test_format("T[a;   b;         c;   ]", str)

        str = """
        T[
            a;
            b;
            c;
        ]"""
        test_format("T[a;   b;         c;   ]", str; indent=4, margin=1)

        str = """
        T[
            a;
            b;
            c
        ]"""
        test_format("T[a;   b;         c   ]", str; indent=4, margin=1)

        str = """
        T[a; b; c; e d f]"""
        test_format("T[a;   b;         c;   e  d    f   ]", str)

        str = """
        T[a; b; c; e d f;]"""
        test_format("T[a;   b;         c;   e  d    f;   ]", str)

        str = """
        T[
            a;
            b;
            c;
            e d f
        ]"""
        test_format("T[a;   b;         c;   e  d    f   ]", str; indent=4, margin=1)

        str = """
        T[
            a;
            b;
            c;
            e d f;
        ]"""
        test_format("T[a;   b;         c;   e  d    f;   ]", str; indent=4, margin=1)

        str = "T[a;]"
        test_format(str, str)

        str = "[a;]"
        test_format(str, str)

        str = """T[e for e in x]"""
        test_format("T[e  for e= x  ]", str)

        str = """T[e for e = 1:2:50]"""
        test_format("T[e  for e= 1:2:50  ]", str)

        str = """struct Foo end"""
        test_format("struct Foo\n      end", str)

        str = """
        struct Foo
            body::Any
        end"""
        test_format("struct Foo\n    body  end", str)

        str = """macro foo() end"""
        test_format("macro foo()\n      end", str)

        str = """macro foo end"""
        test_format("macro foo\n      end", str)

        str = """
        macro foo()
            body
        end"""
        test_format("macro foo()\n    body  end", str)

        str = """mutable struct Foo end"""
        test_format("mutable struct Foo\n      end", str)

        str = """
        mutable struct Foo
            body::Any
        end"""
        test_format("mutable struct Foo\n    body  end", str)

        str = """
        module A
        bodybody
        end"""
        test_format("module A\n    bodybody  end", str)
        t = run_pretty(str, 80)
        @test length(t) == 8

        str = """
        module Foo end"""
        test_format("module Foo\n    end", str)
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """
        baremodule A
        bodybody
        end"""
        test_format("baremodule A\n    bodybody  end", str)
        t = run_pretty(str, 80)
        @test length(t) == 12

        str = """
        baremodule Foo end"""
        test_format("baremodule Foo\n    end", str)
        t = run_pretty(str, 80)
        @test length(t) == 18

        str = """
        if cond1
        elseif cond2
        elseif cond3
        elseif cond4
        elseif cond5
        elseif cond6
        elseif cond7
        else
        end"""
        test_format(str, str)

        str = """
        try
        catch
        finally
        end"""
        test_format(str, str)

        str = """
        (args...; kwargs) -> begin
            body
        end"""
        test_format(str, str)

        test_format("ref[a: (b + c)]", "ref[a:(b+c)]")
        test_format("ref[a in b]", "ref[a in b]")
        test_format("ref[a:b.c]", "ref[a:b.c]") # shouldn't add parens
    end

    @testset "nesting" begin
        str = """
        function f(
            arg1::A,
            key1 = val1;
            key2 = val2,
        ) where {
            A,
            F{
                B,
                C,
            },
        }
            10;
            20
        end"""
        str_ = "function f(arg1::A,key1=val1;key2=val2) where {A,F{B,C}} 10; 20 end"
        test_format(str_, str; indent=4, margin=1)

        str = """
        function f(
            arg1::A,
            key1 = val1;
            key2 = val2,
        ) where {
            A,
            F{B,C},
        }
            10;
            20
        end"""
        test_format(str_, str; indent=4, margin=17)

        str = """
        function f(
            arg1::A,
            key1 = val1;
            key2 = val2,
        ) where {A,F{B,C}}
            10;
            20
        end"""
        test_format(str_, str; indent=4, margin=18)

        str = """
        a |
        b |
        c |
        d"""
        test_format("a | b | c | d", str; indent=4, margin=1)

        str = """
        a, b, c, d"""
        test_format("a, b, c, d", str; indent=4, margin=10)

        str = """
        a,
        b,
        c,
        d"""
        test_format("a, b, c, d", str; indent=4, margin=9)

        str = """(a, b, c, d)"""
        test_format("(a, b, c, d)", str; indent=4, margin=12)

        str = """
        (
            a,
            b,
            c,
            d,
        )"""
        test_format("(a, b, c, d)", str; indent=4, margin=11)

        str = """{a, b, c, d}"""
        test_format("{a, b, c, d}", str; indent=4, margin=12)

        str = """
        {
            a,
            b,
            c,
            d,
        }"""
        test_format("{a, b, c, d}", str; indent=4, margin=11)

        str = """[a, b, c, d]"""
        test_format("[a, b, c, d]", str; indent=4, margin=12)

        str = """
        [
            a,
            b,
            c,
            d,
        ]"""
        test_format("[a, b, c, d]", str; indent=4, margin=11)

        str = """
        cond ?
        e1 :
        e2"""
        test_format("cond ? e1 : e2", str; indent=4, margin=1)

        str = """
        cond ? e1 :
        e2"""
        test_format("cond ? e1 : e2", str; indent=4, margin=12)

        str = """
        cond1 ? e1 :
        cond2 ? e2 :
        cond3 ? e3 :
        e4"""
        test_format("cond1 ? e1 : cond2 ? e2 : cond3 ? e3 : e4", str; indent=4, margin=13)

        # I'm an importer/exporter
        str = """
        export a,
            b"""
        test_format("export a,b", str; indent=4, margin=1)

        str = """
        using a,
          b"""
        test_format("using a,b", str; indent=2, margin=1)

        str_ = "using M1.M2.M3: bar, baz"
        str = """
        using M1.M2.M3:
            bar, baz"""
        test_format(str, str_; indent=4, margin=24)
        test_format(str_, str; indent=4, margin=23)
        test_format(str_, str; indent=4, margin=12)

        str = """
        using M1.M2.M3:
            bar,
            baz"""
        test_format(str_, str; indent=4, margin=11)

        str_ = "import M1.M2.M3: bar, baz"
        str = """
        import M1.M2.M3:
            bar, baz"""
        test_format(str, str_; indent=4, margin=25)
        test_format(str_, str; indent=4, margin=24)
        test_format(str_, str; indent=4, margin=12)

        str = """
        import M1.M2.M3:
            bar,
            baz"""
        test_format(str_, str; indent=4, margin=11)

        str_ = """
        using A,

        B, C"""
        str = "using A, B, C"
        test_format(str_, str)

        str_ = """
        using A,
                  # comment
        B, C"""
        str = """
        using A,
          # comment
          B,
          C"""
        test_format(str_, str; indent=2, margin=80)

        str_ = """
        using A,  #inline
                  # comment
        B, C#inline"""
        str = """
        using A,  #inline
          # comment
          B,
          C#inline"""
        test_format(str_, str; indent=2, margin=80)

        str = """
        @somemacro function (fcall_ | fcall_)
            body_
        end"""
        test_format("@somemacro function (fcall_ | fcall_) body_ end", str; indent=4, margin=37)

        str = """
        @somemacro function (
            fcall_ | fcall_
        )
            body_
        end"""
        test_format("@somemacro function (fcall_ | fcall_) body_ end", str; indent=4, margin=36)
        test_format("@somemacro function (fcall_ | fcall_) body_ end", str; indent=4, margin=20)

        str = """
        @somemacro function (
            fcall_ |
            fcall_
        )
            body_
        end"""
        test_format("@somemacro function (fcall_ | fcall_) body_ end", str; indent=4, margin=19)

        str = "Val(x) = (@_pure_meta; Val{x}())"
        test_format("Val(x) = (@_pure_meta ; Val{x}())", str; indent=4, margin=80)

        # TODO: if this ends up being a issue fix it but it doesn't seem
        # like it actually occurs in the wild.
        str = "(a; b; c)"
        test_format("(a;b;c)", str; indent=4, margin=100)
        str = """
        (
            a;
            b;
            c
        )"""
        test_format("(a;b;c)", str; indent=4, margin=1)

        str = "(x for x = 1:10)"
        test_format("(x   for x  in  1 : 10)", str; indent=4, margin=100)

        str = """
        (
          x for
          x = 1:10
        )"""
        test_format("(x   for x  in  1 : 10)", str; indent=2, margin=10)

        str = """
        (
          x for
          x =
            1:10
        )"""
        test_format("(x   for x  in  1 : 10)", str; indent=2, margin=1)

        # indent for TupleN with no parens
        str = """
        function foo()
            arg1,
            arg2
        end"""
        test_format("function foo() arg1, arg2 end", str; indent=4, margin=1)

        str = """
        function foo()
            # comment
            arg
        end"""
        test_format(str, str; indent=4, margin=1)

        str = """
        A where {
            B,
        }"""
        str_ = "A where {B}"
        test_format(str_, str_)
        test_format(str_, str; indent=4, margin=1)

        str = """
        foo(
          arg1,
        )"""
        str_ = "foo(arg1)"
        test_format(str_, str_)
        test_format(str, str; indent=2, margin=1)

        str = """
        [
          arg1,
        ]"""
        str_ = "[arg1]"
        test_format(str_, str_)
        test_format(str, str; indent=2, margin=1)

        str = """
        {
          arg1,
        }"""
        str_ = "{arg1}"
        test_format(str_, str_)
        test_format(str, str; indent=2, margin=1)

        str = """
        (
          arg1
        )"""
        str_ = "(arg1)"
        test_format(str_, str_)
        test_format(str_, str; indent=2, margin=1)

        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/9#issuecomment-481607068
        str = """
        this_is_a_long_variable_name = Dict{Symbol,Any}(
            :numberofpointattributes => NAttributes,
            :numberofpointmtrs => NMTr,
            :numberofcorners => NSimplex,
            :firstnumber => Cint(1),
            :mesh_dim => Cint(3),
        )"""

        str_ = """this_is_a_long_variable_name = Dict{Symbol,Any}(:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        test_format(str_, str; indent=4, margin=80)

        str = """
        this_is_a_long_variable_name =
             Dict{Symbol,Any}(
                  :numberofpointattributes =>
                       NAttributes,
                  :numberofpointmtrs =>
                       NMTr,
                  :numberofcorners =>
                       NSimplex,
                  :firstnumber =>
                       Cint(1),
                  :mesh_dim =>
                       Cint(3),
             )"""
        test_format(str_, str; indent=5, margin=23)

        str = """
        this_is_a_long_variable_name =
             Dict{Symbol,Any}(
                  :numberofpointattributes =>
                       NAttributes,
                  :numberofpointmtrs =>
                       NMTr,
                  :numberofcorners =>
                       NSimplex,
                  :firstnumber =>
                       Cint(
                            1,
                       ),
                  :mesh_dim =>
                       Cint(
                            3,
                       ),
             )"""
        test_format(str_, str; indent=5, margin=22)

        str = """
        this_is_a_long_variable_name =
             Dict{
                  Symbol,
                  Any,
             }(
                  :numberofpointattributes =>
                       NAttributes,
                  :numberofpointmtrs =>
                       NMTr,
                  :numberofcorners =>
                       NSimplex,
                  :firstnumber =>
                       Cint(
                            1,
                       ),
                  :mesh_dim =>
                       Cint(
                            3,
                       ),
             )"""
        test_format(str_, str; indent=5, margin=1)

        str = """
        this_is_a_long_variable_name = (
            :numberofpointattributes => NAttributes,
            :numberofpointmtrs => NMTr,
            :numberofcorners => NSimplex,
            :firstnumber => Cint(1),
            :mesh_dim => Cint(3),
        )"""

        str_ = """this_is_a_long_variable_name = (:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        test_format(str_, str; indent=4, margin=80)

        str = """
        func(
            a,
            \"""this
            is another
            multi-line
            string.
            Longest line
            \""",
            foo(b, c),
        )"""

        str_ = """
        func(a, \"""this
                is another
                multi-line
                string.
                Longest line
                \""", foo(b, c))"""
        test_format(str_, str)
        str_ = """
        func(
            a,
            \"""this
            is another
            multi-line
            string.
            Longest line
            \""",
            foo(
                b,
                c,
            ),
        )"""
        test_format(str, str_; indent=4, margin=1)

        # Ref
        str = "a[1+2]"
        test_format("a[1 + 2]", str; indent=4, margin=1)

        str = "a[(1+2)]"
        test_format("a[(1 + 2)]", str; indent=4, margin=1)

        str_ = "(a + b + c + d)"
        test_format(str_, str_; indent=4, margin=length(str_))

        str = """
        (
          a +
          b +
          c +
          d
        )"""
        test_format(str_, str; indent=2, margin=length(str_) - 1)
        test_format(str_, str; indent=2, margin=1)

        str_ = "(a <= b <= c <= d)"
        test_format(str_, str_; indent=4, margin=length(str_))

        str = """
        (
           a <=
           b <=
           c <=
           d
        )"""
        test_format(str_, str; indent=3, margin=length(str_) - 1)
        test_format(str_, str; indent=3, margin=1)

        # Don't join the first argument in a comparison
        # or chainopcall node, even if possible.
        str_ = "const a = arg1 + arg2 + arg3"
        str = """
        const a =
            arg1 +
            arg2 +
            arg3"""
        test_format(str_, str; indent=4, margin=18)

        str_ = "const a = arg1 == arg2 == arg3"
        str = """
        const a =
            arg1 ==
            arg2 ==
            arg3"""
        test_format(str_, str; indent=4, margin=19)

        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/60
        str_ = """
        function write_subproblem_to_file(
                node::Node, filename::String;
                format::Symbol=:both, throw_error::Bool = false)
            body
        end"""
        str = """
        function write_subproblem_to_file(
            node::Node,
            filename::String;
            format::Symbol = :both,
            throw_error::Bool = false,
        )
            body
        end"""
        test_format(str_, str)

        # any pairing of argument, kawrg, or param should nest
        str = """
        f(
            arg;
            a = 1,
        )"""
        test_format("f(arg;a=1)", str; indent=4, margin=1)

        str = """
        f(
           arg,
           a = 1,
        )"""
        test_format("f(arg,a=1)", str; indent=3, margin=1)

        str = """
        f(
         a = 1;
         b = 2,
        )"""
        test_format("f(a=1; b=2)", str; indent=1, margin=1)

        str = """
        begin
            if foo
            elseif baz
            elseif a ||
                   b &&
                   c
            elseif bar
            else
            end
        end"""
        test_format(str, str; indent=4, margin=1)

        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/453
        str = """
        bar = Dict(
            :foo => \"""A triple quoted literal string
                    with some words in it.\""",
        )
        """
        test_format(str, str; indent=4, margin=20)
    end

    @testset "nesting line offset" begin
        str = "a - b + c * d"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 5
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "c ? e1 : e2"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 2
        _, s = run_nest(str, 8)
        @test s.line_offset == 2
        _, s = run_nest(str, 1)
        @test s.line_offset == 2

        str = "c1 ? e1 : c2 ? e2 : c3 ? e3 : c4 ? e4 : e5"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 32
        _, s = run_nest(str, 30)
        @test s.line_offset == 22
        _, s = run_nest(str, 20)
        @test s.line_offset == 12
        _, s = run_nest(str, 10)
        @test s.line_offset == 2
        _, s = run_nest(str, 1)
        @test s.line_offset == 2

        str = "f(a, b, c) where {A,B,C}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 15
        _, s = run_nest(str, 14)
        @test s.line_offset == 1
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where Union{A,B,C}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 20
        _, s = run_nest(str, 19)
        @test s.line_offset == 1
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where {A}"
        _, s = run_nest(str, 100)
        # adds surrounding {...} after `where`
        @test s.line_offset == length(str)
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where {A<:S}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 14
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where Union{A,B,Union{C,D,E}}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 31
        _, s = run_nest(str, 30)
        @test s.line_offset == 1
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where {A,{B, C, D},E}"
        _, s = run_nest(str, 100)
        # -2 whitespace in the brackets
        @test s.line_offset == length(str) - 2
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "(a, b, c, d)"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 1

        str = "a, b, c, d"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 1

        str = """
        splitvar(arg) =
            @match arg begin
                ::T_ => (nothing, T)
                name_::T_ => (name, T)
                x_ => (x, :Any)
            end"""
        _, s = run_nest(str, 96)
        @test s.line_offset == 3
        _, s = run_nest(str, 1)
        @test s.line_offset == 7

        str = "prettify(ex; lines = false) = ex |> (lines ? identity : striplines) |> flatten |> unresolve |> resyntax |> alias_gensyms"
        _, s = run_nest(str, 80)
        @test s.line_offset == 17

        str = "foo() = a + b"
        _, s = run_nest(str, length(str))
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 9
        _, s = run_nest(str, 1)
        @test s.line_offset == 5

        str_ = """
        @Expr(:scope_block, begin
                    body1
                    @Expr :break loop_cont
                    body2
                    @Expr :break loop_exit2
                    body3
                end)"""

        str = """
        @Expr(:scope_block, begin
            body1
            @Expr :break loop_cont
            body2
            @Expr :break loop_exit2
            body3
        end)"""
        test_format(str_, str; indent=4, margin=100)

        str = """
        @Expr(
            :scope_block,
            begin
                body1
                @Expr :break loop_cont
                body2
                @Expr :break loop_exit2
                body3
            end
        )"""
        test_format(str_, str; indent=4, margin=20)

        str = "export @esc, isexpr, isline, iscall, rmlines, unblock, block, inexpr, namify, isdef"
        _, s = run_nest(str, length(str))
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 74
        _, s = run_nest(str, 73)
        @test s.line_offset == 9

        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/9#issuecomment-481607068
        str = """this_is_a_long_variable_name = Dict{Symbol,Any}(:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        _, s = run_nest(str, 80)
        @test s.line_offset == 1

        str = """this_is_a_long_variable_name = (:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        _, s = run_nest(str, 80)
        @test s.line_offset == 1

        str = "import A: foo, bar, baz"
        _, s = run_nest(str, 22)
        @test s.line_offset == 17
        _, s = run_nest(str, 16)
        @test s.line_offset == 7
    end

    @testset "additional length" begin
        str_ = "f(a, @g(b, c), d)"
        str = """
        f(
            a,
            @g(b, c),
            d,
        )"""
        test_format(str_, str; indent=4, margin=13)
        test_format(str, str_; indent=4, margin=length(str))

        str_ = "f(a, @g(b, c), d)"
        str = """
        f(
            a,
            @g(
                b,
                c
            ),
            d,
        )"""
        test_format(str_, str; indent=4, margin=12)
        test_format(str, str_; indent=4, margin=length(str))

        str_ = "(a, (b, c), d)"
        str = """
        (
            a,
            (b, c),
            d,
        )"""
        test_format(str_, str; indent=4, margin=11)
        test_format(str, str_; indent=4, margin=length(str))

        str = """
        (
            a,
            (
                b,
                c,
            ),
            d,
        )"""
        test_format(str_, str; indent=4, margin=10)

        str_ = "(a, {b, c}, d)"
        str = """
        (
            a,
            {b, c},
            d,
        )"""
        test_format(str_, str; indent=4, margin=12)
        test_format(str_, str; indent=4, margin=11)

        str = """
        (
            a,
            {
                b,
                c,
            },
            d,
        )"""
        test_format(str_, str; indent=4, margin=10)
        test_format(str, str_; indent=4, margin=length(str))

        str_ = "(a, [b, c], d)"
        str = """
        (
            a,
            [b, c],
            d,
        )"""
        test_format(str_, str; indent=4, margin=13)
        test_format(str_, str; indent=4, margin=11)

        str = """
        (
            a,
            [
                b,
                c,
            ],
            d,
        )"""
        test_format(str_, str; indent=4, margin=10)
        test_format(str, str_; indent=4, margin=length(str))

        str_ = "a, (b, c), d"
        str = """
        a,
        (b, c),
        d"""
        test_format(str_, str; indent=4, margin=length(str_) - 1)
        test_format(str_, str; indent=4, margin=7)

        str = """
        a,
        (
            b,
            c,
        ),
        d"""
        test_format(str_, str; indent=4, margin=6)
        test_format(str, str_; indent=4, margin=length(str))

        str_ = "(var1,var2) && var3"
        str = """
        (var1, var2) &&
            var3"""
        test_format(str_, str; indent=4, margin=19)
        test_format(str_, str; indent=4, margin=15)

        str = """
        (
            var1,
            var2,
        ) && var3"""
        test_format(str_, str; indent=4, margin=14)

        str = """
        (
            var1,
            var2,
        ) &&
            var3"""
        test_format(str_, str; indent=4, margin=1)

        str_ = "(var1,var2) ? (var3,var4) : var5"
        str = """
        (var1, var2) ?
        (var3, var4) :
        var5"""
        test_format(str_, str; indent=4, margin=14)

        str = """
        (
            var1,
            var2,
        ) ?
        (
            var3,
            var4,
        ) : var5"""
        test_format(str_, str; indent=4, margin=13)
        test_format(str_, str; indent=4, margin=8)

        str = """
        (
            var1,
            var2,
        ) ?
        (
            var3,
            var4,
        ) :
        var5"""
        test_format(str_, str; indent=4, margin=7)

        str = """
        (var1, var2) ? (var3, var4) :
        var5"""
        test_format(str_, str; indent=4, margin=29)

        str = """
        (var1, var2) ?
        (var3, var4) : var5"""
        test_format(str_, str; indent=4, margin=28)

        str = """
        f(
            var1::A,
            var2::B,
        ) where {A,B}"""
        test_format("f(var1::A, var2::B) where {A,B}", str; indent=4, margin=30)

        str = """
        f(
            var1::A,
            var2::B,
        ) where {
            A,
            B,
        }"""
        test_format("f(var1::A, var2::B) where {A,B}", str; indent=4, margin=12)

        str = "foo(a, b, c)::Rtype where {A,B} = 10"
        str_ = "foo(a, b, c)::Rtype where {A,B,} = 10"
        test_format(str, str; indent=4, margin=length(str))
        test_format(str_, str; indent=4, margin=length(str_))

        str_ = """
        foo(a, b, c)::Rtype where {A,B} =
            10"""
        test_format(str, str_; indent=4, margin=35)
        test_format(str, str_; indent=4, margin=33)

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {A,B} = 10"""
        test_format(str, str_; indent=4, margin=32)
        test_format(str, str_; indent=4, margin=25)

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {A,B} =
            10"""
        test_format(str, str_; indent=4, margin=24)
        test_format(str, str_; indent=4, margin=22)

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {
            A,
            B,
        } = 10"""
        test_format(str, str_; indent=4, margin=21)

        str_ = """
        foo(
          a,
          b,
          c,
        )::Rtype where {
          A,
          B,
        } =
          10"""
        test_format(str, str_; indent=2, margin=1)

        str_ = """
        foo(
              a,
              b,
              c,
        )::Rtype where {
              A,
              B,
        } = 10"""
        test_format(str, str_; indent=6, margin=18)

        str = "keytype(::Type{<:AbstractDict{K,V}}) where {K,V} = K"
        test_format(str, str; indent=4, margin=52)

        str_ = "transcode(::Type{THISISONESUPERLONGTYPE1234567}) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"

        str = """
        transcode(
          ::Type{THISISONESUPERLONGTYPE1234567},
        ) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"""
        test_format(str_, str; indent=2, margin=80)
        test_format(str_, str; indent=2, margin=68)

        str = """
        transcode(
          ::Type{THISISONESUPERLONGTYPE1234567},
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        test_format(str_, str; indent=2, margin=67)
        test_format(str_, str; indent=2, margin=40)

        str = """
        transcode(
          ::Type{
            THISISONESUPERLONGTYPE1234567,
          },
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        test_format(str_, str; indent=2, margin=39)

        str_ = "transcode(::Type{T}, src::AbstractVector{UInt8}) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"
        str = """
        transcode(
          ::Type{T},
          src::AbstractVector{UInt8},
        ) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"""
        test_format(str_, str; indent=2, margin=80)
        test_format(str_, str; indent=2, margin=68)

        str = """
        transcode(
          ::Type{T},
          src::AbstractVector{UInt8},
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        test_format(str_, str; indent=2, margin=67)

        # issue 56
        str_ = "a_long_function_name(Array{Float64,2}[[1.0], [0.5 0.5], [0.5 0.5; 0.5 0.5], [0.5 0.5; 0.5 0.5]])"
        str = """
        a_long_function_name(
            Array{Float64,2}[[1.0], [0.5 0.5], [0.5 0.5; 0.5 0.5], [0.5 0.5; 0.5 0.5]],
        )"""
        test_format(str, str_; indent=4, margin=length(str))
        test_format(str_, str; indent=4, margin=length(str_) - 1)
        test_format(str_, str; indent=4, margin=79)

        str = """
        a_long_function_name(
            Array{Float64,2}[
                [1.0],
                [0.5 0.5],
                [0.5 0.5; 0.5 0.5],
                [0.5 0.5; 0.5 0.5],
            ],
        )"""
        test_format(str_, str; indent=4, margin=78)

        # unary op
        str_ = "[1, 1]'"
        str = """
        [
          1,
          1,
        ]'"""
        test_format(str, str_; indent=2, margin=length(str))
        test_format(str_, str; indent=2, margin=length(str_) - 1)
    end

    @testset "Trailing zeros" begin
        test_format("1.", "1.0")
        test_format("a * 1. + b", "a * 1.0 + b")
        test_format("1. + 2. * im", "1.0 + 2.0 * im")
        test_format("[1., 2.]", "[1.0, 2.0]")
        test_format("""
        1. +
            2.
        """, "1.0 + 2.0\n")
    end

    @testset "Leading zeros" begin
        test_format(".1", "0.1")
        test_format("a * .1 + b", "a * 0.1 + b")
        test_format(".1 + .2 * im", "0.1 + 0.2 * im")
        test_format("[.1, .2]", "[0.1, 0.2]")
        test_format("""
        .1 +
            .2
        """, "0.1 + 0.2\n")
    end

    # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/77
    @testset "matrices" begin
        str_ = """
        [ a b expr()
        d e expr()]"""
        str = """
        [
          a b expr()
          d e expr()
        ]"""
        test_format(str_, str; indent=2, margin=92)

        str_ = """
        T[ a b Expr()
        d e Expr()]"""
        str = """
        T[
            a b Expr()
            d e Expr()
        ]"""
        test_format(str_, str)

        str_ = """
        [ a b Expr();
        d e Expr();]"""
        str = """
        [
           a b Expr();
           d e Expr();
        ]"""
        test_format(str_, str; indent=3, margin=92)
        str_ = "[a b Expr(); d e Expr()]"
        test_format(str_, str_)
        str = """
        [
           a b Expr();
           d e Expr()
        ]"""
        test_format(str_, str; indent=3, margin=1)

        str_ = """
        T[ a b Expr();
        d e Expr();]"""
        str = """
        T[
            a b Expr();
            d e Expr();
        ]"""
        test_format(str_, str)

        str_ = "T[a b Expr(); d e Expr()]"
        test_format(str_, str_)
        str = """
        T[
            a b Expr();
            d e Expr()
        ]"""
        test_format(str_, str; indent=4, margin=1)

        str = """
        [
          0.0 0.0 0.0 1.0
          0.0 0.0 0.1 1.0
          0.0 0.0 0.2 1.0
          0.0 0.0 0.3 1.0
          0.0 0.0 0.4 1.0
          0.0 0.0 0.5 1.0
          0.0 0.0 0.6 1.0
          0.0 0.0 0.7 1.0
          0.0 0.0 0.8 1.0
          0.0 0.0 0.9 1.0
          0.0 0.0 1.0 1.0
          0.0 0.0 0.0 1.0
          0.0 0.1 0.1 1.0
          0.0 0.2 0.2 1.0
          0.0 0.3 0.3 1.0
          0.0 0.4 0.4 1.0
          0.0 0.5 0.5 1.0
          0.0 0.6 0.6 1.0
          0.0 0.7 0.7 1.0
          0.0 0.8 0.8 1.0
          0.0 0.9 0.9 1.0
          0.0 1.0 1.0 1.0
          0.0 0.0 0.0 1.0
          0.1 0.1 0.1 1.0
          0.2 0.2 0.2 1.0
          0.3 0.3 0.3 1.0
          0.4 0.4 0.4 1.0
          0.5 0.5 0.5 1.0
        ]"""
        test_format(str, str; indent=2, margin=92)
    end

    @testset "multi-variable `for` and `let`" begin
        str = """
        for a in x, b in y, c in z

            body
        end"""
        str_ = """
        for a in x,
            b in y,
            c in z

            body
        end"""
        test_format(str_, str)

        str_ = """
        for a in
            x,
            b in
            y,
            c in
            z

            body
        end"""
        test_format(str, str_; indent=4, margin=1)
        test_format(str_, str)

        str = """
        let a = x, b = y, c = z

            body
        end"""
        str_ = """
        let a = x,
            b = y,
            c = z

            body
        end"""
        test_format(str_, str)

        str_ = """
        let a = x,
            b = y,
            c = z

            body
        end"""
        test_format(str_, str)

        str_ = """
        let a =
                x,
            b =
                y,
            c =
                z

            body
        end"""
        test_format(str, str_; indent=4, margin=1)

        str = """
        let
            # comment
            list = [1, 2, 3]

            body
        end"""
        test_format(str, str)

        # issue 155
        str_ = raw"""
        @testset begin
            @testset "some long title $label1 $label2" for (
                                                               label1,
                                                               x1,
                                                           ) in [
                                                               (
                                                                   "label-1-1",
                                                                   medium_sized_expression,
                                                               ),
                                                               (
                                                                   "label-1-2",
                                                                   medium_sized_expression,
                                                               ),
                                                           ],
                                                           (
                                                               label2,
                                                               x2,
                                                           ) in [
                                                               (
                                                                   "label-2-1",
                                                                   medium_sized_expression,
                                                               ),
                                                               (
                                                                   "label-2-2",
                                                                   medium_sized_expression,
                                                               ),
                                                           ]

                @test x1 == x2
            end
        end"""
        str = raw"""@testset begin
            @testset "some long title $label1 $label2" for (label1, x1) in [
                    ("label-1-1", medium_sized_expression),
                    ("label-1-2", medium_sized_expression),
                ],
                (label2, x2) in [
                    ("label-2-1", medium_sized_expression),
                    ("label-2-2", medium_sized_expression),
                ]

                @test x1 == x2
            end
        end"""
        test_format(str_, str; margin=80)
    end

    @testset "single newline at end of file" begin
        str = "a = 10\n"

        f1 = tempname() * ".jl"
        open(f1, "w") do io
            write(io, "a = 10\n\n\n\n\n\n")
        end
        @test format_file(f1) == false
        @test format_file(f1) == true
        open(f1) do io
            res = read(io, String)
            @test res == str
        end
        rm(f1)
    end

    @testset "trailing comma - breaking cases" begin
        # A trailing comma here is ambiguous
        # It'll cause a parsing error.
        str = """
        gen2 = Iterators.filter(
            x -> x[1] % 2 == 0 && x[2] % 2 == 0,
            (x, y) for x = 1:10, y = 1:10
        )"""
        str_ = "gen2 = Iterators.filter(x -> x[1] % 2 == 0 && x[2] % 2 == 0, (x, y) for x = 1:10, y = 1:10)"

        test_format(str_, str; indent=4, margin=80)

        # With macro calls, a trailing comma can
        # change the semantics of the macro.
        #
        # Keeping this in mind it should not be
        # automatically added.
        str = """
        @func(
            a,
            b,
            c
        )"""
        test_format("@func(a, b, c)", str; indent=4, margin=1)

        str = """
        @func(
            a,
            b,
            c,
        )"""
        test_format("@func(a, b, c,)", str; indent=4, margin=1)
    end

    @testset "comprehension types" begin
        str_ = "var = ((x, y) for x = 1:10, y = 1:10)"
        str = """
        var =
            ((x, y) for x = 1:10, y = 1:10)"""
        test_format(str_, str; indent=4, margin=length(str_) - 1)
        test_format(str_, str; indent=4, margin=35)

        str = """
        var = (
            (x, y) for x = 1:10, y = 1:10
        )"""
        test_format(str_, str; indent=4, margin=34)

        str = """
        var = (
            (x, y) for
            x = 1:10, y = 1:10
        )"""
        test_format(str_, str; indent=4, margin=30)

        str = """
        var = (
            (x, y) for
            x = 1:10,
            y = 1:10
        )"""
        test_format(str_, str; indent=4, margin=20)

        str = """
        var =
            (
                (
                    x,
                    y,
                ) for
                x =
                    1:10,
                y =
                    1:10
            )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        begin
        weights = Dict((file, i) => w for (file, subject) in subjects for (
                i,
                w,
            ) in enumerate(weightfn.(eachrow(subject.events))))
        end"""
        str = """
        begin
            weights = Dict(
                (file, i) => w for (file, subject) in subjects for
                (i, w) in enumerate(weightfn.(eachrow(subject.events)))
            )
        end"""
        test_format(str_, str; indent=4, margin=90)

        str = """
        begin
            weights = Dict(
                (file, i) => w for (file, subject) in subjects
                for (i, w) in
                enumerate(weightfn.(eachrow(subject.events)))
            )
        end"""
        test_format(str_, str; indent=4, margin=60)

        str = """
        begin
            weights = Dict(
                (file, i) => w for
                (file, subject) in subjects for
                (i, w) in enumerate(
                    weightfn.(eachrow(subject.events)),
                )
            )
        end"""
        test_format(str_, str; indent=4, margin=50)

        str_ = "(b for b in bar if b == 0 for bar in foo)"
        test_format(str_, str_)

        str = """
        (
            b for
            b in
            bar if
            b ==
            0 for
            bar in
            foo
        )"""
        test_format(str_, str; indent=4, margin=1)
    end

    @testset "invisbrackets" begin
        str = """
        some_function(
            (((
                very_very_very_very_very_very_very_very_very_very_very_very_long_function_name(
                    very_very_very_very_very_very_very_very_very_very_very_very_long_argument,
                    very_very_very_very_very_very_very_very_very_very_very_very_long_argument,
                ) for x in xs
            ))),
            another_argument,
        )"""
        test_format(str, str)

        str_ = """
some_function(
(((
               very_very_very_very_very_very_very_very_very_very_very_very_long_function_name(
                   very_very_very_very_very_very_very_very_very_very_very_very_long_argument,
                   very_very_very_very_very_very_very_very_very_very_very_very_long_argument,
               )
               for x in xs
))),
           another_argument,
        )"""
        test_format(str_, str)

        str = """
        if ((
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        ))
          nothing
        end"""
        test_format(str, str; indent=2, margin=92)

        str = """
        begin
                if ((
                        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
                        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
                        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                ))
                        nothing
                end
        end"""
        test_format(str, str; indent=8, margin=92)

        #
        # Don't nest the op if an arg is invisbrackets
        #

        str_ = """
        begin
        if foo
        elseif baz
        elseif (a || b) && c
        elseif bar
        else
        end
        end"""

        str = """
        begin
            if foo
            elseif baz
            elseif (a || b) && c
            elseif bar
            else
            end
        end"""
        test_format(str_, str; indent=4, margin=24)

        str = """
        begin
            if foo
            elseif baz
            elseif (a || b) &&
                   c
            elseif bar
            else
            end
        end"""
        test_format(str_, str; indent=4, margin=23)

        str = """
        begin
            if foo
            elseif baz
            elseif (
                a || b
            ) && c
            elseif bar
            else
            end
        end"""
        test_format(str_, str; indent=4, margin=15)

        str = """
        begin
            if foo
            elseif baz
            elseif (
                a ||
                b
            ) && c
            elseif bar
            else
            end
        end"""
        test_format(str_, str; indent=4, margin=14)
        test_format(str_, str; indent=4, margin=10)

        str = """
        begin
            if foo
            elseif baz
            elseif (
                a ||
                b
            ) &&
                   c
            elseif bar
            else
            end
        end"""
        test_format(str_, str; indent=4, margin=9)
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        if s.opts.ignore_maximum_width && !(is_comma(n) || is_block(t) || t.typ === FunctionN ||
                    t.typ  === Macro || is_typedef(t))
                # join based on position in original file
                join_lines = t.endline == n.startline
        end
        """
        str = """
        if s.opts.ignore_maximum_width && !(
            is_comma(n) ||
            is_block(t) ||
            t.typ === FunctionN ||
            t.typ === Macro ||
            is_typedef(t)
        )
            # join based on position in original file
            join_lines = t.endline == n.startline
        end
        """
        test_format(str_, str; indent=4, margin=80)
    end

    @testset "unnest" begin
        str = """
        let X = LinearAlgebra.Symmetric{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where {T},
            Y = Union{
                LinearAlgebra.Hermitian{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where T,
                LinearAlgebra.Symmetric{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where T,
            }

            @test X <: Y
        end"""
        test_format(str, str; indent=4, margin=92)

        str = """
        let X = LinearAlgebra.Symmetric{
                T,
                S,
            } where {S<:(AbstractArray{U,2} where {U<:T})} where {T},
            Y = Union{
                LinearAlgebra.Hermitian{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where T,
                LinearAlgebra.Symmetric{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where T,
            }

            @test X <: Y
        end"""
        test_format(str, str; indent=4, margin=90)

        str = """
        ys = map(xs) do x
            return (
                very_very_very_very_very_very_very_very_very_very_very_long_expr,
                very_very_very_very_very_very_very_very_very_very_very_long_expr,
            )
        end"""
        test_format(str, str)
    end

    @testset "remove excess newlines" begin
        str_ = """
        var = foo(a,

        b,     c,





        d)"""
        str = "var = foo(a, b, c, d)"
        test_format(str_, str)

        str = """
        var =
            foo(
                a,
                b,
                c,
                d,
            )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        var = foo(a,

        b,     c,


        # comment !!!


        d)"""
        str = """
        var = foo(
            a,
            b,
            c,


            # comment !!!


            d,
        )"""
        test_format(str_, str)

        str = """
        var = foo(
            a,
            b,
            c,

            # comment !!!

            d,
        )"""
        test_format(str_, str; remove_extra_newlines = true)

        str_ = """
        var =

            func(a,

            b,

            c)"""
        str = """var = func(a, b, c)"""
        test_format(str_, str)
        test_format(str_, str; remove_extra_newlines = true)

        str_ = """
        var =

            a &&


        b &&
        c"""
        str = """var = a && b && c"""
        test_format(str_, str)
        test_format(str_, str; remove_extra_newlines = true)

        # Inline comment on the line before blank lines should force nesting
        str_ = """
        x =

            a && # inline

            b"""
        str = """
        x =
            a && # inline
            b"""
        test_format(str_, str)

        # Comment in gap lines should force nesting
        str_ = """
        x =

            a &&
            # comment
            b"""
        str = """
        x =
            a &&
            # comment
            b"""
        test_format(str_, str)

        str_ = """
        var =

            a ?


        b :



        c"""
        str = """var = a ? b : c"""
        test_format(str_, str)
        test_format(str_, str; remove_extra_newlines = true)

        str_ = """
        var =

            a +


        b +



        c"""
        str = """var = a + b + c"""
        test_format(str_, str)
        test_format(str_, str; remove_extra_newlines = true)

        str_ = """
        var =

            a   ==


        b   ==



        c"""
        str = """var = a == b == c"""
        test_format(str_, str)
        test_format(str_, str; remove_extra_newlines = true)
    end

    @testset "align ChainOpCall indent" begin
        str_ = """
        function _()
            return some_expression *
            some_expression *
            some_expression *
            some_expression *
            some_expression *
            some_expression *
            some_expression
        end"""
        str = """
        function _()
            return some_expression *
                   some_expression *
                   some_expression *
                   some_expression *
                   some_expression *
                   some_expression *
                   some_expression
        end"""
        test_format(str_, str)

        str_ = """
        @some_macro some_expression *
        some_expression *
        some_expression *
        some_expression *
        some_expression *
        some_expression *
        some_expression"""
        str = """
        @some_macro some_expression *
                    some_expression *
                    some_expression *
                    some_expression *
                    some_expression *
                    some_expression *
                    some_expression"""
        test_format(str_, str)

        str_ = """
        if some_expression && some_expression && some_expression && some_expression

            body
        end"""
        str = """
        if some_expression &&
           some_expression &&
           some_expression &&
           some_expression

            body
        end"""
        test_format(str_, str; margin = 74)
        test_format(str, str_; margin = 75)

        str_ = """
        if argument1 && argument2 && (argument3 || argument4 || argument5) && argument6

            body
        end"""
        str = """
        if argument1 &&
           argument2 &&
           (argument3 || argument4 || argument5) &&
           argument6

            body
        end"""
        test_format(str_, str; margin = 43)

        str = """
        if argument1 &&
           argument2 &&
           (
               argument3 ||
               argument4 ||
               argument5
           ) &&
           argument6

            body
        end"""
        test_format(str_, str; margin = 42)
    end

    @testset "standalone lazy expr indent" begin
        str = """
        begin
          a &&
            b
          a ||
            b
        end"""
        test_format(str, str; indent=2, margin=1)

        str_ = """
        begin
         a && b || c && d
        end"""

        str = """
        begin
            a && b ||
                c && d
        end"""
        test_format(str_, str; indent=4, margin=19)

        str = """
        begin
            a && b ||
                c &&
                d
        end"""
        test_format(str_, str; indent=4, margin=13)

        str = """
        begin
            a &&
            b ||
                c &&
                d
        end"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        begin
        a || (b && c && d)
        end"""

        str = """
        begin
            a ||
                (
                    b &&
                    c &&
                    d
                )
        end"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        begin
        (a && b && c) || d
        end"""

        str = """
        begin
            (
                a &&
                b &&
                c
            ) ||
                d
        end"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        begin
         a || b && c || d
        end"""

        str = """
        begin
            a ||
                b && c ||
                d
        end"""
        test_format(str_, str; indent=4, margin=19)

        str = """
        begin
            a ||
                b &&
                c ||
                d
        end"""
        test_format(str_, str; indent=4, margin=16)

        str_ = """
        begin
         a && b || c || d || e
        end"""
        str = """
        begin
            a &&
            b ||
                c ||
                d ||
                e
        end"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        begin
         a || b && c && d && e
        end"""
        str = """
        begin
            a ||
                b &&
                c &&
                d &&
                e
        end"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        if aa && bb
        end

        if (aa && bb)
        end"""

        str = """
        if aa &&
           bb
        end

        if (
            aa &&
            bb
        )
        end"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        if aa || bb || cc
        end

        if (aa || bb || cc)
        end"""

        str = """
        if aa ||
           bb ||
           cc
        end

        if (
            aa ||
            bb ||
            cc
        )
        end"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """var = a && b"""
        str = """
        var =
            a &&
            b"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """var() = a && b"""
        str = """
        var() =
            a &&
            b"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """var = a || b || c"""
        str = """
        var =
            a ||
            b ||
            c"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """var() = a || b || c"""
        str = """
        var() =
            a ||
            b ||
            c"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        @hello arg1 && arg2 && return arg3"""
        str = """
        @hello arg1 &&
               arg2 &&
               return arg3"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        @hello arg1 || return arg2"""
        str = """
        @hello arg1 ||
               return arg2"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """
        return arg1 || arg2"""
        str = """
        return arg1 ||
               arg2"""
        test_format(str_, str; indent=4, margin=1)

        str_ = raw"""
        @othermacro begin
                x isa Matrix &&
                   @testset "$MT" for MT in (Diagonal, UpperTriangular, LowerTriangular)
                       test_rrule(fnorm, MT(x), p; kwargs..., check_inferred=VERSION >= v"1.5")
                   end
        end
        """
        str = raw"""
        @othermacro begin
            x isa Matrix &&
                @testset "$MT" for MT in (Diagonal, UpperTriangular, LowerTriangular)
                    test_rrule(
                        fnorm,
                        MT(x),
                        p;
                        kwargs...,
                        check_inferred = VERSION >= v"1.5",
                    )
                end
        end
        """
        test_format(str_, str; indent=4, margin=80)
    end

    @testset "source file line offset with unicode" begin
        # These just check to see formatting runs without error

        str = """
        a = 10
        # └─ code.jl (before -> after2)
        v = "test_basic_config"
        """
        test_format(str, str)

        str = """
        a = 10
        unicode_str = "α10′"
        v = "test_basic_config"
        """
        test_format(str, str)

        str = """
        a = 10
        unicode_op = 5 ⪅ 10.0
        v = "test_basic_config"
        """
        test_format(str, str)

        str = """
        a = 10
        unicode_identifier′ = 10
        v = "test_basic_config"
        """
        test_format(str, str)

        str = "const FOO = ['😢']"
        test_format(str, str)

        str = "const FOO = '😢'"
        test_format(str, str)
    end

    @testset "comprehension leftover extra margin" begin
        str_ = """
        src_idx = [mod1(div(dest_idx[dim] - 1, inner[dim]) + 1, S[dim]) for dim = 1:length(S)]
        """
        str = """
        src_idx = [
            mod1(div(dest_idx[dim] - 1, inner[dim]) + 1, S[dim]) for dim = 1:length(S)
        ]
        """
        test_format(str_, str; indent=4, margin=78)
    end

    @testset "operators as arguments" begin
        str_ = "a    .*     %"
        str = "a .* %"
        test_format(str_, str; indent=4, margin=100)

        str_ = "a    *     %"
        str = "a * %"
        test_format(str_, str; indent=4, margin=100)

        @test run_pretty("+(y)", 80)[1].typ === JuliaFormatter.Unary
        @test run_pretty(">=(y)", 80)[1].typ === JuliaFormatter.Call
    end

    @testset "binary shortcircuit" begin
        s1 = """
        if a || b
            body
        elseif c || d
            body2 && body2
        elseif e || f
            body3 || body3
        else
            body4 && body4
        end
        """
        s2 = """
        if a ||
           b
                body
        elseif c ||
               d
                body2 &&
                        body2
        elseif e ||
               f
                body3 ||
                        body3
        else
                body4 &&
                        body4
        end
        """
        test_format(s1, s2; indent=8, margin=1)

        str_ = """
        a =     if where_idx === nothing
               from_typedef
           else
               from_typedef ||
               b
           end
        """
        str = """
        a =
            if where_idx ===
               nothing
                from_typedef
            else
                from_typedef ||
                    b
            end
        """
        test_format(str_, str; indent=4, margin=1)
    end

    @testset "parameter to call nesting" begin
        # always nest is in parameters
        s = raw"""
        test_rrule(
            SymHerm,
            x,
            uplo;
            output_tangent = ΔΩ,
            # type stability here critically relies on uplo being constant propagated,
            # so we need to test this more carefully below
            check_inferred = false,
        )
        """
        test_format(s, s; indent=4, margin=100)

        # always nest is outsite of parameters in the call
        s = raw"""
        test_rrule(  # 5 arg version with scaling scalar
            gemm,
            tA,
            tB,
            randn(T),
            A,
            B;
            check_inferred = false,
        )
        """
        test_format(s, s; indent=4, margin=100)
    end

    @testset "no args before kwargs ; placement" begin
        str_ = """(; a = b, c = d)"""
        str = """
        (;
            a = b,
            c = d,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """(;  # inline
            a = b, c = d)"""
        str = """
        (;  # inline
            a = b,
            c = d,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """(;
            # comment
            a = b, c = d)"""
        str = """
        (;
            # comment
            a = b,
            c = d,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """(arg;
            # comment
            a = b, c = d)"""
        str = """
        (
            arg;
            # comment
            a = b,
            c = d,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """(arg; # inline
            a = b, c = d)"""
        str = """
        (
            arg; # inline
            a = b,
            c = d,
        )"""
        test_format(str_, str; indent=4, margin=1)

        str_ = """(arg;
            a = b, c = d)"""
        str = """
        (
            arg;
            a = b,
            c = d,
        )"""
        test_format(str_, str; indent=4, margin=1)
    end

    @testset "for loop, extra placeholder not added" begin
        str_ = """
        for i in [a,b,c]
            body
        end
        """
        str = """
        for i in
            [
            a,
            b,
            c,
        ]
            body
        end
        """
        test_format(str_, str; indent=4, margin=1)
    end

    @testset "for loop, placeholder not removed" begin
        str_ = """
        for f in (A, B), T in (C, D)
            a
            b
        end"""
        str = """
        for f in (A, B),
            T in (C, D)

            a
            b
        end"""
        test_format(str_, str; indent=4, margin=27)
        test_format(str, str; indent=4, margin=27, join_lines_based_on_source = true)
    end

    @testset "block automatically assume nested when join_lines_based_on_source" begin
        str_ = """
        let y = a, z = b
            body
        end"""
        str = """
        let y = a,
            z = b

            body
        end"""
        test_format(str_, str_; indent=4, margin=16, join_lines_based_on_source = true)
        test_format(str_, str; indent=4, margin=15, join_lines_based_on_source = true)
    end

    if VERSION >= v"1.11.0"
        @testset "public keyword support" begin
            str_ = """
            public    a,b,
             c
            """
            str = """
            public a, b, c
            """
            test_format(str_, str; indent=4, margin=14)
            str = """
            public a,
                b,
                c
            """
            test_format(str_, str; indent=4, margin=1)
        end
    end
end

end # module
