# Contributing

Contributions are very much welcome!

JuliaFormatter is a pretty difficult project to get into.
Conceptually there is not _that_ much going on: the [How It Works](@ref how-it-works) page has a high-level overview of the different stages of formatting.
However, the complexity comes from the fact that:

- Some parts of Julia's syntax itself can be quite complex! Array literals for example are a massive headache for formatters.

- JuliaSyntax's CST contains quite a few quirks and edge cases.

- Changing the formatting of one node can often have knock-on effects on other places especially with more complex examples.

I'm happy to help with any questions about how best to implement stuff, although please note I'm also finding my way around the codebase myself, so I might not always have the best answer.

## The `JuliaFormatter.Internal` module

JuliaFormatter contains some useful utilities which are explicitly marked as internal (i.e., not semver-compliant), inside the `JuliaFormatter.Internal` module.

There are currently two functions.
`format_to_stage` is more of a helper function for investigating what goes on during the formatting process.
However, `test_format` is used extensively in the test suite.
**Please note that all new tests that check the output of formatting should be written using `test_format`.**

```@docs
JuliaFormatter.Internal.format_to_stage
JuliaFormatter.Internal.test_format
```

## Disabling precompilation for development

JuliaFormatter contains a nontrivial precompilation workload, which can be quite annoying to run locally when iterating on changes.
To disable it, consider adding the following to `LocalPreferences.toml`.
The file belongs in the directory corresponding to your Julia environment.
For example, if you use `julia --project=/path/to/JuliaFormatter`, then the file should be located at `/path/to/JuliaFormatter/LocalPreferences.toml`:

```toml
[JuliaFormatter]
precompile_workload = false
```

(This suggestion is taken from [the PrecompileTools.jl docs](https://julialang.github.io/PrecompileTools.jl/stable/#Package-developers:-reducing-the-cost-of-precompilation-during-development).)

## GitHub-specific things

### FormatBot

JuliaFormatter has a small GitHub workflow, called FormatBot, which can be invoked on PRs with the following syntax:

```
!formatbot
    owner/repo[@REV]
    [against=basefmt|nofmt]   (default: basefmt)
    [use_config=true|false]   (default: false)
    [subdir=SUBDIR]           (default: top-level dir of repo)
    [style=STYLE]
    [arg1=val1 arg2=val2...]
```

where `STYLE` is `default|yas|sciml|blue|minimal` (or omitted to use `DefaultStyle`), and remaining keyword arguments are directly interpolated (**as text**) into `JuliaFormatter.format()`.

`use_config` is a special argument, which indicates whether the `.JuliaFormatter.toml` file in the target repository should be used.
By default this is `false`, i.e., the formatter will *ignore* any existing configuration file in the target repository.

!!! note "Security"
    Because the keyword arguments are interpolated directly, this allows for arbitrary code execution, including printing the contents of environment variables.
    Thus, this command can only be invoked by users with write access to the repository.

When invoked on a JuliaFormatter PR, FormatBot will:

1. Clone the target repository at the specified revision (or the default branch if no revision is specified). Let's call this branch `nofmt`, i.e., no formatting.
1. Check out the base of the JuliaFormatter PR (i.e., usually the current release of JuliaFormatter).
   - Run the formatter on the target repository, with the specified style options, and save those changes to a branch (let's call it `basefmt`).
1. Reset the target repository to `nofmt`.
1. Check out the head of the JuliaFormatter PR (i.e., the proposed changes).
   - Run the formatter on the target repository again, with the same style options, and save *those* changes to a different branch (let's call it `headfmt`);
1. If `against=basefmt`, diff the `basefmt` and `headfmt` branches and post the results as a comment on the PR. If `against=nofmt`, diff the `nofmt` and `headfmt` branches instead.

FormatBot will also include a warning if formatting is not idempotent, or fails.

### [Issue triage](@id issue-triage)

Issues (and sometimes PRs) will be assigned a priority label, with a larger number indicating more important.
The exact label for an issue is left to my discretion, but generally these are the categories that they will fall into:

- **P5** - silently changes the meaning of code. This is absolutely terrible!

- **P4** - fails to format code (still bad, but at least this errors loudly). Non-idempotent formatting also falls into this category.

- **P3** - fails to respect formatting options

- **P2** - formatting is ugly but not a bug *per se*, or feature requests in general

- **P1** - really small things, like typos

Additionally where possible I'll also add **good first issue** tags for changes that are quite self-contained.
These may include any priority level but should generally be P3 or lower.

You can see a list of all triaged issues [here](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues?q=is%3Aissue%20state%3Aopen%20label%3AP5%2CP4%2CP3%2CP2%2CP1).

## AI usage

LLMs and AI in general can be really useful for tracing through some of the logic in the codebase.
(I use them a lot myself!)
However, my experience is that they are still quite poor at design choices:

- They tend to chase short-term gains at the expense of long-term maintainability (i.e., they're happy to fix a bug by inserting hacky code).

- Unless prompted carefully, they won't recognise the effect that a change in one part of the codebase will have on other parts.

Essentially, LLMs if not used carefully are a great path into a _local minimum_.

Please do feel free to use LLMs to help explore the codebase, but when making PRs please consider the above points.

I don't think it's sensible (or indeed possible) completely ban LLM usage, but maintaining an open-source project is difficult and my experience is that LLM contributions tend to be [extractive (in the words of the LLVM project)](https://llvm.org/docs/AIToolPolicy.html).
I don't want to spend all my time cleaning up LLM stuff.
**Therefore, PRs which are clearly LLM-generated, and additionally do not show evidence of human engagement or are too big to be easily reviewed will be rejected.**

If you're just getting started with the codebase and want to help out but don't know where to start, please do just reach out.
I'm genuinely very happy to help *people* with this.
But please don't just ask an LLM to make a PR for you.

Finally, following the LLVM policy, **it is also forbidden to use LLMs to fix good first issues**.
