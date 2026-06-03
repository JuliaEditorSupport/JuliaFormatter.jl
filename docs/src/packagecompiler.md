## [PackageCompiler.jl](@id packagecompiler)

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
