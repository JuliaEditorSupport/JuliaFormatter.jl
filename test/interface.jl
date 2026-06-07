module InterfaceTests

using JuliaFormatter: format, format_file, BlueStyle
using Test

function test_format_file(fmt, before, after)
    sandbox_dir = joinpath(@__DIR__, "tmp")
    mkdir(sandbox_dir)
    try
        code_path = joinpath(sandbox_dir, "code.jl")
        open(io -> write(io, before), code_path, "w")

        @test fmt(code_path) == false
        @test strip(read(code_path, String)) == after
    finally
        rm(sandbox_dir; recursive = true)
    end
end

@testset "$f interface" for f in (format, format_file)
    before = "foo(; k =v)"
    @testset "style can be positional arg or keyword" begin
        pos = path -> f(path, BlueStyle())
        key = path -> f(path; style = BlueStyle())
        after = "foo(; k=v)"
        test_format_file(pos, before, after)
        test_format_file(key, before, after)
    end
    @testset "other keywords take affect" begin
        pos = path -> f(path, BlueStyle(); whitespace_in_kwargs = true)
        key = path -> f(path; style = BlueStyle(), whitespace_in_kwargs = true)
        after = "foo(; k = v)"
        test_format_file(pos, before, after)
        test_format_file(key, before, after)
    end
end

end
