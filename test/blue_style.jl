@testset "Blue Style" begin
    # @testset "ops" begin
    #     # `//` and `^` are binary ops without whitespace around them
    #     @test bluefmt("1 // 2 + 3 ^ 4") == "1 // 2 + 3 ^ 4"
    #     @test bluefmt("1 // 2 + 3 ^ 4") == "1//2 + 3^4"
    #     @test bluefmt("a .// 10") == "a .// 10"
    #     @test bluefmt("a.//10") == "a .// 10"
    # end

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
        @test bluefmt(str_) == str

        str_ = """
        var = (arg1,
        arg2)
        """
        str = """
        var = (arg1, arg2)
        """
        @test bluefmt(str_, 4, 18) == str

        str_ = """
        var = {arg1,
        arg2}
        """
        str = """
        var = {
            arg1, arg2
        }
        """
        @test bluefmt(str_, 4, 17) == str
        @test bluefmt(str_, 4, 14) == str

        str_ = """
        var = call(arg1,
        arg2)
        """
        str = """
        var = call(
            arg1, arg2
        )
        """
        @test bluefmt(str_, 4, 14) == str

        str = """
        var = call(
            arg1,
            arg2,
        )
        """
        @test bluefmt(str_, 4, 13) == str

        str_ = """
        var = ref[arg1,
        arg2]
        """
        str = """
        var = ref[
            arg1, arg2
        ]
        """
        @test bluefmt(str_, 4, 14) == str

        str = """
        var = ref[
            arg1,
            arg2,
        ]
        """
        @test bluefmt(str_, 4, 13) == str

        str_ = """
        var = ABC{arg1,
        arg2}
        """
        str = """
        var = ABC{
            arg1,arg2
        }
        """
        @test bluefmt(str_, 4, 13) == str

        str = """
        var = ABC{
            arg1,
            arg2,
        }
        """
        @test bluefmt(str_, 4, 12) == str

        str_ = """
        var = @call(arg1,
        arg2)
        """
        str = """
        var = @call(
            arg1, arg2
        )
        """
        @test bluefmt(str_, 4, 14) == str

        str = """
        var = @call(
            arg1,
            arg2
        )
        """
        @test bluefmt(str_, 4, 13) == str

        str_ = """
        function long_name_of_function_because_i_am_writing_an_example(
            arg1, arg2, arg3, arg4, arg5, arg6
        )
            # code
        end
        """
        @test bluefmt(str_, 4, 38) == str_

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
        @test bluefmt(str_, 4, 37) == str

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
        @test bluefmt(str, 4, 92) == str

        str_ = """
        var = foo(
            map(arr) do x
                x * 10
            end, "")
        """
        str = """
        var = foo(
            map(arr) do x
                x * 10
            end,
            "",
        )
        """
        @test bluefmt(str_, 4, 92) == str

        str_ = """
        df[:, :some_column] = [some_big_function_name(blahhh) for (fooooo, blahhh) in my_long_list_of_vars]
        """
        str = """
        df[:, :some_column] = [
            some_big_function_name(blahhh) for (fooooo, blahhh) in my_long_list_of_vars
        ]
        """
        @test bluefmt(str_, 4, 92) == str

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
            for i = 1:n
                @inbounds mul!(
                    reshape(view(C, :, i), eye_n, k), reshape(view(B, :, i), eye_n, l), transpose(A, B)
                )
            end
        end
        """
        @test bluefmt(str_, 4, 95) == str

        str = """
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
        @test bluefmt(str_, 4, 94) == str

        str = """
        function f()
            for i = 1:n
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
        @test bluefmt(str_, 4, 28) == str

        str = """
        function f()
            for i = 1:n
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
        @test bluefmt(str_, 4, 27) == str
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
                x *
                10
            end,
            "",
        )
        """
        @test bluefmt(str_, 4, 1) == str
    end

    @testset "no chained ternary allowed !!!" begin
        str = """
        E1 ? A : B
        """
        @test bluefmt(str) == str

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
        @test bluefmt(str_) == str
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
        @test bluefmt(str_) == str
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
        @test bluefmt(str_) == str

        str_ = "a || return"
        str = "a || return nothing"
        @test bluefmt(str_) == str
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
        s1 = format_text(str, BlueStyle())
        @test s1 == str
        s2 = format_text(s1, BlueStyle())
        @test s2 == str
    end
end
