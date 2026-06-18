module JlfmtAppTests

using Test: @test, @testset
using JuliaFormatter
using JuliaFormatter: UNFORMATTED_EXIT_CODE, ERROR_EXIT_CODE
using UUIDs: uuid4

const PROJECT_DIR = dirname(abspath(Base.active_project()))
const CONFIG_FILE_NAME = ".JuliaFormatter.toml"

function jlfmt_cmd(julia_flags::Cmd = ``)
    `$(Base.julia_cmd()) $julia_flags --project=$PROJECT_DIR -m JuliaFormatter`
end

function with_sandbox(f)
    mktempdir(; prefix = "jlfmt_test_$(uuid4())_") do dir
        cd(dir) do
            f(dir)
        end
    end
end

function capture_stderr(f)
    path = tempname()
    try
        return open(path, "w+") do io::IOStream
            result = redirect_stderr(f, io)
            flush(io)
            seekstart(io)
            return result, read(io, String)
        end
    finally
        rm(path; force = true)
    end
end

function check_exitcode(expected::Int, cmd::Cmd)
    @test run(ignorestatus(cmd)).exitcode == expected
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
                check_exitcode(UNFORMATTED_EXIT_CODE, `$threaded_cmd --check .`)
                @test success(`$threaded_cmd --inplace .`)
                @test success(`$threaded_cmd --check .`)
            end
        end

        @testset "doesn't crash on empty files" begin
            with_sandbox() do _
                write("empty.jl", "")
                run(`$(jlfmt_cmd()) --inplace empty.jl`)
                @test isempty(readchomp("empty.jl"))
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
                @test readchomp("skip_me.jl") == text
                @test readchomp("sub/skip_me_too.jl") == text
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
                errno, stderr = capture_stderr() do
                    JuliaFormatter.main(["--check", fname])
                end
                @test errno == UNFORMATTED_EXIT_CODE
                @test occursin(
                    "Some files are not formatted correctly. Run again with `--inplace` instead of `--check` to format them.",
                    stderr,
                )
                # --check should not modify the file
                @test readchomp(fname) == unformatted
            end
        end

        @testset "multiple input diagnostics" begin
            with_sandbox() do _
                write("a.jl", "f( x,y )=x+y")
                write("b.jl", "g( x,y )=x+y")

                errno, stderr = capture_stderr() do
                    JuliaFormatter.main(["."])
                end
                @test errno == ERROR_EXIT_CODE
                @test occursin(
                    "multiple input files require either `--inplace` to write changes or `--check` to verify formatting",
                    stderr,
                )
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
                    run(
                        `$(jlfmt_cmd()) --inplace --prioritize-config-file --style=default $fname`,
                    )
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
                    run(
                        `$(jlfmt_cmd()) --inplace --prioritize-config-file --whitespace_in_kwargs $fname`,
                    )
                    @test readchomp(fname) ==
                          format_text(text; whitespace_in_kwargs = false)
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

        @testset "--lines" begin
            @testset "single range formats only that line" begin
                with_sandbox() do _
                    fname = "a.jl"
                    write(fname, "f(x,y)=1\ng( a ,b )=2\n")
                    run(`$(jlfmt_cmd()) --inplace --lines=1:1 $fname`)
                    # line 1 formatted, line 2 kept verbatim
                    @test readchomp(fname) == "f(x, y) = 1\ng( a ,b )=2"
                end
            end

            @testset "multiple ranges via repetition" begin
                with_sandbox() do _
                    fname = "a.jl"
                    write(fname, "f(a,b)=1\ng( x ,y )=2\nh(c,d)=3\n")
                    run(`$(jlfmt_cmd()) --inplace --lines=1:1 --lines=3:3 $fname`)
                    @test readchomp(fname) == "f(a, b) = 1\ng( x ,y )=2\nh(c, d) = 3"
                end
            end

            @testset "stdin" begin
                out = read(
                    pipeline(
                        `$(jlfmt_cmd()) --lines=1:1`;
                        stdin = IOBuffer("f(x,y)=1\ng( a ,b )=2\n"),
                    ),
                    String,
                )
                @test out == "f(x, y) = 1\ng( a ,b )=2\n"
            end

            @testset "--check only inspects the requested lines" begin
                with_sandbox() do _
                    fname = "a.jl"
                    # line 1 already formatted, line 2 not
                    write(fname, "f(x, y) = 1\ng( a ,b )=2\n")
                    # checking only line 1 passes (it is already formatted)...
                    @test success(`$(jlfmt_cmd()) --check --lines=1:1 $fname`)
                    # ...but checking line 2 fails (it needs formatting)
                    @test check_exitcode(UNFORMATTED_EXIT_CODE, `$(jlfmt_cmd()) --check --lines=2:2 $fname`)
                    # --check must not modify the file
                    @test readchomp(fname) == "f(x, y) = 1\ng( a ,b )=2"
                end
            end

            @testset "errors" begin
                with_sandbox() do _
                    write("a.jl", "f(x,y)=1\ng(a,b)=2\n")
                    write("b.jl", "h(x,y)=1\n")
                    write("a.md", "x=1\n")

                    # multiple input files
                    errno, stderr = capture_stderr() do
                        JuliaFormatter.main(["--check", "--lines=1:1", "a.jl", "b.jl"])
                    end
                    @test errno == ERROR_EXIT_CODE
                    @test occursin(
                        "option `--lines` cannot be used together with multiple input files",
                        stderr,
                    )

                    # malformed argument
                    errno, stderr = capture_stderr() do
                        JuliaFormatter.main(["--lines=abc", "a.jl"])
                    end
                    @test errno == ERROR_EXIT_CODE
                    @test occursin("invalid value `abc` for option `--lines=abc`", stderr)

                    # start greater than stop
                    errno, stderr = capture_stderr() do
                        JuliaFormatter.main(["--lines=5:2", "a.jl"])
                    end
                    @test errno == ERROR_EXIT_CODE
                    @test occursin("start is greater than stop", stderr)

                    # out of bounds (reported cleanly, no backtrace)
                    errno, stderr = capture_stderr() do
                        JuliaFormatter.main(["--lines=1:99", "a.jl"])
                    end
                    @test errno == ERROR_EXIT_CODE
                    @test occursin("out of bounds", stderr)
                    @test !occursin("Stacktrace", stderr)

                    # Markdown input is not supported
                    errno, stderr = capture_stderr() do
                        JuliaFormatter.main(["--format_markdown", "--lines=1:1", "a.md"])
                    end
                    @test errno == ERROR_EXIT_CODE
                    @test occursin(
                        "option `--lines` is not supported for Markdown input",
                        stderr,
                    )
                end
            end
        end

        @testset "config file vs CLI argument interaction" begin
            @testset "CLI overrides config file by default" begin
                with_sandbox() do _
                    fname = "a.jl"
                    text = "if true\nx = 1\nend\n"
                    write(fname, text)
                    write(CONFIG_FILE_NAME, "indent = 8")

                    # CLI --indent=2 should win over config indent=8
                    run(`$(jlfmt_cmd()) --inplace --indent=2 $fname`)
                    @test readchomp(fname) == rstrip(format_text(text; indent = 2))
                    # Sanity check: the config value (8) would give different output
                    @test format_text(text; indent = 2) != format_text(text; indent = 8)
                end
            end

            @testset "config provides defaults for options not on CLI" begin
                with_sandbox() do _
                    fname = "a.jl"
                    text = "if true\nx = 1\nend\n"
                    write(fname, text)
                    # Config sets indent=8; CLI does not specify --indent
                    write(CONFIG_FILE_NAME, "indent = 8")

                    run(`$(jlfmt_cmd()) --inplace $fname`)
                    @test readchomp(fname) == rstrip(format_text(text; indent = 8))
                end
            end

            @testset "config and CLI options merge (different keys)" begin
                with_sandbox() do _
                    fname = "a.jl"
                    text = "f(a = 1)\n"
                    write(fname, text)
                    # Config sets whitespace_in_kwargs=false; CLI sets indent=2
                    # Both should take effect since they control different things
                    write(CONFIG_FILE_NAME, "whitespace_in_kwargs = false")

                    run(`$(jlfmt_cmd()) --inplace --indent=2 $fname`)
                    @test readchomp(fname) ==
                          rstrip(format_text(text; whitespace_in_kwargs = false, indent = 2))
                end
            end

            @testset "--config-dir loads config from specified directory" begin
                with_sandbox() do dir
                    fname = "a.jl"
                    text = "if true\nx = 1\nend\n"
                    write(fname, text)

                    # Put the config in a subdirectory, not the file's own directory
                    config_subdir = joinpath(dir, "config")
                    mkdir(config_subdir)
                    write(joinpath(config_subdir, CONFIG_FILE_NAME), "indent = 8")

                    # Without --config-dir, no config is found (file is in sandbox root)
                    run(`$(jlfmt_cmd()) --inplace $fname`)
                    default_result = readchomp(fname)

                    # Reset the file
                    write(fname, text)

                    # With --config-dir, config from subdirectory is used
                    run(`$(jlfmt_cmd()) --inplace --config-dir=$config_subdir $fname`)
                    @test readchomp(fname) == rstrip(format_text(text; indent = 8))
                    @test readchomp(fname) != default_result
                end
            end

            @testset "config style with CLI option override" begin
                with_sandbox() do _
                    fname = "a.jl"
                    # BlueStyle sets f(a = 1) -> f(; a=1)
                    text = "f(a = 1)\n"
                    write(fname, text)
                    # But we also want to test that a CLI option can override a style default
                    # CLI overrides whitespace_in_kwargs=true
                    write(CONFIG_FILE_NAME, "style = \"blue\"")

                    run(
                        `$(jlfmt_cmd()) --inplace --whitespace-in-kwargs=true $fname`,
                    )
                    output = readchomp(fname)
                    @test output == rstrip(
                        format_text(text, BlueStyle(); whitespace_in_kwargs = true),
                    )
                    @test output != strip(format_text(text, BlueStyle()))
                end
            end

            @testset "no config file uses only CLI args" begin
                with_sandbox() do _
                    fname = "a.jl"
                    text = "if true\nx = 1\nend\n"
                    write(fname, text)
                    # No config file written in sandbox

                    run(`$(jlfmt_cmd()) --inplace --indent=8 $fname`)
                    @test readchomp(fname) == rstrip(format_text(text; indent = 8))
                end
            end

            @testset "CLI --ignore replaces config ignore" begin
                text = "a+ b"
                formatted = format_text(text)
                @assert text != formatted

                with_sandbox() do _
                    write("keep.jl", text)
                    write("skip.jl", text)
                    # Config ignores "keep.jl", but CLI ignores "skip.jl" instead.
                    # Since merge replaces the :ignore key, only CLI's pattern applies.
                    write(CONFIG_FILE_NAME, """ignore = ["keep.jl"]\n""")

                    run(`$(jlfmt_cmd()) --inplace --ignore=skip.jl .`)
                    @test readchomp("keep.jl") == formatted
                    @test readchomp("skip.jl") == text
                end
            end

            @testset "nested config files" begin
                with_sandbox() do _
                    # root/
                    # ├── .JuliaFormatter.toml  (indent = 2)
                    # ├── a.jl
                    # └── sub/
                    #     ├── .JuliaFormatter.toml  (indent = 8)
                    #     └── b.jl
                    text = "if true\nx = 1\nend\n"
                    write(CONFIG_FILE_NAME, "indent = 2")
                    write("a.jl", text)
                    mkdir("sub")
                    write(joinpath("sub", CONFIG_FILE_NAME), "indent = 8")
                    write(joinpath("sub", "b.jl"), text)

                    run(`$(jlfmt_cmd()) --inplace .`)
                    @test readchomp("a.jl") == rstrip(format_text(text; indent = 2))
                    @test readchomp(joinpath("sub", "b.jl")) ==
                          rstrip(format_text(text; indent = 8))
                end
            end

            @testset "--prioritize-config-file with --config-dir" begin
                with_sandbox() do dir
                    fname = "a.jl"
                    text = "if true\nx = 1\nend\n"
                    write(fname, text)

                    config_subdir = joinpath(dir, "config")
                    mkdir(config_subdir)
                    write(joinpath(config_subdir, CONFIG_FILE_NAME), "indent = 8")

                    # CLI says indent=2, but --prioritize-config-file makes config win
                    run(
                        `$(jlfmt_cmd()) --inplace --prioritize-config-file --config-dir=$config_subdir --indent=2 $fname`,
                    )
                    @test readchomp(fname) == rstrip(format_text(text; indent = 8))
                end
            end
        end
    end
end

end # module
