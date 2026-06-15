# envpact v0.1.0 Audit Findings

This document catalogues the findings from a 5-agent independent
audit of the envpact ecosystem at v0.1.0 release. The agents
worked in parallel across security, architecture, testing, code
review, and documentation dimensions.

**Scope of audit**: every component repo at HEAD on
2026-06-15.

**Outcome**: 100+ findings across 5 axes. The most important are
summarised below; the full list is being filed as GitHub issues.

---

## TL;DR — fix before recommending the tool to others

These are **BLOCKER** or **CRITICAL** findings — not edge cases:

### Security

1. **`--init auto` does not verify the vault repo is private.** If
   the user already has a public `{user}/envpact-secrets` repo,
   the CLI silently uses it and pushes plaintext secrets to a
   public repo. Catastrophic credential leak.
   *Fix*: assert `repo.private === true` after `gh repo view`;
   abort otherwise. Same fix needed in dashboard
   `getVaultRepo`.

2. **Command injection in `ensureRepoExistsViaGh`.** Uses
   `execSync` with shell-string interpolation. Hardened by fixing
   to `execFileSync` array form + slug regex validation.

3. **GitHub Action writes `.env` to disk before
   `core.setSecret`.** A subsequent step that `cat`s the workspace
   could log unmasked values. Reorder: mask first, write second.

4. **MCP tools accept arbitrary `project_name` / `key`.**
   Prototype pollution + path injection risk via `__proto__`,
   `constructor`, or `..` segments. Add Zod regex constraints +
   reject pollution keys at the vault layer.

5. **Path traversal in MCP `generate_env`** via
   `working_directory` + `output_path`. An agent influenced by
   prompt injection can overwrite `~/.bashrc`, `~/.ssh/...`, etc.
   Validate that resolved output stays inside `working_directory`.

6. **Encrypted (`enc:`) values are only decrypted by the CLI.**
   The MCP server, Python module, Action, VS Code extension, and
   dashboard pass ciphertext through to `.env` verbatim. Apps
   receive `OPENAI_API_KEY=enc:base64...` and 500 in production.

### Architecture

7. **Resolver drift across the 6 ports.** envpact-cli omits the
   `encrypted` field in the missing-project return; dashboard
   omits it AND skips schema validation entirely. A canonical
   conformance test suite is needed.

8. **No conflict resolution on concurrent vault writes.** CLI on
   laptop + dashboard on phone, simultaneous edits → silent data
   loss or 409 with no retry. Add file locking (CLI/MCP/Python/
   VS Code) and dashboard 409-refetch-replay logic.

9. **`v1 → v2` upgrade is silent and not idempotency-tested.**
   Mixed-version clients on different machines can lose data.

10. **No graceful fail-soft for v3+ schema.** Hard-throwing on
    unknown versions means a v3 vault written from one machine
    bricks every older client.

### Code

11. **`decryptValue` strips one trailing newline blindly** —
    plaintext that ended with `\n\n` returns `\n`. Round-trip
    truncation.

12. **`release-all.sh` Python heredoc uses `'PY'` (single quotes)
    so `$VERSION` does not expand** — pyproject.toml gets the
    literal string `$VERSION`. PyPI publish will reject. Found
    by code-review agent — would have killed the first release.

13. **Python `id(content)` tmp suffix can collide after GC.** Use
    `os.getpid()` + `time.time_ns()` instead.

14. **`git push --quiet` hangs indefinitely** when SSH key has a
    passphrase and no agent runs. Add `GIT_TERMINAL_PROMPT=0` and
    a 30s timeout.

15. **Argv parser silently accepts unknown flags** — typos like
    `--rotate-secret` become truthy `args.rotate_secret = true`
    and fall through to `cmdGenerate`.

### Tests

16. **No cross-implementation parity tests** across the 6
    resolver ports. Drift is the most likely source of production
    bugs and the existing suites can't catch it.

17. **`core.setSecret` masking is not verified** in any action
    test. A future refactor that drops the call would silently
    stop masking secrets in CI logs.

18. **Resolver edge cases are untested**: empty string values,
    whitespace-only, values containing `=`/`#`/newlines, missing
    environment with no `default`, `shared.MISSING` references,
    encrypted shared values referenced from per-env objects.

19. **MCP error paths are untested.** Only `tools/list` is
    handshake-tested. Calling tools with missing required fields
    or stale vault state could crash the server (which kills the
    MCP transport in Claude Desktop / Cursor).

20. **Dashboard has zero tests.** OAuth polling, escapeHtml, and
    the GitHub Contents API client are all unverified.

### Documentation

21. **Umbrella README was empty** at audit time. Fixed in this
    commit.

22. **`@v1` action references everywhere; only `@v0` exists.**
    Every workflow snippet copy-pasted by a user will fail.

23. **`npx envpact-cli`, `pip install envpact`, VS Code
    Marketplace install, https://envpact.oriz.in** — all
    referenced as if live, none actually published yet at
    audit time.

24. **Resolver semantics under-specified.** SHARED_SPEC §1
    doesn't say what happens for empty strings, arrays, nulls,
    `_default_env: ""`, or `shared.` (empty key).

---

## Severity Distribution

| Agent dimension | BLOCKER | MAJOR/CRITICAL | MINOR/MEDIUM | INFO/LOW |
|---|---:|---:|---:|---:|
| Security | – | 7 | 3 | 2 |
| Architecture | 2 | 14 | 4 | 2 |
| Tests | 7 | 11 | 7 | 0 |
| Code review | – | 10 | 14 | 6 |
| Documentation | 6 | 35 | 8 | 3 |

The audit consumed ~790k subagent tokens and ~3 hours of agent
time. It surfaced ~150 distinct findings.

---

## Disposition

The 5 highest-impact fixes (#1, #2, #6, #11, #21) land in this
commit. The remainder are filed as GitHub issues against the
appropriate component repo with severity labels. They become the
**v0.2.0 milestone**.

The audit is itself open-source — the agent prompts that produced
these findings are at `_build/audit-prompts/` (where applicable)
and can be re-run on any future commit by anyone with Claude
Code access.

---

## Re-running the audit

```bash
# From the umbrella repo, with a Claude Code session that has /agents skill:
/agents
# Then prompt: "Audit the envpact ecosystem we just shipped."
```

Five subagents (security, architecture, test-engineer,
code-reviewer, doc-writer) will run in parallel and return JSON
findings. Synthesise into a fresh AUDIT-v0.X.0.md.

---

## License

This audit document is MIT-licensed alongside the rest of envpact.
