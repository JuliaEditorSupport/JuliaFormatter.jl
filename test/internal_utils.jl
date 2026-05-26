@testset "Internal utilities" begin
    # Build the same parser/document/state objects the formatter utilities consume.
    function parsed_node(text)
        doc = JuliaFormatter.Document(text)
        state = JuliaFormatter.State(doc, Options())
        root = JuliaSyntax.parseall(JuliaSyntax.GreenNode, text)
        nodes = filter(n -> !JuliaSyntax.is_whitespace(n), JuliaSyntax.children(root))
        return doc, state, only(nodes)
    end

    @testset "source operator recovery" begin
        # JuliaSyntax v1 can represent source operators as Identifier leaves; recover
        # the actual operator kind from the original source text.
        _, state, node = parsed_node("a + b")
        op_indices = JuliaFormatter.source_operator_indices(node)
        op = JuliaSyntax.children(node)[only(op_indices)]

        @test JuliaFormatter.source_operator_kind(state, op, 3) === JuliaSyntax.Kind("+")
        @test JuliaFormatter.source_op_kind(state, node) === JuliaSyntax.Kind("+")

        _, state, node = parsed_node("x .+ y")
        @test JuliaFormatter.source_operator_indices(node) == [3, 4]
        @test JuliaFormatter.source_op_kind(state, node) === JuliaSyntax.Kind("+")

        # Prefix operator calls should be treated as unary only when the recovered
        # source operator is valid in unary position.
        _, state, node = parsed_node("+(y)")
        @test JuliaFormatter.source_prefix_operator_index(node, state) == 1
        @test JuliaSyntax.is_prefix_op_call(node)

        _, state, node = parsed_node(">=(y)")
        @test JuliaFormatter.source_prefix_operator_index(node, state) == 1
        @test !JuliaSyntax.is_prefix_op_call(node)
    end

    @testset "short-form function utilities" begin
        # Short-form definitions parse as function nodes but need binary-op handling
        # so the equals sign keeps assignment-like spacing and metadata.
        _, state, node = parsed_node("f(x) = x")

        @test JuliaFormatter.is_short_function_def(node)
        @test JuliaFormatter.source_operator_indices(node) == [3]
        @test JuliaFormatter.source_op_kind(state, node) === JuliaSyntax.Kind("=")

        # Compound assignments split the source operator across multiple child nodes.
        _, state, node = parsed_node("x += 1")
        @test JuliaFormatter.source_operator_indices(node) == [3, 4]
        @test JuliaFormatter.source_op_kind(state, node) === JuliaSyntax.Kind("op=")

        # Long-form definitions must stay on the dedicated function-definition path.
        _, _, node = parsed_node("""
        function f(x)
            x
        end
        """)
        @test !JuliaFormatter.is_short_function_def(node)
    end

    @testset "assignment predicate" begin
        # Use JuliaSyntax's syntactic-assignment category instead of rebuilding
        # assignment membership from precedence ranges and child checks.
        _, _, node = parsed_node("x = 1")
        @test JuliaFormatter.is_assignment(node)

        _, _, node = parsed_node("x += 1")
        @test JuliaFormatter.is_assignment(node)

        _, _, node = parsed_node("x in xs")
        @test !JuliaFormatter.is_assignment(node)
    end

    @testset "do-block and iteration utilities" begin
        # Calls with a do block are split so the call arguments and do body can be
        # formatted by their dedicated paths.
        _, _, node = parsed_node("""
        map(xs) do x
            x + 1
        end
        """)
        childs = JuliaSyntax.children(node)
        do_idx = JuliaFormatter.do_block_index(childs)

        @test do_idx == 5
        @test JuliaFormatter.has_do_block_call(node) == do_idx
        @test length(JuliaFormatter.call_args(childs[1:(do_idx-1)])) == 1

        # Single-iterator loops can inspect the RHS iterable directly.
        _, _, node = parsed_node("""
        for x in [1, 2]
        end
        """)
        iter = JuliaSyntax.children(node)[2]
        @test !JuliaFormatter.iteration_has_comma(iter)
        @test JuliaSyntax.kind(JuliaFormatter.iteration_rhs(iter)) ===
              JuliaSyntax.Kind("vect")

        # Cartesian iterations need to detect the comma and use the final iteration
        # expression as the effective RHS.
        _, _, node = parsed_node("""
        for x in [1, 2], y in 3:4
        end
        """)
        iter = JuliaSyntax.children(node)[2]
        @test JuliaFormatter.iteration_has_comma(iter)
        @test JuliaSyntax.kind(JuliaFormatter.iteration_rhs(iter)) ===
              JuliaSyntax.Kind("call")
    end

    @testset "display-width source offsets" begin
        # Alignment uses display columns, not code-unit offsets; the combining mark
        # in s\u0304_b should not add a visible column.
        text = "s\u0304_b      = 1\n"
        doc = JuliaFormatter.Document(text)
        eq_offset = findfirst(isequal('='), text)

        @test eq_offset > 10
        @test JuliaFormatter.source_display_line_offset(doc, 1, eq_offset) == 10
        @test JuliaFormatter.node_align_length(
            JuliaFormatter.FST(JuliaFormatter.IDENTIFIER, 1, 1, 1, "s\u0304_b"),
        ) == 3
    end

    @testset "module flags" begin
        # JuliaSyntax v1 stores baremodule as a module node with a flag.
        _, _, node = parsed_node("""
        baremodule A
        end
        """)

        @test JuliaSyntax.kind(node) === JuliaSyntax.Kind("module")
        @test JuliaSyntax.has_flags(node, JuliaSyntax.BARE_MODULE_FLAG)
        @test !JuliaFormatter.is_short_function_def(node)
        @test JuliaFormatter.format_text("baremodule A\nend") == "baremodule A end"
    end
end
