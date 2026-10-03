# Fix log: feature 103 - the source is never "the existing target"

Branch `103-same-file-delete-guard`, from `102-filecomp-unicode-names` (0f79f578).
Decisions by the author (maintainer away): `spec.md` *Clarifications*. Research and the
measurements behind every decision: `research.md`. Pre-change build:
`build\tandemcommander\Debug_x64_pre103` (`Debug_x64_pre101` deleted as asked).
Not committed (maintainer away).

## T003 - S1: the rule (`src/common/salsamefile.h`, new, header-only; `salfileio.{h,cpp}`)

| Piece | What it does |
|---|---|
| `CSalFileIdentity` | volume serial + 64-bit index (`GetFileInformationByHandle`), 64-bit serial + 128-bit id (`GetFileInformationByHandleEx(FileIdInfo)` - `FILE_ID_INFO` mirrored, the SDK hides it below `_WIN32_WINNT` 0x0602), link count, attributes, size, creation and last-write time |
| `SalGetFileIdentityW(path, linkItself, id)` | `CreateFileW(FILE_READ_ATTRIBUTES, share all, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS [| FILE_FLAG_OPEN_REPARSE_POINT for a rename])`; such an open ignores share modes and starts no WebDAV download (measured: PROPFIND only); falls back to `GetFileAttributesExW` (metadata, no id) |
| `SalFileIdMatch` | equal / different / unknown; 128-bit when both sides have it, else the 64-bit index; an all-zero or all-ones id is "no id" (WebDAV: 0); two different non-zero volume serials are "different" even without ids |
| `SalFileMetaEqual` | kind, size (files), last-write and creation time in whole seconds (a missing creation time is not compared) |
| `SalDecideExistingTarget(copy, err, src, tgt)` | rename/move: temporary name when the ids are equal, the identity is unreadable, or the metadata are equal whatever the ids say (review finding 4: file systems with per-path ids); legacy only when metadata differ and the ids are not equal. Copy: refuse when the metadata are equal and the ids are not different, except a source with more than one link (legacy, as before); legacy otherwise |
| `SalRenameViaTempName(src, tgt, move, ...)` (template over the move function) | `src` -> `salXXX` in the source's folder (8.3-compliant; a taken name is skipped; **never the source's or the target's own file name** - review finding 2) -> `tgt` without replace. Done / target is another entry (source renamed back) / failed (source back, error) / left at the temporary name (error, the path is reported) |
| `SalGetFileIdentity`, `SalRenameViaTempNameU8` (`salfileio`) | the UTF-8 facade (`SalPathToWExtAlloc`, `SalMoveFile` - long paths, Novell read-only handling) |

Project files: `salsamefile.h` listed in `salamand.vcxproj` (+ filters) and
`saltests.vcxproj`.

## T004 - S2: rename and move (`worker.cpp DoMoveFile`, `fileswn5.cpp RenameFileInternal`)

`DoMoveFile`, same-root branch, after the Novell retry and **before** the 8.3 tidy-up and the
overwrite/delete branch (both unchanged): on "already exists", when the names need no
trailing-backslash variant (the condition of the old branches, so invalid names stay as
before), read both identities (the link itself) and decide.
- temporary name, done -> `OPERATION_DONE` (archive attribute restored as after a plain move);
- target is another entry -> the old branches, unchanged (8.3 tidy-up, overwrite question,
  delete, retry);
- failed, the source back -> the move error dialog with the route's error (`NORMAL_ERROR`); the
  target is never touched;
- left at the temporary name -> its own dialog (the move error dialog with the temporary path as
  the file being moved), shown also after *Skip All*; Retry finishes the rename or renames the
  source back and starts the move over; Skip / Skip All / Cancel make one more attempt to give
  the source its name back (review findings 1 and the re-review note).

`RenameFileInternal` (Quick Rename): the same decision before both old branches, which now run
only when `keepTarget` is FALSE. Done -> `REN_OPERATION_DONE` (focus on the new name); failed ->
the error message; left at the temporary name -> a message with the error and the path (the path
alone if the text cannot be allocated), and the Quick Rename dialog is not offered again for the
vanished name (review finding 8).

