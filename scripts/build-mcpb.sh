#!/usr/bin/env bash
#
# scripts/build-mcpb.sh — build the envpact-mcp .mcpb bundle and
# mirror it to the umbrella's dist/ for convenience.
#
# Usage:
#   bash scripts/build-mcpb.sh
#
# Output:
#   ./dist/envpact-mcp.mcpb              (umbrella mirror)
#   ./_build/repos/envpact-mcp/dist/envpact-mcp.mcpb   (canonical)
#
# After this runs, you can publish from the umbrella root:
#   npx -y @smithery/cli mcp publish ./dist/envpact-mcp.mcpb -n chirag127/envpact-mcp

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPONENT="$ROOT/_build/repos/envpact-mcp"

# Locate node + gh on Windows-PATH for child processes.
if [ -d "C:/Users/C5420321/AppData/Local/Microsoft/WinGet/Packages/OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe" ]; then
  NODE_DIR="C:\\Users\\C5420321\\AppData\\Local\\Microsoft\\WinGet\\Packages\\OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe\\node-v24.16.0-win-x64"
  export PATH="$NODE_DIR;$PATH"
fi

if [ ! -d "$COMPONENT" ]; then
  echo "error: envpact-mcp component not found at $COMPONENT" >&2
  echo "       run \`git submodule update --init --recursive\` first?" >&2
  exit 1
fi

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
dim() { printf "\033[2m%s\033[0m\n" "$1"; }

bold "==> Building envpact-mcp.mcpb"
echo

# Ensure devDeps for the build (esbuild + @anthropic-ai/mcpb).
# `npm ci --ignore-scripts` keeps the install fast and avoids any
# postinstall scripts on Windows that flake under OneDrive.
if [ ! -d "$COMPONENT/node_modules/@anthropic-ai/mcpb" ] || [ ! -d "$COMPONENT/node_modules/esbuild" ]; then
  bold "→ installing build deps (esbuild + @anthropic-ai/mcpb)"
  ( cd "$COMPONENT" && npm ci --no-audit --no-fund --ignore-scripts )
fi

# Run the canonical build.
( cd "$COMPONENT" && node scripts/build-mcpb.js )

SRC="$COMPONENT/dist/envpact-mcp.mcpb"
if [ ! -f "$SRC" ]; then
  echo "error: build did not produce $SRC" >&2
  exit 1
fi

# Mirror to umbrella dist/.
mkdir -p "$ROOT/dist"
cp "$SRC" "$ROOT/dist/envpact-mcp.mcpb"

echo
green "✓ ./dist/envpact-mcp.mcpb (umbrella)"
green "✓ ./_build/repos/envpact-mcp/dist/envpact-mcp.mcpb (canonical)"
echo
dim "Next: publish to Smithery (interactive OAuth)"
dim "  npx -y @smithery/cli mcp publish ./dist/envpact-mcp.mcpb -n chirag127/envpact-mcp"
dim "or attach automatically by tagging:"
dim "  ./scripts/release-all.sh 0.2.1"
