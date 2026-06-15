# Vault Schema (v2)

The vault is a single `secrets.json` file in your private GitHub
repo. This document specifies the exact schema; the formal JSON
Schema is at https://envpact.oriz.in/schema/v2.json.

## Top-level

```ts
{
  "$schema": "https://envpact.oriz.in/schema/v2.json",
  "version": 2,
  "shared":   { [key: string]: string },
  "projects": { [project: string]: ProjectEntry },
  "metadata": { created_at: string, updated_at: string, owner?: string }
}
```

## ProjectEntry

```ts
{
  "_default_env"?: string,                          // optional metadata
  [key: string]: string | { [env: string]: string } // any number of secrets
}
```

- A **flat** value is a single string used in every environment.
- A **per-environment** value is an object whose keys are
  environment names (`development`, `staging`, `production`,
  `default`, or anything you choose).

Keys whose name starts with `_` are **metadata** and are not
exported to `.env`. Currently only `_default_env` is recognized;
unknown `_*` keys are ignored gracefully.

## Value forms

| Form | Example | Behaviour |
| :--- | :--- | :--- |
| Plain string | `"PORT": "3000"` | Used as-is. |
| Shared reference | `"OPENAI_API_KEY": "shared.OPENAI_API_KEY"` | Looked up in `shared`. One level only — no recursion. |
| Encrypted | `"DB_PASSWORD": "enc:base64(armored-age-ciphertext)"` | Decrypted on read using `~/.envpact/age.key`. |
| Per-environment | `"URL": { "dev": "...", "prod": "..." }` | Selects based on requested environment. |
| Mixed (per-env w/ shared) | `"URL": { "prod": "shared.URL_PROD" }` | Selected env value still subject to the `shared.` prefix rule. |

## Resolution Algorithm

See [SHARED_SPEC §1](../_build/specs/SHARED_SPEC.md). The exact
order:

1. Determine effective environment: argument override →
   `_default_env` → `'default'`.
2. For each project key:
   - String → resolve via the prefix rules.
   - Object → pick `[env]` or fall back to `[default]`, then
     resolve the picked value via the prefix rules.
   - Anything else → mark INVALID.
3. Return `{ resolved, unresolved, invalid, encrypted, environment }`.

## Validation

- `version` MUST be `1` or `2`. Other values are rejected.
- `shared` and `projects` MUST be objects (or absent).
- `shared` values MUST be strings.
- Project key names should match `[A-Za-z_][A-Za-z0-9_]*`
  (standard env var naming) — non-conforming names are written
  to `.env` but warn.

## Migration: v1 → v2

The v1 schema only had flat strings (no per-environment objects).
A v1 vault is automatically promoted to v2 on read — flat strings
work identically. You only opt into per-environment values by
*writing* an object value for a key.

## Examples

### Single project, single environment

```json
{
  "version": 2,
  "shared": {},
  "projects": {
    "blog": {
      "PUBLIC_SITE_URL": "https://blog.oriz.in",
      "PUBLIC_CF_BEACON": "abc123"
    }
  }
}
```

### Shared keys, two environments

```json
{
  "version": 2,
  "shared": {
    "OPENAI_API_KEY": "sk-…",
    "STRIPE_SECRET_KEY_LIVE": "sk_live_…",
    "STRIPE_SECRET_KEY_TEST": "sk_test_…"
  },
  "projects": {
    "saas-app": {
      "_default_env": "production",
      "OPENAI_API_KEY": "shared.OPENAI_API_KEY",
      "STRIPE_SECRET_KEY": {
        "development": "shared.STRIPE_SECRET_KEY_TEST",
        "production":  "shared.STRIPE_SECRET_KEY_LIVE"
      },
      "PORT": "3000"
    }
  }
}
```

### Encrypted values

```json
{
  "version": 2,
  "shared": {
    "DB_PASSWORD": "enc:YWdlLWVuY3J5cHRpb24ub3JnL3YxC..."
  },
  "projects": { "any-app": { "DB_PASSWORD": "shared.DB_PASSWORD" } }
}
```
