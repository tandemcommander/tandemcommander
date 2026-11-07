---
title: Backlog app start leaves its existing state files with no access rights
type: bug
status: open
severity: 6
area: tooling
source: manual
who: agent
created: 2026-11-07
updated: 2026-11-07
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Backlog app start leaves its existing state files with no access rights

## Problem

Every start of the backlog app makes its state folder `.git/tandem-backlog-app/` private with `icacls <folder> /inheritance:r /grant:r *<SID>:(OI)(CI)F *S-1-5-18:(OI)(CI)F /T /C /Q`. The folders end with owner + SYSTEM as intended, but every **file** already in the folder at that moment ends with an empty, protected DACL (`D:PAI`): nobody, the owner included, can read, write or delete it (the owner can only change its permissions). Files written after the start inherit normally, which hides the defect until the app touches an older file.

The visible symptom: during a run (the run lock held) a new item created in the app fails with

```
EPERM, Permission denied: \\?\E:\Projects\tandemcommander\.git\tandem-backlog-app\main-worktree '\\?\E:\Projects\tandemcommander\.git\tandem-backlog-app\main-worktree'
```

`SideWorktree.exists()` cannot read the worktree's `.git` file, takes the side worktree for missing, and `ensure()` tries to delete the folder with `rmSync`, which the locked files refuse. Every change the app makes during a run fails the same way. The event log `events.jsonl` (from 2026-10-30) is locked as well, so the app has most likely not appended an event since its next start.

## Evidence

Measured 2026-11-07 on the maintainer's tree (read-only), code at `aca5c5d3`:

- `tools/backlog-app/packages/server/src/settings/state-dir.ts:66-71` `StateDir.restrictToOwner()` runs the `icacls` command above; it is called at every start from `tools/backlog-app/packages/server/src/main.ts:226`.
- `Get-Acl` SDDL: the folders `cache`, `chats`, `jobs`, `main-worktree`, `undo` = `D:PAI(A;OICI;FA;;;SY)(A;OICI;FA;;;<user SID>)`; the files `main-worktree/.git` and `events.jsonl` = `D:PAI` (empty); `instance.json` and `tray.json` (rewritten after the start) = `D:AI(A;ID;FA;;;SY)(A;ID;FA;;;<user SID>)`.
- 375 files of the state folder have `D:PAI`, among them `main-worktree/.git` and all of `main-worktree/backlog/**`.
- `cat main-worktree/.git` and `git rev-parse` inside the worktree: `Permission denied`.
- Timeline: the side worktree was created 2026-11-01 15:07; `main-worktree/.git` was last read 2026-11-06 20:19; the app started 2026-11-06 21:28 (`instance.json`) and locked it.
- The failing path: `tools/backlog-app/packages/server/src/backlog/side-worktree.ts:100-104` `exists()` (false when `.git` cannot be read) -> `:121` `rmSync(this.path, { recursive: true, force: true })` -> EPERM.

## Expected

A start of the app keeps every file of the state folder readable and writable by the user running it (and SYSTEM), and no other user gains access. Files that are already locked by an earlier start are repaired at the next start. A change during a run lands through the side worktree again, and the event log is written.

## Approach

- Set the private ACL on the folder itself without `/T`, then reset the contents to inherit from it: `icacls <folder>\* /reset /T /C /Q` (or grant files an explicit ACE without `(OI)(CI)`).
- The same reset repairs the files that earlier starts already locked.
- A test that creates a file in the state folder, runs `restrictToOwner()` and reads, writes and deletes the file afterwards; a test that a pre-locked file (`D:PAI`) is readable after the next start.
- Check whether `SideWorktree.exists()` should tell an unreadable `.git` (an error to report) from a missing one (a folder to recreate) instead of deleting the folder.

## Notes

Manual repair until the fix lands (the owner may always change the permissions): `icacls "E:\Projects\tandemcommander\.git\tandem-backlog-app\*" /reset /T /C /Q` - it lasts only until the next start of the app.

The defect came with feature 344 (review M2, commit `449e4638`, 2026-10-30). Severity 6: every change the app makes during a run fails and the event log is lost - a feature of the app is broken for every user on Windows; no user data of the product is lost.

## Log

- 2026-11-07 — created (source manual)
- 2026-11-07 — moved to Next position 1
