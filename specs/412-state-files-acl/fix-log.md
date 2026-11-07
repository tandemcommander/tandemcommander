# Fix log - 412-state-files-acl

Backlog item `backlog-app-start-locks-existing-state-files`: the backlog app's start leaves the
files already in its state folder with an empty, protected access list (`D:PAI`).

## Measurement before (main at 23a9f24a)

1. Temp folder `%TEMP%\tcbl_measure` with `a.txt`, `sub\b.txt`; the exact call of
   `StateDir.restrictToOwner()`:
   `icacls <d> /inheritance:r /grant:r *<SID>:(OI)(CI)F *S-1-5-18:(OI)(CI)F /T /C /Q` -> exit 0,
   "Successfully processed 4 files".
   - `<d>`, `sub`: `D:PAI(A;OICI;FA;;;SY)(A;OICI;FA;;;<SID>)`
   - `a.txt`, `sub\b.txt`: `D:PAI` (empty) - `Get-Content a.txt` -> "Access to the path ... is denied."
   - `c.txt` created afterwards: `D:AI(A;ID;FA;;;SY)(A;ID;FA;;;<SID>)` (inherits - hides the defect).
2. The maintainer's real state folder `.git\tandem-backlog-app` (read-only `Get-Acl`): 383 files,
   375 with `D:PAI`, among them `main-worktree\.git` and `events.jsonl`. Not repaired by the run:
   the next start of the fixed app repairs it.
3. Reachability: `main.ts` calls `state.restrictToOwner()` at every start; `SideWorktree.exists()`
   -> `existsSync(.git)` true (attributes are readable through the folder), `git rev-parse` fails
   (cannot read `.git`) -> false -> `ensure()` -> `rmSync(path, {recursive, force})` -> EPERM.
4. Trial of the item's approach in the same temp folder (after locking it again, plus a hidden
   `.git` file): `icacls <d> /inheritance:r /grant:r ... /C /Q` (no `/T`), then
   `icacls <d>\* /reset /T /C /Q` -> exit 0, every entry `D:AI` with inherited owner + SYSTEM ACEs
   (hidden `.git` included, previously locked files repaired), the folder `D:PAI` owner + SYSTEM.
   Empty folder: `icacls <e>\* /reset /T /C /Q` -> exit 0, "Successfully processed 0 files".

## Decisions

- Folder ACL without `/T`, then the contents reset (`<folder>\*` `/reset /T /C /Q`) - the item's
  first approach.
- The launcher secret depends on the folder step only (the secret file `instance.json` is written
  after the step and inherits); a failed contents reset prints a note.
- `SideWorktree`: a `.git` that exists but cannot be read (EACCES / EPERM) is an error, never a
  reason to delete the folder.

## Work
