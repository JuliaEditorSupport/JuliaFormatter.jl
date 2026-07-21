"""
Compare formatting output between two versions of JuliaFormatter.

Clones a target repo, formats it with a base and/or PR version of
JuliaFormatter, and prints a Markdown comment summarising the diff.
Designed to be called both from CI and locally.

Run with --help for usage and examples.

Environment variables (all optional, used for the Markdown header):
    HEAD_SHA   Commit SHA of the PR JuliaFormatter.
    REPO_URL   URL of the JuliaFormatter repo.
    RUN_URL    URL of the workflow run.
"""

import argparse
import os
import subprocess
import sys
import tempfile
import uuid

FORMATTER_REPO = "JuliaEditorSupport/JuliaFormatter.jl"


def git(target_dir, *args):
    subprocess.run(["git", "-C", target_dir, *args], check=True)


def jlfmt(project, jlfmt_args, format_path):
    return subprocess.run([
        "julia", f"--project={project}", "-e",
        "import Pkg; Pkg.instantiate(); using JuliaFormatter; exit(JuliaFormatter.main(ARGS))",
        "--", *jlfmt_args, format_path,
    ])


def build_header(repo, rev, opts, base_ref, head_sha, repo_url, run_url):
    repo_display = f"{repo}@{rev}" if rev is not None else repo
    lines = [
        "### FormatBot Results",
        "",
        "| Description | Value |",
        "|---|---|",
    ]
    if run_url:
        lines.append(f"| **FormatBot workflow run** | [workflow run]({run_url}) |")
    lines.append(
        f"| **Target repo** | [`{repo_display}`](https://github.com/{repo}{f'/tree/{rev}' if rev is not None else ''}) |"
    )
    fmt_repo_url = repo_url or f"https://github.com/{FORMATTER_REPO}"
    if base_ref:
        lines.append(f"| **JuliaFormatter base** | [`{base_ref[:7]}`]({fmt_repo_url}/commit/{base_ref}) |")
    if head_sha:
        lines.append(f"| **JuliaFormatter PR** | [`{head_sha[:7]}`]({fmt_repo_url}/commit/{head_sha}) |")
    if opts:
        lines.append(f"| **Options** | `{' '.join(opts)}` |")
    lines.append("")
    return "\n".join(lines)


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Compare formatting output between two versions of JuliaFormatter.",
        epilog=(
            "Any unrecognised --flags are forwarded to JuliaFormatter's CLI.\n"
            "\n"
            "Examples:\n"
            "  %(prog)s JuliaLang/julia --base-ref master\n"
            "  %(prog)s JuliaLang/julia --base-ref master --style=blue --margin=92\n"
            "  %(prog)s JuliaLang/julia --style=blue\n"
            "  %(prog)s SomeOrg/SomeRepo@v1.0.0 --base-ref main --subdir src\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("repo_rev", metavar="repo", help="owner/repo or owner/repo@rev")
    parser.add_argument("--base-ref", help="compare against this ref of JuliaFormatter (omit to compare against unformatted code)")
    parser.add_argument("--formatter-pr", default=".", help="path to the PR JuliaFormatter checkout (default: .)")
    parser.add_argument("--target-dir", help="directory to clone the target repo into (default: a temporary directory)")
    parser.add_argument("--subdir", help="only format a subdirectory of the target repo")
    parser.add_argument("--max-diff-bytes", type=int, default=50_000, help="truncate diff display after this many bytes (default: 50000)")
    args, jlfmt_extra = parser.parse_known_args(argv)
    args.jlfmt_args = ["--inplace"] + jlfmt_extra
    return args


def main():
    args = parse_args(sys.argv[1:])

    head_sha = os.environ.get("HEAD_SHA", "")
    repo_url = os.environ.get("REPO_URL", "")
    run_url = os.environ.get("RUN_URL", "")

    # --- Parse repo and revision ---
    if "@" in args.repo_rev:
        repo, rev = args.repo_rev.rsplit("@", 1)
    else:
        repo, rev = args.repo_rev, None

    display_opts = [a for a in args.jlfmt_args if a != "--inplace" and a != "--ignore-config"]
    if args.subdir is not None:
        display_opts.insert(0, f"subdir={args.subdir}")

    header = build_header(repo, rev, display_opts, args.base_ref, head_sha, repo_url, run_url)

    uid = uuid.uuid4().hex[:8]
    branch_clean = f"formatbot-clean-{uid}"
    branch_base = f"formatbot-base-{uid}"
    branch_pr = f"formatbot-pr-{uid}"

    tmpdir = tempfile.mkdtemp(prefix="formatbot-")
    target_dir = args.target_dir or os.path.join(tmpdir, "target")
    formatter_base_dir = os.path.join(tmpdir, "formatter-base") if args.base_ref is not None else None

    try:
        # --- Clone base formatter if needed ---
        if args.base_ref is not None:
            subprocess.run([
                "git", "clone", "--depth", "1", "--branch", args.base_ref,
                f"https://github.com/{FORMATTER_REPO}.git", formatter_base_dir,
            ], check=True)

        # --- Clone target repo ---
        clone_cmd = ["git", "clone", "--depth", "1"]
        if rev is not None:
            clone_cmd += ["--branch", rev]
        clone_cmd += [f"https://github.com/{repo}.git", target_dir]
        subprocess.run(clone_cmd, check=True)

        # Resolve format path
        format_path = os.path.join(target_dir, args.subdir) if args.subdir is not None else target_dir
        if args.subdir is not None and not os.path.isdir(format_path):
            print(f"{header}\n**Error:** Directory `{args.subdir}` not found in target repo.")
            sys.exit(1)

        # Commit clean state so we can branch from it
        git(target_dir, "config", "user.name", "FormatBot")
        git(target_dir, "config", "user.email", "noreply@github.com")
        git(target_dir, "config", "commit.gpgsign", "false")
        git(target_dir, "checkout", "-b", branch_clean)
        git(target_dir, "add", "-A")
        git(target_dir, "commit", "--allow-empty", "-m", branch_clean)

        # --- Format with base, commit to branch ---
        if args.base_ref is not None:
            git(target_dir, "checkout", "-b", branch_base)
            base_result = jlfmt(formatter_base_dir, args.jlfmt_args, format_path)
            if base_result.returncode != 0:
                print(
                    f"{header}\n**Error:** Formatting with base failed."
                    + (f" See [workflow run]({run_url})." if run_url else "")
                )
                sys.exit(1)
            git(target_dir, "add", "-A")
            git(target_dir, "commit", "--allow-empty", "-m", "formatted with base")
            jlfmt(formatter_base_dir, args.jlfmt_args, format_path)
            base_idempotent = subprocess.run(
                ["git", "-C", target_dir, "diff", "--exit-code"],
            ).returncode == 0
            git(target_dir, "checkout", "--", ".")

        # --- Format with PR, commit to branch ---
        git(target_dir, "checkout", branch_clean)
        git(target_dir, "checkout", "-b", branch_pr)
        pr_result = jlfmt(args.formatter_pr, args.jlfmt_args, format_path)
        if pr_result.returncode != 0:
            print(
                f"{header}\n**Error:** Formatting with PR failed."
                + (f" See [workflow run]({run_url})." if run_url else "")
            )
            sys.exit(1)
        git(target_dir, "add", "-A")
        git(target_dir, "commit", "--allow-empty", "-m", "formatted with pr")

        # --- Check idempotence ---
        jlfmt(args.formatter_pr, args.jlfmt_args, format_path)
        pr_idempotent = subprocess.run(
            ["git", "-C", target_dir, "diff", "--exit-code"],
        ).returncode == 0
        git(target_dir, "checkout", "--", ".")

        # --- Compute diff ---
        diff_base = branch_base if args.base_ref is not None else branch_clean
        diff_result = subprocess.run(
            ["git", "-C", target_dir, "diff", "--diff-algorithm=histogram",
             diff_base, branch_pr],
            capture_output=True,
            text=True,
        )
        diff_text = diff_result.stdout

        # --- Build idempotence warning ---
        non_idempotent = []
        if args.base_ref is not None and not base_idempotent:
            non_idempotent.append("base")
        if not pr_idempotent:
            non_idempotent.append("PR")
        if non_idempotent:
            idempotency_warning = (
                f"\n\n> [!CAUTION]\n"
                f"> Formatting with **{' and '.join(non_idempotent)}** is not idempotent!\n"
            )
        else:
            idempotency_warning = ""

        # --- Print comment ---
        if not diff_text:
            print(f"{header}{idempotency_warning}\nNo formatting differences.")
        else:
            diff_bytes = len(diff_text.encode())
            if diff_bytes > args.max_diff_bytes:
                diff_display = diff_text[:args.max_diff_bytes]
                warning = (
                    f"\n\n**Warning:** Diff truncated ({diff_bytes} bytes total)."
                    + (f" See [workflow run]({run_url}) for full output.\n" if run_url else "\n")
                )
            else:
                diff_display = diff_text
                warning = ""
            print(
                f"{header}{idempotency_warning}{warning}\n<details>\n<summary>Diff ({diff_bytes} bytes)</summary>"
                f"\n\n```````diff\n{diff_display}\n```````\n\n</details>"
            )

    except subprocess.CalledProcessError as e:
        cmd = " ".join(str(c) for c in e.cmd)
        print(
            f"{header}\n**Error:** `{cmd}` failed with exit code {e.returncode}."
            + (f" See [workflow run]({run_url})." if run_url else "")
        )
        sys.exit(1)
    except Exception as e:
        print(
            f"{header}\n**Error:** {e}."
            + (f" See [workflow run]({run_url})." if run_url else "")
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
