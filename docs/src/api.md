# API Documentation

## Public API

```@docs
JuliaFormatter.format
JuliaFormatter.format_text
JuliaFormatter.format_file
JuliaFormatter.format_md
JuliaFormatter.DefaultStyle
JuliaFormatter.YASStyle
JuliaFormatter.BlueStyle
JuliaFormatter.SciMLStyle
JuliaFormatter.MinimalStyle
```

## Internal API

Note that these are subject to change in any version (even patches), and the docstrings are not necessarily up to date!

```@autodocs
Modules = [JuliaFormatter, JuliaFormatter.Shims]
Filter = t -> !(t in (format, format_text, format_file, format_md, DefaultStyle, YASStyle, BlueStyle, SciMLStyle, MinimalStyle))
```
