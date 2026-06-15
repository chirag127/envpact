# envpact Security Model

## Threat Model

envpact's security claims are limited and explicit:

### What envpact protects against

- **Plaintext secrets in public repos.** `.env` is generated
  on-demand from a private vault, never committed.
- **Secret duplication.** Shared values live once; a leak forces
  a one-line rotation, not a 40-repo grep.
- **Accidental exposure in CI logs.** The Action masks every
  resolved value via `core.setSecret` before any other step runs.
- **Accidental exposure in editor screenshots.** All UIs (CLI's
  `--list-shared`, MCP `list_shared`, VS Code tree view, dashboard
  tables) show names only.

### What envpact does NOT protect against

- **A compromised GitHub account.** If your GitHub session is
  hijacked, the attacker has your vault. Mitigate with hardware
  key MFA (YubiKey, Titan, etc.) on your GitHub account.
- **A compromised dev machine.** The vault is cloned to
  `~/.envpact/secrets/` in plaintext (unless you opt into age
  encryption per secret). A user with shell access on your
  machine has the vault.
- **A malicious AI agent.** The MCP server gives any connected
  agent the ability to read & write the vault. Only run MCP
  servers you trust.
- **Side-channel attacks** (timing, shared cache, etc.).

## Hardening Checklist

| Action | Why |
| :--- | :--- |
| Hardware key MFA on GitHub | Vault security == GitHub account security |
| `gh auth login --insecure-storage=false` | Prevent local token theft |
| Fine-grained PAT for `envpact-action` (Contents:Read on the vault repo only) | Blast-radius limit |
| Different PAT for `--sync-github-secrets` (admin scope on the *consumer* repo only) | Separation of duties |
| Add `.env` to a global `.gitignore` (`git config --global core.excludesfile`) | Defense-in-depth against future projects |
| Opt into age encryption for high-value shared secrets (`envpact --encrypt KEY`) | Defense if the private repo ever leaks |
| Periodic rotation: every 90 days for production keys | Standard practice |

## Audit

Every change to `secrets.json` is a Git commit, signed off (`-s`)
by the component that made it (`envpact-cli`, `envpact-mcp`,
`envpact-vscode`, `envpact-python`, `envpact-dashboard`). The
GitHub UI shows full history at:

`https://github.com/<you>/envpact-secrets/commits/main/secrets.json`

This serves as a complete audit log: who rotated what, when,
from which client.

## Reporting Vulnerabilities

Email **whyiswhen@gmail.com**. Don't open public issues for
security findings.

For each component, the dedicated `SECURITY.md` (when present)
takes precedence over this document.
