using Pkg: Pkg
Pkg.develop(; path = dirname(@__DIR__))

using Documenter, JuliaFormatter

makedocs(;
    sitename = "JuliaFormatter",
    format = Documenter.HTML(),
    modules = [JuliaFormatter],
    pages = [
        "Overview" => "index.md",
        "Options" => [
            "Formatting Options" => "formatting_options.md",
            "Custom Alignment" => "custom_alignment.md",
        ],
        "Styles" => [
            "Default Style" => "default_style.md",
            "YAS Style" => "yas_style.md",
            "Blue Style" => "blue_style.md",
            "SciML Style" => "sciml_style.md",
        ],
        "Skipping Formatting" => "skipping_formatting.md",
        "Configuration File" =>
            [".JuliaFormatter.toml" => "config.md", "File Options" => "file_options.md"],
        "Command-Line Interface" => "cli.md",
        "Integrations" => [
            "Editors" => "editors.md",
            "GitHub Actions" => "github_actions.md",
            "pre-commit" => "precommit.md",
            "PackageCompiler" => "packagecompiler.md",
        ],
        "How It Works" => "how_it_works.md",
        "API Reference" => "api.md",
        "Contributing" => "contributing.md",
        "Project Status" => "status.md",
    ],
)

deploydocs(;
    repo = "github.com/JuliaEditorSupport/JuliaFormatter.jl.git",
    push_preview = true,
)
