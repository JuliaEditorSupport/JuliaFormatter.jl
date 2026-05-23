using JuliaFormatter
using JuliaFormatter: DefaultStyle, YASStyle, Options, options, CONFIG_FILE_NAME
using Test
using JuliaSyntax

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

function yasfmt1(str; kwargs...)
    fmt1(str; style = YASStyle(), options(DefaultStyle())..., kwargs...)
end
function yasfmt(str; i = 4, m = 80, kwargs...)
    fmt(str; i = i, m = m, style = YASStyle(), kwargs...)
end
yasfmt(str, i::Int, m::Int; kwargs...) = yasfmt(str; i = i, m = m, kwargs...)

bluefmt1(str) = fmt1(str; style = BlueStyle(), options(DefaultStyle())...)
function bluefmt(str; i = 4, m = 80, kwargs...)
    fmt(str; i = i, m = m, style = BlueStyle(), kwargs...)
end
bluefmt(str, i::Int, m::Int; kwargs...) = bluefmt(str; i = i, m = m, kwargs...)

minimalfmt1(str) = fmt1(str; style = MinimalStyle(), options(DefaultStyle())...)
function minimalfmt(str; i = 4, m = 92, kwargs...)
    fmt(str; i = i, m = m, style = MinimalStyle(), kwargs...)
end
minimalfmt(str, i::Int, m::Int; kwargs...) = minimalfmt(str; i = i, m = m, kwargs...)

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
    include("default_style.jl")
    include("yas_style.jl")
    include("blue_style.jl")
    include("sciml_style.jl")
    if VERSION >= v"1.7"
        include("multidimensional_array.jl")
    end
    include("issues.jl")
    include("options.jl")
    include("interface.jl")
    include("config.jl")
    include("format_repo.jl")
    include("jlfmt_app.jl")
end
