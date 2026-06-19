# envpact Shared Specification

**This is the single source of truth for all envpact components.**
Every component MUST follow these rules exactly so the ecosystem
interoperates without drift.

> **v3 schema** — current as of 2026-06-19. Replaces v2 (which had
> per-environment objects and `_default_env` fields). v3 is **flat,
> single-environment, and timestamp-aware** for per-key conflict
> detection. v1/v2 vaults auto-upgrade on first read with a loud
> warning; see §1.4.

---

## 1. The Vault: `secrets.json`

A single JSON file in the user's private GitHub repo
`{username}/envpact-secrets`. Cloned locally to
`~/.envpact/secrets/`.

### 1.1 Schema (v3 — flat, single-environment)

```json
{
  "$schema": "https://envpact.oriz.in/schema/v3.json",
  "version": 3,
  "shared": {
    "OPENAI_API_KEY": {
      "value": "sk-…",
      "_modified_at": "2026-06-19T10:00:00.000Z"
    },
    "STRIPE_SECRET_KEY": {
      "value": "sk_live_…",
      "_modified_at": "2026-06-19T10:01:00.000Z"
    }
  },
  "projects": {
    "my-app": {
      "OPENAI_API_KEY": {
        "value": "shared.OPENAI_API_KEY",
        "_modified_at": "2026-06-19T10:00:00.000Z"
      },
      "PORT": {
        "value": "3000",
        "_modified_at": "2026-06-19T10:00:00.000Z"
      },
      "DATABASE_URL": {
        "value": "postgresql://localhost/myapp",
        "_modified_at": "2026-06-19T10:00:00.000Z"
      }
    }
  },
  "metadata": {
    "created_at": "2026-06-15T00:00:00Z",
    "updated_at": "2026-06-19T10:01:00.000Z",
    "owner": "chirag127"
  }
}
```

#### Entry shape

Every leaf in `shared.*` and `projects.<name>.*` is an **entry
object** with two fields:

- `value` (string, required) — the secret value, OR a
  `shared.KEY_NAME` reference, OR an `enc:<base64>` encrypted
  blob.
- `_modified_at` (ISO-8601 UTC timestamp, required) — when this
  entry's `value` last changed. Used for conflict detection on
  per-key pull/push (see §1.5).

There are NO nested per-environment objects. There is NO
`_default_env` field. The vault represents one environment per
project; users wanting multi-environment isolation use multiple
vaults or multiple project names (e.g. `my-app-prod` /
`my-app-dev`).

### 1.2 Resolution Algorithm

Given inputs `(secrets_json, project_name)`:

1. Look up `project = secrets_json.projects[project_name]`. If
   missing, return `{resolved: {}, missing: true}`.
2. For each `(key, entry)` in `project`:
   1. If `entry` is not an object with a string `value` field:
      mark INVALID and continue.
   2. Let `raw = entry.value`.
   3. If `raw` starts with `enc:`: pass through to `resolved[key]`
      with status `encrypted`. Caller decides whether to decrypt.
   4. If `raw` starts with `shared.`: look up
      `secrets_json.shared[raw.slice(7)]`.
      - If the shared key is missing: mark `key` as UNRESOLVED.
      - Else: take the shared entry's `value`. If THAT also
        starts with `shared.`: still mark INVALID (no recursion;
        one level only). If it starts with `enc:`: pass through
        as encrypted. Else: assign to `resolved[key]`.
   5. Else: assign `raw` to `resolved[key]`.
3. Return `{resolved: {…}, unresolved: [...], invalid: [...],
   encrypted: [...], missing: false}`.

### 1.3 Per-key sync semantics

**Pull** = read vault → write to local `.env`.
**Push** = read local `.env` → write to vault.

Both operations are **per-key** (one `KEY` at a time) but a
caller MAY iterate over the `.env.example` key list to do bulk
sync. Conflict detection runs per-key.

State sidecar: each consumer (cli/mcp/vscode) maintains a
`.env.example.lock` file in the project root capturing the last
successful sync state per key:

```json
{
  "version": 1,
  "keys": {
    "OPENAI_API_KEY": {
      "vault_modified_at": "2026-06-19T10:00:00.000Z",
      "synced_at": "2026-06-19T10:05:00.000Z"
    }
  }
}
```

