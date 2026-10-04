# Fix log: feature 106 - a pack never writes its archive over a file it packs

Branch `106-zip-overwrite-source`, from `105-pictview-saveas-loss` (cfd49e2b). Decisions by the
author (the maintainer asked for autonomy): `spec.md` *Clarifications*. Measurements behind
every decision: `research.md`. Pre-change build: `build\tandemcommander\Debug_x64_pre106`.
Not committed (the coordinator commits after an independent review).

## Measured first - the premise

Right for the ZIP plug-in's multi-volume packing, and the loss is total (`research.md` 0):
a selected file named like a volume is **gone** (volume 1: truncated before it was even listed,
then deleted by the error path - on a Copy too, under every spelling and through a hard link);
named like a later volume, Copy leaves archive data in it and Move breaks the archive and
deletes the other files. A declined "Overwrite?" for volume 2+ **deleted the declined file**.
The self-extractor routes are unreachable (no SFX package). And a route the premise did not
name: the core's Pack dialog *Overwrite* deleted a selected file named like the archive before
any packer ran (ZIP and 7-Zip, Copy and Move, every spelling). No loss on the ordinary ZIP pack
(the plug-in holds the archive open for writing, a selected archive cannot be read - sharing
violation, Skip), on F5/F6 into an archive that is itself selected, in the 7-Zip plug-in (the
old archive ends up inside the new one; Move cannot delete the locked archive) or TAR (no
packing). WinRAR is not installed - not driven.

## T003 - S1: the rule (`src/common/salsamefile.h`, header-only, pure)

