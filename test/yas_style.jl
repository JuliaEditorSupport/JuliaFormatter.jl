@testset "YAS Style" begin
    @testset "basic" begin
        str_ = "foo(; k =v)"
        str = "foo(; k = v)"
        @test yasfmt(str_, 4, 80) == str

        str_ = "[a,]"
        str = "[a]"
        @test yasfmt(str_, 4, 92) == str

        str_ = "T[a,]"
        str = "T[a]"
        @test yasfmt(str_, 4, 92) == str

        str_ = "{a,}"
        str = "{a}"
        @test yasfmt(str_, 4, 92) == str

        str_ = "T{a,}"
        str = "T{a}"
        @test yasfmt(str_, 4, 92) == str

        str_ = "T(a,)"
        str = "T(a)"
        @test yasfmt(str_, 4, 92) == str

        str_ = "(a,)"
        str = "(a,)"
        @test yasfmt(str_, 4, 92) == str

        str_ = "@foo(a,)"
        str = "@foo(a,)"
        @test yasfmt(str_, 4, 92) == str

        str_ = "a = (arg1, arg2, arg3)"
        str = """
        a = (arg1, arg2,
             arg3)"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
        @test yasfmt(str_, 4, 16) == str

        str = """
        a = (arg1,
             arg2,
             arg3)"""
        @test yasfmt(str_, 4, 15) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = [arg1, arg2, arg3]"
        str = """
        a = [arg1, arg2,
             arg3]"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
        @test yasfmt(str_, 4, 16) == str

        str = """
        a = [arg1,
             arg2,
             arg3]"""
        @test yasfmt(str_, 4, 15) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = {arg1,arg2,arg3}"
        str = """
        a = {arg1, arg2, arg3}"""
        @test yasfmt(str_, 4, 22) == str

        str = """
        a = {arg1, arg2,
             arg3}"""
        @test yasfmt(str_, 4, 21) == str
        @test yasfmt(str_, 4, 16) == str

        str = """
        a = {arg1,
             arg2,
             arg3}"""
        @test yasfmt(str_, 4, 15) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = Union{arg1, arg2, arg3}"
        str = """
        a = Union{arg1,arg2,arg3}"""
        @test yasfmt(str_, 4, 25) == str

        str = """
        a = Union{arg1,arg2,
                  arg3}"""
        @test yasfmt(str_, 4, 24) == str
        @test yasfmt(str_, 4, 20) == str

        str = """
        a = Union{arg1,
                  arg2,
                  arg3}"""
        @test yasfmt(str_, 4, 19) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = fcall(arg1,arg2,arg3)"
        str = """
        a = fcall(arg1, arg2, arg3)"""
        @test yasfmt(str_, 4, length(str)) == str

        str = """
        a = fcall(arg1, arg2,
                  arg3)"""
        @test yasfmt(str_, 4, 26) == str
        @test yasfmt(str_, 4, 21) == str

        str = """
        a = fcall(arg1,
                  arg2,
                  arg3)"""
        @test yasfmt(str_, 4, 20) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = @call(arg1,arg2,arg3)"
        str = """
        a = @call(arg1, arg2, arg3)"""
        @test yasfmt(str_, 4, length(str)) == str

        str = """
        a = @call(arg1, arg2,
                  arg3)"""
        @test yasfmt(str_, 4, 26) == str
        @test yasfmt(str_, 4, 21) == str

        str = """
        a = @call(arg1,
                  arg2,
                  arg3)"""
        @test yasfmt(str_, 4, 20) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = array[arg1,arg2,arg3]"
        str = """
        a = array[arg1, arg2, arg3]"""
        @test yasfmt(str_, 4, length(str)) == str

        str = """
        a = array[arg1, arg2,
                  arg3]"""
        @test yasfmt(str_, 4, 26) == str
        @test yasfmt(str_, 4, 21) == str

        str = """
        a = array[arg1,
                  arg2,
                  arg3]"""
        @test yasfmt(str_, 4, 20) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = """
        using Cassette: A, B, C"""
        str = """
        using Cassette: A,
                        B,
                        C"""
        @test yasfmt(str_, 4, 1) == str
    end

    # more complicated samples
    @testset "pretty" begin
        str_ = "comp = [a * b for a in 1:10, b in 11:20]"
        str = """
        comp = [a * b
                for a in 1:10, b in 11:20]"""
        @test yasfmt(str_, 2, length(str_) - 1; always_for_in = true) == str
        @test yasfmt(str_, 2, 34; always_for_in = true) == str

        str = """
        comp = [a * b
                for a in 1:10,
                    b in 11:20]"""
        @test yasfmt(str_, 2, 33; always_for_in = true) == str

        str = """
        comp = [a *
                b
                for a in
                    1:10,
                    b in
                    11:20]"""
        @test yasfmt(str_, 2, 1; always_for_in = true) == str

        str_ = "comp = Typed[a * b for a in 1:10, b in 11:20]"
        str = """
        comp = Typed[a * b
                     for a in 1:10, b in 11:20]"""
        @test yasfmt(str_, 2, length(str_) - 1; always_for_in = true) == str
        @test yasfmt(str_, 2, 39; always_for_in = true) == str

        str = """
        comp = Typed[a * b
                     for a in 1:10,
                         b in 11:20]"""
        @test yasfmt(str_, 2, 38; always_for_in = true) == str

        str = """
        comp = Typed[a *
                     b
                     for a in
                         1:10,
                         b in
                         11:20]"""
        @test yasfmt(str_, 2, 1; always_for_in = true) == str

        str_ = "foo(arg1, arg2, arg3) == bar(arg1, arg2, arg3)"
        str = """
        foo(arg1, arg2, arg3) ==
        bar(arg1, arg2, arg3)"""
        # change in default behavior
        @test yasfmt(str, 2, length(str_); join_lines_based_on_source = false) == str_
        @test yasfmt(str_, 2, length(str_) - 1) == str
        @test yasfmt(str_, 2, 24) == str

        str = """
        foo(arg1, arg2,
            arg3) ==
        bar(arg1, arg2, arg3)"""
        @test yasfmt(str_, 2, 23) == str
        @test yasfmt(str_, 2, 21) == str

        str = """
        foo(arg1, arg2,
            arg3) ==
        bar(arg1, arg2,
            arg3)"""
        @test yasfmt(str_, 2, 20) == str
        @test yasfmt(str_, 2, 15) == str

        str = """
        foo(arg1,
            arg2,
            arg3) ==
        bar(arg1,
            arg2,
            arg3)"""
        @test yasfmt(str_, 2, 14) == str
        @test yasfmt(str_, 2, 1) == str

        str_ = """
        function func(arg1::Type1, arg2::Type2, arg3) where {Type1,Type2}
          body
        end"""
        str = """
        function func(arg1::Type1, arg2::Type2,
                      arg3) where {Type1,Type2}
          body
        end"""
        @test yasfmt(str_, 2, 64) == str
        @test yasfmt(str_, 2, 39) == str

        str = """
        function func(arg1::Type1,
                      arg2::Type2,
                      arg3) where {Type1,
                                   Type2}
          body
        end"""
        @test yasfmt(str_, 2, 31) == str
        @test yasfmt(str_, 2, 1) == str

        str_ = """
        @test TimeSpan(spike_annotation) == TimeSpan(first(spike_annotation), last(spike_annotation))"""
        str = """
        @test TimeSpan(spike_annotation) ==
              TimeSpan(first(spike_annotation), last(spike_annotation))"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
        @test yasfmt(str_, 4, 63) == str
        str_ = """
        @test TimeSpan(spike_annotation) == TimeSpan(first(spike_annotation), last(spike_annotation))"""
        str = """
        @test TimeSpan(spike_annotation) ==
              TimeSpan(first(spike_annotation),
                       last(spike_annotation))"""
        @test yasfmt(str_, 4, 62) == str

        str_ =
            raw"""ecg_signal = signal_from_template(eeg_signal; channel_names=[:avl, :avr], file_extension=Symbol("lpcm.zst"))"""
        str = raw"""
        ecg_signal = signal_from_template(eeg_signal; channel_names = [:avl, :avr],
                                          file_extension = Symbol("lpcm.zst"))"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
        @test yasfmt(str_, 4, 75) == str

        str = raw"""
        ecg_signal = signal_from_template(eeg_signal;
                                          channel_names = [:avl, :avr],
                                          file_extension = Symbol("lpcm.zst"))"""
        @test yasfmt(str_, 4, 73) == str
        str = raw"""
        ecg_signal = signal_from_template(eeg_signal;
                                          channel_names = [:avl,
                                                           :avr],
                                          file_extension = Symbol("lpcm.zst"))"""
        @test yasfmt(str_, 4, 1) == str
    end

    @testset "inline comments with arguments" begin
        str_ = """
        var = fcall(arg1,
            arg2, arg3, # comment
                            arg4, arg5)"""
        str = """
        var = fcall(arg1, arg2, arg3, # comment
                    arg4, arg5)"""
        @test yasfmt(str_, 4, 80; join_lines_based_on_source = false) == str
        @test yasfmt(str_, 4, 29; join_lines_based_on_source = false) == str

        str = """
        var = fcall(arg1, arg2,
                    arg3, # comment
                    arg4, arg5)"""
        @test yasfmt(str_, 4, 28; join_lines_based_on_source = false) == str
        @test yasfmt(str_, 4, 23; join_lines_based_on_source = false) == str

        str = """
        var = fcall(arg1,
                    arg2,
                    arg3, # comment
                    arg4,
                    arg5)"""
        @test yasfmt(str_, 4, 22) == str
        @test yasfmt(str_, 4, 1) == str

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
                for a = 1:10,  # comment 2
                    b = 11:20, c = 300:400]"""
        @test yasfmt(str_, 2, 80; join_lines_based_on_source = false) == str
        @test yasfmt(str_, 2, 35; join_lines_based_on_source = false) == str

        str = """
        comp = [begin
                  x = a * b + c
                  y = x^2 + 3x # comment 1
                end
                for a = 1:10,  # comment 2
                    b = 11:20,
                    c = 300:400]"""
        @test yasfmt(str_, 2, 34) == str

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
        @test yasfmt(str_, 2, 80) == str

        str_ = """spike_annotation = first(ann for ann in recording.annotations if ann.value == "epileptiform_spike")"""
        str = """
        spike_annotation = first(ann
                                 for ann in recording.annotations
                                 if ann.value == "epileptiform_spike")"""
        @test yasfmt(str_, 2, 80) == str

        # only that
        str_ = "foo(a, b) = (arg1, arg2, arg3)"
        str = """
        foo(a, b) = (arg1, arg2,
                     arg3)"""
        @test yasfmt(str_, 2, length(str_) - 1) == str

        str = """
        foo(a, b) = (arg1,
                     arg2,
                     arg3)"""
        @test yasfmt(str_, 2, 1) == str

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
        @test yasfmt(str_, 4, 32) == str

        # parsing error is newline is placed front of `for` here
        str_ = "var = ((x, y) for x = 1:10, y = 1:10)"
        str = """
        var = ((x, y) for x = 1:10,
                          y = 1:10)"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
    end

    @testset "invisbrackets" begin
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
        @test yasfmt(str_, 2, 92) == str
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
              for i = 1:8]"""
        @test yasfmt(str_, 2, 60; join_lines_based_on_source = false) == str
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
        @test yasfmt(str_, 4, 92) == str
    end

    @testset "issue 320" begin
        str_ = "[x[i] for i = 1:length(x)]"
        str = "[x[i] for i in 1:length(x)]"
        @test yasfmt(str_, 4, 92; always_for_in = true) == str
    end

    @testset "issue 321 - exponential inline comments !!!" begin
        str = """
        scaled_ticks, mini, maxi = optimize_ticks(scale_func(lmin), scale_func(lmax); k_min=4, # minimum number of ticks
                                                  k_max=8)"""
        @test yasfmt(str, 4, 92; whitespace_in_kwargs = false) == str
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
        @test yasfmt(str) == str

        str = """
        mpoly_rules = [@rule(~x::ismpoly - ~y::ismpoly => ~x + -1 * (~y))
                       @rule(-(~x) => -1 * ~x)
                       @acrule(~x::ismpoly + ~y::ismpoly => ~x + ~y)
                       @rule(+(~x) => ~x)
                       @acrule(~x::ismpoly * ~y::ismpoly => ~x * ~y)
                       @rule(*(~x) => ~x)
                       @rule((~x::ismpoly)^(~a::isnonnegint) => (~x)^(~a))]"""
        @test yasfmt(str) == str

        str_ = """
        [10 20; 30 40; 50 60;
         10
         10]"""
        @test yasfmt(str_, 4, 21) == str_

        str = """
        [10 20; 30 40;
         50 60;
         10
         10]"""
        @test yasfmt(str_, 4, 20) == str
        @test yasfmt(str_, 4, 14) == str

        str = """
        [10 20;
         30 40;
         50 60;
         10
         10]"""
        @test yasfmt(str_, 4, 13) == str

        str_ = """
        T[10 20; 30 40; 50 60;
          10
          10]"""
        @test yasfmt(str_, 4, 22) == str_

        str = """
        T[10 20; 30 40;
          50 60;
          10
          10]"""
        @test yasfmt(str_, 4, 21) == str
        @test yasfmt(str_, 4, 15) == str

        str = """
        T[10 20;
          30 40;
          50 60;
          10
          10]"""
        @test yasfmt(str_, 4, 14) == str

        str = "(T[10 20; 30 40; 50 60;])"
        @test yasfmt(str, 4, 25) == str
        str = "(T[10 20; 30 40; 50 60])"
        @test yasfmt(str, 4, 24) == str

        str_ = """
        (T[10 20; 30 40;
           50 60])"""
        @test yasfmt(str, 4, 23) == str_
    end

    @testset "imports no placeholder, no error" begin
        str = "import A"
        @test yasfmt(str) == str

        str = "export A"
        @test yasfmt(str) == str

        str = "using A"
        @test yasfmt(str) == str
    end

    if VERSION >= v"1.7"
        @testset "issue 582 - vcat" begin
            @test yasfmt("[sts...;]") == "[sts...;]"
            @test yasfmt("[a;b;]") == "[a; b;]"
            @test yasfmt("[a;b;;]") == "[a; b;;]"
        end
    end

    @testset "variable_call_indent" begin
        str = raw"""
        Dict{Int,Int}(1 => 2,
                      3 => 4)
        """

        # This should be valid with and without `Dict` in `variable_call_indent`
        @test format_text(str, YASStyle()) == str
        @test format_text(str, YASStyle(); variable_call_indent = ["Dict"]) == str

        str = raw"""
        SVector(1.0,
                2.0)
        """

        # Test the same with different callers
        @test format_text(str, YASStyle(); variable_call_indent = ["Dict"]) == str
        @test format_text(str, YASStyle(); variable_call_indent = ["SVector", "test2"]) ==
              str

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
        @test format_text(str, YASStyle()) == formatted_str1
        @test format_text(str, YASStyle(); variable_call_indent = ["Dict"]) ==
              formatted_str2

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

        # Test the same with different callers
        @test format_text(str, YASStyle(); variable_call_indent = ["Dict"]) ==
              formatted_str1
        @test format_text(str, YASStyle(); variable_call_indent = ["test", "SVector"]) ==
              formatted_str2

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

        # This is already valid with `variable_call_indent`
        @test format_text(str, YASStyle()) == formatted_str
        @test format_text(str, YASStyle(); variable_call_indent = ["Dict"]) == str

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
        @test format_text(str, YASStyle()) == str
        @test format_text(str, YASStyle(); variable_call_indent = ["Dict"]) == formatted_str

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
        @test format_text(str, YASStyle()) == str
        @test format_text(str, YASStyle(); variable_call_indent = ["SVector"]) ==
              formatted_str

        str = raw"""
        Dict{Int,Int}(# Comment
                    1 => 2,
                    3 => 4)
        """

        formatted_str1 = raw"""
        Dict{Int,Int}(1 => 2,
                      3 => 4)
        """

        formatted_str2 = raw"""
        Dict{Int,Int}(# Comment
            1 => 2,
            3 => 4)
        """

        # Test `variable_call_indent` with an inline comment after the opening parenthesis
        # With `variable_call_indent = false`, the comment will be eaten,
        # see https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/609
        @test format_text(str, YASStyle()) == formatted_str1
        @test format_text(str, YASStyle(); variable_call_indent = ["Dict"]) ==
              formatted_str2

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
        @test format_text(str, YASStyle()) == formatted_str1
        @test format_text(str, YASStyle(); variable_call_indent = ["Dict"]) ==
              formatted_str2

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
        @test format_text(str, YASStyle(); variable_call_indent = ["test"]) ==
              formatted_str1
        @test format_text(str, YASStyle(); variable_call_indent = ["SVector", "test"]) ==
              formatted_str2
    end
end
