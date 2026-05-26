using Pkg: Pkg
Pkg.develop(; path = dirname(@__DIR__))

using Documenter, JuliaFormatter

makedocs(;
    sitename = "JuliaFormatter",
    format = Documenter.HTML(),
    modules = [JuliaFormatter],
    pages = [
        "Introduction" => "index.md",
        "How It Works" => "how_it_works.md",
        "Code Style" => "style.md",
        "Skipping Formatting" => "skipping_formatting.md",
        "Syntax Transforms" => "transforms.md",
        "Custom Alignment" => "custom_alignment.md",
        "YAS Style" => "yas_style.md",
        "Blue Style" => "blue_style.md",
        "SciML Style" => "sciml_style.md",
        "Configuration File" => "config.md",
        "Command Line Interface" => "cli.md",
        "Integrations" => "integrations.md",
        "API Reference" => "api.md",
    ],
)
