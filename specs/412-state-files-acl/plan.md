# Implementation Plan: Backlog app start keeps its state files accessible

**Branch**: `412-state-files-acl` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/412-state-files-acl/spec.md`

## Summary

`StateDir.restrictToOwner()` (backlog app, feature 344) applies
`icacls <folder> /inheritance:r /grant:r *<SID>:(OI)(CI)F *S-1-5-18:(OI)(CI)F /T` - on files the
`(OI)(CI)` grant is dropped and they keep an empty protected DACL. The fix sets the folder's own
ACL without `/T`, then resets the contents to inherit from it: one
`icacls <folder>\* /reset /T /C /Q` when a walk found no link and listed every folder, otherwise
folder by folder (`icacls <dir>\* /reset /C /L /Q`, top-down, never into a link). The side
worktree's `ensure()` refuses with a clear error when its `.git` exists but cannot be read,
instead of deleting the folder.

## Technical Context

**Language/Version**: TypeScript on Node 24 (type stripping, `erasableSyntaxOnly`)
**Primary Dependencies**: none new; `node:fs`, `node:child_process`; Windows `icacls.exe`, `whoami.exe` from System32
**Storage**: the state folder `<git-common-dir>/tandem-backlog-app/`
**Testing**: vitest (`npm run test`, project `server`), whole gate `npm run check` (typecheck, ESLint with jsdoc/tsdoc, prettier, tests)
**Target Platform**: Windows 11 (the ACL path); POSIX unchanged (`chmod 700`)
**Project Type**: localhost web app (developer tool, `tools/backlog-app/`)
**Performance Goals**: the start stays about 1 s: the fast path is one `icacls` call (the real folder: 691 folders; folder by folder would be about 6 s at 9 ms a call)
**Constraints**: no other user gains access; a link's target outside the folder is never changed
**Scale/Scope**: two source files (`settings/state-dir.ts`, `backlog/side-worktree.ts`), `main.ts` (the note), one new test file, one test added to `side-worktree.test.ts`

## Constitution Check

- I Build reproducibility: no dependency added; the product build is untouched. PASS
- II Backward compatibility: the product is untouched; the app's state folder keeps its layout. PASS
- III Incremental modernization: a local fix of one function. PASS
- IV Windows commitment: uses the System32 tools by full path, as before. PASS
- V Plugin architecture: untouched. PASS
- VI UI consistency: no UI change (one console note). PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/412-state-files-acl/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/state-folder-access.md
├── fix-log.md
└── checklists/requirements.md
```

### Source Code

```text
tools/backlog-app/packages/server/src/settings/state-dir.ts     restrictToOwner(): folder step, contents reset (fast path / folder by folder)
tools/backlog-app/packages/server/src/main.ts                   the note when the contents reset failed
tools/backlog-app/packages/server/src/backlog/side-worktree.ts  ensure(): unreadable .git -> ApiError, no delete
tools/backlog-app/packages/server/test/state-dir.test.ts        new (Windows-only cases skipped elsewhere)
tools/backlog-app/packages/server/test/side-worktree.test.ts    the unreadable .git case
```

**Structure Decision**: the existing server package; no new module.

## Complexity Tracking

None.
