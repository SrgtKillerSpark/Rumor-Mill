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

Run `mcp__godot-mcp__validate_scripts` and paste the full JSON output into the issue comment.

> **Known limitation:** The MCP validate_scripts tool only compiles scripts that Godot loads during headless startup (autoloads and main scene tree). Scripts loaded by non-main scenes may be silently skipped. Until this is fixed (see child bug from SPA-1545), **also open the project in the Godot editor and confirm zero parse errors in the Output panel.** If the editor shows errors that MCP missed, note them explicitly.

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

## MCP Tool Gap — Interim Workaround

The MCP `validate_scripts` tool runs Godot in headless mode with default arguments. Godot only compiles scripts in the autoload chain and main scene tree during headless startup. Scripts referenced exclusively by non-main scenes (e.g., `rumor_panel.gd`, scenario-specific HUDs) are not loaded and therefore not validated.

**Until the MCP tool is patched to force-load all project scripts:**

1. Always cross-check MCP output against the Godot editor's Output/Debugger panel.
2. If the editor reports errors that MCP did not, note the discrepancy in your comment.
3. Do not treat a clean MCP result as sufficient proof of zero parse errors.
