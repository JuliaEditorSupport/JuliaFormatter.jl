module AnnotateUntypedFieldsWithAnyTests

using JuliaFormatter.Internal: test_format, ALL_STYLES
using Test

@testset "annotate_untyped_fields_with_any" begin
    @testset "basic" begin
        strtrue = """
        struct name
            arg::Any
        end"""
        strfalse = """
        struct name
            arg
        end"""
        for str_ in (
            "struct name\n    arg\nend",
            "struct name\narg\nend",
            "struct name\n        arg\n    end",
        )
            for style in ALL_STYLES
                test_format(str_, strtrue; annotate_untyped_fields_with_any=true)
                test_format(str_, strfalse; annotate_untyped_fields_with_any=false)
            end
        end
    end

    @testset "not in macros/exprs" begin
        str1 = """
        @macro struct name
            arg
        end"""
        str2 = """
        :(struct name
            arg
        end)"""
        str3 = """
        quote
            struct name
                arg
            end
        end"""

        for str in (str1, str2, str3)
            for style in ALL_STYLES
                test_format(str, str; annotate_untyped_fields_with_any=true)
                test_format(str, str; annotate_untyped_fields_with_any=false)
            end
        end
    end
end

end # module
