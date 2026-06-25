# Project status

([Penny speaking here](https://github.com/penelopeysm); my views are only my own, etc. etc.)

This is a less formal page, where I discuss the current state of JuliaFormatter development and some long-term goals.

## Update - 25 June 2026

Since I wrote this page, a lot of work has gone into making JuliaFormatter v2 more reliable, with fewer cases where formatting changes the meaning of code, fails, or is non-idempotent.
These efforts have so far mainly been focused on Default and Blue styles.
These two styles are now tested extensively on around 5 million lines of Julia code in CI, and I believe that they are now much more reliable than they were in previous v2 releases.

Note that, as described in the [Formatting Options](@ref formatting-options) page, to guarantee idempotence it is recommended that you set certain options:

- `v2_stable_multiline_strings = true`
- `conditional_to_if = false`
- `pipe_to_function_call = false`

Without these, idempotence cannot be guaranteed.

**I would say that as of v2.10, Default and Blue styles are ready for general usage.**
While it is possible that there will be some changes to the output as a result of other bug fixes, formatting should largely stay unchanged going forwards.

However, SciMLStyle and YASStyle are still quite buggy, and I would not (yet) recommend using them in v2.
(Unfortunately, they also contain a lot of custom code, which is why I have put them off for now, and also why I have much less motivation to fix them...)
JuliaFormatter v1 might still be the safer option for these styles.

PRs to improve SciML and YAS styles are very welcome!

## Stability

At present, I do not consider it possible to outright guarantee that formatted output will not change between versions.

That is to say, the version of JuliaFormatter guarantees its public library API, along with its configuration options.
However, I cannot give a blanket guarantee that v2.p.q will not change the formatting of v2.r.s.
(Note that this is consistent with the way that JuliaFormatter has been developed to date.)

The main reason for this is because JuliaFormatter v2 still contains a number of bugs, *in particular*, with SciML and YAS styles.
With Default and Blue styles the situation is much better, and it is likely that there will be fewer changes in formatting between versions; however, I can't *promise* this.

A secondary reason is that the codebase is in what I consider to be a local minimum.
It often happens to work, but there are for example several functions which are overloaded in different places for different purposes.
There is definitely some refactoring needed to make the code easier to maintain and easier to improve.
It is very hard to do this without breaking _some_ formatting _somewhere_.

Another lesser point is that JuliaFormatter is designed to be customisable and it's not trivial at all to predict how the introduction of a new formatting option interacts with the rest of the codebase.

### Pinning the JuliaFormatter version

**If you want absolute stability, you should pin the version of JuliaFormatter you use.
In fact, I believe that even if JuliaFormatter *was* more stable, pinning the version is *still* a good idea.**
It's common to just let CI use 'v2' of JuliaFormatter or something similar, which will naturally resolve to the most recent version each time CI is run.
**In my opinion this is bad practice.**

The reason for this is because formatting changes should be separate from other code changes, and should be only introduced as part of an intentional upgrade.
This avoids noisy diffs, and also plays well with the `git blame --ignore-rev` option: if you have a commit that consists only of formatting changes, you can add that to `.git-blame-ignore-revs`, and GitHub/GitLab will ignore that commit when showing the history of a file (see e.g. [this post](https://andreynautilus.github.io/posts/2025-08-23-git-blame-ignore/)).

On top of that, there's really no reason why one should ever want to upgrade to the *latest* version of JuliaFormatter *unless* you specifically want to take advantage of new features or bug fixes.
If you are already happy with v2.p.q then v2.r.s is not going to offer you anything better than that.
You should just pin that version and be done with it.

## What to look forward to in v3?

[You can see this issue for more info about what I'd generally like to have in v3.](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1033)

However, to throw a spanner in the works: *I don't actually think that v3 of JuliaFormatter is the right way to do this.*
I think that it's better to do this in a separate package.

There are several reasons for this:

1. I'd really like to make a clean break from the current aims of JuliaFormatter.
   I think that the extreme customisability makes it difficult to maintain.

1. It would be essentially a massive rewrite anyway.

1. While the above can still happen in a new major version, if anything, my experience of v1 -> v2 has shown that having two different versions of a formatter is a pain point for users.
   For example, you can't install both versions in the same environment.
   Also, since JuliaFormatter is bundled with LanguageServer.jl, it is quite difficult to use a different version of JuliaFormatter from whatever it ships with.
   Although creating a new formatter [runs a risk](https://xkcd.com/927/), it avoids the problem of having to somehow juggle two (or three) different versions of the same package.
