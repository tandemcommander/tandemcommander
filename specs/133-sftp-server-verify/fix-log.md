# Fix log: feature 133 - SFTP checked against a server; a listing that ends early is an error

Branch `133-sftp-server-verify` from `132-pictview-thumbnail-verify`. Session 2026-10-13, asked
for by the maintainer ("do all four", point 2). Spec Kit order: `spec.md`, `plan.md`,
`research.md`, `tasks.md` were written before the first line of code.

## 1. The probe

`probe/sftp133_probe.ps1` drives the plug-in in the program on the hidden desktop against the
container `tandem-sftp` (`localhost:2222`): the address is typed into Change Directory, the
password dialog is answered, the row's command is posted (the core's Copy 727, Move 728,
Delete 729, Create Directory 730), every dialog is answered and kept, and then the state of the
server (`probe/fixture133.sh state` through `docker exec`) and of the local target folder is
compared. Fifteen rows, each its own start of the program.

## 2. Measured before any change

| Row | 0.1.9 (`probe/sftp133_result_before_v019.txt`) | build of 131 / 132 |
|---|---|---|
| R1 delete in a read-only directory | `Cannot delete "...": ` - **no reason** | `...: Permission denied.` |
| R2 create a directory there | no reason | `Permission denied.` |
| R3 download an unreadable file | no reason | `Permission denied.` |
| P1 go to a link to a directory 2,900 bytes deep, create a directory with a 250-byte name | the panel is at the resolved path, **cut**; **the new directory has a name of 155 bytes** | the panel is at `.../p1/deep`; the name has 250 bytes |
| P5 / P5M download / move a tree whose files would get local names beyond 4,095 bytes | **a file is stored under a shortened name** | "Unable to finish operation because of too long path.", nothing stored, nothing deleted |
| P4 delete a tree with files beyond the server's own limit | 17 messages, **none with its reason** | 17 messages, **12 without their reason** (the path fills the 1,200-byte message) |
| M1 move a directory of 30 files | 30 files local, **30 files and the directory still on the server**, no message | the same |
| M2 move one file | moved | moved |
| URL `sftp://user@host:port/path` | "A host name is missing in the path specified." | the same |
| LISTCOPY / LISTMOVE (seam, old logic: `probe/sftp133_result_list_before_fix.txt`) | - | **9 of 30 files copied, no message**; the server keeps all 30 |
| LISTPANEL | - | the panel shows 9 entries as the whole directory, no message |

What this settles:

- **The SFTP fixes of 131 work in the program** (R1-R3, P1, P5, P5M): on 0.1.9 a file was stored
  under a cut name and a directory was created with a cut name.
- **A move does not delete what it did not download** (research R2 confirmed): the recommendation
  that named this "the second place where data may be at stake" was wrong. A move of a directory
  never removes the directory at all - M1 (recorded, not changed here; `specs/NEXT-WORK.md`).
- The 131 rows P4 / P5 as written (files beyond 4,095 bytes of **remote** path) cannot be reached
  with OpenSSH: its `sftp-server` does not list a name whose full path passes its own `PATH_MAX`
  (4,096), which is the plug-in's limit too. The refusal of a remote join is covered by the unit
  harness only; P5 / P5M reach the **local** join instead (a long target folder).
- R4 (upload into a read-only directory), R5 (stale reason after a failed Quick Rename), P2 / P3
  with Quick Rename: not driven - they need the other panel as the source or the in-place edit
  line; owed to a person (`quickstart.md`).

## 3. Fixed

- **A listing that did not reach its end is a failure** (`session.cpp` `ListDir`,
  `SftpReadDirStep` in `sftputils.cpp`): a failed read and low memory left the loop like the end
  of the directory did. Copy and move of such a directory end with "Cannot list directory
  "...": reason" and copy nothing from the part that was read; the panel goes back to the
  parent directory instead of showing a part as the whole. A stop by the user stays a cancel
  (and is no longer "fully transferred" for a move).
- **A directory is removed only when every item of it is known to be gone** (`operats.cpp`
  `DeleteRecursive`): after a failed listing, a skipped item or a failed delete of an item the
  server was still asked to remove the directory (it refused - the server's rule, not ours),
  and every level above added a message of its own. P4: 17 messages before, 1 now.
- **An error message is never cut** (`SftpFormatMsgAlloc`, `SFTPShowPathError`): ten messages
  were composed in 1,200 bytes - with a long path the path was cut and the reason lost (P4).
- **`sftp://user@host/path` is accepted** (`ParseUserPart`).
- Recursive chmod / chown write a directory they could not list into the log.
- An empty error text of the SSH library reads "unknown error".

## 4. The seam

`TC_SFTP_PROBE_LIST_FAIL = "<path suffix>;<entry>;<times>"`, debug builds only
(`session.cpp` `ProbeListFailAt`): the read of the given entry of a matching directory fails
for the first `<times>` listings. It was built in first, with the old logic, so "before" and
"after" of the LIST rows come from the same tree. With the seam the reason reads "readdir:
libssh2 error -30" (the library has no error of its own then - see the review, finding 2).

## 5. Independent review (read-only, refute-first) - no loss, no overrun, no crash found

Four defects it named, all fixed:

1. `DeleteRecursive` still sent `Rmdir` for a directory whose listing had failed - "contents not
   verified" followed by a destructive request (not a regression, but rewritten here and against
   FR-004). Now: no request; and generally no `Rmdir` unless every item is gone (section 3).
2. **The reason of a failed read could be stale**: libssh2 returns
   `LIBSSH2_ERROR_BUFFER_TOO_SMALL` (a name over 2,047 bytes - the case this feature names
   first) without recording an error, so the session's last error was that of some earlier call.
   The session's text is used only when its code is the call's code; a name that does not fit
   says "too long path"; anything else "readdir: libssh2 error N".
3. Recursive chmod / chown skipped a subtree whose listing failed without a word - logged now.
4. "Every caller looks at the cancel flag" was not true: `DownloadDir` returned "fully
   transferred" after a stop inside a listing, and a move then asked the server to remove the
   directory. Fixed (`xrFailed`). `ListCurrentPath` shows what was read before the user's stop
   as the panel - old behaviour, kept and recorded.

Recorded, not changed: an empty name / empty NAME packet from a broken server reads as "end"
(the library's interface cannot tell); a transient read error during a refresh now leaves the
panel one level up (the route an `opendir` failure always took).

Found sound: every exit of `ListDir`; no caller uses partial entries on failure; the move path
deletes only after `xrOk`; all eight templates in English and in the 11 translations have
exactly the inserts passed (`%s` twice, or once); the ten converted message sites keep parent,
template, arguments and the one log line; `//` changes no address that worked before; the seam
cannot be in a Release build.

## 6. Final runs

| What | Result | Record |
|---|---|---|
| probe, final build, `-Expect fixed` | PASS 30, FAIL 0, NOT DRIVEN 0 (15 rows) | `probe/sftp133_result.txt` |
| probe, 0.1.9 | section 2 | `probe/sftp133_result_before_v019.txt` |
| LIST rows with the seam and the old logic | 9 of 30 files, no message | `probe/sftp133_result_list_before_fix.txt` |
| SFTP unit harness | 101 passed, 0 failed (16 new) | `src/plugins/sftp/test/` |
| saltests / `tools/check_encoding.py` | 18,567 checks, 0 failed / `TOTAL: 0` | |
| regression probes 130 (Czech), 131 | 19 / 0; 2 / 0 (before the review fixes, which are inside the SFTP plug-in) | |
| `build.cmd full`, `build.cmd full release` | clean | |
| product registry key | identical before and after every run | |
