#!/usr/bin/env bash
# Installs the repo's git hooks (scripts/git-hooks) into the shared git dir, for the main checkout and
# all its worktrees. pre-push reads git config user.email, so set it to this repo's own address.
# usage: scripts/git-hooks/install.sh
set -euo pipefail
[[ ${1:-} != help ]] || { sed -n '2,4p' "$0" >&2; exit 2; }
dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
hooks=$(git rev-parse --git-common-dir)/hooks
mkdir -p "$hooks"
install -m 755 "$dir/pre-push" "$hooks/pre-push"
echo "installed $hooks/pre-push; user.email $(git config user.email || echo unset)"