`vault_modified_at` is the `_modified_at` value the consumer saw
when it last successfully synced. `synced_at` is wall-clock at
sync time (informational).

#### Pull semantics

Given `(project_name, key, force=false)`:

1. Pull vault repo (`git pull --ff-only`).
2. Read vault, resolve `entry = projects[project].keys[key]` (or
   `shared[key]` for shared pulls). If missing: error
   `KEY_NOT_IN_VAULT`.
3. Read `.env` for current local value (if any) and
   `.env.example.lock` for last-known `vault_modified_at`.
4. Conflict check (skipped when `force=true`):
   - Local `.env` value differs from the `value` last synced from
     vault (i.e. user edited `.env` since last pull/push) AND
     vault `_modified_at` is the same as `vault_modified_at` in
     the lock → return `LOCAL_NEWER`. Caller must re-run with
     `force=true`.
   - Local `.env` matches last-synced AND vault `_modified_at`
     differs → straight-forward pull, proceed.
   - Both diverged → return `BOTH_DIVERGED`. Always requires
     `force=true`.
5. Write the resolved value to `.env` (preserving comments/order
   per §5).
6. Update `.env.example.lock`'s entry for `key`:
   `vault_modified_at = entry._modified_at`,
   `synced_at = now()`.

#### Push semantics

Given `(project_name, key, force=false)`:

1. Pull vault repo.
2. Read `.env` for the new value. If `key` is missing from
   `.env`: error `KEY_NOT_IN_LOCAL`.
3. Read vault entry. If absent: this is a new-key push, proceed
   without conflict check (treat as `LOCAL_ONLY`).
4. Conflict check (skipped when `force=true`):
   - Vault `_modified_at` is newer than the lock's
     `vault_modified_at` → return `VAULT_NEWER`. Caller must
     re-run with `force=true`.
5. Write entry to vault: `value = local`, `_modified_at = now()`.
6. Update `metadata.updated_at`. Save vault, commit
   (`envpact: push <project>.<key>` + signoff), push.
7. Update `.env.example.lock`'s entry for `key`.

#### Status enumeration

A consumer surfacing per-key sync state classifies each key into
exactly one of:

- `synced` — `.env` value equals resolved vault value, and lock's
  `vault_modified_at` matches vault's `_modified_at`.
- `local_newer` — user edited `.env` since last sync; vault
  unchanged.
- `vault_newer` — vault `_modified_at` advanced since last sync;
  `.env` unchanged from lock baseline.
- `both_diverged` — both moved.
- `local_only` — present in `.env`, absent from vault.
- `vault_only` — present in vault, absent from `.env`.

### 1.4 Migration: v1/v2 → v3 (lossy auto-upgrade)

When a consumer reads a `secrets.json` with `version` 1 or 2:

1. Log a warning: `"envpact: upgrading vault from v<n> → v3.
   Per-environment values will be flattened. Backup at
   pre-v3-migration branch (if you didn't make one, abort now)."`
2. For each `shared` entry: wrap into `{value: <string>,
   _modified_at: metadata.updated_at || now()}`.
3. For each `project`:
   1. Drop the `_default_env` key (and any other key starting
      with `_`).
   2. For each remaining `(key, raw)`:
      - If `raw` is a string: wrap into `{value: raw,
        _modified_at: metadata.updated_at || now()}`.
      - If `raw` is an object: pick the first non-empty value in
        this priority order:
        1. `raw["default"]`
        2. `raw["production"]`
        3. The first string value in `Object.values(raw)`.
        Wrap that into `{value: <picked>, _modified_at: now()}`.
4. Set `version = 3`, `$schema = "https://envpact.oriz.in/schema/v3.json"`.
5. Re-commit only when the caller actually mutates the vault
   (don't rewrite the on-disk file just for reading — keep
   reads idempotent).

### 1.5 Encryption (opt-in)

Unchanged from v2. A string value of the form `enc:<base64>` is
treated as ciphertext, decrypted using `~/.envpact/age.key` at
resolution time when the consumer can. The `enc:` prefix is
inside `entry.value`, never on the entry object itself. CLI
remains the only port that decrypts; all others surface
encrypted entries with a clear message pointing at the CLI.

---

## 2. Local Configuration

