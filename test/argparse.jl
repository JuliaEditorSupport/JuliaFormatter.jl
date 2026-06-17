module ArgparseTests

using Test: @test, @testset, @test_throws, @test_logs
using JuliaFormatter.ArgParse: ParseArgsError, ParsedArgs, parse_args, parse_raw, PARSER,
    StdoutMode, InplaceMode, CheckMode
using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle

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
            @test args.verbose == false
            @test args.format_markdown == false
            @test args.config_priority == false
            @test args.outputfile === nothing
            @test args.stdin_filename == "stdin"
            @test args.config_dir == ""
            @test args.ignore_patterns == []
            @test args.line_ranges == []
            @test args.format_options == Dict{Symbol,Any}()
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
        end

        @testset "simple flags" begin
            @test parse_args(["-d"]).diff == true
            @test parse_args(["-v"]).verbose == true
            @test parse_args(["--format_markdown"]).format_markdown == true
            @test parse_args(["--prioritize-config-file"]).config_priority == true
        end

        @testset "string options" begin
            @test parse_args(["--stdin-filename=foo.jl"]).stdin_filename == "foo.jl"
            @test parse_args(["--config-dir=/some/path"]).config_dir == "/some/path"
        end

        @testset "ignore patterns" begin
            args = parse_args(["--ignore=*.tmp", "--ignore=*/test/*"])
            @test args.ignore_patterns == ["*.tmp", "*/test/*"]
            @test parse_args(["f.jl"]).ignore_patterns == []
        end

        @testset "line ranges" begin
            args = parse_args(["--lines=1:10", "--lines=42:47"])
            @test args.line_ranges == [(1, 10), (42, 47)]
            @test parse_args(["f.jl"]).line_ranges == []
        end

        @testset "format options from value options" begin
            args = parse_args(["--indent=2", "--margin=80"])
            @test args.format_options[:indent] == 2
            @test args.format_options[:margin] == 80
        end

        @testset "format options from negatable flags" begin
            args = parse_args(["--always_for_in"])
            @test args.format_options[:always_for_in] == true

            args = parse_args(["--no-always_for_in"])
            @test args.format_options[:always_for_in] == false
        end

        @testset "unset format options are absent" begin
            args = parse_args(["--always_for_in"])
            @test haskey(args.format_options, :always_for_in)
            @test !haskey(args.format_options, :trailing_comma)
        end

        @testset "mixed flags and paths" begin
            args = parse_args(["-i", "--margin=80", "-d", "-v", "--style=blue", "src/", "lib/"])
            @test args.mode == InplaceMode
            @test args.diff == true
            @test args.verbose == true
            @test args.format_options[:style] == BlueStyle()
            @test args.format_options[:margin] == 80
            @test args.paths == ["src/", "lib/"]
        end

        @testset "flags can appear in any order" begin
            a = parse_args(["-c", "-d", "--margin=80"])
            b = parse_args(["--margin=80", "-d", "-c"])
            @test a.mode == b.mode == CheckMode
            @test a.diff == b.diff == true
            @test a.format_options[:margin] == b.format_options[:margin] == 80
        end

        @testset "all formatting options (new-style)" begin
            @test parse_args(["--style=default"]).format_options[:style] == DefaultStyle()
            @test parse_args(["--style=yas"]).format_options[:style] == YASStyle()
            @test parse_args(["--style=blue"]).format_options[:style] == BlueStyle()
            @test parse_args(["--style=sciml"]).format_options[:style] == SciMLStyle()
            @test parse_args(["--style=minimal"]).format_options[:style] == MinimalStyle()
            @test parse_args(["--indent=2"]).format_options[:indent] == 2
            @test parse_args(["--margin=80"]).format_options[:margin] == 80
            @test parse_args(["--sciml-margin-overrun=10"]).format_options[:sciml_margin_overrun] == 10
            @test parse_args(["--normalize-line-endings=unix"]).format_options[:normalize_line_endings] == "unix"
            @test parse_args(["--always-for-in=true"]).format_options[:always_for_in] == true
            @test parse_args(["--always-for-in=false"]).format_options[:always_for_in] == false
            @test parse_args(["--whitespace-typedefs=true"]).format_options[:whitespace_typedefs] == true
            @test parse_args(["--whitespace-typedefs=false"]).format_options[:whitespace_typedefs] == false
            @test parse_args(["--remove-extra-newlines=true"]).format_options[:remove_extra_newlines] == true
            @test parse_args(["--remove-extra-newlines=false"]).format_options[:remove_extra_newlines] == false
            @test parse_args(["--import-to-using=true"]).format_options[:import_to_using] == true
            @test parse_args(["--import-to-using=false"]).format_options[:import_to_using] == false
            @test parse_args(["--pipe-to-function-call=true"]).format_options[:pipe_to_function_call] == true
            @test parse_args(["--pipe-to-function-call=false"]).format_options[:pipe_to_function_call] == false
            @test parse_args(["--short-to-long-function-def=true"]).format_options[:short_to_long_function_def] == true
            @test parse_args(["--short-to-long-function-def=false"]).format_options[:short_to_long_function_def] == false
            @test parse_args(["--always-use-return=true"]).format_options[:always_use_return] == true
            @test parse_args(["--always-use-return=false"]).format_options[:always_use_return] == false
            @test parse_args(["--whitespace-in-kwargs=true"]).format_options[:whitespace_in_kwargs] == true
            @test parse_args(["--whitespace-in-kwargs=false"]).format_options[:whitespace_in_kwargs] == false
            @test parse_args(["--format-docstrings=true"]).format_options[:format_docstrings] == true
            @test parse_args(["--format-docstrings=false"]).format_options[:format_docstrings] == false
            @test parse_args(["--align-struct-field=true"]).format_options[:align_struct_field] == true
            @test parse_args(["--align-struct-field=false"]).format_options[:align_struct_field] == false
            @test parse_args(["--align-assignment=true"]).format_options[:align_assignment] == true
            @test parse_args(["--align-assignment=false"]).format_options[:align_assignment] == false
            @test parse_args(["--align-conditional=true"]).format_options[:align_conditional] == true
            @test parse_args(["--align-conditional=false"]).format_options[:align_conditional] == false
            @test parse_args(["--align-pair-arrow=true"]).format_options[:align_pair_arrow] == true
            @test parse_args(["--align-pair-arrow=false"]).format_options[:align_pair_arrow] == false
            @test parse_args(["--trailing-comma=true"]).format_options[:trailing_comma] == true
            @test parse_args(["--trailing-comma=false"]).format_options[:trailing_comma] == false
            @test parse_args(["--trailing-zero=true"]).format_options[:trailing_zero] == true
            @test parse_args(["--trailing-zero=false"]).format_options[:trailing_zero] == false
            @test parse_args(["--v2-stable-multiline-strings=true"]).format_options[:v2_stable_multiline_strings] == true
            @test parse_args(["--v2-stable-multiline-strings=false"]).format_options[:v2_stable_multiline_strings] == false
            @test parse_args(["--conditional-to-if=true"]).format_options[:conditional_to_if] == true
            @test parse_args(["--conditional-to-if=false"]).format_options[:conditional_to_if] == false
        end

        @testset "deprecated underscored options still work" begin
            @test parse_args(["--sciml_margin_overrun=10"]).format_options[:sciml_margin_overrun] == 10
            @test parse_args(["--normalize_line_endings=unix"]).format_options[:normalize_line_endings] == "unix"
        end

        @testset "all formatting options (deprecated negatable flags still work)" begin
            @test parse_args(["--always_for_in"]).format_options[:always_for_in] == true
            @test parse_args(["--no-always_for_in"]).format_options[:always_for_in] == false
            @test parse_args(["--whitespace_typedefs"]).format_options[:whitespace_typedefs] == true
            @test parse_args(["--no-whitespace_typedefs"]).format_options[:whitespace_typedefs] == false
            @test parse_args(["--remove_extra_newlines"]).format_options[:remove_extra_newlines] == true
            @test parse_args(["--no-remove_extra_newlines"]).format_options[:remove_extra_newlines] == false
            @test parse_args(["--import_to_using"]).format_options[:import_to_using] == true
            @test parse_args(["--no-import_to_using"]).format_options[:import_to_using] == false
            @test parse_args(["--pipe_to_function_call"]).format_options[:pipe_to_function_call] == true
            @test parse_args(["--no-pipe_to_function_call"]).format_options[:pipe_to_function_call] == false
            @test parse_args(["--short_to_long_function_def"]).format_options[:short_to_long_function_def] == true
            @test parse_args(["--no-short_to_long_function_def"]).format_options[:short_to_long_function_def] == false
            @test parse_args(["--always_use_return"]).format_options[:always_use_return] == true
            @test parse_args(["--no-always_use_return"]).format_options[:always_use_return] == false
            @test parse_args(["--whitespace_in_kwargs"]).format_options[:whitespace_in_kwargs] == true
            @test parse_args(["--no-whitespace_in_kwargs"]).format_options[:whitespace_in_kwargs] == false
            @test parse_args(["--format_docstrings"]).format_options[:format_docstrings] == true
            @test parse_args(["--no-format_docstrings"]).format_options[:format_docstrings] == false
            @test parse_args(["--align_struct_field"]).format_options[:align_struct_field] == true
            @test parse_args(["--no-align_struct_field"]).format_options[:align_struct_field] == false
            @test parse_args(["--align_assignment"]).format_options[:align_assignment] == true
            @test parse_args(["--no-align_assignment"]).format_options[:align_assignment] == false
            @test parse_args(["--align_conditional"]).format_options[:align_conditional] == true
            @test parse_args(["--no-align_conditional"]).format_options[:align_conditional] == false
            @test parse_args(["--align_pair_arrow"]).format_options[:align_pair_arrow] == true
            @test parse_args(["--no-align_pair_arrow"]).format_options[:align_pair_arrow] == false
            @test parse_args(["--trailing_comma"]).format_options[:trailing_comma] == true
            @test parse_args(["--no-trailing_comma"]).format_options[:trailing_comma] == false
            @test parse_args(["--trailing_zero"]).format_options[:trailing_zero] == true
            @test parse_args(["--no-trailing_zero"]).format_options[:trailing_zero] == false
            @test parse_args(["--v2_stable_multiline_strings"]).format_options[:v2_stable_multiline_strings] == true
            @test parse_args(["--no-v2_stable_multiline_strings"]).format_options[:v2_stable_multiline_strings] == false
            @test parse_args(["--conditional_to_if"]).format_options[:conditional_to_if] == true
            @test parse_args(["--no-conditional_to_if"]).format_options[:conditional_to_if] == false
        end

        @testset "new-style option overrides deprecated flag (last wins)" begin
            args = parse_args(["--always_for_in", "--always-for-in=false"])
            @test args.format_options[:always_for_in] == false
            args = parse_args(["--always-for-in=false", "--always_for_in"])
            @test args.format_options[:always_for_in] == true
        end
    end
end

end # module
