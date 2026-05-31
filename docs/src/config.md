# [Configuration File](@id config)

Since v0.4.3, JuliaFormatter offers [`.prettierrc`-style](https://prettier.io/docs/en/configuration.html) configuration file support.

When JuliaFormatter is called, it will look for `.JuliaFormatter.toml` in the location of the file being formatted, and searching _up_ the file tree until a config file is (or isn't) found.
If found, the configurations in the file will override any options passed to JuliaFormatter's functions.

## Specifying options

In `.JuliaFormatter.toml`, you can specify any of the [formatting options](@ref formatting-options) in TOML.
For example, if `somedir/.JuliaFormatter.toml` contains

```toml
indent = 2
margin = 100
```

then files under `somedir` will be formatted with 2 spaces of indentation and a maximum line length of 100.

Configuration files also admit some extra options that are not formatting-related, such as `ignore`.
See [File Options](@ref file-options) for more details.

## Search path

`.JuliaFormatter.toml` will be searched _up_ from the directory of the file being formatted.
So if you have:

```
dir
├─ .JuliaFormatter.toml
├─ code.jl
└─ subdir
   └─ sub_code.jl
```

then:

- `format("subdir/sub_code.jl")` will take its configuration from `dir/.JuliaFormatter.toml`; and
- `format("dir")` will format both `dir/code.jl` and `dir/subdir/sub_code.jl` according to the same configuration.

If there are multiple `.JuliaFormatter.toml` files, the _deepest_ configuration takes precedence.
For example, if you have

```
dir
├─ .JuliaFormatter.toml
├─ code.jl
├─ subdir1
│  ├─ .JuliaFormatter.toml
│  └─ sub_code1.jl
└─ subdir2
   └─ sub_code2.jl
```

and call `format("dir")`, then

- `code.jl` and `sub_code2.jl` will be formatted according to the rules defined in `dir/.JuliaFormatter.toml`, whereas
- `sub_code1.jl` will be formatted according to `dir/subdir1/.JuliaFormatter.toml`.
