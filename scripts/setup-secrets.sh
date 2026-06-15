#!/usr/bin/env bash
# envpact — interactive secret setup
#
# Prompts for each token / API key and runs `gh secret set` against
# the right repos. Run this AFTER you've created the tokens per
# TOKENS.md.
#
# Usage:
#   ./scripts/setup-secrets.sh
#
# Requirements:
#   - gh CLI authenticated (gh auth status)
#   - All 6 sub-repos already created under chirag127/

set -uo pipefail

REPOS_NPM=("envpact-cli" "envpact-mcp")
REPO_VSCODE="envpact-vscode"
REPO_DASHBOARD="envpact-dashboard"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m%s\033[0m\n" "$1"; }
red() { printf "\033[31m%s\033[0m\n" "$1"; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    red "Missing required tool: $1"
    exit 1
  fi
}

require gh

if ! gh auth status >/dev/null 2>&1; then
  red "gh CLI is not authenticated."
  red "Run: gh auth login"
  exit 1
fi

bold "==> envpact secret setup <=="
echo
echo "This script sets the following secrets across the 6 envpact repos:"
echo "  • NPM_TOKEN                       → envpact-cli, envpact-mcp"
echo "  • VSCE_PAT                        → envpact-vscode"
echo "  • OVSX_PAT (optional)             → envpact-vscode"
echo "  • CLOUDFLARE_API_TOKEN            → envpact-dashboard"
echo "  • CLOUDFLARE_ACCOUNT_ID           → envpact-dashboard"
echo "  • PUBLIC_GITHUB_OAUTH_CLIENT_ID   → envpact-dashboard"
echo
echo "Press Enter to skip any token you don't want to set right now."
echo

read_secret() {
  local prompt="$1"
  local var
  echo -n "$prompt: " >&2
  stty -echo
  read -r var
  stty echo
  echo "" >&2
  printf '%s' "$var"
}

# 1. NPM_TOKEN
echo
bold "[1/5] NPM_TOKEN"
echo "Generate at https://www.npmjs.com/settings/<your-user>/tokens"
NPM_TOKEN=$(read_secret "  Paste NPM_TOKEN")
if [ -n "$NPM_TOKEN" ]; then
  for repo in "${REPOS_NPM[@]}"; do
    if echo "$NPM_TOKEN" | gh secret set NPM_TOKEN --repo "chirag127/$repo" >/dev/null 2>&1; then
      green "  ✓ chirag127/$repo: NPM_TOKEN set"
    else
      red "  ✗ chirag127/$repo: failed"
    fi
  done
else
  yellow "  skipped"
fi

# 2. VSCE_PAT
echo
bold "[2/5] VSCE_PAT"
echo "Generate at https://dev.azure.com/<your-org>/_usersSettings/tokens"
VSCE_PAT=$(read_secret "  Paste VSCE_PAT")
if [ -n "$VSCE_PAT" ]; then
  if echo "$VSCE_PAT" | gh secret set VSCE_PAT --repo "chirag127/$REPO_VSCODE" >/dev/null 2>&1; then
    green "  ✓ chirag127/$REPO_VSCODE: VSCE_PAT set"
  else
    red "  ✗ failed"
  fi
else
  yellow "  skipped"
fi

# 3. OVSX_PAT (optional)
echo
bold "[3/5] OVSX_PAT (optional, for Open VSX mirror)"
echo "Generate at https://open-vsx.org/user-settings/tokens"
OVSX_PAT=$(read_secret "  Paste OVSX_PAT (or press Enter to skip)")
if [ -n "$OVSX_PAT" ]; then
  if echo "$OVSX_PAT" | gh secret set OVSX_PAT --repo "chirag127/$REPO_VSCODE" >/dev/null 2>&1; then
    green "  ✓ OVSX_PAT set"
  else
    red "  ✗ failed"
  fi
else
  yellow "  skipped"
fi

# 4. Cloudflare credentials
echo
bold "[4/5] Cloudflare credentials"
echo "Account ID: https://dash.cloudflare.com/ (right side of dashboard)"
echo "API token:  https://dash.cloudflare.com/profile/api-tokens"
CLOUDFLARE_ACCOUNT_ID=$(read_secret "  Paste CLOUDFLARE_ACCOUNT_ID")
CLOUDFLARE_API_TOKEN=$(read_secret "  Paste CLOUDFLARE_API_TOKEN")
if [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
  echo "$CLOUDFLARE_ACCOUNT_ID" | gh secret set CLOUDFLARE_ACCOUNT_ID --repo "chirag127/$REPO_DASHBOARD" >/dev/null 2>&1 \
    && green "  ✓ CLOUDFLARE_ACCOUNT_ID set" \
    || red "  ✗ failed"
fi
if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
  echo "$CLOUDFLARE_API_TOKEN" | gh secret set CLOUDFLARE_API_TOKEN --repo "chirag127/$REPO_DASHBOARD" >/dev/null 2>&1 \
    && green "  ✓ CLOUDFLARE_API_TOKEN set" \
    || red "  ✗ failed"
fi

# 5. GitHub OAuth Client ID for dashboard
echo
bold "[5/5] GitHub OAuth Client ID for dashboard"
echo "Create at https://github.com/settings/developers (enable Device Flow!)"
GH_OAUTH_ID=$(read_secret "  Paste PUBLIC_GITHUB_OAUTH_CLIENT_ID")
if [ -n "$GH_OAUTH_ID" ]; then
  echo "$GH_OAUTH_ID" | gh secret set PUBLIC_GITHUB_OAUTH_CLIENT_ID --repo "chirag127/$REPO_DASHBOARD" >/dev/null 2>&1 \
    && green "  ✓ PUBLIC_GITHUB_OAUTH_CLIENT_ID set" \
    || red "  ✗ failed"
fi

echo
bold "==> Done <=="
echo
echo "Verify each repo:"
for repo in envpact-cli envpact-mcp envpact-python envpact-action envpact-vscode envpact-dashboard; do
  echo "  gh secret list --repo chirag127/$repo"
done
echo
echo "Note: PyPI publishing for envpact-python uses Trusted Publisher (OIDC)."
echo "Configure it once at https://pypi.org/manage/project/envpact/settings/publishing/"
echo "after the first manual upload — see TOKENS.md §2."
echo
echo "When all secrets are set, release v0.1.0 with:"
echo "  ./scripts/release-all.sh 0.1.0"
