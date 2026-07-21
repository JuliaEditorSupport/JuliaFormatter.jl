# Refactor FormatBot workflow to use JuliaFormatter's CLI

## File to edit

`.github/workflows/FormatBot.yml`

## Background

The FormatBot workflow currently constructs a `format.jl` script as a Python string that calls `JuliaFormatter.format()` with programmatically-built Julia code (style constructors like `BlueStyle()`, keyword args). This is hacky. JuliaFormatter has a proper CLI entry point via `JuliaFormatter.main(ARGS)` (see `src/app.jl`) that accepts all the same options as CLI flags (e.g. `--style=blue`, `--margin=92`, `--ignore-config`). We should use it.

## What to change

Keep Python, keep `shell: python`.

### 1. Replace `format.jl` script generation with a `jlfmt()` helper

Remove the `style_shortcuts` dict, `kwargs` list, `fmt_call` construction, and `Path("format.jl").write_text(...)` block. Replace them with a helper function that invokes Julia directly:

```python
def jlfmt(project):
    return subprocess.run([
        "julia", f"--project={project}", "-e",
        "import Pkg; Pkg.instantiate(); using JuliaFormatter; exit(JuliaFormatter.main(ARGS))",
        "--", *jlfmt_args, format_path,
    ])
```

### 2. Build `jlfmt_args` as CLI flags

Instead of building Julia kwargs, build a list of CLI flags. Start with `["--inplace"]`. FormatBot meta-options (`subdir=`, `use_config=`, `against=`) are extracted as before; everything else from the comment is passed through directly as CLI args. No transformation needed — just append the token as-is.

Users will write `--style=blue --margin=92` instead of `style=blue margin=92`.

### 3. Replace config file deletion with `--ignore-config`

Currently the script runs `find target_dir -name ".JuliaFormatter.toml" -delete` when `use_config` is false. Instead, append `--ignore-config` to `jlfmt_args`. Remove the `find ... -delete` block.

### 4. Drop `throw_on_error=true`

The CLI already exits non-zero on errors, so this kwarg is unnecessary.

### 5. Update all Julia subprocess calls to use `jlfmt()`

There are 4 `subprocess.run(["julia", ..., "format.jl", format_path])` calls (2 for base formatting + idempotence check, 2 for PR formatting + idempotence check). Replace them with `jlfmt("formatter-base")` or `jlfmt("formatter-pr")` as appropriate. The return-code checking logic around them stays the same.

### 6. Don't change anything else

The comment parsing, git operations, header construction, diff computation, idempotence checking, and comment posting all stay as-is.

## Interface change

The FormatBot comment syntax changes from:

```
!formatbot JuliaLang/julia style=blue margin=92
```

to:

```
!formatbot JuliaLang/julia --style=blue --margin=92
```

The meta-options (`subdir=`, `use_config=`, `against=`) keep their current `key=value` form (no `--` prefix) so they don't collide with jlfmt flags.
