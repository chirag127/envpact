# API Tokens & Publishing Credentials

This is the **complete** list of credentials needed to:
- Publish each component to its package registry.
- Deploy the dashboard to Cloudflare Pages.
- Allow consumers of `envpact-action` to fetch your private vault.

You only need to acquire these **once**. After running the setup
script, GitHub Actions takes over.

---

## Required Tokens

| Token | Used For | Where to Add It |
| :--- | :--- | :--- |
| `NPM_TOKEN` | Publishing `envpact-cli` and `envpact-mcp` to npm | repo secrets on `envpact-cli` and `envpact-mcp` |
| PyPI Trusted Publisher | Publishing `envpact` (Python) to PyPI via OIDC | PyPI project settings (no secret in GitHub) |
| `VSCE_PAT` | Publishing `envpact-vscode` to VS Code Marketplace | repo secrets on `envpact-vscode` |
| `OVSX_PAT` (optional) | Mirroring VS Code extension to Open VSX | repo secrets on `envpact-vscode` |
| `CLOUDFLARE_API_TOKEN` | Deploying `envpact-dashboard` to Cloudflare Pages | repo secrets on `envpact-dashboard` |
| `CLOUDFLARE_ACCOUNT_ID` | Identifying your Cloudflare account | repo secrets on `envpact-dashboard` |
| `PUBLIC_GITHUB_OAUTH_CLIENT_ID` | Dashboard OAuth login flow (public, baked into build) | repo variable on `envpact-dashboard` |

---

## Step 1: Generate `NPM_TOKEN`

1. Sign in at https://www.npmjs.com/.
2. Click your avatar → **Access Tokens** → **Generate New Token**.
3. Choose **Granular Access Token**.
   - Token name: `envpact-publishing`.
   - Expiration: 1 year.
   - Permissions: **Read and write**.
   - Packages and scopes: select `envpact-cli` and `envpact-mcp`
     (or "Read and write to packages and scopes" → All).
4. Click **Generate Token** and **copy** the token immediately
   (`npm_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`).
5. Paste it when the setup script prompts you, OR run manually:
   ```bash
   gh secret set NPM_TOKEN --repo chirag127/envpact-cli
   gh secret set NPM_TOKEN --repo chirag127/envpact-mcp
   ```

---

## Step 2: Configure PyPI Trusted Publisher

PyPI's modern publishing flow uses **GitHub OIDC** — no token
needed in GitHub at all. Instead, PyPI verifies the workflow's
identity directly.

1. Sign in at https://pypi.org/.
2. Reserve the package name **once** (PyPI requires the project to
   exist before you can configure trusted publishers):
   ```bash
   cd envpact-python
   python -m venv .venv && . .venv/bin/activate    # Windows: .venv\Scripts\activate
   pip install --upgrade build twine
   python -m build
   python -m twine upload dist/*
   # ...prompts for username; for the very first upload, use a
   # classic API token from https://pypi.org/manage/account/token/
   ```
3. After the first manual upload succeeds, configure trusted
   publishing at
   https://pypi.org/manage/project/envpact/settings/publishing/:
   - **Owner**: `chirag127`
   - **Repository name**: `envpact-python`
   - **Workflow name**: `publish.yml`
   - **Environment name**: `pypi` (matches `environment: pypi` in
     `.github/workflows/publish.yml`).
4. Delete the classic token you used for the bootstrap upload.

From this point on, `git tag v0.2.0 && git push --tags` triggers
the workflow, which authenticates to PyPI via OIDC automatically.

---

## Step 3: Generate `VSCE_PAT`

VS Code Marketplace uses Azure DevOps for publisher identity.

1. Sign in to Azure DevOps at https://dev.azure.com/ (free).
2. Create an organization if you don't have one.
3. Click your avatar (top-right) → **Personal access tokens**.
4. Click **+ New Token**.
   - Name: `vsce-envpact`.
   - Organization: **All accessible organizations**.
   - Expiration: 1 year.
   - Scopes: **Custom defined** → check **Marketplace → Manage**.
5. Click **Create** and **copy** the token.
6. Create the publisher (one-time):
   ```bash
   npx vsce login chirag127
   # paste the PAT when prompted
   ```
7. Add the same PAT to GitHub:
   ```bash
   gh secret set VSCE_PAT --repo chirag127/envpact-vscode
   ```

### Optional: Open VSX (Eclipse) mirror