| Path | Purpose |
| :--- | :--- |
| `~/.envpact/` | Root config directory |
| `~/.envpact/config.json` | Local config (see below) |
| `~/.envpact/secrets/` | Cloned vault repo (working tree) |
| `~/.envpact/secrets/secrets.json` | The vault file |
| `~/.envpact/age.key` | Optional age private key (mode 0600) |
| `<project>/.env` | Generated per-project secret file (gitignored) |
| `<project>/.env.example` | Required-key spec for the project |
| `<project>/.env.example.lock` | Per-key sync state — see §1.3 |

`HOME` resolution (Windows compatible):
`process.env.USERPROFILE || process.env.HOME || os.homedir()`

`config.json` schema (v2):
```json
{
  "version": 2,
  "vault_repo": "chirag127/envpact-secrets",
  "vault_url": "https://github.com/chirag127/envpact-secrets.git",
  "last_sync": "2026-06-19T10:05:00Z",
  "auth_method": "auto"
}
```

Note: the v1 `default_environment` field is dropped in v2 of the
config schema. Consumers reading a v1 config should silently
upgrade in memory.

---

## 3. Git Auth Detection (auto)

Unchanged. In order of preference:

1. **gh CLI**: if `gh auth status` exits 0, use
   `gh repo clone OWNER/REPO PATH` and `gh auth git-credential` for
   subsequent operations.
2. **SSH**: if `vault_url` is `git@github.com:...` or
   `~/.ssh/id_ed25519` exists, use `git clone git@github.com:...`.
3. **HTTPS PAT**: if `GITHUB_TOKEN` env var is set, use
   `https://oauth2:$GITHUB_TOKEN@github.com/...`.
4. **Fail with actionable error** listing all three options.

---

## 4. Project Auto-Detection

Unchanged.

```
1. Try `git config --get remote.origin.url` in cwd.
2. If output matches /[:/]([^/]+)\/([^/]+?)(?:\.git)?$/,
   project name = capture group 2.
3. Else fallback to path.basename(cwd).
4. Always lowercase the result.
```

---

## 5. .env File Generation Rules

- Output path: `.env` (configurable via `--output`).
- Format: `KEY=VALUE\n` per line, no quoting unless value contains
  whitespace, `\n`, `\r`, `=`, `#`, or starts with whitespace —
  then double-quote and JSON-escape backslashes/quotes/newlines.
- Preserve key order from `.env.example` (if present).
- Add header comment:
  `# Generated by envpact on <ISO timestamp>\n# DO NOT COMMIT — add .env to .gitignore\n`.
- Append `.env` to `.gitignore` if not already present.

The single environment is implicit. No multi-env header
metadata.

---

## 6. CLI Flags (CANONICAL — every CLI uses identical names)

```
envpact [options]

  --init [<git-url>|auto]    Initialize vault. "auto" creates a new
                              private repo via `gh repo create`.
  --vault-url <url>          Explicit vault git URL (overrides config).
  --vault-repo <slug>        Vault repo slug (e.g. user/envpact-secrets).
  --project <name>           Project override (else: git remote / cwd).
  --env-file <path>          .env.example path (default: .env.example).
  --output <path>            .env output path (default: .env).
  --pull <KEY>               Pull a single key from vault → .env.
                              Refuses if local is newer; use --force.
  --push <KEY>               Push a single key from .env → vault.
                              Refuses if vault is newer; use --force.
  --status                   Show per-key sync status (synced /
                              local_newer / vault_newer / both_diverged
                              / local_only / vault_only).
  --force                    Override conflict refusals on pull/push.
  -g, --github               Sync resolved secrets to GitHub Actions
                              via `gh secret set`.
  --dry-run                  Print resolved env, do not write.
  --rotate <key>             Rotate a shared secret interactively.
  --list                     List all projects in vault.
  --list-shared              List shared secret names (values masked).
  --add <KEY>=<VALUE>        Add/update a project secret.
  --add-shared <KEY>=<VAL>   Add/update a shared secret.
  --encrypt <KEY>            Encrypt a shared secret with age.
  --decrypt <KEY>            Decrypt a shared secret with age.
  --vault-pull               Pull latest vault git state.
  --vault-push               Push pending vault git changes.
  --no-pull                  Skip auto-pull this run.
  --no-push                  Skip auto-push this run.
  --from-stdin               Read --rotate / --push value from stdin.
  -q, --quiet                Suppress per-reference progress dump.
  -v, --version              Print version.
  -h, --help                 Show this help.
```

