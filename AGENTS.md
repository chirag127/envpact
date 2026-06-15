# AGENTS.md — envpact (umbrella)

## Project Context

This is the umbrella repo of the envpact ecosystem. It contains:

- 6 sub-repositories as **git submodules**.
- Cross-component documentation in `docs/`.
- Canonical specifications in `_build/specs/`.
- Release tooling in `scripts/`.

## Sub-components

| Component | Path | Language | Registry |
| :--- | :--- | :--- | :--- |
| envpact-cli | `envpact-cli/` | Node CommonJS | npm |
| envpact-mcp | `envpact-mcp/` | Node ESM | npm |
| envpact-python | `envpact-python/` | Python 3.10+ | PyPI |
| envpact-action | `envpact-action/` | Node 20 | GitHub Marketplace |
| envpact-vscode | `envpact-vscode/` | TypeScript | VS Code Marketplace + Open VSX |
| envpact-dashboard | `envpact-dashboard/` | Astro static | Cloudflare Pages |

## Working on Sub-components

```bash
# Inside the umbrella, jump into a sub-repo:
cd envpact-cli
# ...changes go here, this is its own git repo with origin
# pointing at chirag127/envpact-cli...
```

The umbrella repo is NOT a workspace. Each sub-component has its
own `package.json`/`pyproject.toml` and its own dependencies.

## Spec Source of Truth

`_build/specs/SHARED_SPEC.md` is the canonical spec for the
resolver and vault schema. Every component implements the same
algorithm; deviation requires updating the spec first and then
porting across all components.

## Release Process

```bash
./scripts/setup-secrets.sh         # one-time: paste tokens, gh secret set
./scripts/release-all.sh 0.1.0     # tag every component v0.1.0
```

Each tag triggers that component's publish workflow:
- npm packages → `npm publish --provenance --access public`
- PyPI → OIDC trusted publisher
- VS Code → `vsce publish` (+ optional `ovsx publish`)
- Cloudflare Pages → wrangler deploy on every push to main

## Submodule Updates

```bash
git submodule update --recursive --remote
git add <changed-submodule>
git commit -m "chore: bump <component> to <sha>"
```

Only do this when the umbrella's submodule pointers fall behind
the components' main branches by more than ~10 commits, or when
preparing a coordinated release.
