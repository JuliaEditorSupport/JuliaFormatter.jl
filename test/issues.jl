module IssuesTests

using JuliaFormatter
using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, MinimalStyle, SciMLStyle, Options, format_text
using JuliaFormatter.Internal: test_format, ALL_STYLES
using JuliaSyntax
using Test

function run_nest(text::String; opts = Options(), style = DefaultStyle())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; version=JuliaFormatter.SUPPORTED_SYNTAX_VERSION)
    t = JuliaFormatter.pretty(style, g, s)
    JuliaFormatter.nest!(style, t, s)
    t, s
end

@testset "GitHub Issues" begin
    @testset "137" begin
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
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1048
        @test_broken false
        # test_format(str_, str)

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
              x = f() do
                  body
              end
              x
          end for x in xs)"""
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1048
        @test_broken false
        # test_format(str_, str)

        str = """
        let n = try
                ..
            catch
                ..
            end
            ..
        end"""
        test_format(str, str)

        str = """
        let n = let
                ..
            end
            ..
        end"""
        test_format(str, str)

        str = """
        let n = begin
                ..
            end
            ..
        end"""
        test_format(str, str)
    end

    @testset "139" begin
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
        test_format(str_, str)

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
        test_format(str_, str)

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
        test_format(str_, str)

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
        test_format(str_, str)
    end

    @testset "150" begin
        str_ = "const SymReg{B,MT} = ArrayReg{B,Basic,MT} where {MT <:AbstractMatrix{Basic}}"
        str = "const SymReg{B,MT} = ArrayReg{B,Basic,MT} where {MT<:AbstractMatrix{Basic}}"
        test_format(str_, str; whitespace_typedefs = false)

        str = "const SymReg{B, MT} = ArrayReg{B, Basic, MT} where {MT <: AbstractMatrix{Basic}}"
        test_format(str_, str; whitespace_typedefs = true)
    end

    @testset "170" begin
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
        # https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1048
        @test_broken false
        # test_format(str_, str)

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
        test_format(str, str)

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
        test_format(str_, str)
        _, s = run_nest(str_; opts = Options(; margin = 100))
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
        test_format(str_, str)
        _, s = run_nest(str_; opts = Options(; margin = 100))
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
        test_format(str_, str)
        _, s = run_nest(str_; opts = Options(; margin = 100))
        @test s.line_offset == 1
    end

    @testset "183 & 525" begin
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
        test_format(str_, str)
    end

    @testset "189" begin
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
        test_format(str_, str)
    end

    @testset "193" begin
        str = """
        module Module
        # comment
        end"""
        test_format(str, str)

        str = """
        module Module
        # comment
        @test
        # comment
        end"""
        test_format(str, str)
    end

    @testset "194" begin
        str_ = """
        function mystr( str::String )
        return SubString( str, 1:
        3 )
        end"""
        str = """
        function mystr(str::String)
            return SubString(str, 1:3)
        end"""
        test_format(str_, str)
    end

    @testset "200" begin
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
        test_format(str_, str; margin = 81)
        test_format(str, str_; margin = 82)
    end

    @testset "202" begin
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
        test_format(str_, str; margin = 92)

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
        test_format(str_, str; margin = 92)
    end

    @testset "207" begin
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
        test_format(str_, str; margin = 92)

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {T, TGP <: AbstractGP{T}; IsMultiOutput{TGP}} end"""
        test_format(str_, str; margin = 92, whitespace_typedefs = true)

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
        test_format(str_, str; margin = 92)

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {C <: Union{T, TGP <: AbstractGP{T}; IsMultiOutput{TGP}}} end"""
        test_format(str_, str; margin = 92, whitespace_typedefs = true)
    end

    @testset "218" begin
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
        test_format(str_, str)
        test_format(str_, str)
    end

    @testset "248" begin
        str_ = """
        var = call(a, @macrocall b)"""
        str = """
        var =
            call(
                a,
                @macrocall b
            )"""
        test_format(str_, str; indent=4, margin=1)
    end

    @testset "260 - BracesCat" begin
        str = "{1; 2; 3}"
        test_format(str, str; indent=4, margin=length(str))

        str_ = "{1; 2; 3}"
        str = """
        {
          1;
          2;
          3
        }"""
        test_format(str_, str; indent=2, margin=length(str_) - 1)
        test_format(str, str_; indent=2, margin=length(str_))

        str_ = "{1; 2; 3;}"
        str = "{1; 2; 3}"
        test_format(str_, str; indent=2, margin=90)
    end

    @testset "262 - removal of @ in nested macrocall" begin
        str = raw":($(@__MODULE__).@macro)"
        test_format(str, str)

        str = raw":($(@__MODULE__).property)"
        test_format(str, str)

        str = raw":($(@__MODULE__))"
        test_format(str, str)

        str_ = raw":($(@__MODULE__.macro).field.macro)"
        str = raw":($(__MODULE__.@macro).field.macro)"
        test_format(str_, str)
        test_format(str, str)

        str_ = raw"@a.b.c"
        str = raw"a.b.@c"
        test_format(str_, str)
        test_format(str, str)
    end

    @testset "264 - `let` empty block body" begin
        str_ = "let; end"
        str = """
        let;
        end"""
        test_format(str_, str)
    end

    @testset "268 - whitespace around dot op if LHS is number literal" begin
        str = "xs[-5 .<= xs .& xs .<= 5]"
        test_format(str, str)
        str_ = "xs[(-5 .<= xs).&(xs.<=5)]"
        str = "xs[(-5 .<= xs) .& (xs .<= 5)]"
        test_format(str_, str)
    end

    @testset "277 - flatten ops when no whitespace is allowed" begin
        # previously this would remove |>
        str_ = "get_actions(env)[env |> π.learner |> π.explorer]"
        str = "get_actions(env)[env|>π.learner|>π.explorer]"
        test_format(str_, str)
        test_format(str, str_; whitespace_ops_in_indices = true)
    end

    @testset "286 - Float32 leading/trailing zeros" begin
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
        test_format(str_, str)
    end

    @testset "289 - no spaces/nesting for matrix elements" begin
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
        test_format(str_, str; indent=4, margin=1)
    end

    @testset "317 - infinite recursion" begin
        str = raw"""
        SUITE["manifolds"][name]["tv = 2 * tv1 + 3 * tv2"] = @benchmarkable $tv =
            2 * $tv1 + 3 * $tv2
        """
        test_format(str, str, BlueStyle())
    end

    @testset "324 - bounds error when aligning binary op calls" begin
        # caused by the star operator
        str_ = """
        θ = eigvals(Matrix([0I(n^2) -I(n^2); P0 P1]), -Matrix([I(n^2) 0I(n^2); 0I(n^2) P2]))
        c = maximum(abs.(θ[(imag.(θ).==0).*(real.(θ).>0)]))
        """
        str = """
        θ = eigvals(Matrix([0I(n^2) -I(n^2); P0 P1]), -Matrix([I(n^2) 0I(n^2); 0I(n^2) P2]))
        c = maximum(abs.(θ[(imag.(θ) .== 0) .* (real.(θ) .> 0)]))
        """
        test_format(str_, str; align_assignment = true)
    end

    @testset "332" begin
        # this string has a nbsp after 'c'
        # so it should have an additional byte because
        # it's unicode
        str_ = """a = b || c ;
               f("A")"""
        str = """a = b || c;
               f("A")"""
        test_format(str_, str)
    end

    @testset "336" begin
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
        test_format(str_, str; indent=4, margin=80)
    end

    @testset "375" begin
        s = raw"conflictstatus = @jimport ilog.cp.IloCP$ConflictStatus"
        test_format(s, s)

        s = raw"conflictstatus = @jimport ilog.cp.IloCP$ConflictStatus"
        test_format(s, s, BlueStyle())
    end

    @testset "352" begin
        str_ = """
                      @inbounds for f in 1:n_freqs, m in 1:n_channels, l in 1:n_channels, k in 1:length(weighted_evals)
                         a = f + m + l + k
                      end"""
        str = """
        @inbounds for f in 1:n_freqs, m in 1:n_channels, l in 1:n_channels,
                      k in 1:length(weighted_evals)

            a = f + m + l + k
        end"""
        test_format(str_, str, YASStyle(); always_for_in = true, join_lines_based_on_source = false)

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
        test_format(str_, str, BlueStyle(); always_for_in = true)
    end

    @testset "387" begin
        str_ = """new{T1,T2}(arg1,arg2)"""
        str = """
        new{T1,
            T2}(arg1,
                arg2)"""
        test_format(str_, str, YASStyle(); margin = 1)
    end

    @testset "405" begin
        str = """
        function __init__()
            raw\""" Doc string.\"""f
        end
        """
        test_format(str, str; always_use_return = true)

        str = """
        function __init__()
            @doc raw\"""
            Doc string.
            \"""
            f
        end
        """
        test_format(str, str; always_use_return = true)

        str = """
        function __init__()
            raw\"""
            Doc string.
            \"""
            f
        end
        """
        test_format(str, str; always_use_return = true)
    end

    @testset "417" begin
        str = """
        formαt"JPEG"
        """
        test_format(str, str)

        str = """
        A.formαt"JPEG"
        """
        test_format(str, str)

        str = """
        A.B.formαt"JPEG"
        """
        test_format(str, str)
    end

    @testset "419" begin
        str = """
        [z for y in x for z in y]
        """
        test_format(str, str, YASStyle())
        test_format(str, str, YASStyle(); margin = 25)

        str_ = """
        [z for y in x
         for z in y]
        """
        test_format(str, str_, YASStyle(); margin = 24)

        str_ = """
        [z
         for y in
             x
         for z in
             y]
        """
        test_format(str, str_, YASStyle(); margin = 1)
    end

    @testset "427" begin
        str = "var\"##iv#469\" = (@variables(t))[1]"
        test_format(str, str)

        str_ = """
        var\"##iv#469\" =
            (@variables(t))[1]"""
        test_format(str, str_; margin = length(str) - 1)
    end

    @testset "429" begin
        str = """
        find_derivatives!(vars, expr::Equation, f=identity) = (find_derivatives!(vars, expr.lhs, f); find_derivatives!(vars, expr.rhs, f); vars)
        """
        str_ = """
        function find_derivatives!(vars, expr::Equation, f = identity)
            (find_derivatives!(vars, expr.lhs, f); find_derivatives!(vars, expr.rhs, f); vars)
        end
        """
        test_format(str, str_; margin = 92, short_to_long_function_def = true)
    end

    @testset "431" begin
        str = """
        local Jcx_rows, Jcx_cols, Jcx_vals, Jct_val
        """
        test_format(str, str)

        str_ = "global a=2,b"
        str = "global a=2, b"
        test_format(str_, str)

        str_ = "global a = 2,b"
        str = "global a = 2, b"
        test_format(str_, str)
    end

    @testset "440" begin
        str = "import Base.+"
        test_format(str, str)
    end

    @testset "444" begin
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
        test_format(str_, str; margin = 1)
        str = """
        function (
            a,
            b,
            c;
        )
            return body
        end
        """
        test_format(str_, str, BlueStyle(); margin = 1)
    end

    @testset "449" begin
        str = """
        (var"x" = 1.0,)
        """
        test_format(str, str)
    end

    @testset "451" begin
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
                import $sym
                export $sym
            end
        end
        """
        test_format(str_, str; import_to_using = true)
    end

    @testset "456" begin
        str = """
        function update()
            @debug "isfull" dist = 3
            a = 4
            var3 = 2
        end
        """
        test_format(str, str; align_assignment = true)

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
        test_format(str, str_aligned; align_assignment = true)
    end

    @testset "460" begin
        str = """
        using Distributed
        @everywhere import Distributed
        have_workers = Distributed.nprocs() - 1
        """
        test_format(str, str; import_to_using = true)
    end

    @testset "463" begin
        str = """
        using Test

        @testset "displayKw" begin
            struct S
                f
            end
        end
        """
        test_format(str, str; annotate_untyped_fields_with_any = false,
            align_struct_field = true)
    end

    @testset "467" begin
        str_ = "-3.. -2"
        str = "-3 .. -2"
        test_format(str_, str)
        test_format(str_, str, BlueStyle())
    end

    @testset "473" begin
        str_ = "[1.0, 2.0, 3.0] .|> Int"
        str = "Int.([1.0, 2.0, 3.0])"
        test_format(str_, str; pipe_to_function_call = true)
    end

    @testset "475" begin
        # with the fix for #494 the keyword arguments transform is no longer applied
        # to macro calls.
        str = """
        @deprecate(
            presign(path::AWSS3.S3Path, duration::Period=Hour(1); config::AWSConfig=aws_config()),
            AWSS3.s3_sign_url(config, path.bucket, path.key, Dates.value(Second(duration))),
        )
        """
        test_format(str, str; indent=4, margin=100, whitespace_in_kwargs = false,
            separate_kwargs_with_semicolon = true)
        str = """
        @deprecate(
            presign(path::AWSS3.S3Path; duration::Period=Hour(1), config::AWSConfig=aws_config()),
            AWSS3.s3_sign_url(config, path.bucket, path.key, Dates.value(Second(duration))),
        )
        """
        test_format(str, str; indent=4, margin=100, whitespace_in_kwargs = false,
            separate_kwargs_with_semicolon = true)

        str = """
        @deprecate(presign(path::AWSS3.S3Path, duration::Period=Hour(1); config::AWSConfig=aws_config()),
                   AWSS3.s3_sign_url(config, path.bucket, path.key, Dates.value(Second(duration))),)
        """
        test_format(str, str, YASStyle(); margin = 100,
            whitespace_in_kwargs = false,
            separate_kwargs_with_semicolon = true)

        str = """
        @deprecate(presign(path::AWSS3.S3Path, duration::Period=Hour(1), config::AWSConfig=aws_config()),
                   AWSS3.s3_sign_url(config, path.bucket, path.key, Dates.value(Second(duration))),)
        """
        test_format(str, str, YASStyle(); margin = 100,
            whitespace_in_kwargs = false,
            separate_kwargs_with_semicolon = true)
    end

    @testset "480" begin
        str = "@show (1,)"
        test_format(str, str)

        str = "@show(1,)"
        test_format(str, str)

        str = """
        @NamedTuple{a::Int, b::Int}[]

        @SVector[@SVector[1, 2], @SVector[1, 2]]
        """
        test_format(str, str)

        str = """
        @NamedTuple {a::Int, b::Int}[]

        @SVector[@SVector[1, 2], @SVector [1, 2]]
        """
        test_format(str, str)
    end

    @testset "485 - blue style binary/chain op nesting" begin
        str = """
        if primal_name isa Symbol ||
            Meta.isexpr(primal_name, :(.)) ||
            Meta.isexpr(primal_name, :curly)
            foo()
        end
        """
        test_format(str, str, BlueStyle(); indent=4, margin=80)

        str_ = """
        if a && b
        end
        """
        str = """
        if a &&
            b
        end
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=1)

        str_ = """
        @test foo == bar == baz
        """
        str = """
        @test foo ==
            bar ==
            baz
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=1)

        str_ = """
        @test foo == bar
        """
        str = """
        @test foo ==
            bar
        """
        test_format(str_, str, BlueStyle(); indent=4, margin=1)

        str = """
        const a =
            arg1 +
            arg2 +
            arg3
        """
        test_format(str, str, BlueStyle(); indent=4, margin=1)

        str = """
        const a =
            arg1 +
            arg2
        """
        test_format(str, str, BlueStyle(); indent=4, margin=1)
    end

    @testset "494" begin
        str = "Base.@deprecate f(x, y=x) g(x, y)\n"
        test_format(str, str, BlueStyle())

        str = "Base.@deprecate f(x, y) g(x, y=y)\n"
        test_format(str, str, BlueStyle())
    end

    @testset "500 - leading zeros with '-.'" begin
        s0 = """
        a = -.2
        b = - .2
        """
        s1 = """
        a = -0.2
        b = - 0.2
        """
        test_format(s0, s1)

        s0 = """
        a = -.2f32
        b = - .2f32
        """
        s1 = """
        a = -0.2f32
        b = - 0.2f32
        """
        test_format(s0, s1)

        s0 = """
        a = -.2f-5
        b = - .2f-5
        """
        s1 = """
        a = -0.2f-5
        b = - 0.2f-5
        """
        test_format(s0, s1)
    end

    @testset "509" begin
        code = """M.var"@f";"""
        test_format(code, code)

        code = """
        const var"@_assert" = Base.var"@assert"
        """
        test_format(code, code)
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
        test_format(str, str)
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
        test_format(str_, str)

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
        test_format(str_, str)

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
        test_format(str_, str)

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
        test_format(str_, str)
    end

    @testset "514" begin
        str_ = "output = input .|> f.g"
        str = "output = f.g.(input)"
        test_format(str_, str; pipe_to_function_call = true)

        str_ = "output = input .|> f.g.h"
        str = "output = f.g.h.(input)"
        test_format(str_, str; pipe_to_function_call = true)
    end

    @testset "526" begin
        str = "Base.:(|>)(r::AbstractRegister, blk::AbstractBlock) = apply!(r, blk)"
        test_format(str, str; pipe_to_function_call = true)
    end

    @testset "530" begin
        radical_ops = ("√", "∛", "∜")
        @testset "DefaultStyle" begin
            for op in radical_ops
                s = "3$(op)2"
                test_format(s, s)
            end
        end

        @testset "DefaultStyle" begin
            for op in radical_ops
                s = "3$(op)2"
                test_format(s, s, BlueStyle())
            end
        end
    end

    @testset "533" begin
        # semicolon should not be added prior to `extrap` since it's a function definition.
        s = "function linterp(x0::T, y0::T, x1::T, y1::T, x::T, extrap::Bool=false)::T where {T<:AbstractFloat} end"
        test_format(s, s, BlueStyle(); margin = 200)
        test_format(s, s, YASStyle(); margin = 200)

        s = "function linterp(x0::T, y0::T, x1::T, y1::T, x::T, extrap::Bool=false)::T end"
        test_format(s, s, BlueStyle(); margin = 200)
        test_format(s, s, YASStyle(); margin = 200)
    end

    @testset "541" begin
        str = """
        [10;]
        """
        test_format(str, str; align_matrix = true)
        str = """
        [0:0.2:50;]
        """
        test_format(str, str; align_matrix = true)
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
        test_format(str_, str; align_matrix = true)

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
        test_format(str_, str; align_matrix = true)
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
        test_format(str, str_, YASStyle(); indent=4, margin=92, join_lines_based_on_source = true,
            always_use_return = true,
            whitespace_in_kwargs = false)
    end

    @testset "562" begin
        # An inline `#= =#` comment in a call must keep a space from the following
        # argument (it must not be glued to it or moved to the end of the call).
        for s in (
            "f(x, #= y,=# z)",
            "g(op_data, #= ::OpData =# entry)",
        )
            for style in ALL_STYLES
                test_format(s, s, style)
            end
        end
    end

    @testset "568" begin
        s = """
        function (func(arg))
            body
        end
        """
        # no trailing comma since (arg) is semantically different from (arg,) !!!
        s_ = """
        function (func(
            arg,
        ))
            body
        end
        """
        test_format(s, s_; indent=4, margin=19)
    end

    @testset "571" begin
        s = """
        arraycopy_common(false#=fwd=#, LLVM.Builder(B), orig, origops[1], gutils)
        return nothing
        """
        s_ = """
        arraycopy_common(false #=fwd=#, LLVM.Builder(B), orig, origops[1], gutils)
        return nothing
        """
        test_format(s, s_)

        s1 = """
        foo(a, b, #=c=#)
        """
        s2 = """
        foo(
            a,
            b, #=c=#
        )
        """
        test_format(s1, s2; indent=4, margin=1)
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
        test_format(str, str_, SciMLStyle())

        str = raw"""
        begin @foo(a) end
        """
        str_ = raw"""
        begin
            @foo(a)
        end
        """
        test_format(str, str_, SciMLStyle())
    end

    @testset "609 comments being swallowed" begin
        s = "f(\n    q = 2  # this comment will not be removed\n)"
        test_format(s, s, SciMLStyle())
        s2 = "f(; q=2,  # this comment will not be removed\n  )"
        test_format(s, s2, YASStyle())
    end

    @testset "613" begin
        s = """
        x = ```
        my_cmd very_long command that really should be multi-line but isn't, and exceeds the character limit, will be indented forever by repeated calls to format
        ```
        """
        test_format(s, s)
    end

    @testset "618" begin
        s = """
        2 |> x -> 2x
        """
        s_ = """
        (x -> 2x)(2)
        """
        test_format(s, s_; indent=4, margin=92, pipe_to_function_call = true)
    end

    @testset "619" begin
        # Semicolons in vector literals must be preserved (they denote vcat, not hcat).
        # Previously SciMLStyle dropped semicolons when reformatting.
        eq_str = raw"eqs = [0 ~ -1x_f + (ModelingToolkitComponents.inputsf)(t, dt, x_f_input); 0 ~ -1dm_f1 + (ModelingToolkitComponents.inputsf)(t, dt, dm_f1_input); 0 ~ -1dm_f2 + (ModelingToolkitComponents.inputsf)(t, dt, dm_f2_input); 0 ~ -1csled₊F_brake + (ModelingToolkitComponents.inputsf)(t, csled₊dt, csled₊F_brake_input); 0 ~ -1 * csled₊sled₊k_sled * (-1csled₊sled₊a + csled₊sled₊u) + csled₊sled₊F_sled; 0 ~ -1 * csled₊sled₊k_car * (-1csled₊sled₊w + csled₊sled₊a) + csled₊sled₊F_car; 0 ~ -1csled₊sled₊F_car + csled₊sled₊m_car * csled₊sled₊ddw; 0 ~ -1 * (ifelse)(c4₊f₊vSA₊x > 0, (c4₊f₊vSA₊k1 * (abs)(-1c4₊piston₊v1₊p + c4₊accum_m₊v₊p) * (abs)(c4₊f₊vSA₊x / c4₊f₊vSA₊x_m) + c4₊f₊vSA₊k2 * (abs)(c4₊f₊vSA₊x / c4₊f₊vSA₊x_m) * (sqrt)((abs)(-1c4₊piston₊v1₊p + c4₊accum_m₊v₊p)) + c4₊f₊vSA₊k3 * (c4₊f₊vSA₊x / c4₊f₊vSA₊x_m) ^ 2 * (abs)(-1c4₊piston₊v1₊p + c4₊accum_m₊v₊p)) * (sign)(-1c4₊piston₊v1₊p + c4₊accum_m₊v₊p), 0) + c4₊f₊vSA₊HA₊dm; 0 ~ (-1c4₊accum_m₊v₊y + (ModelingToolkitComponents.delayf)(c4₊accum_m₊v₊y, t, c4₊accum_m₊v₊dt, c4₊accum_m₊v₊dt, c4₊accum_m₊v₊yo)) / c4₊accum_m₊v₊dt + c4₊accum_m₊v₊dy; 0 ~ (-1 * c4₊accum_m₊v₊area * c4₊accum_m₊v₊rho_0 * (c4₊accum_m₊v₊l_int + c4₊accum_m₊v₊y) * c4₊accum_m₊v₊dp) / c4₊accum_m₊v₊bulk + -1 * c4₊accum_m₊v₊area * c4₊accum_m₊v₊rho_0 * (1.0 + c4₊accum_m₊v₊p / c4₊accum_m₊v₊bulk) * c4₊accum_m₊v₊dy + c4₊accum_m₊v₊H₊dm; 0 ~ (-1c4₊piston₊v1₊y + (ModelingToolkitComponents.delayf)(c4₊piston₊v1₊y, t, c4₊piston₊v1₊dt, c4₊piston₊v1₊dt, c4₊piston₊v1₊yo)) / c4₊piston₊v1₊dt + c4₊piston₊ms₊dy; 0 ~ (-1c4₊piston₊v2₊y + (ModelingToolkitComponents.delayf)(c4₊piston₊v2₊y, t, c4₊piston₊v2₊dt, c4₊piston₊v2₊dt, c4₊piston₊v2₊yo)) / c4₊piston₊v2₊dt + -1c4₊piston₊ms₊dy; 0 ~ (-1c4₊piston₊ms₊y + (ModelingToolkitComponents.delayf)(c4₊piston₊ms₊y, t, c4₊piston₊ms₊dt, c4₊piston₊ms₊dt, c4₊piston₊ms₊yo)) / c4₊piston₊ms₊dt + c4₊piston₊ms₊dy; 0 ~ (ifelse)(c4₊piston₊ms₊y < c4₊piston₊ms₊ubnd, (ifelse)(c4₊piston₊ms₊y > c4₊piston₊ms₊lbnd, -1c4₊piston₊ms₊T₊f + c4₊piston₊ms₊m * c4₊piston₊ms₊ddy + -1 * c4₊piston₊ms₊g * c4₊piston₊ms₊m, -1c4₊piston₊ms₊T₊f + -1.0e9c4₊piston₊ms₊lbnd + c4₊piston₊ms₊m * c4₊piston₊ms₊ddy + 1.0e6c4₊piston₊ms₊dy + 1.0e9c4₊piston₊ms₊y + -1 * c4₊piston₊ms₊g * c4₊piston₊ms₊m), -1c4₊piston₊ms₊T₊f + -1.0e9c4₊piston₊ms₊ubnd + c4₊piston₊ms₊m * c4₊piston₊ms₊ddy + 1.0e6c4₊piston₊ms₊dy + 1.0e9c4₊piston₊ms₊y + -1 * c4₊piston₊ms₊g * c4₊piston₊ms₊m); 0 ~ (-1 * c4₊fp₊area * c4₊fp₊length * c4₊fp₊rho_0 * c4₊fp₊dp) / c4₊fp₊bulk + c4₊fp₊H₊dm]"
        output = """
        eqs = [0 ~ -1x_f + (ModelingToolkitComponents.inputsf)(t, dt, x_f_input);
               0 ~ -1dm_f1 + (ModelingToolkitComponents.inputsf)(t, dt, dm_f1_input);
               0 ~ -1dm_f2 + (ModelingToolkitComponents.inputsf)(t, dt, dm_f2_input);
               0 ~
               -1csled₊F_brake +
               (ModelingToolkitComponents.inputsf)(t, csled₊dt, csled₊F_brake_input);
               0 ~ -1 * csled₊sled₊k_sled * (-1csled₊sled₊a + csled₊sled₊u) + csled₊sled₊F_sled;
               0 ~ -1 * csled₊sled₊k_car * (-1csled₊sled₊w + csled₊sled₊a) + csled₊sled₊F_car;
               0 ~ -1csled₊sled₊F_car + csled₊sled₊m_car * csled₊sled₊ddw;
               0 ~
               -1 * (ifelse)(c4₊f₊vSA₊x > 0,
                   (c4₊f₊vSA₊k1 * (abs)(-1c4₊piston₊v1₊p + c4₊accum_m₊v₊p) *
                    (abs)(c4₊f₊vSA₊x / c4₊f₊vSA₊x_m) +
                    c4₊f₊vSA₊k2 * (abs)(c4₊f₊vSA₊x / c4₊f₊vSA₊x_m) *
                    (sqrt)((abs)(-1c4₊piston₊v1₊p + c4₊accum_m₊v₊p)) +
                    c4₊f₊vSA₊k3 * (c4₊f₊vSA₊x / c4₊f₊vSA₊x_m) ^ 2 *
                    (abs)(-1c4₊piston₊v1₊p + c4₊accum_m₊v₊p)) *
                   (sign)(-1c4₊piston₊v1₊p + c4₊accum_m₊v₊p),
                   0) + c4₊f₊vSA₊HA₊dm;
               0 ~
               (-1c4₊accum_m₊v₊y + (ModelingToolkitComponents.delayf)(
                   c4₊accum_m₊v₊y, t, c4₊accum_m₊v₊dt, c4₊accum_m₊v₊dt, c4₊accum_m₊v₊yo)) /
               c4₊accum_m₊v₊dt + c4₊accum_m₊v₊dy;
               0 ~
               (-1 * c4₊accum_m₊v₊area * c4₊accum_m₊v₊rho_0 *
                (c4₊accum_m₊v₊l_int + c4₊accum_m₊v₊y) * c4₊accum_m₊v₊dp) / c4₊accum_m₊v₊bulk +
               -1 * c4₊accum_m₊v₊area * c4₊accum_m₊v₊rho_0 *
               (1.0 + c4₊accum_m₊v₊p / c4₊accum_m₊v₊bulk) * c4₊accum_m₊v₊dy + c4₊accum_m₊v₊H₊dm;
               0 ~
               (-1c4₊piston₊v1₊y + (ModelingToolkitComponents.delayf)(
                   c4₊piston₊v1₊y, t, c4₊piston₊v1₊dt, c4₊piston₊v1₊dt, c4₊piston₊v1₊yo)) /
               c4₊piston₊v1₊dt + c4₊piston₊ms₊dy;
               0 ~
               (-1c4₊piston₊v2₊y + (ModelingToolkitComponents.delayf)(
                   c4₊piston₊v2₊y, t, c4₊piston₊v2₊dt, c4₊piston₊v2₊dt, c4₊piston₊v2₊yo)) /
               c4₊piston₊v2₊dt + -1c4₊piston₊ms₊dy;
               0 ~
               (-1c4₊piston₊ms₊y + (ModelingToolkitComponents.delayf)(
                   c4₊piston₊ms₊y, t, c4₊piston₊ms₊dt, c4₊piston₊ms₊dt, c4₊piston₊ms₊yo)) /
               c4₊piston₊ms₊dt + c4₊piston₊ms₊dy;
               0 ~ (ifelse)(c4₊piston₊ms₊y < c4₊piston₊ms₊ubnd,
                   (ifelse)(c4₊piston₊ms₊y > c4₊piston₊ms₊lbnd,
                       -1c4₊piston₊ms₊T₊f + c4₊piston₊ms₊m * c4₊piston₊ms₊ddy +
                       -1 * c4₊piston₊ms₊g * c4₊piston₊ms₊m,
                       -1c4₊piston₊ms₊T₊f + -1.0e9c4₊piston₊ms₊lbnd +
                       c4₊piston₊ms₊m * c4₊piston₊ms₊ddy + 1.0e6c4₊piston₊ms₊dy +
                       1.0e9c4₊piston₊ms₊y + -1 * c4₊piston₊ms₊g * c4₊piston₊ms₊m),
                   -1c4₊piston₊ms₊T₊f + -1.0e9c4₊piston₊ms₊ubnd +
                   c4₊piston₊ms₊m * c4₊piston₊ms₊ddy + 1.0e6c4₊piston₊ms₊dy + 1.0e9c4₊piston₊ms₊y +
                   -1 * c4₊piston₊ms₊g * c4₊piston₊ms₊m);
               0 ~
               (-1 * c4₊fp₊area * c4₊fp₊length * c4₊fp₊rho_0 * c4₊fp₊dp) / c4₊fp₊bulk + c4₊fp₊H₊dm]
        """ |> strip
        test_format(eq_str, output, SciMLStyle())
        @test Meta.parse(eq_str) == Meta.parse(output)
    end

    @testset "622" begin
        # Array indexing with colon should not produce invalid syntax when nested.
        # Previously, `to_eval[\n    performance_accept, :\n]` had a bare `:` after a
        # newline, which Julia interpreted as the quoting operator.
        s = "chainsamples[α_accept_indices[performance_accept], :] = to_eval[performance_accept, :]\n"
        s_ = """
        chainsamples[α_accept_indices[performance_accept], :] = to_eval[
            performance_accept, :,
        ]
        """
        test_format(s, s_, BlueStyle(); margin = 60)
    end

    @testset "624" begin
        s = """
        deploydocs(;
            repo="github.com/julia-vscode/CSTParser.jl",
        )
        """
        test_format(s, s, MinimalStyle())
    end

    @testset "630" begin
        s = raw"""
        rn = @reaction_network begin
            k/$V, A + B --> C
        end k"""
        test_format(s, s, SciMLStyle())
    end

    @testset "636" begin
        s = "a |> M.f"
        test_format(s, "M.f(a)"; indent=4, margin=92, pipe_to_function_call = true)

        # -> has a higher precedence than |>
        s = """
        coordsperm = coords .|> x -> x.I[[2, 1, 3]] |> CartesianIndex
        """
        s_ = """
        coordsperm = (x -> CartesianIndex(x.I[[2, 1, 3]])).(coords)
        """
        test_format(s, s_; indent=4, margin=92, pipe_to_function_call = true)

        # -> has a higher precedence than |>
        s = """
        coordsperm = coords .|> x -> x.I[[2, 1, 3]] .|> CartesianIndex
        """
        s_ = """
        coordsperm = (x -> CartesianIndex.(x.I[[2, 1, 3]])).(coords)
        """
        test_format(s, s_; indent=4, margin=92, pipe_to_function_call = true)

        s = """
        coordsperm = coords .|> (x -> x.I[[2, 1, 3]]) .|> CartesianIndex
        """
        s_ = """
        coordsperm = CartesianIndex.((x -> x.I[[2, 1, 3]]).(coords))
        """
        test_format(s, s_; indent=4, margin=92, pipe_to_function_call = true)

        s = """
        coordsperm = coords |> (x -> x.I[[2, 1, 3]]) |> CartesianIndex
        """
        s_ = """
        coordsperm = CartesianIndex((x -> x.I[[2, 1, 3]])(coords))
        """
        test_format(s, s_; indent=4, margin=92, pipe_to_function_call = true)
    end

    @testset "642" begin
        # Unary plus in macro call should not break the formatter.
        s = "@constraint(Lower(model), +x[1] + x[2] <= 2)\n"
        test_format(s, s)

        # Unary plus at the start of a chain of multiplications inside `sum()`.
        s_ = """
        sum(
                + _shutdown_margin(u, ng, d, s, t0, t, case, part)
                * _unit_flow_capacity(u, ng, d, s, t0, t)
                * _switch(
                    d; from_node=nonspin_units_started_up, to_node=nonspin_units_shut_down
                )[u, n, s, t_over]
                * overlap_duration(t_over, t)
                for (u, n, s, t_over) in _switch(
                    d; from_node=nonspin_units_started_up_indices, to_node=nonspin_units_shut_down_indices
                )(m; unit=u, stochastic_scenario=s, t=t_overlaps_t(m; t=t));
                init=0
            )
        """
        s = """
        sum(
            + _shutdown_margin(u, ng, d, s, t0, t, case, part) *
            _unit_flow_capacity(u, ng, d, s, t0, t) *
            _switch(d; from_node = nonspin_units_started_up, to_node = nonspin_units_shut_down)[
                u,
                n,
                s,
                t_over,
            ] *
            overlap_duration(t_over, t) for (u, n, s, t_over) in _switch(
                d;
                from_node = nonspin_units_started_up_indices,
                to_node = nonspin_units_shut_down_indices,
            )(
                m;
                unit = u,
                stochastic_scenario = s,
                t = t_overlaps_t(m; t = t),
            );
            init = 0,
        )
        """
        test_format(s_, s)
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
        test_format(s, s_; indent=4, margin=92, align_assignment = true)

        # no manual edit
        s = """
        @foo @noinline Base.@constprop :none aaaaaaaaaaaaa() = 0
        @foo @noinline Base.@constprop :none bbbbbbbbbbbbbbbbbbbbbbb() = 0
        @foo @foo @ccccccccccccccccccccccccccccccccccccccccccccccccc() = 0
        """
        test_format(s, s; indent=4, margin=92, align_assignment = true)
    end

    @testset "655" begin
        s = """
        [
          a;
        ]
        """
        test_format(s, s; indent=2, margin=92, join_lines_based_on_source = true)
        test_format(s, s; indent=2, margin=1)
        s = """
        [
          a
        ]
        """
        test_format(s, s; indent=2, margin=92, join_lines_based_on_source = true, trailing_comma = nothing)
        test_format(s, s; indent=2, margin=1, trailing_comma = nothing)
    end

    @testset "656" begin
        s = "[x for x in xs if x in 1:length(ys)]"
        test_format(s, s; indent=4, margin=92)
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
        test_format(s, s; format_docstrings = true)
    end

    @testset "669" begin
        # Macro call arguments like `xd(t)=xd_start` should not be rewritten to
        # `function xd(t) ... end` when `short_to_long_function_def = true`.
        s = """
        sts = @variables x(t) = x_start [description = "State of filter"] xd(t) = xd_start [
            description = "Derivative state of filter",
        ]
        """
        test_format(s, s; short_to_long_function_def = true)
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
        test_format(str_, str; indent=4, margin=1)
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
        test_format(s1, s2; indent=2, margin=5, short_to_long_function_def = true)
    end

    @testset "688" begin
        s = """
        vector_to_concatenate = [
            repeat([foo], foo_times);
            repeat([bar], bar_times)
        ]
        """ |> strip
        test_format(s, s; margin=30)
        test_format(s, s, MinimalStyle())
    end

    @testset "690" begin
        # Inline comments after trailing comma should not be deleted by SciMLStyle.
        s_ = """
        var_to_diff = DiffGraph(
            [2, 3, nothing, 5, 6, nothing], # primal_to_diff
            [nothing, 1, 2, nothing, 4, 5], # diff_to_primal
        )
        """
        s = """
        var_to_diff = DiffGraph(
            [2, 3, nothing, 5, 6, nothing], # primal_to_diff
            [nothing, 1, 2, nothing, 4, 5] # diff_to_primal
        )
        """
        test_format(s_, s, SciMLStyle())

        s_ = """
        if (# opening inline
            some_exceedingly_long_variable_name > some_other_fairly_long_variable_name # another inline
            # stand-alone
            || some_additional_long_variable_name > some_other_fairly_long_variable_name # closing inline
        )
            print("something")
        end
        """
        s = """
        if (# opening inline
            some_exceedingly_long_variable_name > some_other_fairly_long_variable_name # another inline
            # stand-alone
            ||
            some_additional_long_variable_name > some_other_fairly_long_variable_name # closing inline
            )
            print("something")
        end
        """
        test_format(s_, s, YASStyle(); margin=120)

        s60 = """
        if (# opening inline
            some_exceedingly_long_variable_name >
            some_other_fairly_long_variable_name # another inline
            # stand-alone
            ||
            some_additional_long_variable_name >
            some_other_fairly_long_variable_name # closing inline
            )
            print("something")
        end
        """
        test_format(s_, s60, YASStyle(); margin=60)
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
        test_format(s1, s2; indent=4, margin=10, short_to_long_function_def = true)
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
        test_format(s1, s2, BlueStyle(); indent=4, margin=92)
    end

    @testset "703" begin
        s = """
        mutable struct A
            const a :: Int
            bcd     :: String
        end
        """
        test_format(s, s; indent=4, margin=92, align_struct_field = true)
    end

    @testset "713" begin
        s1 = """
        [1. 1; 1 -1]
        """
        s2 = """
        [1.0 1; 1 -1]
        """
        test_format(s1, s2; indent=4, margin=92, align_matrix = true)
    end

    @testset "714" begin
        s1 = """
        A = [-2.. -1 3..4; 5..6 7..8]
        """
        s2 = """
        A = [-2 .. -1 3..4; 5..6 7..8]
        """
        test_format(s1, s2; indent=4, margin=92)
    end

    @testset "715" begin
        s = """
        map(1:10) do x
            # empty
        end
        """
        test_format(s, s; indent=4, margin=92, always_use_return = true)
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
        test_format(s, s; indent=4, margin=92)

        s = """
        begin
        #! format: noindent

        end
        """
        test_format(s, s; indent=4, margin=92)
    end

    @testset "736" begin
        # should not get spaces around `in`.
        s = "!in(x, y)"
        for style in ALL_STYLES
            test_format(s, s, style)
        end
    end

    @testset "743" begin
        s = """
        foo(ᶜa) = - ᶜa
        """
        test_format(s, s; indent=4, margin=92)
        test_format(s, s, SciMLStyle())
    end

    @testset "745" begin
        s = "[;;;]"
        test_format(s, s; indent=4, margin=92)
        test_format(s, s; indent=4, margin=1)
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
        test_format(str_, str; indent=4, margin=92, join_lines_based_on_source = true)
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
        test_format(str_, str, SciMLStyle())
    end

    @testset "769" begin
        s = raw"""
        @assert x isa Tuple \"msg\"
        """
        test_format(s, s, SciMLStyle())
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
        test_format(str, str)
    end

    @testset "779" begin
        s = "Int <: B where {B} && Int <: C where {C}"
        test_format(s, s)
    end

    @testset "781" begin
        # Previously failed with "hasn't reached fixpoint in 4 iterations".
        s = "f([a b\n            c d])"
        test_format(s, s, SciMLStyle(); align_matrix = true)
    end

    @testset "782" begin
        # `catch (e)` should be preserved as-is, not moved into the catch body.
        # Previously the formatter produced `catch\n    (e)\n    ...` which changes
        # semantics: `e` would no longer be bound to the exception.
        s = """
        try
            error("Whoops")
        catch (e)
            println("Found \$e")
        end
        """
        test_format(s, s)
    end

    @testset "795" begin
        s = "a[1 .+ 1 .+ 1]"
        for style in ALL_STYLES
            test_format(s, s, style)
        end
    end

    @testset "802" begin
        s = """
        mutable struct Foo
            const a
        end
        """
        test_format(s, s; indent=4, margin=92, align_struct_field = true)
    end

    @testset "810" begin
        s = """
        @f(a, b, c)
        """
        test_format(s, s, SciMLStyle())
    end

    @testset "815" begin
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
        test_format(
            s1, s2, BlueStyle();
            trailing_comma = true,
            join_lines_based_on_source = true,
        )

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
        test_format(
            s1, s2, BlueStyle(),
            trailing_comma = true,
            join_lines_based_on_source = true,
        )
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
        test_format(s, s2, SciMLStyle())
    end

    @testset "820" begin
        s = "this_func(::Tuple{<:(some_func())}) = nothing"
        test_format(s, s)
    end

    @testset "822" begin
        s = """
        ℯ #=
        =#
        """
        test_format(s, s)

        s = """
        begin
            π => im #=
            comment =#
        end
        """
        test_format(s, s)
    end

    @testset "833" begin
        # spaces around .+ were removed previously
        s = "x[n^2 .+ I]"
        for style in (DefaultStyle(), YASStyle(), MinimalStyle())
            test_format(s, s, style)
        end
        for style in (SciMLStyle(), BlueStyle())
            # spaces around binop in indexing expr
            s2 = "x[n ^ 2 .+ I]"
            test_format(s, s2, style)
        end
    end

    @testset "837" begin
        s = "Bool[;;]"
        for style in ALL_STYLES
            test_format(s, s)
        end
    end

    @testset "850" begin
        s = raw"""println("$x"[1:end-2])"""
        for style in ALL_STYLES
            # output depends on style but we can check AST is unchanged
            out = format_text(s, style)
            @test Meta.parse(s) == Meta.parse(out)
            # test idempotence
            @test format_text(out, style) == out
        end
    end

    @testset "860" begin
        # Integer literals and broadcasting inside `[]` should not cause a parse error.
        s = "a[x+1 .+ 1]"
        test_format(s, s)
        test_format(s, "a[x + 1 .+ 1]"; whitespace_ops_in_indices = true)
    end

    @testset "862" begin
        # Block comments should not be stripped entirely.
        # Previously `T <: Tuple #=...=# && ...` lost the first block comment.
        s = "T <: Tuple #=comment1=# && !(T isa Union) #=comment2=#\n"
        test_format(s, s)
    end

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
        test_format(str_, str, BlueStyle(); join_lines_based_on_source = true)
    end

    @testset "880" begin
        s1 = "constant_list[node_index.val:: UInt16]"
        s2 = "constant_list[node_index.val::UInt16]"
        test_format(s1, s2; indent=4, margin=100, whitespace_ops_in_indices = true)

        s1 = "constant_list[node_index.val+ UInt16]"
        s2 = "constant_list[node_index.val + UInt16]"
        test_format(s1, s2; indent=4, margin=100, whitespace_ops_in_indices = true)

        s = ".!purge"
        test_format(s, s; indent=4, margin=100)
    end

    @testset "885" begin
        # Unary minus with sub/superscript variables like `- ᶠb` should not cause a
        # LoadError. The space is needed for Julia to parse `-` as a unary operator
        # before a subscript/superscript identifier.
        for s in (
            "a = - ₐb",
            "a = - ᵃb",
            "a = - ᶠb",
            "a = - ᶜb",
        )
            test_format(s, s)
        end
    end

    @testset "887 short_circuit_to_if + prepend_return" begin
        s = raw"""
        function exampleFunction()
            LOGFILEHANDLE != "notset" && write(LOGFILEHANDLE, "examplestring")
        end"""
        expected = raw"""
        function exampleFunction()
            return LOGFILEHANDLE != "notset" && write(LOGFILEHANDLE, "examplestring")
        end"""
        for style in ALL_STYLES
            test_format(s, expected, style; short_circuit_to_if = true, always_use_return = true)
        end
    end

    @testset "890" begin
        # `public` keyword should not eat the following space.
        # Previously YASStyle turned `public Foo,Bar` into `publicFoo,Bar`.
        s = "public ExcludedRecordingV1, ExcludedRecordingV1SchemaVersion\n"
        s_ = "public ExcludedRecordingV1,ExcludedRecordingV1SchemaVersion\n"
        for style in ALL_STYLES
            test_format(s_, s, style)
        end
    end

    @testset "894" begin
        # MinimalStyle should preserve whitespace around `-`.
        s = """
        function sub(a, b)
            a - b
        end
        """
        test_format(s, s, MinimalStyle())
    end

    @testset "897 BlueStyle chained ternary to if idempotence" begin
        text = "push!(attributes, operandsegmentsizes([1, 1, 1, (lhs_scale==nothing) ? 0 : 1(rhs_scale==nothing) ? 0 : 1]))"
        for style in ALL_STYLES
            if style isa BlueStyle
                # BlueStyle converts the ternary into if/elseif/else so we manually test that
                blue_out = "push!(attributes, operandsegmentsizes([\n    1,\n    1,\n    1,\n    if (lhs_scale==nothing)\n        0\n    elseif 1(rhs_scale==nothing)\n        0\n    else\n        1\n    end,\n]))"
                test_format(text, blue_out, BlueStyle())
            else
                test_format(text, nothing, style)
            end
        end

        # minimised case too
        s = "foooooooo(foooooooo(a ? b : c ? d : e))"
        for style in ALL_STYLES
            test_format(s, nothing, style)
            test_format(s, nothing, style; margin=40)
        end

        # check that comments aren't lost
        s = "#=1=# a #=2=# ? #=3=# b #=4=# : #=5=# c #=6=# ? #=7=# d #=8=# : #=9=# e #=10=#"
        test_format(s, nothing, BlueStyle())
        out = format_text(s, BlueStyle())
        for i in 1:10
            @test occursin("#=$(i)=#", out)
        end
    end

    @testset "902" begin
        # `short_circuit_to_if` should not transform `&&` into `if` inside a closure
        # argument, because that changes the semantics of the code.
        s_ = """
        indices = findall(
            ss ->
                ss == 1 &&
                    ss == 2,
            my_vec)
        """
        s = "indices = findall(ss -> ss == 1 && ss == 2, my_vec)\n"
        test_format(s_, s; short_circuit_to_if = true)
    end

    @testset "904" begin
        # `foo(::Bool=false)` should not get extra parentheses like `foo((::Bool)=false)`.
        s_ = "foo(::Bool=false) = false\n"
        test_format(s_, s_, YASStyle())
        test_format(s_, s_, BlueStyle())
        test_format(s_, s_, MinimalStyle())
        s_ = "foo(::Bool = false) = false\n"
        test_format(s_, s_, DefaultStyle())
        test_format(s_, s_, SciMLStyle())
    end

    @testset "905" begin
        # The `∈`/`in` operator in a generator *body* must not be normalized; only the
        # iteration specifications (after `for`) are affected by `always_for_in`.
        for style in (DefaultStyle(), BlueStyle(), YASStyle())
            test_format(
                "all(v ∈ P for v in mylist)",
                "all(v ∈ P for v in mylist)",
                style;
                always_for_in = true,
            )
            # the iteration spec itself is still normalized
            test_format(
                "all(v ∈ P for v = mylist)",
                "all(v ∈ P for v in mylist)",
                style;
                always_for_in = true,
            )
        end
    end

    @testset "908 comment in do-block" begin
        s = "funct() do # comment\nend"
        test_format(s, s)
    end

    @testset "911" begin
        # `@testset` block should not prevent the formatter from nesting function
        # arguments that exceed the margin.
        s_ = """
        @testset begin
            DynamicPPL.assume(::Random.AbstractRNG, ::DynamicPPL.Sampler{MyEmptyAlg}, dist, vn, vi) = DynamicPPL.assume(
                    dist, vn, vi
                )
        end
        """
        s = """
        @testset begin
            DynamicPPL.assume(
                ::Random.AbstractRNG, ::DynamicPPL.Sampler{MyEmptyAlg}, dist, vn, vi
            ) = DynamicPPL.assume(dist, vn, vi)
        end
        """
        test_format(s_, s, BlueStyle())
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
        test_format(s, s; indent=4, margin=100)

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
        test_format(str_, s; indent=4, margin=100)
    end

    @testset "914" begin
        # SciMLStyle with `yas_style_nesting` should produce consistent indentation
        # regardless of argument length.
        s_ = """
        for some_long_variable in some_long_function(some_even_longer_variable,
                               some_longer_variable)
        end
        """
        s = """
        for some_long_variable in some_long_function(some_even_longer_variable,
                                                     some_longer_variable)
        end
        """
        test_format(s_, s, SciMLStyle(); yas_style_nesting = true)
    end

    @testset "916" begin
        # Generated docstrings with nested interpolation like `$($("@$f"))` should not
        # cause a parsing error.
        s = raw"""
        for f in [:A, :B]
            @eval begin
                export $f
                \"\"\"
                    Function $($("$f")) docstring

                # Example

                ```jldoctest
                julia> $($("@$f")) 1
                1
                ```
                \"\"\"
                macro $f(p)
                    p
                end
            end
        end
        """
        test_format(s, s)
    end

    @testset "917" begin
        s = "using Foo: ( .. )"
        sf = "using Foo: (..)"
        test_format(s, sf; indent=4, margin=100)
    end

    @testset "921" begin
        # These are floating point literals with hexadecimal significands. E.g. 0x1p1 is the
        # float with with 0x1 as the significant and 1 as the exponent.
        s = "0x1p1"
        test_format(s, s)
        s = "+0x1p1"
        test_format(s, s)
        s = "-0x1p1"
        test_format(s, s)
    end

    @testset "926" begin
        # Function calls with binary operators as arguments should preserve whitespace.
        # Previously `f(*, +, a, b)` was formatted as `f(*,+,a,b)`.
        test_format("f(*, +, a, b)", "f(*, +, a, b)")
        test_format("f(*, +, a, b, c)", "f(*, +, a, b, c)")
    end

    @testset "940 short_circuit_to_if in while cond" begin
        s = """
        function foo(i)
            cond2 = true
            while i < 42 && cond2
                i += 1
            end
            return i
        end"""
        for style in ALL_STYLES
            test_format(s, s, style; short_circuit_to_if = true)
        end
    end

    @testset "941 generator idempotence" begin
        kwargs = (indent=4, margin=120, always_for_in=true, for_in_replacement="∈", whitespace_typedefs=true, whitespace_ops_in_indices=true, remove_extra_newlines=true, whitespace_in_kwargs=false, annotate_untyped_fields_with_any=false, normalize_line_endings="unix")
        text = "idx = (\n    if refdim == 1\n        I\n    elseif refdim == 2\n        J\n    else\n        (:)\n    end for (vdim, refdim) ∈ T.parameters\n)"
        for style in ALL_STYLES
            test_format(text, nothing, style; ast=true, kwargs...)
        end
    end

    @testset "944 for-in scoping" begin
        test_format(
            "[x[i] = y[i] for i = 1:length(y)]",
            "[x[i] = y[i] for i in 1:length(y)]";
            always_for_in = true,
        )
        
        s = "any(x in 1:5 for x in xs)"
        test_format(s, s)
    end

    @testset "946" begin
        s = "function f()\n    #==Pairs Tuple or ValidationResult==#\n    #=\n    So far\n    =#\nend\n"
        for style in ALL_STYLES
            test_format(s, s, style)
        end

        s2 = "function g()\n    y #=c=#\nend"
        for style in (DefaultStyle(), SciMLStyle(), MinimalStyle())
            test_format(s2, s2, style)
        end
        # these have always_use_return=true so test separately
        s2_return = """
        function g()
            return y #=c=#
        end""" |> strip
        for style in (BlueStyle(), YASStyle())
            test_format(s2, s2_return, style)
        end
        test_format(s2, s2_return; always_use_return = true)
    end

    @testset "949 format:on after TopLevel FST end but before last line" begin
        for s in (
            "#! format: off\nfoo(   )\n#! format: on\n\n",
            "#! format: off\nfoo(   )\n#! format: on\n",
            "#! format: off\nfoo(   )\n#! format: on",
            "#! format: off\nfoo(   )\n#! format: on\n#hi",
            "#! format: off\nfoo(   )\n#! format: on\n#hi\n",
        )
            for style in ALL_STYLES
                test_format(s, s, style)
            end
        end
    end

    @testset "1025" begin
        # from julia@1.12.6 Compiler/src/typelimits.jl
        s = """
        if is_lattice_equal(𝕃, ai, bi) || is_lattice_equal(𝕃, ai, ft)
            tyi = ai
        elseif is_lattice_equal(𝕃, bi, ft)
            tyi = bi
        elseif (tyi′ = tmerge_field(𝕃, ai, bi); tyi′ !== nothing)
            tyi = tyi′
        else
            tni = _typename(widenconst(ai))
            if tni isa Const && tni === _typename(widenconst(bi))
                tyi = typeintersect(ft, (tni.val::Core.TypeName).wrapper)
            else
                tyi = ft
            end
        end
        """
        test_format(s, s)
    end

    @testset "1017 trailing commas after macros/global" begin
        # macro
        s_ = "f(a = u -> @. u0)"
        s = "f(\n    a = u ->\n        @. u0\n)"
        for trailing_comma in (true, false, nothing)
            test_format(s_, s_; trailing_comma = trailing_comma)
            test_format(s_, s; margin = 10, trailing_comma = trailing_comma)
            for style in (SciMLStyle(), BlueStyle(), YASStyle(), MinimalStyle())
                test_format(s_, nothing; margin=10, ast=true)
            end
        end

        # global
        s_ = raw"""
        let libccalllazyfoo = LazyLibrary(lclf_path; on_load_callback=() -> global lclf_loaded = true),
            libccalllazybar = LazyLibrary(lclb_path; dependencies=[libccalllazyfoo], on_load_callback=() -> global lclb_loaded = true)
            eval(:(const libccalllazyfoo = $libccalllazyfoo))
            eval(:(const libccalllazybar = $libccalllazybar))
        end"""
        s = raw"""
        let libccalllazyfoo =
                LazyLibrary(lclf_path; on_load_callback = () -> global lclf_loaded = true),
            libccalllazybar = LazyLibrary(
                lclb_path;
                dependencies = [libccalllazyfoo],
                on_load_callback = () -> global lclb_loaded = true
            )

            eval(:(const libccalllazyfoo = $libccalllazyfoo))
            eval(:(const libccalllazybar = $libccalllazybar))
        end"""
        for trailing_comma in (true, false, nothing)
            test_format(s_, s; trailing_comma = trailing_comma)
        end
    end

    @testset "1018 macro do-block" begin
        # A macro call using `do` with keyword-style args must be formatted like the
        # function-call form, not left partially unformatted with extra spaces and
        # unindented multiline `do` arguments.
        test_format(
            "y = @foo(a=1,  b=2)  do x,\ny\n    x + y\nend\n",
            "y = @foo(a=1, b=2) do x, y\n    return x + y\nend\n",
            BlueStyle(),
        )
        test_format(
            "expr_spec = @template_spec(parameters=(p1=10, p2=10, p3=1),  expressions=(f, g))  do x1,\nx2,\nclass\n\n    x1 * 2\nend\n",
            "expr_spec = @template_spec(\n    parameters=(p1=10, p2=10, p3=1), expressions=(f, g)\n) do x1, x2, class\n    return x1 * 2\nend\n",
            BlueStyle(),
        )
        # default-style macrocall + do-block keeps single spaces and indents the body
        test_format("@modify(x) do y\n    y\nend", "@modify(x) do y\n    y\nend")
        test_format(
            "Makie.@recipe(A, B) do scene\n    t\nend",
            "Makie.@recipe(A, B) do scene\n    t\nend",
        )
        # macroblocks without a closer are unaffected
        test_format("@testset \"x\" begin\n    a\nend", "@testset \"x\" begin\n    a\nend")
    end

    @testset "1046 YAS comments being swallowed" begin
        s = """
        if (# opening inline
            a # another inline
            # stand-alone
            &&
            c # closing inline
            )
            foo
        end
        """ |> strip
        test_format(s, s, YASStyle())

        s2 = """f(# hi\n  a)"""
        test_format(s2, s2, YASStyle())

        # test some hash-eq comments for good measure
        s = """
        f(#= hi =# aaa,
          bbb,
          ccc #= hi =#)
        """
        test_format(s, s, YASStyle())
    end

    @testset "1048 generator idempotence" begin
        s = """
        (
            let x = f() do
                    return body
                end
                x
            end for x in xs
        )"""
        for style in ALL_STYLES
            if style isa YASStyle
                # no boundary newlines inside parens.
                target = "(let x = f() do\n         return body\n     end\n     x\n end\n for x in xs)"
                test_format(s, target, style)
            else
                test_format(s, s, style)
            end
        end

        s = """
        ys = (
            if p1(x)
                f1(x)
            elseif p2(x)
                f2(x)
            else
                f3(x)
            end for x in xs
        )"""
        for style in ALL_STYLES
            if style isa YASStyle
                target = """
                ys = (if p1(x)
                          f1(x)
                      elseif p2(x)
                          f2(x)
                      else
                          f3(x)
                      end
                      for x in xs)"""
                test_format(s, target, style)
            else
                test_format(s, s, style)
            end
        end
    end

    @testset "1062 docstring indent on rhs of short function def" begin
        for str in (
            "test_f() = \"\"\"\nxxxxx\n\"\"\"",
            "test_f = \"\"\"\nxxxxx\n\"\"\"",
        )
            for style in ALL_STYLES
                test_format(str, str)
                test_format(str, str; margin=4)
            end
        end
    end

    @testset "1064 space before hasheq-comment" begin
        s = "combine(x, 3 #= this is the magic number =#)"
        for style in ALL_STYLES
            test_format(s, s, style)
        end
    end

    @testset "1070 idempotent hasheq-comment in parameter list" begin
        # A `#= =#` comment on its own line in a nested parameter list must not gain a
        # spurious blank line on reformat. The signature is long enough to stay nested.
        s = """
        function f(
            obj;
            #=c=#
            keyword_argument_one::SomeLongTypeName,
            keyword_argument_two::AnotherLongType,
            keyword_argument_three::OneMoreType,
        )
            return obj
        end
        """
        test_format(s, s)
    end

    @testset "1072 exporting colon" begin
        for keyword in ("export", "public")
            s_ = "$(keyword) +, :, -"
            for style in ALL_STYLES
                test_format(s_, s_, style; margin=length(s_))
            end
            for style in (DefaultStyle(), BlueStyle(), MinimalStyle())
                s = "$(keyword) +,\n    :,\n    -"
                test_format(s_, s, style; margin=5)
            end
            for style in (SciMLStyle(), YASStyle())
                s = "$(keyword) +,\n       :,\n       -"
                test_format(s_, s, style; margin=5)
            end
        end
    end

    @testset "1076 avoid un-nesting chain" begin
        s_ = """
        if curs_row >= 0 && cur_row + 1 >= rows &&             # when too many lines,
                            cur_row - curs_row + 1 >= rows ÷ 2 # center the cursor
            lastline = true
        end"""
        s = """
        if curs_row >= 0 &&
           cur_row + 1 >= rows &&             # when too many lines,
           cur_row - curs_row + 1 >= rows ÷ 2 # center the cursor
            lastline = true
        end"""
        test_format(s_, s)

        sblue = """
        if curs_row >= 0 &&
            cur_row + 1 >= rows &&             # when too many lines,
            cur_row - curs_row + 1 >= rows ÷ 2 # center the cursor
            lastline = true
        end"""
        test_format(s_, sblue, BlueStyle())

        syas = """
        if curs_row >= 0 && cur_row + 1 >= rows &&             # when too many lines,
           cur_row - curs_row + 1 >= rows ÷ 2 # center the cursor
            lastline = true
        end"""
        for style in (YASStyle(), SciMLStyle(), MinimalStyle())
            test_format(s_, syas, style)
        end
    end

    @testset "1078 <: and >: as function calls" begin
        for s in (
            "<:(A, B)",
            ">:(A, B)",
            "f(<:(A, B))",
            "f(>:(A, B))",
            "@m <:(A, B)",
            "@m >:(A, B)",
        )
            for style in ALL_STYLES
                test_format(s, s, style)
            end
        end
    end

    @testset "1079 operator calls with (args...)" begin
        for s in (
            "<:(args...)",
            ">:(args...)",
            "+(args...)",
            "f(<:(args...))",
            "f(>:(args...))",
            "f(+(args...))",
            "@m <:(args...)",
            "@m >:(args...)",
            "@m +(args...)",
        )
            for style in ALL_STYLES
                test_format(s, s, style)
            end
        end
    end

    @testset "1088 comment after do" begin
        for comment_and_do_arg in (
            "# comment",
            "x # comment",
            "(x, y) # comment",
            "#= comment =# x",
        )
            for maybe_macro in ("@test ", "")
                s = """
                $(maybe_macro)f() do $(comment_and_do_arg)
                    return g
                end"""
                for style in ALL_STYLES
                    test_format(s, s, style)
                end
            end
        end
    end

    @testset "1105 typed comprehension idempotence" begin
        s = """
        function f()
            initial_incoming_vals = Pair{Any, Any}[
                if 0 in defuses[x].defs
                    Pair{Any, Any}(Argument(x), true)
                elseif !defuses[x].any_newvar
                    Pair{Any, Any}(UNDEF_TOKEN, false)
                else
                    Pair{Any, Any}(SSAValue(-2), false)
                end for x in 1:length(ci.slotflags)
            ]
        end"""
        target = """
        function f()
            initial_incoming_vals = Pair{Any,Any}[
                if 0 in defuses[x].defs
                    Pair{Any,Any}(Argument(x), true)
                elseif !defuses[x].any_newvar
                    Pair{Any,Any}(UNDEF_TOKEN, false)
                else
                    Pair{Any,Any}(SSAValue(-2), false)
                end for x = 1:length(ci.slotflags)
            ]
        end"""
        for style in ALL_STYLES
            if style isa DefaultStyle
                test_format(s, target, style)
            else
                test_format(s, nothing, style)
            end
        end
    end

    @testset "1107 surround_whereop_typeparameters idempotence" begin
        s = "sig = Tuple{T, Val{T}} where T<:(Val{T} where T<:(Val{T} where T<:(Val{T} where T<:(Val{T} where T<:Val))))"
        for style in ALL_STYLES
            test_format(s, nothing, style; ast=true, margin=88)
            test_format(s, nothing, style; ast=true, surround_whereop_typeparameters = true, margin=88)
        end
    end

    @testset "1108 always_for_in idempotence" begin
        # The bug was that without the `in` -> `=`, it's over margin, so lines were broken.
        # But after converting to `=` it's within margin, so the formatter decided to join
        # it back, leading to idempotence failure.
        s_ = """
        function f()
            d = Dict([randstring(8) => [RainbowString(randstring(8)) for i in 1:10] for j in 1:5]...)
        end"""
        s = """
        function f()
            d = Dict([randstring(8) => [RainbowString(randstring(8)) for i = 1:10] for j = 1:5]...)
        end"""
        test_format(s_, s)
        # Check that other style decisions don't mess with it
        for style in ALL_STYLES
            test_format(s_, s, style; margin=92, always_use_return=false, always_for_in=true, for_in_replacement="=")
        end
    end

    @testset "1109 multiline string idempotence" begin
        # All of these were idempotence bugs with JuliaLang/julia@v1.12.6.

        # from test/intrinsics.jl
        s1 = """
        @testset "issue #54548" begin
            @inline passthrough(ptr::Core.LLVMPtr{T,A}) where {T,A} = Base.llvmcall((
                \"""
        define ptr addrspace(1) @entry(ptr addrspace(1) %0) #0 {
        entry:
            ret ptr addrspace(1) %0
        }

        attributes #0 = { alwaysinline }\""",
                "entry",
            ), Core.LLVMPtr{T,A}, Tuple{Core.LLVMPtr{T,A}}, ptr)
            f(gws) = passthrough(Core.bitcast(Core.LLVMPtr{UInt32,1}, gws))
            f(C_NULL)
        end
        """

        # from test/show.jl
        s2 = raw"""
        eval(Meta._parse_string(
            \"""function my_fun28173(x)
            y = if x == 1
                    "HI"
                elseif x == 2
                    r = 1
                    s = try
                        r = 2
                        Base.inferencebarrier(false) && error()
                        "BYE"
                    catch
                        r = 3
                        "CAUGHT!"
                    end
                    "\$r\$s"
                else
                    "three"
                end
            return y
        end\""",
            "a"^80,
            1,
            1,
            :statement,
        )[1]) # use parse to control the line numbers
        """

        # from test/syntax.jl
        s3 = """
        @test isempty(Test.collect_test_logs() do
            include_string(
                @__MODULE__,
                \"""
        function foo37126()
            f(lhs::Integer, rhs::Integer) = nothing
            f(lhs::Integer, rhs::AbstractVector{<:Integer}) = nothing
            return f
        end
        struct Bar37126{T<:Real, P<:Real} end
        \""",
            )
        end[1])
        """

        for s in (s1, s2, s3)
            for style in ALL_STYLES
                test_format(s, nothing, style; v2_stable_multiline_strings=true)
            end
        end
    end

    @testset "1114 parenthesised caller in function def" begin
        for where in ("", " where T", " where {S,T}", " where S where T")
            s = """
            function (foo::Foo)(a, b)$(where)
               foo
            end
            """
            for style in ALL_STYLES
                test_format(s, nothing, style; ast=true, always_use_return=false)
                test_format(s, nothing, style; ast=true, always_use_return=false, margin=10)
            end
        end

        s = """
        @inline function (boundary_condition::BoundaryConditionNavierStokesWall{<:NoSlip,
                                                                                <:Adiabatic})(flux_inner,
                                                                                              u_inner,
                                                                                              orientation::Integer,
                                                                                              direction,
                                                                                              x,
                                                                                              t,
                                                                                              operator_type::Gradient,
                                                                                              equations::CompressibleNavierStokesDiffusion1D{GradientVariablesPrimitive})
            v1 = boundary_condition.boundary_condition_velocity.boundary_value_function(x, t,
                                                                                        equations)
            return SVector(u_inner[1], v1, u_inner[3])
        end"""
        output = """
        @inline function (boundary_condition::BoundaryConditionNavierStokesWall{
            <:NoSlip,
            <:Adiabatic,
        })(
            flux_inner,
            u_inner,
            orientation::Integer,
            direction,
            x,
            t,
            operator_type::Gradient,
            equations::CompressibleNavierStokesDiffusion1D{GradientVariablesPrimitive},
        )
            v1 = boundary_condition.boundary_condition_velocity.boundary_value_function(
                x,
                t,
                equations,
            )
            return SVector(u_inner[1], v1, u_inner[3])
        end"""
        test_format(s, output; ast=true)

        s = raw"""
        function (f::AbsAffineSchemeMor{<:AbsAffineScheme{S},<:AbsAffineScheme{S},<:Any,<:Any,Nothing})(P::AbsAffineRationalPoint) where {S}
          # The Nothing type parameter assures that the base morphism is trivial.
          @req domain(f) == codomain(P) "$(P) not in domain"
          @req base_ring(domain(f)) == base_ring(codomain(f)) "schemes must be defined over the same base ring. Try to map the point as an ideal instead"
          x = coordinates(codomain(f))
          g = pullback(f)
          p = coordinates(P)
          imgs = [evaluate(lift(g(y)),p) for y in x]
          return codomain(f)(imgs; check=false)
        end"""
        out = raw"""
        function (f::AbsAffineSchemeMor{
            <:AbsAffineScheme{S},
            <:AbsAffineScheme{S},
            <:Any,
            <:Any,
            Nothing,
        })(
            P::AbsAffineRationalPoint,
        ) where {S}
            # The Nothing type parameter assures that the base morphism is trivial.
            @req domain(f) == codomain(P) "$(P) not in domain"
            @req base_ring(domain(f)) == base_ring(codomain(f)) "schemes must be defined over the same base ring. Try to map the point as an ideal instead"
            x = coordinates(codomain(f))
            g = pullback(f)
            p = coordinates(P)
            imgs = [evaluate(lift(g(y)), p) for y in x]
            return codomain(f)(imgs; check = false)
        end"""
        test_format(s, out; ast=true)

        # Check that parenthesised callers outside of function definitions aren't affected.
        s = "(loooooong)(1, 2, 3)"
        out = "(\n    loooooong\n)(\n    1,\n    2,\n    3,\n)"
        test_format(s, out; ast=true, margin=10)
        s = """
        (function()
            foo
        end)()"""
        out = """
        (
            function ()
                foo
            end
        )()"""
        test_format(s, out; ast=true, margin=10)
    end

    @testset "1121 standalone circuit inconsistency" begin
        for prefix in (
            "",
            "x = ",
            "x + ",
            "return ",
        )
            s = "$(prefix)f(a, mmmmm || nnnnn, c)"
            out = "$(prefix)f(\n    a,\n    mmmmm ||\n        nnnnn,\n    c,\n)"
            test_format(s, out; ast=true, margin=10)
        end

        # and the original trigger
        s = """
        function f()
            EnzymeInterpreter(cache_or_token, mt, world, mode == API.DEM_ForwardMode, mode == API.DEM_ReverseModeCombined || mode == API.DEM_ReverseModePrimal || mode == API.DEM_ReverseModeGradient, inactive_rules, broadcast_rewrite, within_autodiff_rewrite, handler)
        end"""
        out = """
        function f()
            return EnzymeInterpreter(
                cache_or_token,
                mt,
                world,
                mode == API.DEM_ForwardMode,
                mode == API.DEM_ReverseModeCombined ||
                    mode == API.DEM_ReverseModePrimal ||
                    mode == API.DEM_ReverseModeGradient,
                inactive_rules,
                broadcast_rewrite,
                within_autodiff_rewrite,
                handler,
            )
        end"""
        test_format(s, out, BlueStyle())
    end

    @testset "1123 short_circuit_to_if inside calls" begin
        # short_circuit_to_if should not expand `&&`/`||` inside function calls,
        # tuples, etc. where the value is used.
        for s in (
            "f(a && b)",
            "return f(a && b)",
            "x = f(a && b)",
            "(a && b, c)",
            "[a && b]",
            "@macro a && b",
            "(a && b) + c", # even when parenthesised
        )
            test_format(s, s; short_circuit_to_if=true)
        end

        # But standalone `a && b` in a block should still expand -- as long as it's not at
        # the end of the block (in which case the block evaluates to it).
        for (block_begin, block_end) in (
            ("function g()", "end"),
            ("if foo", "end"),
            ("for i = 1:10", "end"),
            ("while true", "end"),
            ("let x = 1", "end"),
            ("begin", "end"),
        )
            test_format(
                "$block_begin\n    a && b\n    2\n$block_end",
                "$block_begin\n    if a\n        b\n    end\n    2\n$block_end";
                short_circuit_to_if=true,
            )

            # Check that it doesn't expand at the end of the block.
            test_format(
                "$block_begin\n    a && b\n$block_end",
                "$block_begin\n    a && b\n$block_end",
                short_circuit_to_if=true,
            )
        end

        # Should expand at the top level.
        test_format("a && b", "if a\n    b\nend"; short_circuit_to_if=true)
    end

    @testset "1124 do not change syntax in Exprs" begin
        @testset "short to long funcdef" begin
            for s in (
                ":(f(x) = 1)",
                "@macro f(x) = 1",
                "@macro(f(x) = 1)",
            )
                for style in ALL_STYLES
                    test_format(s, s, style; short_to_long_function_def=true, force_long_function_def=true)
                end
            end
        end
    end

    @testset "1125 always_use_return idempotence" begin
        s = """
        function f()
            if visible
                any_visible = any(ALL_SCREENS) do s
                    s !== screen && s.owns_glscreen &&
                        GLAbstraction.context_alive(s.glscreen) &&
                        GLFW.GetWindowAttrib(s.glscreen, GLFW.VISIBLE) != 0
                end
                any_visible || macos_set_dock_visible(false)
            end
        end"""
        output = """
        function f()
            if visible
                any_visible = any(ALL_SCREENS) do s
                    return s !== screen &&
                           s.owns_glscreen &&
                           GLAbstraction.context_alive(s.glscreen) &&
                           GLFW.GetWindowAttrib(s.glscreen, GLFW.VISIBLE) != 0
                end
                any_visible || macos_set_dock_visible(false)
            end
        end"""
        test_format(s, output; always_use_return=true)
        test_format(s, output, BlueStyle())
    end

    @testset "1132 BlueStyle chained ternary expansion idempotence" begin
        s = "f() = a ? b : c ? d : e"
        output = """
        f() =
            if a
                b
            elseif c
                d
            else
                e
            end"""
        test_format(s, output, BlueStyle())
    end

    @testset "1142 chained ternary expansion comments in condition" begin
        # the elseif condition needs to be parenthesised, otherwise the
        # comment ruins the day
        for expr in ("c && d", "c + d")
            s = """
            begin
                a ? b :
                # comment
                $(expr) ? e : f
            end"""
            output = """
            begin
                if a
                    b
                elseif (
                    # comment
                    $(expr)
                )
                    e
                else
                    f
                end
            end"""
            test_format(s, output, BlueStyle())
        end

        # if expr is c(d), it gets shifted above. Just don't ask. It's a JuliaSyntax thing.
        s = """
        begin
            a ? b :
            # comment
            c(d) ? e : f
        end"""
        output = """
        begin
            if a
                b
                # comment
            elseif c(d)
                e
            else
                f
            end
        end"""
        test_format(s, output, BlueStyle())
    end

    @testset "1144 ops as keyword names" begin
        for s in (
            "Compiler.sort!(v; by = x -> -x, < = >) === v == [1,2,3]",
            "sort(v; by, lt) == Compiler.sort!(copy(v); by, < = lt)",
        )
            for style in ALL_STYLES
                test_format(s, nothing, style; ast=true)
            end
        end

        # Don't need to parenthesise if there are comments to help us separate
        s = "f(x; < #= comment =# = >)"
        out = "f(x; < #= comment =# =(>))"
        test_format(s, out, BlueStyle())
        for style in (DefaultStyle(), SciMLStyle(), YASStyle(), MinimalStyle())
            test_format(s, nothing, style; ast=true)
        end

        s = "f(x; < = #= comment =# >)"
        out = "f(x; (<)= #= comment =# >)"
        test_format(s, out, BlueStyle())
        for style in (DefaultStyle(), SciMLStyle(), YASStyle(), MinimalStyle())
            test_format(s, nothing, style; ast=true)
        end
    end

    @testset "1147 pipe_to_function_call with assignment" begin
        for parens in (
            "(a = b)",
            "(#= 1 =# a #= 2 =# = #= 3 =# b #= 4 =#)",
        )
            s = "$(parens) |> f"
            expected_out = "f($(parens))"
            for style in ALL_STYLES
                test_format(s, expected_out, style; pipe_to_function_call=true)
            end
        end

        s = """(
            a = b # why
        ) |> f"""
        expected_out = """f((
            a = b # why
        ))"""
        for style in (DefaultStyle(), BlueStyle())
            test_format(s, expected_out, style; pipe_to_function_call=true)
        end
    end
end

end
