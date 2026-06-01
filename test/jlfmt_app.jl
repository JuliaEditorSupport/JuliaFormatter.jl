@testset "Test jlfmt app" begin
    if VERSION < v"1.12"
        @info "Skipping jlfmt app tests for pre-v1.12 Julia."
        return
    end

    @testset "Test app with threads" begin
        mktempdir(; prefix = "jlfmt_threads_") do sandbox_dir
            write(
                joinpath(sandbox_dir, "spacing_and_call.jl"),
                """
                f( x,y )=x+y
                z=f( 1,2 )
                """,
            )

            write(
                joinpath(sandbox_dir, "control_flow_and_collection.jl"),
                """
                function g(xs)
                ys=[ x*2 for x in xs if x>0 ]
                return ys
                end
                """,
            )

            write(
                joinpath(sandbox_dir, "struct_and_keywords.jl"),
                """
                struct Foo
                x::Int
                y::String
                end

                h(;a=1,b=2)=a+b
                """,
            )

            project = dirname(Base.active_project())

            check_before_cmd = `$(Base.julia_cmd()) --threads=3 --project=$project -m JuliaFormatter --check $sandbox_dir`
            @test !success(check_before_cmd)

            format_cmd = `$(Base.julia_cmd()) --threads=3 --project=$project -m JuliaFormatter --inplace $sandbox_dir`
            @test success(format_cmd)

            check_after_cmd = `$(Base.julia_cmd()) --threads=3 --project=$project -m JuliaFormatter --check $sandbox_dir`
            @test success(check_after_cmd)
        end
    end

    @testset "style is picked up from config correctly" begin
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/951
        mktempdir(; prefix = "jlfmt_style_") do sandbox_dir
            cd(sandbox_dir) do
                text = "(; a = 1)"
                write("a.jl", text)

                # Blue style will remove whitespace around kwarg.
                write(".JuliaFormatter.toml", "style = \"blue\"")
                run(`$(Base.julia_cmd()) --project=$(Base.active_project()) -m JuliaFormatter --inplace .`)
                @test readchomp("a.jl") == format_text(text, BlueStyle())
                # Sanity check to make sure our test is actually testing something
                @test text != format_text(text, BlueStyle())

                # Default style will add the whitespace back
                write(".JuliaFormatter.toml", "style = \"default\"")
                run(`$(Base.julia_cmd()) --project=$(Base.active_project()) -m JuliaFormatter --inplace .`)
                @test readchomp("a.jl") == text
            end
        end
    end
end
