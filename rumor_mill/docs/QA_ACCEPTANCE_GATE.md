# QA Acceptance Gate

**Effective:** 2026-05-03
**Scope:** All fix-style issues (priority high/critical, UI/visual bugs, gameplay bugs).

## Mandatory Checks Before `in_review`

The assignee may NOT set status to `in_review` until all applicable checks are completed and artifacts pasted into the issue comment.

### 1. Script Validation

Run `mcp__godot-mcp__validate_scripts` and paste the JSON output.

**IMPORTANT — Known MCP Gap:** `validate_scripts` runs `godot --headless` which only compiles scripts in the autoload chain and main scene tree. Scripts loaded exclusively by non-main scenes (e.g., `rumor_panel.gd`, scenario HUDs, `social_graph_overlay.gd`) are **silently skipped**. Always cross-check against the Godot editor Output panel.

### 2. Headless Launch

Run `mcp__godot-mcp__launch_headless` for the relevant scene. Paste JSON output showing clean exit (exit code 0, no errors).

### 3. Visual / Gameplay Proof

| Bug Type | Required Proof |
|----------|---------------|
| UI/visual | Screenshot of the running game showing the fixed state. Attach to issue. |
| Gameplay | Either a 30-second GIF of the repro now passing, OR a unit test that fails before the fix and passes after. Cite the test file path. |

### 4. Commit SHA

Cite the commit SHA. Must be verifiable via `git log --oneline | grep <sha>`.

## Artifact Checklist Template

Copy this into your `in_review` comment:

```markdown
## QA Acceptance Artifacts

- [ ] `validate_scripts` JSON: [paste or "clean — 0 errors"]
- [ ] Editor cross-check: [confirm no errors in Output panel]
- [ ] `launch_headless` JSON: [paste or "exit 0, no errors"]
- [ ] Visual/gameplay proof: [screenshot attached / GIF attached / test at `tests/test_xxx.gd`]
- [ ] Commit SHA: `<sha>`
```

## Enforcement

CEO will PATCH any `in_review` issue back to `in_progress` if these artifacts are missing.