*Change Case* and directory moves inside one root run through `DoMoveFile` and are covered.

## T005 - S2: copy (`worker.cpp DoCopyFile`; also every move between two roots)

At `CREATE_ERROR`, "already exists", before the overwrite question: the source's identity from
the open read handle (`in`; an overlapped handle works - saltests), the target's (through links),
`SalDecideExistingTarget(TRUE, ...)`. Refusal: the worker's error dialog (`WM_USER_DIALOG` 0)
with caption `IDS_ERRORCOPY` / `IDS_ERRORMOVE` ("Copy Error" / "Move Error", code page, as the
caption is set with `SetWindowText`) and text `IDS_CANNOTCOPYFILETOITSELF` /
`IDS_CANNOTMOVEFILETOITSELF` through `LoadStrU8` (the dialog shows that field as UTF-8). Retry
re-opens the target (`OPEN_TGT_FILE`), Skip / Skip All (its own flag
`CProgressDlgData::SkipAllSameFile` - review finding 5) skip the file with `skip = TRUE` (a move
between roots then does not delete the source), Cancel ends the operation. No new string.

## T006 - S3: plug-ins (no interface change, stays 107)

| Plug-in | Site | Change |
|---|---|---|
| Renamer | `rendlg3.cpp CRenamerDialog::MoveFile` (batch rename and its Undo) | the rule before the old overwrite (its guard was `SG->StrICmp`, the code-page byte fold); a failure goes to `FileError(IDS_MOVEERROR)`; left at the temporary name -> `SalMessageBox` (error + path) that *Skip All* cannot hide, then the file is skipped |
| Renamer | `CopyFile` (a rename into another root: copy, then delete the source) | refusal before the overwrite question, reported as `FileError(IDS_OPENFILEERROR)` with the system text of "already exists" (the plug-in has no "to itself" string; no new string); Retry -> `COPY_AGAIN`; the source is not deleted (review finding 3) |
| PictView | `render1.cpp CRendererWindow::RenameFileInternal` (rename of the viewed image) | the rule before the old overwrite (`SalamanderGeneral->StrICmp` guard); left at the temporary name -> message with the path, the rename is not offered again |

