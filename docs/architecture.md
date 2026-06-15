# envpact Architecture

This document explains how the 6 components fit together. For
the canonical resolution algorithm, see [SHARED_SPEC](../_build/specs/SHARED_SPEC.md).

## Trust Boundary

The single most important security property: **the vault repo
MUST be private**. Everything else is built on this. envpact does
NOT add cryptographic protection over the GitHub repo's existing
ACL by default — encryption is opt-in for defense-in-depth.

## Components and Roles

```
                          [ envpact-secrets repo (PRIVATE) ]
                                   │
                            secrets.json (v2)
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
   read+write                  read+write                  read-only
        │                          │                          │
   [envpact-cli]              [envpact-mcp]              [envpact-action]
   [envpact-python]           [envpact-vscode]           (CI/CD; no clone)
        │                          │                          │
        ▼                          ▼                          ▼
     .env                  AI agent tools                  CI .env
   (gitignored)         (Cursor/Claude/Cline)         (job-scoped, masked)
```

## Where State Lives

| State | Location | Mutated by |
| :--- | :--- | :--- |
| `secrets.json` | `~/.envpact/secrets/` (clone of private repo) | CLI, MCP, VS Code, Python |
| `~/.envpact/config.json` | local config | CLI |
| `~/.envpact/age.key` | local age key (mode 0600) | CLI (`--encrypt`) |
| `.env` (per project) | project working tree | All read-side components |
| GitHub Actions secrets (per project) | GitHub | CLI (`--github`), Action (sync mode) |

## Resolution Flow

1. Caller picks `(project_name, environment)`. Auto-detected from
   git remote when omitted.
2. Vault is loaded (the local clone — the CLI auto-pulls before
   reads).
3. Each project key:
   - Flat string starting with `shared.` → look up in `shared`.
   - Object with environment keys → pick `[env]` or fall back to
     `[default]`.
   - String starting with `enc:` → decrypt via local age key.
4. Resolved values are written atomically to `.env` (mode 0600).
5. New keys discovered during prompting are written back to the
   vault and committed (signed-off, auto-pushed).

## Why Submodules in the Umbrella Repo?

Each component is independently versioned, has its own CI/CD,
its own README, its own publishing pipeline. The umbrella exists
to:

- Cross-link the docs.
- Provide the canonical SHARED_SPEC.
- Host the cross-cutting tooling (`scripts/setup-secrets.sh`,
  `scripts/release-all.sh`).

A monorepo with workspaces would couple the release cadence — we
don't want that. Submodules let each component evolve at its own
pace.

## Why Not …?

- **Why not encrypt by default?** Two reasons. (1) Many users
  prefer the "private repo" model alone — it's already strong if
  you have hardware-key MFA on GitHub. (2) Encryption introduces
  key-distribution complexity that solo devs don't always need.
  We give users opt-in via `enc:` prefixes.
- **Why not sealed boxes for GitHub Actions?** The CLI/Action
  shells out to `gh secret set`, which handles the libsodium
  sealed-box encryption transparently. Embedding sodium would add
  binary build complexity for one operation.
- **Why not gRPC / a tiny server?** $0 / no infrastructure was a
  hard requirement. Git is the protocol.
