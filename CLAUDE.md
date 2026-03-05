# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mandatory Codex Review Workflow

> **⚠ BLOCKING REQUIREMENT — NEVER SKIP THIS STEP.**
> All plans and code changes MUST be reviewed and approved by Codex **before** being presented to the user or treated as complete. Use the `codex-chunk` skill for all reviews. Initial approval does not carry over — **each update requires a new round of Codex review**. No exceptions.

### 1. Plan Review (BEFORE presenting to user)

- Draft the plan, then submit it to Codex for review via the `codex-chunk` skill **before** showing it to the user
- Incorporate **all** Codex feedback and re-submit until Codex approves
- The user must only ever see plans that have already passed Codex review
- If the plan changes after user feedback, re-submit the revised plan to Codex before continuing

### 2. Code Change Review (during and after implementation)

- **Per-file review**: After editing **each file**, immediately submit the changes to Codex for review via the `codex-chunk` skill. Do NOT proceed to the next file until Codex approves the current one
- **Final holistic review**: After all edits are complete, submit the **entire changeset** to Codex for a comprehensive review via the `codex-chunk` skill
- Address **every** issue found in the final review, then re-submit until Codex approves
- Never present code changes to the user until both per-file and final holistic Codex reviews have passed

### 3. Post-change Review (any subsequent modifications)

- If the user requests follow-up changes, bug fixes, or refinements after the initial implementation, **each new change** must go through the same per-file + final holistic Codex review cycle
- Codex approval from a previous round does **not** carry forward — treat every edit as requiring fresh approval
