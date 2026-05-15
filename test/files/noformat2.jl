#! format: off
using JuliaFormatter
using CSTParser
using Test

fmt1(s, i, m, always_for_in) = JuliaFormatter.format_text(s, indent = i, margin = m, always_for_in = always_for_in)

# Verifies formatting the formatted text
# results in the same output
function fmt(s; i = 4, m = 80, 
             always_for_in = false)
    s1 = fmt1(s, i, m, always_for_in)
    fmt1(s1, i, m, always_for_in)
end
fmt(s, i, m) = fmt(s; i = i, m = m)
fmt1(s, i, m) = fmt1(s; i = i, m = m)

function run_pretty(text::String, print_width::Int)
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, 4, print_width)
    x = CSTParser.parse(text, true)
    t = JuliaFormatter.pretty(x, s)
    t
end

function run_nest(text::String, print_width::Int)
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, 4, print_width)
    x = CSTParser.parse(text, true)
    t = JuliaFormatter.pretty(x, s)
    JuliaFormatter.nest!(t, s)
    s
end

@testset "All" begin

    @testset "basic" begin
        @test fmt("") == ""
        @test fmt("a") == "a"
        @test fmt("a  #foo") == "a  #foo"
        @test fmt("#foo") == "#foo"

        str = """
        #=
        Hello, world!
        =#"""
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
        b = 10*20

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
    end

    @testset "toplevel" begin
        str = """

        hello = "string";

        a = 10;


        c = 50;

        #comment"""
        str_ = """

        hello = "string";

        a = 10
        ;


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
        @test fmt(str) == str

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

        str = """
        for i = 1:30, j = 100:-2:1
            println(i, j)
        end"""
        str_ = """
        for i = 1:30, j in 100:-2:1
            println(i, j)
        end"""
        @test fmt(str) == str

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

    @testset "always eq to in" begin
        str_ = """
        for i = 1:n
            println(i)
        end"""
        str = """
        for i in 1:n
            println(i)
        end"""
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = """
        for i = I1, j in I2
            println(i, j)
        end"""
        str = """
        for i in I1, j in I2
            println(i, j)
        end"""
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = """
        for i = 1:30, j = 100:-2:1
            println(i, j)
        end"""
        str = """
        for i in 1:30, j in 100:-2:1
            println(i, j)
        end"""
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = "[(i,j) for i=I1,j=I2]"
        str = "[(i, j) for i in I1, j in I2]"
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = "((i,j) for i=I1,j=I2)"
        str = "((i, j) for i in I1, j in I2)"
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = "[(i, j) for i = 1:2:10, j = 100:-1:10]"
        str = "[(i, j) for i in 1:2:10, j in 100:-1:10]"
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str
    end

    @testset "tuples" begin
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
        @test fmt("! x") == "!x"
        @test fmt("x ...") == "x..."
    end

    @testset "binary ops" begin
        @test fmt("a+b*c") == "a + b * c"
        @test fmt("a +b*c") == "a + b * c"
        @test fmt("a+ b*c") == "a + b * c"
        @test fmt("a+b *c") == "a + b * c"
        @test fmt("a+b* c") == "a + b * c"
        @test fmt("a+b*c ") == "a + b * c"
        @test fmt("a:b") == "a:b"
        @test fmt("a : b") == "a:b"
        @test fmt("a: b") == "a:b"
        @test fmt("a :b") == "a:b"
        @test fmt("a +1 :b -1") == "a+1:b-1"
        @test fmt("a:b:c") == "a:b:c"
        @test fmt("a :b:c") == "a:b:c"
        @test fmt("a: b:c") == "a:b:c"
        @test fmt("a:b :c") == "a:b:c"
        @test fmt("a:b: c") == "a:b:c"
        @test fmt("a:b:c ") == "a:b:c"
        @test fmt("a::b:: c") == "a::b::c"
        @test fmt("a :: b::c") == "a::b::c"
        # issue #74
        @test fmt("0:1/3:2") == "0:1/3:2"
        @test fmt("2a") == "2a"
        @test fmt("2(a+1)") == "2 * (a + 1)"

        str_ = "a[1:2 * num_source * num_dump-1]"
        str = "a[1:2*num_source*num_dump-1]"
        @test fmt(str_, 4, 1) == str

        str_ = "a[2 * num_source * num_dump-1:1]"
        str = "a[2*num_source*num_dump-1:1]"
        @test fmt(str_, 4, 1) == str

        str = "!(typ <: ArithmeticTypes)"
        @test fmt(str) == str

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
        @test fmt(str_) == str_
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
        @test fmt(str_) == str_
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

        str_ = """foo() = let var1=value1,var2,var3=value3 body end"""
        str = """
        foo() =
            let var1 = value1, var2, var3 = value3
                body
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
        @test fmt(str_, 2, 1) == str

        str_ = """foo = quote body end"""
        str = """
        foo = quote
          body
        end"""
        @test fmt(str_, 2, 1) == str

        str_ = """foo = for i=1:10 body end"""
        str = """
        foo =
          for i = 1:10
            body
          end"""
        @test fmt(str_, 2, 1) == str

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

        str_ = """foo = let var1=value1,var2,var3=value3 body end"""
        str = """
        foo =
          let var1 = value1, var2, var3 = value3
            body
          end"""
        @test fmt(str_, 2, 1) == str

        str = """
        foo = let
          body
        end"""
        @test fmt(str, 2, 1) == str

        str_ = """a, b = cond ? e1 : e2"""
        str = """
        a, b = cond ?
               e1 :
               e2"""
        @test fmt(str_, 4, 13) == str

        str = """
        a,
        b = cond ?
            e1 : e2"""
        @test fmt(str_, 4, 12) == str
    end

    @testset "op chain" begin
        @test fmt("a+b+c+d") == "a + b + c + d"
    end

    @testset "comparison chain" begin
        @test fmt("a<b==c≥d") == "a < b == c ≥ d"
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
        @test fmt("func(; c = 1)", 4, 1) == "func(; c = 1)"
        @test fmt("func(; c = 1,)") == "func(; c = 1)"
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
            x + y + foo + bar + ba
            x + y + foo + bar +
            baz
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 27
        @test fmt(str, 4, 26) == str

        # issue #58

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
        for i = 1:10
            body
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 12

        str = """
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
        let x = X
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

        # TODO: This should probably be aligned to match up with `a` ?
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

    @testset "structs" begin
        str = """
        struct name
            arg
        end"""
        @test fmt("""
        struct name
            arg
        end""") == str
        @test fmt("""
        struct name
        arg
        end""") == str
        @test fmt("""
        struct name
                arg
            end""") == str


        str = """
        mutable struct name
            arg
        end"""
        @test fmt("""
        mutable struct name
            arg
        end""") == str
        @test fmt("""
        mutable struct name
        arg
        end""") == str
        @test fmt("""
        mutable struct name
                arg
            end""") == str
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

    @testset "docs" begin
        str = """
        \"""
        doc
        \"""
        function f()
            20
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 12

        str = """
        \"""doc
        \"""
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        \"""
        doc\"""
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        \"""doc\"""
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        "doc
        "
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        "
        doc"
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        "doc"
        function f()
            20
        end"""
        @test fmt(str) == str

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
        @test fmt(str_) == str

        str = """\"""
                 doc for Foo
                 \"""
                 Foo"""
        @test fmt(str) == str
        t = run_pretty(str, 80)
        @test length(t) == 11

        str = """
        \"""
        doc
        \"""
        function f()    #  comment
            20
        end"""
        @test fmt(str) == str
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


        str = """
        begin
            begin
                throw(ErrorException(\"""An error occured formatting \$filename. :-(

                                     Please file an issue at https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues
                                     with a link to a gist containing the contents of the file. A gist
                                     can be created at https://gist.github.com/.\"""))
            end
        end"""
        str_ = """
        begin
        begin
           throw(ErrorException(\"""An error occured formatting \$filename. :-(

                                Please file an issue at https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues
                                with a link to a gist containing the contents of the file. A gist
                                can be created at https://gist.github.com/.\"""))
           end
        end"""
        @test fmt(str_) == str


        str = """
        foo() = llvmcall(\"""
                         llvm1
                         llvm2
                         \""")"""
        @test fmt(str) == str

        str_ = """
        foo() =
          llvmcall(\"""
                   llvm1
                   llvm2
                   \""")"""
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

        str = """
        A ? # foo
        # comment 1

        B : C"""
        @test fmt(str) == str

        str = """
        begin
            var = a +
                # comment
                  b
        end
        """
        @test fmt(str) == str

        str = """
        begin
            var = a +  # inline
            # comment

                  b
        end
        """
        @test fmt(str) == str

        str = """
        begin
            var = a +  # inline
                  b
        end
        """
        @test fmt(str) == str

        str_ = """
        foo() = 10 where {
            # comment
            A,
                # comment
            B
            # comment
        }"""
        str = """
        foo() = 10 where {
            # comment
            A,
                # comment
            B,
            # comment
        }"""
        @test fmt(str_) == str

        str_ = """
        foo() = 10 where Foo{
            # comment
            A,
                # comment
            B
            # comment
        }"""
        str = """
        foo() = 10 where Foo{
            # comment
            A,
                # comment
            B,
            # comment
        }"""
        @test fmt(str_) == str

        str_ = """
        foo() = Foo(
            # comment
            A,
                # comment
            B
            # comment
        )"""
        str = """
        foo() = Foo(
            # comment
            A,
                # comment
            B,
            # comment
        )"""
        @test fmt(str_) == str

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
        foo(
            ;
            a = b, # comment
            c = d,
            # comment
        )"""
        @test fmt(str) == str

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
        #

        # Issue #51
        # NOTE: `str_` has extra whitespace after
        # keywords on purpose
        str_ = "begin \n # comment\n end"
        str = """
        begin
         # comment
        end"""
        @test fmt(str_) == str

        str_ = "try \n # comment\n catch \n # comment\n finally \n # comment\n end"
        str = """
        try
         # comment
        catch
         # comment
        finally
         # comment
        end"""
        @test fmt(str_) == str

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
                     10
                     20
                 end"""
        @test fmt("""function foo() 10;  20 end""") == str
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """abstract type AbstractFoo end"""
        @test fmt("""abstract type
                     AbstractFoo
                end""") == str

        str = """for i = 1:10
                     1
                     2
                     3
                 end"""
        @test fmt("""for i=1:10 1; 2; 3 end""") == str

        str = """while true
                     1
                     2
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
                     a1
                     a2
                 catch e
                     b1
                     b2
                 finally
                     c1
                     c2
                 end"""
        @test fmt("""try a1;a2 catch e b1;b2 finally c1;c2 end""") == str

        str = """map(a) do b, c
                     e
                 end"""
        @test fmt("""map(a) do b,c
                     e end""") == str

        str = """let a = b, c = d
                     e1
                     e2
                     e3
                 end"""
        @test fmt("""let a=b,c=d\ne1; e2; e3 end""") == str

        str = """let a, b
                     e
                 end"""
        @test fmt("""let a,b
                     e end""") == str

        str = """return a, b, c"""
        @test fmt("""return a,b,
                     c""") == str

        str = """begin
                     a
                     b
                     c
                 end"""
        @test fmt("""begin a; b; c end""") == str

        str = """begin end"""
        @test fmt("""begin \n            end""") == str

        str = """quote
                     a
                     b
                     c
                 end"""
        @test fmt("""quote a; b; c end""") == str

        str = """quote end"""
        @test fmt("""quote \n end""") == str

        str = """if cond1
                     e1
                     e2
                 end"""
        @test fmt("if cond1 e1;e2 end") == str

        str = """if cond1
                     e1
                     e2
                 else
                     e3
                     e4
                 end"""
        @test fmt("if cond1 e1;e2 else e3;e4 end") == str

        str = """begin
                     if cond1
                         e1
                         e2
                     elseif cond2
                         e3
                         e4
                     elseif cond3
                         e5
                         e6
                     else
                         e7
                         e8
                     end
                 end"""
        @test fmt("begin if cond1 e1; e2 elseif cond2 e3; e4 elseif cond3 e5;e6 else e7;e8  end end") == str

        str = """if cond1
                     e1
                     e2
                 elseif cond2
                     e3
                     e4
                 end"""
        @test fmt("if cond1 e1;e2 elseif cond2 e3; e4 end") == str

        str = """
        [a b c]"""
        @test fmt("[a   b         c   ]") == str

        str = """
        [a; b; c]"""
        @test fmt("[a;   b;         c;   ]") == str

        str = """
        T[a b c]"""
        @test fmt("T[a   b         c   ]") == str

        str = """
        T[a; b; c]"""
        @test fmt("T[a;   b;         c;   ]") == str

        str = """
        T[a; b; c; e d f]"""
        @test fmt("T[a;   b;         c;   e  d    f   ]") == str

        str = """
        T[a; b; c; e d f]"""
        @test fmt("T[a;   b;         c;   e  d    f    ;   ]") == str

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
            body
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
            body
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
            10
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
            10
            20
        end"""
        @test fmt(str_, 4, 17) == str

        str = """
        function f(
            arg1::A,
            key1 = val1;
            key2 = val2,
        ) where {A,F{B,C}}
            10
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

        str = """a,\nb,\nc,\nd"""
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
        @test fmt("using a,b", 4, 1) == str

        str = """
        using M: a,
                 b"""
        @test fmt("using M:a,b", 4, 1) == str

        str = """
        import M1.M2.M3: a,
                         b"""
        @test fmt("import M1.M2.M3:a,b", 4, 1) == str

        str = """
        foo() =
            (one, x -> (true, false))"""
        @test fmt("foo() = (one, x -> (true, false))", 4, 30) == str

        str = """
        foo() = (
            one,
            x -> (
                true,
                false,
            ),
        )"""
        @test fmt("foo() = (one, x -> (true, false))", 4, 20) == str

        str = """
        foo() = (
                 one,
                 x -> (
                       true,
                       false,
                 ),
        )"""
        @test fmt("foo() = (one, x -> (true, false))", 10, 20) == str

        str = """
        @somemacro function (fcall_ | fcall_)
            body_
        end"""
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 37) == str

        str = """
        @somemacro function (fcall_ |
                             fcall_)
            body_
        end"""
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 36) == str

        str = "Val(x) = (@_pure_meta; Val{x}())"
        @test fmt("Val(x) = (@_pure_meta ; Val{x}())", 4, 80) == str

        str = "(a; b; c)"
        @test fmt("(a;b;c)", 4, 100) == str
        @test fmt("(a;b;c)", 4, 1) == str

        str = "(x for x = 1:10)"
        @test fmt("(x   for x  in  1 : 10)", 4, 100) == str
        @test fmt("(x   for x  in  1 : 10)", 4, 1) == str

        # indent for TupleH with no parens
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

        # don't nest < 2 args

        str = "A where {B}"
        @test fmt(str, 4, 1) == str

        str = "foo(arg1)"
        @test fmt(str, 4, 1) == str

        str = "[arg1]"
        @test fmt(str, 4, 1) == str

        str = "{arg1}"
        @test fmt(str, 4, 1) == str

        str = "(arg1)"
        @test fmt(str, 4, 1) == str

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
            elseif (a ||
                    b) && c
            elseif bar
            else
            end
        end"""
        @test fmt(str_, 4, 21) == str
        @test fmt(str_, 4, 19) == str

        str = """
        begin
            if foo
            elseif baz
            elseif (a ||
                    b) &&
                   c
            elseif bar
            else
            end
        end"""
        @test fmt(str_, 4, 18) == str

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
        @test fmt(str_, 4, 22) == str

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

        str = """this_is_a_long_variable_name = Dict{
             Symbol,
             Any,
        }(
             :numberofpointattributes => NAttributes,
             :numberofpointmtrs => NMTr,
             :numberofcorners => NSimplex,
             :firstnumber => Cint(1),
             :mesh_dim => Cint(3),
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
        begin
            a && b
            a || b
        end"""
        @test fmt(str, 4, 1) == str

        str = """
        begin
            a &&
            b ||
            c &&
            d
        end"""
        @test fmt("begin\n a && b || c && d\nend", 4, 1) == str

        str = """
        func(a, \"""this
                is another
                multi-line
                string.
                Longest line
                \""", foo(b, c))"""
        @test fmt(str, 4, 100) == str

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
        @test fmt(str, 4, 31) == str


        # Ref
        str = "a[1+2]"
        @test fmt("a[1 + 2]", 4, 1) == str

        str = "a[(1+2)]"
        @test fmt("a[(1 + 2)]", 4, 1) == str

        str_ = "(a + b + c + d)"
        @test fmt(str_, 4, 15) == str_

        str = "(a + b + c +\n d)"
        @test fmt(str_, 4, 14) == str
        @test fmt(str_, 4, 12) == str

        str = "(a + b +\n c + d)"
        @test fmt(str_, 4, 11) == str
        @test fmt(str_, 4, 8) == str

        str = "(a +\n b +\n c + d)"
        @test fmt(str_, 4, 7) == str

        str = "(a +\n b +\n c +\n d)"
        @test fmt(str_, 4, 1) == str

        str_ = "(a <= b <= c <= d)"
        @test fmt(str_, 4, 18) == str_

        str = "(a <= b <= c <=\n d)"
        @test fmt(str_, 4, 17) == str
        @test fmt(str_, 4, 15) == str

        str = "(a <= b <=\n c <= d)"
        @test fmt(str_, 4, 14) == str
        @test fmt(str_, 4, 10) == str

        str = "(a <=\n b <=\n c <= d)"
        @test fmt(str_, 4, 9) == str
        @test fmt(str_, 4, 8) == str

        str = "(a <=\n b <=\n c <=\n d)"
        @test fmt(str_, 4, 7) == str
        @test fmt(str_, 4, 1) == str

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

        # single function kwarg or param should not nest
        @test fmt("f(;a=1)", 4, 1) == "f(; a = 1)"
        @test fmt("f(a=1)", 4, 1) == "f(a = 1)"

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
        @test fmt("f(arg,a=1)", 4, 1) == str

        str = """
        f(
          a = 1;
          b = 2,
        )"""
        @test fmt("f(a=1; b=2)", 4, 1) == str
    end

    @testset "nesting line offset" begin
        str = "a - b + c * d"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 5
        s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "c ? e1 : e2"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 2
        s = run_nest(str, 8)
        @test s.line_offset == 2
        s = run_nest(str, 1)
        @test s.line_offset == 2

        str = "c1 ? e1 : c2 ? e2 : c3 ? e3 : c4 ? e4 : e5"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 32
        s = run_nest(str, 30)
        @test s.line_offset == 22
        s = run_nest(str, 20)
        @test s.line_offset == 12
        s = run_nest(str, 10)
        @test s.line_offset == 2
        s = run_nest(str, 1)
        @test s.line_offset == 2

        str = "f(a, b, c) where {A,B,C}"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 15
        s = run_nest(str, 14)
        @test s.line_offset == 1
        s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where Union{A,B,C}"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 20
        s = run_nest(str, 19)
        @test s.line_offset == 1
        s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where {A}"
        s = run_nest(str, 100)
        # adds surrounding {...} after `where`
        @test s.line_offset == length(str)
        s = run_nest(str, 1)
        @test s.line_offset == 11

        str = "f(a, b, c) where {A<:S}"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, 1)
        @test s.line_offset == 14

        str = "f(a, b, c) where Union{A,B,Union{C,D,E}}"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 31
        s = run_nest(str, 30)
        @test s.line_offset == 1
        s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where {A,{B, C, D},E}"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "(a, b, c, d)"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 1

        str = "a, b, c, d"
        s = run_nest(str, 100)
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 1

        str = """
        splitvar(arg) =
            @match arg begin
                ::T_ => (nothing, T)
                name_::T_ => (name, T)
                x_ => (x, :Any)
            end"""
        s = run_nest(str, 96)
        @test s.line_offset == 3
        s = run_nest(str, 1)
        @test s.line_offset == 7

        str = "prettify(ex; lines = false) = ex |> (lines ? identity : striplines) |> flatten |> unresolve |> resyntax |> alias_gensyms"
        s = run_nest(str, 80)
        @test s.line_offset == 17

        str = "foo() = a + b"
        s = run_nest(str, length(str))
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 9
        s = run_nest(str, 1)
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
            end,
        )"""
        @test fmt(str_, 4, 20) == str


        str = "export @esc, isexpr, isline, iscall, rmlines, unblock, block, inexpr, namify, isdef"
        s = run_nest(str, length(str))
        @test s.line_offset == length(str)
        s = run_nest(str, length(str) - 1)
        @test s.line_offset == 12

        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/9#issuecomment-481607068
        str = """this_is_a_long_variable_name = Dict{Symbol,Any}(:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        s = run_nest(str, 80)
        @test s.line_offset == 1

        str = """this_is_a_long_variable_name = (:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        s = run_nest(str, 80)
        @test s.line_offset == 1
    end

    @testset "additional length" begin
        str_ = "f(a, @g(b, c), d)"
        str = """
        f(
          a,
          @g(b, c),
          d,
        )"""
        @test fmt(str_, 4, 11) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "f(a, @g(b, c), d)"
        str = """
        f(
          a,
          @g(
             b,
             c,
          ),
          d,
        )"""
        @test fmt(str_, 4, 10) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(a, (b, c), d)"
        str = """
        (
         a,
         (
          b,
          c,
         ),
         d,
        )"""
        @test fmt(str_, 4, 7) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(a, {b, c}, d)"
        str = """
        (
         a,
         {
          b,
          c,
         },
         d,
        )"""
        @test fmt(str_, 4, 6) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(a, [b, c], d)"
        str = """
        (
         a,
         [
          b,
          c,
         ],
         d,
        )"""
        @test fmt(str_, 4, 6) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "a, (b, c), d"
        str = """
        a,
        (
         b,
         c,
        ),
        d"""
        @test fmt(str_, 4, 6) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "a, (b, c), d"
        str = """
        a,
        (b, c),
        d"""
        @test fmt(str_, 4, 7) == str
        @test fmt(str, 4, length(str)) == str_

        str = """
        (
         var1,
         var2,
        ) && var3"""
        @test fmt("(var1,var2) && var3", 4, 10) == str

        str = """
        (
         var1,
         var2,
        ) && var3"""
        @test fmt("(var1,var2) && var3", 4, 19) == str

        str = """
        (var1, var2) ?
        (var3, var4) :
        var5"""
        @test fmt("(var1,var2) ? (var3,var4) : var5", 4, 14) == str

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
        @test fmt("(var1,var2) ? (var3,var4) : var5", 4, 13) == str

        str = """
        (var1, var2) ? (var3, var4) :
        var5"""
        @test fmt("(var1,var2) ? (var3,var4) : var5", 4, 29) == str

        str = """
        (var1, var2) ?
        (var3, var4) : var5"""
        @test fmt("(var1,var2) ? (var3,var4) : var5", 4, 28) == str

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
        foo(a, b, c)::Rtype where {
            A,
            B,
        } = 10"""
        @test fmt(str, 4, 32) == str_
        @test fmt(str, 4, 19) == str_

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {
            A,
            B,
        } = 10"""
        @test fmt(str, 4, 18) == str_

        str = "keytype(::Type{<:AbstractDict{K,V}}) where {K,V} = K"
        @test fmt(str, 4, 52) == str

        str_ = "transcode(::Type{THISISONESUPERLONGTYPE1234567}) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"
        str = """
        transcode(::Type{THISISONESUPERLONGTYPE1234567}) where {T<:Union{
          Int32,
          UInt32,
        }} = transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 80) == str
        @test fmt(str_, 2, 38) == str

        str = """
        transcode(::Type{THISISONESUPERLONGTYPE1234567}) where {T<:Union{
          Int32,
          UInt32,
        }} =
          transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 37) == str

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
        a_long_function_name(Array{Float64,2}[
            [1.0],
            [0.5 0.5],
            [0.5 0.5; 0.5 0.5],
            [0.5 0.5; 0.5 0.5],
        ])"""
        @test fmt(str, 4, length(str)) == str_
        @test fmt(str_) == str

        # unary op
        str_ = "[1, 1]'"
        str = """
        [
         1,
         1,
        ]'"""
        @test fmt(str, 4, length(str)) == str_
        @test fmt(str_, 4, length(str_) - 1) == str
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
    @testset "issue 77" begin
        str_ = """
        [ a b Expr()
        d e Expr()]"""
        str = """
        [
         a b Expr()
         d e Expr()
        ]"""
        @test fmt(str_) == str

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
         a b Expr()
         d e Expr()
        ]"""
        @test fmt(str_) == str
        str_ = "[a b Expr(); d e Expr()]"
        @test fmt(str_) == str_
        @test fmt(str_, 4, 1) == str

        str_ = """
        T[ a b Expr();
        d e Expr();]"""
        str = """
        T[
          a b Expr()
          d e Expr()
        ]"""
        @test fmt(str_) == str

        str_ = "T[a b Expr(); d e Expr()]"
        @test fmt(str_) == str_
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
        @test fmt(str) == str
    end

end