| Piece | What it does |
|---|---|
| `SalPackOutputIsSource(out, src)` | the existing output `out` (volume, self-extractor, the archive "Overwrite" deletes) is the source `src`: the same id (also another hard link - a truncation reaches the shared data; 103's `Links > 1 -> legacy` is for delete-then-recreate, not here), or no usable ids + equal metadata ("maybe" = yes) |
| `SalPackTargetInSelection(archive, ancestors, n, item, isDir)` | a selected file is the archive itself; a selected folder is one of the archive's folders (its tree is packed) |

## T004 - S2: core (`fileswn7.cpp`)

- `PackArchiveIsSelectedSource(archive, panelPath, data)`: identity of the archive
  (`SalGetFileIdentity`, through links), of each of its folders up to the root (`CutDirectory`
  loop), of each selected item (`panelPath\name`, heap string - any length); `..` skipped; an
  item whose identity cannot be read is not compared; low memory -> refuse.
- In `CFilesWindow::Pack`, the *Overwrite* answer runs it before `ClearReadOnlyAttr` +
  `SalDeleteFile`; a match shows "Cannot copy a file to itself." (`LoadStrU8`) under "Error
  Overwriting File" and goes back to the Pack dialog (`_PACK_AGAIN`, as after a failed delete).
  Nothing is deleted. Costs only on that answer.

## T005 - S3: ZIP plug-in (`add.cpp`, `add_del.{h,cpp}`, `zip.rh2`, `lang/lang.rc2`)

- `PackMultiVol`: the files are listed (`EnumFiles2`, `MatchAll`, the 65,535-entries check)
  **before** anything is created; error or nothing to pack -> return, nothing created (the old
  order created volume 1 first and, with nothing to pack, deleted it again). SFX branch: the exe
  is checked with `IsPackedSource` before `TestIfExist`'s question.
- `PackSelfExtract`: the files are listed before `TestIfExist` / `CREATE_ALWAYS` of the exe,
  then the same check (unreachable - compiled, not driven).
- `CreateNextFile` (every volume): before `CREATE_ALWAYS` (also with "Overwrite all") and when
  `CREATE_NEW` meets an existing file, `IsPackedSource(TempName)` -> `RefusePackedSource` (the
  plug-in's error box: file name + `IDS_PACKEDSOURCE`) -> `IDS_NODISPLAY`, before the overwrite
  question; the loop is left with `break`.
- `TempNameOurs` (new member, set in `CreateNextFile` only when this operation created the file;
  not for the second pass of a removable-media self-extractor, review N3): `PackMultiVol`'s cleanup deletes
  `TempName` only then. Before, a declined / refused / disk-space-cancelled name was deleted.
- `CZipPack::IsPackedSource(nameU8)`: identity of the output (`SplU8ToWExtAlloc`,
  `SalGetFileIdentityW`, through links); not there -> FALSE; else every listed non-directory
  source is opened (`FILE_READ_ATTRIBUTES`) and
  compared with `SalPackOutputIsSource` (first version: only sources of the output's listed size -
  removed after the review, SF-1).
- `IDS_PACKEDSOURCE` = 1255 (free slot of the 1248-1263 bundle): "This file is one of the files
  being packed. The archive cannot be written over it."
- Unchanged: `PackNormal` (protected by its open archive handle - measured), `CreateSFX`,
  the last volume's rename to `name.zip`.

## T006 - S4: saltests `TestPackSelf106`

Pure: same file, hard link, same id with changed metadata, another file with equal metadata,
another volume, no ids + equal / other size / other time / directory, two volumes without ids,
unreadable identity; the selection rule (the archive as a file item, its folder, a folder above,
a sibling, no folders known, a file item never compared with folders). Real NTFS in `%TEMP%`:
the 8.3 spelling, another case, a hard link, another file of equal size, the archive's own
folder. **13,555 -> 13,588 checks, 0 failed.**

## T007 - S5: translations

`build_langs.cmd --export-templates --module zip` -> `translate.merge --dry-run --module zip`:
exactly 1 gap per language (82 characters). The merge sent **656 DeepL characters** (quota
remaining 487,056). Review: es wrote *archivo* for the file (the corpus: *fichero* = file,
*archivo* = archive); cs, sk, de, fr, nl, ro, hu said the archive is written "onto/over" the
file in a way that reads as the archive being overwritten. **8 pins** under `zip` in
`translations/ui-overrides.json` (note `_feature_106`), each with its corpus' word for packing
(cs/sk komprimace, de Packen, fr compression, nl inpakken, hu csomagolás, ro arhivare, es
compresión; formal, no direct address). **The tool's full run also re-laid out 510 dialog
controls** (check-box widths +12 since the files were written at build 185, `VERSION` 185 -> 192)
- unrelated churn, not taken: the committed `.slt`/`.origin` hold exactly the new row
(`1255,1,"..."`) and its key (`"STRINGTABLE:17:1255": "human"`), the rest byte-identical to HEAD.
Afterwards: dry run 0 gaps, 0 validation failures; `translate.slt --verify` 298 files byte-exact.

## T008 - S6: probe `probe/packself_probe.ps1` (hidden desktop)

70 rows (41 RUN + 25 END + 4 NOT DRIVEN): every route of `research.md` with the source = output
(same name, case, the folder's 8.3 name, the file's 8.3 name, `\\localhost\C$`, a hard link),
Copy and Move; per row every source byte-identical, or gone and byte-identical inside the result
(`7z x`), plus the row's expectation; ordinary packing (plain ZIP, plain 7-Zip, multi-volume)
tested by `7z x`.

| Build | Result |
|---|---|
| this (`packself_result.txt`) | **PASS 66, FAIL 0, NOT DRIVEN 4; loss 0 in every row** - A rows: "Cannot copy a file to itself." + the Pack dialog again; C/D rows: "This file is one of the files being packed..." with no overwrite question; E rows: the declined file kept |
| before (`packself_result_pre106.txt`) | **PASS 49, FAIL 17, NOT DRIVEN 4** - every A row (7: ZIP and 7-Zip, Copy and Move, case, 8.3, UNC, the archive inside a selected folder) lost the file; every C row (7, incl. the hard link: `x.bin` overwritten with volume data) and both D rows lost a source (D-later-move: archive "Missing volume", `b.bin` gone); E-decline-vol2 deleted the declined `a.z02`. The rows without a collision (A-unrelated, B, E-vol1, F, G, H) pass on both builds |

`packself_result_measurement_pre106.txt` is the first run on the build before (an earlier probe
version without A-dir, A-unrelated and C-hardlink; its B-7z/H-7z "FAIL" rows were the probe
counting the updated archive itself as a changed source - the invariant now accepts the archive
when its old content is inside the new one).

NOT DRIVEN: self-extractor (no SFX package), RAR (WinRAR not installed), removable media,
a real mouse drag (the same core call as F5/F6).

## T009 - Gates

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | succeeded, 0 errors, the 3 known warnings (`salamdr2.cpp`, `zip.cpp`) |
| full Release build (`build.cmd full release`) | exit 0, BUILD SUCCEEDED, 0 errors, the same 3 known warnings; 189 language modules; runtime closure OK (218 modules) |
| saltests | **13,588 checks, 0 failed** (13,555 before) |
| `python tools\check_encoding.py --strict` | TOTAL 0 |
| clang-format | no finding in the changed regions (the files' pre-existing findings unchanged) |
| 094 ZIP probe (`regress_zip094_106.txt`) | AS EXPECTED 56, DIFFERENT 1 - the same as its baseline (X1, the self-extractor row, cannot be driven in a Debug tree) |
| 099 linkmove (`regress_linkmove_106.txt`) | PASS 24, FAIL 0 |
| 097 arcwork, ZIP/7z subset (`regress_arcwork_106.txt`: zipU200, zipL300A, zipA5000, zipE5000, zipC200, 7zU200, 7zA5000, 7zC200) | PASS 120, FAIL 0 |
| 103 samefile (`regress_samefile_106.txt`) | PASS 62, FAIL 0 |
| registry after every run | restored, SHA-256 1AB614304771DBE0... identical |

`PRIVACY.md`: unchanged - nothing new is stored, sent or written outside the operation's own
output (a refused pack writes nothing).

## T011 - independent review: ACCEPT, with changes applied before the commit

The reviewer reproduced the 66 rows and passed 8 extra cases (an unselected `a.z03` + Cancel
kept; a same-named file in another folder not refused; the archive two levels inside a selected
folder, through a junction, a file symlink to the archive or to volume 1 - refused; an ASCII
multi-volume archive tests OK in 7z.exe; translations structurally valid, all 9 Release `.slg`
carry 1255).

- **SF-1 (data loss, reproduced by the reviewer):** `IsPackedSource` skipped sources whose
  *listed* size differed from the output's size. NTFS updates the size in a directory entry only
  for the name a write went through, so a hard-linked source written through its other name is
  listed with a stale size - skipped - and "Overwrite h.z01?" *Yes* replaced its data. **The
  size filter is removed**: every listed file is compared (the check runs only when an output
  file already exists). Probe row **C-hardlink-stale** (3,000 bytes appended through
  `out\h.z01` after the panel listed `x.bin`).
- **N2:** a refused *Overwrite* still stored "Add into archive without asking next time", so the
  next pack silently added. Now the check box is not stored when the *Overwrite* it came with was
  refused **or failed** (the delete-failure path had the same effect; both go back to the
  dialog). Probe row **A-zip-noask-refused** (tick + Overwrite, then the same Pack again: asked
  again).
- **N3 (pre-existing, contained - fixed):** the second pass of a removable-media self-extractor
  opens the volume by name on whatever disk is in the drive and had marked it "ours", so a
  failure would delete a user's file of that name on a wrong disk. The second pass no longer
  marks it; a failure leaves it (not driven: no removable drive, no SFX package).
- **Romanian:** the ZIP plug-in loads its texts through the code page; CP1250 has no
  comma-below `ș`/`ț`. The pin is now written without diacritics, as the rest of the Romanian ZIP
  corpus (dry run 0 gaps, `--verify` byte-exact).
- **N1 (recorded):** the core's refusal "Cannot copy a file to itself." names no file and does
  not say that deselecting the archive (or the folder holding it) helps - the visible side of the
  behaviour change. A clearer text needs a new core string and its translations.

## T012 - re-run after the review changes

| Gate | Result |
|---|---|
| Debug build | succeeded, 0 errors |
| saltests | 13,588 checks, 0 failed |
| strict encoding guard | TOTAL 0 |
| probe, this build (`packself_result.txt`) | **PASS 70, FAIL 0, NOT DRIVEN 4, loss 0** (the 66 rows plus C-hardlink-stale and A-zip-noask-refused, RUN + END) |
| probe, build before, the two new rows (`packself_result_pre106_review.txt`) | both FAIL: C-hardlink-stale - `x.bin` overwritten with volume data through the link; A-zip-noask-refused - `src.zip` replaced by the new archive (the build before deleted it on the first Overwrite) |
| full Release build | exit 0, BUILD SUCCEEDED, 0 errors, 189 language modules, runtime closure OK |
| registry | restored after each run, SHA-256 1AB614304771DBE0... identical |

## Recorded, not changed

- **Partial volumes stay after a failed multi-volume pack** (a refusal at volume n, disk full,
  Cancel): volumes 1..n-1 that the operation wrote. They are its own output; deleting them by
  name is unsafe on removable media (one name on every disk). Before and after 106.
- **Multi-volume into a name whose `name.zip` exists** (the core asked Add/Overwrite and the
  user chose Add): the last volume cannot be renamed to `name.zip` (`MoveFileU8` never replaces,
  the result is not checked) - the set ends with `name.z0N`, silently, and the old `name.zip`
  stays. Found by reading, not measured; no data lost (rename by hand).
- **7-Zip plug-in**: packing into an archive that is itself selected puts the old archive inside
  the new one, and Move then shows "Delete Error (32)" for the archive (it is locked on purpose).
  No loss; 7-Zip's console does the same without `-sdel`.
- **ZIP plug-in, *Add* into an archive that is itself selected**: a sharing-violation error for
  the archive (Retry/Skip/Cancel) instead of a clear text. No loss.
- The core's refusal reuses "Cannot copy a file to itself." (no file name, "copy" for a pack) -
  a new core string would need its own translation round; the Pack dialog comes back with the
  name filled in.
- `translate.merge --module zip` re-lays out 510 controls of the committed ZIP translations
  (tool drift since build 185); a deliberate re-layout pass would be its own change.

## CLAUDE.md "Recent Changes" entry

- 106-zip-overwrite-source: **a pack never writes its archive over a file it packs.** Measured
  first (`research.md`), worse than the 103 note: a multi-volume ZIP whose volume name was a
  selected file (`a.z01`/`a.z04` for `a.zip`) lost that file after "Overwrite?" Yes - on a Copy
  too (volume 1 was created before the files were even listed), and with Move broke the archive
  and deleted the other files; any spelling (case, 8.3, `\\localhost\C$`) and a hard link. A
  declined "Overwrite?" for volume 2+ deleted the declined file. And the core's Pack dialog
  *Overwrite* deleted a selected file named like the archive before any packer ran (ZIP, 7-Zip).
  Now: `SalPackOutputIsSource` / `SalPackTargetInSelection` (`salsamefile.h`, pure: same id incl.
  hard links, or no ids + equal metadata = yes); the ZIP plug-in lists the files before creating
  any output and checks every existing volume / self-extractor against all of them (only when
  such an output already exists) - refused before the question with the new `IDS_PACKEDSOURCE` (1255,
  free slot, 8 languages pinned under `_feature_106`; review SF-1: no size filter - a hard link
  written through its other name is listed with a stale size); `TempNameOurs` - a failed multi-volume
  pack deletes only a volume it created; the core's *Overwrite* checks the selected items and the
  archive's folders and says "Cannot copy a file to itself." (behaviour change: an old archive
  that is itself selected can no longer be overwritten by packing it - deselect it). Unchanged,
  measured without loss: ordinary ZIP pack/F5/F6 into a selected archive (its open handle blocks
  the read), 7-Zip (the old archive ends up inside), TAR (no packing); SFX unreachable; RAR not
  driven. Interface 107, no registry change. saltests 13,555 -> 13,588. Probe
  `probe/packself_probe.ps1` 70/0 (before: 49/17 plus the two review rows failing). Found, not fixed: partial volumes after a failed
  multi-volume pack; the last volume not renamed when `name.zip` exists; `translate.merge
  --module zip` would re-lay out 510 controls. Records: `specs/106-zip-overwrite-source/fix-log.md`.
