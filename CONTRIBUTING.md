# Contributing to envpact

Thanks for your interest in contributing! envpact is a
multi-repo ecosystem — see the per-component CONTRIBUTING.md
for code-level guidelines:

- [envpact-cli/CONTRIBUTING.md](./envpact-cli/CONTRIBUTING.md)
- [envpact-mcp/CONTRIBUTING.md](./envpact-mcp/CONTRIBUTING.md)
- [envpact-python/CONTRIBUTING.md](./envpact-python/CONTRIBUTING.md)

## Repository Layout

```
envpact/                       # this umbrella repo
├── envpact-cli/               # submodule → chirag127/envpact-cli
├── envpact-mcp/               # submodule → chirag127/envpact-mcp
├── envpact-python/            # submodule → chirag127/envpact-python
├── envpact-action/            # submodule → chirag127/envpact-action
├── envpact-vscode/            # submodule → chirag127/envpact-vscode
├── envpact-dashboard/         # submodule → chirag127/envpact-dashboard
├── _build/specs/              # canonical specs (SHARED_SPEC.md, MCP_TOOLS.json)
├── docs/                      # cross-cutting docs
└── scripts/                   # release tooling
```

## Working on a Component

```bash
git clone --recursive https://github.com/chirag127/envpact.git
cd envpact

# Update all submodules to their latest main
git submodule update --recursive --remote

# Make changes inside one component
cd envpact-cli
git switch -c my-feature
# ... edit, test, commit ...
git push origin my-feature
# Open a PR against chirag127/envpact-cli (the component repo,
# not the umbrella).
```

The umbrella repo only updates submodule pointers when releasing
a coordinated bump — for normal feature work, the per-component
PR is enough.

## Spec Changes

If your change requires updating the resolver semantics or the
vault schema, **update [SHARED_SPEC.md](./_build/specs/SHARED_SPEC.md)
first**, then port the change across:

1. envpact-cli/lib/resolver.js (canonical implementation)
2. envpact-mcp/src/lib/resolver.js (ESM mirror)
3. envpact-python/src/envpact/resolver.py (Python port)
4. envpact-action/src/resolver.js (embedded copy)
5. envpact-vscode/src/resolver.ts (TS port)
6. envpact-dashboard/public/scripts/resolver.js (browser port)

Each port has the same test cases (only the test syntax differs).
A spec PR that doesn't update all 6 ports gets blocked.

## Tag-Based Releases

```bash
./scripts/release-all.sh 0.1.0
```

This bumps `version` in each `package.json` / `pyproject.toml`,
commits, tags `v0.1.0`, and pushes. Each component's publish
workflow takes over.

## Code of Conduct

Be respectful, kind, and helpful. We don't tolerate harassment
of any kind. Disclose security issues privately to
whyiswhen@gmail.com — never via public issues.
