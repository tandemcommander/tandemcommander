# Fix log: feature 119 - the leftovers of the packing fixes

Branch `119-packing-leftovers`, from `118-plugin-update-close` (ea528c45). Decisions by the author
(the maintainer asked for autonomy): `spec.md` *Clarifications*. Research (code reading - no GUI run
was allowed this session): `research.md`. Pre-change build: `build\tandemcommander\Debug_x64_pre119`
(byte-identical to `Debug_x64_118`); this build for the GUI runs: `build\tandemcommander\Debug_x64_119`.
Not committed.

## Measured first (by reading - the GUI measurement is the pending probe)

- **Item 1**: `PackMultiVol` deleted only `TempName`, the current volume. Every failure after volume
  1 (a source that cannot be opened + Cancel, Cancel in the progress, a declined "Overwrite a.z0n?",
  106's refusal at volume n, a full disk) left volumes 1..n-1 - a set nothing opens. 106's own probe
  rows D-later state it ("volumes 1-3 of the refused archive stay").
- **Item 2**: the last volume's `MoveFileU8(name, ZipName)` never replaces and its result was not
  checked: with `name.zip` existing (the core's question answered *Add*, or switched off) the set
  ended with `name.z0N` and a **Move deleted the sources** (the pack "succeeded"). The plug-in has a
  translated text for exactly this, `IDS_CANTMULTIVOL`, whose use was commented out in
  `PackToArchive`.
- **Items 3, 4**: the core's three routes into a packer (Pack dialog, F5 / F6, drag & drop / paste)
  never asked whether the existing archive is one of the sources; only 106's *Overwrite* answer did.
  ZIP: a sharing violation per such file; 7-Zip: the old archive packed into the new one, Move then
  "Delete Error (32)" (106 B / H rows).
- **Item 5**: no core string with `%s` says "to itself"; `CFileErrorDlg` with `IDD_ERROR3` shows a
  file's name beside any error text.
- **Found on the way** (fixed with item 1): the 106 clean-up ran on any `ErrorID`, including a
  Move's `CleanUpSource` failure (low memory in `InsertDir`, after sources were deleted) - it then
  deleted the current volume, which with WinZip names off is the archive's last volume holding the
  deleted sources' data. Now nothing is deleted once the archive is complete.

## T004 - the rule (`src/common/salpackvol.h`, header-only, pure)

| Piece | What it does |
|---|---|
| `CSalPackCreatedFiles` | the volumes one pack created: UTF-8 name + `CSalFileIdentity` (from the creating handle); `Add` FALSE on low memory |
| `SalPackVolCleanupScope(failed, outputComplete, removable)` | nothing (success, or the archive complete) / the volume still being written (removable media, under the identity rule) / every recorded volume (fixed or network disk) |
| `SalPackCreatedMayDelete(created, sizeKnown, size, nowExists, now)` | the same id: yes (unless both creation times are known and differ); another id (another file took the name, another disk): never; gone: nothing to do; no usable ids: only a file (no folder, no link) with the recorded, non-zero creation time and the size this operation wrote - else kept (code review SF1; the first version deleted by name) |
| `SalMultiVolFinalNameTaken(sfx, seqNames, winZipNames, removable, exists)` | refuse before creating: the last volume will be renamed to an existing name (fixed disk, sequential + WinZip names, no self-extractor) |

saltests `TestPackLeftovers119`: the list (growth past 8, own copies, UTF-8 byte for byte, Clear),
the scope table, the delete decision (same file written since, another file, another disk, gone,
no ids, unreadable handle, no ids on two volumes), the rename decision (6 rows), and real NTFS in
`%TEMP%`: a volume recorded from its handle, the name then taken by another file (never deleted),
the name gone, the moved volume still "the same file". **14,576 -> 14,639 checks, 0 failed**
(14,655 after the code review's SF1 rows, T015).

## T005 / T006 - ZIP plug-in (`add.cpp`, `add_del.{h,cpp}`)

- `PackMultiVol`: first `SalMultiVolFinalNameTaken(..., SalGetFileAttributes(ZipName) !=
  INVALID_FILE_ATTRIBUTES)` -> `ProcessError(IDS_CANTMULTIVOL, 0, ZipName, OK only)`,
  `IDS_NODISPLAY`, nothing created. Then a local `CSalPackCreatedFiles` published through
  `CreatedVolumes` by a scope guard (NULL again on every return).
- `CreateNextFile`: after its own successful `CreateFileU8` (`CREATE_NEW`, or `CREATE_ALWAYS` after
  *Yes* / *All*) the volume is recorded with `SalFileIdentityFromHandle`; if recording fails (low
  memory) the file is closed and deleted and `IDS_LOWMEM` returned - never an unrecorded volume. The
  self-extractor's second pass (`OPEN_EXISTING`) records nothing (106 N3).
- The final rename: `_strdup` failure -> `IDS_LOWMEM` (was: the rename silently skipped);
  `MoveFileU8` failure -> `IDS_CANTMULTIVOL` (exists) or `IDS_ERRCREATE` + system text, with
  `ZipName`, `ErrorID = IDS_NODISPLAY`: no Move deletion, the set is deleted.
- `outputComplete` set when the archive is finished (after the rename / the self-extractor's
  directory), before `CleanUpSource`.
- The clean-up moved out of the `if (!ErrorID)` after volume 1 (nothing is recorded when volume 1
  failed) and decided by `SalPackVolCleanupScope`; `DeleteCreatedVolumes(all)`: removable media ->
  `TempName` if `TempNameOurs` (unchanged); else every recorded volume, newest first, identity
  re-read with `linkItself` and deleted only by `SalPackCreatedMayDelete`. `TempFile` is set to NULL
  after its close.
- Unchanged: `PackNormal`, `PackSelfExtract`; the SFX exe of `PackMultiVol` + SFX is not recorded
  (unreachable - no SFX package).

## T007 - core (`fileswn7.cpp`, `fileswn8.cpp`, `fileswna.cpp`, `fileswnd.h`)

- `PackArchiveIsSelectedSource` (106) is no longer `static`; declared in `fileswnd.h`.
- `ShowPackIntoItselfRefusal(parent, archive, move, caption)`: `CFileErrorDlg(..., IDD_ERROR3)` -
  Name: the archive (UTF-8, `CStaticText`, path ellipsis), Error: `IDS_CANNOTCOPYFILETOITSELF` /
  `IDS_CANNOTMOVEFILETOITSELF`, OK.
- Pack dialog: right after `SalGetFullName`, before the Move link scan and the "Add or Overwrite?"
  question: refused with caption "Pack", back to the dialog (`_PACK_AGAIN`). 106's check in the
  *Overwrite* branch kept as a guard, now with the named box ("Error Overwriting File").
- F5 / F6 (`FilesAction`): after the 099 link scan and `*secondPart = 0`, before the zero-size
  archive is deleted: refused with "Copy Error" / "Move Error", the operation ends (the 099 exit
  sequence).
- Drag & drop / cut + paste (`DragDropToArcOrFS`): after the 099 link scan: refused the same way;
  the operation ends through the existing path.

## T008 / T009 - gates

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | succeeded, 0 errors; the known `zip.cpp(5913)` C4244 warning when the core recompiles |
| saltests | **14,639 checks, 0 failed** (14,576 before; 14,655 after T015) |
| `python tools\check_encoding.py --strict` | TOTAL 0 |
| clang-format on the changed regions | clean (two alignment findings in the new test and the constructor line fixed with `--lines`; the saltests include block's alignment finding is pre-existing) |
| full Release build (`build.cmd full release`) | exit 0, BUILD SUCCEEDED, 0 errors, no compiler warning (the 46 MSBuild "Remote deployment might be slow" notices), 189 language modules, runtime closure OK (218 modules) - built twice, the second time after the formatting fix |
| files | sources UTF-8 BOM + CRLF as before (saltests.cpp: no BOM, CRLF, as before); no control characters; the new header BOM + CRLF |
| `PRIVACY.md` | unchanged - nothing new is stored, sent or written |
| strings / translations | none added (`IDS_CANTMULTIVOL` existed in all 11 language sources) |

## T010 - Review (hostile re-read of the diff)

- **Never a file this operation did not create**: only `CreateNextFile`'s own successful create
  records; the name is deleted only while its id equals the recorded one; a declined, refused or
  reopened name is never recorded; removable media keep the current-volume rule. A pre-existing file
  overwritten after *Yes* is deleted with the set - decided (spec), as 106 already did for the
  current volume.
- **Move never deletes after a refused / failed pack**: the core's refusals return before any
  packer; in the plug-in `CleanUpSource` runs only with `!ErrorID && !UserBreak`, and the failed
  rename now sets `ErrorID` before it. Once the archive is complete nothing is deleted
  (`outputComplete`), so a clean-up failure cannot cost the archive (the old code could).
- **The refusal comes before every side effect** on each route: before the Move link scan and the
  question (Pack), before the zero-size archive's deletion (F5 / F6, drag & drop).
- `goto _PACK_AGAIN` jumps backwards over the dialog's construction (as 106's) - legal, the dialog
  is rebuilt.
- Low memory: `PackArchiveIsSelectedSource` refuses (fail closed, as 106); recording a volume fails
  -> the volume is deleted and the pack fails; deleting the set without memory leaves a volume
  rather than deleting unchecked.
- Not changed, noticed: `WriteSFXCentralDir` ignores `CreateNextFile`'s result (`if (ret) ret;`)
  and writes through a NULL `TempFile` if the reopen fails - SFX only, unreachable; recorded.
- Process slip: one `sed -i` was used on `quickstart.md` (a one-number correction) against the
  project rule; the file was verified afterwards (LF, no control characters, content as intended).

## T011 - probe `probe/packleft_probe.ps1` (written, parse-checked, NOT run)

106's `packself_probe.ps1` extended: every 106 row with the 119 expectation (A: refused before the
question, the "Name:" form; B / H: refused; C: no volume created; D / E: no volume of the abandoned
set left), plus L (a later source held open by the probe, the error cancelled - no `m.*` volume
left; files in `out` the pack did not create byte-identical; "Overwrite m.z01?" Yes then the failure
-> `m.z01` gone), K (multi-volume into an existing `k.zip`: Add / Move / question off / Czech name
refused with "only like a new archive", nothing created; Overwrite -> the set renamed to `k.zip`),
Czech (CP1250) names on B, F, H, L, K rows, and H-7z-dir-copy (the archive inside a selected folder).
52 instances, 104 RUN + END rows, 5 NOT DRIVEN (after T015: 55 instances with the three paste
rows P, 110 RUN + END rows). Results read with 7z.exe (Python's `zipfile` cannot
read split sets). Commands and the expected table: `quickstart.md`.

Probe limit: the archive's name in the refusal is drawn by `CStaticText`, which does not answer
WM_GETTEXT - the probe checks the "Name:" form, a person sees the name (`quickstart.md` by hand).

## T015 - code review (ACCEPT pending GUI, no blocker) - all fixed

- **SF1** (`salpackvol.h`): `!= simDifferent` deleted on "unknown" - on a share without file ids
  (or with an identity that could not be read at creation) a file another process put under a
  volume's name during a long pack would have been deleted by name. Now *keep when unsure*: without
  usable ids only a file with the recorded, non-zero creation time and the recorded size; the same
  id also needs equal creation times when both are known. Sizes: `NoteVolumeSize` records the size
  on disk when a volume this operation writes is closed (`NextDisk`, the rename, the final close;
  `CSalPackCreatedFiles::SetLastSize`). An identity the handle does not give is re-read by name at
  once (`SalGetFileIdentityW(name, TRUE)` - a `FILE_READ_ATTRIBUTES` open ignores our share mode 0);
  still nothing -> never deleted. saltests rows rewritten (they asserted deletion by name) +
  witnesses: equal / other size, other / missing creation time, folder, link, unreadable either
  side, two volumes; real NTFS rows with the ids stripped.
- **SF2** (`add.cpp`): `NextDisk` closed volume n and showed "insert the next disk" while
  `TempNameOurs` was still true; *Cancel* then deleted `TempName` on the NEW disk (sequential names
  off: the user's `name.zip`). `NextDisk` now clears `TempNameOurs` right after closing the volume,
  and the removable clean-up deletes the most recent recorded volume only while `TempNameOurs`, its
  name equals `TempName` and `SalPackCreatedMayDelete` agrees (another disk = another volume serial:
  kept). Wording fixed in the header, `add_del.h`, the spec (FR-002), CHANGELOG and NEXT-WORK.
- **SF3**: the probe refuses the Default / Winlogon desktop (as `zipskip_probe.ps1`), and so does
  `098-long-path-overruns/probe/fix_probe_lib.ps1` for every probe that dot-sources it. Measured:
  `exit` inside a dot-sourced file ends only that file (the probe went on) - the library ends the
  process (`[Environment]::Exit(3)`) before anything is touched; opt-out for a run the maintainer
  agreed to watch: `TC_PROBE_ALLOW_VISIBLE_DESKTOP=1`. Checked on the visible desktop: the library
  refuses with exit 3, the opt-out loads it; the probe itself stopped at its earlier "another
  tandemcommander.exe is running" check (a `Debug_x64_113` instance of another agent) - nothing
  started.
- **SF4**: rows P-zip-cutpaste, P-7z-copypaste, P-zip-cz-cutpaste - copy / cut (773 / 774) in the
  left panel, Change Directory of that panel into the archive, paste (775): the drag & drop route
  (`DragDropToArcOrFS`). They need the clipboard, which 098 / 101 / 107 could not open from the
  hidden desktop - then NOT DRIVEN; by-hand step 2b in `quickstart.md` (a real drag and a Ctrl+X /
  Ctrl+V). The clipboard's text is saved and restored (`Save-Clip` / `Restore-Clip`).
- **SF5** (`fileswn7.cpp`): `PackArchiveIsSelectedSource` opened every selected item on the UI
  thread (no wait window, no Esc). Pre-filter when certain: the archive has usable ids and one
  link, and the folder of its resolved path is read - not the panel folder: no plain (non-link)
  file can be it; the panel folder: only the item with its long or 8.3 name. Folders, links and
  uncertain cases (no ids, hard links, unreadable folders) keep the per-item check; low memory
  still refuses.
- **NITs**: the archive's folders now come from the typed AND the resolved path
  (`SalGetFinalPathU8Alloc` - a junction or SUBST letter in the typed path hid the real parents) -
  fixed. `DetectRemovable` (`zip/common.cpp`): measured `GetDriveType("")` = `DRIVE_NO_ROOT_DIR`
  (not the current directory's drive, as the review assumed) and `GetDriveType("C:")` = the same
  as `"C:\"`, so UNC paths were already "not removable"; but `\\?\X:\` paths were too, and the root
  was copied unbounded into `MAX_PATH` - now `X:\` is asked (also behind `\\?\`), UNC is never
  removable - fixed. Deleting all recorded volumes on removable media (safe with the identity rule)
  - not done, untestable here, recorded. FAT slot reuse - negligible, recorded.

Gates after the review fixes: Debug build 0 errors, 0 warnings; saltests **14,655 / 0**; strict
guard TOTAL 0; clang-format clean in the changed regions (the saltests include block finding is
pre-existing); full Release build BUILD SUCCEEDED, 0 errors, no compiler warning (46 "Remote
deployment" notices), 189 language modules, runtime closure OK; PowerShell parser: the probe and
the library parse without errors. `Debug_x64_119` re-copied (mirror of `Debug_x64`, no
`Intermediate`) at 2026-10-06 01:14:50.

## T016 - code-only re-review of the SF1-SF5 fixes: ACCEPT pending GUI

SF5 pre-filter sound (only with a usable id and Links == 1, final path resolves junctions/SUBST/8.3;
false folder equality still checks the archive's own name); SF1 sizes noted before each close and in
NextDisk after the flush, the renamed last volume and the SFX second pass keep the safe direction;
SF2 Cancel in the insert-disk dialog deletes nothing; the shared probe library's desktop guard is the
same detection 111-118 used. **The GUI run must show** the UNC rows (`A-zip-unc-move`, `C-unc-copy`,
`C-unc-move`, the B rows) pass - they are also the evidence that the folder comparison matches across
the local and `\\localhost\C$` spellings (else a selected `src.zip` would be skipped by the pre-filter).
Remaining NITs (recorded): a file replaced by a symlink after the listing would be skipped (refreshes
are suspended - theoretical); a server reporting Links == 1 for a hard-linked file (none known).

Committed after this check with the GUI runs still owed; the build is preserved as
`build\tandemcommander\Debug_x64_119` (01:14:50). Results follow in a separate commit.

## GUI results (2026-10-06, hidden desktop, one run at a time)

Builds: `build\tandemcommander\Debug_x64_119` (the preserved build of 01:14:50) and
`build\tandemcommander\Debug_x64_pre119`. No other Tandem Commander was running at any start. The
registry baseline was now SHA-256 `1AB614304771DBE0...` (the maintainer restored the morning state):
checked before and after every run - **identical every time**, each probe's own export / restore
also reported `identical=True`; no backup was imported by hand. Fixtures removed, no instance left
running, no crash report, every END row PASS (exit code 0, no stray window).

| Run | Result | File |
|---|---|---|
| `packleft_probe.ps1` on **Debug_x64_119** | **PASS 104, FAIL 0, NOT DRIVEN 8** (52 RUN + 52 END; NOT DRIVEN: the 5 X rows + the 3 P rows) | `probe/packleft_result.txt`, `run_119.log` |
| `packleft_probe.ps1` on **Debug_x64_pre119** | **PASS 69, FAIL 35, NOT DRIVEN 8** - exactly the rows `quickstart.md` predicted: every A (8), B (8), D (2), H (7), L (5) and K-add / -add-move / -noask / -cz (4) row and E-decline-vol2; the C, E-decline-vol1, F, G, A-zip-unrelated-over and K-exist-over rows pass on both | `probe/packleft_result_pre119.txt`, `run_pre119.log` |
| 099 `linkmove_probe.ps1` on Debug_x64_119 | **PASS 24, FAIL 0** (as its baseline) | `probe/regress_linkmove_119.txt`, `run_regress099.log` |
| 110 `zipname_probe.ps1` on Debug_x64_119 | **42 PASS / 0 FAIL / 0 NOT DRIVEN** (as its baseline) | `probe/regress_zipname_119.txt`, `run_regress110.log` |
| 113 `zipskip_probe.ps1` on Debug_x64_119 | **37 PASS / 0 FAIL / 0 NOT DRIVEN** (as 113's own run on Debug_x64_113) | `probe/regress_zipskip_119.txt`, `run_regress113.log` |

What the rows show on this build:

- **The reviewer's condition holds**: `A-zip-unc-move` (the archive typed as `\\localhost\C$\...`),
  `C-unc-copy`, `C-unc-move` and all eight B rows PASS - the refusal fires across the local and the
  `\\localhost\C$` spelling, so the SF5 pre-filter's folder comparison matched (had it judged the
  two folders different, `src.zip` would have been skipped and the pack would have run).
- A / B / H: refused before any question (`Asked 0`), the box "Pack" / "Copy Error" / "Move Error"
  with `Name:` + "Cannot copy (move) a file to itself.", the Pack dialog back; sources intact, the
  archive unchanged (7z tests it).
- L: the ZIP error "Cannot open or create file. (sharing violation)" for the held `z9.bin`, Cancel,
  and `out\` holds nothing of the set; `m.z09`, `m.txt` intact; `m.z01` overwritten after *Yes*
  is gone with the set; Move deleted no source.
- K: "Archive of the same file name already exists ... only like a new archive" for `k.zip`,
  nothing created, `k.zip` still holds only `old.bin`; with *Overwrite* the set ends as `k.zip`
  and 7z tests it (2 files).
- D / E: refused / declined at volume 4 / 2 - no volume of the abandoned set left.

What the build before 119 did in the same rows (measured, `packleft_result_pre119.txt`):

- L-lock-copy: `out\m.z01`, `m.z02` left behind after the Cancel (item 1); L-lock-yes-vol1:
  `m.z01` (holding volume data) and `m.z02` left.
- D-later-move: `a.z01`-`a.z03` of the refused archive left in the source folder; E-decline-vol2:
  `a.z01` left beside the declined `a.z02`.
- **K-exist-add-move: loss 2** - the set ended `k.z01`-`k.z04` beside the old `k.zip`, and the
  Move then deleted `p.bin` and `q.bin` (their data only in the misnamed set, which 7z cannot open
  through `k.zip`); K-exist-noask the same. Item 2 was worse than "no loss": a Move lost the
  sources from every readable place.
- B / H: not refused - the ZIP plug-in asked "Confirm File Overwrite" for the member, 7-Zip packed
  the old archive into the new one (`src.7z`: "the archive itself, updated (its old content is
  inside it)").
- A: the question asked first, then a plain "Cannot copy a file to itself." box without `Name:`.

**Paste rows (P) - NOT DRIVEN, also not on the visible desktop.** On the hidden desktop the
clipboard could not be opened (as in 098 / 101 / 107). Before using the visible-desktop allowance I
checked from this session: `OpenClipboard` fails with **ERROR_ACCESS_DENIED (5)** on the visible
desktop too (STA, no other owner - the session's processes have no clipboard access; the program
started from it would inherit that, so its own Ctrl+X / Ctrl+V would fail as well). The
visible-desktop run was therefore not made: it would only have reported the same NOT DRIVEN rows.
The drag & drop / paste refusal remains **by-hand step 2b** in `quickstart.md` (a person with a
real mouse and clipboard). Its code path is `DragDropToArcOrFS` with the same
`PackArchiveIsSelectedSource` / `ShowPackIntoItselfRefusal` pair that the H rows proved.

Probe-only change during the runs: `packleft_probe.ps1`'s own desktop check now honours the same
opt-out (`TC_PROBE_ALLOW_VISIBLE_DESKTOP=1`) as `fix_probe_lib.ps1` (it refused the Default desktop
unconditionally); not used, see above. No product file was touched, nothing was built.

## Pending

- By-hand steps in `quickstart.md` (1-3, and 2b - drag & drop / paste, which no session here can
  drive).
- Independent review of the GUI evidence.

## Recorded, not changed

- "Deselecting helps" is not said in words - needs a new core string (8 languages); the box names
  the archive, which is what to leave out of the selection.
- `IDS_CANTMULTIVOL` in Romanian begins with a lower-case letter ("arhiva cu acelasi nume ...").
- A selected item on a file system without file ids that has the archive's size and times (or a
  selected folder with an ancestor folder's times) is a "maybe" and refused (house rule since 103).
- `WriteSFXCentralDir`'s unchecked reopen (above); the SFX exe of a failed SFX multi-volume pack is
  not recorded - both unreachable without an SFX package.
- Still open from 106 (NEXT-WORK): `translate.merge --module zip` would re-lay out 510 controls; a
  case-sensitive folder refuses `a.txt` -> existing `A.txt`.

## CLAUDE.md "Recent Changes" entry (proposed)

- 119-packing-leftovers: **the five leftovers of 106 - no stray volumes, no misnamed set, and a pack
  into its own archive refused with the archive's name.** Measured by code reading (no GUI run was
  allowed; the probe is pending). (1) A failed multi-volume ZIP pack deleted only the current volume
  - volumes 1..n-1 stayed (Cancel, a source that cannot be opened, a declined "Overwrite?", 106's
  refusal at volume n). Now `CreateNextFile` records every volume it creates with the identity from
  its handle (`CSalPackCreatedFiles`, header-only `src/common/salpackvol.h`) and a failure deletes
  each recorded volume only while its name still holds that file (`SalPackCreatedMayDelete`);
  kept whenever unsure (no file ids: only with the recorded creation time and written size -
  code review SF1); removable media: only the volume still being written (`NextDisk` stops calling
  a closed volume "ours" before the disk can change - SF2); nothing once the archive is complete
  (`outputComplete` - a Move's clean-up failure used to delete the last volume when WinZip names
  were off). A pre-existing volume name overwritten after *Yes* goes with the set (decided).
  (2) The last volume's rename to `name.zip` never replaces and was unchecked: with `name.zip`
  existing (Add) the set ended with `name.z0N` and a Move deleted the sources. Now refused before
  anything is created with the plug-in's existing, translated `IDS_CANTMULTIVOL` (its use had been
  commented out since Open Salamander) where the rename will happen (`SalMultiVolFinalNameTaken`:
  fixed disk, sequential + WinZip names, no SFX); a failed rename is reported and fails the pack.
  (3, 4) The core refuses every pack into an archive that is one of its own sources (106's
  `PackArchiveIsSelectedSource`, now shared) on the Pack dialog - before the "Add or Overwrite?"
  question, which is no longer asked then - F5 / F6 and drag & drop / paste, before any packer:
  ZIP's sharing violation and 7-Zip's archive-inside-itself + "Delete Error (32)" are gone.
  **Behaviour change**: such a pack is refused as a whole - deselect the archive. (5) The refusal
  names the archive: `ShowPackIntoItselfRefusal` = `CFileErrorDlg` with `IDD_ERROR3` and the
  existing copy / move "to itself" text (no new string; "deselect" in words would need one -
  recorded). The check pre-filters plain files when certain (usable ids, one link, the archive's
  real folder known - SF5) and takes the archive's folders from the resolved path too. Also:
  `DetectRemovable` asks `X:\` (also behind `\\?\`), UNC never removable. The probe library
  `fix_probe_lib.ps1` now refuses the Default / Winlogon desktop for every probe (exit inside a
  dot-sourced file ends only that file - it ends the process; opt-out
  `TC_PROBE_ALLOW_VISIBLE_DESKTOP=1`). Interface 107, no registry change, no string. saltests
  14,576 -> 14,655. Probe `probe/packleft_probe.ps1` (106's rows with 119 expectations + L, K, P
  (paste - NOT DRIVEN without a clipboard), Czech; 110 RUN + END rows)
  run on the hidden desktop: this build PASS 104 / FAIL 0 / NOT DRIVEN 8 (the 3 paste rows - this
  session cannot open the clipboard, on either desktop - and 5 X rows), the build before 69 / 35
  (every refusal and clean-up row; K-exist-add-move lost both sources: the Move deleted them into
  the misnamed set); regressions 099 24/0, 110 42/0, 113 37/0; UNC rows PASS. Owed: by-hand drag
  & drop / paste (quickstart 2b). Records:
  `specs/119-packing-leftovers/fix-log.md`.
