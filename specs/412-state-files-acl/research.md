# Research - 412-state-files-acl

## R1 Why the files end with an empty DACL

- Decision: the old call is the cause; measured in a temp folder (fix-log *Measurement before*).
- Rationale: `/inheritance:r` removes the inherited ACEs of every entry (`/T`); `/grant:r` with
  `(OI)(CI)` on a file grants nothing (the inheritance flags have no meaning on a file and the ACE
  is not kept), so a file is left with a protected empty DACL. Folders keep the grant.

## R2 How to make the contents follow the folder

- Decision: folder first (no `/T`), then `icacls <folder>\* /reset /T /C /Q`.
- Rationale: `/reset` replaces an entry's DACL with the inherited one and clears protection; the
  folder grants only the owner and SYSTEM, inheritable; previously locked entries are repaired.
  Measured: every entry `D:AI` + inherited owner and SYSTEM, the hidden `.git` included; an empty
  folder exits 0.
- Alternatives: grant files an explicit ACE without `(OI)(CI)` - leaves explicit ACEs on every
  file and does not clear protection of entries a later folder change should reach; rejected.
  Reset everything first and then protect the folder - the contents would inherit the
  repository's broad ACL for a moment; rejected.

## R3 Links

- Decision: never follow a link; one `/T` call only when a walk with
  `readdirSync(dir, { withFileTypes: true })` found no `isSymbolicLink()` entry and listed every
  folder; otherwise per folder top-down `icacls <dir>\* /reset /C /L /Q`, descending only into
  real folders.
- Rationale: measured, `/reset /T` follows a junction (with and without `/L`) and reset an
  explicit ACE of a file outside the folder; without `/T`, `/L` resets the link entry itself.
  Node reports a junction as a symbolic link in `Dirent`.
- Cost: 9 ms per `icacls` call; 691 folders in the real state folder -> the fast path keeps the
  start near 1 s; the slow path only happens with links (never created by the app or git here).

## R4 The result of the step

- Decision: `restrictToOwner()` returns `{ private, contents }`: `private` = the folder step
  succeeded (decides the launcher secret as before); `contents` = `"reset" | "failed"`.
  `main.ts` prints a note on `failed`.
- Rationale: the secret file `instance.json` is written after the step and inherits the folder's
  ACL, so the secret is safe whenever the folder step succeeded.

## R5 Unreadable side worktree

- Decision: `ensure()` checks, when `exists()` is false and `.git` is present, whether reading it
  fails with `EACCES` / `EPERM`; then `ApiError("tool-failed", ...)` naming the permissions and
  the manual repair, the folder kept. `exists()` itself stays a boolean (it is also used by
  `revert()` in failure paths, where a throw would hide the first error).
