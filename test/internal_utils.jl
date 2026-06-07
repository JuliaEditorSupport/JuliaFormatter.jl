module InternalUtilsTests

import Test: @testset, @test
import JuliaFormatter as JF
import JuliaSyntax as JS

@testset "Internal utilities" begin
    # Build the same parser/document/state objects the formatter utilities consume.
    function parsed_node(text)
        doc = JF.Document(text)
        state = JF.State(doc, JF.Options())
        root = JS.parseall(JS.GreenNode, text; version=JF.SUPPORTED_SYNTAX_VERSION)
        nodes = filter(n -> !JS.is_whitespace(n), JS.children(root))
        return doc, state, only(nodes)
    end

    @testset "source operator recovery" begin
        # JS v1 can represent source operators as Identifier leaves; recover
        # the actual operator kind from the original source text.
        _, state, node = parsed_node("a + b")
        op_indices = JF.source_operator_indices(node)
        op = JS.children(node)[only(op_indices)]

        @test JF.source_op_kind_from_offset(state, op, 3) === JS.Kind("+")
        @test JF.source_op_kind(state, node) === JS.Kind("+")

        _, state, node = parsed_node("x .+ y")
        @test JF.source_operator_indices(node) == [3, 4]
        @test JF.source_op_kind(state, node) === JS.Kind("+")

        _, state, node = parsed_node("x < y < z")
        @test JF.source_operator_indices(node) == [3, 7]
        @test JF.source_op_kind(state, node) === JS.Kind("<")
    end

    @testset "source_unary_operator_index prefix $text" for text in (
        "+(y)",
        "-(y)",
        ">=(y)",
        "+y",
        "-y",
        "!y",
    )
        _, state, node = parsed_node(text)
        @test JF.source_unary_operator_index(true, node, state) == 1
    end

    @testset "source_unary_operator_index postfix $text" for text in (
        "y...",
        "y'",
        "x'ᵀ",
        "(y)...",
        "[1, 2]'",
    )
        _, state, node = parsed_node(text)
        @test JF.source_unary_operator_index(false, node, state) ==
              length(JS.children(node))
    end

    @testset "short-form function utilities" begin
        # Short-form definitions parse as function nodes but need binary-op handling
        # so the equals sign keeps assignment-like spacing and metadata.
        _, state, node = parsed_node("f(x) = x")

        @test JF.is_short_function_def(node)
        @test JF.source_operator_indices(node) == [3]
        @test JF.source_op_kind(state, node) === JS.Kind("=")

        # Compound assignments split the source operator across multiple child nodes.
        _, state, node = parsed_node("x += 1")
        @test JF.source_operator_indices(node) == [3, 4]
        @test JF.source_op_kind(state, node) === JS.Kind("op=")

        _, state, node = parsed_node("x .+= 1")
        @test JF.source_operator_indices(node) == [3, 4, 5]
        @test JF.source_op_kind(state, node) === JS.Kind("op=")

        # Long-form definitions must stay on the dedicated function-definition path.
        _, _, node = parsed_node("""
        function f(x)
            x
        end
        """)
        @test !JF.is_short_function_def(node)
    end

    @testset "assignment predicate" begin
        # Use JS's syntactic-assignment category instead of rebuilding
        # assignment membership from precedence ranges and child checks.
        _, _, node = parsed_node("x = 1")
        @test JF.is_assignment(node)

        _, _, node = parsed_node("x += 1")
        @test JF.is_assignment(node)

        _, _, node = parsed_node("x in xs")
        @test !JF.is_assignment(node)
    end

    @testset "do-block and iteration utilities" begin
        # Calls with a do block are split so the call arguments and do body can be
        # formatted by their dedicated paths.
        _, _, node = parsed_node("""
        map(xs) do x
            x + 1
        end
        """)
        childs = JS.children(node)
        do_idx = JF.do_block_index(childs)

        @test do_idx == 5
        @test JF.has_do_block_call(node) == do_idx
        @test length(JF.call_args(childs[1:(do_idx-1)])) == 1

        # Single-iterator loops can inspect the RHS iterable directly.
        _, _, node = parsed_node("""
        for x in [1, 2]
        end
        """)
        iter = JS.children(node)[2]
        @test !JF.iteration_has_comma(iter)
        @test JS.kind(JF.iteration_rhs(iter)) === JS.Kind("vect")

        # Cartesian iterations need to detect the comma and use the final iteration
        # expression as the effective RHS.
        _, _, node = parsed_node("""
        for x in [1, 2], y in 3:4
        end
        """)
        iter = JS.children(node)[2]
        @test JF.iteration_has_comma(iter)
        @test JS.kind(JF.iteration_rhs(iter)) === JS.Kind("call")
    end

    @testset "display-width source offsets" begin
        # Alignment uses display columns, not code-unit offsets; the combining mark
        # in s\u0304_b should not add a visible column.
        text = "s\u0304_b      = 1\n"
        doc = JF.Document(text)
        eq_offset = findfirst(isequal('='), text)

        @test eq_offset > 10
        @test JF.source_display_line_offset(doc, 1, eq_offset) == 10
        @test JF.node_align_length(JF.FST(JF.IDENTIFIER, 1, 1, 1, "s\u0304_b")) == 3
    end

    @testset "module flags" begin
        # JS v1 stores baremodule as a module node with a flag.
        _, _, node = parsed_node("""
        baremodule A
        end
        """)

        @test JS.kind(node) === JS.Kind("module")
        @test JS.has_flags(node, JS.BARE_MODULE_FLAG)
        @test !JF.is_short_function_def(node)
        @test JF.format_text("baremodule A\nend") == "baremodule A end"
    end
