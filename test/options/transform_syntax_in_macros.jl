module TransformSyntaxInMacrosTests

using JuliaFormatter.Internal: test_format
using Test

@testset "transform_syntax_in_macros" begin
    # For each syntax transformation that respects transform_syntax_in_macros, we test:
    # 1. The transformation does NOT fire inside a macro by default
    # 2. The transformation DOES fire inside a macro when transform_syntax_in_macros=true

    @testset "always_use_return" begin
        s = """
        @macro function foo()
            1
        end"""
        s_transformed = """
        @macro function foo()
            return 1
        end"""
        test_format(s, s; always_use_return=true)
        test_format(
            s,
            s_transformed;
            always_use_return=true,
            transform_syntax_in_macros=true,
        )
    end

    @testset "annotate_untyped_fields_with_any" begin
        s = """
        @macro struct Foo
            x
        end"""
        s_transformed = """
        @macro struct Foo
            x::Any
        end"""
        test_format(s, s; annotate_untyped_fields_with_any=true)
        test_format(
            s,
            s_transformed;
            annotate_untyped_fields_with_any=true,
            transform_syntax_in_macros=true,
        )
    end

    @testset "import_to_using" begin
        s = """
        @eval import Foo"""
        s_transformed = """
        @eval using Foo: Foo"""
        test_format(s, s; import_to_using=true)
        test_format(
            s,
            s_transformed;
            import_to_using=true,
            transform_syntax_in_macros=true,
        )
    end

    @testset "long_to_short_function_def" begin
        s = """
        @macro function foo()
            return 1
        end"""
        s_transformed = """
        @macro foo() = 1"""
        test_format(s, s; long_to_short_function_def=true)
        test_format(
            s,
            s_transformed;
            long_to_short_function_def=true,
            transform_syntax_in_macros=true,
        )
    end

    @testset "short_circuit_to_if" begin
        s = """
        @foo function f()
            a && b
            return c
        end"""
        s_transformed = """
        @foo function f()
            if a
                b
            end
            return c
        end"""
        test_format(s, s; short_circuit_to_if=true)
        test_format(
            s,
            s_transformed;
            short_circuit_to_if=true,
            transform_syntax_in_macros=true,
        )
    end

    # @testset "short_to_long_function_def" begin
    #     s = """
    #     @macro foo() = 1"""
    #     s_transformed = """
    #     @macro function foo()
    #         1
    #     end"""
    #     test_format(
    #         s,
    #         s;
    #         margin=length("@macro foo() = 1"),
    #         short_to_long_function_def=true,
    #     )
    #     test_format(
    #         s,
    #         s_transformed;
    #         margin=length("@macro foo() = 1") - 1,
    #         short_to_long_function_def=true,
    #         transform_syntax_in_macros=true,
    #     )
    # end

    # These transformations should NOT fire inside macros even with
    # transform_syntax_in_macros=true

    @testset "pipe_to_function_call still blocked" begin
        s = """
        @macro begin
            a |> b
        end"""
        test_format(s, s; pipe_to_function_call=true)
        test_format(
            s,
            s;
            pipe_to_function_call=true,
            transform_syntax_in_macros=true,
        )
    end

    @testset "separate_kwargs_with_semicolon still blocked" begin
        s = """
        @macro begin
            foo(a, b = 1)
        end"""
        test_format(s, s; separate_kwargs_with_semicolon=true)
        test_format(
            s,
            s;
            separate_kwargs_with_semicolon=true,
            transform_syntax_in_macros=true,
        )
    end

    # quote and :() are InsideExpr, so transforms should remain blocked
    # even with transform_syntax_in_macros=true

    @testset "quote blocks still blocked" begin
        s = """
        quote
            function foo()
                1
            end
        end"""
        test_format(s, s; always_use_return=true)
        test_format(
            s,
            s;
            always_use_return=true,
            transform_syntax_in_macros=true,
        )
    end

    @testset "interpolation expressions still blocked" begin
        s = """
        :(function foo()
            1
        end)"""
        test_format(s, s; always_use_return=true)
        test_format(
            s,
            s;
            always_use_return=true,
            transform_syntax_in_macros=true,
        )
    end
end

end # module
