# GitHub Actions

To set up a formatting check in CI, you can use [the `julia-actions/julia-format` action](https://github.com/julia-actions/julia-format): please see that repository's documentations for instructions on how to set it up.

Alternatively, if you have JuliaFormatter set up as part of your repository's [pre-commit checks](@ref pre-commit) checks, you can directly use pre-commit's CI tooling:

- [GitHub Action workflow](https://github.com/pre-commit/action)
- [GitHub App](https://pre-commit.ci/)
