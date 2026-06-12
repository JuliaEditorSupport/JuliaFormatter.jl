module ShortCircuitToIfTests

using JuliaFormatter.Internal: test_format
using Test

@testset "short_circuit_to_if" begin
    s_ = """
        begin
        a && b
        end
    """
    s = """
    begin
        if a
            b
        else
            false
        end
    end
    """
    test_format(s_, s; margin=92, short_circuit_to_if = true)

    s_ = """
        begin
        a || b
        end
    """
    s = """
    begin
        if !(a)
            b
        else
            true
        end
    end
    """
    test_format(s_, s; margin=11, short_circuit_to_if = true)

    s = """
    begin
        if !(
            a
        )
            b
        else
            true
        end
    end
    """
    test_format(s_, s; margin=10, short_circuit_to_if = true)

    # > 1
    s_ = """
        begin
        a && b && c && d
        end
    """
    s = """
    begin
        if a && b && c
            d
        else
            false
        end
    end
    """
    test_format(s_, s; margin=92, short_circuit_to_if = true)

    s_ = """
        begin
        a && b && c || d
        end
    """
    s1 = """
    begin
        if !(a && b && c)
            d
        else
            true
        end
    end
    """
    test_format(s_, s1; margin=21, short_circuit_to_if = true)

    s2 = """
    begin
        if !(
            a && b && c
        )
            d
        else
            true
        end
    end
    """
    test_format(s_, s2; margin=20, short_circuit_to_if = true)

    s_ = """
        begin
        (a && b && c) || d
        end
    """
    test_format(s_, s1; margin=21, short_circuit_to_if = true)
    test_format(s_, s2; margin=20, short_circuit_to_if = true)

    s_ = """
    function foo()
        a && (b || c || d)
    end
    """
    s = """
    function foo()
        if a
            (b || c || d)
        else
            false
        end
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
        else
            false
        end
    end
    """
    test_format(s_, s; margin=92, short_circuit_to_if = true)

    @testset "return statement" begin
        # If the return statement is already there, don't add it!
        for op in ("&&", "||")
            s = """
            function f()
                return a $(op) b
            end
            """
            test_format(s, s; short_circuit_to_if = true)
        end

        # But if the return statement isn't there yet and we asked to prepend it...
        s = """
        function f()
            a && b
        end
        """
        output = """
        function f()
            return if a
                b
            else
                false
            end
        end
        """
        test_format(s, output; short_circuit_to_if = true, always_use_return = true)

        s = """
        function f()
            a || b
        end
        """
        output = """
        function f()
            return if !(a)
                b
            else
                true
            end
        end
        """
        test_format(s, output; short_circuit_to_if = true, always_use_return = true)
    end

    @testset "while cond" begin
        s = """
        while a && b
            c
        end
        """
        test_format(s, s; short_circuit_to_if = true)
    end
end

end # module
