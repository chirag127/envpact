---
title: envpact — centralized secrets manager for AI agents
description: Manage your private secrets vault from VS Code, the CLI, an MCP server, a GitHub Action, and a browser dashboard. Your vault is your own private GitHub repo; envpact never sees your tokens.
---

# envpact

> **Centralized secrets manager for AI coding agents.** Your secrets live in
> *your own private GitHub repo* (`<your-username>/envpact-secrets`); envpact
> reads them into project-scoped `.env` files, syncs them to AI agents over MCP,
> and rotates them across every project at once. No third-party server, no
> plaintext secrets in public repos, one source of truth.

[Live dashboard →](https://envpact.oriz.in){: .btn .btn-primary} &nbsp;
[GitHub →](https://github.com/chirag127/envpact){: .btn}

---

## What problem this solves

A solo developer maintaining 40 public repos has the same `OPENAI_API_KEY` in
40 `.env.example` files, 40 places to update on rotation, and a constant low-grade
fear that one of them slipped into a commit. envpact lets you keep every secret
in one private repo, reference it from every project by name (`shared.OPENAI_API_KEY`),
and rotate it once.

| Without envpact | With envpact |
| :--- | :--- |
| 40 copies of `OPENAI_API_KEY` across 40 repos | One `shared.OPENAI_API_KEY` in your private vault |
| Manually update 40 `.env` files on rotation | Update once; all 40 pick it up next run |
| `.env.example` lies about which keys you need | `envpact-cli` generates a real `.env` from the vault |
| AI agents need the keys you typed somewhere | MCP server hands keys to Claude/Cursor/Cline directly |

---

## How auth works (the part you actually care about)

> **Your vault is yours. Nobody but you can read it.**

When you run any envpact tool for the first time, this is what happens:

1. The tool reads your existing GitHub authentication via `gh auth token` (the
   one you already have for GitHub CLI). If you're not logged in, it asks you
   to run `gh auth login`. **Nothing else.**
2. It calls `gh api user` to learn your username, then creates (or opens)
   `<your-username>/envpact-secrets` — a **private** repo in **your** account.
3. Every read and write of secrets happens directly between your computer and
   GitHub's API, signed with **your** token. No envpact server is involved.
4. The browser dashboard (`envpact.oriz.in`) is the same: it stores its OAuth
   token in your tab's `sessionStorage` only and talks to `api.github.com`
   directly. Cloudflare Pages serves the static HTML; the only Cloudflare
   Functions in the loop are two thin proxies (`/api/auth/device`,
   `/api/auth/token`) that forward GitHub's OAuth device-flow start/poll calls
   server-side because GitHub doesn't send CORS headers for those endpoints.

**There is no envpact account.** There is no envpact-side database. If the
dashboard at envpact.oriz.in went offline tomorrow, the CLI, MCP server, VS
Code extension, and GitHub Action would all keep working — they don't depend
on it.

For the threat model in detail, see [Security model](./security.html).

---

## Components

envpact is a family of small tools that share one schema and one vault:

| Component | What it is | Install |
| :--- | :--- | :--- |
| [**`envpact-cli`**](https://github.com/chirag127/envpact-cli) | Terminal CLI: init vault, generate `.env`, rotate, sync. The reference implementation. | `npx -y envpact-cli` |
| [**`envpact-mcp`**](https://github.com/chirag127/envpact-mcp) | MCP server. Add to Claude Desktop / Code / Cursor / Windsurf / Cline / Goose. 8 tools. | `npx -y envpact-mcp` |
| [**`envpact-action`**](https://github.com/chirag127/envpact-action) | GitHub Action. Pull secrets from your vault into the runner's environment for CI. | `uses: chirag127/envpact-action@v1` |
| [**`envpact-vscode`**](https://github.com/chirag127/envpact-vscode) | VS Code extension. Sidebar, codelens on `.env.example`, auto-sync on save. | [Marketplace](https://marketplace.visualstudio.com/items?itemName=chirag127.envpact) |
| [**`envpact-dashboard`**](https://github.com/chirag127/envpact-dashboard) | Browser dashboard at envpact.oriz.in. Visual vault management; pure GitHub-API client. | [envpact.oriz.in](https://envpact.oriz.in) |
| [**`envpact-python`**](https://github.com/chirag127/envpact-python) | Python module. Same resolver, for Python projects. | `pip install envpact` |
| [**`envpact-registry-publisher`**](https://github.com/chirag127/envpact-registry-publisher) | Tool: programmatic submission of MCP servers to public registries. | `npx envpact-registry-publish` |

Pick whichever surface fits your workflow. They all read the same vault format.

---

## Quick start

```bash
# 1. Authenticate with GitHub (if you haven't already).
gh auth login

# 2. Initialize your vault. Creates <you>/envpact-secrets (private).
npx -y envpact-cli --init

# 3. Add a secret.
npx -y envpact-cli add-shared OPENAI_API_KEY sk-...

# 4. In any project, generate .env from your vault.
cd ~/my-project
npx -y envpact-cli   # reads .env.example, writes .env

# 5. Or wire it to your AI agent over MCP. Add to claude_desktop_config.json:
#    {
#      "mcpServers": {
#        "envpact": { "command": "npx", "args": ["-y", "envpact-mcp"] }
#      }
#    }
```

Full walkthrough: see [Architecture](./architecture.html).

---

## Project documentation

- **[Architecture](./architecture.html)** — How the 7 components fit together, schema v3, the resolver pipeline.
- **[Schema](./schema.html)** — The vault file format, in full.
- **[Environments](./environments.html)** — How `.env`, `.env.production`, `.env.local` map to vault environments.
- **[Security model](./security.html)** — Threat model, what's in scope, what isn't.

Each component repo also has a `docs/` folder with its own deep-dive.

---

## Status

- ✅ envpact-cli — v0.2.0, on npm
- ✅ envpact-mcp — v0.2.0, on npm
- ✅ envpact-action — v0.2.0, on GitHub Marketplace
- ✅ envpact-vscode — v0.4.0, on VS Code Marketplace + Open VSX
- ✅ envpact-dashboard — v0.4.0, live at [envpact.oriz.in](https://envpact.oriz.in)
- ✅ envpact-python — v0.2.0, on PyPI
- ✅ envpact-registry-publisher — v0.1.2, on GitHub

---

## License

MIT, all components. See each repo for its `LICENSE` file.

## Maintained by

[Chirag Singhal](https://github.com/chirag127). Bug reports and PRs welcome on
any component repo.
