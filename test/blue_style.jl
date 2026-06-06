module BlueTests

using JuliaFormatter.Internal: test_format
using Test
using JuliaFormatter: BlueStyle

@testset "Blue Style" begin
    @testset "nest to one line" begin
        str_ = """
        var = [arg1, #com
        arg2]
        """
        str = """
        var = [
            arg1, #com
            arg2,
        ]
        """
        test_format(str_, str, BlueStyle())

        str_ = """
        var = (arg1,
        arg2)
        """
        str = """
        var = (arg1, arg2)
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=18)

        str_ = """
        var = {arg1,
        arg2}
        """
        str = """
        var = {
            arg1, arg2
        }
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=17)
        test_format(str_, str, BlueStyle(); indent=4, margin=14)

        str_ = """
        var = call(arg1,
        arg2)
        """
        str = """
        var = call(
            arg1, arg2
        )
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=14)

        str = """
        var = call(
            arg1,
            arg2,
        )
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=13)

        str_ = """
        var = ref[arg1,
        arg2]
        """
        str = """
        var = ref[
            arg1, arg2
        ]
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=14)

        str = """
        var = ref[
            arg1,
            arg2,
        ]
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=13)

        str_ = """
        var = ABC{arg1,
        arg2}
        """
        str = """
        var = ABC{
            arg1,arg2
        }
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=13)

        str = """
        var = ABC{
            arg1,
            arg2,
        }
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=12)

        str_ = """
        var = @call(arg1,
        arg2)
        """
        str = """
        var = @call(
            arg1, arg2
        )
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=14)

        str = """
        var = @call(
            arg1,
            arg2
        )
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=13)

        str_ = """
        function long_name_of_function_because_i_am_writing_an_example(
            arg1, arg2, arg3, arg4, arg5, arg6
        )
            # code
        end
        """
        test_format(str_, str_, BlueStyle(); indent=4, margin=38)

        str = """
        function long_name_of_function_because_i_am_writing_an_example(
            arg1,
            arg2,
            arg3,
            arg4,
            arg5,
            arg6,
        )
            # code
        end
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=37)

        str = """
        Dict(
            "options" => join(
                imap(Iterators.filter(keep_option, connection_options)) do (k, v)
                    "-c k=(show_option(v))"
                end,
                " ",
            ),
        )
        """
        test_format(str_, str_, BlueStyle(); indent=4, margin=92)

        str_ = """
        var = foo(
            map(arr) do x
                x * 10
            end, "")
        """
        str = """
        var = foo(
            map(arr) do x
                return x * 10
            end,
            "",
        )
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=92)

        str_ = """
        df[:, :some_column] = [some_big_function_name(blahhh) for (fooooo, blahhh) in my_long_list_of_vars]
        """
        str = """
        df[:, :some_column] = [
            some_big_function_name(blahhh) for (fooooo, blahhh) in my_long_list_of_vars
        ]
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=92)

        str_ = """
        function f()
            for i = 1:n
         @inbounds mul!(
             reshape(view(C, :, i), eye_n, k),
             reshape(view(B, :, i), eye_n, l),
             transpose(A, B),
         )
            end
        end
        """
        str = """
        function f()
            for i in 1:n
                @inbounds mul!(
                    reshape(view(C, :, i), eye_n, k), reshape(view(B, :, i), eye_n, l), transpose(A, B)
                )
            end
        end
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=95)

        str = """
        function f()
            for i in 1:n
                @inbounds mul!(
                    reshape(view(C, :, i), eye_n, k),
                    reshape(view(B, :, i), eye_n, l),
                    transpose(A, B),
                )
            end
        end
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=94)

        str = """
        function f()
            for i in 1:n
                @inbounds mul!(
                    reshape(
                        view(
                            C, :, i
                        ),
                        eye_n,
                        k,
                    ),
                    reshape(
                        view(
                            B, :, i
                        ),
                        eye_n,
                        l,
                    ),
                    transpose(A, B),
                )
            end
        end
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=28)

        str = """
        function f()
            for i in 1:n
                @inbounds mul!(
                    reshape(
                        view(
                            C, :, i
                        ),
                        eye_n,
                        k,
                    ),
                    reshape(
                        view(
                            B, :, i
                        ),
                        eye_n,
                        l,
                    ),
                    transpose(
                        A, B
                    ),
                )
            end
        end
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=27)
    end

    @testset "do not nest assignments if the RHS is iterable" begin
        str_ = """
        var = foo(
            map(arr) do x
                x * 10
            end, "")
        """
        str = """
        var = foo(
            map(
                arr,
            ) do x
                return x *
                       10
            end,
            "",
        )
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=1)
    end

    @testset "no chained ternary allowed !!!" begin
        str = """
        E1 ? A : B
        """
        test_format(str, str, BlueStyle())

        str_ = """
        E1 ? A : E2 ? B : C
        """
        str = """
        if E1
            A
        elseif E2
            B
        else
            C
        end
        """
        test_format(str_, str, BlueStyle())
    end

    @testset "has always_use_return=true" begin
        str_ = """
        function foo()
            x
        end
        """
        str = """
        function foo()
            return x
        end
        """
        test_format(str_, str, BlueStyle())
    end

    @testset "use `return nothing` instead of `return`" begin
        str_ = """
        function foo()
            return
        end
        """
        str = """
        function foo()
            return nothing
        end
        """
        test_format(str_, str, BlueStyle())

        str_ = "a || return"
        str = "a || return nothing"
        test_format(str_, str, BlueStyle())
    end

    @testset "weird line removal case" begin
        str = raw"""
        const FASTABLE_AST = quote
            @testset "Unary complex functions" begin
                for f in (abs, abs2, conj), z in (-4.1 - 0.02im, 6.4, 3 + im)
                    @testset "Unary complex functions f = $f, z = $z" begin
                        complex_jacobian_test(f, z)
                    end
                end
                # As per PR #196, angle gives a ZeroTangent() pullback for Real z and ΔΩ, rather than
                # the one you'd get from considering the reals as embedded in the complex plane
                # so we need to special case it's tests
                for z in (-4.1 - 0.02im, 6.4 + 0im, 3 + im)
                    complex_jacobian_test(angle, z)
                end
                @test frule((ZeroTangent(), randn()), angle, randn())[2] === ZeroTangent()
                @test rrule(angle, randn())[2](randn())[2] === ZeroTangent()
            end

            @testset "Unary functions" begin
                for x in (-4.1, 6.4, 0.0, 0.0 + 0.0im, 0.5 + 0.25im)
                    test_scalar(+, x)
                    test_scalar(-, x)
                    test_scalar(atan, x)
                end
            end

            @testset "binary functions" begin
                @testset "$f(x, y)" for f in (atan, rem, max, min)
                    # be careful not to sample near singularities for `rem`
                    base = rand() + 1
                    test_frule(f, (rand(0:10) + 0.6rand() + 0.2) * base, base)
                    base = rand() + 1
                    test_rrule(f, (rand(0:10) + 0.6rand() + 0.2) * base, base)
                end

                @testset "$f(x::$T, y::$T)" for f in (/, +, -, hypot), T in (Float64, ComplexF64)
                    test_frule(f, 10rand(T), rand(T))
                    test_rrule(f, 10rand(T), rand(T))
                end
            end
        end
        """
        test_format(str, str, BlueStyle())
    end
end

end