**Removed in v3:** `--env <name>` (no environments any more).

---

## 7. MCP Tools (CANONICAL)

1. `generate_env(project_name?, working_directory?, output_path?)` →
   writes .env, returns `{resolved_count, output_path, missing,
   unresolved, invalid}`.
2. `list_projects()` → `{projects: [{name, key_count}]}`.
3. `list_shared()` → `{shared: [{name, encrypted}]}` (values masked).
4. `add_secret(project_name, key, value)` → `{ok, modified_at}`.
5. `add_shared_secret(key, value)` → `{ok, modified_at}`.
6. `rotate_secret(key, new_value, sync_github?)` → `{key,
   references, pushed}`.
7. `sync_github(project_name?, repo_slug?)` → `{count, errors}`.
8. `pull_secret(project_name, key, force?)` → `{key,
   pulled_value_masked, status, modified_at}`. `force=true`
   overrides conflict refusal.
9. `push_secret(project_name, key, value, force?)` → `{key,
   status, modified_at}`. `force=true` overrides conflict refusal.
10. `sync_status(project_name)` → `{keys: [{name, status,
    vault_modified_at, lock_modified_at}]}`.

**Removed in v3:** `list_environments` (no environments any
more). The `environment` parameter is gone from every tool that
had it.

All tool descriptions and JSON schemas are in
`_build/specs/MCP_TOOLS.json`.

---

## 8. License & Author Metadata

- License: **MIT**
- Author: `Chirag Singhal <whyiswhen@gmail.com>`
- GitHub: `chirag127`
- Repository convention: `https://github.com/chirag127/envpact-{component}`
- Schema URL: `https://envpact.oriz.in/schema/v3.json`
- Dashboard URL: `https://envpact.oriz.in` (Cloudflare Pages, custom domain)
- Fallback Dashboard URL: `https://envpact-dashboard.pages.dev`

---

## 9. Versioning

- Current schema: **v3** (2026-06-19).
- Components ship semver; the schema version and the package
  version are independent. Components reading v3 may be at any
  package version ≥ the one that introduced v3 support.

---

## 10. Conventions Every Component Follows

- **Zero runtime dependencies** where possible (Node CLI: stdlib
  only; Python: stdlib only; MCP server may use
  `@modelcontextprotocol/sdk` + `zod` only).
- **Cross-platform paths**: always `path.join(...)` /
  `pathlib.Path(...)`.
- **Never log secret values**: not in errors, not in
  `--list-shared` (mask with `****`), not in MCP responses.
- **Validate schema before use**: reject `secrets.json` with
  unknown `version` field. v1/v2 auto-upgrade per §1.4.
- **Atomic writes**: write to `.tmp` then `rename()`.
- **All commits to vault are signed-off** (`-s`).
- **Test coverage target**: ≥80% line coverage for resolver,
  parser, vault, sync modules.

---

## 11. Files Every Repo MUST Include

- `README.md` — overview, install, usage, examples
- `LICENSE` — MIT, Copyright 2026 Chirag Singhal
- `AGENTS.md` — agent context per template below
- `CHANGELOG.md` — Keep a Changelog format
- `.gitignore` — language-appropriate
- `.github/workflows/ci.yml` — lint + test on PR/push
- `.github/workflows/publish.yml` — publish on tag push (where applicable)
- `CONTRIBUTING.md` — short guide

---

## 12. AGENTS.md Template

```markdown
# AGENTS.md — envpact-{component}

## Project Context
{component} of envpact — centralized, serverless secrets manager
for solo developers managing 100+ public GitHub repos.

## Architecture
- Vault: private GitHub repo with secrets.json (v3 schema, flat,
  one environment per project, per-key timestamps for conflict
  detection)
- Resolver: shared.KEY references, no nested per-env objects
- Local: ~/.envpact/secrets/ (cloned vault)

## Key Files
{component-specific list}

## Conventions
- Zero external runtime dependencies
- Cross-platform paths (path.join / pathlib)
- Atomic file writes
- Never log/print secret values
- ESM for new code, CommonJS only for legacy CLI

## Testing
- {framework} for tests
- Mock filesystem and Git operations
- Coverage target: ≥80% for resolver, parser, vault, sync

## Security
- NEVER log/print secret values
- Mask values in list-shared output
- Validate schema before use
- Handle Git auth failures gracefully
```
