@testset "GitHub Issues" begin
    @testset "issue #137" begin
        str = """
        (
            let x = f() do
                    body
                end
                x
            end for x in xs
        )"""
        str_ = """
        (
               let x = f() do
                       body
                   end
                   x
               end for x in xs
         )"""
        @test fmt(str_) == str

        str = """
        (
            let
                x = f() do
                    body
                end
                x
            end for x in xs
        )"""
        str_ = """
        (
          let
              x = f() do
                  body
              end
              x
          end for x in xs)"""
        @test fmt(str_) == str

        str = """
        let n = try
                ..
            catch
                ..
            end
            ..
        end"""
        @test fmt(str) == str

        str = """
        let n = let
                ..
            end
            ..
        end"""
        @test fmt(str) == str

        str = """
        let n = begin
                ..
            end
            ..
        end"""
        @test fmt(str) == str
    end

    @testset "multiline / issue 139" begin
        str_ = """
        m = match(r\"""
                  (
                      pattern1 |
                      pattern2 |
                      pattern3
                  )
                  \"""x, aaa, str)"""
        str = """
        m = match(
            r\"""
            (
                pattern1 |
                pattern2 |
                pattern3
            )
            \"""x,
            aaa,
            str,
        )"""
        @test fmt(str_) == str

        str_ = """
        m = match(r```
                  (
                      pattern1 |
                      pattern2 |
                      pattern3
                  )
                  ```x, aaa, str)"""
        str = """
        m = match(
            r```
            (
                pattern1 |
                pattern2 |
                pattern3
            )
            ```x,
            aaa,
            str,
        )"""
        @test fmt(str_) == str

        str_ = """
        y = similar([
            1
            2
            3
        ], (4, 5))"""
        str = """
        y = similar(
            [
                1
                2
                3
            ],
            (4, 5),
        )"""
        @test fmt(str_) == str

        str_ = """
        y = similar(T[
            1
            2
            3
        ], (4, 5))"""
        str = """
        y = similar(
            T[
                1
                2
                3
            ],
            (4, 5),
        )"""
        @test fmt(str_) == str
    end

    @testset "issue #150" begin
        str_ = "const SymReg{B,MT} = ArrayReg{B,Basic,MT} where {MT <:AbstractMatrix{Basic}}"
        str = "const SymReg{B,MT} = ArrayReg{B,Basic,MT} where {MT<:AbstractMatrix{Basic}}"
        @test fmt(str_; whitespace_typedefs = false) == str

        str = "const SymReg{B, MT} = ArrayReg{B, Basic, MT} where {MT <: AbstractMatrix{Basic}}"
        @test fmt(str_; whitespace_typedefs = true) == str
    end

    @testset "issue #170 - block within comprehension" begin
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
        ys = (
            if p1(x)
                f1(x)
            elseif p2(x)
                f2(x)
            else
                f3(x)
            end for x in xs
        )
        """
        @test fmt(str_) == str

        str = """
        ys = map(xs) do x
            if p1(x)
                f1(x)
            elseif p2(x)
                f2(x)
            else
                f3(x)
            end
        end
        """
        @test fmt(str) == str

        str_ = """
        y1 = Any[if true
            very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_expr
        end for i in 1:1]"""
        str = """
        y1 = Any[
            if true
                very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_expr
            end for i = 1:1
        ]"""
        @test fmt(str_) == str
        _, s = run_nest(str_, 100)
        @test s.line_offset == 1

        str_ = """
        y1 = [if true
            very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_expr
        end for i in 1:1]"""
        str = """
        y1 = [
            if true
                very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_expr
            end for i = 1:1
        ]"""
        @test fmt(str_) == str
        _, s = run_nest(str_, 100)
        @test s.line_offset == 1

        str_ = """
        y1 = [if true
            short_expr
        end for i in 1:1]"""
        str = """
        y1 = [
            if true
                short_expr
            end for i = 1:1
        ]"""
        @test fmt(str_) == str
        _, s = run_nest(str_, 100)
        @test s.line_offset == 1
    end

    @testset "issue 183 & 525" begin
        # fixing 525 caused the previous test to fail since it
        # exchanged the semicolon to a trailing comma, which isn't exactly
        # what we wanted and it turns out sometimes the comma was
        # added in addition to the semicolon. Now, if the semicolon
        # is there the trailing comma is not added.
        str_ = """
        function f(args...)

            next!(s.progress;
            # comment
            )
            nothing
        end"""
        str = """
        function f(args...)

            next!(
                s.progress;
                # comment
            )
            nothing
        end"""
        @test fmt(str_) == str
    end

    @testset "issue #189" begin
        str_ = """
    D2 = [
            (b_hat * y - delta_hat[i] * y) * gamma[i] + (b * y_hat - delta[i] * y_hat) *
                                                            gamma_hat[i] + (b_hat - y_hat) *
                                                                           delta[i] + (b - y) *
                                                                                      delta_hat[i] - delta[i] * delta_hat[i]
            for i = 1:8
        ]"""
        str = """
        D2 = [
            (b_hat * y - delta_hat[i] * y) * gamma[i] +
            (b * y_hat - delta[i] * y_hat) * gamma_hat[i] +
            (b_hat - y_hat) * delta[i] +
            (b - y) * delta_hat[i] - delta[i] * delta_hat[i] for i = 1:8
        ]"""
        @test fmt(str_) == str
    end

    @testset "issue #193" begin
        str = """
        module Module
        # comment
        end"""
        @test fmt(str) == str

        str = """
        module Module
        # comment
        @test
        # comment
        end"""
        @test fmt(str) == str
    end

    @testset "issue #194" begin
        str_ = """
        function mystr( str::String )
        return SubString( str, 1:
        3 )
        end"""
        str = """
        function mystr(str::String)
            return SubString(str, 1:3)
        end"""
        @test fmt(str_) == str
    end

    @testset "issue #200" begin
        str_ = """
        begin
            f() do
                @info @sprintf \"\"\"
                Δmass   = %.16e\"\"\" abs(weightedsum(Q) - weightedsum(Qe)) / weightedsum(Qe)
            end
        end"""

        # NOTE: this looks slightly off because we're compensating for escaping quotes
        str = """
        begin
            f() do
                @info @sprintf \"\"\"
                Δmass   = %.16e\"\"\" abs(weightedsum(Q) - weightedsum(Qe)) /
                                   weightedsum(Qe)
            end
        end"""
        @test fmt(str_; m = 81) == str
        @test fmt(str; m = 82) == str_
    end

    @testset "issue #202" begin
        str_ = """
        @inline function _make_zop_getvalues(iterators)
            types = map(iterators) do itr
                t =     constructorof(typeof(itr))::Union{Iterators.ProductIterator,CartesianIndices}
                Val(t)
            end
            return function (xs) end
        end"""
        str = """
        @inline function _make_zop_getvalues(iterators)
            types = map(iterators) do itr
                t = constructorof(typeof(itr))::Union{Iterators.ProductIterator,CartesianIndices}
                Val(t)
            end
            return function (xs) end
        end"""
        @test fmt(str_; m = 92) == str

        str_ = """
        @vlplot(
            data = dataset("cars"),
            facet = {row = {field = :Origin, type = :nominal}},
            spec = {
                layer = [
                    {
                        mark = :point,
                        encoding =     {x = {field = :Horsepower}, y = {field = :Miles_per_Gallon}},
                    },
                    {
                        mark = {type = :rule, color = :red},
                        data = {values = [{ref = 10}]},
                        encoding = {y = {field = :ref, type = :quantitative}},
                    },
                ],
            }
        )"""
        str = """
        @vlplot(
            data = dataset("cars"),
            facet = {row = {field = :Origin, type = :nominal}},
            spec = {
                layer = [
                    {
                        mark = :point,
                        encoding = {x = {field = :Horsepower}, y = {field = :Miles_per_Gallon}},
                    },
                    {
                        mark = {type = :rule, color = :red},
                        data = {values = [{ref = 10}]},
                        encoding = {y = {field = :ref, type = :quantitative}},
                    },
                ],
            }
        )"""
        @test fmt(str_; m = 92) == str
    end

    @testset "issue #207" begin
        str_ = """
        @traitfn function predict_ar(m::TGP, p::Int = 3, n::Int = 1; y_past = get_y(m)) where {T,TGP<:AbstractGP{T};IsMultiOutput{TGP}}
        end"""

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {T,TGP<:AbstractGP{T};IsMultiOutput{TGP}} end"""
        @test fmt(str_; m = 92) == str

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {T, TGP <: AbstractGP{T}; IsMultiOutput{TGP}} end"""
        @test fmt(str_; m = 92, whitespace_typedefs = true) == str

        str_ = """
        @traitfn function predict_ar(m::TGP, p::Int = 3, n::Int = 1; y_past = get_y(m)) where C <: Union{T,TGP<:AbstractGP{T};IsMultiOutput{TGP}}
        end"""

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {C<:Union{T,TGP<:AbstractGP{T};IsMultiOutput{TGP}}} end"""
        @test fmt(str_; m = 92) == str

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {C <: Union{T, TGP <: AbstractGP{T}; IsMultiOutput{TGP}}} end"""
        @test fmt(str_; m = 92, whitespace_typedefs = true) == str
    end

    @testset "issue #218" begin
        str_ = raw"""
        for MT in GROUP_MANIFOLD_BASIS_DISAMBIGUATION
            eval(quote
                @invoke_maker 1 Manifold get_vector(M::$MT, e::Identity, X, B::VeeOrthogonalBasis)
            end)
        end"""
        str = raw"""
        for MT in GROUP_MANIFOLD_BASIS_DISAMBIGUATION
            eval(
                quote
                    @invoke_maker 1 Manifold get_vector(
                        M::$MT,
                        e::Identity,
                        X,
                        B::VeeOrthogonalBasis,
                    )
                end,
            )
        end"""
        @test fmt1(str_) == str
        @test fmt(str_) == str
    end

    @testset "issue 248" begin
        str_ = """
        var = call(a, @macrocall b)"""
        str = """
        var =
            call(
                a,
                @macrocall b
            )"""
        @test fmt(str_, 4, 1) == str
    end

    @testset "issue 260 - BracesCat" begin
        str = "{1; 2; 3}"
        @test fmt(str, 4, length(str)) == str

        str_ = "{1; 2; 3}"
        str = """
        {
          1;
          2;
          3
        }"""
        @test fmt(str_, 2, length(str_) - 1) == str
        @test fmt(str, 2, length(str_)) == str_

        str_ = "{1; 2; 3;}"
        str = "{1; 2; 3}"
        @test fmt(str_, 2, 90) == str
    end

    @testset "issue 262 - removal of @ in nested macrocall" begin
        str = raw":($(@__MODULE__).@macro)"
        @test fmt(str) == str

        str = raw":($(@__MODULE__).property)"
        @test fmt(str) == str

        str = raw":($(@__MODULE__))"
        @test fmt(str) == str

        str_ = raw":($(@__MODULE__.macro).field.macro)"
        str = raw":($(__MODULE__.@macro).field.macro)"
        @test fmt(str_) == str
        @test fmt(str) == str

        str_ = raw"@a.b.c"
        str = raw"a.b.@c"
        @test fmt(str_) == str
        @test fmt(str) == str
    end

    @testset "issue 264 - `let` empty block body" begin
        str_ = "let; end"
        str = """
        let;
        end"""
        @test fmt(str_) == str
    end

    @testset "issue 268 - whitespace around dot op if LHS is number literal" begin
        str = "xs[-5 .<= xs .& xs .<= 5]"
        @test fmt(str) == str
        str_ = "xs[(-5 .<= xs).&(xs.<=5)]"
        str = "xs[(-5 .<= xs) .& (xs .<= 5)]"
        @test fmt(str_) == str
    end

    @testset "issue 277 - flatten ops when no whitespace is allowed" begin
        # previously this would remove |>
        str_ = "get_actions(env)[env |> π.learner |> π.explorer]"
        str = "get_actions(env)[env|>π.learner|>π.explorer]"
        @test fmt(str_) == str
        @test fmt(str; whitespace_ops_in_indices = true) == str_
    end

    @testset "issue 286 - Float32 leading/trailing zeros" begin
        str_ = """
        a = 3.f0
        b = 3f0
        c = 30f0
        d = 30.0f0
        e = 30.123f0
        f = .123f0
        """
        str = """
        a = 3.0f0
        b = 3.0f0
        c = 30.0f0
        d = 30.0f0
        e = 30.123f0
        f = 0.123f0
        """
        @test fmt(str_) == str

        @testset "500 - leading zeros with '-.'" begin
            s0 = """
            a = -.2
            b = - .2
            """
            s1 = """
            a = -0.2
            b = - 0.2
            """
            @test fmt(s0) == s1

            s0 = """
            a = -.2f32
            b = - .2f32
            """
            s1 = """
            a = -0.2f32
            b = - 0.2f32
            """
            @test fmt(s0) == s1

            s0 = """
            a = -.2f-5
            b = - .2f-5
            """
            s1 = """
            a = -0.2f-5
            b = - 0.2f-5
            """
            @test fmt(s0) == s1
        end
    end

    @testset "issue 289 - no spaces/nesting for matrix elements" begin
        str_ = """
        A =  [0. 1 0 0
           -k/Jm -c/Jm k/Jm c/Jm
            0 0 0 1
            f(1,2) c/Ja -k/Ja -c/Ja]
        """

        str = """
        A =
            [
                0.0 1 0 0
                -k/Jm -c/Jm k/Jm c/Jm
                0 0 0 1
                f(1, 2) c/Ja -k/Ja -c/Ja
            ]
        """
        @test fmt(str_, 4, 1) == str
    end

    @testset "issue 317 - infinite recursion" begin
        str = raw"""
        SUITE["manifolds"][name]["tv = 2 * tv1 + 3 * tv2"] = @benchmarkable $tv =
            2 * $tv1 + 3 * $tv2
        """
        @test format_text(str, BlueStyle()) == str
    end

    @testset "issue 324 - bounds error when aligning binary op calls" begin
        # caused by the star operator
        str_ = """
        θ = eigvals(Matrix([0I(n^2) -I(n^2); P0 P1]), -Matrix([I(n^2) 0I(n^2); 0I(n^2) P2]))
        c = maximum(abs.(θ[(imag.(θ).==0).*(real.(θ).>0)]))
        """
        str = """
        θ = eigvals(Matrix([0I(n^2) -I(n^2); P0 P1]), -Matrix([I(n^2) 0I(n^2); 0I(n^2) P2]))
        c = maximum(abs.(θ[(imag.(θ) .== 0) .* (real.(θ) .> 0)]))
        """
        @test format_text(str_; align_assignment = true) == str
    end

    @testset "issue 332" begin
        # this string has a nbsp after 'c'
        # so it should have an additional byte because
        # it's unicode
        str_ = """a = b || c ;
               f("A")"""
        str = """a = b || c;
               f("A")"""
        @test format_text(str_) == str
    end

    @testset "issue 336" begin
        str_ = """
        nzthis = _hessian_slice(d, ex, x, H, obj_factor, nzcount, recovery_tmp_storage, Val{1})::Int
        """
        str = """
        nzthis = _hessian_slice(
            d,
            ex,
            x,
            H,
            obj_factor,
            nzcount,
            recovery_tmp_storage,
            Val{1},
        )::Int
        """
        @test fmt(str_, 4, 80) == str
    end

    @testset "issue 375" begin
        s = raw"conflictstatus = @jimport ilog.cp.IloCP$ConflictStatus"
        @test fmt(s) == s

        s = raw"conflictstatus = @jimport ilog.cp.IloCP$ConflictStatus"
        @test bluefmt(s) == s
    end

    @testset "issue 352" begin
        str_ = """
                      @inbounds for f in 1:n_freqs, m in 1:n_channels, l in 1:n_channels, k in 1:length(weighted_evals)
                         a = f + m + l + k
                      end"""
        str = """
        @inbounds for f in 1:n_freqs, m in 1:n_channels, l in 1:n_channels,
                      k in 1:length(weighted_evals)

            a = f + m + l + k
        end"""
        @test yasfmt(str_; always_for_in = true, join_lines_based_on_source = false) == str

        str_ = """
        using Test

        @testset "A long testset name that is rather long" for variable in 100:200, other_var in 1:100
            @test true
        end
        """
        str = """
        using Test

        @testset "A long testset name that is rather long" for variable in 100:200,
            other_var in 1:100

            @test true
        end
        """
        @test bluefmt(str_; always_for_in = true) == str
    end

    @testset "issue 387" begin
        str_ = """new{T1,T2}(arg1,arg2)"""
        str = """
        new{T1,
            T2}(arg1,
                arg2)"""
        @test yasfmt(str_; m = 1) == str
    end

    if VERSION >= v"1.6.0"
        @testset "issue 396 (import as)" begin
            str = """import Base.threads as th"""
            @test fmt(str) == str
            @test fmt(str; m = 1) == str
            @test fmt(str; m = 1, import_to_using = true) == str
        end
    end

    @testset "issue 405" begin
        str = """
        function __init__()
            raw\""" Doc string.\"""f
        end
        """
        @test fmt(str; always_use_return = true) == str

        str = """
        function __init__()
            @doc raw\"""
            Doc string.
            \"""
            f
        end
        """
        @test fmt(str; always_use_return = true) == str

        str = """
        function __init__()
            raw\"""
            Doc string.
            \"""
            f
        end
        """
        @test fmt(str; always_use_return = true) == str
    end

    @testset "issue 417" begin
        str = """
        formαt"JPEG"
        """
        @test fmt(str) == str

        str = """
        A.formαt"JPEG"
        """
        @test fmt(str) == str

        str = """
        A.B.formαt"JPEG"
        """
        @test fmt(str) == str
    end

    @testset "issue 419" begin
        str = """
        [z for y in x for z in y]
        """
        @test yasfmt(str) == str
        @test yasfmt(str; m = 25) == str

        str_ = """
        [z for y in x
         for z in y]
        """
        @test yasfmt(str; m = 24) == str_

        str_ = """
        [z
         for y in
             x
         for z in
             y]
        """
        @test yasfmt(str; m = 1) == str_
    end

    @testset "issue 427" begin
        str = "var\"##iv#469\" = (@variables(t))[1]"
        @test fmt(str) == str

        str_ = """
        var\"##iv#469\" =
            (@variables(t))[1]"""
        @test fmt(str; m = length(str) - 1) == str_
    end

    @testset "issue 429" begin
        str = """
        find_derivatives!(vars, expr::Equation, f=identity) = (find_derivatives!(vars, expr.lhs, f); find_derivatives!(vars, expr.rhs, f); vars)
        """
        str_ = """
        function find_derivatives!(vars, expr::Equation, f = identity)
            (find_derivatives!(vars, expr.lhs, f); find_derivatives!(vars, expr.rhs, f); vars)
        end
        """
        @test fmt(str; m = 92, short_to_long_function_def = true) == str_
    end

    @testset "issue 440" begin
        str = "import Base.+"
        @test fmt(str) == str
    end

    @testset "issue 444" begin
        str_ = """
        function (a,b,c;)
        body
        end
        """
        str = """
        function (
            a,
            b,
            c;
        )
            body
        end
        """
        @test fmt(str_; m = 1) == str
        @test bluefmt(str_; m = 1) == str
    end

    @testset "issue 431" begin
        str = """
        local Jcx_rows, Jcx_cols, Jcx_vals, Jct_val
        """
        @test fmt(str) == str

        str_ = "global a=2,b"
        str = "global a=2, b"
        @test fmt(str_) == str

        str_ = "global a = 2,b"
        str = "global a = 2, b"
        @test fmt(str_) == str
    end

    @testset "issue 449" begin
        str = """
        (var"x" = 1.0,)
        """
        @test fmt(str) == str
    end

    @testset "issue 451" begin
        str_ = raw"""
        function _initialize_backend(pkg::AbstractBackend)
            sym = backend_package_name(pkg)
            @eval Main begin
                import $sym
                export $sym
            end
        end
        """
        str = raw"""
        function _initialize_backend(pkg::AbstractBackend)
            sym = backend_package_name(pkg)
            @eval Main begin
                using $sym: $sym
                export $sym
            end
        end
        """
        @test fmt(str_; import_to_using = true) == str
    end

    @testset "issue 456" begin
        str = """
        function update()
            @debug "isfull" dist = 3
            a = 4
            var3 = 2
        end
        """
        @test fmt(str; align_assignment = true) == str

        str = """
        function update()
            @debug "isfull" dist = 3
            a                    = 4
            var3    = 5
        end
        """
        str_aligned = """
        function update()
            @debug "isfull" dist = 3
            a                    = 4
            var3                 = 5
        end
        """
        @test fmt(str; align_assignment = true) == str_aligned
    end

    @testset "issue 460" begin
        # Do not allow import to using conversion when in a macroblock context such as:
        #
        #   @everywhere import A, B
        #
        # Prior to this change this would be rewritten as:
        #
        #   @everywhere
        #   using A: A
        #   using B: B
        #
        # which breaks the code.
        #
        # There's an easy fix such that the first `using` is on the same line as @everywhere
        # but beyond that we probably have to wrap it in a begin/end block. For now it's best
        # to just not do the conversion in this situation.
        str = """
        using Distributed
        @everywhere import Distributed
        have_workers = Distributed.nprocs() - 1
        """
        @test fmt(str; import_to_using = true) == str
    end

    @testset "issue 463" begin
        str = """
        using Test

        @testset "displayKw" begin
            struct S
                f
            end
        end
        """
        @test fmt(
            str;
            annotate_untyped_fields_with_any = false,
            align_struct_field = true,
        ) == str
    end

    @testset "issue 467" begin
        str_ = "-3.. -2"
        str = "-3 .. -2"
        @test fmt(str_) == str
        @test bluefmt(str_) == str
    end

    @testset "issue 473" begin
        str_ = "[1.0, 2.0, 3.0] .|> Int"
        str = "Int.([1.0, 2.0, 3.0])"
        @test fmt(str_; pipe_to_function_call = true) == str
        st = run_format(str_; opts = Options(; pipe_to_function_call = true))
        @test st.line_offset == length(str)
    end

    @testset "issue 475" begin
        # with the fix for #494 the keyword arguments transform is no longer applied
        # to macro calls.
        str = """
        @deprecate(
            presign(path::AWSS3.S3Path, duration::Period=Hour(1); config::AWSConfig=aws_config()),
            AWSS3.s3_sign_url(config, path.bucket, path.key, Dates.value(Second(duration))),
        )
        """
        @test fmt(
            str,
            4,
            100;
            whitespace_in_kwargs = false,
            separate_kwargs_with_semicolon = true,
        ) == str
        str = """
        @deprecate(
            presign(path::AWSS3.S3Path; duration::Period=Hour(1), config::AWSConfig=aws_config()),
            AWSS3.s3_sign_url(config, path.bucket, path.key, Dates.value(Second(duration))),
        )
        """
        @test fmt(
            str,
            4,
            100;
            whitespace_in_kwargs = false,
            separate_kwargs_with_semicolon = true,
        ) == str

        str = """
        @deprecate(presign(path::AWSS3.S3Path, duration::Period=Hour(1); config::AWSConfig=aws_config()),
                   AWSS3.s3_sign_url(config, path.bucket, path.key, Dates.value(Second(duration))),)
        """
        @test yasfmt(
            str,
            4,
            100;
            margin = 100,
            whitespace_in_kwargs = false,
            separate_kwargs_with_semicolon = true,
        ) == str

        str = """
        @deprecate(presign(path::AWSS3.S3Path, duration::Period=Hour(1), config::AWSConfig=aws_config()),
                   AWSS3.s3_sign_url(config, path.bucket, path.key, Dates.value(Second(duration))),)
        """
        @test yasfmt(
            str,
            4,
            100;
            margin = 100,
            whitespace_in_kwargs = false,
            separate_kwargs_with_semicolon = true,
        ) == str
    end

    @testset "485 - blue style binary/chain op nesting" begin
        str = """
        if primal_name isa Symbol ||
            Meta.isexpr(primal_name, :(.)) ||
            Meta.isexpr(primal_name, :curly)
            foo()
        end
        """
        @test bluefmt(str, 4, 80) == str

        str_ = """
        if a && b
        end
        """
        str = """
        if a &&
            b
        end
        """
        @test bluefmt(str_, 4, 1) == str

        str_ = """
        @test foo == bar == baz
        """
        str = """
        @test foo ==
            bar ==
            baz
        """
        @test bluefmt(str_, 4, 1) == str

        str_ = """
        @test foo == bar
        """
        str = """
        @test foo ==
            bar
        """
        @test bluefmt(str_, 4, 1) == str

        str = """
        const a =
            arg1 +
            arg2 +
            arg3
        """
        @test bluefmt(str, 4, 1) == str

        str = """
        const a =
            arg1 +
            arg2
        """
        @test bluefmt(str, 4, 1) == str
    end

    @testset "494" begin
        str = "Base.@deprecate f(x, y = x) g(x, y)\n"
        @test bluefmt(str) == str

        str = "Base.@deprecate f(x, y) g(x, y = y)\n"
        @test bluefmt(str) == str
    end

    @testset "509" begin
        code = """M.var"@f";"""
        @test fmt(code) == code

        code = """
        const var"@_assert" = Base.var"@assert"
        """
        @test fmt(code) == code
    end

    @testset "512" begin
        # the 3rd line in the multiline comment contains a bunch of spaces prior
        # to the newline, before this fix the whitespace prior to the start of
        # the comment would be prepended to that line so that on repeated indents
        # the spaces would keep increasing.
        str = """
        function make_router()
            function get_sesh()
                #=
                x

                x=#
            end
        end
        """
        @test fmt(fmt(str)) == str
    end

    @testset "513" begin
        # The first 2 tests handle the case presented in the issue.
        # However, during the fix I encountered a separate problem where
        # if there was an inline comment followed 1 or more standalone newlines,
        # such as:
        #
        # ```
        # a * # inline
        #
        # b
        # ```
        #
        # then the inline comment would be removed since removing extra newlines
        # exited the routine before inline comments were handled. To be fair this is
        # quite a far case and has not been reported as of yet.
        str_ = """
        (
            10 # i got removed!
            *
            10 # me too!
            +
            10 # hello
        )
        """
        str = """
        (
            10 # i got removed!
            * 10 # me too!
            + 10 # hello
        )
        """
        @test fmt(str_) == str

        str_ = """
        (
            10 # i got removed!
            * # omg
            10 # me too!
            + # more
            10 # hello
        )
        """
        str = """
        (
            10 # i got removed!
            * # omg
            10 # me too!
            + # more
            10 # hello
        )
        """
        @test fmt(str_) == str

        str_ = """
        (
            10 * # i got removed!

            10 + # me too!

            10 # hello
        )
        """
        str = """
        (
            10 * # i got removed!
            10 + # me too!
            10 # hello
        )
        """
        @test fmt(str_) == str

        # before this would format to f(a, b)
        str_ = """
        f(a, # comment

            b
        )
        """
        str = """
        f(
            a, # comment
            b,
        )
        """
        @test fmt(str_) == str
    end

    @testset "514" begin
        str_ = "output = input .|> f.g"
        str = "output = f.g.(input)"
        @test fmt(str_; pipe_to_function_call = true) == str

        str_ = "output = input .|> f.g.h"
        str = "output = f.g.h.(input)"
        @test fmt(str_; pipe_to_function_call = true) == str
    end

    @testset "526" begin
        str = "Base.:(|>)(r::AbstractRegister, blk::AbstractBlock) = apply!(r, blk)"
        @test fmt(str; pipe_to_function_call = true) == str
    end

    @testset "480" begin
        str = "@show (1,)"
        @test fmt(str) == str

        str = "@show(1,)"
        @test fmt(str) == str

        str = """
        @NamedTuple{a::Int, b::Int}[]

        @SVector[@SVector[1, 2], @SVector[1, 2]]
        """
        @test fmt(str) == str

        str = """
        @NamedTuple {a::Int, b::Int}[]

        @SVector[@SVector[1, 2], @SVector [1, 2]]
        """
        @test fmt(str) == str
    end

    @testset "530" begin
        radical_ops = ("√", "∛", "∜")
        @testset "DefaultStyle" begin
            for op in radical_ops
                s = "3$(op)2"
                @test fmt(s) == s
            end
        end

        @testset "DefaultStyle" begin
            for op in radical_ops
                s = "3$(op)2"
                @test bluefmt(s) == s
            end
        end
    end

    @testset "533" begin
        # semicolon should not be added prior to `extrap` since it's a function definition.
        s = "function linterp(x0::T, y0::T, x1::T, y1::T, x::T, extrap::Bool = false)::T where {T<:AbstractFloat} end"
        @test bluefmt(s; m = 200) == s
        @test yasfmt(s; m = 200) == s

        s = "function linterp(x0::T, y0::T, x1::T, y1::T, x::T, extrap::Bool = false)::T end"
        @test bluefmt(s; m = 200) == s
        @test yasfmt(s; m = 200) == s
    end

    @testset "541" begin
        str = """
        [10;]
        """
        @test fmt(str; align_matrix = true) == str
        str = """
        [0:0.2:50;]
        """
        @test fmt(str; align_matrix = true) == str
    end

    @testset "543" begin
        str_ = """
        G4 = [ H    Zero  H; Zero    H   H
              Zero  Zero  H]
        """
        str = """
        G4 = [
             H    Zero  H;
            Zero    H   H
            Zero  Zero  H
        ]
        """
        @test fmt(str_; align_matrix = true) == str

        str_ = """
        H = [1 1; 1 1]
        Zero = [0 0; 0 0]

        G1 = vcat(hcat(H,    Zero, H),
                  hcat(Zero, H,    H),
                  hcat(Zero, Zero, H))

        G2 = [ H    Zero  H
              Zero    H   H
              Zero  Zero  H]

        G3 = [ H    Zero  H;
              Zero    H   H
              Zero  Zero  H]

        G4 = [ H    Zero  H; Zero    H   H
              Zero  Zero  H]
        """
        str = """
        H = [1 1; 1 1]
        Zero = [0 0; 0 0]

        G1 = vcat(hcat(H, Zero, H), hcat(Zero, H, H), hcat(Zero, Zero, H))

        G2 = [
             H    Zero  H
            Zero    H   H
            Zero  Zero  H
        ]

        G3 = [
             H    Zero  H;
            Zero    H   H
            Zero  Zero  H
        ]

        G4 = [
             H    Zero  H;
            Zero    H   H
            Zero  Zero  H
        ]
        """
        @test fmt(str_; align_matrix = true) == str
    end

    @testset "546" begin
        str = """
        function _plot_augmented_roc(inference_signals::DataFrame, per_threshold_sensitivity,
                                     thresholds; save_dir=nothing, save_prefix="", title_suffix="",
                                     xaxis_prefix="Control dataset: ")
            plot_data = augment_roc_data(inference_signals, thresholds)
            _plot_augmented_roc(plot_data, per_threshold_sensitivity;
                                       save_dir=save_dir, save_prefix=save_prefix,
                                       title_suffix=title_suffix, xaxis_prefix=xaxis_prefix)
        end
        """
        str_ = """
        function _plot_augmented_roc(inference_signals::DataFrame, per_threshold_sensitivity,
                                     thresholds; save_dir=nothing, save_prefix="", title_suffix="",
                                     xaxis_prefix="Control dataset: ")
            plot_data = augment_roc_data(inference_signals, thresholds)
            return _plot_augmented_roc(plot_data, per_threshold_sensitivity;
                                       save_dir=save_dir, save_prefix=save_prefix,
                                       title_suffix=title_suffix, xaxis_prefix=xaxis_prefix)
        end
        """
        @test yasfmt(
            str,
            4,
            92;
            join_lines_based_on_source = true,
            always_use_return = true,
            whitespace_in_kwargs = false,
        ) == str_
    end

    @testset "568" begin
        s = """
        function (func(arg))
            body
        end
        """
        # no trailing comma since (arg) is semantically different from (arg,) !!!
        # NOTE: as of CSTParser 3.4.0 this is no longe parsed as a tuple but as invisbrackets
        # so we don't need to worry about it
        s_ = """
        function (func(
            arg,
        ))
            body
        end
        """
        @test fmt(s, 4, 19) == s_
    end

    @testset "571" begin
        s = """
        arraycopy_common(false#=fwd=#, LLVM.Builder(B), orig, origops[1], gutils)
        return nothing
        """
        s_ = """
        arraycopy_common(false#=fwd=#, LLVM.Builder(B), orig, origops[1], gutils)
        return nothing
        """
        @test fmt(s) == s_

        s1 = """
        foo(a, b, #=c=#)
        """
        s2 = """
        foo(
            a,
            b,#=c=#
        )
        """
        @test fmt(s1, 4, 1) == s2
    end

    @testset "604" begin
        str = raw"""
        begin @foo a end
        """
        str_ = raw"""
        begin
            @foo a
        end
        """
        @test format_text(str, SciMLStyle()) == str_

        str = raw"""
        begin @foo(a) end
        """
        str_ = raw"""
        begin
            @foo(a)
        end
        """
        @test format_text(str, SciMLStyle()) == str_
    end

    @testset "613" begin
        s = """
        x = ```
        my_cmd very_long command that really should be multi-line but isn't, and exceeds the character limit, will be indented forever by repeated calls to format
        ```
        """
        @test format_text(s) == s
    end

    @testset "636" begin
        s = "a |> M.f"
        @test fmt(s, 4, 92; pipe_to_function_call = true) == "M.f(a)"

        # -> has a higher precedence than |>
        s = """
        coordsperm = coords .|> x -> x.I[[2, 1, 3]] |> CartesianIndex
        """
        s_ = """
        coordsperm = (x -> CartesianIndex(x.I[[2, 1, 3]])).(coords)
        """
        @test fmt(s, 4, 92; pipe_to_function_call = true) == s_

        # -> has a higher precedence than |>
        s = """
        coordsperm = coords .|> x -> x.I[[2, 1, 3]] .|> CartesianIndex
        """
        s_ = """
        coordsperm = (x -> CartesianIndex.(x.I[[2, 1, 3]])).(coords)
        """
        @test fmt(s, 4, 92; pipe_to_function_call = true) == s_

        s = """
        coordsperm = coords .|> (x -> x.I[[2, 1, 3]]) .|> CartesianIndex
        """
        s_ = """
        coordsperm = CartesianIndex.((x -> x.I[[2, 1, 3]]).(coords))
        """
        @test fmt(s, 4, 92; pipe_to_function_call = true) == s_

        s = """
        coordsperm = coords |> (x -> x.I[[2, 1, 3]]) |> CartesianIndex
        """
        s_ = """
        coordsperm = CartesianIndex((x -> x.I[[2, 1, 3]])(coords))
        """
        @test fmt(s, 4, 92; pipe_to_function_call = true) == s_
    end

    @testset "618" begin
        s = """
        2 |> x -> 2x
        """
        s_ = """
        (x -> 2x)(2)
        """
        @test fmt(s, 4, 92; pipe_to_function_call = true) == s_
    end

    @testset "644" begin
        s = """
        @foo @noinline Base.@constprop :none aaaaaaaaaaaaa() = 0
        @foo @noinline Base.@constprop :none bbbbbbbbbbbbbbbbbbb()     = 0
        @foo @foo @ccccccccccccccccccccccccccccccccccccccccccccccccc() = 0
        """
        s_ = """
        @foo @noinline Base.@constprop :none aaaaaaaaaaaaa()           = 0
        @foo @noinline Base.@constprop :none bbbbbbbbbbbbbbbbbbb()     = 0
        @foo @foo @ccccccccccccccccccccccccccccccccccccccccccccccccc() = 0
        """
        @test fmt(s, 4, 92; align_assignment = true) == s_

        # no manual edit
        s = """
        @foo @noinline Base.@constprop :none aaaaaaaaaaaaa() = 0
        @foo @noinline Base.@constprop :none bbbbbbbbbbbbbbbbbbbbbbb() = 0
        @foo @foo @ccccccccccccccccccccccccccccccccccccccccccccccccc() = 0
        """
        @test fmt(s, 4, 92; align_assignment = true) == s
    end

    @testset "655" begin
        s = """
        [
          a;
        ]
        """
        @test fmt(s, 2, 92; join_lines_based_on_source = true) == s
        @test fmt(s, 2, 1) == s
        s = """
        [
          a
        ]
        """
        @test fmt(s, 2, 92; join_lines_based_on_source = true, trailing_comma = nothing) ==
              s
        @test fmt(s, 2, 1; trailing_comma = nothing) == s
    end

    @testset "656" begin
        s = "[x for x in xs if x in 1:length(ys)]"
        @test fmt(s, 4, 92) == s
    end

    @testset "667" begin
        s = raw"""
        \"""
            𝐀

        A dimension representing Angle.

        !!! note "Not SI"

            *Angle* is not an SI base dimension.
        \"""
        @dimension 𝐀 "𝐀" Angle true
        """
        @test fmt(s; format_docstrings = true) == s
    end

    @testset "682" begin
        str_ = """
        var = call(a; arg=@macrocall b)"""
        str = """
        var =
            call(
                a;
                arg = @macrocall b
            )"""
        @test fmt(str_, 4, 1) == str
    end

    @testset "686" begin
        s1 = """
        abc() = begin
          1
        end
        """
        s2 = """
        function abc()
          1
        end
        """
        @test fmt(s1, 2, 5; short_to_long_function_def = true) == s2
    end

    @testset "698" begin
        s1 = """
        let hello() = begin
                print("ok")
            end
            hello()
        end

        let hello() = print("ok");
            hello()
        end
        """
        s2 = """
        let hello() =
                begin
                    print(
                        "ok",
                    )
                end
            hello()
        end

        let hello() =
                print(
                    "ok",
                );
            hello()
        end
        """
        @test fmt(s1, 4, 10; short_to_long_function_def = true) == s2
    end

    @testset "700" begin
        s1 = """
        a_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooong_array_name = [1 1; 1 1]

        x = a_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooong_array_name[sum(a_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooong_array_name[:, 1]), :]
        """
        s2 = """
        a_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooong_array_name = [1 1; 1 1]

        x = a_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooong_array_name[
            sum(a_loooooooooooooooooooooooooooooooooooooooooooooooooooooooooong_array_name[:, 1]), :,
        ]
        """
        @test bluefmt(s1, 4, 92) == s2
    end

    if VERSION >= v"1.8"
        @testset "703" begin
            s = """
            mutable struct A
                const a :: Int
                bcd     :: String
            end
            """
            @test fmt(s, 4, 92; align_struct_field = true) == s
        end
    end

    @testset "713" begin
        s1 = """
        [1. 1; 1 -1]
        """
        s2 = """
        [1.0 1; 1 -1]
        """
        @test fmt(s1, 4, 92; align_matrix = true) == s2
    end

    @testset "714" begin
        s1 = """
        A = [-2.. -1 3..4; 5..6 7..8]
        """
        s2 = """
        A = [-2 .. -1 3..4; 5..6 7..8]
        """
        @test fmt(s1, 4, 92) == s2
    end

    @testset "715" begin
        s = """
        map(1:10) do x
            # empty
        end
        """
        @test fmt(s, 4, 92; always_use_return = true) == s
    end
    @testset "728" begin
        s = """
        begin
        #! format: noindent

        # This is OK
        function foo end

        # This is not

        end
        """
        @test fmt(s, 4, 92) == s

        s = """
        begin
        #! format: noindent

        end
        """
        @test fmt(s, 4, 92) == s
    end

    @testset "743" begin
        s = """
        foo(ᶜa) = - ᶜa
        """
        @test fmt(s, 4, 92) == s
        @test format_text(s, SciMLStyle()) == s
    end

    if VERSION >= v"1.8"
        @testset "745" begin
            s = "[;;;]"
            @test fmt(s, 4, 92) == s
            @test fmt(s, 4, 1) == s
        end
    end

    @testset "748" begin
        # this started out as an error with SciMLStyle but I narrowed it down to an edge case
        # with the `join_lines_based_on_source` option with vcat types
        str_ = """
        [0.128483; 1.256853; 0.0030203; 0.0027977; 0.0101511; 0.0422942; 0.2391346;
                  0.0008014; 0.0001464; 2.67e-05; 4.8e-6; 9e-7; 0.0619917; 1.2444292; 0.0486676;
                  199.9383546; 137.4267984; 1.5180203; 1.5180203]
        """
        str = """
        [0.128483; 1.256853; 0.0030203; 0.0027977; 0.0101511; 0.0422942; 0.2391346;
            0.0008014; 0.0001464; 2.67e-05; 4.8e-6; 9e-7; 0.0619917; 1.2444292; 0.0486676;
            199.9383546; 137.4267984; 1.5180203; 1.5180203]
        """
        @test fmt(str_, 4, 92; join_lines_based_on_source = true) == str
    end

    @testset "753" begin
        str_ = """
        using ModelingToolkit
        @mtkmodel A begin
                @variables begin
                        i(t) = 0.0, [description = "Line longer than the char limit of 94 characters", unit = u"A"]
                end
        end
        """
        str = """
        using ModelingToolkit
        @mtkmodel A begin
            @variables begin
                i(t) = 0.0,
                [description = "Line longer than the char limit of 94 characters", unit = u"A"]
            end
        end
        """
        @test format_text(str_, SciMLStyle()) == str
    end

    @testset "624" begin
        s = """
        deploydocs(;
            repo="github.com/julia-vscode/CSTParser.jl",
        )
        """
        s1 = format_text(s, MinimalStyle())
        @test format_text(s1, MinimalStyle()) == s
    end

    @testset "769" begin
        s = raw"""
        @assert x isa Tuple \"msg\"
        """
        @test format_text(s, SciMLStyle()) == s
    end

    @testset "779" begin
        s = "Int <: B where {B} && Int <: C where {C}"
        fmt(s) == s
    end

    if VERSION >= v"1.8"
        @testset "802" begin
            s = """
            mutable struct Foo
                const a
            end
            """
            @test fmt(s, 4, 92; align_struct_field = true) == s
        end
    end

    @testset "810" begin
        s = """
        @f(a, b, c)
        """
        @test format_text(s, SciMLStyle()) == s
    end

    @testset "817" begin
        s = raw"""
        a = ["Unknown" => SubRegion.Unknown, "Northern Europe" => SubRegion.Northern_Europe, "Southern Asia" => SubRegion.Southern_Asia, "Western Europe" => SubRegion.Western_Europe, "Sub-Saharan Africa" => SubRegion.Sub_Saharan_Africa, "Western Asia" => SubRegion.Western_Asia, "Eastern Asia" => SubRegion.Eastern_Asia, "Northern America" => SubRegion.Northern_America, "South-eastern Asia" => SubRegion.South_eastern_Asia, "Australia and New Zealand" => SubRegion.Australia_and_New_Zealand, "Eastern Europe" => SubRegion.Eastern_Europe, "Latin America and the Caribbean" => SubRegion.Latin_America_and_the_Caribbean, "Southern Europe" => SubRegion.Southern_Europe, "Central Asia" => SubRegion.Central_Asia]
        """
        s2 = raw"""
        a = ["Unknown" => SubRegion.Unknown, "Northern Europe" => SubRegion.Northern_Europe,
            "Southern Asia" => SubRegion.Southern_Asia,
            "Western Europe" => SubRegion.Western_Europe,
            "Sub-Saharan Africa" => SubRegion.Sub_Saharan_Africa,
            "Western Asia" => SubRegion.Western_Asia, "Eastern Asia" => SubRegion.Eastern_Asia,
            "Northern America" => SubRegion.Northern_America,
            "South-eastern Asia" => SubRegion.South_eastern_Asia,
            "Australia and New Zealand" => SubRegion.Australia_and_New_Zealand,
            "Eastern Europe" => SubRegion.Eastern_Europe,
            "Latin America and the Caribbean" => SubRegion.Latin_America_and_the_Caribbean,
            "Southern Europe" => SubRegion.Southern_Europe,
            "Central Asia" => SubRegion.Central_Asia]
        """
        @test format_text(s, SciMLStyle()) == s2
    end

    @testset "822" begin
        s = """
        ℯ #=
        =#
        """
        @test format_text(s) == s

        s = """
        begin
            π => im #=
            comment =#
        end
        """
        @test format_text(s) == s
    end

    @testset "820" begin
        s = "this_func(::Tuple{<:(some_func())}) = nothing"
        @test format_text(s) == s
    end

    @testset "820" begin
        s1 = """
        X = (
            xxxxx=["xxxx", "xxxx", "xxxx"],
            xxxxx=["xxxx", "xxxx", "xxxx"]
        )
        """
        s2 = """
        X = (
            xxxxx=["xxxx", "xxxx", "xxxx"],
            xxxxx=["xxxx", "xxxx", "xxxx"],
        )
        """
        @test format_text(
            s1;
            style = BlueStyle(),
            trailing_comma = true,
            join_lines_based_on_source = true,
        ) == s2

        s1 = """
        XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX = (
            xxxxx=["xxxx", "xxxx", "xxxx"],
            xxxxx=["xxxx", "xxxx", "xxxx"]
        )
        """
        s2 = """
        XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX = (
            xxxxx=["xxxx", "xxxx", "xxxx"],
            xxxxx=["xxxx", "xxxx", "xxxx"],
        )
        """
        @test format_text(
            s1;
            style = BlueStyle(),
            trailing_comma = true,
            join_lines_based_on_source = true,
        ) == s2
    end

    @testset "774" begin
        str = """
        getdata() = rand() < 0.5 ? rand() : missing

        function dowork()
            while !ismissing((val = getdata();))
                println(val^2)
            end
        end
        """
        @test fmt(str) == str
    end

    if VERSION >= v"1.7"
        @testset "876" begin
            str_ = """
            function find_horizontal(geom::GIWrap.Polygon)::Vector{Tuple{Float64,Float64}}
                coords = collect(GI.coordinates(geom)...)
                first_coord = first(coords)
                second_coord = coords[
                    (getindex.(coords, 2) .∈ first_coord[2]) .&&
                    (getindex.(coords, 1) .∉ first_coord[1])
                ]

                return [tuple(first_coord...), tuple(first(second_coord)...)]
            end
            """
            str = """
            function find_horizontal(geom::GIWrap.Polygon)::Vector{Tuple{Float64,Float64}}
                coords = collect(GI.coordinates(geom)...)
                first_coord = first(coords)
                second_coord = coords[
                    (getindex.(coords, 2) .∈ first_coord[2]) .&& (getindex.(coords, 1) .∉ first_coord[1])
                ]

                return [tuple(first_coord...), tuple(first(second_coord)...)]
            end
            """
            f1 = format_text(str_, BlueStyle(); join_lines_based_on_source = true)
            @test f1 == str
            f1 = format_text(f1, BlueStyle(); join_lines_based_on_source = true)
            @test f1 == str
        end
    end

    @testset "880" begin
        s1 = "constant_list[node_index.val:: UInt16]"
        s2 = "constant_list[node_index.val::UInt16]"
        @test s1 = fmt(s1, 4, 100, whitespace_ops_in_indices = true) == s2

        s1 = "constant_list[node_index.val+ UInt16]"
        s2 = "constant_list[node_index.val + UInt16]"
        @test s1 = fmt(s1, 4, 100, whitespace_ops_in_indices = true) == s2

        s = ".!purge"
        @test s = fmt(s, 4, 100) == s
    end

    @testset "912" begin
        s = """
        try
            nothing
        catch e
            nothing
        else
            nothing
        end
        """
        @test fmt(s, 4, 100) == s

        str_ = """
        try
         # comment
         catch e
         # comment
        body
         # comment
         else
         # comment
         end
        """
        s = """
        try
            # comment
        catch e
            # comment
            body
            # comment
        else
            # comment
        end
        """
        @test fmt(str_, 4, 100) == s
    end

    @testset "917" begin
        s = "using Foo: ( .. )"
        sf = "using Foo: (..)"
        @test fmt(s, 4, 100) == sf
    end

    @testset "921" begin
        # These are floating point literals with hexadecimal significands. E.g. 0x1p1 is the
        # float with with 0x1 as the significant and 1 as the exponent.
        s = "0x1p1"
        @test fmt(s) == s
        s = "+0x1p1"
        @test fmt(s) == s
        s = "-0x1p1"
        @test fmt(s) == s
    end
end
