#!/usr/bin/env bash
#
# envpact — interactive token rotator
#
# Run this in your OWN terminal where readline TTY actually works.
# For each token, you'll see a masked-input prompt; paste the value
# and press Enter. The value is piped DIRECTLY into the CLI's
# --from-stdin path — never appears in cmdline args, never echoes
# to the screen, never lands in your shell history.
#
# Usage:
#   bash scripts/rotate-tokens.sh                 # all 7 tokens
#   bash scripts/rotate-tokens.sh NPM_TOKEN ...   # subset
#
# Recovery aid for the 2026-06-16 incident where placeholders
# were written over the user's real .env tokens.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/_build/repos/envpact-cli/bin/envpact.js"

# Locate node and gh on Windows-PATH for child processes.
NODE_DIR="C:\\Users\\C5420321\\AppData\\Local\\Microsoft\\WinGet\\Packages\\OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe\\node-v24.16.0-win-x64"
GH_DIR="C:\\Users\\C5420321\\AppData\\Local\\Microsoft\\WinGet\\Packages\\GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe\\bin"
export PATH="$NODE_DIR;$GH_DIR;$PATH"

if [ ! -f "$CLI" ]; then
  echo "error: envpact-cli not found at $CLI" >&2
  exit 1
fi

# Default set: every shared secret the umbrella declares.
DEFAULT_TOKENS=(
  NPM_TOKEN
  VSCE_PAT
  OVSX_PAT
  CLOUDFLARE_API_TOKEN
  CLOUDFLARE_ACCOUNT_ID
  PUBLIC_GITHUB_OAUTH_CLIENT_ID
  GITHUB_TOKEN
)

if [ "$#" -gt 0 ]; then
  TOKENS=("$@")
else
  TOKENS=("${DEFAULT_TOKENS[@]}")
fi

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
dim() { printf "\033[2m%s\033[0m\n" "$1"; }

bold "envpact token rotator — ${#TOKENS[@]} secret(s) to rotate"
dim "Press Enter on an empty value to SKIP a token."
echo

for token in "${TOKENS[@]}"; do
  bold "→ shared.$token"
  # Read the value from stdin with terminal echo OFF.
  # `read -s` is silent (no echo). The value lives only in $value
  # for the duration of the loop iteration.
  printf "  paste value (input hidden, Enter to skip): "
  IFS= read -rs value
  echo

  if [ -z "$value" ]; then
    dim "  skipped"
    echo
    continue
  fi

  # Pipe the value into the CLI's --from-stdin path. The value
  # never appears as a process argument (no /proc/PID/cmdline
  # exposure on Linux/macOS, no Windows ETW exposure).
  if printf '%s' "$value" | node "$CLI" --rotate "$token" --from-stdin --quiet >/dev/null; then
    green "  ✓ rotated and pushed to chirag127/envpact-secrets"
  else
    echo "  ✗ rotation failed for $token" >&2
  fi
  unset value
  echo
done

bold "Verifying vault state"
node "$CLI" --list-shared
echo
dim "Done. Run 'cd $ROOT && cat .env' to see the regenerated env."
