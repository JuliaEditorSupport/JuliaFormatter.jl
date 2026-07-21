using Test

# Make sure to develop the local version of the package. Otherwise the jlfmt app tests can
# end up using a stale version.
using Pkg: Pkg
Pkg.develop(; path = dirname(@__DIR__))

@testset "JuliaFormatter" begin
    include("dispatch.jl")
    include("internal_utils.jl")
    include("default_style.jl")
    include("yas_style.jl")
    include("blue_style.jl")
    include("sciml_style.jl")
    include("multidimensional_array.jl")
    include("issues.jl")
    include("inline_comments.jl")
    include("options.jl")
    include("options/always_use_return.jl")
    include("options/annotate_untyped_fields_with_any.jl")
    include("options/for_to_in.jl")
    include("options/import_to_using.jl")
    include("options/long_to_short_function_def.jl")
    include("options/short_circuit_to_if.jl")
    include("options/trailing_comma.jl")
    include("options/v2_stable_multiline_strings.jl")
    include("options/separate_kwargs_with_semicolons.jl")
    include("options/transform_syntax_in_macros.jl")
    include("options/format_docstrings.jl")
    include("options/enforce_triplequoted_docstrings.jl")
    include("line_ranges.jl")
    include("interface.jl")
    include("config.jl")
    include("format_repo.jl")
    include("argparse.jl")
    include("jlfmt_app.jl")
end
