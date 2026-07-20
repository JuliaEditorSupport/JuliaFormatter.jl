module OptionEnforceTriplequoteDocstring

using JuliaFormatter.Internal: test_format
using Test

@testset "Basic" begin

    opts = (; format_docstrings=true)

    # (use begin blocks to check indentation)
    triple = """
    begin
        \"""
        doc
        \"""
        f() = 0
    end
    """

    single = """
    begin
        "doc"
        f() = 0
    end
    """

    # Normalize to triple by default.
    test_format(triple, triple; opts...)
    test_format(single, triple; opts...)

    # Unless we opt out.
    opts = (; format_docstrings=true, enforce_triplequote_docstring=false)
    test_format(single, single; opts...)

    # Not exactly good taste, but the option leaves it alone as promised.
    single_multiline = """
    begin
        "line1\\n\\
        line2"
        f() = 0
    end
    """
    test_format(single_multiline, single_multiline; opts...)

    # Still drop trailing whitespace on the first line (#667).
    test_format(
        """
        begin
            "$(" \t \t ")
            doc
            "
            f() = 0
        end
        """,
        """
        begin
            "doc"
            f() = 0
        end
        """,
        ; opts...)

end

end
