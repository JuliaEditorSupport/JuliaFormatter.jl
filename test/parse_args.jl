module ParseArgsTests

using Test: @test, @testset, @test_throws
using JuliaFormatter.ArgParse: ParsedArgs, ParseArgsError, parse_args, OutputMode, StdoutMode, InplaceMode, CheckMode
using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle

@testset "parse_args" begin
    @testset "empty args" begin
        args = parse_args(String[])
        @test args.paths == []
        @test args.mode == StdoutMode
        @test args.diff == false
        @test args.verbose == false
        @test args.format_markdown == false
        @test args.config_priority == false
        @test args.outputfile === nothing
        @test args.stdin_filename == "stdin"
        @test args.config_dir == ""
        @test args.ignore_patterns == []
        @test args.line_ranges == []
        @test args.format_options == Dict{Symbol,Any}()
        @test args.help == false
        @test args.version == false
    end

    @testset "help" begin
        for flag in ["-h", "--help"]
            args = parse_args([flag])
            @test args.help == true
        end
    end

    @testset "version" begin
        args = parse_args(["--version"])
        @test args.version == true
    end

    @testset "output mode" begin
        @testset "inplace" begin
            for flag in ["-i", "--inplace"]
                args = parse_args([flag, "foo.jl"])
                @test args.mode == InplaceMode
            end
        end

        @testset "check" begin
            for flag in ["-c", "--check"]
                args = parse_args([flag, "foo.jl"])
                @test args.mode == CheckMode
            end
        end

        @testset "stdout (default)" begin
            args = parse_args(["foo.jl"])
            @test args.mode == StdoutMode
        end

        @testset "mutual exclusion" begin
            @test_throws ParseArgsError parse_args(["--check", "--inplace", "foo.jl"])
            @test_throws ParseArgsError parse_args(["--check", "-o", "out.jl", "foo.jl"])
            @test_throws ParseArgsError parse_args(["--inplace", "--output=out.jl", "foo.jl"])
        end
    end

    @testset "boolean flags" begin
        @testset "diff" begin
            for flag in ["-d", "--diff"]
                args = parse_args([flag, "foo.jl"])
                @test args.diff == true
            end
        end

        @testset "verbose" begin
            for flag in ["-v", "--verbose"]
                args = parse_args([flag, "foo.jl"])
                @test args.verbose == true
            end
        end

        @testset "format_markdown" begin
            args = parse_args(["--format_markdown", "foo.jl"])
            @test args.format_markdown == true
        end

        @testset "prioritize-config-file" begin
            args = parse_args(["--prioritize-config-file", "foo.jl"])
            @test args.config_priority == true
        end
    end

    @testset "output" begin
        @testset "-o flag" begin
            args = parse_args(["-o", "out.jl", "foo.jl"])
            @test args.outputfile == "out.jl"
        end

        @testset "--output= flag" begin
            args = parse_args(["--output=out.jl", "foo.jl"])
            @test args.outputfile == "out.jl"
        end

        @testset "-o without argument" begin
            @test_throws ParseArgsError parse_args(["-o"])
        end
    end

    @testset "stdin-filename" begin
        args = parse_args(["--stdin-filename=myfile.jl"])
        @test args.stdin_filename == "myfile.jl"
    end

    @testset "config-dir" begin
        args = parse_args(["--config-dir=/some/path"])
        @test args.config_dir == "/some/path"
    end

    @testset "style" begin
        expected = Dict(
            "default" => DefaultStyle(), "yas" => YASStyle(), "blue" => BlueStyle(),
            "sciml" => SciMLStyle(), "minimal" => MinimalStyle(),
        )
        for (name, style) in expected
            args = parse_args(["--style=$name", "foo.jl"])
            @test args.format_options[:style] == style
        end
        @test_throws ParseArgsError parse_args(["--style=nonexistent", "foo.jl"])
    end

    @testset "ignore patterns" begin
        @testset "single pattern" begin
            args = parse_args(["--ignore=*.tmp", "foo.jl"])
            @test args.ignore_patterns == ["*.tmp"]
        end

        @testset "multiple patterns" begin
            args = parse_args(["--ignore=*.tmp", "--ignore=*/test/*", "foo.jl"])
            @test args.ignore_patterns == ["*.tmp", "*/test/*"]
        end
    end

    @testset "line ranges" begin
        @testset "single range" begin
            args = parse_args(["--lines=1:10", "foo.jl"])
            @test args.line_ranges == [(1, 10)]
        end

        @testset "multiple ranges" begin
            args = parse_args(["--lines=1:10", "--lines=42:47", "foo.jl"])
            @test args.line_ranges == [(1, 10), (42, 47)]
        end

        @testset "malformed range" begin
            @test_throws ParseArgsError parse_args(["--lines=abc", "foo.jl"])
        end

        @testset "start greater than stop" begin
            @test_throws ParseArgsError parse_args(["--lines=5:2", "foo.jl"])
        end
    end

    @testset "integer format options" begin
        @testset "indent" begin
            args = parse_args(["--indent=2", "foo.jl"])
            @test args.format_options[:indent] == 2
        end

        @testset "margin" begin
            args = parse_args(["--margin=80", "foo.jl"])
            @test args.format_options[:margin] == 80
        end

        @testset "sciml_margin_overrun" begin
            args = parse_args(["--sciml_margin_overrun=10", "foo.jl"])
            @test args.format_options[:sciml_margin_overrun] == 10
        end
    end

    @testset "string format options" begin
        @testset "normalize_line_endings" begin
            for mode in ["auto", "unix", "windows"]
                args = parse_args(["--normalize_line_endings=$mode", "foo.jl"])
                @test args.format_options[:normalize_line_endings] == mode
            end
        end
    end

    @testset "boolean format options" begin
        boolean_options = [
            :always_for_in,
            :whitespace_typedefs,
            :remove_extra_newlines,
            :import_to_using,
            :pipe_to_function_call,
            :short_to_long_function_def,
            :always_use_return,
            :whitespace_in_kwargs,
            :format_docstrings,
            :align_struct_field,
            :align_assignment,
            :align_conditional,
            :align_pair_arrow,
            :trailing_comma,
            :trailing_zero,
            :v2_stable_multiline_strings,
            :conditional_to_if,
        ]

        @testset "$opt" for opt in boolean_options
            # --flag sets to true
            args = parse_args(["--$opt", "foo.jl"])
            @test args.format_options[opt] == true

            # --no-flag sets to false
            args = parse_args(["--no-$opt", "foo.jl"])
            @test args.format_options[opt] == false
        end

        @testset "only set options appear in format_options" begin
            args = parse_args(["--always_for_in", "foo.jl"])
            @test haskey(args.format_options, :always_for_in)
            @test !haskey(args.format_options, :trailing_comma)
        end
    end

    @testset "positional paths" begin
        args = parse_args(["foo.jl"])
        @test args.paths == ["foo.jl"]

        args = parse_args(["foo.jl", "bar.jl", "src/"])
        @test args.paths == ["foo.jl", "bar.jl", "src/"]
    end

    @testset "mixed flags and paths" begin
        args = parse_args(["--inplace", "--style=blue", "--indent=2", "src/", "lib/"])
        @test args.mode == InplaceMode
        @test args.format_options[:style] == BlueStyle()
        @test args.format_options[:indent] == 2
        @test args.paths == ["src/", "lib/"]
    end

    @testset "last value wins for repeated options" begin
        args = parse_args(["--style=blue", "--style=yas", "foo.jl"])
        @test args.format_options[:style] == YASStyle()

        args = parse_args(["--indent=2", "--indent=4", "foo.jl"])
        @test args.format_options[:indent] == 4

        args = parse_args(["--always_for_in", "--no-always_for_in", "foo.jl"])
        @test args.format_options[:always_for_in] == false
    end

    @testset "stdin marker" begin
        args = parse_args(["-"])
        @test args.paths == ["-"]
    end
end

end # module
