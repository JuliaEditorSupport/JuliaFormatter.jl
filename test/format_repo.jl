module FormatRepoTests

using JuliaFormatter: format
using Test

@testset "Format repo" begin
    @testset "$name" for (name, kwargs) in (
        ("empty", (;)),
        ("jlbos", (; join_lines_based_on_source=true)),
        ("jlbos+margin", (; join_lines_based_on_source=true, margin=10_000))
    )
        try
            sandbox_dir = joinpath(tempdir(), join(rand('a':'z', 40)))
            if isdir(sandbox_dir)
                rm(sandbox_dir; recursive=true)
            end
            mkdir(sandbox_dir)
            cp(@__DIR__, sandbox_dir; force=true)
            format(sandbox_dir; kwargs...)
            @test format(sandbox_dir; kwargs...)
        finally
            try
                rm(sandbox_dir; recursive=true)
            catch
            end
        end
    end
end

end