Both include `../../common/salsamefile.h` (wide API only, no TCHAR; compiles at 0x0601 and in
the plug-ins' MBCS builds).

## T007 - S4: saltests `TestSameFile103`

13,326 -> **13,425** checks, 0 failed. Rule tables (ids: 64/128-bit, all-zero/all-ones, volume
serials, unreadable; metadata: rounding, missing creation time, directories; the decision for
both operations: the same file, another hard link, a volume clone / constant id, per-path ids,
another file, WebDAV alias and twins, unreadable). The route on a fake file system that folds
like a macOS server (NFD = NFC, ASCII case, a folder alias): the defect's case, another file,
a locked source, a failing second step, a failing way back (path reported), taken temporary
names, all 4096 taken, no room for the name, **a source named `sal000` through a folder alias**
(review finding 2: without the skip the route would have called the source "another file").
Real NTFS files: hard link (one id, two links), the 8.3 short-name alias, an overlapped handle,
a directory, a missing file, the route on disk (another file; a plain rename). The temporary
folder comes from `GetTempPathW` (a non-ASCII `%TEMP%` works).

## T008 - the probe (`probe/samefile_probe.ps1`, `probe/davnorm.py`)

Hidden desktop, registry exported/restored/verified (SHA-256 identical after every run),
fixtures under `%TEMP%\tc103_sf` removed, the SUBST letter removed, the WebDAV server stopped.
`davnorm.py`: a WebDAV server on the Python standard library whose name lookup folds like a
macOS server (NFC/NFD + case = one entry; a plain case change of the same entry is allowed, as
real servers do); also reachable as `\\127.0.0.1@port` - one file under two server names.

23 cases, routes: qren = Quick Rename (754), mov = F6 (728), cpy = F5 (727); confirmations on
except dav-msil. `probe/samefile_result.txt` (this build, `-Expect103`: also the windows this
feature shows) **46 PASS / 0 FAIL**; `probe/samefile_result_pre103.txt` (`Debug_x64_pre103`)
**42 PASS / 4 FAIL - the four losses**. END rows: exit code 0, no stray window, no report, in
every case on both builds.

| Case | Alias / situation | Route | Pre-103: asked -> data | 103: asked -> data |
|---|---|---|---|---|
| dav-qren | NFD stored, NFC typed (folding WebDAV) | qren | overwrite (identical lines) + "(31) device not functioning" -> **lost** | nothing -> renamed `Café.txt` (server: MOVE to `salXXX`, MOVE to `Café.txt`) |
| dav-mov | same | mov | overwrite + "Error Moving File" -> **lost** | nothing -> renamed |
| dav-msil | same, *Confirm file overwrite* off | mov | only the error -> **lost** | nothing -> renamed |
| dav-xmov | one file, two server names | mov | overwrite -> copy onto itself, source deleted -> **lost** | "Cannot move a file to itself." -> kept |
| dav-xcpy | same | cpy | overwrite x.txt with x.txt -> kept (rewritten onto itself) | "Cannot copy a file to itself." -> kept, untouched |
| dav-norm | another file | mov | overwrite -> overwritten | the same |
| dav-twin | another file, equal size and times | mov | overwrite -> overwritten | the same (server: the route tried, saw the target survive, renamed back, then the old overwrite) |
| dav-twcp | another file, equal size and times | cpy | overwrite -> overwritten | "Cannot copy a file to itself." -> both kept (**the documented false refusal**) |
| junc-mov | junction alias of the folder | mov | nothing (NTFS no-op) -> kept | the same |
| junc-cpy | junction alias | cpy | overwrite + "Error Deleting File (32)" -> kept | "Cannot copy a file to itself." -> kept |
| subst-mov / subst-cpy | SUBST letter | mov / cpy | overwrite + "Error Deleting File (32)" -> kept | "Cannot move/copy a file to itself." -> kept |
| unc-mov / unc-cpy | `\\localhost\C$` | mov / cpy | overwrite + "Error Deleting File (32)" -> kept | "Cannot move/copy a file to itself." -> kept |
| hl-qren / hl-mov | hard link `b.txt` of `a.txt` | qren / mov | nothing (NTFS renames link onto link) -> `b.txt` | the same |
| hl-cpy | hard link | cpy | overwrite -> independent copy | the same (old handling kept for links) |
| cs-qren | case-sensitive folder, `a.txt` and `A.txt` two files | qren | "(183) already exists" -> both kept | the same |
| 8dot3-qren | own 8.3 name | qren | nothing (no-op) | the same |
| case-qren | plain case change | qren | nothing -> `A.txt` | the same |
| norm-qren / norm-mov / norm-cpy | another file | qren / mov / cpy | overwrite -> overwritten | the same |

Not driven: PictView's rename. Measured on **both** builds: the viewer keeps the shown image
open, so its Rename fails with error 32 (sharing violation) before any "already exists" - on
NTFS and on WebDAV; the probe's viewer route is kept for when that is fixed (recorded below).
The Renamer plug-in has no GUI driver.

## T010 - gates (final tree)

| What | Result | Baseline (102) |
|---|---|---|
| Debug build; `build.cmd full release` (20 plug-ins, 189 language modules, runtime closure OK) | no errors | - |
| saltests | **13,438 checks, 0 failed** (13,425 before the second review) | 13,326 |
| `check_encoding.py --strict` | TOTAL: 0 | 0 |
| `probe/samefile_probe.ps1` | 62 / 0 (pre-103: 55 / 7) after the second review; 46 / 0 (42 / 4) before it | - |
| 092 `build_and_run.cmd` (case_only, path_identity) | ALL PROBES PASSED (82 rows, 0 failed) | same |
| 092 `focus_probe` (old = `Debug_x64_pre103`, new = this build) | new 10/10 PASS; old identical to new (its 3 "UNEXPECTED for the old build" rows are 092's fixed defects, already in the pre-103 build) | - |
| 095 `longarc_probe` | 60 PASS / 0 FAIL, Debug handle notes 4 | same |
| 096 `archedit_probe` | 17 of 17 UPDATED, 0 retries | same |
| 098 `fix_probe` | 107 PASS / 0 FAIL / 3 not driven / 1 INFO | same |
| 099 `linkmove_probe` | 24 PASS / 0 FAIL | same |
| 101 `leftovers_probe -Expect fixed` | 20 PASS / 0 FAIL / 4 not driven (clipboard) | same |

After the second review's fixes the Debug build, saltests, the guard, the samefile probe (both builds), 096, 098, 099 and 101 and the full Release build (exit 0, no error lines) were run again on the final tree; 092 and 095 are from the round before (the change since touches only a link moved onto its target). Registry SHA-256 identical after every run (`1AB61430...F769`); nothing left running; fixtures,
the SUBST letter and the WebDAV server removed. Results: `probe/regress_*_103.txt`,
`probe/regress_focus092_103.txt` (the hidden-desktop log; its Czech UI text is in the code page).

## T009 - independent review

First pass: no blocker; 4 SHOULD-FIX, 5 NOTE - all SHOULD-FIX fixed, re-review **ACCEPT** on
every item:

| # | Finding | Disposition |
|---|---|---|
| 1 | left at the temporary name: hidden after *Skip All*, Retry could never work | own dialog loop / messages (T004, T006) |
| 2 | a source named like a temporary name (`sal0AB`) through a folder alias: "rename onto itself" succeeds, the self-check then takes the source for another file -> the old branch deletes it | candidates equal to the source's or target's name skipped; saltests case |
| 3 | Renamer's copy between roots unguarded (WebDAV alias: copy onto itself, then delete) | refusal (T006) |
| 4 | a move trusted "ids differ" (per-path ids of FUSE/WinFsp/Dokan mounts) | equal metadata now take the self-checking route whatever the ids say |
| 5 | false refusals without ids; *Skip All* shared with "cannot open target" | own flag `SkipAllSameFile`; the false-refusal window recorded below |
| 6 | a copy onto a symbolic link that points at the source is now refused (before: the link was replaced by a real copy on NTFS) | accepted as correct (it is the same file), recorded |
| 7 | "more than one link -> old handling" relies on share modes being shared between two paths of one link | recorded |
| 8 | Quick Rename re-opened for a vanished name | fixed (T004) |
| 9 | test gaps (`GetTempPathA`, overlapped handle, the `sal###` case) | added |
| re-review | a cancel while the left-at-temporary dialog cannot be shown left the file there silently | one last attempt to rename it back on Skip / Cancel |
| re-review | two different files with equal metadata (a backup that kept its times) now take two extra renames before the overwrite question, even if the user then answers No: the folder's time changes and NTFS may give the source a new 8.3 short name | recorded (the price of finding 4) |

## Second independent review (ACCEPT) and its fixes

Verdict ACCEPT: no path where 103 deletes something the build before kept; the probe 46/0
reproduced; its own adversarial cases (second rename and the way back refused -> the file stays
at `salXXX`, nothing deleted; a target created between the two steps -> safe).

**SHOULD-FIX 1, fixed - a symbolic link renamed or moved onto the file it points at deleted
that file (both older builds).** A rename compares the link itself (`linkItself`), so link and
target counted as two files; the overwrite question showed two identical lines (read through
the link), Yes deleted the real file and moved the link into its name - a link to itself (error
1921). Now `SalLinkPointsAtTarget(src as link, src read THROUGH the link, tgt)` runs first
(only when the source is a reparse point) in `DoMoveFile` (refusal through the worker's error
dialog: "Move Error" / "Cannot move a file (directory) to itself.", Retry / Skip / Skip All -
`SkipAllSameFile` - / Cancel), `RenameFileInternal` (message "Cannot move a file (directory) to
itself."), Renamer `MoveFile` and PictView's rename (reported as "already exists": the plug-ins
have no such text). Measured mirror and variants (probe rows, both builds):

| Case | Route | Pre-103 | 103 |
|---|---|---|---|
| sl-qren: `lnk.txt` (symlink -> `a.txt`) renamed to `a.txt` | Quick Rename | overwrite (identical lines) -> `a.txt` became a link to itself: **lost** | "Cannot move a file to itself." -> kept |
| sl-mov: the same | F6 to `...\a.txt` | **lost** | "Cannot move a file to itself." -> kept |
| slt-qren / slt-mov: `a.txt` renamed onto `lnk.txt` (the link points at the source) | Quick Rename / F6 | overwrite -> only the link deleted, `a.txt` becomes `lnk.txt`: kept | the same (old handling: correct) |
| sl-cpy: `lnk.txt` copied onto `a.txt` | F5 | overwrite, then the sharing error -> kept | "Cannot copy a file to itself." -> kept |
| slt-cpy: `a.txt` copied onto `lnk.txt` | F5 | overwrite -> the link replaced by an independent copy: kept | "Cannot copy a file to itself." -> kept (link kept) |
| jn-qren: junction `J` (-> `F`) renamed to `F` | Quick Rename | "(183) already exists" -> kept | "Cannot move a directory to itself." -> kept |
| jn-mov: `J` with `F` as the F6 target | F6 | moved INTO `F` (`F\J` -> `F`, a loop), nothing asked -> kept | the same |

`probe/samefile_result.txt` **62 PASS / 0 FAIL** (31 cases); `probe/samefile_result_pre103.txt`
**55 / 7**: the six losses (dav-qren, dav-mov, dav-msil, dav-xmov, sl-qren, sl-mov) and slt-cpy
(no loss; the old build replaced the link by a copy, which that row's check does not accept).
saltests: rule rows and a real symbolic link (`CreateSymbolicLinkW`, unprivileged flag; skipped
with a message when it cannot be created) - **13,438 checks, 0 failed**.

**NIT 2 - Renamer's refusal**: it now has its own skip state (`CRenamerDialog::SkipAllSameFile`,
reset with the others in `ExecuteScript` and `Undo`), used by the copy refusal and the new link
refusal. The text stays "cannot open file ... already exists" / "move error ... already exists":
**the core's "Cannot copy/move a file to itself." strings live in the core's language module,
which a plug-in cannot reach through interface 107** (`LoadStr` needs the module handle; no
service returns the core's) - using them needs an interface change or a new plug-in string, both
excluded. Recorded.

**NIT 3 - CHANGELOG**: corrected - a move within one drive through a junction was always
harmless (Windows leaves the file where it is, probe junc-mov); the refusal is for copies and for
moves to another drive letter or server name of the file; the symbolic-link fix added.

**Recorded only (also in NEXT-WORK where a gap):**
- NIT 1: "left at the temporary name" is shown through the ordinary move-error dialog (the
  temporary path as the file being moved; no new string); a failed final rename-back on Skip /
  Cancel is only traced.
- NIT 4: moving a FOLDER onto an alias of itself between two roots (`C:\x\F` ->
  `\\localhost\C$\x\`) still deletes its EMPTY subfolders, on both builds (the files are refused;
  no data lost) - a folder-level identity check for moves between roots is missing.
- NIT 5: a hard link reached through an alias still gets "overwrite x with x?" and then error 32;
  the reviewer measured that NTFS refuses to delete the same link through UNC while it is open, so
  the link-count exemption is safe on NTFS; other servers unverified.

**The CLAUDE.md entry** was written by the coordinating session (the maintainer adds one per
feature through it); its text is the proposal below.

## Recorded, not changed

- **A real macOS (smbx) or Samba share was not driven** - nothing here can say whether such a
  server answers the NFC/NFD rename with "already exists" (the defect's premise) or performs
  it; the WebDAV server reproduces the answer, not the product. Expected on such a share: the
  rename goes through `salXXX` (macOS returns stable file ids - "same" - and the route is
  taken), never a deletion. Owed to a person with the hardware (`quickstart.md` step 6).
- **False refusal of a copy** on a file system without file ids (WebDAV): a *different* file
  with the same size and the same last-write and creation seconds is refused as "Cannot copy a
  file to itself." (probe dav-twcp). Nothing is lost. A move is not affected (dav-twin).
  A local NTFS source copied onto such a target refuses the same way when the server keeps the
  creation time.
- A copy onto a symbolic link that points at the source is refused (review 6).
- Hard links on a file system whose two paths to one link do not share share-mode state (review
  7): a copy onto another spelling of the same link with link count > 1 keeps the old handling.
- The ZIP plug-in's self-extractor / multi-volume creation overwrites a selected source when the
  new archive's file has its name and the user confirms - another defect class (no alias needed).
- A case-sensitive folder still refuses `a.txt` -> existing `A.txt` (092's case-only guard); the
  identity now proves they are two files, so the overwrite could be offered - a behaviour change
  left for a decision.
- `DoCreateDir`'s "name already used" message passes the code-page `LoadStr(IDS_NAMEALREADYUSED)`
  into the UTF-8 error field of `CFileErrorDlg` (non-ASCII translations garbled) - pre-existing,
  noticed while choosing `LoadStrU8` for the new refusal.
- **PictView's Rename cannot rename the image it shows** (error 32, sharing violation; both
  builds, NTFS and WebDAV, PNG through the WIC engine) - pre-existing, found while writing the
  probe; so the plug-in's new code was compiled and reviewed but not driven. The Renamer's batch
  dialog has no probe driver either.
- Side effects of the self-checking route (review re-review): two different files with equal
  size and times (a backup that kept its times) take two extra renames before the overwrite
  question - the folder's time changes and NTFS may give the source a new 8.3 short name even if
  the user answers No; a directory whose rename the route attempts while it is in use reports
  the sharing violation instead of "already exists".

## CLAUDE.md entry

- 103-same-file-delete-guard: **the source is never "the existing target".** A rename or
  move that met "already exists" decided by the NAMES that the target was another file and
  deleted it; on a server that folds more than Windows (NFC/NFD on macOS) the target was the
  source. Reproduced without a Mac: `specs/103-.../probe/davnorm.py`, a standard-library WebDAV
  server folding like macOS (the redirector answers such a rename with 183; WebDAV reports file
  id 0) - the build before 103 **deleted the file** on Quick Rename, F6, F6 without the overwrite
  question, and F6 between `\\localhost@port` and `\\127.0.0.1@port` (copy onto itself, then
  the source deleted - nothing blocks `CREATE_ALWAYS` on a WebDAV alias). NTFS itself answers
  success for its own aliases (hard link, 8.3 name, junction); copies onto SUBST / `\\localhost\C$`
  / junction aliases survived only by the source's share mode (after "overwrite x with x?").
  Rule, header-only `src/common/salsamefile.h` (+ UTF-8 facade in `salfileio`): identity = volume
  serial + file id (128-bit `FileIdInfo` mirrored for 0x0601) from a `FILE_READ_ATTRIBUTES`
  open, metadata when there is no id; rename/move onto (possibly) itself -> **self-checking
  temporary name** (`src` -> `salXXX` -> `tgt`; if the target survives, it is another file and
  the old handling follows; never the source's own name as the temporary one); copy (and a move
  between roots) onto itself -> "Cannot copy/move a file to itself." (existing strings, own
  Skip All). Sites: `DoMoveFile`, `RenameFileInternal`, `DoCopyFile`, Renamer `MoveFile` +
  `CopyFile`, PictView rename; a symbolic link / junction moved onto what it points at is refused
  (it deleted the file before - second review). No new string, interface 107. Probe 62/0
  (pre-103 55/7: six losses); saltests 13,326 -> 13,438. Review: 4 SHOULD-FIX fixed, re-review ACCEPT. Records:
  `specs/103-same-file-delete-guard/fix-log.md`.
