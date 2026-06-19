# Tooling

## Package manager: pnpm 10.18.0

Every Node-based component in this monorepo uses **pnpm** (pinned
to `10.18.0` via `packageManager` in each `package.json`). Locking
to a specific version means dev machines and CI runners install
the same content-addressable layout — no surprise hoisting
differences between `npm` and `pnpm`, no "works for me" failures
from stale lockfiles.

### Why 10.18 specifically

pnpm 11+ requires Node >=22.13 (it depends on `node:sqlite`, a
Node 22 built-in). Several CI matrices include Node 18 and 20 to
catch backwards-compat regressions; pnpm 11 crashes at startup on
those runners with `ERR_UNKNOWN_BUILTIN_MODULE`. pnpm 10.18 is the
latest 10.x: it supports Node ≥18.12 AND has the v10 settings
schema (`allowBuilds` lives in `pnpm-workspace.yaml`).

### Why pnpm

- **Content-addressable store.** Identical packages across all 5
  repos in `_build/repos/` share one on-disk copy. Across-repo
  installs are I/O-bound, not bandwidth-bound.
- **Strict by default.** Transitive deps are not implicitly
  hoisted into the top-level `node_modules`. We caught and fixed
  one bug (`fflate` was a transitive of `@anthropic-ai/mcpb`,
  silently available under npm; pnpm refused, we promoted it to
  a direct devDep).
- **`packageManager` field.** Corepack reads it on every command,
  so `pnpm` always resolves to the pinned version regardless of
  what's globally installed.

### Bootstrap

pnpm comes with Node via Corepack. From any component dir:

```bash
# One-time, on each new dev machine:
corepack enable

# Then everywhere:
pnpm install --frozen-lockfile  # like `npm ci`
pnpm test
pnpm run build
```

### `pnpm-workspace.yaml`

Each component carries its own `pnpm-workspace.yaml` with an
`allowBuilds` block. pnpm v11 refuses to run a transitive dep's
install/postinstall script unless the dep is explicitly approved.
This catches supply-chain footguns at install time.

We currently approve:

| Component | allowBuilds |
| :--- | :--- |
| envpact-mcp | esbuild |
| envpact-mcp/worker | workerd, esbuild, sharp |
| envpact-vscode | @vscode/vsce-sign, esbuild, keytar |
| envpact-dashboard | esbuild, sharp |
| envpact-action | (none — pure JS deps) |

When you bump a dep and pnpm reports `[ERR_PNPM_IGNORED_BUILDS]`,
read the dep's source before adding it to `allowBuilds`. A new
postinstall script is a hard line in the supply chain that
deserves a manual review.

## CI: actions/cache@v4 + pnpm/action-setup@v4

Every workflow follows the same canonical install pattern:

```yaml
- uses: actions/checkout@v4

- name: Install pnpm
  uses: pnpm/action-setup@v4
  with:
    version: 10.18.0
    run_install: false

- uses: actions/setup-node@v4
  with:
    node-version: 22

- name: Resolve pnpm store directory
  id: pnpm-store
  shell: bash
  run: echo "path=$(pnpm store path --silent)" >> "$GITHUB_OUTPUT"

- name: Cache pnpm store
  uses: actions/cache@v4
  with:
    path: ${{ steps.pnpm-store.outputs.path }}
    key: ${{ runner.os }}-node22-pnpm-${{ hashFiles('**/pnpm-lock.yaml') }}
    restore-keys: |
      ${{ runner.os }}-node22-pnpm-
      ${{ runner.os }}-pnpm-

- run: pnpm install --frozen-lockfile
```

### Why not `setup-node`'s built-in `cache: pnpm`?

It's unreliable when pnpm is installed by `pnpm/action-setup` —
they race on which one wins `$PATH`, and when `setup-node` loses
the cache key targets a path that doesn't exist. The manual
store-path pattern (resolve via `pnpm store path` after both
actions ran, then `actions/cache@v4`) is what the pnpm team
itself recommends.

### Cache key strategy

- Primary: `<os>-node<version>-pnpm-<hash of pnpm-lock.yaml>`
- Fallback: `<os>-node<version>-pnpm-` then `<os>-pnpm-`

The fallback chain means a lockfile bump still gets a partial
cache hit, just with the changed packages re-downloaded. Cold
installs that miss everything still work; they're just slow.

## Component tooling

| Component | Build tool | Test runner |
| :--- | :--- | :--- |
| envpact-cli | (zero deps; node stdlib only) | node --test |
| envpact-mcp | esbuild → mcpb pack | scripts/test.mjs (Node native) |
| envpact-mcp/worker | wrangler (Cloudflare) | (none yet — typecheck only) |
| envpact-action | @vercel/ncc | scripts/test.mjs (Node native) |
| envpact-vscode | tsc → @vscode/vsce package | scripts/test.mjs + tsx (auto) |
| envpact-dashboard | astro build | node --test (no test files yet) |
| envpact (Python) | hatchling | pytest |

### About scripts/test.mjs

pnpm scripts on Windows dispatch via `cmd.exe`, which does NOT
expand POSIX globs. So `node --test tests/*.test.js` in package.json
fails on Windows runners — the literal `tests\*.test.js` string
reaches node, which can't open it as a file path. `scripts/test.mjs`
solves this by walking `tests/` in Node itself and passing each
matched file to a child `node --test` as an explicit arg.

The same script auto-detects TypeScript test files and adds
`--import tsx` when needed, so `envpact-vscode`'s `.ts` suite uses
the same script as the JS-only repos.

This is why every repo's `test` script is uniformly
`node scripts/test.mjs`.

## Releasing

```bash
./scripts/release-all.sh 0.2.1
```

Tags `v0.2.1` across all components, the publish workflows
fire in parallel:

- envpact-cli, envpact-mcp → npm publish via pnpm
- envpact-python → PyPI via OIDC trusted publisher
- envpact-vscode → vsce publish via pnpm exec
- envpact-action → release.yml updates the major-version moving tag
- envpact-mcp build-mcpb.yml → attaches `.mcpb` to the GitHub Release
- envpact-dashboard → deploy.yml deploys to Cloudflare Pages
