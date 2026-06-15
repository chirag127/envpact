# Per-Environment Values

envpact's vault schema v2 supports per-environment values for any
project key. This lets you maintain a single `secrets.json` that
serves `development`, `staging`, and `production` — without
duplicating the project block.

## Two Forms

### Flat (single value)

```json
{
  "projects": {
    "my-app": {
      "OPENAI_API_KEY": "shared.OPENAI_API_KEY",
      "PORT": "3000"
    }
  }
}
```

### Per-environment

```json
{
  "projects": {
    "my-app": {
      "_default_env": "production",
      "OPENAI_API_KEY": "shared.OPENAI_API_KEY",
      "DATABASE_URL": {
        "development": "postgres://localhost/myapp_dev",
        "staging": "shared.DATABASE_URL_STAGING",
        "production": "shared.DATABASE_URL_PROD"
      }
    }
  }
}
```

You can mix both freely in the same project: `OPENAI_API_KEY` is
flat (same value everywhere), `DATABASE_URL` is per-environment.

## Selecting an Environment

| Component | Flag |
| :--- | :--- |
| CLI | `envpact --env production` |
| MCP `generate_env` | `{ "environment": "production" }` |
| Python | `pact.generate_env(environment="production")` |
| GitHub Action | `environment: production` input |
| VS Code | Quick Pick on every Generate command |
| Dashboard | Prompt on Download |

If no environment is passed, the resolver uses
`project._default_env` if set, else `'default'`.

## Fallback Rules

When you ask for environment `staging` and a key only has
`production` and `default`:

- The resolver returns the value of `default` (if present).
- If neither `staging` nor `default` exist, the key is reported
  as `unresolved`.

This makes it safe to introduce a new environment incrementally:
add a `default` value first, then specialise per env over time.

## Rotation Across Environments

```bash
# Rotate the production-only DB password without touching dev/staging:
envpact --add my-app DATABASE_URL=postgres://newhost/db --env production

# Rotate a shared secret used by multiple envs of multiple projects:
envpact --rotate DATABASE_URL_PROD
```

## Anti-Patterns

- **Don't put `dev` API keys in `shared`.** `shared` is for keys
  that are genuinely the same across many projects. Use a
  per-project `_default_env` block instead.
- **Don't hard-code `production` values inline.** Use
  `shared.` references so rotation is one-line.
- **Don't ship `default` as production.** `default` is a *fallback*,
  not a deployment environment. Set `_default_env: production`
  explicitly so the intent is obvious.
