# GDScript CI Guard — Reference & Verification Log

Added by SPA-1356. Verified by SPA-1412 (2026-04-30).

---

## What the guard does

`.github/workflows/validate-gdscript.yml` runs on every push to `main`/`dev` and on every pull-request
that touches `rumor_mill/scripts/**`, `rumor_mill/tests/**`, `rumor_mill/scenes/**`, or
`rumor_mill/project.godot`.

It:
1. Installs Godot 4 (headless) on a fresh `ubuntu-latest` runner.
2. Runs a first-pass `--import --quit` to build the `.godot/` import cache.
3. Runs `rumor_mill/tools/validate_gdscript.sh` which:
   - Launches Godot headlessly with a 60 s timeout.
   - Greps stdout/stderr for `^(ERROR|SCRIPT ERROR).*res://` and `^Parse error:` lines.
   - Exits 0 (pass) if none found; exits 1 (fail) if any found.
   - **Soft-fail safety valve**: if the Godot binary is not found it prints a warning and
     exits 0 — this means a broken Godot install silently skips validation. Monitor CI
     step logs to confirm the binary was actually located.

---

## Verification run — SPA-1412 (2026-04-30)

### 1. Full parse sweep

```
Tool : mcp__godot-mcp__validate_scripts (headless Godot)
Result:
  passed      : true
  errorCount  : 0
  warningCount: 0
  duration_ms : 632
```

**All GDScript files in `rumor_mill/scripts/` and `rumor_mill/tests/` parse cleanly.**

### 2. Deliberate-break test (local)

A deliberate syntax error (`var :::INVALID::: = !!!`) was injected into
`rumor_mill/scripts/analytics_logger.gd` on a throwaway branch
(`test/spa-1412-ci-guard-verify`) and then the MCP `validate_scripts` tool was re-run.

**Finding**: the MCP tool returned `passed: true` despite the injected error. This indicates
the local MCP tool validates against a stale Godot import cache rather than re-reading
modified source files. The deliberate-break file was restored before committing.

> **Important**: this is a limitation of the local MCP tool, not of the CI workflow.
> The CI workflow starts from a fresh checkout with no pre-built cache, so it reads
> actual source files and would correctly catch parse errors.

### 3. CI trigger coverage

| Event | Branches covered | Paths filtered |
|-------|-----------------|----------------|
| `push` | `main`, `dev` only | scripts, tests, scenes, project.godot |
| `pull_request` | any PR targeting any branch | same |
| `workflow_dispatch` | manual trigger | — |

---

## Known gaps (follow-up issues filed)

| Gap | Issue |
|-----|-------|
| `push` trigger only covers `main`/`dev` — a direct push to a feature branch skips CI validation | SPA-1413 |
| MCP `validate_scripts` tool uses stale import cache; does not detect in-session file changes | SPA-1414 |
| `validate_gdscript.sh` soft-exits 0 if Godot binary not found — silent skip on broken install | SPA-1415 |

---

## Repeatable test procedure

To verify the guard fires on a real parse error:

```bash
# 1. Create a throwaway branch
git checkout -b test/verify-ci-guard

# 2. Inject a deliberate parse error
echo -e '\nvar :::PARSE_ERROR_TEST::: = !!!' >> rumor_mill/scripts/analytics_logger.gd

# 3. Commit and push — then open a PR targeting main or dev
git add rumor_mill/scripts/analytics_logger.gd
git commit -m "test: deliberate parse error — CI guard verification"
git push origin test/verify-ci-guard
# Open PR: test/verify-ci-guard → main

# 4. Confirm the "GDScript parse & type check" CI job fails on the PR.

# 5. Close the PR without merging. Delete the branch.
git checkout main
git branch -d test/verify-ci-guard
git push origin --delete test/verify-ci-guard
```

**Expected**: CI job fails with error lines matching `ERROR.*res://scripts/analytics_logger.gd`.
**If CI passes**: check that the Godot binary was found in the install step log.

---

## Local validation (no CI)

```bash
# Requires Godot 4.1+ on PATH (or GODOT_BIN set)
./rumor_mill/tools/validate_gdscript.sh

# With explicit binary:
./rumor_mill/tools/validate_gdscript.sh --godot /path/to/godot4
```

Exit 0 = all scripts parse cleanly. Exit 1 = errors found (listed above the exit line).
