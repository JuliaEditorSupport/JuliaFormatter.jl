module YasStyleTests

using JuliaFormatter.Internal: test_format
using Test
using JuliaFormatter: YASStyle
using JuliaFormatter: format_text

@testset "YAS Style" begin
    @testset "basic" begin
        str_ = "foo(; k =v)"
        str = "foo(; k=v)"
        test_format(str_, str, YASStyle(); indent=4, margin=80)

        str_ = "[a,]"
        str = "[a]"
        test_format(str_, str, YASStyle(); indent=4, margin=92)

        str_ = "T[a,]"
        str = "T[a]"
        test_format(str_, str, YASStyle(); indent=4, margin=92)

        str_ = "{a,}"
        str = "{a}"
        test_format(str_, str, YASStyle(); indent=4, margin=92)

        str_ = "T{a,}"
        str = "T{a}"
        test_format(str_, str, YASStyle(); indent=4, margin=92)

        str_ = "T(a,)"
        str = "T(a)"
        test_format(str_, str, YASStyle(); indent=4, margin=92)

        str_ = "(a,)"
        str = "(a,)"
        test_format(str_, str, YASStyle(); indent=4, margin=92)

        str_ = "@foo(a,)"
        str = "@foo(a,)"
        test_format(str_, str, YASStyle(); indent=4, margin=92)

        str_ = "a = (arg1, arg2, arg3)"
        str = """
        a = (arg1, arg2,
             arg3)"""
        test_format(str_, str, YASStyle(); indent=4, margin=length(str_) - 1)
        test_format(str_, str, YASStyle(); indent=4, margin=16)

        str = """
        a = (arg1,
             arg2,
             arg3)"""
        test_format(str_, str, YASStyle(); indent=4, margin=15)
        test_format(str_, str, YASStyle(); indent=4, margin=1)

        str_ = "a = [arg1, arg2, arg3]"
        str = """
        a = [arg1, arg2,
             arg3]"""
        test_format(str_, str, YASStyle(); indent=4, margin=length(str_) - 1)
        test_format(str_, str, YASStyle(); indent=4, margin=16)

        str = """
        a = [arg1,
             arg2,
             arg3]"""
        test_format(str_, str, YASStyle(); indent=4, margin=15)
        test_format(str_, str, YASStyle(); indent=4, margin=1)

        str_ = "a = {arg1,arg2,arg3}"
        str = """
        a = {arg1, arg2, arg3}"""
        test_format(str_, str, YASStyle(); indent=4, margin=22)

        str = """
        a = {arg1, arg2,
             arg3}"""
        test_format(str_, str, YASStyle(); indent=4, margin=21)
        test_format(str_, str, YASStyle(); indent=4, margin=16)

        str = """
        a = {arg1,
             arg2,
             arg3}"""
        test_format(str_, str, YASStyle(); indent=4, margin=15)
        test_format(str_, str, YASStyle(); indent=4, margin=1)

        str_ = "a = Union{arg1, arg2, arg3}"
        str = """
        a = Union{arg1,arg2,arg3}"""
        test_format(str_, str, YASStyle(); indent=4, margin=25)

        str = """
        a = Union{arg1,arg2,
                  arg3}"""
        test_format(str_, str, YASStyle(); indent=4, margin=24)
        test_format(str_, str, YASStyle(); indent=4, margin=20)

        str = """
        a = Union{arg1,
                  arg2,
                  arg3}"""
        test_format(str_, str, YASStyle(); indent=4, margin=19)
        test_format(str_, str, YASStyle(); indent=4, margin=1)

        str_ = "a = fcall(arg1,arg2,arg3)"
        str = """
        a = fcall(arg1, arg2, arg3)"""
        test_format(str_, str, YASStyle(); indent=4, margin=length(str))

        str = """
        a = fcall(arg1, arg2,
                  arg3)"""
        test_format(str_, str, YASStyle(); indent=4, margin=26)
        test_format(str_, str, YASStyle(); indent=4, margin=21)

        str = """
        a = fcall(arg1,
                  arg2,
                  arg3)"""
        test_format(str_, str, YASStyle(); indent=4, margin=20)
        test_format(str_, str, YASStyle(); indent=4, margin=1)

        str_ = "a = @call(arg1,arg2,arg3)"
        str = """
        a = @call(arg1, arg2, arg3)"""
        test_format(str_, str, YASStyle(); indent=4, margin=length(str))

        str = """
        a = @call(arg1, arg2,
                  arg3)"""
        test_format(str_, str, YASStyle(); indent=4, margin=26)
        test_format(str_, str, YASStyle(); indent=4, margin=21)

        str = """
        a = @call(arg1,
                  arg2,
                  arg3)"""
        test_format(str_, str, YASStyle(); indent=4, margin=20)
        test_format(str_, str, YASStyle(); indent=4, margin=1)

        str_ = "a = array[arg1,arg2,arg3]"
        str = """
        a = array[arg1, arg2, arg3]"""
        test_format(str_, str, YASStyle(); indent=4, margin=length(str))

        str = """
        a = array[arg1, arg2,
                  arg3]"""
        test_format(str_, str, YASStyle(); indent=4, margin=26)
        test_format(str_, str, YASStyle(); indent=4, margin=21)

        str = """
        a = array[arg1,
                  arg2,
                  arg3]"""
        test_format(str_, str, YASStyle(); indent=4, margin=20)
        test_format(str_, str, YASStyle(); indent=4, margin=1)

        str_ = """
        using Cassette: A, B, C"""
        str = """
        using Cassette: A,
                        B,
                        C"""
        test_format(str_, str, YASStyle(); indent=4, margin=1)
    end

    # more complicated samples
    @testset "pretty" begin
        str_ = "comp = [a * b for a in 1:10, b in 11:20]"
        str = """
        comp = [a * b
                for a in 1:10, b in 11:20]"""
        test_format(str_, str, YASStyle(); indent=2, margin=length(str_) - 1, always_for_in = true)
        test_format(str_, str, YASStyle(); indent=2, margin=34, always_for_in = true)

        str = """
        comp = [a * b
                for a in 1:10,
                    b in 11:20]"""
        test_format(str_, str, YASStyle(); indent=2, margin=33, always_for_in = true)

        str = """
        comp = [a *
                b
                for a in
                    1:10,
                    b in
                    11:20]"""
        test_format(str_, str, YASStyle(); indent=2, margin=1, always_for_in = true)

        str_ = "comp = Typed[a * b for a in 1:10, b in 11:20]"
        str = """
        comp = Typed[a * b
                     for a in 1:10, b in 11:20]"""
        test_format(str_, str, YASStyle(); indent=2, margin=length(str_) - 1, always_for_in = true)
        test_format(str_, str, YASStyle(); indent=2, margin=39, always_for_in = true)

        str = """
        comp = Typed[a * b
                     for a in 1:10,
                         b in 11:20]"""
        test_format(str_, str, YASStyle(); indent=2, margin=38, always_for_in = true)

        str = """
        comp = Typed[a *
                     b
                     for a in
                         1:10,
                         b in
                         11:20]"""
        test_format(str_, str, YASStyle(); indent=2, margin=1, always_for_in = true)

        str_ = "foo(arg1, arg2, arg3) == bar(arg1, arg2, arg3)"
        str = """
        foo(arg1, arg2, arg3) ==
        bar(arg1, arg2, arg3)"""
        # change in default behavior
        test_format(str, str_, YASStyle(); indent=2, margin=length(str_), join_lines_based_on_source = false)
        test_format(str_, str, YASStyle(); indent=2, margin=length(str_) - 1)
        test_format(str_, str, YASStyle(); indent=2, margin=24)

        str = """
        foo(arg1, arg2,
            arg3) ==
        bar(arg1, arg2, arg3)"""
        test_format(str_, str, YASStyle(); indent=2, margin=23)
        test_format(str_, str, YASStyle(); indent=2, margin=21)

        str = """
        foo(arg1, arg2,
            arg3) ==
        bar(arg1, arg2,
            arg3)"""
        test_format(str_, str, YASStyle(); indent=2, margin=20)
        test_format(str_, str, YASStyle(); indent=2, margin=15)

        str = """
        foo(arg1,
            arg2,
            arg3) ==
        bar(arg1,
            arg2,
            arg3)"""
        test_format(str_, str, YASStyle(); indent=2, margin=14)
        test_format(str_, str, YASStyle(); indent=2, margin=1)

        str_ = """
        function func(arg1::Type1, arg2::Type2, arg3) where {Type1,Type2}
          body
        end"""
        str = """
        function func(arg1::Type1, arg2::Type2,
                      arg3) where {Type1,Type2}
          return body
        end"""
        test_format(str_, str, YASStyle(); indent=2, margin=64)
        test_format(str_, str, YASStyle(); indent=2, margin=39)

        str = """
        function func(arg1::Type1,
                      arg2::Type2,
                      arg3) where {Type1,
                                   Type2}
          return body
        end"""
        test_format(str_, str, YASStyle(); indent=2, margin=31)
        test_format(str_, str, YASStyle(); indent=2, margin=1)

        str_ = """
        @test TimeSpan(spike_annotation) == TimeSpan(first(spike_annotation), last(spike_annotation))"""
        str = """
        @test TimeSpan(spike_annotation) ==
              TimeSpan(first(spike_annotation), last(spike_annotation))"""
        test_format(str_, str, YASStyle(); indent=4, margin=length(str_) - 1)
        test_format(str_, str, YASStyle(); indent=4, margin=63)
        str_ = """
        @test TimeSpan(spike_annotation) == TimeSpan(first(spike_annotation), last(spike_annotation))"""
        str = """
        @test TimeSpan(spike_annotation) ==
              TimeSpan(first(spike_annotation),
                       last(spike_annotation))"""
        test_format(str_, str, YASStyle(); indent=4, margin=62)

        str_ =
            raw"""ecg_signal = signal_from_template(eeg_signal; channel_names=[:avl, :avr], file_extension=Symbol("lpcm.zst"))"""
        str = raw"""
        ecg_signal = signal_from_template(eeg_signal; channel_names=[:avl, :avr],
                                          file_extension=Symbol("lpcm.zst"))"""
        test_format(str_, str, YASStyle(); indent=4, margin=length(str_) - 1)
        test_format(str_, str, YASStyle(); indent=4, margin=75)

        str = raw"""
        ecg_signal = signal_from_template(eeg_signal;
                                          channel_names=[:avl, :avr],
                                          file_extension=Symbol("lpcm.zst"))"""
        test_format(str_, str, YASStyle(); indent=4, margin=71)
        str = raw"""
        ecg_signal = signal_from_template(eeg_signal;
                                          channel_names=[:avl,
                                                         :avr],
                                          file_extension=Symbol("lpcm.zst"))"""
        test_format(str_, str, YASStyle(); indent=4, margin=1)
    end

    @testset "inline comments with arguments" begin
        str_ = """
        var = fcall(arg1,
            arg2, arg3, # comment
                            arg4, arg5)"""
        str = """
        var = fcall(arg1, arg2, arg3, # comment
                    arg4, arg5)"""
        test_format(str_, str, YASStyle(); indent=4, margin=80, join_lines_based_on_source = false)
        test_format(str_, str, YASStyle(); indent=4, margin=29, join_lines_based_on_source = false)

        str = """
        var = fcall(arg1, arg2,
                    arg3, # comment
                    arg4, arg5)"""
        test_format(str_, str, YASStyle(); indent=4, margin=28, join_lines_based_on_source = false)
        test_format(str_, str, YASStyle(); indent=4, margin=23, join_lines_based_on_source = false)

        str = """
        var = fcall(arg1,
                    arg2,
                    arg3, # comment
                    arg4,
                    arg5)"""
        test_format(str_, str, YASStyle(); indent=4, margin=22)
        test_format(str_, str, YASStyle(); indent=4, margin=1)

        str_ = """
        comp = [
        begin
                    x = a * b + c
                    y = x^2 + 3x # comment 1
            end
                       for a in 1:10,  # comment 2
                    b in 11:20,
           c in 300:400]"""

        str = """
        comp = [begin
                  x = a * b + c
                  y = x^2 + 3x # comment 1
                end
                for a in 1:10,  # comment 2
                    b in 11:20, c in 300:400]"""
        test_format(str_, str, YASStyle(); indent=2, margin=80, join_lines_based_on_source = false)
        test_format(str_, str, YASStyle(); indent=2, margin=38, join_lines_based_on_source = false)

        str = """
        comp = [begin
                  x = a * b + c
                  y = x^2 + 3x # comment 1
                end
                for a in 1:10,  # comment 2
                    b in 11:20,
                    c in 300:400]"""
        test_format(str_, str, YASStyle(); indent=2, margin=36)

        str_ = """
        ys = ( if p1(x)
                 f1(x)
        elseif p2(x)
            f2(x)
        else
            f3(x)
        end for    x in xs)
        """
        str = """
        ys = (if p1(x)
                f1(x)
              elseif p2(x)
                f2(x)
              else
                f3(x)
              end
              for x in xs)
        """
        test_format(str_, str, YASStyle(); indent=2, margin=80)

        str_ = """spike_annotation = first(ann for ann in recording.annotations if ann.value == "epileptiform_spike")"""
        str = """
        spike_annotation = first(ann
                                 for ann in recording.annotations
                                 if ann.value == "epileptiform_spike")"""
        test_format(str_, str, YASStyle(); indent=2, margin=80)

        # only that
        str_ = "foo(a, b) = (arg1, arg2, arg3)"
        str = """
        foo(a, b) = (arg1, arg2,
                     arg3)"""
        test_format(str_, str, YASStyle(); indent=2, margin=length(str_) - 1, short_to_long_function_def=false)

        str = """
        foo(a, b) = (arg1,
                     arg2,
                     arg3)"""
        test_format(str_, str, YASStyle(); indent=2, margin=1, short_to_long_function_def=false)

        str_ = """
        fooooooooooooooooooo(arg1, arg2,
        x -> begin
        body
        end
        )"""
        str = """
        fooooooooooooooooooo(arg1, arg2,
                             x -> begin
                                 body
                             end)"""
        test_format(str_, str, YASStyle(); indent=4, margin=32)

        # parsing error is newline is placed front of `for` here
        str_ = "var = ((x, y) for x = 1:10, y = 1:10)"
        str = """
        var = ((x, y) for x in 1:10,
                          y in 1:10)"""
        test_format(str_, str, YASStyle(); indent=4, margin=length(str_) - 1)
    end

    @testset "parens" begin
        str_ = """
        if ((
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        ))
          nothing
        end"""
        str = """
        if ((aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
             aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
             aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa))
          nothing
        end"""
        test_format(str_, str, YASStyle(); indent=2, margin=92)
    end

    @testset "issue 189" begin
        str_ = """
    D2 = [
            (b_hat * y - delta_hat[i] * y) * gamma[i] + (b * y_hat - delta[i] * y_hat) *
                                                            gamma_hat[i] + (b_hat - y_hat) *
                                                                           delta[i] + (b - y) *
                                                                                      delta_hat[i] - delta[i] * delta_hat[i]
            for i = 1:8
        ]"""
        str = """
        D2 = [(b_hat * y - delta_hat[i] * y) * gamma[i] +
              (b * y_hat - delta[i] * y_hat) * gamma_hat[i] +
              (b_hat - y_hat) * delta[i] +
              (b - y) * delta_hat[i] - delta[i] * delta_hat[i]
              for i in 1:8]"""
        test_format(str_, str, YASStyle(); indent=2, margin=60, join_lines_based_on_source = false)
    end

    @testset "issue 237" begin
        str_ = """
        for x in (arg1, arg2,)
            @info "Test"
        end"""
        str = """
        for x in (arg1, arg2)
            @info "Test"
        end"""
        test_format(str_, str, YASStyle(); indent=4, margin=92)
    end

    @testset "issue 320" begin
        str_ = "[x[i] for i = 1:length(x)]"
        str = "[x[i] for i in 1:length(x)]"
        test_format(str_, str, YASStyle(); indent=4, margin=92, always_for_in = true)
    end

    @testset "issue 321 - exponential inline comments !!!" begin
        str = """
        scaled_ticks, mini, maxi = optimize_ticks(scale_func(lmin), scale_func(lmax); k_min=4, # minimum number of ticks
                                                  k_max=8)"""
        test_format(str, str, YASStyle(); indent=4, margin=92, whitespace_in_kwargs = false)
    end

    @testset "issue 355 - vcat/typedvcat" begin
        str = """
        mpoly_rules = T[@rule(~x::ismpoly - ~y::ismpoly => ~x + -1 * (~y))
                        @rule(-(~x) => -1 * ~x)
                        @acrule(~x::ismpoly + ~y::ismpoly => ~x + ~y)
                        @rule(+(~x) => ~x)
                        @acrule(~x::ismpoly * ~y::ismpoly => ~x * ~y)
                        @rule(*(~x) => ~x)
                        @rule((~x::ismpoly)^(~a::isnonnegint) => (~x)^(~a))]"""
        test_format(str, str, YASStyle())

        str = """
        mpoly_rules = [@rule(~x::ismpoly - ~y::ismpoly => ~x + -1 * (~y))
                       @rule(-(~x) => -1 * ~x)
                       @acrule(~x::ismpoly + ~y::ismpoly => ~x + ~y)
                       @rule(+(~x) => ~x)
                       @acrule(~x::ismpoly * ~y::ismpoly => ~x * ~y)
                       @rule(*(~x) => ~x)
                       @rule((~x::ismpoly)^(~a::isnonnegint) => (~x)^(~a))]"""
        test_format(str, str, YASStyle())

        str_ = """
        [10 20; 30 40; 50 60;
         10
         10]"""
        test_format(str_, str_, YASStyle(); indent=4, margin=21)

        str = """
        [10 20; 30 40;
         50 60;
         10
         10]"""
        test_format(str_, str, YASStyle(); indent=4, margin=20)
        test_format(str_, str, YASStyle(); indent=4, margin=14)

        str = """
        [10 20;
         30 40;
         50 60;
         10
         10]"""
        test_format(str_, str, YASStyle(); indent=4, margin=13)

        str_ = """
        T[10 20; 30 40; 50 60;
          10
          10]"""
        test_format(str_, str_, YASStyle(); indent=4, margin=22)

        str = """
        T[10 20; 30 40;
          50 60;
          10
          10]"""
        test_format(str_, str, YASStyle(); indent=4, margin=21)
        test_format(str_, str, YASStyle(); indent=4, margin=15)

        str = """
        T[10 20;
          30 40;
          50 60;
          10
          10]"""
        test_format(str_, str, YASStyle(); indent=4, margin=14)

        str = "(T[10 20; 30 40; 50 60;])"
        test_format(str, str, YASStyle(); indent=4, margin=25)
        str = "(T[10 20; 30 40; 50 60])"
        test_format(str, str, YASStyle(); indent=4, margin=24)

        str_ = """
        (T[10 20; 30 40;
           50 60])"""
        test_format(str, str_, YASStyle(); indent=4, margin=23)
    end

    @testset "imports no placeholder, no error" begin
        str = "import A"
        test_format(str, "using A: A", YASStyle())

        str = "export A"
        test_format(str, str, YASStyle())

        str = "using A"
        test_format(str, str, YASStyle())
    end

    @testset "issue 582 - vcat" begin
        test_format("[sts...;]", "[sts...;]", YASStyle())
        test_format("[a;b;]", "[a; b;]", YASStyle())
        test_format("[a;b;;]", "[a; b;;]", YASStyle())
    end

    @testset "variable_call_indent" begin
        str = raw"""
        Dict{Int,Int}(1 => 2,
                      3 => 4)
        """

        # This should be valid with and without `Dict` in `variable_call_indent`
        test_format(str, str, YASStyle())
        test_format(str, str, YASStyle(); variable_call_indent = ["Dict"])

        str = raw"""
        SVector(1.0,
                2.0)
        """
        test_format(str, str, YASStyle())
        test_format(str, str, YASStyle(); variable_call_indent = ["SVector", "test2"])
        test_format(str, str, YASStyle(); variable_call_indent = ["Dict"])

        str = raw"""
        Dict{Int,Int}(
        1 => 2,
                3 => 4)
        """
        formatted_str1 = raw"""
        Dict{Int,Int}(1 => 2,
                      3 => 4)
        """
        formatted_str2 = raw"""
        Dict{Int,Int}(
            1 => 2,
            3 => 4)
        """
        # `variable_call_indent` keeps the line break and doesn't align
        test_format(str, formatted_str1, YASStyle())
        test_format(str, formatted_str2, YASStyle(); variable_call_indent = ["Dict"])

        str = raw"""
        SVector(
        1.0,
                2.0)
        """
        formatted_str1 = raw"""
        SVector(1.0,
                2.0)
        """
        formatted_str2 = raw"""
        SVector(
            1.0,
            2.0)
        """
        test_format(str, formatted_str1, YASStyle(); variable_call_indent = ["Dict"])
        test_format(str, formatted_str2, YASStyle(); variable_call_indent = ["test", "SVector"])

        str = raw"""
        Dict{Int,Int}(
            1 => 2,
            3 => 4,
        )
        """
        formatted_str = raw"""
        Dict{Int,Int}(1 => 2,
                      3 => 4)
        """
        test_format(str, formatted_str, YASStyle())
        test_format(str, str, YASStyle(); variable_call_indent = ["Dict"])

        str = raw"""
        SomeLongerTypeThanJustString = String
        y = Dict{Int,SomeLongerTypeThanJustString}(1 => "some arbitrary string bla bla bla bla bla bla",
            2 => "another longer arbitrary string bla bla bla bla bla bla bla bla")
        """

        formatted_str1 = raw"""
        SomeLongerTypeThanJustString = String
        y = Dict{Int,SomeLongerTypeThanJustString}(1 => "some arbitrary string bla bla bla bla bla bla",
                                                   2 => "another longer arbitrary string bla bla bla bla bla bla bla bla")
        """

        formatted_str2 = raw"""
        SomeLongerTypeThanJustString = String
        y = Dict{Int,SomeLongerTypeThanJustString}(
            1 => "some arbitrary string bla bla bla bla bla bla",
            2 => "another longer arbitrary string bla bla bla bla bla bla bla bla",
        )
        """

        # Here, `variable_call_indent` forces the line break because the line is too long.
        # For some reason, this has to be formatted twice.
        # (TODO penelopeysm -- isn't this an idempotence bug?)
        @test_broken false
        @test format_text(str, YASStyle()) == formatted_str1
        intermediate_str = format_text(str, YASStyle(); variable_call_indent = ["Dict"])
        @test format_text(intermediate_str, YASStyle(); variable_call_indent = ["Dict"]) ==
              formatted_str2

        str = raw"""
        Dict{Int,Int}(
                      # Comment
                      1 => 2,
                      3 => 4)
        """
        formatted_str = raw"""
        Dict{Int,Int}(
            # Comment
            1 => 2,
            3 => 4)
        """
        # Test `variable_call_indent` with a comment in a separate line
        test_format(str, str, YASStyle())
        test_format(str, formatted_str, YASStyle(); variable_call_indent = ["Dict"])

        str = raw"""
        SVector(
                # Comment
                1.0,
                2.0)
        """
        formatted_str = raw"""
        SVector(
            # Comment
            1.0,
            2.0)
        """
        # Test the same with different callers
        test_format(str, str, YASStyle())
        test_format(str, formatted_str, YASStyle(); variable_call_indent = ["SVector"])

        str = raw"""
        Dict{Int,Int}(# Comment
                    1 => 2,
                    3 => 4)
        """
        formatted_str1 = raw"""
        Dict{Int,Int}(# Comment
                      1 => 2,
                      3 => 4)
        """
        formatted_str2 = raw"""
        Dict{Int,Int}(# Comment
            1 => 2,
            3 => 4)
        """
        # Test `variable_call_indent` with an inline comment after the opening parenthesis
        test_format(str, formatted_str1, YASStyle())
        test_format(str, formatted_str2, YASStyle(); variable_call_indent = ["Dict"])

        str = raw"""
        Dict{Int,Int}( # Comment
                # Comment
                1 => 2,
                # Another comment
                3 => 4)
        """
        formatted_str1 = raw"""
        Dict{Int,Int}( # Comment
                      # Comment
                      1 => 2,
                      # Another comment
                      3 => 4)
        """
        formatted_str2 = raw"""
        Dict{Int,Int}( # Comment
            # Comment
            1 => 2,
            # Another comment
            3 => 4)
        """
        # Test `variable_call_indent` with both an inline comment after the opening parenthesis
        # and a comment in a separate line.
        test_format(str, formatted_str1, YASStyle())
        test_format(str, formatted_str2, YASStyle(); variable_call_indent = ["Dict"])

        str = raw"""
        SVector( # Comment
                    # Comment
                    1.0,
                    # Another comment
                    2.0)
        """
        formatted_str1 = raw"""
        SVector( # Comment
                # Comment
                1.0,
                # Another comment
                2.0)
        """
        formatted_str2 = raw"""
        SVector( # Comment
            # Comment
            1.0,
            # Another comment
            2.0)
        """
        # Test the same with different callers
        test_format(str, formatted_str1, YASStyle(); variable_call_indent = ["test"])
        test_format(str, formatted_str2, YASStyle(); variable_call_indent = ["SVector", "test"])
    end

    @testset "indentation of binary ops" begin
        s1 = """
        begin
            @test aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa == ["theta[1]",
                                                           "theta[2]",
                                                           "theta[3]",
                                                           "theta[4]",
                                                           "tau"]
        end"""
        # different margins have different code paths so test both
        for margin in (80, 2000)
            test_format(s1, s1, YASStyle(); margin=margin)
        end

        s2 = """
        begin
            @test ccc => function ()
                             return f() do x
                                 return aaaaaaaaaaaaa
                             end
                         end
        end"""
        for margin in (80, 2000)
            test_format(s2, s2, YASStyle(); margin=margin)
        end
    end
end

end