end

@testset "predicates on GreenNodes" begin
    @testset "unary_info" begin
        # [1] to index into the actual node we care about
        p(x) = JS.parseall(JS.GreenNode, strip(x); version=JF.SUPPORTED_SYNTAX_VERSION)[1]
        # Prefix operator
        @test JF.unary_info(p("+(x)")) === true
        @test JF.unary_info(p("+x")) === true
        @test JF.unary_info(p("+x")) === true
        @test JF.unary_info(p("+[1,2]")) === true
        @test JF.unary_info(p("<:x")) === true
        @test JF.unary_info(p("-x")) === true
        @test JF.unary_info(p("-[1,2]")) === true
        # Postfix operators
        @test JF.unary_info(p("x'")) === false
        @test JF.unary_info(p("x'ᵀ")) === false
        @test JF.unary_info(p("x'...")) === false
        @test JF.unary_info(p("[1,2]'")) === false
        @test JF.unary_info(p("x...")) === false
        @test JF.unary_info(p("[1,2]...")) === false
        # Things that aren't unaries at all
        @test JF.unary_info(p("+")) === nothing
        @test JF.unary_info(p("<:")) === nothing
        @test JF.unary_info(p("x + y")) === nothing
        @test JF.unary_info(p("f(x)")) === nothing
        @test JF.unary_info(p("x")) === nothing
        @test JF.unary_info(p("[1, 2]")) === nothing
        @test JF.unary_info(p("x.y")) === nothing
        @test JF.unary_info(p("+(x, y)")) === nothing
        @test JF.unary_info(p("string(x)")) === nothing
    end

    @testset "first_nonws_leaf_and_offset" begin
        p(x) = JS.parseall(JS.GreenNode, x; version=JF.SUPPORTED_SYNTAX_VERSION)
        # Simple identifier
        let result = JF.first_nonws_leaf_and_offset(p("x")[1])
            @test result !== nothing
            @test JS.kind(result[1]) === JS.Kind("Identifier")
            @test result[2] == 0
        end
        # Operator application — first leaf is the operator
        let result = JF.first_nonws_leaf_and_offset(p("+x")[1])
            @test result !== nothing
            @test result[2] == 0
        end
        # With some whitespace
        let result = JF.first_nonws_leaf_and_offset(p("  +x"))
            @test result !== nothing
            @test result[2] == 2
        end
    end

    @testset "source_begins_with_op_needing_parens" begin
        function check(code)
            node = JS.parseall(JS.GreenNode, code; version=JF.SUPPORTED_SYNTAX_VERSION)[1]
            opts = JF.Options()
            s = JF.State(JF.Document(code), opts)
            return JF.source_begins_with_op_needing_parens(s, node, s.offset)
        end
        # Operators
        @test check("+x")
        @test check("-x")
        @test check("!x")
        @test check(">=(x)")
        # Non-operators / already parenthesised
        @test !check("(+x)")
        @test !check("string(x)")
        @test !check("x")
        @test !check("[1, 2]")
        @test !check("x'")
        @test !check("x'ᵀ")
        @test !check("a ? b : c")
        # Manual exclusions (see source_begins_with_op_needing_parens comments)
        @test !check(":x")
        @test !check("isa(x, T)")
    end
end

end # module
