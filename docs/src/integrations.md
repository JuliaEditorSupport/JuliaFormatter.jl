# Integrations

## `pre-commit`

[`pre-commit`](https://pre-commit.com) is a tool for installing and managing pre-commit Git hooks, which makes Git automatically run specified commands before commits are made.
This is useful for ensuring that code matches a certain quality standard before it is committed: for example, you can use `pre-commit` to run `JuliaFormatter.jl` on your code before it is committed.

JuliaFormatter provides two pre-commit hooks for you to use.
One uses the old-style `julia -e ...` invocation; the other uses the `jlfmt` app, which must be installed separately.

### `julia-formatter` hook (uses `julia -e ...`)

!!! note
    This hook can be quite slow since it needs to start a new Julia process (and incur TTFX) each time it is run!

This hook launches JuliaFormatter via your global Julia installation, which means that you must first install JuliaFormatter as a package.

```julia
import Pkg; Pkg.add("JuliaFormatter")
```

To use the hook, you can add the following to your `.pre-commit-config.yaml`:

```yaml
repos:
- repo: https://github.com/JuliaEditorSupport/JuliaFormatter.jl
  rev: baf84dcde3e7d39a3339fecb51a5d853f8aa35af
  hooks:
  - id: "julia-formatter"
```

(If you have other pre-commit hooks, just add the `repo: ...` block to your pre-existing list of repos.)

**Note that `rev` controls the version of the _hook_ that is checked out; it does not control which version of JuliaFormatter is actually used to format your code.**
The version used to do the actual formatting is determined by the version of JuliaFormatter that is installed in your global Julia environment.
This means that if you want to format your code with JuliaFormatter v1, you must make sure that you install v1 in your global Julia environment.

The `rev` field above is a commit hash that points to [v2.3.2 of JuliaFormatter.jl](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/releases/tag/v2.3.2).
As of the time of writing, this is the latest release of JuliaFormatter.jl.
However, it is extremely unlikely that this hook will change in future releases, so you do not need to worry about 'updating' it to a newer version.

!!! note
    You could also point to a branch or a release tag, but it is safer to point to a commit hash, since that is immutable and is not vulnerable to e.g. supply chain attacks.

### `jlfmt` hook (uses the `jlfmt` app)

To use the `jlfmt` hook you must first make sure that the `jlfmt` app is installed on your system.
Instructions for installing the `jlfmt` app are given in the [CLI documentation](@ref cli).

The version of `jlfmt` that you install here will be the version that is used to actually format your code.
The `jlfmt` app was only introduced in v2.2.0, so versions before that are inaccessible: if you want to format your code with JuliaFormatter v1, you will not be able to use this hook.

Once you have the `jlfmt` app installed and available on your `PATH`, you can add the following to your `.pre-commit-config.yaml`:

```yaml
repos:
- repo: https://github.com/JuliaEditorSupport/JuliaFormatter.jl
  rev: TODO TODO
  hooks:
  - id: "jlfmt"
```

If you prefer not to add `jlfmt` to your `PATH`, you can specify the path to the `jlfmt` executable in the `args` field of the hook, like so:

```yaml
repos:
- repo: https://github.com/JuliaEditorSupport/JuliaFormatter.jl
  rev: TODO TODO
  hooks:
  - id: "jlfmt"
    args: ["--jlfmt-path=/path/to/jlfmt"]
```

Just like for the `julia-formatter` hook, the `rev` field controls the version of the _hook_ that is checked out, not the version of JuliaFormatter that is used to do the formatting: that is governed by the version of the `jlfmt` app that you installed.
The `rev` field used here points to JuliaFormatter v2.4.0, but this hook is unlikely to change in future releases, so you do not need to worry about updating it to a newer version.

!!! note
    You could also point `rev` to a branch or a release tag, but it is safer to point to a commit hash, since that is immutable and is not vulnerable to e.g. supply chain attacks.
