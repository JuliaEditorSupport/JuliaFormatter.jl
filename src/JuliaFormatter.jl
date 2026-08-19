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

# The `using` and `import` statements above are separated from the rest of the package code
# in order to accommodate julia-vscode. See
# https://github.com/JuliaEditorSupport/JuliaFormatter.jl/pull/1249
include("packagedef.jl")

end # module JuliaFormatter
