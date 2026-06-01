# Code editors

If you are using any reasonably modern code editor, the easiest option for integrating JuliaFormatter into your editor is to use a language server which provides formatting capabilities.

## LanguageServer.jl

[LanguageServer.jl](https://github.com/julia-vscode/LanguageServer.jl) provides LSP support for Julia and uses JuliaFormatter to format Julia code.
Instructions for setting up LanguageServer.jl for your editor of choice can be found in the LanguageServer.jl docs.

!!! warning "JuliaFormatter version with LanguageServer.jl"

    Note that JuliaFormatter is a dependency of LanguageServer.jl, and thus, the version of JuliaFormatter used for formatting code will be set once when you install LanguageServer.jl and fixed after that.

    This is **not** an ideal situation because often, the version of formatter used is a project-level setting: for example, CI will be configured to run with a specific version of JuliaFormatter, and you will want to use the same version when formatting locally.

    The real solution here is to decouple the formatter from the language server, for example, by having the language server call out to a separate formatter process.
    This will hopefully change in the future, but for now this is a genuine limitation.

### VSCode

If you use [the Julia VSCode extension](https://marketplace.visualstudio.com/items?itemName=julialang.language-julia) this is already backed by LanguageServer.jl and hence JuliaFormatter.
[`.JuliaFormatter.toml`](@ref config) files in your project will be detected automatically.
See [the extension's docs](https://www.julia-vscode.org/docs/stable/userguide/formatter/) for more information.

!!! note "JuliaFormatter version"
    As described above, the version of JuliaFormatter used is dictated by the extension.
    See e.g. [this issue](https://github.com/julia-vscode/julia-vscode/issues/4010#issue-3888453945) for an example of how to work around this by installing a custom formatter in VSCode.

## JETLS.jl

[JETLS.jl](https://github.com/aviatesk/JETLS.jl) is a new language server implementation for Julia, backed by much more thorough static analysis of Julia code.
It also contains support for formatting code, and importantly, it does so by invoking a formatter executable!
This means that you can use any version of JuliaFormatter you like (from v2.2 onwards, since that is when the [`jlfmt` CLI app](@ref cli) became available)

Please see the JETLS.jl docs for more information on [editor setup](https://aviatesk.github.io/JETLS.jl/release/#index/editor-setup) and [configuring the formatter](https://aviatesk.github.io/JETLS.jl/release/formatting/).

!!! warning "JETLS.jl is cutting-edge"
    JETLS.jl's README currently states "Experimental: JETLS is under active development. Not production-ready; APIs and behavior may change. Stability and performance are limited. Expect bugs and rough edges."

## Legacy editor support

Before the days where LSP was ubiquitous, there were various editor plugins which provided direct integration with JuliaFormatter:

- [Vim / Neovim](https://github.com/kdheepak/JuliaFormatter.vim)
- [Emacs](https://codeberg.org/FelipeLema/julia-formatter.el)
- [VSCode (deprecated)](https://github.com/singularitti/vscode-julia-formatter/)
- [Atom (maintenance-only)](https://github.com/JunoLab/Atom.jl)
