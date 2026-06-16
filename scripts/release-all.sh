#!/usr/bin/env bash
# envpact — release a version across every component repo
#
# Usage:
#   ./scripts/release-all.sh 0.1.0
#
# What it does (per repo):
#   1. Verifies the working tree is clean.
#   2. Bumps version in package.json / pyproject.toml.
#   3. Commits the bump.
#   4. Tags v<VERSION>.
#   5. Pushes commits + tag to origin.
#
# The repos' publish workflows do the rest (npm publish / PyPI /
# vsce publish / Cloudflare Pages deploy).

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: $0 <version>"
  echo "example: $0 0.1.0"
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "error: version must be semver (e.g. 0.1.0 or 1.0.0-beta.1)"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="v$VERSION"

bump_npm_pkg() {
  local dir="$1"
  ( cd "$dir"
    node -e "
      const fs=require('fs');
      const p=require('./package.json');
      p.version='$VERSION';
      fs.writeFileSync('./package.json', JSON.stringify(p,null,2)+'\n');
    "
  )
}

bump_pypi_pkg() {
  local dir="$1"
  ( cd "$dir"
    # Note: heredoc delimiter is UNQUOTED so $VERSION expands.
    # If you change this to 'PY' (quoted), pyproject.toml will be
    # written with the literal string $VERSION and PyPI publish
    # will fail. (Found by audit agent — do not "simplify".)
    python - <<PY
import re, pathlib
p = pathlib.Path('pyproject.toml')
text = p.read_text()
text = re.sub(r'^version\s*=\s*"[^"]+"', 'version = "$VERSION"', text, count=1, flags=re.M)
p.write_text(text)
PY
  )
}

release_one() {
  local component="$1"
  local kind="$2"
  local dir="$ROOT/$component"

  echo
  echo "=== $component ==="
  # In a submodule, .git is a FILE (gitdir pointer), not a directory.
  # `git -C <dir> rev-parse` is the right detector.
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "skip — not a git repo (submodule?)"
    return
  fi
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "skip — working tree dirty"
    return
  fi

  case "$kind" in
    npm) bump_npm_pkg "$dir" ;;
    pypi) bump_pypi_pkg "$dir" ;;
    none) ;; # action / dashboard don't bump a registry version file
  esac

  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    git -C "$dir" add -A
    git -C "$dir" commit -m "chore: release $TAG" -s
  fi
  if git -C "$dir" tag "$TAG" 2>/dev/null; then
    echo "  tagged $TAG"
  else
    echo "  $TAG already exists"
  fi
  git -C "$dir" push origin HEAD
  git -C "$dir" push origin "$TAG"
}

release_one envpact-cli npm
release_one envpact-mcp npm
release_one envpact-python pypi
release_one envpact-action npm
release_one envpact-vscode npm
release_one envpact-dashboard none   # auto-deploys on push to main

echo
echo "All releases pushed. Watch the workflows:"
for r in envpact-cli envpact-mcp envpact-python envpact-action envpact-vscode envpact-dashboard; do
  echo "  https://github.com/chirag127/$r/actions"
done
