# envpact

> 📚 **Documentation:** [chirag127.github.io/envpact](https://chirag127.github.io/envpact/) · 🌐 **Live dashboard:** [envpact.oriz.in](https://envpact.oriz.in)

[![CLI on npm](https://img.shields.io/npm/v/envpact-cli?label=envpact-cli)](https://www.npmjs.com/package/envpact-cli)
[![MCP on npm](https://img.shields.io/npm/v/envpact-mcp?label=envpact-mcp)](https://www.npmjs.com/package/envpact-mcp)
[![PyPI](https://img.shields.io/pypi/v/envpact?label=envpact%20%28Python%29)](https://pypi.org/project/envpact/)
[![VS Code Marketplace](https://img.shields.io/visual-studio-marketplace/v/chirag127.envpact?label=VS%20Code)](https://marketplace.visualstudio.com/items?itemName=chirag127.envpact)
[![Open VSX](https://img.shields.io/open-vsx/v/chirag127/envpact?label=Open%20VSX)](https://open-vsx.org/extension/chirag127/envpact)
[![Smithery](https://smithery.ai/badge/envpact)](https://smithery.ai/server/envpact)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **A `$0`, serverless, Git-backed secrets manager for solo
> developers managing 100+ public GitHub repositories.**

`envpact` (env + pact) is a binding contract between you and your
secrets — a single private GitHub repo with a single
`secrets.json` becomes the source of truth for every project you
maintain. Reuse shared keys via a `shared.KEY` syntax. Rotate
once → every project gets the new value next run. AI agents
(Cursor, Windsurf, Claude Code, Cline) read it via MCP. CI/CD
reads it via the GitHub Action. You read it via CLI, VS Code, or
the web dashboard.

No SaaS subscription. No server to host. No project-count limit.

> **v0.2.0 (2026-06-18)** — Every package is published. The high-severity
> findings from the [v0.1.0 audit](./AUDIT.md) are resolved (private-vault
> assertion, command-injection hardening, MCP path-traversal containment,
> non-CLI ports refuse to leak `enc:` ciphertext). Two MAJOR items remain
> open and are deferred to v0.3.0: cross-port resolver parity tests
> (#7/#16) and vault-write file locking (#8). See AUDIT.md "Resolved in
> v0.2.0" for the full disposition.
>
> **Remote MCP is live** at https://mcp.envpact.oriz.in/mcp — Cloudflare
> Worker variant of envpact-mcp using Streamable HTTP transport. See
> [envpact-mcp/worker/README.md](./envpact-mcp/worker/README.md) for
> architecture and [envpact-mcp/SMITHERY.md](./envpact-mcp/SMITHERY.md)
> for the Smithery publish runbook.

---

## Why envpact?

Solo developers face a unique secrets management dilemma:

| Pain | envpact's answer |
| :--- | :--- |
| Public repos can't have plaintext `.env` | The vault is private; `.env` is generated locally and gitignored |
| Same `OPENAI_API_KEY` repeated across 40 projects | Reference once: `shared.OPENAI_API_KEY` |
| Manual rotation across dozens of repos | `envpact --rotate KEY` updates the source; everything else resolves on next run |
| Doppler costs $252/yr at 100 projects | envpact is free, forever |
| AI agents need real `.env` files on disk | The CLI + MCP write `.env` directly |

---

## Ecosystem

| Component | Repo | Install |
| :--- | :--- | :--- |
| **CLI** (Node) | [envpact-cli](./envpact-cli) | `npx envpact-cli` |
| **MCP server** | [envpact-mcp](./envpact-mcp) | Add `npx -y envpact-mcp` to your AI agent's MCP config, or [install via Smithery](https://smithery.ai/server/envpact), or use the remote variant at https://mcp.envpact.oriz.in/mcp |
| **Python module** | [envpact-python](./envpact-python) | `pip install envpact` |
| **GitHub Action** | [envpact-action](./envpact-action) | `chirag127/envpact-action@v0` |
| **VS Code extension** | [envpact-vscode](./envpact-vscode) | `ext install chirag127.envpact` (also on [Open VSX](https://open-vsx.org/extension/chirag127/envpact)) |
| **Web dashboard** | [envpact-dashboard](./envpact-dashboard) | https://envpact.oriz.in |

Every component reads & writes the **same vault**
(`~/.envpact/secrets/secrets.json`) using the **same resolution
algorithm** (see [SHARED_SPEC](./_build/specs/SHARED_SPEC.md)).
Switching between them is seamless.

---

## Quick Start

```bash
# 1. Bootstrap your private vault (creates {you}/envpact-secrets via gh CLI)
npx envpact-cli --init auto

# 2. In any project with a .env.example
cd my-app
npx envpact-cli
# → resolves shared refs, prompts for any missing values, writes .env

# 3. Sync to GitHub Actions secrets for CI/CD
npx envpact-cli --github

# 4. (Optional) Configure an AI agent — Cursor, Claude Desktop, etc.
# Add this to your agent's MCP config:
{
  "mcpServers": {
    "envpact": {
      "command": "npx",
      "args": ["-y", "envpact-mcp"]
    }
  }
}
```

---

## Architecture

```
                  Your machine                          GitHub.com
                  ─────────────────                     ─────────────────────────
                  ~/.envpact/secrets/   ←——— git ———→   {user}/envpact-secrets (PRIVATE)
                          ↕                                ├── secrets.json
                          ↕                                │   ├── shared: { OPENAI_API_KEY, … }
        ┌─────────────────┼──────────────────────┐         │   └── projects: { my-app: { … } }
        ↓                 ↓                      ↓
    envpact-cli      envpact-mcp        envpact (Python)
        ↓             (stdio)                ↓
   .env (local) ←——— AI agents          Python scripts
                  (Cursor, Claude,
                   Windsurf, Cline)

    envpact-action ─────→ resolves at CI time, writes .env, syncs gh secrets
    envpact-vscode ─────→ visual UI inside VS Code
    envpact-dashboard ──→ static site at envpact.oriz.in (GitHub OAuth)
```

---

## Vault Schema (v2)

```json
{
  "$schema": "https://envpact.oriz.in/schema/v2.json",
  "version": 2,
  "shared": {
    "OPENAI_API_KEY": "sk-…",
    "DATABASE_URL_PROD": "postgresql://…"
  },
  "projects": {
    "my-app": {
      "_default_env": "production",
      "OPENAI_API_KEY": "shared.OPENAI_API_KEY",
      "PORT": "3000",
      "DATABASE_URL": {
        "development": "postgres://localhost/myapp_dev",
        "production": "shared.DATABASE_URL_PROD"
      }
    }
  }
}
```

- A string starting with `shared.` is looked up in the `shared` block.
- A nested object selects per-environment values.
- Encrypted values (prefix `enc:`) are decrypted on read using
  your local age key — opt-in.

Full canonical algorithm: [SHARED_SPEC §1](./_build/specs/SHARED_SPEC.md).

---

## Security Model

The trust model is **"keep the vault repo private"**. Everything
else builds on that:

- The vault repo MUST be private. envpact only deduplicates and
  enables rotation; the trust root is GitHub.
- `.env` files are written with mode 0600 and added to
  `.gitignore` automatically.
- Secret values are NEVER printed in `--list-shared`, MCP tool
  responses, VS Code tree views, or dashboard tables.
- Encryption (`age`) is opt-in per secret for defense-in-depth.
- All vault commits are signed-off (`-s`).
- The dashboard is 100% client-side; tokens stay in `sessionStorage`.

See [docs/security.md](./docs/security.md) for the full model.

---

## Known limitations (v0.2.0)

The [v0.1.0 audit](./AUDIT.md) closed the seven highest-severity
items in v0.2.0. Two MAJOR items remain open and are tracked
against the **v0.3.0 milestone**:

- **No cross-port resolver parity tests yet** (AUDIT #7 / #16).
  Each of the 6 resolver ports has its own test suite, but a
  shared canonical fixture set and per-port runner doesn't exist
  yet — the most likely source of production drift bugs.
- **Vault writes have no file locking** (AUDIT #8). Concurrent
  writes from CLI + MCP + dashboard can lose data without retry.
  Avoid running multiple writers at the same time until v0.3.0.

See [AUDIT.md "Resolved in v0.2.0"](./AUDIT.md#resolved-in-v020-2026-06-16)
for the full disposition table.

---

## Comparison

| | envpact | dotenvx | Doppler | Infisical | 1Password |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Cost (100 projects) | **$0** | $0 | $252/yr | $216/yr | $36/yr |
| Centralized | ✓ | ✗ | ✓ | ✓ | ✓ |
| DRY references | ✓ | ✗ | ✓ | ✓ | ✗ |
| Local `.env` gen | ✓ | ✓ | ✓ | ✓ | ✓ |
| GitHub sync | ✓ | ✗ | ✓ | ✓ | ✗ |
| MCP server | ✓ | ✗ | ✗ | ✗ | ✗ |
| Python module | ✓ | ✗ | ✗ | ✓ | ✗ |
| VS Code extension | ✓ | ✗ | ✗ | ✗ | ✓ |
| Zero runtime deps | ✓ | ✓ | ✗ | ✗ | ✗ |
| Self-hosted | Git | Git | Cloud | Cloud/VPS | Cloud |
| AI-agent ready | ✓ | ✗ | ✗ | ✗ | ✗ |

---

## Documentation

- [SHARED_SPEC](./_build/specs/SHARED_SPEC.md) — canonical
  resolution algorithm and vault schema.
- [docs/architecture.md](./docs/architecture.md) — how the
  components fit together.
- [docs/security.md](./docs/security.md) — threat model.
- [docs/environments.md](./docs/environments.md) — using
  per-environment values.
- [docs/schema.md](./docs/schema.md) — full schema reference.
- [TOKENS.md](./TOKENS.md) — step-by-step guide to acquiring
  every API token / PAT the ecosystem uses.
- [AUDIT.md](./AUDIT.md) — multi-agent v0.1.0 audit findings.
- [scripts/setup-secrets.sh](./scripts/setup-secrets.sh) —
  interactive script to set CI/CD secrets across all 6 repos.
- [scripts/release-all.sh](./scripts/release-all.sh) — tag a
  version across all components.

---

## Contributing

Each sub-component has its own `CONTRIBUTING.md`. The umbrella
repo only tracks submodule pointers.

To work on multiple components at once:

```bash
git clone --recursive https://github.com/chirag127/envpact.git
cd envpact
git submodule update --recursive --remote
```

---

## License

MIT © Chirag Singhal — see [LICENSE](./LICENSE).
