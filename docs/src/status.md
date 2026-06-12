# Project status

([Penny speaking here](https://github.com/penelopeysm); my views are only my own, etc. etc.)

This is a less formal page, where I discuss the current state of JuliaFormatter development and some long-term goals.

## Stability

**At present, I do not consider it possible to guarantee that formatted output will not change between versions.**

That is to say, the version of JuliaFormatter guarantees its public library API, along with its configuration options.
However, I cannot give a blanket guarantee that v2.p.q will not change the formatting of v2.r.s.
(Note that this is consistent with the way that JuliaFormatter has been developed to date.)

The main reason for this is because JuliaFormatter v2 is still quite buggy.
It fails to format a fair amount of code in the wild: for example, it can't format `JuliaLang/julia@v1.12.6`.
Even a cursory look at the issue tracker will show that there are still many things that are broken with v2!

A secondary reason is that the codebase is in what I consider to be a local minimum.
It often happens to work, but there are for example several functions which are overloaded in different places for different purposes.
There is definitely some refactoring needed to make the code easier to maintain and easier to improve.
It is very hard to do this without breaking _some_ formatting _somewhere_.

Another lesser point is that JuliaFormatter is designed to be customisable and it's not trivial at all to predict how the introduction of a new formatting option interacts with the rest of the codebase.

### Pinning the JuliaFormatter version

**If you want stability, you should pin the version of JuliaFormatter you use.
In fact, I believe that even if JuliaFormatter *was* more stable, pinning the version is *still* a good idea.**
It's common to just let CI use 'v2' of JuliaFormatter or something similar, which will naturally resolve to the most recent version each time CI is run.
**In my opinion this is bad practice.**

The reason for this is because formatting changes should be separate from other code changes, and should be only introduced as part of an intentional upgrade.
This avoids noisy diffs, and also plays well with the `git blame --ignore-rev` option: if you have a commit that consists only of formatting changes, you can add that to `.git-blame-ignore-revs`, and GitHub/GitLab will ignore that commit when showing the history of a file (see e.g. [this post](https://andreynautilus.github.io/posts/2025-08-23-git-blame-ignore/)).

On top of that, there's really no reason why one should ever want to upgrade to the *latest* version of JuliaFormatter *unless* you specifically want to take advantage of new features or bug fixes.
If you are already happy with v2.p.q then v2.r.s is not going to offer you anything better than that.
You should just pin that version and be done with it.

## Testing

The discussion above naturally leads us onto the question of, how _do_ we know if some formatting somewhere is broken by a given change?
Right now, the only true test of JuliaFormatter's output is in its unit tests.
The unit tests are quite sparse, but *even if* they were greatly expanded, there is no real way that unit tests can even hope to cover the full range of Julia code in the wild.

To this end, I think it's important to run regression tests against large codebases.
I've recently introduced a GitHub Action workflow which runs two versions of JuliaFormatter (PR base + PR head) against a named GitHub repository, and compares the diff.
See, for example, [this PR](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/pull/1011).

I'd like to add some of these checks into CI.
However, this of course means that I have to hardcode some combinations of repositories + formatting options.
**Nominations for codebases are very welcome.**

## The road ahead

For v2, my immediate plan is to fix extremely high-priority bugs: essentially anything labelled as P5 or P4 on the issue tracker.
(See the [contributing docs](@ref issue-triage) for more details on the priority labels.)
I might try to fix P3 bugs as well, but it's very likely that P3 bugs will be prioritised only for DefaultStyle.
(Of course, contributions are more than welcome.)

*However, as stated above, I also believe that some refactoring will make JuliaFormatter easier to maintain and easier to improve.*
In particular, JuliaSyntax's CST is an extremely thin layer on top of the original source code.
It does contain all the information that JuliaFormatter needs, but it's not always in the right shape or form, and that means that downstream code is quite complex.
It would be much easier to work with an augmented form of the CST that baked in some of this information.
(I believe that the FST data structure is mostly fine: there is probably some general code cleanup to be done there, but conceptually it's good.)

I think that this is work that is just as important: it's quite tricky to really make improvements to the codebase without making it worse in some other sense.
Consequently, I believe that once the most critical bugs are fixed I will start working on some of that refactoring.

## What to look forward to in v3?

[You can see this issue for more info about what I'd generally like to have in v3.](https://github.com/JuliaEditorSupport/JuliaFormatter.jl/issues/1033)

I would not recommend holding your breath for a v3 release, though.
This is a project I work on in my spare time, and although I think I'm a pretty decent software engineer, this is naturally a difficult codebase.
I really do recognise that this is an important project for the Julia ecosystem, and I will indeed try my best(!), but I *cannot* over-promise things: note that I want to protect myself against open-source burnout as well.
