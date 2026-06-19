module ImportToUsingTests

using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, format_text
using JuliaFormatter.Internal: test_format
using Test

ALL_STYLES = (DefaultStyle(), YASStyle(), BlueStyle(), SciMLStyle(), MinimalStyle())

@testset "import_to_using" begin
    @testset "basic" begin
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
    end

    @testset "232 submodule imports disabled" begin
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/232
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

    @testset "396 import X as Y disabled" begin
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/396
        str = """import Base.threads as th"""
        test_format(str, str)
        test_format(str, str; margin = 1)
        test_format(str, str; margin = 1, import_to_using = true)
    end

    @testset "664 import relative path disabled" begin
        # `import ..x` should not be converted to `using ..x: x` with `import_to_using`,
        # because `using ..x: x` is invalid when `x` is not a module.
        s = "module M\nimport ..x\ny = x\nend\n"
        test_format(s, s; import_to_using = true)

        str = "import ..A, .B, ...C"
        test_format(str, str; import_to_using = true)
    end

    @testset "disabled inside macro/quote" begin
        for str in (
            ":(import Foo)",
            ":(import Foo, Bar)",
            "quote\n    import Foo\nend",
            "@eval import Foo",
            "@eval(import Foo)",
        )
            for style in ALL_STYLES
                test_format(str, str, style; import_to_using = true)
            end
        end
    end
end

end
