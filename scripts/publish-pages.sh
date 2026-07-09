#!/usr/bin/env bash
# Publish the static Sileo source (repo/) to the gh-pages branch.
# GitHub Pages is configured for branch: gh-pages, path: /
# Pushing only to main will NOT update what Sileo sees.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty. Commit or stash before publishing." >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$branch" != "main" ]]; then
  echo "Publish from main (current: $branch)." >&2
  exit 1
fi

# Ensure Packages index is fresh
./scripts/package-repo.sh

git fetch origin gh-pages
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Export current repo/ as the site root
rsync -a --delete "$ROOT/repo/" "$tmp/site/"

git worktree add --force "$tmp/gh-pages" gh-pages
rsync -a --delete \
  --exclude '.git' \
  "$tmp/site/" "$tmp/gh-pages/"

(
  cd "$tmp/gh-pages"
  git add -A
  if git diff --cached --quiet; then
    echo "gh-pages already up to date."
  else
    git commit -m "Publish Sileo repo snapshot from main $(git -C "$ROOT" rev-parse --short HEAD)"
    git push origin HEAD:gh-pages
    echo "Pushed gh-pages. Sileo source will update after GitHub Pages rebuilds (~30–60s)."
  fi
)

git worktree remove --force "$tmp/gh-pages" 2>/dev/null || true
echo "Done. Source: https://chasesdavis.github.io/repo/"
