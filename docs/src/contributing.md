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

## Issue triage

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
