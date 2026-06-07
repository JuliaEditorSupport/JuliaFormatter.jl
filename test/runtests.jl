using JuliaFormatter
using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, Options, options, CONFIG_FILE_NAME
using JuliaFormatter: format_text
using JuliaFormatter.Internal: test_format
using Test
using JuliaSyntax

# Make sure to develop the local version of the package. Otherwise the jlfmt app tests can
# end up using a stale version.
using Pkg: Pkg
Pkg.develop(; path = dirname(@__DIR__))

function fmt1(s; i = 4, m = 80, kwargs...)
    JuliaFormatter.format_text(s; kwargs..., indent = i, margin = m)
end
fmt1(s, i, m; kwargs...) = fmt1(s; kwargs..., i = i, m = m)

# Verifies formatting the formatted text
# results in the same output
function fmt(s; i = 4, m = 80, kwargs...)
    kws = merge(options(DefaultStyle()), kwargs)
    s1 = fmt1(s; kws..., i = i, m = m)
    return fmt1(s1; kws..., i = i, m = m)
end
fmt(s, i, m; kwargs...) = fmt(s; kwargs..., i = i, m = m)

function run_pretty(text::String; style = DefaultStyle(), opts = Options())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text)
    t = JuliaFormatter.pretty(style, g, s)
    t
end
run_pretty(text::String, margin::Int) = run_pretty(text, opts = Options(margin = margin))

function run_nest(text::String; opts = Options(), style = DefaultStyle())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text)
    t = JuliaFormatter.pretty(style, g, s)
    JuliaFormatter.nest!(style, t, s)
    t, s
end
run_nest(text::String, margin::Int) = run_nest(text, opts = Options(margin = margin))

function run_format(text::String; style = DefaultStyle(), opts = Options())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text)
    JuliaFormatter.format_text(g, style, s)
    s
end

@testset "JuliaFormatter" begin
    include("internal_utils.jl")
    include("default_style.jl")
    include("yas_style.jl")
    include("blue_style.jl")
    include("sciml_style.jl")
    include("multidimensional_array.jl")
    include("issues.jl")
    include("options.jl")
    include("interface.jl")
    include("config.jl")
    include("format_repo.jl")
    include("jlfmt_app.jl")
end