Mirroring to Open VSX lets users on VSCodium / Cursor / Theia /
Eclipse install your extension too.

1. Sign in to https://open-vsx.org/ via Eclipse OAuth.
2. https://open-vsx.org/user-settings/tokens → **Generate New Token**.
3. ```bash
   gh secret set OVSX_PAT --repo chirag127/envpact-vscode
   ```

---

## Step 4: Generate `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID`

1. Sign in at https://dash.cloudflare.com/.
2. **Account ID**: visible on the right side of the dashboard.
   Copy it (a 32-char hex string).
3. **API token**:
   - https://dash.cloudflare.com/profile/api-tokens → **Create
     Token**.
   - Use the **Edit Cloudflare Workers** template (it includes
     Pages permissions).
   - Or create custom: **Account Resources** = your account,
     permissions:
     - Account → Cloudflare Pages → Edit
     - Account → Workers Scripts → Edit (optional, for the
       remote MCP variant later)
     - Zone → DNS → Edit (only if you want the action to manage
       the custom-domain DNS record automatically)
   - Click **Continue** → **Create Token** → copy.
4. ```bash
   gh secret set CLOUDFLARE_API_TOKEN --repo chirag127/envpact-dashboard
   gh secret set CLOUDFLARE_ACCOUNT_ID --repo chirag127/envpact-dashboard
   ```

---

## Step 5: Create the GitHub OAuth App for the Dashboard

1. https://github.com/settings/developers → **OAuth Apps** → **New
   OAuth App**.
   - Application name: `envpact dashboard`.
   - Homepage URL: `https://envpact.oriz.in` (or
     `https://envpact-dashboard.pages.dev` if you skip the
     custom domain).
   - Authorization callback URL: same as Homepage URL (unused for
     device flow but the form requires a value).
2. Click **Register application**.
3. **CRITICAL**: scroll down and check **Enable Device Flow**.
4. Copy the **Client ID** (looks like `Iv1.abc123…` or
   `Ov23li…`).
5. Add it as a **public** repo variable (it's safe to expose; this
   is a public-client OAuth flow):
   ```bash
   gh secret set PUBLIC_GITHUB_OAUTH_CLIENT_ID --repo chirag127/envpact-dashboard
   ```
   (Either secret or variable works; the build references it via
   `${{ secrets.PUBLIC_GITHUB_OAUTH_CLIENT_ID }}`.)

---

## Step 6: Create the Custom Domain (envpact.oriz.in)

1. https://dash.cloudflare.com/ → select your `oriz.in` zone.
2. **DNS** → add a CNAME:
   - Name: `envpact`
   - Target: `envpact-dashboard.pages.dev`
   - Proxy status: **Proxied** (orange cloud)
3. https://dash.cloudflare.com/?to=/:account/pages/view/envpact-dashboard/domains
   → **Set up a custom domain** → enter `envpact.oriz.in` → done.

---

## Verify Everything

After running the setup script (or doing all the above manually):

```bash
# Check each repo has the right secrets configured
for repo in envpact-cli envpact-mcp envpact-python envpact-action envpact-vscode envpact-dashboard; do
  echo "=== chirag127/$repo ==="
  gh secret list --repo "chirag127/$repo"
done
```

Expected:

| Repo | Secrets |
| :--- | :--- |
| `envpact-cli` | `NPM_TOKEN` |
| `envpact-mcp` | `NPM_TOKEN` |
| `envpact-python` | (empty — uses OIDC) |
| `envpact-action` | (empty — only needs the consumer's `ENVPACT_VAULT_TOKEN` set on consumer repos) |
| `envpact-vscode` | `VSCE_PAT`, optionally `OVSX_PAT` |
| `envpact-dashboard` | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `PUBLIC_GITHUB_OAUTH_CLIENT_ID` |

## Releasing v0.1.0 to all registries

Once secrets are configured:

```bash
# From the umbrella repo:
./scripts/release-all.sh 0.1.0
```

Or per-component:

```bash
cd envpact-cli && git tag v0.1.0 && git push --tags
cd ../envpact-mcp && git tag v0.1.0 && git push --tags
cd ../envpact-python && git tag v0.1.0 && git push --tags
cd ../envpact-action && git tag v0.1.0 && git push --tags
cd ../envpact-vscode && git tag v0.1.0 && git push --tags
# Dashboard auto-deploys on every push to main; no tag required.
```

Each tag triggers that component's publish workflow. Watch them at
https://github.com/chirag127?tab=repositories.
