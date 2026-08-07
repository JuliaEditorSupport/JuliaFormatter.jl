module JuliaFormatter

using PrecompileTools: @setup_workload, @compile_workload
using JuliaSyntax
using JuliaSyntax: children, span, @K_str, kind, @KSet_str
using Glob
import CommonMark: block_modifier
using CommonMark:
    AdmonitionRule,
    CodeBlock,
    enable!,
    FootnoteRule,
    markdown,
    MathRule,
    Parser,
    Rule,
    TableRule,
    FrontMatterRule

include("packagedef.jl")

end # module JuliaFormatter
