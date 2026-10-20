# Fix log: feature 258 - SFTP upload into drop folders, limits of a replacement, left temporary files

From backlog item `sftp-replace-keeps-links-acls-drop-dirs` (review leftover of 139).

## 2026-10-20 - measured on main at 2807bbc4 (before specify)

- Docker Desktop was not running; started with `docker desktop start` (container `tandem-sftp`
  came up; to be stopped again at the end of the run).
- **Unix write-only folder on OpenSSH works**: in the container, `/home/tctest/m257/drop733`
  (root:root 0733) and `drop1733` (1733). A paramiko replay of the plug-in's request sequence
  (`seq.py`: lstat target -> "no such file", open `.tcpart-12345678` CREAT|EXCL -> ok, lstat /
  stat temp -> ok, posix-rename -> ok; only the listing is refused). So the review's "drop
  directory fails the size confirmation" does not hold for OpenSSH.
- **A server that refuses to show files in an upload-only folder** (SFTPGo "upload" without
  "list", hosted drop boxes) - modelled by `probe/dropsftp.py` (paramiko server; `/drop` refuses
  stat, lstat, fstat, opendir, rename, remove, setstat with PERMISSION_DENIED, allows an
  exclusive create). Replay: lstat target DENIED, open temp ok, stat temp DENIED, posix-rename
  DENIED.
- **GUI probe before** (`probe/sftp258_probe.ps1`, then still named sftp257 in a temp folder -
  the header line of `probe/result_before.txt` says so; Debug build of 2807bbc4, hidden desktop):
  PASS 7, FAIL 5:
  - DROPNEW / DROPMOVE / DROPDIR FAIL: `Cannot upload "/drop/up.txt": Permission denied.` - the
    item fails at the FIRST lstat of the target (`StatEx` = sxError), before any data; nothing
    arrives, the Move keeps its source.
  - DROPEXIST PASS (guard row: the existing drop file is untouched - because nothing works).
  - REPL FAIL: the question is "The file already exists on the server: /pub/r.txt Overwrite it?
    (Yes = this file, No = skip; Cancel = skip the rest)" - no word of links or ACL.
  - CUT FAIL: `Cannot upload "/cut/c.txt": The connection to the server was lost. (close: Error
    waiting for status message) (the temporary file .tcpart-0a1c25be could not be removed)`;
    the file stayed on the server. The second Copy of the row showed no dialog at all (to be
    looked at with the fixed build).
- **Hard links** (container, replay): `a.txt` + hard link `b.txt` ("OLD"); temp written "NEW",
  posix-rename over `a.txt` -> `a.txt` "NEW" (new inode 312765), `b.txt` "OLD" (312767, link
  count 1). Split, as the item says.
- **ACL / extended attributes**: no ACL tools in the container; by reading - SFTP version 3
  attributes carry neither, a new inode has none of the old file's.
- `BL verify` recorded.

## Decisions (autonomous run)

See spec *Clarifications* / *Assumptions*: links and ACL stated in the question; left temps
remembered in memory per session and offered at the next upload; drop route only on a
permission status; confirmation by acknowledgments only when the size request is refused with
a permission status.

## Analyze

- Run 1: HIGH F1 (spec edge case "the rest stay recorded" vs data model "nothing is put back"),
  MEDIUM F2 (SC-001 counted the guard row), MEDIUM U1 (negative control vague), LOW C1 (FR-004
  without a task). All fixed in spec / data-model / tasks.
- Run 2: no finding; coverage 100 % (10 requirements, 16 tasks).
