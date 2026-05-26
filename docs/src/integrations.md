# Integrations

## `pre-commit`

[`pre-commit`](https://pre-commit.com) is a tool for installing and managing pre-commit Git hooks, which makes Git automatically run specified commands before commits are made.
This is useful for ensuring that code matches a certain quality standard before it is committed: for example, you can use `pre-commit` to run `JuliaFormatter.jl` on your code before it is committed.

JuliaFormatter provides two pre-commit hooks for you to use.
One uses the old-style `julia -e ...` invocation; the other uses the `jlfmt` app, which must be installed separately.

### `julia-formatter` hook (uses `julia -e ...`)

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

To pass additional arguments to the Julia invocation (e.g. if JuliaFormatter is installed in a specific project), you can use the `args` field, like so:

```yaml
repos:
- repo: https://github.com/JuliaEditorSupport/JuliaFormatter.jl
  rev: baf84dcde3e7d39a3339fecb51a5d853f8aa35af
  hooks:
  - id: "julia-formatter"
    args: ["--project=/path/to/myproj"]
```

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

Once you have the `jlfmt` app installed, you can add the following to your `.pre-commit-config.yaml`:

```yaml
repos:
- repo: https://github.com/JuliaEditorSupport/JuliaFormatter.jl
  rev: TODO TODO
  hooks:
  - id: "jlfmt"
```

The path to the `jlfmt` executable in the `args` field of the hook, like so (although you should not _need_ to do so—see below):

```yaml
repos:
- repo: https://github.com/JuliaEditorSupport/JuliaFormatter.jl
  rev: TODO TODO
  hooks:
  - id: "jlfmt"
    args: ["--jlfmt-path=/path/to/jlfmt"]
```

However, even without this argument, the pre-commit hook will attempt to locate `jlfmt` for you.
It looks in the following places, in order:

1. Using the executable specified via the `--jlfmt-path` argument, if provided.
2. A `jlfmt` executable on your system `PATH`.
3. `{dir}/bin/jlfmt` for each directory `{dir}` in the `JULIA_DEPOT_PATH` environment variable.
4. `~/.julia/bin/jlfmt`, which is the default depot path if `JULIA_DEPOT_PATH` is not set.

Just like for the `julia-formatter` hook, the `rev` field controls the version of the _hook_ that is checked out, not the version of JuliaFormatter that is used to do the formatting: that is governed by the version of the `jlfmt` app that you installed.
The `rev` field used here points to JuliaFormatter v2.4.0, but this hook is unlikely to change in future releases, so you do not need to worry about updating it to a newer version.

!!! note
    You could also point `rev` to a branch or a release tag, but it is safer to point to a commit hash, since that is immutable and is not vulnerable to e.g. supply chain attacks.


## PackageCompiler.jl

By default, each time JuliaFormatter is launched, it will incur some startup cost due to JIT compilation.
This is the (infamous) TTFX that Julia has in general.

Although recent releases of JuliaFormatter are substantially faster due to intelligent usage of precompilation, the TTFX can still be a problem in the following circumstances:

- If you are using JuliaFormatter v1 (which can be quite painfully slow sometimes)
- If you are running JuliaFormatter frequently, e.g. via pre-commit

which is to say, in many common scenarios!

To mitigate this problem, you can use [PackageCompiler.jl](https://julialang.github.io/PackageCompiler.jl/) to create a custom sysimage that includes cached precompiled code.
While this one-time setup can be quite a bit of a hassle, the benefits can be quite substantial, with speedups of 10x being quite common in practice for JuliaFormatter v1.

Here is a step-by-step walkthrough of how to do this:

1. Make a scratch directory to do stuff in.

   ```bash
   mkdir scratch
   cd scratch
   ```

1. Download any Julia codebase that is large enough and contains code that is representative of the code you want to format.

   When generating the compiled sysimage, we will format this codebase.
   The choice of codebase can affect the results because the precompilation process will cache code paths that are encountered during this formatting, meaning that you should obtain the largest speedups if you choose a codebase that is similar (or identical!) to the code you will be formatting in the future.
   
   As an example, we'll use the Julia base repository itself.

   ```bash
   git clone --depth 1 --branch v1.11.9 https://github.com/JuliaLang/julia.git
   cd julia
   ```

1. Now launch Julia with the following flags:

   ```bash
   julia --startup-file=no --compile=yes -O3 --threads=auto
   ```

1. And run the following in the Julia REPL.
   **Note that the version of JuliaFormatter you install here will be the version that is used to format your code.**

   ```bash
   using Pkg
   Pkg.activate(; temp=true)
   Pkg.add(name="JuliaFormatter", version="2") # Or your preferred version
   Pkg.add("PackageCompiler")

   # Write the precompilation workload to a file.
   open("precompile_file.jl", "w") do io
       write(io, "using JuliaFormatter; format(\".\")")
   end

   # Generate a sysimage with that workload.
   using PackageCompiler
   create_sysimage(
       ["JuliaFormatter"];
       sysimage_path="../juliaformatter.so",
       precompile_execution_file="precompile_file.jl"
   )
   ```

1. Now you should have a sysimage file in the `scratch` directory you made just now (but of course you can change that `sysimage_path` if you prefer).
   Move it to somewhere that is more permanent.
   Once you have done so, you can delete the entire `scratch` directory.

1. After that, to run JuliaFormatter, you can launch Julia as follows:

   ```bash
   julia --startup-file=no --threads=auto -J SYSIMAGE_PATH -O0 --compile=min -e 'using JuliaFormatter; format(".")'
   ```

   where `SYSIMAGE_PATH` is the path to the sysimage you generated in the previous steps.

This is the basic process: you can tweak any aspect of this to your liking, for example, by wrapping the final `julia` invocation in a script/function that takes a path as an argument and passes it into the `julia` call.
For some ideas, see e.g. [this issue](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/633#issuecomment-1518805248) and [this Gist](https://gist.github.com/penelopeysm/9338c160eeb05437205535c2edcf80ee).

### Subsequent usage with `pre-commit`

Once you have generated the sysimage, you can make a custom `pre-commit` hook that uses it, like so:

```yaml
repos:
- repo: local
  hooks:
  - id: format
    name: format
    language: system
    entry: julia --startup-file=no ... # The same command as above.
```

Unfortunately, there are some downsides to this approach.
Firstly, JuliaFormatter cannot provide such a hook for you because the `entry` field needs to be customised for your system (e.g. the sysimage path).
Furthermore, arguably, such a hook should not be shared across users (unless your sysimage is also shared!).
This means that the pre-commit hook above should not be committed to source control.
