@testset "Default Style" begin
    @testset "basic" begin
        @test fmt("") == ""
        @test fmt("a") == "a"
        @test fmt("a  #foo") == "a  #foo"
        @test fmt("#foo") == "#foo"

        str = """
        begin
            #=
               Hello, world!
             =#
        end
        """
        @test fmt(str) == str

        str = """
        #=
        Hello, world!
        =#
        a"""
        @test fmt(str) == str
    end

    @testset "format toggle" begin
        str = "#! format: off\n module Foo a \n end"
        @test fmt(str) == str

        str = "#! format: off\n#! format: on"
        @test fmt(str) == str

        str = """
        begin
            #! format: off
            don't
                  format
                         this
            #! format: on
        end"""
        @test fmt(str) == str

        str = """
        begin
            #! format: off
            # don't
            #     format
            #            this
            #! format: on
        end"""
        @test fmt(str) == str

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
        @test fmt(str_) == str

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
        @test fmt(str_) == str

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
        @test fmt(str) == str
    end

    @testset "dot op" begin
        @test fmt("10 .^ a") == "10 .^ a"
        @test fmt("10.0 .^ a") == "10.0 .^ a"
        @test fmt("a.^b") == "a .^ b"
        @test fmt("a.^10.") == "a .^ 10.0"
        @test fmt("a.//10") == "a .// 10"

        @test fmt("a .^ b") == "a .^ b"
        @test fmt("a .^ 10.") == "a .^ 10.0"
        @test fmt("a .// 10") == "a .// 10"
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
        @test fmt(str_) == str
        t = run_pretty(str, 80)
        @test length(t) == 17
    end

    @testset "for = vs in normalization" begin
        str = """
        for i = 1:n
            println(i)
        end"""
        @test fmt(str) == str

        str = """
        for i in itr
            println(i)
        end"""
        @test fmt(str) == str

        str = """
        for i = 1:n
            println(i)
        end"""
        str_ = """
        for i in 1:n
            println(i)
        end"""
        @test fmt(str_) == str

        str = """
        for i in itr
            println(i)
        end"""
        str_ = """
        for i = itr
            println(i)
        end"""
        @test fmt(str_) == str

        str_ = """
        for i = I1, j in I2
            println(i, j)
        end"""
        str = """
        for i in I1, j in I2
            println(i, j)
        end"""
        @test fmt(str_) == str

        str_ = """
        for i = 1:30, j in 100:-2:1
            println(i, j)
        end"""
        str = """
        for i = 1:30, j = 100:-2:1
            println(i, j)
        end"""
        @test fmt(str_) == str

        str_ = "[(i,j) for i=I1,j=I2]"
        str = "[(i, j) for i in I1, j in I2]"
        @test fmt(str_) == str

        str_ = "((i,j) for i=I1,j=I2)"
        str = "((i, j) for i in I1, j in I2)"
        @test fmt(str_) == str

        str_ = "[(i,j) for i in 1:2:10,j  in 100:-1:10]"
        str = "[(i, j) for i = 1:2:10, j = 100:-1:10]"
        @test fmt(str_) == str

        str_ = "((i,j) for i in 1:2:10,j  in 100:-1:10)"
        str = "((i, j) for i = 1:2:10, j = 100:-1:10)"
        @test fmt(str_) == str
    end

    @testset "tuples" begin
        @test fmt("(a,)") == "(a,)"
        @test fmt("a,b") == "a, b"
        @test fmt("a ,b") == "a, b"
        @test fmt("(a,b)") == "(a, b)"
        @test fmt("(a ,b)") == "(a, b)"
        @test fmt("( a, b)") == "(a, b)"
        @test fmt("(a, b )") == "(a, b)"
        @test fmt("(a, b ,)") == "(a, b)"
        @test fmt("""(a,    b ,
                            c)""") == "(a, b, c)"
    end

    @testset "curly" begin
        @test fmt("X{a,b}") == "X{a,b}"
        @test fmt("X{ a,b}") == "X{a,b}"
        @test fmt("X{a ,b}") == "X{a,b}"
        @test fmt("X{a, b}") == "X{a,b}"
        @test fmt("X{a,b }") == "X{a,b}"
        @test fmt("X{a,b }") == "X{a,b}"

        str = """
        mutable struct Foo{A<:Bar,Union{B<:Fizz,C<:Buzz},<:Any}
            a::A
        end"""
        @test fmt(str) == str
        t = run_pretty(str, 80)
        @test length(t) == 55

        str = """
        struct Foo{A<:Bar,Union{B<:Fizz,C<:Buzz},<:Any}
            a::A
        end"""
        @test fmt(str) == str
        t = run_pretty(str, 80)
        @test length(t) == 47
    end

    @testset "where op" begin
        str = "Atomic{T}(value) where {T<:AtomicTypes} = new(value)"
        str_ = "Atomic{T}(value) where T <: AtomicTypes = new(value)"
        @test fmt(str) == str
        @test fmt(str_) == str

        str = "Vector{Vector{T} where T}"
        @test fmt(str) == str

        str_ = "Vector{Vector{T}} where T"
        str = "Vector{Vector{T}} where {T}"
        @test fmt(str_) == str
        @test fmt(str) == str
    end

    @testset "unary ops" begin
        @test fmt("! x") == "! x"
        @test fmt("x ...") == "x ..."
        @test fmt("!x") == "!x"
        @test fmt("x...") == "x..."

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
        @test fmt(str) == str

        str_ = "foo(args...)"
        str = """
        foo(
            args...,
        )"""
        @test fmt(str_; m = 1) == str
        @test fmt(str; m = 1) == str
    end

    @testset ": op" begin
        @test fmt("a:b:c") == "a:b:c"
        @test fmt("a :b:c") == "a:b:c"
        @test fmt("a: b:c") == "a:b:c"
        @test fmt("a:b :c") == "a:b:c"
        @test fmt("a:b: c") == "a:b:c"
        @test fmt("a:b:c ") == "a:b:c"
    end

    @testset "binary ops" begin

        @testset "whitespace addition" begin
            # For these 'operators' whitespace should only be added if there is already some
            # whitespace around the operator. (Note that the word 'operator' is used here
            # lightly, because many of these are parsed as infix _function calls_ rather
            # than infix _operators_ per se -- IMO we need clearer nomenclature.) There are
            # probably more that we need to test...
            for op in ("+", "*", "/", "-", "^", "%", "<", ">", "<=", ">=", "=>", "->", "-->", "<--", "~", "<:", ">:")
                # see below also for <: and >:
                @test fmt("a$(op)b") == "a$(op)b"
                @test fmt("a $(op)b") == "a $(op) b"
                @test fmt("a$(op) b") == "a $(op) b"
                @test fmt("a $(op) b") == "a $(op) b"
                @test fmt("a  $(op)  b") == "a $(op) b"
            end
            # For these ops there should never be whitespace
            for op in (":", "::")
                target = "a$(op)b"
                @test fmt("a$(op)b") == target
                @test fmt("a $(op)b") == target
                @test fmt("a$(op) b") == target
                @test fmt("a $(op) b") == target
                @test fmt("a  $(op)  b") == target
            end
            # Supertypes / subtypes have special behaviour within typedefs
            for op in ("<:", ">:")
                target = "function f() where {a$(op)b} end"
                @test fmt("function f() where {a$(op)b} end") == target
                @test fmt("function f() where {a $(op)b} end") == target
                @test fmt("function f() where {a$(op) b} end") == target
                @test fmt("function f() where {a $(op) b} end") == target
                @test fmt("function f() where {a  $(op)  b} end") == target
            end
        end

        @test fmt("a+b*c") == "a+b*c"
        @test fmt("a +b *c") == "a + b * c"
        @test fmt("a + b      *c") == "a + b * c"
        @test fmt("a +b*c") == "a + b*c"
        @test fmt("a + b*c") == "a + b*c"
        @test fmt("a+b *c") == "a+b * c"
        @test fmt("a+b* c") == "a+b * c"
        @test fmt("a+b*c ") == "a+b*c"
        @test fmt("a:b") == "a:b"
        @test fmt("a : b") == "a:b"
        @test fmt("a: b") == "a:b"
        @test fmt("a :b") == "a:b"
        @test fmt("a +1 :b -1") == "(a+1):(b-1)"

        @test fmt("a::b:: c") == "a::b::c"
        @test fmt("a :: b::c") == "a::b::c"
        @test fmt("a      :: b   :: c") == "a::b::c"
        # issue 74
        @test fmt("0:1/3:2") == "0:(1/3):2"
        @test fmt("2a") == "2a"
        # issue 251
        @test fmt("2(a   + 1)") == "2(a + 1)"
        @test fmt("2(a+1)") == "2(a+1)"
        @test fmt("1 / 2a^2") == "1 / 2a^2"

        str_ = "a[1:2 * num_source * num_dump-1]"
        str = "a[1:(2*num_source*num_dump-1)]"
        @test fmt(str_, 4, 1) == str

        str_ = "a[2 * num_source * num_dump-1:1]"
        str = "a[(2*num_source*num_dump-1):1]"
        @test fmt(str_, 4, 1) == str

        str = "!(typ <: ArithmeticTypes)"
        @test fmt(str) == str

        text = "a + b"
        d = JuliaFormatter.Document(text)
        s = JuliaFormatter.State(d, Options())
        g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text)
        op = JuliaSyntax.children(only(JuliaSyntax.children(g)))[3]
        @test JuliaFormatter.source_op_kind_from_offset(s, op, UInt32(3)) ===
              JuliaSyntax.Kind("+")

        @test fmt("1 // 2 + 3^4") == "1 // 2 + 3^4"
        @test fmt("1 // 2 + 3 ^ 4") == "1 // 2 + 3 ^ 4"

        # Function def

        str_ = """foo() = if cond a else b end"""
        str = """
        foo() =
            if cond
                a
            else
                b
            end"""
        @test fmt(str_) == str

        str_ = """
        foo() = begin
            body
        end"""
        str = """
        foo() =
            begin
                body
            end"""
        @test fmt(str) == str_
        @test fmt(str_, 4, 1) == str

        str_ = """
        foo() = quote
            body
        end"""
        str = """
        foo() =
            quote
                body
            end"""
        @test fmt(str) == str_
        @test fmt(str_, 4, 1) == str

        str = """foo() = :(Union{})"""
        @test fmt(str) == str

        str_ = """foo() = for i=1:10 body end"""
        str = """
        foo() =
            for i = 1:10
                body
            end"""
        @test fmt(str_) == str

        str_ = """foo() = for outer i=1:10 body end"""
        str = """
        foo() =
            for outer i = 1:10
                body
            end"""
        @test fmt(str_) == str

        str_ = """foo() = while cond body end"""
        str = """
        foo() =
            while cond
                body
            end"""
        @test fmt(str_) == str

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
        @test fmt(str_) == str

        # Assignment op

        str_ = """foo = if cond a else b end"""
        str = """
        foo =
          if cond
            a
          else
            b
          end"""
        @test fmt(str_, 2, 1) == str

        str_ = """foo = begin body end"""
        str = """
        foo = begin
          body
        end"""
        @test fmt(str_, 2, 11) == str
        str = """
        foo =
          begin
            body
          end"""
        @test fmt(str_, 2, 10) == str

        str_ = """foo = quote body end"""
        str = """
        foo = quote
          body
        end"""
        @test fmt(str_, 2, 11) == str
        str = """
        foo =
          quote
            body
          end"""
        @test fmt(str_, 2, 10) == str

        str_ = """foo = for i=1:10 body end"""
        str = """
        foo = for i = 1:10
          body
        end"""
        @test fmt(str_, 2, 18) == str
        str = """
        foo =
          for i = 1:10
            body
          end"""
        @test fmt(str_, 2, 17) == str

        str_ = """foo = while cond body end"""
        str = """
        foo =
          while cond
            body
          end"""
        @test fmt(str_, 2, 1) == str

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
        @test fmt(str_, 2, 1) == str

        str_ = """
        foo = let
          body
        end"""
        @test fmt(str_, 2, 9) == str_
        str = """
        foo =
          let
            body
          end"""
        @test fmt(str_, 2, 8) == str
        str = """
        foo =
          let
            body
          end"""
        @test fmt(str_, 2, 1) == str

        str_ = """a, b = cond ? e1 : e2"""

        str = """
        a, b =
            cond ? e1 : e2"""
        @test fmt(str_, 4, length(str_) - 1) == str
        @test fmt(str_, 4, 18) == str

        str = """
        a, b =
            cond ? e1 :
            e2"""
        @test fmt(str_, 4, 17) == str
        @test fmt(str_, 4, 15) == str

        str = """
        a, b =
            cond ?
            e1 : e2"""
        @test fmt(str_, 4, 14) == str
        @test fmt(str_, 4, 11) == str

        str = """
        a, b =
            cond ?
            e1 :
            e2"""
        @test fmt(str_, 4, 10) == str

        str = """
        begin
            variable_name =
                argument1 + argument2
        end"""
        @test fmt(str, 4, 40) == str

        str = """
        begin
            variable_name =
                argument1 +
                argument2
        end"""
        @test fmt(str, 4, 28) == str

        str = """
        begin
            variable_name =
                conditional ? expression1 : expression2
        end"""
        @test fmt(str, 4, 58) == str

        str = """
        begin
            variable_name =
                conditional ? expression1 :
                expression2
        end"""
        @test fmt(str, 4, 46) == str

        str = """
        begin
            variable_name =
                conditional ?
                expression1 : expression2
        end"""
        @test fmt(str, 4, 34) == str
        @test fmt(str, 4, 33) == str

        str = """
        begin
            variable_name =
                conditional ?
                expression1 :
                expression2
        end"""
        @test fmt(str, 4, 32) == str

        str = "shmem[pout*rows+row] += shmem[pin*rows+row] + shmem[pin*rows+row-offset]"

        str_ = """
        shmem[pout*rows+row] +=
               shmem[pin*rows+row] + shmem[pin*rows+row-offset]"""
        @test fmt(str, 7, 71) == str_
        str_ = """
        shmem[pout*rows+row] +=
               shmem[pin*rows+row] +
               shmem[pin*rows+row-offset]"""
        @test fmt(str, 7, 54) == str_

        str = """
        begin
           var = func(arg1, arg2, arg3) * num
        end"""
        @test fmt(str, 3, 37) == str

        str_ = """
        begin
           var =
              func(arg1, arg2, arg3) * num
        end"""
        @test fmt(str, 3, 36) == str_
        @test fmt(str, 3, 34) == str_

        str_ = """
        begin
           var =
              func(arg1, arg2, arg3) *
              num
        end"""
        @test fmt(str, 3, 33) == str_
        @test fmt(str, 3, 30) == str_

        str_ = """
        begin
           var =
              func(
                 arg1,
                 arg2,
                 arg3,
              ) * num
        end"""
        @test fmt(str, 3, 29) == str_

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
        @test fmt(str, 3, 1) == str_

        str = """
        begin
            foo() =
                (one, x -> (true, false))
        end"""
        @test fmt(str, 4, 36) == str
        @test fmt(str, 4, 33) == str

        str = """
        begin
            foo() = (
                one,
                x -> (true, false),
            )
        end"""
        @test fmt(str, 4, 32) == str
        @test fmt(str, 4, 27) == str
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
        @test fmt(str, 4, 26) == str

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
        @test fmt(str) == str

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
        @test fmt(str) == str

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
        @test fmt(str) == str

        str = "var = \"a_long_function_stringggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg\""
        fmt(str, 4, 1) == str
    end

    @testset "op chain" begin
        @test fmt("a+b+c+d") == "a+b+c+d"
        @test fmt("a + b + c +d") == "a + b + c + d"
    end

    @testset "comparison chain" begin
        @test fmt("a<b==c≥d") == "a<b==c≥d"
        @test fmt("a<b == c≥d") == "a < b == c ≥ d"
    end

    @testset "single line block" begin
        @test fmt("(a;b;c)") == "(a; b; c)"
    end

    @testset "func call" begin
        @test fmt("func(a, b, c)") == "func(a, b, c)"
        @test fmt("func(a,b,c)") == "func(a, b, c)"
        @test fmt("func(a,b,c,)") == "func(a, b, c)"
        @test fmt("func(a,b,c, )") == "func(a, b, c)"
        @test fmt("func( a,b,c    )") == "func(a, b, c)"
        @test fmt("func(a, b, c) ") == "func(a, b, c)"
        @test fmt("func(a, b; c)") == "func(a, b; c)"
        @test fmt("func(  a, b; c)") == "func(a, b; c)"
        @test fmt("func(a  ,b; c)") == "func(a, b; c)"
        @test fmt("func(a=1,b; c=1)") == "func(a = 1, b; c = 1)"

        str = """
        func(;
          c = 1,
        )"""
        @test fmt("func(; c = 1)", 2, 1) == str

        @test fmt("func(; c = 1,)") == "func(; c = 1)"
        @test fmt("func(a;)") == "func(a;)"

        str = """
        func(;
            a,
            b,
        )"""
        @test fmt(str, 4, 1) == str

        str = """
        func(
            x;
            a,
            b,
        )"""
        @test fmt(str, 4, 1) == str
    end

    @testset "macro call" begin
        str = """
        @f(
            a,
            b;
            x
        )"""
        str_ = "@f(a, b; x)"
        @test fmt(str_) == str_
        @test fmt(str_, 4, 1) == str

        str = """
        @f(
            a;
            x
        )"""
        str_ = "@f(a; x)"
        @test fmt(str_) == str_
        @test fmt(str_, 4, 1) == str

        str = """
        @f(;
          x
        )"""
        str_ = "@f(; x)"
        @test fmt(str_) == str_
        @test fmt(str_, 2, 1) == str

        str = """
        @f(;
            a,
            b
        )"""
        @test fmt(str, 4, 1) == str

        str = """
        @f(
            x;
            a,
            b
        )"""
        @test fmt(str, 4, 1) == str

        str = """@warn("Text")"""
        @test fmt(str) == str

        str_ = "@Module.macro"
        str = "Module.@macro"
        @test fmt(str_) == str
        @test fmt(str) == str

        str_ = "\$Module.@macro"
        str = "\$Module.@macro"
        @test fmt(str_) == str
        @test fmt(str) == str

        # @doc here should not be parsed as a macro string
        str = raw"push!(docs, :(@doc($meta, $(each.args[end]), $define)))"
        @test fmt(str) == str
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
        @test fmt(str_, 4, length(str_) - 1) == str
    end

    @testset "begin" begin
        str = """
        begin
            arg
        end"""
        @test fmt("""
                    begin
                    arg
                    end""") == str
        @test fmt("""
                    begin
                        arg
                    end""") == str
        @test fmt("""
                    begin
                        arg
                    end""") == str
        @test fmt("""
                    begin
                            arg
                    end""") == str
        str = """
        begin
            begin
                arg
            end
        end"""
        @test fmt("""
                    begin
                    begin
                    arg
                    end
                    end""") == str
        @test fmt("""
                    begin
                                begin
                    arg
                    end
                    end""") == str
        @test fmt("""
                    begin
                                begin
                    arg
                            end
                    end""") == str

        str = """
        begin
            s = foo(aaa, bbbb, cccc)
            s = foo(
                aaaa,
                bbbb,
                cccc,
            )
        end"""
        @test fmt(str, 4, 28) == str
    end

    @testset "quote" begin
        str = """
        quote
            arg
        end"""
        @test fmt("""
        quote
            arg
        end""") == str
        @test fmt("""
        quote
        arg
        end""") == str
        @test fmt("""
        quote
                arg
            end""") == str

        str = """:(a = 10; b = 20; c = a * b)"""
        @test fmt(":(a = 10; b = 20; c = a * b)") == str

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
        @test fmt(str_) == str
        @test fmt(str) == str

        str = """
        quote
            s = foo(aaa, bbbb, cccc)
            s = foo(
                aaaa,
                bbbb,
                cccc,
            )
        end"""
        @test fmt(str, 4, 28) == str
    end

    @testset "do" begin
        str = """
        map(args) do x
            y = 20
            return x * y
        end"""

        @test fmt("""
        map(args) do x
          y = 20
                            return x * y
            end""") == str

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
        @test fmt(str_) == str

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
        @test fmt(str_) == str
    end

    @testset "for" begin
        str = """
        for iter in I
            arg
        end"""
        @test fmt("""
        for iter in I
            arg
        end""") == str
        @test fmt("""
        for iter in I
        arg
        end""") == str
        @test fmt("""
        for iter in I
          arg
        end""") == str

        str = """
        for iter in I, iter2 in I2
            arg
        end"""
        @test fmt("""
        for iter = I, iter2= I2
            arg
        end""") == str
        @test fmt("""
        for iter= I, iter2=I2
        arg
        end""") == str
        @test fmt("""
        for iter    = I, iter2 = I2
                arg
            end""") == str

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
        @test fmt("""
        while cond
            arg
        end""") == str
        @test fmt("""
        while cond
        arg
        end""") == str
        @test fmt("""
        while cond
                arg
            end""") == str

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
    end

    @testset "let" begin
        str = """
        let x=X
            arg
        end"""
        @test fmt("""
        let x=X
            arg
        end""") == str
        @test fmt("""
        let x=X
        arg
        end""") == str
        @test fmt("""
        let x=X
            arg
        end""") == str

        str = """
        let x = X, y = Y
            arg
        end"""
        @test fmt("""
        let x = X, y = Y
            arg
        end""") == str
        @test fmt("""
        let x = X, y = Y
        arg
        end""") == str

        str = """
        y, back = let
            body
        end"""
        @test fmt("""
        y,back = let
          body
        end""") == str

        str = """
        let x = a,
            # comment
            b,
            c

            body
        end"""
        @test fmt("""
        let x = a,
            # comment
               b,
              c
           body
           end""") == str

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
        @test fmt("""
        try
            arg
        catch
            arg
        end""") == str

        @test fmt("""
        try
        arg
        catch
        arg
        end""") == str

        @test fmt("""
        try
                arg
            catch
                arg
            end""") == str

        str = """
        try
            arg
        catch
            arg
        end"""
        @test fmt("""
        try
            arg
        catch
            arg
        end""") == str

        @test fmt("""
        try
        arg
        catch
        arg
        end""") == str

        @test fmt("""
        try
                arg
            catch
                arg
            end""") == str

        str = """
        try
            arg
        catch err
            arg
        end"""

        @test fmt("""
        try
            arg
        catch err
            arg
        end""") == str

        @test fmt("""
        try
        arg
        catch err
        arg
        end""") == str

        @test fmt("""
        try
                arg
            catch err
                arg
            end""") == str

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
    end

    @testset "strings" begin
        str = """
        \"""
        Interpolate using `\\\$`
        \"""
        a"""
        @test fmt(str) == str

        str = """error("foo\\n\\nbar")"""
        @test fmt(str) == str

        str = """
        \"""
        \\\\
        \"""
        x"""
        @test fmt(str) == str

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
        @test fmt(str_) == str

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
                @test fmt(s) == s
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
        @test fmt(str_, 4, 120) == str

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
        @test fmt(str_, 4, 1) == str

        str = """
        foo() = llvmcall(\"""
                         llvm1
                         llvm2
                         \""")"""
        @test fmt(str) == str
        # nests and then unnests
        @test fmt(str, 2, 20) == str

        str_ = """
        foo() =
          llvmcall(\"""
                   llvm1
                   llvm2
                   \""")"""
        @test fmt(str, 2, 19) == str_

        # the length calculation is kind of wonky here
        # but it's still a worthwhile test
        str_ = """
        foo() =
            llvmcall(\"""
                     llvm1
                     llvm2
                     \""")"""
        @test fmt(str, 4, 19) == str_

        str_ = """
        foo() = llvmcall(
            \"""
            llvm1
            llvm2
            \""",
        )"""
        @test fmt(str, 4, 18) == str_

        str_ = """
        foo() =
          llvmcall(
            \"""
            llvm1
            llvm2
            \""",
          )"""
        @test fmt(str, 2, 10) == str_

        str = """
        str = \"""
        begin
            arg
        end\"""
        """
        @test fmt(str) == str

        str = """
        str = \"""
              begin
                  arg
              end\"""
        """
        @test fmt(str) == str

        str = raw"""@test :(x`s`flag) == :(@x_cmd "s" "flag")"""
        @test fmt(str) == str

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
        @test fmt(str) == str
        @test fmt(str, 4, 1) == str_

        str_ = """foo(r"hello"x)"""
        str = """
        foo(
            r"hello"x,
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = """foo(r`hello`x)"""
        str = """
        foo(
            r`hello`x,
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = """foo(r\"""hello\"""x)"""
        str = """
        foo(
            r\"""hello\"""x,
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = """foo(r```hello```x)"""
        str = """foo(
            r```hello```x,
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = """foo(\"""hello\""")"""
        str = """foo(
            \"""hello\""",
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = """foo(```hello```)"""
        str = """foo(
            ```hello```,
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = raw"""
        occursin(r"^#!\s*format\s*:\s*off\s*$", t.val)
        """
        @test fmt(str_) == str_

        str = raw"""
        occursin(
            r"^#!\s*format\s*:\s*off\s*$",
            t.val,
        )
        """
        @test fmt(str_, 4, 1) == str
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
        @test fmt(str) == str
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
        @test fmt(str_) == str

        str = "# comment 0\n\n\n\n\na = 1\n\n# comment 1\n\n\n\n\nb = 2\n\n\nc = 3\n\n# comment 2\n\n"
        @test fmt(str) == str

        str = """
        #=
        hello
        world
        =#
        const a = \"hi there\""""
        @test fmt(str) == str

        str = """
        if a
            # comment above var
            var = 10
            # comment below var
        else
            something_else()
        end"""
        @test fmt(str) == str

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
        @test fmt(str_) == str

        str = """
        function bar(x, y)
            # single comment ending in a subscriptₙ
            x - y
        end"""
        @test fmt("""
        function bar(x, y)
            # single comment ending in a subscriptₙ
            x- y
        end""") == str

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
        @test fmt(str_) == str

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
        @test fmt(str_) == str

        str = """
        A ? # foo
        # comment 1

        B :    # bar
        # comment 2
        C"""
        @test fmt(str) == str

        str = """
        A ? B :
        # comment

        C"""
        @test fmt(str) == str

        str_ = """
        foo = A ?
            # comment 1

            B : C"""

        str = """
        foo =
            A ?
            # comment 1

            B : C"""
        @test fmt(str_) == str

        str = """
        foo =
           A ?
           # comment 1

           B :
           C"""
        @test fmt(str_, 3, 1) == str

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
        @test fmt(str_, 3, 100) == str
        @test fmt(str_, 3, 1) == str

        str = """
        begin
            var =
                a +
                # comment
                b
        end
        """
        @test fmt(str) == str

        str = """
        begin
            var() =
                a +
                # comment
                b
        end
        """
        @test fmt(str) == str

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
        @test fmt(str_) == str

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
        @test fmt(str_, 2, 92) == str

        str = """
        foo() = 10 where {
            # comment
            A,
            # comment
            B,
            # comment
        }"""
        @test fmt(str) == str

        str = """
        foo() = 10 where Foo{
            # comment
            A,
            # comment
            B,
            # comment
        }"""
        @test fmt(str) == str

        str = """
        foo() = Foo(
            # comment
            A,
            # comment
            B,
            # comment
        )"""
        @test fmt(str) == str

        str = """
        foo(
            # comment
            ;
            # comment
            a = b, # comment
            c = d,
            # comment
        )"""
        @test fmt(str) == str

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
        @test fmt(str_) == str

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
        @test fmt(str_) == str

        str_ = """
        foo( ;
            ;a = b, # comment
            c = d,
            # comment
        )"""
        @test fmt(str_) == str

        # str = """
        # [
        #  a b Expr();
        #  d e Expr()
        # ]"""
        # str_ = """
        # [
        # ;
        # ;
        # ;
        #  a b Expr();
        #  ;
        #  d e Expr();
        #  ;
        # ]"""
        # @test fmt(str_) == str

        # Issue #51
        # NOTE: `str_` has extra whitespace after
        # keywords on purpose
        str_ = "begin \n # comment\n end"
        str = """
        begin
          # comment
        end"""
        @test fmt(str_, 2, 92) == str

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
        @test fmt(str_, 6, 92) == str

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
        @test fmt(str_, 6, 92) == str

        str = """a = "hello ##" # # # α"""
        @test fmt(str) == str

        # issue #65
        str = "1 # α"
        @test fmt(str) == str

        str = "# α"
        @test fmt(str) == str

        str = """
        #=
        α
        =#
        x = 1
        """
        @test fmt(str) == str

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
        @test fmt(str_; format_docstrings = true) == str

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
        @test fmt(str) == str

        str = """
        foo = [
            # comment
            1,
            2,
            3,
        ]"""
        @test fmt(str) == str

        # issue 152
        str = """
        try
            ;
        catch
            ;
        end   # comment"""
        str_ = """try; catch;  end   # comment"""
        @test fmt(str_) == str

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
        @test fmt(str_) == str
    end

    @testset "pretty" begin
        str = """function foo end"""
        @test fmt("""
            function  foo
            end""") == str
        t = run_pretty(str, 80)
        @test length(t) == 16

        str = """function foo() end"""
        @test fmt("""
                     function  foo()
            end""") == str
        t = run_pretty(str, 80)
        @test length(t) == 18

        str = """function foo()
                     10;
                     20
                 end"""
        @test fmt("""function foo() 10;  20 end""") == str
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """abstract type AbstractFoo end"""
        @test fmt("""abstract type
                     AbstractFoo
                end""") == str

        str = "primitive type A <: B 32 end"
        @test fmt("""primitive type
                     A   <: B
                     32
                end""") == str

        str = """for i = 1:10
                     1;
                     2;
                     3
                 end"""
        @test fmt("""for i=1:10 1; 2; 3 end""") == str

        str = """while true
                     1;
                     2;
                     3
                 end"""
        @test fmt("""while true 1; 2; 3 end""") == str

        str = """try
                     a
                 catch e
                     b
                 end"""
        @test fmt("""try a catch e b end""") == str

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
        @test fmt("""try a1;a2 catch e b1;b2 finally c1;c2 end""") == str

        str = """map(a) do b, c
                     e
                 end"""
        @test fmt("""map(a) do b,c
                     e end""") == str

        str = """let a=b, c = d
                     e1;
                     e2;
                     e3
                 end"""
        @test fmt("""let a=b,c  =  d  \ne1; e2; e3 end""") == str

        str = """let a, b
                     e
                 end"""
        @test fmt("""let a,b
                     e end""") == str

        str = """return a, b, c"""
        @test fmt("""return a,b,
                     c""") == str

        str = """begin
                     a;
                     b;
                     c
                 end"""
        @test fmt("""begin a; b; c end""") == str

        str = """begin end"""
        @test fmt("""begin \n            end""") == str

        str = """quote
                     a;
                     b;
                     c
                 end"""
        @test fmt("""quote a; b; c end""") == str

        str = """quote end"""
        @test fmt("""quote \n end""") == str

        str = """if cond1
                     e1;
                     e2
                 end"""
        @test fmt("if cond1 e1;e2 end") == str

        str = """if cond1
                     e1;
                     e2
                 else
                     e3;
                     e4
                 end"""
        @test fmt("if cond1 e1;e2 else e3;e4 end") == str

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
        @test fmt(
            "begin if cond1 e1; e2 elseif cond2 e3; e4 elseif cond3 e5;e6 else e7;e8  end end",
        ) == str

        str = """if cond1
                     e1;
                     e2
                 elseif cond2
                     e3;
                     e4
                 end"""
        @test fmt("if cond1 e1;e2 elseif cond2 e3; e4 end") == str

        str = """
        [a b c]"""
        @test fmt("[a   b         c   ]") == str

        str = """
        [a; b; c;]"""
        @test fmt("[a;   b;         c;   ]") == str
        str = """
        [a; b; c]"""
        @test fmt("[a;   b;         c   ]") == str

        str = """
        T[a b c]"""
        @test fmt("T[a   b         c   ]") == str

        str = """T[a; b; c]"""
        @test fmt("T[a;   b;         c   ]") == str
        str = """T[a; b; c;]"""
        @test fmt("T[a;   b;         c;   ]") == str

        str = """
        T[
            a;
            b;
            c;
        ]"""
        @test fmt("T[a;   b;         c;   ]", 4, 1) == str

        str = """
        T[
            a;
            b;
            c
        ]"""
        @test fmt("T[a;   b;         c   ]", 4, 1) == str

        str = """
        T[a; b; c; e d f]"""
        @test fmt("T[a;   b;         c;   e  d    f   ]") == str

        str = """
        T[a; b; c; e d f;]"""
        @test fmt("T[a;   b;         c;   e  d    f;   ]") == str

        str = """
        T[
            a;
            b;
            c;
            e d f
        ]"""
        @test fmt("T[a;   b;         c;   e  d    f   ]", 4, 1) == str

        str = """
        T[
            a;
            b;
            c;
            e d f;
        ]"""
        @test fmt("T[a;   b;         c;   e  d    f;   ]", 4, 1) == str

        str = "T[a;]"
        @test fmt(str) == str

        str = "[a;]"
        @test fmt(str) == str

        str = """T[e for e in x]"""
        @test fmt("T[e  for e= x  ]") == str

        str = """T[e for e = 1:2:50]"""
        @test fmt("T[e  for e= 1:2:50  ]") == str

        str = """struct Foo end"""
        @test fmt("struct Foo\n      end") == str

        str = """
        struct Foo
            body::Any
        end"""
        @test fmt("struct Foo\n    body  end") == str

        str = """macro foo() end"""
        @test fmt("macro foo()\n      end") == str

        str = """macro foo end"""
        @test fmt("macro foo\n      end") == str

        str = """
        macro foo()
            body
        end"""
        @test fmt("macro foo()\n    body  end") == str

        str = """mutable struct Foo end"""
        @test fmt("mutable struct Foo\n      end") == str

        str = """
        mutable struct Foo
            body::Any
        end"""
        @test fmt("mutable struct Foo\n    body  end") == str

        str = """
        module A
        bodybody
        end"""
        @test fmt("module A\n    bodybody  end") == str
        t = run_pretty(str, 80)
        @test length(t) == 8

        str = """
        module Foo end"""
        @test fmt("module Foo\n    end") == str
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """
        baremodule A
        bodybody
        end"""
        @test fmt("baremodule A\n    bodybody  end") == str
        t = run_pretty(str, 80)
        @test length(t) == 12

        str = """
        baremodule Foo end"""
        @test fmt("baremodule Foo\n    end") == str
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
        @test fmt(str) == str

        str = """
        try
        catch
        finally
        end"""
        @test fmt(str) == str

        str = """
        (args...; kwargs) -> begin
            body
        end"""
        @test fmt(str) == str

        @test fmt("ref[a: (b + c)]") == "ref[a:(b+c)]"
        @test fmt("ref[a in b]") == "ref[a in b]"
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
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 17) == str

        str = """
        function f(
            arg1::A,
            key1 = val1;
            key2 = val2,
        ) where {A,F{B,C}}
            10;
            20
        end"""
        @test fmt(str_, 4, 18) == str

        str = """
        a |
        b |
        c |
        d"""
        @test fmt("a | b | c | d", 4, 1) == str

        str = """
        a, b, c, d"""
        @test fmt("a, b, c, d", 4, 10) == str

        str = """
        a,
        b,
        c,
        d"""
        @test fmt("a, b, c, d", 4, 9) == str

        str = """(a, b, c, d)"""
        @test fmt("(a, b, c, d)", 4, 12) == str

        str = """
        (
            a,
            b,
            c,
            d,
        )"""
        @test fmt("(a, b, c, d)", 4, 11) == str

        str = """{a, b, c, d}"""
        @test fmt("{a, b, c, d}", 4, 12) == str

        str = """
        {
            a,
            b,
            c,
            d,
        }"""
        @test fmt("{a, b, c, d}", 4, 11) == str

        str = """[a, b, c, d]"""
        @test fmt("[a, b, c, d]", 4, 12) == str

        str = """
        [
            a,
            b,
            c,
            d,
        ]"""
        @test fmt("[a, b, c, d]", 4, 11) == str

        str = """
        cond ?
        e1 :
        e2"""
        @test fmt("cond ? e1 : e2", 4, 1) == str

        str = """
        cond ? e1 :
        e2"""
        @test fmt("cond ? e1 : e2", 4, 12) == str

        str = """
        cond1 ? e1 :
        cond2 ? e2 :
        cond3 ? e3 :
        e4"""
        @test fmt("cond1 ? e1 : cond2 ? e2 : cond3 ? e3 : e4", 4, 13) == str

        # I'm an importer/exporter
        str = """
        export a,
            b"""
        @test fmt("export a,b", 4, 1) == str

        str = """
        using a,
          b"""
        @test fmt("using a,b", 2, 1) == str

        str_ = "using M1.M2.M3: bar, baz"
        str = """
        using M1.M2.M3:
            bar, baz"""
        @test fmt(str, 4, 24) == str_
        @test fmt(str_, 4, 23) == str
        @test fmt(str_, 4, 12) == str

        str = """
        using M1.M2.M3:
            bar,
            baz"""
        @test fmt(str_, 4, 11) == str

        str_ = "import M1.M2.M3: bar, baz"
        str = """
        import M1.M2.M3:
            bar, baz"""
        @test fmt(str, 4, 25) == str_
        @test fmt(str_, 4, 24) == str
        @test fmt(str_, 4, 12) == str

        str = """
        import M1.M2.M3:
            bar,
            baz"""
        @test fmt(str_, 4, 11) == str

        str_ = """
        using A,

        B, C"""
        str = "using A, B, C"
        @test fmt(str_) == str

        str_ = """
        using A,
                  # comment
        B, C"""
        str = """
        using A,
          # comment
          B,
          C"""
        @test fmt(str_, 2, 80) == str

        str_ = """
        using A,  #inline
                  # comment
        B, C#inline"""
        str = """
        using A,  #inline
          # comment
          B,
          C#inline"""
        @test fmt(str_, 2, 80) == str

        str = """
        @somemacro function (fcall_ | fcall_)
            body_
        end"""
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 37) == str

        str = """
        @somemacro function (
            fcall_ | fcall_
        )
            body_
        end"""
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 36) == str
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 20) == str

        str = """
        @somemacro function (
            fcall_ |
            fcall_
        )
            body_
        end"""
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 19) == str

        str = "Val(x) = (@_pure_meta; Val{x}())"
        @test fmt("Val(x) = (@_pure_meta ; Val{x}())", 4, 80) == str

        # TODO: if this ends up being a issue fix it but it doesn't seem
        # like it actually occurs in the wild.
        str = "(a; b; c)"
        @test fmt("(a;b;c)", 4, 100) == str
        str = """
        (
            a;
            b;
            c
        )"""
        @test fmt("(a;b;c)", 4, 1) == str

        str = "(x for x = 1:10)"
        @test fmt("(x   for x  in  1 : 10)", 4, 100) == str

        str = """
        (
          x for
          x = 1:10
        )"""
        @test fmt("(x   for x  in  1 : 10)", 2, 10) == str

        str = """
        (
          x for
          x =
            1:10
        )"""
        @test fmt("(x   for x  in  1 : 10)", 2, 1) == str

        # indent for TupleN with no parens
        str = """
        function foo()
            arg1,
            arg2
        end"""
        @test fmt("function foo() arg1, arg2 end", 4, 1) == str

        str = """
        function foo()
            # comment
            arg
        end"""
        @test fmt(str, 4, 1) == str

        str = """
        A where {
            B,
        }"""
        str_ = "A where {B}"
        @test fmt(str_) == str_
        @test fmt(str_, 4, 1) == str

        str = """
        foo(
          arg1,
        )"""
        str_ = "foo(arg1)"
        @test fmt(str_) == str_
        @test fmt(str, 2, 1) == str

        str = """
        [
          arg1,
        ]"""
        str_ = "[arg1]"
        @test fmt(str_) == str_
        @test fmt(str, 2, 1) == str

        str = """
        {
          arg1,
        }"""
        str_ = "{arg1}"
        @test fmt(str_) == str_
        @test fmt(str, 2, 1) == str

        str = """
        (
          arg1
        )"""
        str_ = "(arg1)"
        @test fmt(str_) == str_
        @test fmt(str_, 2, 1) == str

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
        @test fmt(str_, 4, 80) == str

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
        @test fmt(str_, 5, 23) == str

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
        @test fmt(str_, 5, 22) == str

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
        @test fmt(str_, 5, 1) == str

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
        @test fmt(str_, 4, 80) == str

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
        @test fmt(str_) == str
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
        @test fmt(str, 4, 1) == str_

        # Ref
        str = "a[1+2]"
        @test fmt("a[1 + 2]", 4, 1) == str

        str = "a[(1+2)]"
        @test fmt("a[(1 + 2)]", 4, 1) == str

        str_ = "(a + b + c + d)"
        @test fmt(str_, 4, length(str_)) == str_

        str = """
        (
          a +
          b +
          c +
          d
        )"""
        @test fmt(str_, 2, length(str_) - 1) == str
        @test fmt(str_, 2, 1) == str

        str_ = "(a <= b <= c <= d)"
        @test fmt(str_, 4, length(str_)) == str_

        str = """
        (
           a <=
           b <=
           c <=
           d
        )"""
        @test fmt(str_, 3, length(str_) - 1) == str
        @test fmt(str_, 3, 1) == str

        # Don't join the first argument in a comparison
        # or chainopcall node, even if possible.
        str_ = "const a = arg1 + arg2 + arg3"
        str = """
        const a =
            arg1 +
            arg2 +
            arg3"""
        @test fmt(str_, 4, 18) == str

        str_ = "const a = arg1 == arg2 == arg3"
        str = """
        const a =
            arg1 ==
            arg2 ==
            arg3"""
        @test fmt(str_, 4, 19) == str

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
        @test fmt(str_) == str

        # any pairing of argument, kawrg, or param should nest
        str = """
        f(
            arg;
            a = 1,
        )"""
        @test fmt("f(arg;a=1)", 4, 1) == str

        str = """
        f(
           arg,
           a = 1,
        )"""
        @test fmt("f(arg,a=1)", 3, 1) == str

        str = """
        f(
         a = 1;
         b = 2,
        )"""
        @test fmt("f(a=1; b=2)", 1, 1) == str

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
        @test fmt(str, 4, 1) == str

        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/453
        str = """
        bar = Dict(
            :foo => \"""A triple quoted literal string
                    with some words in it.\""",
        )
        """
        @test fmt(str, 4, 20) == str
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
        @test fmt(str_, 4, 100) == str

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
        @test fmt(str_, 4, 20) == str

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
        @test fmt(str_, 4, 13) == str
        @test fmt(str, 4, length(str)) == str_

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
        @test fmt(str_, 4, 12) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(a, (b, c), d)"
        str = """
        (
            a,
            (b, c),
            d,
        )"""
        @test fmt(str_, 4, 11) == str
        @test fmt(str, 4, length(str)) == str_

        str = """
        (
            a,
            (
                b,
                c,
            ),
            d,
        )"""
        @test fmt(str_, 4, 10) == str

        str_ = "(a, {b, c}, d)"
        str = """
        (
            a,
            {b, c},
            d,
        )"""
        @test fmt(str_, 4, 12) == str
        @test fmt(str_, 4, 11) == str

        str = """
        (
            a,
            {
                b,
                c,
            },
            d,
        )"""
        @test fmt(str_, 4, 10) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(a, [b, c], d)"
        str = """
        (
            a,
            [b, c],
            d,
        )"""
        @test fmt(str_, 4, 13) == str
        @test fmt(str_, 4, 11) == str

        str = """
        (
            a,
            [
                b,
                c,
            ],
            d,
        )"""
        @test fmt(str_, 4, 10) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "a, (b, c), d"
        str = """
        a,
        (b, c),
        d"""
        @test fmt(str_, 4, length(str_) - 1) == str
        @test fmt(str_, 4, 7) == str

        str = """
        a,
        (
            b,
            c,
        ),
        d"""
        @test fmt(str_, 4, 6) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(var1,var2) && var3"
        str = """
        (var1, var2) &&
            var3"""
        @test fmt(str_, 4, 19) == str
        @test fmt(str_, 4, 15) == str

        str = """
        (
            var1,
            var2,
        ) && var3"""
        @test fmt(str_, 4, 14) == str

        str = """
        (
            var1,
            var2,
        ) &&
            var3"""
        @test fmt(str_, 4, 1) == str

        str_ = "(var1,var2) ? (var3,var4) : var5"
        str = """
        (var1, var2) ?
        (var3, var4) :
        var5"""
        @test fmt(str_, 4, 14) == str

        str = """
        (
            var1,
            var2,
        ) ?
        (
            var3,
            var4,
        ) : var5"""
        @test fmt(str_, 4, 13) == str
        @test fmt(str_, 4, 8) == str

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
        @test fmt(str_, 4, 7) == str

        str = """
        (var1, var2) ? (var3, var4) :
        var5"""
        @test fmt(str_, 4, 29) == str

        str = """
        (var1, var2) ?
        (var3, var4) : var5"""
        @test fmt(str_, 4, 28) == str

        str = """
        f(
            var1::A,
            var2::B,
        ) where {A,B}"""
        @test fmt("f(var1::A, var2::B) where {A,B}", 4, 30) == str

        str = """
        f(
            var1::A,
            var2::B,
        ) where {
            A,
            B,
        }"""
        @test fmt("f(var1::A, var2::B) where {A,B}", 4, 12) == str

        str = "foo(a, b, c)::Rtype where {A,B} = 10"
        str_ = "foo(a, b, c)::Rtype where {A,B,} = 10"
        @test fmt(str, 4, length(str)) == str
        @test fmt(str_, 4, length(str_)) == str

        str_ = """
        foo(a, b, c)::Rtype where {A,B} =
            10"""
        @test fmt(str, 4, 35) == str_
        @test fmt(str, 4, 33) == str_

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {A,B} = 10"""
        @test fmt(str, 4, 32) == str_
        @test fmt(str, 4, 25) == str_

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {A,B} =
            10"""
        @test fmt(str, 4, 24) == str_
        @test fmt(str, 4, 22) == str_

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {
            A,
            B,
        } = 10"""
        @test fmt(str, 4, 21) == str_

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
        @test fmt(str, 2, 1) == str_

        str_ = """
        foo(
              a,
              b,
              c,
        )::Rtype where {
              A,
              B,
        } = 10"""
        @test fmt(str, 6, 18) == str_

        str = "keytype(::Type{<:AbstractDict{K,V}}) where {K,V} = K"
        @test fmt(str, 4, 52) == str

        str_ = "transcode(::Type{THISISONESUPERLONGTYPE1234567}) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"

        str = """
        transcode(
          ::Type{THISISONESUPERLONGTYPE1234567},
        ) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 80) == str
        @test fmt(str_, 2, 68) == str

        str = """
        transcode(
          ::Type{THISISONESUPERLONGTYPE1234567},
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 67) == str
        @test fmt(str_, 2, 40) == str

        str = """
        transcode(
          ::Type{
            THISISONESUPERLONGTYPE1234567,
          },
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 39) == str

        str_ = "transcode(::Type{T}, src::AbstractVector{UInt8}) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"
        str = """
        transcode(
          ::Type{T},
          src::AbstractVector{UInt8},
        ) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 80) == str
        @test fmt(str_, 2, 68) == str

        str = """
        transcode(
          ::Type{T},
          src::AbstractVector{UInt8},
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 67) == str

        # issue 56
        str_ = "a_long_function_name(Array{Float64,2}[[1.0], [0.5 0.5], [0.5 0.5; 0.5 0.5], [0.5 0.5; 0.5 0.5]])"
        str = """
        a_long_function_name(
            Array{Float64,2}[[1.0], [0.5 0.5], [0.5 0.5; 0.5 0.5], [0.5 0.5; 0.5 0.5]],
        )"""
        @test fmt(str, 4, length(str)) == str_
        @test fmt(str_, 4, length(str_) - 1) == str
        @test fmt(str_, 4, 79) == str

        str = """
        a_long_function_name(
            Array{Float64,2}[
                [1.0],
                [0.5 0.5],
                [0.5 0.5; 0.5 0.5],
                [0.5 0.5; 0.5 0.5],
            ],
        )"""
        @test fmt(str_, 4, 78) == str

        # unary op
        str_ = "[1, 1]'"
        str = """
        [
          1,
          1,
        ]'"""
        @test fmt(str, 2, length(str)) == str_
        @test fmt(str_, 2, length(str_) - 1) == str
    end

    @testset "Trailing zeros" begin
        @test fmt("1.") == "1.0"
        @test fmt("a * 1. + b") == "a * 1.0 + b"
        @test fmt("1. + 2. * im") == "1.0 + 2.0 * im"
        @test fmt("[1., 2.]") == "[1.0, 2.0]"
        @test fmt("""
        1. +
            2.
        """) == "1.0 + 2.0\n"
    end

    @testset "Leading zeros" begin
        @test fmt(".1") == "0.1"
        @test fmt("a * .1 + b") == "a * 0.1 + b"
        @test fmt(".1 + .2 * im") == "0.1 + 0.2 * im"
        @test fmt("[.1, .2]") == "[0.1, 0.2]"
        @test fmt("""
        .1 +
            .2
        """) == "0.1 + 0.2\n"
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
        @test fmt(str_, 2, 92) == str

        str_ = """
        T[ a b Expr()
        d e Expr()]"""
        str = """
        T[
            a b Expr()
            d e Expr()
        ]"""
        @test fmt(str_) == str

        str_ = """
        [ a b Expr();
        d e Expr();]"""
        str = """
        [
           a b Expr();
           d e Expr();
        ]"""
        @test fmt(str_, 3, 92) == str
        str_ = "[a b Expr(); d e Expr()]"
        @test fmt(str_) == str_
        str = """
        [
           a b Expr();
           d e Expr()
        ]"""
        @test fmt(str_, 3, 1) == str

        str_ = """
        T[ a b Expr();
        d e Expr();]"""
        str = """
        T[
            a b Expr();
            d e Expr();
        ]"""
        @test fmt(str_) == str

        str_ = "T[a b Expr(); d e Expr()]"
        @test fmt(str_) == str_
        str = """
        T[
            a b Expr();
            d e Expr()
        ]"""
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str, 2, 92) == str
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
        @test fmt(str_) == str

        str_ = """
        for a in
            x,
            b in
            y,
            c in
            z

            body
        end"""
        @test fmt(str, 4, 1) == str_
        @test fmt(str_) == str

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
        @test fmt(str_) == str

        str_ = """
        let a = x,
            b = y,
            c = z

            body
        end"""
        @test fmt(str_) == str

        str_ = """
        let a =
                x,
            b =
                y,
            c =
                z

            body
        end"""
        @test fmt(str, 4, 1) == str_

        str = """
        let
            # comment
            list = [1, 2, 3]

            body
        end"""
        @test fmt(str) == str

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
        @test fmt(str_) == str
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

        @test fmt(str_, 4, 80) == str

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
        @test fmt("@func(a, b, c)", 4, 1) == str

        str = """
        @func(
            a,
            b,
            c,
        )"""
        @test fmt("@func(a, b, c,)", 4, 1) == str
    end

    @testset "comprehension types" begin
        str_ = "var = ((x, y) for x = 1:10, y = 1:10)"
        str = """
        var =
            ((x, y) for x = 1:10, y = 1:10)"""
        @test fmt(str_, 4, length(str_) - 1) == str
        @test fmt(str_, 4, 35) == str

        str = """
        var = (
            (x, y) for x = 1:10, y = 1:10
        )"""
        @test fmt(str_, 4, 34) == str

        str = """
        var = (
            (x, y) for
            x = 1:10, y = 1:10
        )"""
        @test fmt(str_, 4, 30) == str

        str = """
        var = (
            (x, y) for
            x = 1:10,
            y = 1:10
        )"""
        @test fmt(str_, 4, 20) == str

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
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 90) == str

        str = """
        begin
            weights = Dict(
                (file, i) => w for (file, subject) in subjects
                for (i, w) in
                enumerate(weightfn.(eachrow(subject.events)))
            )
        end"""
        @test fmt(str_, 4, 60) == str

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
        @test fmt(str_, 4, 50) == str

        str_ = "(b for b in bar if b == 0 for bar in foo)"
        @test format_text(str_) == str_
        @test fmt(str_) == str_

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
        @test fmt(str_, 4, 1) == str
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
        @test fmt(str) == str

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
        @test fmt(str_) == str

        str = """
        if ((
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        ))
          nothing
        end"""
        @test fmt(str, 2, 92) == str

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
        @test fmt(str, 8, 92) == str

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
        @test fmt(str_, 4, 24) == str

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
        @test fmt(str_, 4, 23) == str

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
        @test fmt(str_, 4, 15) == str

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
        @test fmt(str_, 4, 14) == str
        @test fmt(str_, 4, 10) == str

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
        @test fmt(str_, 4, 9) == str
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 80) == str
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
        @test fmt(str, 4, 92) == str

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
        @test fmt(str, 4, 90) == str

        str = """
        ys = map(xs) do x
            return (
                very_very_very_very_very_very_very_very_very_very_very_long_expr,
                very_very_very_very_very_very_very_very_very_very_very_long_expr,
            )
        end"""
        @test fmt(str) == str
    end

    @testset "remove excess newlines" begin
        str_ = """
        var = foo(a,

        b,     c,





        d)"""
        str = "var = foo(a, b, c, d)"
        @test fmt(str_) == str

        str = """
        var =
            foo(
                a,
                b,
                c,
                d,
            )"""
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_) == str

        str = """
        var = foo(
            a,
            b,
            c,

            # comment !!!

            d,
        )"""
        @test fmt(str_; remove_extra_newlines = true) == str

        str_ = """
        var =

            func(a,

            b,

            c)"""
        str = """var = func(a, b, c)"""
        @test fmt(str_) == str
        @test fmt(str_; remove_extra_newlines = true) == str

        str_ = """
        var =

            a &&


        b &&
        c"""
        str = """var = a && b && c"""
        @test fmt(str_) == str
        @test fmt(str_; remove_extra_newlines = true) == str

        str_ = """
        var =

            a ?


        b :



        c"""
        str = """var = a ? b : c"""
        @test fmt(str_) == str
        @test fmt(str_; remove_extra_newlines = true) == str

        str_ = """
        var =

            a +


        b +



        c"""
        str = """var = a + b + c"""
        @test fmt(str_) == str
        @test fmt(str_; remove_extra_newlines = true) == str

        str_ = """
        var =

            a   ==


        b   ==



        c"""
        str = """var = a == b == c"""
        @test fmt(str_) == str
        @test fmt(str_; remove_extra_newlines = true) == str
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
        @test fmt(str_) == str

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
        @test fmt(str_) == str

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
        @test fmt(str_; m = 74) == str
        @test fmt(str; m = 75) == str_

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
        @test fmt(str_; m = 43) == str

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
        @test fmt(str_; m = 42) == str
    end

    @testset "standalone lazy expr indent" begin
        str = """
        begin
          a &&
            b
          a ||
            b
        end"""
        @test fmt(str, 2, 1) == str

        str_ = """
        begin
         a && b || c && d
        end"""

        str = """
        begin
            a && b ||
                c && d
        end"""
        @test fmt(str_, 4, 19) == str

        str = """
        begin
            a && b ||
                c &&
                d
        end"""
        @test fmt(str_, 4, 13) == str

        str = """
        begin
            a &&
            b ||
                c &&
                d
        end"""
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 19) == str

        str = """
        begin
            a ||
                b &&
                c ||
                d
        end"""
        @test fmt(str_, 4, 16) == str

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
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 1) == str

        str_ = """var = a && b"""
        str = """
        var =
            a &&
            b"""
        @test fmt(str_, 4, 1) == str

        str_ = """var() = a && b"""
        str = """
        var() =
            a &&
            b"""
        @test fmt(str_, 4, 1) == str

        str_ = """var = a || b || c"""
        str = """
        var =
            a ||
            b ||
            c"""
        @test fmt(str_, 4, 1) == str

        str_ = """var() = a || b || c"""
        str = """
        var() =
            a ||
            b ||
            c"""
        @test fmt(str_, 4, 1) == str

        str_ = """
        @hello arg1 && arg2 && return arg3"""
        str = """
        @hello arg1 &&
               arg2 &&
               return arg3"""
        @test fmt(str_, 4, 1) == str

        str_ = """
        @hello arg1 || return arg2"""
        str = """
        @hello arg1 ||
               return arg2"""
        @test fmt(str_, 4, 1) == str

        str_ = """
        return arg1 || arg2"""
        str = """
        return arg1 ||
               arg2"""
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 80) == str
    end

    @testset "source file line offset with unicode" begin
        # These just check to see formatting runs without error

        str = """
        a = 10
        # └─ code.jl (before -> after2)
        v = "test_basic_config"
        """
        @test fmt(str) == str

        str = """
        a = 10
        unicode_str = "α10′"
        v = "test_basic_config"
        """
        @test fmt(str) == str

        str = """
        a = 10
        unicode_op = 5 ⪅ 10.0
        v = "test_basic_config"
        """
        @test fmt(str) == str

        str = """
        a = 10
        unicode_identifier′ = 10
        v = "test_basic_config"
        """
        @test fmt(str) == str

        str = "const FOO = ['😢']"
        @test fmt(str) == str

        str = "const FOO = '😢'"
        @test fmt(str) == str
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
        @test fmt(str_, 4, 78) == str
    end

    @testset "operators as arguments" begin
        str_ = "a    .*     %"
        str = "a .* %"
        @test fmt(str_, 4, 100) == str

        str_ = "a    *     %"
        str = "a * %"
        @test fmt(str_, 4, 100) == str

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
        @test fmt(s1, 8, 1) == s2

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
        @test fmt(str_, 4, 1) == str
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
        @test fmt(s, 4, 100) == s

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
        @test fmt(s, 4, 100) == s
    end

    @testset "no args before kwargs ; placement" begin
        str_ = """(; a = b, c = d)"""
        str = """
        (;
            a = b,
            c = d,
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = """(;  # inline
            a = b, c = d)"""
        str = """
        (;  # inline
            a = b,
            c = d,
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = """(;
            # comment
            a = b, c = d)"""
        str = """
        (;
            # comment
            a = b,
            c = d,
        )"""
        @test fmt(str_, 4, 1) == str

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
        @test fmt(str_, 4, 1) == str

        str_ = """(arg; # inline
            a = b, c = d)"""
        str = """
        (
            arg; # inline
            a = b,
            c = d,
        )"""
        @test fmt(str_, 4, 1) == str

        str_ = """(arg;
            a = b, c = d)"""
        str = """
        (
            arg;
            a = b,
            c = d,
        )"""
        @test fmt(str_, 4, 1) == str
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
        @test fmt(str_, 4, 1) == str
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
        @test fmt(str_, 4, 27) == str
        @test fmt(str, 4, 27; join_lines_based_on_source = true) == str
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
        @test fmt(str_, 4, 16; join_lines_based_on_source = true) == str_
        @test fmt(str_, 4, 15; join_lines_based_on_source = true) == str
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
            @test fmt(str_, 4, 14) == str
            str = """
            public a,
                b,
                c
            """
            @test fmt(str_, 4, 1) == str
        end
    end
end
