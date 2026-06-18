module ParseArgsTests

using Test: @test, @testset, @test_throws
using JuliaFormatter.ArgParse:
    ParsedArgs, ParseArgsError, parse_args, OutputMode, StdoutMode, InplaceMode, CheckMode
using JuliaFormatter:
    DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, Configuration, _Unset

@testset "parse_args" begin
    @testset "empty args" begin
        args = parse_args(String[])
        @test args.paths == []
        @test args.mode == StdoutMode
        @test args.diff == false
        @test args.verbose == false
        @test args.config_priority == false
        @test args.outputfile === nothing
        @test args.stdin_filename == "stdin"
        @test args.config_dir == ""
        @test args.line_ranges == []
        @test args.config.style === nothing
        @test args.config.ignore === nothing
        @test args.config.format_markdown === nothing
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
            @test args.config.format_markdown == true
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
            @test args.config.style == style
        end
        @test_throws ParseArgsError parse_args(["--style=nonexistent", "foo.jl"])
    end

    @testset "ignore patterns" begin
        @testset "single pattern" begin
            args = parse_args(["--ignore=*.tmp", "foo.jl"])
            @test args.config.ignore == ["*.tmp"]
        end

        @testset "multiple patterns" begin
            args = parse_args(["--ignore=*.tmp", "--ignore=*/test/*", "foo.jl"])
            @test args.config.ignore == ["*.tmp", "*/test/*"]
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
            @test args.config.options.indent == 2
        end

        @testset "margin" begin
            args = parse_args(["--margin=80", "foo.jl"])
            @test args.config.options.margin == 80
        end

        @testset "sciml-margin-overrun" begin
            args = parse_args(["--sciml-margin-overrun=10", "foo.jl"])
            @test args.config.options.sciml_margin_overrun == 10
        end

        @testset "sciml_margin_overrun (deprecated)" begin
            args = parse_args(["--sciml_margin_overrun=10", "foo.jl"])
            @test args.config.options.sciml_margin_overrun == 10
        end
    end

    @testset "string format options" begin
        @testset "normalize-line-endings" begin
            for mode in ["auto", "unix", "windows"]
                args = parse_args(["--normalize-line-endings=$mode", "foo.jl"])
                @test args.config.options.normalize_line_endings == mode
            end
        end

        @testset "normalize_line_endings (deprecated)" begin
            for mode in ["auto", "unix", "windows"]
                args = parse_args(["--normalize_line_endings=$mode", "foo.jl"])
                @test args.config.options.normalize_line_endings == mode
            end
        end
    end

    @testset "for-in-replacement" begin
        for val in ["in", "=", "∈"]
            args = parse_args(["--for-in-replacement=$val", "foo.jl"])
            @test args.config.options.for_in_replacement == val
        end
    end

    @testset "boolean format options (new-style)" begin
        boolean_options = Dict(
            "align-assignment" => :align_assignment,
            "align-conditional" => :align_conditional,
            "align-matrix" => :align_matrix,
            "align-pair-arrow" => :align_pair_arrow,
            "align-struct-field" => :align_struct_field,
            "always-for-in" => :always_for_in,
            "always-use-return" => :always_use_return,
            "annotate-untyped-fields-with-any" => :annotate_untyped_fields_with_any,
            "conditional-to-if" => :conditional_to_if,
            "disallow-single-arg-nesting" => :disallow_single_arg_nesting,
            "force-long-function-def" => :force_long_function_def,
            "format-docstrings" => :format_docstrings,
            "import-to-using" => :import_to_using,
            "indent-submodule" => :indent_submodule,
            "join-lines-based-on-source" => :join_lines_based_on_source,
            "long-to-short-function-def" => :long_to_short_function_def,
            "pipe-to-function-call" => :pipe_to_function_call,
            "remove-extra-newlines" => :remove_extra_newlines,
            "separate-kwargs-with-semicolon" => :separate_kwargs_with_semicolon,
            "short-circuit-to-if" => :short_circuit_to_if,
            "short-to-long-function-def" => :short_to_long_function_def,
            "surround-whereop-typeparameters" => :surround_whereop_typeparameters,
            "trailing-comma" => :trailing_comma,
            "trailing-zero" => :trailing_zero,
            "v2-stable-multiline-strings" => :v2_stable_multiline_strings,
            # Note: variable-call-indent is multi/String, tested separately
            "whitespace-in-kwargs" => :whitespace_in_kwargs,
            "whitespace-ops-in-indices" => :whitespace_ops_in_indices,
            "whitespace-typedefs" => :whitespace_typedefs,
            "yas-style-nesting" => :yas_style_nesting,
        )

        @testset "$cli_name" for (cli_name, dest) in sort(collect(boolean_options))
            args = parse_args(["--$cli_name=true", "foo.jl"])
            @test getfield(args.config.options, dest) == true

            args = parse_args(["--$cli_name=false", "foo.jl"])
            @test getfield(args.config.options, dest) == false
        end

        @testset "only set options appear in config" begin
            args = parse_args(["--always-for-in=true", "foo.jl"])
            @test args.config.options.always_for_in == true
            @test args.config.options.trailing_comma isa _Unset
        end

        @testset "variable-call-indent (multi)" begin
            args = parse_args(["--variable-call-indent=Dict", "foo.jl"])
            @test args.config.options.variable_call_indent == ["Dict"]

            args = parse_args(["--variable-call-indent=Dict", "--variable-call-indent=Foo", "foo.jl"])
            @test args.config.options.variable_call_indent == ["Dict", "Foo"]

            args = parse_args(["foo.jl"])
            @test args.config.options.variable_call_indent isa _Unset
        end

        @testset "nothing values for always-for-in and trailing-comma" begin
            args = parse_args(["--always-for-in=nothing", "foo.jl"])
            @test args.config.options.always_for_in === nothing
            args = parse_args(["--trailing-comma=nothing", "foo.jl"])
            @test args.config.options.trailing_comma === nothing
        end
    end

    @testset "boolean format options (deprecated negatable flags)" begin
        deprecated_options = [
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

        @testset "$opt" for opt in deprecated_options
            args = parse_args(["--$opt", "foo.jl"])
            @test getfield(args.config.options, opt) == true

            args = parse_args(["--no-$opt", "foo.jl"])
            @test getfield(args.config.options, opt) == false
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
        @test args.config.style == BlueStyle()
        @test args.config.options.indent == 2
        @test args.paths == ["src/", "lib/"]
    end

    @testset "last value wins for repeated options" begin
        args = parse_args(["--style=blue", "--style=yas", "foo.jl"])
        @test args.config.style == YASStyle()

        args = parse_args(["--indent=2", "--indent=4", "foo.jl"])
        @test args.config.options.indent == 4

        args = parse_args(["--always-for-in=true", "--always-for-in=false", "foo.jl"])
        @test args.config.options.always_for_in == false

        # deprecated and new-style can be mixed, last wins
        args = parse_args(["--always_for_in", "--always-for-in=false", "foo.jl"])
        @test args.config.options.always_for_in == false
        args = parse_args(["--always-for-in=false", "--always_for_in", "foo.jl"])
        @test args.config.options.always_for_in == true
    end

    @testset "stdin marker" begin
        args = parse_args(["-"])
        @test args.paths == ["-"]
    end
end

end # module
