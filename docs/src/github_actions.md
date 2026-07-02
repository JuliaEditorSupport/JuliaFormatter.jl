# GitHub Actions

To set up a formatting check in CI, here is a barebones action.
This will just fail if any files are not formatted.

!!! note "Pin the version of JuliaFormatter"
    It is **strongly** recommended that you pin the version of JuliaFormatter used in your CI workflow.

```yaml
name: Format

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  format:
    name: Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # 7.0.0
      - uses: julia-actions/setup-julia@fa02766e078afaaf09b14210362cee14137e6a32 # 3.0.2
      - uses: julia-actions/cache@a45e8fa8be21c18a06b7177052533149e61e9b38 # 3.1.0
      - name: Install JuliaFormatter
        run: |
          julia -e 'using Pkg; Pkg.Registry.add("General"); Pkg.Registry.update(); Pkg.Apps.add(name="JuliaFormatter", version=v"2.10.1")'
      - name: Check formatting
        run: |
          ${HOME}/.julia/bin/jlfmt --check --verbose .
```

If you want an action that makes comments on PRs with suggested formatting changes, you can use [the `julia-actions/julia-format` action](https://github.com/julia-actions/julia-format): please see that repository's documentations for instructions on how to set it up.

Alternatively, if you have JuliaFormatter set up as part of your repository's [pre-commit checks](@ref pre-commit) checks, you can directly use pre-commit's CI tooling:

- [GitHub Action workflow](https://github.com/pre-commit/action)
- [GitHub App](https://pre-commit.ci/)
