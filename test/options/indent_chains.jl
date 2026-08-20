module IndentChainsTests

using JuliaFormatter: BlueStyle, MinimalStyle, YASStyle
using JuliaFormatter.Internal: test_format
using Test

@testset "indent_chains" begin
    # `join_lines_based_on_source` keeps the line breaks of the input, so the chains below
    # stay nested and we can observe how the continuation lines are indented.
    @testset "disabled (default)" begin
        # continuation lines are aligned to the column the expression starts at, and a
        # top-level chain gets no indentation at all
        test_format(
            "aaa |>\nbbb |>\nccc\n",
            "aaa |>\nbbb |>\nccc\n";
            join_lines_based_on_source=true,
            ast=true,
        )
        test_format(
            "x = (aaa |>\n     bbb)\n",
            "x = (aaa |>\n     bbb)\n";
            join_lines_based_on_source=true,
            ast=true,
        )
        test_format(
            "function g()\n    return aaa |>\n           bbb\nend\n",
            "function g()\n    return aaa |>\n           bbb\nend\n";
            join_lines_based_on_source=true,
            ast=true,
        )
        test_format(
            "x = aaaaaaaa == bbbbbbbbb == cccccccc\n",
            "x =\n    aaaaaaaa ==\n    bbbbbbbbb ==\n    cccccccc\n";
            margin=20,
            ast=true,
        )
        test_format(
            "x = aaaaaaaa == bbbbbbbbb == cccccccc\n",
            "x = aaaaaaaa ==\n    bbbbbbbbb ==\n    cccccccc\n",
            YASStyle();
            margin=20,
            ast=true,
        )
    end

    @testset "enabled" begin
        # each continuation line receives one indent level relative to the statement
        test_format(
            "aaa |>\nbbb\n",
            "aaa |>\n    bbb\n";
            indent_chains=true,
            join_lines_based_on_source=true,
            ast=true,
        )
        test_format(
            "aaa |>\nbbb |>\nccc\n",
            "aaa |>\n    bbb |>\n    ccc\n";
            indent_chains=true,
            join_lines_based_on_source=true,
            ast=true,
        )
        # aligned input converges to the indented form
        test_format(
            "f() = aaa |>\n      bbb |>\n      ccc\n",
            "f() = aaa |>\n    bbb |>\n    ccc\n";
            indent_chains=true,
            join_lines_based_on_source=true,
            ast=true,
        )
        test_format(
            "x = (aaa |>\n     bbb)\n",
            "x = (aaa |>\n    bbb)\n";
            indent_chains=true,
            join_lines_based_on_source=true,
            ast=true,
        )
        # inside a function body the extra indent is relative to the statement
        test_format(
            "function g()\n    return aaa |>\n           bbb\nend\n",
            "function g()\n    return aaa |>\n        bbb\nend\n";
            indent_chains=true,
            join_lines_based_on_source=true,
            ast=true,
        )
        # comparisons in an if condition
        test_format(
            "if aaa ==\n   bbb\n    x\nend\n",
            "if aaa ==\n    bbb\n    x\nend\n";
            indent_chains=true,
            join_lines_based_on_source=true,
            ast=true,
        )
        # nested chains each get one extra level
        test_format(
            "x = aaa(bbb |>\nccc) |>\nddd\n",
            "x = aaa(bbb |>\n    ccc) |>\n    ddd\n";
            indent_chains=true,
            join_lines_based_on_source=true,
            ast=true,
        )
        # the option also applies when nesting is driven by the margin rather than by the
        # line breaks of the source. Here the comparison itself is already on an indented
        # line (the RHS of the assignment), so its continuations get one level on top.
        test_format(
            "x = aaaaaaaa == bbbbbbbbb == cccccccc\n",
            "x =\n    aaaaaaaa ==\n        bbbbbbbbb ==\n        cccccccc\n";
            indent_chains=true,
            margin=20,
            ast=true,
        )
    end

    @testset "standalone short-circuit chains" begin
        # `n_block!` already indents these by one level; the option must not double it
        for indent_chains in (false, true)
            test_format(
                "aa &&\nbb\n",
                "aa &&\n    bb\n";
                indent_chains,
                join_lines_based_on_source=true,
                ast=true,
            )
            test_format(
                "aa &&\nbb &&\ncc\n",
                "aa &&\n    bb &&\n    cc\n";
                indent_chains,
                join_lines_based_on_source=true,
                ast=true,
            )
            test_format(
                "f(aa &&\nbb)\n",
                "f(aa &&\n    bb)\n";
                indent_chains,
                join_lines_based_on_source=true,
                ast=true,
            )
        end
    end

    @testset "MinimalStyle enables it by default" begin
        test_format("aaa |>\nbbb\n", "aaa |>\n    bbb\n", MinimalStyle(); ast=true)
        test_format(
            "x = (aaa |>\n     bbb)\n",
            "x = (aaa |>\n    bbb)\n",
            MinimalStyle();
            ast=true,
        )
        test_format(
            "if aaa ==\n   bbb\n    x\nend\n",
            "if aaa ==\n    bbb\n    x\nend\n",
            MinimalStyle();
            ast=true,
        )
        # opting back out restores the aligned layout
        test_format(
            "x = (aaa |>\n     bbb)\n",
            "x = (aaa |>\n     bbb)\n",
            MinimalStyle();
            indent_chains=false,
            ast=true,
        )
    end

    @testset "BlueStyle" begin
        test_format(
            "x = (aaa +\n     bbb +\n     ccc)\n",
            "x = (aaa +\n     bbb +\n     ccc)\n",
            BlueStyle();
            join_lines_based_on_source=true,
            ast=true,
        )
        test_format(
            "x = (aaa +\n     bbb +\n     ccc)\n",
            "x = (aaa +\n    bbb +\n    ccc)\n",
            BlueStyle();
            indent_chains=true,
            join_lines_based_on_source=true,
            ast=true,
        )
    end
end

end # module
