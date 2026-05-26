#!/usr/bin/env bash

# Wrapper for the jlfmt executable, which is used in the jlfmt pre-commit hook.
#
# Resolution order for jlfmt:
#
#   1. --jlfmt-path=<path> (explicit override)
#   2. jlfmt on PATH
#   3. $JULIA_DEPOT_PATH/bin (each entry, colon-separated)
#   4. ~/.julia/bin (default depot)
#
# Gracefully errors if jlfmt can't be found.

jlfmt=""

# Parse --jlfmt-path argument and pass the rest through.
args=()
for arg in "$@"; do
    case "$arg" in
        --jlfmt-path=*) jlfmt="${arg#--jlfmt-path=}" ;;
        *) args+=("$arg") ;;
    esac
done

if [ -n "$jlfmt" ]; then
    # Path was explicitly specified. Expand tildes and check if it exists
    jlfmt="${jlfmt/#\~/$HOME}"
    if ! command -v "$jlfmt" &>/dev/null; then
        echo "Error: The executable '$jlfmt' (passed via --jlfmt-path) was not found."
        exit 1
    fi
else
    # Not specified, we'll have to search for it ourselves.
    # Step 1: Check PATH
    if command -v jlfmt &>/dev/null; then
        jlfmt="jlfmt"
    # Step 2: Check JULIA_DEPOT_PATH
    elif [ -n "$JULIA_DEPOT_PATH" ]; then
        IFS=: read -ra depots <<< "$JULIA_DEPOT_PATH"
        for depot in "${depots[@]}"; do
            depot="${depot/#\~/$HOME}"
            if [ -x "$depot/bin/jlfmt" ]; then
                jlfmt="$depot/bin/jlfmt"
                break
            fi
        done
    fi
    # Step 3: Check ~/.julia/bin (default fallback: cf. Julia's
    # `Base.init_depot_path()` implementation). In principle, we would like to
    # run `julia -e 'println(DEPOT_PATH)'`, but that takes too long, so is not
    # a viable option for pre-commit.
    if [ -z "$jlfmt" ] && [ -x "${HOME}/.julia/bin/jlfmt" ]; then
        jlfmt="${HOME}/.julia/bin/jlfmt"
    fi
    # Error
    if [ -z "$jlfmt" ]; then
        echo "ERROR: 'jlfmt' not found."
        echo "Install it with: julia -e 'import Pkg; Pkg.Apps.add(\"JuliaFormatter\")'"
        echo "Then make sure that jlfmt is on your PATH, or tell pre-commit its location with:"
        echo ""
        echo "    args: [\"--jlfmt-path=/path/to/jlfmt\"]"
        echo ""
        echo "See https://juliaeditorsupport.github.io/JuliaFormatter.jl/stable/integrations/ for details."
        exit 1
    fi
fi

exec "$jlfmt" --threads=auto -- --inplace "${args[@]}"
