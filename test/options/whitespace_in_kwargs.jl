module OptionsWhitespaceInKwargsTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, format_text
using JuliaFormatter.Internal: test_format, ALL_STYLES
using Test

@testset "whitespace in keyword arguments" begin
    @testset "basic" begin
        for constructor in (
            kw -> "f(arg1, $kw)",
            kw -> "f(arg1; $kw)",
            kw -> "f(arg1, $kw, arg3)",
            kw -> "f(arg1; $kw, kwarg2)",
            kw -> "@f(arg1, $kw)",
            kw -> "@f(arg1; $kw)",
            kw -> "@f(arg1, $kw, arg3)",
            kw -> "@f(arg1; $kw, kwarg2)",
        )
            with_space = constructor("x = y")
            without_space = constructor("x=y")

            # Default style allows us to check the exact output
            test_format(with_space, with_space; whitespace_in_kwargs = true)
            test_format(without_space, with_space; whitespace_in_kwargs = true)
            test_format(with_space, without_space; whitespace_in_kwargs = false)
            test_format(without_space, without_space; whitespace_in_kwargs = false)

            # Other styles generally do things, e.g. replacing commas with semicolons,
            # so we just check that the whitespace is handled correctly
            #
            # Note: SciMLStyle has special handling for whitespace in macro kwargs so we
            # ignore it here
            @testset "$style" for style in (YASStyle(), BlueStyle(), MinimalStyle())
                out = format_text(with_space, style; whitespace_in_kwargs = true)
                @test occursin("x = y", out)
                out = format_text(without_space, style; whitespace_in_kwargs = true)
                @test occursin("x = y", out)
                out = format_text(with_space, style; whitespace_in_kwargs = false)
                @test occursin("x=y", out)
                out = format_text(without_space, style; whitespace_in_kwargs = false)
                @test occursin("x=y", out)
            end
        end
    end

    @testset "kwargs needing parenthesisation" begin
        str = "f(; a!) = a!"
        test_format(str, str; whitespace_in_kwargs = false)

        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/242
        str_ = "f(a, b! = 1; c! = 2, d = 3, e! = 4)"
        str = "f(a, (b!)=1; (c!)=2, d=3, (e!)=4)"
        test_format(str_, str; whitespace_in_kwargs = false)

        str_ = "( k1 =v1,  k2! = v2)"
        str = "(k1=v1, (k2!)=v2)"
        test_format(
            str_,
            str,
            YASStyle();
            whitespace_in_kwargs = false,
        )
        test_format(str_, str; whitespace_in_kwargs = false)

        str_ = "( k1 =v1,  k2! = v2)"
        str = "(k1 = v1, k2! = v2)"
        test_format(
            str_,
            str,
            YASStyle();
            whitespace_in_kwargs = true,
        )
        test_format(str_, str; whitespace_in_kwargs = true)
    end

    @testset "kwarg values that would merge with `=`" begin
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1016
        for (str_, str) in (
            "(; g = >=(1))" => "(; g=(>=(1)))",
            "(; g = >(1))" => "(; g=(>(1)))",
            "(; g = ==(1))" => "(; g=(==(1)))",
            "(; g = ===(1))" => "(; g=(===(1)))",
            "(; g = =>(1))" => "(; g=(=>(1)))",
            # Already parenthesised
            "(; g = (>=(1)))" => "(; g=(>=(1)))",
            # These don't need parentheses.
            "(; g = +x)" => "(; g=+x)",
            "(; g = -x)" => "(; g=-x)",
            "(; g = !x)" => "(; g=!x)",
            "(; g = +x/2)" => "(; g=+x/2)",
            "(; g = +(2))" => "(; g=+(2))",
            "(; g = .+x)" => "(; g=.+x)",
            "(; g = .>=(1))" => "(; g=.>=(1))",
            "(; g = ≥(1))" => "(; g=≥(1))",
            "(; g = <(1))" => "(; g=<(1))",
            "(; g = ⊆)" => "(; g=⊆)",
            "(; g = :x)" => "(; g=:x)",
            raw"(; g = $x)" => raw"(; g=$x)",
        )
            test_format(str_, str; whitespace_in_kwargs = false, ast = true)
        end

        # Pathological case: `pipe_to_function_call` transforms the kwarg value, so we need
        # to make sure the parentheses are applied to the transformed text
        test_format(
            "(; g = x |> >(1))",
            "(; g=(>(1)(x)))";
            whitespace_in_kwargs = false,
            pipe_to_function_call = true,
        )
    end

    s = "C(; Vt=Ȳ')"
    test_format(s, s;  whitespace_in_kwargs = false)

    @testset "assignment in macro without parentheses" begin
        # `@macro A, B=C` parses as `@macro ((A, B) = C)`, so the `=` is an
        # assignment and not a keyword argument. The space after the macro name
        # must be kept.
        for style in ALL_STYLES, whitespace_in_kwargs in (true, false)
            out = format_text("@macro A, B=C", style; whitespace_in_kwargs)
            @test startswith(out, "@macro A")
        end
    end

    @testset "added parentheses nest like parentheses in the source" begin
        # With `whitespace_in_kwargs = false`, `a = >=(...)` becomes `a=(>=(...))`.
        # The added parentheses must nest the same way as they do when they are
        # already in the source (i.e. on the second pass), otherwise formatting is
        # not idempotent.
        s = raw"f(a = >=(h(xxxxxxxxxxxx, yyyyyyyyyyyy)))"
        out = raw"""
        f(
            a=(>=(
                h(
                    xxxxxxxxxxxx,
                    yyyyyyyyyyyy,
                ),
            )),
        )"""
        test_format(s, out; whitespace_in_kwargs = false, margin = 30, ast = true)

        # Check idempotence for all styles. `test_format` checks this for us, so we
        # just use the first pass as the expected output.
        for style in ALL_STYLES, yas_style_nesting in (true, false), margin in (20, 30, 40)
            opts = (; whitespace_in_kwargs = false, yas_style_nesting, margin)
            test_format(s, format_text(s, style; opts...), style; opts...)
        end

        # The same thing inside a macro call
        s = raw"@m(a = >=(h(xxxxxxxxxxxx, yyyyyyyyyyyy)))"
        for style in ALL_STYLES, margin in (20, 30, 40)
            opts = (; whitespace_in_kwargs = false, margin)
            test_format(s, format_text(s, style; opts...), style; opts...)
        end
    end
end

end
