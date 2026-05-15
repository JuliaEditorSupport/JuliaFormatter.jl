# Integrations

## `pre-commit`

To learn more about `pre-commit`, [check out their docs](https://pre-commit.com).

With [Pull 674](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/pull/674), support for 
`pre-commit` was added. To add `JuliaFormatter.jl` to your own `pre-commit` workflow,
add the following to your `.pre-commit-config.yaml`.

```yaml
repos:
# ... other repos you may have
- repo: "https://github.com/JuliaEditorSupport/JuliaFormatter.jl"
  rev: "v1.0.18"  # or whatever the desired release is
  hooks:
  - id: "julia-formatter"
# ... other repos you may have
```

Note that it requires the `jlfmt` Pkg app to be installed with

```julia
pkg> app add JuliaFormatter
```

You can find a list of releases [here](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/releases).
**Be sure to use the entire version string!** (You can double-check this by opening the
release and looking at the part of the URL that follows `.../releases/tag/VERSION`.)
