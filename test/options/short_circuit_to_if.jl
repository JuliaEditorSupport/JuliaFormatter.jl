module ShortCircuitToIfTests

using JuliaFormatter.Internal: test_format, ALL_STYLES
using Test

@testset "short_circuit_to_if" begin
    s_ = """
        begin
        a && b
        2
        end
    """
    s = """
    begin
        if a
            b
        end
        2
    end
    """
    test_format(s_, s; margin=92, short_circuit_to_if = true)

    s_ = """
        begin
        a || b
        2
        end
    """
    s = """
    begin
        if !(a)
            b
        end
        2
    end
    """
    test_format(s_, s; margin=11, short_circuit_to_if = true)

    s = """
    begin
        if !(
            a
        )
            b
        end
        2
    end
    """
    test_format(s_, s; margin=10, short_circuit_to_if = true)

    # > 1
    s_ = """
        begin
        a && b && c && d
        2
        end
    """
    s = """
    begin
        if a && b && c
            d
        end
        2
    end
    """
    test_format(s_, s; margin=92, short_circuit_to_if = true)

    s_ = """
        begin
        a && b && c || d
        2
        end
    """
    s1 = """
    begin
        if !(a && b && c)
            d
        end
        2
    end
    """
    test_format(s_, s1; margin=21, short_circuit_to_if = true)

    s2 = """
    begin
        if !(
            a && b && c
        )
            d
        end
        2
    end
    """
    test_format(s_, s2; margin=20, short_circuit_to_if = true)

    s_ = """
        begin
        (a && b && c) || d
        2
        end
    """
    test_format(s_, s1; margin=21, short_circuit_to_if = true)
    test_format(s_, s2; margin=20, short_circuit_to_if = true)

    s_ = """
    function foo()
        a && (b || c || d)
        2
    end
    """
    s = """
    function foo()
        if a
            (b || c || d)
        end
        2
    end
    """
    test_format(s_, s; margin=92, short_circuit_to_if = true)

    s_ = """
    function foo(a)
        a || return "bar"

        "hello"
    end
    """
    s = """
    function foo(a)
        if !(a)
            return "bar"
        end

        "hello"
    end
    """
    test_format(s_, s; margin=92, short_circuit_to_if = true)

    s_ = """
    function foo(a, b)
        a || return "bar"

        "hello"

        b && return "ooo"
        2
    end
    """
    s = """
    function foo(a, b)
        if !(a)
            return "bar"
        end

        "hello"

        if b
            return "ooo"
        end
        2
    end
    """
    test_format(s_, s; margin=92, short_circuit_to_if = true)

    @testset "return statement" begin
        for op in ("&&", "||")
            # If the return statement is already there, don't expand it!
            s = """
            function f()
                return a $(op) b
            end"""
            test_format(s, s; short_circuit_to_if = true)

            # Also don't expand if it's the last statement in the function and always_use_return
            # is true -- because that means it's conceptually the same as a returned value.
            s_noreturn = """
            function f()
                a $(op) b
            end"""
            test_format(s_noreturn, s; short_circuit_to_if = true, always_use_return = true)
        end
    end

    @testset "don't expand before trailing block comment" begin
        # The short-circuit is the last expression in the block (the block comment
        # doesn't count), so its value is needed and it shouldn't be expanded.
        # The comment stays on its own line (#1194) but `a && b` is still recognised
        # as the last expression.
        s = """
        function foo(a, b)
            a && b
            #= hello =#
        end"""
        test_format(s, s; short_circuit_to_if = true)
    end

    @testset "don't expand in while cond" begin
        s = """
        while a && b
            c
        end
        """
        test_format(s, s; short_circuit_to_if = true)
    end

    @testset "not in macro/expr" begin
        s1 = "@foo a && b"
        s2 = """
        @foo function f()
            a && b
            return c
        end"""
        s3 = ":(a && b)"
        s4 = """
        quote
            begin
                a && b
            end
        end"""
        for s in (s1, s2, s3, s4)
            for style in ALL_STYLES
                test_format(s, s; short_circuit_to_if = true)
                test_format(s, s; short_circuit_to_if = false)
            end
        end
    end
end

end # module
