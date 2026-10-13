# GitHub issues job - progress (working file of the agent)

Task (2026-10-13, the maintainer is away): fix `issue_3`, `issue_5`, `issue_6`, `issue_7`,
`issue_8` one by one. Each is its own Spec Kit flow (specify, plan, tasks, implement) on its own
branch, with independent tests and a report `issues/issue_X_report.md` (the text to paste into
the GitHub thread). Fixes go out in 0.1.10. Nothing is pushed or published.

How the work is organised

- Branches are stacked: `124-...` from `main`, each next one from the previous. Local commits
  only, messages `[NNN] ...`.
- Baseline for "before" measurements: `build\tandemcommander\Debug_x64_v019` (copy of the Debug
  tree of the 0.1.9 release commit, made 2026-10-13).
- Shared probe helper for owner-drawn text (capture + Windows text recognition):
  `specs/124-regedt-key-text/probe/shotocr_lib.ps1`.
- A session cron job re-enters the work every 30 minutes if the session went idle (usage limit).

| Issue | Feature | State |
|-------|---------|-------|
| #3 regedt KEY text | 124-regedt-key-text | **done** - committed on the branch, report `issues/issue_3_report.md` |
| #5 `\\server\` | 125-unc-server-shares | **done** - core fallback (share list), plug-in policy untouched and recorded in NEXT-WORK section D; report `issues/issue_5_report.md` |
| #6 Windows 7 start | 126-package-api-late-bind | **done** - the two functions resolved at run time; report `issues/issue_6_report.md` |
| #7 mixed templates | 127-mixed-template-texts | **done** - about 45 places + Registry Editor + guard; report `issues/issue_7_report.md` |
| #8 shortcuts | - | not started |
