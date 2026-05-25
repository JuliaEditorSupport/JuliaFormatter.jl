#!/usr/bin/env bash

# Wrapper for the jlfmt executable, which is used in the jlfmt pre-commit hook.
#
# Accepts --jlfmt-path=<path> to specify a custom jlfmt executable, and gracefully
# errors if jlfmt hasn't been installed yet.

jlfmt="jlfmt"

# Parse our args, pass the rest through
args=()
for arg in "$@"; do
    case "$arg" in
        --jlfmt-path=*) jlfmt="${arg#--jlfmt-path=}" ;;
        *) args+=("$arg") ;;
    esac
done

jlfmt="${jlfmt/#\~/$HOME}"

if ! command -v "$jlfmt" &>/dev/null; then
    echo "ERROR: '$jlfmt' not found."
    echo "Install it with: julia -e 'import Pkg; Pkg.Apps.add(\"JuliaFormatter\")'"
    echo "Then make sure that jlfmt is on your PATH, or tell pre-commit its location with:"
    echo ""
    echo "    args: [\"--jlfmt-path=/path/to/jlfmt\"]"
    echo ""
    echo "See https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/integrations/ for details."
    exit 1
fi

exec "$jlfmt" --threads=auto -- --inplace "${args[@]}"
