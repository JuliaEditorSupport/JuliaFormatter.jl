module JlfmtAppTests

using Test: @test, @testset
using JuliaFormatter
using UUIDs: uuid4

const PROJECT_DIR = dirname(abspath(Base.active_project()))
const CONFIG_FILE_NAME = ".JuliaFormatter.toml"

jlfmt_cmd(julia_flags::Cmd = ``) =
    `$(Base.julia_cmd()) $julia_flags --project=$PROJECT_DIR -m JuliaFormatter`

function with_sandbox(f)
    mktempdir(; prefix = "jlfmt_test_$(uuid4())_") do dir
        cd(dir) do
            f(dir)
        end
    end
end

@static if VERSION < v"1.12"
    @info "Skipping jlfmt app tests for pre-v1.12 Julia."
else
    @testset "Test jlfmt app" begin
        @testset "--threads" begin
            with_sandbox() do _
                write("spacing_and_call.jl", "f( x,y )=x+y\nz=f( 1,2 )\n")
                write(
                    "control_flow_and_collection.jl",
                    "function g(xs)\nys=[ x*2 for x in xs if x>0 ]\nreturn ys\nend\n",
                )
                write(
                    "struct_and_keywords.jl",
                    "struct Foo\nx::Int\ny::String\nend\n\nh(;a=1,b=2)=a+b\n",
                )

                threaded_cmd = jlfmt_cmd(`--threads=3`)
                @test !success(`$threaded_cmd --check .`)
                @test success(`$threaded_cmd --inplace .`)
                @test success(`$threaded_cmd --check .`)
            end
        end

        @testset "DefaultStyle is used if not configured" begin
            with_sandbox() do _
                text = "(; a=1)"
                write("a.jl", text)
                run(`$(jlfmt_cmd()) --inplace a.jl`)
                @test readchomp("a.jl") == format_text(text, DefaultStyle())
                # Sanity check that the text is actually being formatted
                @test text != format_text(text, DefaultStyle())
            end
        end

        @testset "ignore" begin
            text = "a+ b"
            formatted = format_text(text)
            @assert text != formatted

            function write_ignore_test_files()
                write("fmt.jl", text)
                write("skip_me.jl", text)
                mkdir("sub")
                write("sub/also_fmt.jl", text)
                write("sub/skip_me_too.jl", text)
            end

            function check_ignore_results()
                @test readchomp("fmt.jl") == formatted
                @test readchomp("sub/also_fmt.jl") == formatted
                @test read("skip_me.jl", String) == text
                @test read("sub/skip_me_too.jl", String) == text
            end

            @testset "via --ignore flag" begin
                with_sandbox() do _
                    write_ignore_test_files()
                    run(
                        `$(jlfmt_cmd()) --inplace --ignore=skip_me.jl --ignore=sub/skip_me_too.jl .`,
                    )
                    check_ignore_results()
                end
            end

            @testset "via .JuliaFormatter.toml" begin
                with_sandbox() do _
                    write_ignore_test_files()
                    write(
                        CONFIG_FILE_NAME,
                        """ignore = ["skip_me.jl", "sub/skip_me_too.jl"]\n""",
                    )
                    run(`$(jlfmt_cmd()) --inplace .`)
                    check_ignore_results()
                end
            end
        end

        @testset "--check" begin
            with_sandbox() do _
                fname = "a.jl"
                unformatted = "f( x,y )=x+y"

                # Format first, then --check should pass
                write(fname, unformatted)
                run(`$(jlfmt_cmd()) --inplace $fname`)
                @test success(`$(jlfmt_cmd()) --check $fname`)

                # --check should fail on unformatted file
                write(fname, unformatted)
                @test !success(`$(jlfmt_cmd()) --check $fname`)
                # --check should not modify the file
                @test readchomp(fname) == unformatted
            end
        end

        @testset "--inplace" begin
            with_sandbox() do _
                fname = "a.jl"
                unformatted = "f( x,y )=x+y"
                formatted = format_text(unformatted)

                write(fname, unformatted)
                run(`$(jlfmt_cmd()) --inplace $fname`)
                @test readchomp(fname) == formatted

                # Running again on already-formatted file is a no-op
                run(`$(jlfmt_cmd()) --inplace $fname`)
                @test readchomp(fname) == formatted
            end
        end

        @testset "stdout mode" begin
            with_sandbox() do _
                fname = "a.jl"
                unformatted = "f( x,y )=x+y"
                formatted = format_text(unformatted)

                write(fname, unformatted)
                output = readchomp(`$(jlfmt_cmd()) $fname`)
                @test output == formatted
                # File should be unchanged
                @test readchomp(fname) == unformatted
            end
        end

        @testset "--prioritize-config-file" begin
            @testset "style" begin
                with_sandbox() do _
                    fname = "a.jl"
                    text = "(; a = 1)"
                    write(fname, text)
                    write(CONFIG_FILE_NAME, "style = \"blue\"")

                    # By default, CLI --style overrides config
                    run(`$(jlfmt_cmd()) --inplace --style=default $fname`)
                    @test readchomp(fname) == text

                    # With --prioritize-config-file, config wins over CLI
                    run(`$(jlfmt_cmd()) --inplace --prioritize-config-file --style=default $fname`)
                    @test readchomp(fname) == format_text(text, BlueStyle())
                end
            end

            @testset "options" begin
                with_sandbox() do _
                    fname = "a.jl"
                    text = "f(a = 1)"
                    write(fname, text)
                    write(CONFIG_FILE_NAME, "whitespace_in_kwargs = false")

                    # By default, CLI flag overrides config
                    run(`$(jlfmt_cmd()) --inplace --whitespace_in_kwargs $fname`)
                    @test readchomp(fname) == text

                    # With --prioritize-config-file, config wins over CLI
                    run(`$(jlfmt_cmd()) --inplace --prioritize-config-file --whitespace_in_kwargs $fname`)
                    @test readchomp(fname) == format_text(text; whitespace_in_kwargs = false)
                end
            end
        end

        @testset "style is picked up from config correctly" begin
            # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/951
            with_sandbox() do _
                fname = "a.jl"
                text = "(; a = 1)"
                write(fname, text)

                write(CONFIG_FILE_NAME, "style = \"blue\"")
                run(`$(jlfmt_cmd()) --inplace .`)
                @test readchomp(fname) == format_text(text, BlueStyle())
                @test text != format_text(text, BlueStyle())

                write(".JuliaFormatter.toml", "style = \"default\"")
                run(`$(jlfmt_cmd()) --inplace .`)
                @test readchomp(fname) == text
            end
        end
    end
end

end # module
