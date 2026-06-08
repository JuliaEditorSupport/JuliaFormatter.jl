module IssuesTests

using JuliaFormatter
using JuliaFormatter: DefaultStyle, YASStyle, BlueStyle, MinimalStyle, SciMLStyle, Options, format_text
using JuliaFormatter.Internal: test_format
using JuliaSyntax
using Test

ALL_STYLES = (DefaultStyle(), YASStyle(), BlueStyle(), MinimalStyle(), SciMLStyle())

function run_nest(text::String; opts = Options(), style = DefaultStyle())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; version=JuliaFormatter.SUPPORTED_SYNTAX_VERSION)
    t = JuliaFormatter.pretty(style, g, s)
    JuliaFormatter.nest!(style, t, s)
    t, s
end

function run_format(text::String; style = DefaultStyle(), opts = Options())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, opts)
    g = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text; version=JuliaFormatter.SUPPORTED_SYNTAX_VERSION)
    JuliaFormatter.format_text(g, style, s)
    s
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
          let
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

    @testset "396 (import as)" begin
        str = """import Base.threads as th"""
        test_format(str, str)
        test_format(str, str; margin = 1)
        test_format(str, str; margin = 1, import_to_using = true)
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
                using $sym: $sym
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
        st = run_format(str_; opts = Options(; pipe_to_function_call = true))
        @test st.line_offset == length(str)
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
        test_format(s, s_; indent=4, margin=19)
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
        test_format(s, s_)

        s1 = """
        foo(a, b, #=c=#)
        """
        s2 = """
        foo(
            a,
            b,#=c=#
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

    @testset "664" begin
        # `import ..x` should not be converted to `using ..x: x` with `import_to_using`,
        # because `using ..x: x` is invalid when `x` is not a module.
        s = "module M\nimport ..x\ny = x\nend\n"
        test_format(s, s; import_to_using = true)
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
        s_ = "T <: Tuple #=comment1=# && !(T isa Union) #=comment2=#\n"
        s = "T <: Tuple#=comment1=# && !(T isa Union)#=comment2=#\n"
        test_format(s_, s)
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
end

end
