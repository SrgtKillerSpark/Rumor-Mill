# QA Acceptance Gate — Standard Operating Procedure

**Effective:** 2026-05-03
**Policy issue:** SPA-1545
**Applies to:** All agents (Coder, QA Lead, QA Tester) working on fix-style issues

---

## Scope

This gate applies to ANY issue that meets one or more of these criteria:

- Priority **high** or **critical**
- Labeled as a UI/visual bug
- Labeled as a gameplay bug
- Any fix-style issue (bug fix, regression fix, hotfix)

## Gate Requirements

An assignee **may NOT** set an issue's status to `in_review` until ALL applicable artifacts below are present in the issue thread as a comment.

### 1. Script Validation (required for all)

Run `mcp__godot-mcp__validate_scripts` and paste the full JSON output into the issue comment. Output must show `passed: true` and `errorCount: 0`.

> **Note (resolved 2026-05-03):** A prior gap where validate_scripts only compiled autoload/main-scene scripts was fixed in commit `b55a7a5` (SPA-1546). The tool now scans every `.gd` file in the project tree via `DirAccess` recursion. If you suspect a false-clean result, cross-check with the Godot editor Output panel as a secondary verification.

### 2. Headless Launch (required for all)

Run `mcp__godot-mcp__launch_headless` for the relevant scene and paste the JSON output into the issue comment. Output must be clean (no errors, no crashes).

### 3. Visual Proof — UI/Visual Bugs

Open the project in the Godot editor, press Play, and take a screenshot of the running game showing the fixed state. Attach the screenshot to the issue.

### 4. Gameplay Proof — Gameplay Bugs

Provide one of:

- A 30-second GIF/video recording showing the repro case now passing, **OR**
- A unit test that fails before the fix and passes after. Cite the test file path in the comment.

### 5. Commit SHA (required for all)

Cite the commit SHA of the fix. It must be verifiable via `git log --oneline | grep <sha>`.

## Artifact Checklist Template

Use this template in your in_review comment:

```markdown
## QA Acceptance Artifacts

- [ ] `validate_scripts` JSON output (clean)
- [ ] Editor parse-error check (0 errors in Output panel)
- [ ] `launch_headless` JSON output (clean, scene: `<scene_name>`)
- [ ] Visual proof: screenshot attached (UI/visual bugs only)
- [ ] Gameplay proof: GIF/video or test path cited (gameplay bugs only)
- [ ] Commit SHA: `<sha>`
```

## Enforcement

- **QA Lead and QA Tester** must follow this gate when running test plans and clearing issues.
- **CEO** will block-PATCH any `in_review` issue back to `in_progress` if these artifacts are missing.

## MCP Tool Gap — Resolved

A prior gap in `validate_scripts` (it only compiled autoload/main-scene scripts) was fixed in SPA-1546 (commit `b55a7a5`). The tool now uses `DirAccess` recursion to scan every `.gd` file in the project tree. A clean MCP result is now sufficient proof of zero parse errors. If you ever suspect a regression, cross-check with the Godot editor Output panel.
