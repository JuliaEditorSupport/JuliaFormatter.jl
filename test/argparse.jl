module ArgparseTests

using Test: @test, @testset, @test_throws, @test_logs
using JuliaFormatter.ArgParse: ParseArgsError, ParsedArgs, parse_args, parse_raw, PARSER,
    StdoutMode, InplaceMode, CheckMode
using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle, _Unset, Options

@testset "argparse" begin
    @testset "parse_raw" begin
        @testset "empty args" begin
            raw = parse_raw(PARSER, String[])
            @test raw[:paths] == []
        end

        @testset "flag short and long forms" begin
            raw = parse_raw(PARSER, ["-c", "foo.jl"])
            @test raw[:check] == true
            raw = parse_raw(PARSER, ["--check", "foo.jl"])
            @test raw[:check] == true
        end

        @testset "option with = and space" begin
            raw = parse_raw(PARSER, ["--margin=80"])
            @test raw[:margin] == 80
            raw = parse_raw(PARSER, ["--margin", "80"])
            @test raw[:margin] == 80
        end

        @testset "option with multiple names" begin
            raw = parse_raw(PARSER, ["-o", "out.jl"])
            @test raw[:outputfile] == "out.jl"
            raw = parse_raw(PARSER, ["--output=out.jl"])
            @test raw[:outputfile] == "out.jl"
            raw = parse_raw(PARSER, ["--output", "out.jl"])
            @test raw[:outputfile] == "out.jl"
        end

        @testset "negatable flag (deprecated)" begin
            raw = parse_raw(PARSER, ["--always_for_in"])
            @test raw[:always_for_in] == true
            raw = parse_raw(PARSER, ["--no-always_for_in"])
            @test raw[:always_for_in] == false
        end

        @testset "boolean option with = syntax" begin
            raw = parse_raw(PARSER, ["--always-for-in=true"])
            @test raw[:always_for_in] == true
            raw = parse_raw(PARSER, ["--always-for-in=false"])
            @test raw[:always_for_in] == false
        end

        @testset "multi option collects values" begin
            raw = parse_raw(PARSER, ["--ignore=*.tmp", "--ignore=*/test/*"])
            @test raw[:ignore] == ["*.tmp", "*/test/*"]
        end

        @testset "last value wins for non-multi" begin
            raw = parse_raw(PARSER, ["--margin=10", "--margin=20"])
            @test raw[:margin] == 20
        end

        @testset "positional args preserved in order" begin
            raw = parse_raw(PARSER, ["a.jl", "-c", "b.jl", "--margin=1", "c.jl"])
            @test raw[:paths] == ["a.jl", "b.jl", "c.jl"]
        end

        @testset "unknown flags treated as positional" begin
            raw = parse_raw(PARSER, ["--unknown", "foo.jl"])
            @test raw[:paths] == ["--unknown", "foo.jl"]
        end

        @testset "missing value for option" begin
            @test_throws ParseArgsError parse_raw(PARSER, ["--margin"])
        end

        @testset "invalid value for option" begin
            @test_throws ParseArgsError parse_raw(PARSER, ["--margin=abc"])
        end

        @testset "line ranges" begin
            raw = parse_raw(PARSER, ["--lines=1:10", "--lines=42:47"])
            @test raw[:lines] == [(1, 10), (42, 47)]
        end

        @testset "line range errors" begin
            @test_throws ParseArgsError parse_raw(PARSER, ["--lines=abc"])
            @test_throws ParseArgsError parse_raw(PARSER, ["--lines=5:2"])
        end
    end

    @testset "parse_args" begin
        @testset "defaults" begin
            args = parse_args(String[])
            @test args.help == false
            @test args.version == false
            @test args.mode == StdoutMode
            @test args.diff == false
            @test args.config_priority == false
            @test args.ignore_config == false
            @test args.outputfile === nothing
            @test args.stdin_filename == "stdin"
            @test args.config_dir == ""
            @test args.line_ranges == []
            @test args.config.options == Options{_Unset}()
            @test args.config.ignore === nothing
            @test args.config.verbose === nothing
            @test args.config.format_markdown === nothing
            @test args.config.overwrite === nothing
            @test args.paths == []
        end

        @testset "help and version" begin
            @test parse_args(["-h"]).help == true
            @test parse_args(["--help"]).help == true
            @test parse_args(["--version"]).version == true
        end

        @testset "output mode" begin
            @test parse_args(["-c"]).mode == CheckMode
            @test parse_args(["--check"]).mode == CheckMode
            @test parse_args(["-i"]).mode == InplaceMode
            @test parse_args(["--inplace"]).mode == InplaceMode
            @test parse_args(["f.jl"]).mode == StdoutMode
        end

        @testset "output mode mutual exclusion" begin
            @test_throws ParseArgsError parse_args(["--check", "--inplace"])
            @test_throws ParseArgsError parse_args(["--check", "-o", "out.jl"])
            @test_throws ParseArgsError parse_args(["--inplace", "--output=out.jl"])
        end

        @testset "outputfile" begin
            args = parse_args(["-o", "out.jl"])
            @test args.outputfile == "out.jl"
            args = parse_args(["--output=out.jl"])
            @test args.outputfile == "out.jl"
            @test parse_args(["f.jl"]).outputfile === nothing
            @test_throws ParseArgsError parse_args(["-o"])
        end

        @testset "simple flags" begin
            @test parse_args(["-d"]).diff == true
            @test parse_args(["-v"]).verbose == true
            @test parse_args(["--prioritize-config-file"]).config_priority == true
            @test parse_args(["--ignore-config"]).ignore_config == true
        end

        @testset "format-markdown" begin
            # Not passed: nothing (defer to config file)
            @test parse_args(["f.jl"]).config.format_markdown === nothing
            # Explicit true
            @test parse_args(["--format-markdown=true"]).config.format_markdown === true
            # Explicit false (can override config file)
            @test parse_args(["--format-markdown=false"]).config.format_markdown === false
            # Deprecated flag (still works, sets true)
            @test parse_args(["--format_markdown"]).config.format_markdown === true
        end

        @testset "config file options mutual exclusion" begin
            @test_throws ParseArgsError parse_args(["--prioritize-config-file", "--ignore-config"])
            @test_throws ParseArgsError parse_args(["--ignore-config", "--config-dir", "foo"])
        end

        @testset "string options" begin
            @test parse_args(["--stdin-filename=foo.jl"]).stdin_filename == "foo.jl"
            @test parse_args(["--config-dir=/some/path"]).config_dir == "/some/path"
        end

        @testset "style" begin
            @test parse_args(["--style=default"]).config.style == DefaultStyle()
            @test parse_args(["--style=yas"]).config.style == YASStyle()
            @test parse_args(["--style=blue"]).config.style == BlueStyle()
            @test parse_args(["--style=sciml"]).config.style == SciMLStyle()
            @test parse_args(["--style=minimal"]).config.style == MinimalStyle()
            @test_throws ParseArgsError parse_args(["--style=nonexistent"])
        end

        @testset "ignore patterns" begin
            args = parse_args(["--ignore=*.tmp"])
            @test args.config.ignore == ["*.tmp"]
            args = parse_args(["--ignore=*.tmp", "--ignore=*/test/*"])
            @test args.config.ignore == ["*.tmp", "*/test/*"]
            @test parse_args(["f.jl"]).config.ignore === nothing
        end

        @testset "line ranges" begin
            args = parse_args(["--lines=1:10"])
            @test args.line_ranges == [(1, 10)]
            args = parse_args(["--lines=1:10", "--lines=42:47"])
            @test args.line_ranges == [(1, 10), (42, 47)]
            @test parse_args(["f.jl"]).line_ranges == []
        end

        @testset "format options from value options" begin
            args = parse_args(["--indent=2", "--margin=80"])
            @test args.config.options.indent == 2
            @test args.config.options.margin == 80
        end

        @testset "format options from negatable flags" begin
            args = parse_args(["--always_for_in"])
            @test args.config.options.always_for_in == true

            args = parse_args(["--no-always_for_in"])
            @test args.config.options.always_for_in == false
        end

        @testset "unset format options are absent" begin
            args = parse_args(["--always_for_in"])
            @test args.config.options.always_for_in == true
            @test args.config.options.trailing_comma === _Unset()
        end

        @testset "mixed flags and paths" begin
            args = parse_args(["-i", "--margin=80", "-d", "-v", "--style=blue", "src/", "lib/"])
            @test args.mode == InplaceMode
            @test args.diff == true
            @test args.verbose == true
            @test args.config.style == BlueStyle()
            @test args.config.options.margin == 80
            @test args.paths == ["src/", "lib/"]
        end

        @testset "flags can appear in any order" begin
            a = parse_args(["-c", "-d", "--margin=80"])
            b = parse_args(["--margin=80", "-d", "-c"])
            @test a.mode == b.mode == CheckMode
            @test a.diff == b.diff == true
            @test a.config.options.margin == b.config.options.margin == 80
        end

        @testset "for-in-replacement" begin
            for val in ["in", "=", "∈"]
                @test parse_args(["--for-in-replacement=$val"]).config.options.for_in_replacement == val
            end
        end

        @testset "normalize-line-endings" begin
            for mode in ["auto", "unix", "windows"]
                @test parse_args(["--normalize-line-endings=$mode"]).config.options.normalize_line_endings == mode
            end
        end

        @testset "all formatting options (new-style)" begin
            # int options
            @test parse_args(["--indent=2"]).config.options.indent == 2
            @test parse_args(["--margin=80"]).config.options.margin == 80
            @test parse_args(["--sciml-margin-overrun=10"]).config.options.sciml_margin_overrun == 10
            # bool options (alphabetical)
            @test parse_args(["--align-assignment=true"]).config.options.align_assignment == true
            @test parse_args(["--align-assignment=false"]).config.options.align_assignment == false
            @test parse_args(["--align-conditional=true"]).config.options.align_conditional == true
            @test parse_args(["--align-conditional=false"]).config.options.align_conditional == false
            @test parse_args(["--align-matrix=true"]).config.options.align_matrix == true
            @test parse_args(["--align-matrix=false"]).config.options.align_matrix == false
            @test parse_args(["--align-pair-arrow=true"]).config.options.align_pair_arrow == true
            @test parse_args(["--align-pair-arrow=false"]).config.options.align_pair_arrow == false
            @test parse_args(["--align-struct-field=true"]).config.options.align_struct_field == true
            @test parse_args(["--align-struct-field=false"]).config.options.align_struct_field == false
            @test parse_args(["--always-for-in=true"]).config.options.always_for_in == true
            @test parse_args(["--always-for-in=false"]).config.options.always_for_in == false
            @test parse_args(["--always-for-in=nothing"]).config.options.always_for_in === nothing
            @test parse_args(["--always-use-return=true"]).config.options.always_use_return == true
            @test parse_args(["--always-use-return=false"]).config.options.always_use_return == false
            @test parse_args(["--annotate-untyped-fields-with-any=true"]).config.options.annotate_untyped_fields_with_any == true
            @test parse_args(["--annotate-untyped-fields-with-any=false"]).config.options.annotate_untyped_fields_with_any == false
            @test parse_args(["--conditional-to-if=true"]).config.options.conditional_to_if == true
            @test parse_args(["--conditional-to-if=false"]).config.options.conditional_to_if == false
            @test parse_args(["--disallow-single-arg-nesting=true"]).config.options.disallow_single_arg_nesting == true
            @test parse_args(["--disallow-single-arg-nesting=false"]).config.options.disallow_single_arg_nesting == false
            @test parse_args(["--enforce-triplequoted-docstrings=true"]).config.options.enforce_triplequoted_docstrings == true
            @test parse_args(["--enforce-triplequoted-docstrings=false"]).config.options.enforce_triplequoted_docstrings == false
            @test parse_args(["--force-long-function-def=true"]).config.options.force_long_function_def == true
            @test parse_args(["--force-long-function-def=false"]).config.options.force_long_function_def == false
            @test parse_args(["--format-docstrings=true"]).config.options.format_docstrings == true
            @test parse_args(["--format-docstrings=false"]).config.options.format_docstrings == false
            @test parse_args(["--import-to-using=true"]).config.options.import_to_using == true
            @test parse_args(["--import-to-using=false"]).config.options.import_to_using == false
            @test parse_args(["--indent-submodule=true"]).config.options.indent_submodule == true
            @test parse_args(["--indent-submodule=false"]).config.options.indent_submodule == false
            @test parse_args(["--join-lines-based-on-source=true"]).config.options.join_lines_based_on_source == true
            @test parse_args(["--join-lines-based-on-source=false"]).config.options.join_lines_based_on_source == false
            @test parse_args(["--long-to-short-function-def=true"]).config.options.long_to_short_function_def == true
            @test parse_args(["--long-to-short-function-def=false"]).config.options.long_to_short_function_def == false
            @test parse_args(["--pipe-to-function-call=true"]).config.options.pipe_to_function_call == true
            @test parse_args(["--pipe-to-function-call=false"]).config.options.pipe_to_function_call == false
            @test parse_args(["--remove-extra-newlines=true"]).config.options.remove_extra_newlines == true
            @test parse_args(["--remove-extra-newlines=false"]).config.options.remove_extra_newlines == false
            @test parse_args(["--separate-kwargs-with-semicolon=true"]).config.options.separate_kwargs_with_semicolon == true
            @test parse_args(["--separate-kwargs-with-semicolon=false"]).config.options.separate_kwargs_with_semicolon == false
            @test parse_args(["--short-circuit-to-if=true"]).config.options.short_circuit_to_if == true
            @test parse_args(["--short-circuit-to-if=false"]).config.options.short_circuit_to_if == false
            @test parse_args(["--short-to-long-function-def=true"]).config.options.short_to_long_function_def == true
            @test parse_args(["--short-to-long-function-def=false"]).config.options.short_to_long_function_def == false
            @test parse_args(["--surround-whereop-typeparameters=true"]).config.options.surround_whereop_typeparameters == true
            @test parse_args(["--surround-whereop-typeparameters=false"]).config.options.surround_whereop_typeparameters == false
            @test parse_args(["--trailing-comma=true"]).config.options.trailing_comma == true
            @test parse_args(["--trailing-comma=false"]).config.options.trailing_comma == false
            @test parse_args(["--trailing-comma=nothing"]).config.options.trailing_comma === nothing
            @test parse_args(["--trailing-zero=true"]).config.options.trailing_zero == true
            @test parse_args(["--trailing-zero=false"]).config.options.trailing_zero == false
            @test parse_args(["--transform-syntax-in-macros=true"]).config.options.transform_syntax_in_macros == true
            @test parse_args(["--transform-syntax-in-macros=false"]).config.options.transform_syntax_in_macros == false
            @test parse_args(["--v2-stable-multiline-strings=true"]).config.options.v2_stable_multiline_strings == true
            @test parse_args(["--v2-stable-multiline-strings=false"]).config.options.v2_stable_multiline_strings == false
            @test parse_args(["--variable-call-indent=Dict"]).config.options.variable_call_indent == ["Dict"]
            @test parse_args(["--variable-call-indent=Dict", "--variable-call-indent=Foo"]).config.options.variable_call_indent == ["Dict", "Foo"]
            @test parse_args(["--whitespace-in-kwargs=true"]).config.options.whitespace_in_kwargs == true
            @test parse_args(["--whitespace-in-kwargs=false"]).config.options.whitespace_in_kwargs == false
            @test parse_args(["--whitespace-ops-in-indices=true"]).config.options.whitespace_ops_in_indices == true
            @test parse_args(["--whitespace-ops-in-indices=false"]).config.options.whitespace_ops_in_indices == false
            @test parse_args(["--whitespace-typedefs=true"]).config.options.whitespace_typedefs == true
            @test parse_args(["--whitespace-typedefs=false"]).config.options.whitespace_typedefs == false
            @test parse_args(["--yas-style-nesting=true"]).config.options.yas_style_nesting == true
            @test parse_args(["--yas-style-nesting=false"]).config.options.yas_style_nesting == false
        end

        @testset "deprecated underscored options still work" begin
            @test parse_args(["--sciml_margin_overrun=10"]).config.options.sciml_margin_overrun == 10
            @test parse_args(["--normalize_line_endings=unix"]).config.options.normalize_line_endings == "unix"
        end

        @testset "all formatting options (deprecated negatable flags still work)" begin
            @test parse_args(["--always_for_in"]).config.options.always_for_in == true
            @test parse_args(["--no-always_for_in"]).config.options.always_for_in == false
            @test parse_args(["--whitespace_typedefs"]).config.options.whitespace_typedefs == true
            @test parse_args(["--no-whitespace_typedefs"]).config.options.whitespace_typedefs == false
            @test parse_args(["--remove_extra_newlines"]).config.options.remove_extra_newlines == true
            @test parse_args(["--no-remove_extra_newlines"]).config.options.remove_extra_newlines == false
            @test parse_args(["--import_to_using"]).config.options.import_to_using == true
            @test parse_args(["--no-import_to_using"]).config.options.import_to_using == false
            @test parse_args(["--pipe_to_function_call"]).config.options.pipe_to_function_call == true
            @test parse_args(["--no-pipe_to_function_call"]).config.options.pipe_to_function_call == false
            @test parse_args(["--short_to_long_function_def"]).config.options.short_to_long_function_def == true
            @test parse_args(["--no-short_to_long_function_def"]).config.options.short_to_long_function_def == false
            @test parse_args(["--always_use_return"]).config.options.always_use_return == true
            @test parse_args(["--no-always_use_return"]).config.options.always_use_return == false
            @test parse_args(["--whitespace_in_kwargs"]).config.options.whitespace_in_kwargs == true
            @test parse_args(["--no-whitespace_in_kwargs"]).config.options.whitespace_in_kwargs == false
            @test parse_args(["--format_docstrings"]).config.options.format_docstrings == true
            @test parse_args(["--no-format_docstrings"]).config.options.format_docstrings == false
            @test parse_args(["--align_struct_field"]).config.options.align_struct_field == true
            @test parse_args(["--no-align_struct_field"]).config.options.align_struct_field == false
            @test parse_args(["--align_assignment"]).config.options.align_assignment == true
            @test parse_args(["--no-align_assignment"]).config.options.align_assignment == false
            @test parse_args(["--align_conditional"]).config.options.align_conditional == true
            @test parse_args(["--no-align_conditional"]).config.options.align_conditional == false
            @test parse_args(["--align_pair_arrow"]).config.options.align_pair_arrow == true
            @test parse_args(["--no-align_pair_arrow"]).config.options.align_pair_arrow == false
            @test parse_args(["--trailing_comma"]).config.options.trailing_comma == true
            @test parse_args(["--no-trailing_comma"]).config.options.trailing_comma == false
            @test parse_args(["--trailing_zero"]).config.options.trailing_zero == true
            @test parse_args(["--no-trailing_zero"]).config.options.trailing_zero == false
            @test parse_args(["--v2_stable_multiline_strings"]).config.options.v2_stable_multiline_strings == true
            @test parse_args(["--no-v2_stable_multiline_strings"]).config.options.v2_stable_multiline_strings == false
            @test parse_args(["--conditional_to_if"]).config.options.conditional_to_if == true
            @test parse_args(["--no-conditional_to_if"]).config.options.conditional_to_if == false
        end

        @testset "last value wins for repeated options" begin
            @test parse_args(["--style=blue", "--style=yas"]).config.style == YASStyle()
            @test parse_args(["--indent=2", "--indent=4"]).config.options.indent == 4
            # new-style option overrides deprecated flag (and vice versa)
            args = parse_args(["--always_for_in", "--always-for-in=false"])
            @test args.config.options.always_for_in == false
            args = parse_args(["--always-for-in=false", "--always_for_in"])
            @test args.config.options.always_for_in == true
        end

        @testset "positional paths" begin
            @test parse_args(["foo.jl"]).paths == ["foo.jl"]
            @test parse_args(["foo.jl", "bar.jl", "src/"]).paths == ["foo.jl", "bar.jl", "src/"]
        end

        @testset "stdin marker" begin
            @test parse_args(["-"]).paths == ["-"]
        end

        @testset "variable-call-indent unset when not specified" begin
            @test parse_args(["f.jl"]).config.options.variable_call_indent isa _Unset
        end
    end
end

end # module
