# Fix log - 326-uniso-rrip-without-rr

Backlog item `iso-plug-in-rock-ridge-names-of-xorriso-images-are-not-read` - ISO plug-in: Rock
Ridge names of xorriso images are not read, the ISO 9660 names are listed.

## Measurement before (main at 2c033750)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- Seed images made with feature 322's `specs/322-uniso-hfs-btree-joliet/probe/mkimg322.sh`
  (xorriso 1.5.6 in WSL Ubuntu) plus `xorriso -compliance old_rr` of the same source.
- `tools\run_on_hidden_desktop.ps1` with `specs\322-uniso-hfs-btree-joliet\probe\iso322_probe.ps1`
  on the HEAD build: 18 / 0, with
  - `RR  RUN PASS extracted: TOP.TXT` - the Rock Ridge name `top.txt` not used;
  - `RR-LONG RUN PASS ... the Rock Ridge name used False; extracted name lengths: 31`.
  Registry restored, identical (SHA-256 D36F5B06...).
- A Python dump of the root directory records (scratch script, `struct` over the image):
  - rr.iso, rrlong.iso, oldrr.iso: `.` = `SP(len 7 v1 be ef 00)` `PX` `TF` `CE`; continuation
    area (block 0x33) = `ER` `RRIP_1991A`; `FOLDER` = `PX TF NM(folder)`; `TOP.TXT;1` =
    `PX TF NM(top.txt)`; rrlong's file `PX TF NM(flags 1 = CONTINUE, 93 letters) CE`.
  - No `RR` entry anywhere, also with `-compliance old_rr`.
  - plain.iso: no System Use entries.
- Reachability: a panel opens an `.iso` through the ISO plug-in (`uniso=on`); without Joliet
  `CISO9660::ListDirectoryRe` -> `ExtractExtFileName` / `ExtractFileName` decide every name;
  `ExtractExtFileName` reads `NM` only when the first entry is `RR`.

## Decisions

- Recognise SUSP by the `SP` entry of the root's `.` record (spec Clarifications); `RR` per record
  keeps working; LEN_SKP honoured only with `SP`.

## speckit-analyze

- Run 1: 0 CRITICAL, 0 HIGH; MEDIUM C1 (no CHANGELOG task), C2 (no clang-format task), U1 (T008
  vague about the System Use bounds) - fixed in tasks.md (T014, T015, T008 reworded); LOW I1
  ("length 7" measured vs "at least 7" rule) and G1 (unreadable root not tested - it only leaves
  SUSP off) accepted.
- Run 2: 0 CRITICAL, 0 HIGH, coverage 10 / 10.

## The feature's probe before (main's binary, unchanged sources)

`specs/326-uniso-rrip-without-rr/probe/iso326_probe.ps1` (seeds by `probe/mkimg326.sh`, xorriso
1.5.6 in WSL) -> `probe/result_before.txt`: **PASS 13, FAIL 5** - RR `TOP.TXT`, OLDRR `TOP.TXT`,
RR-DIR `FOLDER\NOTE.TXT`, RR-LONG 31 letters, SEMI `SEMI_COLON.TXT`; LEGACY-RR `top.txt` (the `RR`
path works), LEGACY-DIR `FOLDER`, PLAIN `TOP.TXT`, J-ASCII `top.txt`. Registry restored, identical.
LEGACY is a copy of `rr.iso` patched by the probe (the root's `SP` check bytes cleared, `top.txt`'s
first entry `PX` renamed `RR`) - genisoimage's layout without Docker.

## Implementation

- `src/common/salsusp.h` (new, header-only): `SalSuspSystemUseArea`, `SalSuspIsSp`,
  `SalSuspRootHasSp`, `SalSuspRockRidgeStart` (contract `contracts/salsusp.md`).
- `src/plugins/uniso/iso9660.h/.cpp`: members `SuspVolume` / `SuspSkip`; `Open` reads the root
  extent's first sector (the block `ListDirectoryRe` reads first) when not Joliet and sets them from
  `SalSuspRootHasSp` (a failed read leaves SUSP off); `ExtractExtFileName` decides by
  `SalSuspRockRidgeStart` (first entry `RR` -> from 0 as before; a SUSP volume -> from LEN_SKP) and
  now returns TRUE for a Rock Ridge name.
- Found while tracing the caller (FR-005, same change): `ExtractFileName` cut every file name at its
  first `;` (the ISO 9660 version suffix) - also a Rock Ridge name: `semi;colon.txt` would have come
  out as `semi` (genisoimage images too, before). A Rock Ridge name is no longer cut there; Joliet
  and ISO 9660 names keep the version suffix removal. Probe row SEMI added before the build of the
  fix (so its "before" is measured on main's binary).
- Callers of `ExtractExtFileName` (grep): `ExtractFileName` (files) and `ListDirectoryRe` (folders,
  return value unused - folders never had the `;` removal). `CISO9660` is opened by
  `CISOImage` (isoimage.cpp) and `CUDFISO::Open` (udfiso.cpp): both go through `Open`.
- clang-format (VS 2022 LLVM x64) reformatted unrelated lines of `saltests.cpp` (2,137 lines) and
  three trailing comments of `iso9660.*`: reverted; only the feature's lines are formatted.

## Checks

- `.\build.cmd` -> BUILD SUCCEEDED (one warning C4267 at `iso9660.cpp` `fd.NameLen = strlen(...)`,
  pre-existing - the same line on main).
- `saltests.exe` -> `saltests: 27915 checks, 0 failed` (TestSusp326 adds 31).
- Negative control (scratch `mutate.py` on `salsusp.h`, rebuilt, restored byte-identical): no-rr
  (the `RR` branch off) -> 2 failed; no-check (`BE EF` not checked) -> 1 failed; no-skip (LEN_SKP
  ignored) -> 2 failed; no-pad (the padding byte ignored) -> 2 failed.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe after -> `probe/result_after.txt`: **PASS 18, FAIL 0** - RR `top.txt`, OLDRR `top.txt`,
  RR-DIR `folder\note.txt`, RR-LONG 200 letters, SEMI `semi;colon.txt`, LEGACY-RR `top.txt`,
  LEGACY-DIR `FOLDER\NOTE.TXT`, PLAIN `TOP.TXT`, J-ASCII `top.txt`. Registry restored, identical.
- Feature 322's probe on the new build -> `probe/result_322_after.txt`: **18 / 0** (its RR row now
  `top.txt`, RR-LONG "the Rock Ridge name used True", 200 letters; Joliet CJK, HFS+, hybrid as before).
- No UI string, dialog or menu changed: no `.slt` refresh.
- Not driven: a real genisoimage image (Docker not running) - replaced by the LEGACY rows; feature
  223's probe was not re-run (its RR-LONG row needs Docker).

## Review

### Review 1 (independent agent, refute-first) - 1 MUST, 0 SHOULD, 4 NOTE

- Confirmed: the probe 18 / 0 re-run; a negative control with main's `uniso.spl` in a worktree copy
  lists ISO 9660 names of its own xorriso images; `salsusp.h` bounds; `Open`'s root block equals
  `ListDirectoryRe`'s; callers (`ExtractFileName`, `ListDirectoryRe`; `CISO9660` from
  `isoimage.cpp` and `udfiso.cpp`, both through `Open`).
- **MUST M1**: Rock Ridge names reached the listing and the extraction uncleaned - now for every
  xorriso image. Reproduced by the reviewer and again here (probe rows added, run on the branch
  build before the fix -> `probe/result_review1_before.txt`): ESC `..\escape.txt` written to
  `%TEMP%\tc326\escape.txt` (two levels above the target, read-only; "Cannot set file attributes.
  (123)"; the probe's fixture could not be removed - cleaned by hand afterwards), COLON `12:30.txt`
  -> a 0-byte file `12` and the data in the stream `30.txt`, TDOT `trail.`, DEV `con.txt` as they
  are. **Fixed**: `SalSuspCleanRockRidgeName` (salsusp.h) - feature 087's per-component rule
  (`\` and `/` are characters of a POSIX name here, so they become `_` instead of splitting);
  `ExtractExtFileName` cleans every `NM` name, a name the cleaning cannot hold falls back to the
  plain name. After: ESC `.._escape.txt`, COLON `12_30.txt`, TDOT `trail_`, DEV `_con.txt`, nothing
  outside the target, no streams.
- N1 (case-only twins now both listed; an overwrite question on extraction) - expected, not changed.
- N2 (a long Latin-1 folder name grows in `EnsureU8Name`, `AddDir` refuses, the listing ends) led to
  a measurement of the same class with valid names: **DEEP** (five folders of 60 letters, a
  305-byte folder part) on the branch build: "UnISO - Error" at the open and the folder tree lost
  (`result_review1_before.txt`), where main's ISO 9660 names (31 letters) list it whole - a
  regression of this feature. **Fixed** (FR-009): `ListDirectory` first walks a volume recognised
  by `SP` with `FitCheck` (`AddFileDir` only asks `sallistingname.h`, the core's own rule, with the
  same path strings; its messages quiet); when an entry would be refused the volume is listed as
  before 326 (`SuspVolume = FALSE`). Re-listing after a failure was rejected: `dir->Clear` would
  wipe other file systems' entries of a UDF / HFS+ hybrid or a multi-session image. After: DEEP no
  message, `deep.txt` extracted with its content under the ISO 9660 names.
- N3 (a leading `RR` wins over LEN_SKP) - deliberate (FR-003), unchanged.
- N4 (Joliet still wins over Rock Ridge) - as specified, in the CHANGELOG limitation.
- Out of the item (Inbox, `review:326`): `iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe`
  (the same cleaning for Joliet / ISO 9660 names), `iso-plug-in-an-entry-the-listing-refuses-ends-the-listing`
  (a refused entry clears the listing - genisoimage deep trees, Latin-1 names; a partial Rock Ridge
  listing instead of the whole fallback).

Checks after the fixes:

- `.\build.cmd` -> BUILD SUCCEEDED; `saltests` -> `27937 checks, 0 failed` (TestSusp326 now 53).
- Mutants of the cleaning rule (scratch `mutate.py`, restored byte-identical): no-backslash -> 1
  failed, no-device -> 5 failed, no-trail -> 4 failed.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format only on the feature's changed lines (scratch `fmtlines.py`, `--lines` from
  `git diff -U0 main`).
- `iso326_probe.ps1` -> `probe/result_after_review1.txt`: **PASS 28, FAIL 0** (14 rows: RR, OLDRR,
  PLAIN, LEGACY-RR, RR-DIR, LEGACY-DIR, RR-LONG, DEEP, ESC, COLON, TDOT, DEV, SEMI, J-ASCII);
  registry restored, identical. The DEEP row first expected `top.txt` (wrong expectation: the
  designed fallback lists `TOP.TXT`) - rewritten to check what matters (no message, `deep.txt`
  reachable with its content).
- Feature 322's probe -> `probe/result_322_after.txt`: **18 / 0**.

### Review 2 - three launches stopped without a report

- Launch 1 (17:14) wrote probe results until 17:23 (`%TEMP%\rev326`: unsafe folder names `..\evil`,
  `con`, `a:b`, `x.` cleaned, nothing outside the target - 12 / 0; the feature probe 28 / 0), then no
  progress over two fallback checks (17:25, 17:36) - treated as stopped (SKILL.md step 7), relaunched.
- Launch 2 (17:36, `%TEMP%\rev326c`): unsafe folder names again clean; a case-only twin image
  (`Folder\a.txt` / `folder\a.txt`) extracted one `a.txt`; a negative-control run in a worktree
  left no restore line (its backup file was not left behind) - no progress over two checks (17:58,
  18:11), relaunched with the partial work.
- Launch 3 (18:11, `%TEMP%\rev326d`): ran feature 252's probe with an ISO kind on the branch build:
  ISO-HIDE, ISO-GLOBAL, ISO-TREE FAIL, TAR rows PASS; then no progress over two checks (18:33,
  18:45) - stopped.
- **Finding taken from the partial work (data loss, treated as MUST)**: Rock Ridge names keep their
  case, so an xorriso image can hold `a.txt` and `A.txt`, folders `D` and `d` - feature 252's defect
  (Hide Selected Names hid both twins, Restore Selection took both, folders merged) reaches the ISO
  plug-in, whose upper-case ISO 9660 names never had twins. **Fixed** (FR-010): `uniso.cpp`
  `ListArchive` builds the listing with `SALDIRFLAG_CASESENSITIVE` and clears it unless
  `SalDirTreeHasCaseTwins` finds twins - exactly `tardll.cpp`'s code of feature 252
  (`UnpackWholeArchive` lists through `ListArchive` too).
- Probe `probe/twins326_probe.ps1` (feature 252's `arc252_probe.ps1` with an ISO kind made by
  `probe/mkiso326.sh` from the case-sensitive source folder): before the fix (branch build
  7187965d) -> `probe/result_twins_before.txt` **PASS 5, FAIL 3** (ISO-HIDE `z.txt` only, ISO-GLOBAL
  both twins, ISO-TREE `d/x.txt,d/y.txt` merged); after -> `probe/result_twins_after.txt` **8 / 0**
  (ISO-HIDE `A.txt=UPPER,z.txt`, ISO-GLOBAL `a.txt=lower`, ISO-TREE `D/x.txt,d/y.txt`, ISO-CONTROL
  inside `Docs` opened as `DOCS`).
- After: `.\build.cmd` BUILD SUCCEEDED; saltests `27937 checks, 0 failed`; encoding guard `TOTAL: 0`;
  `iso326_probe` -> `probe/result_after_review2.txt` **28 / 0**; 322's probe **18 / 0**.
- The registry hash at a probe's start changed between runs (D36F... until 17:07, BB5A... from 17:19,
  D530... from 18:15); every finished probe restored its own start state identically and no
  `tc*326*_backup.reg` was left - the key was changed outside the probes (the program used on the
  maintainer's desktop), not by an interrupted probe.

### Review 2 - fourth launch (completed) - 0 MUST, 1 SHOULD, 3 NOTE

The earlier launches had not stopped: each waited on its own background probe (the harness reported
"waiting on its own background work"); the fourth launch was given a findings file and finished.

- Confirmed: every path a Rock Ridge name takes (`ExtractExtFileName` only; extraction uses listing
  names - `UnpackArchive`, `UnpackOneFile`, `ExtractAllItems`); the fit check uses the real pass's
  strings (path after `AddBootRecord`: `Session NN`, the hybrid's `\ISO (vol)`), the same
  `sallistingname.h` rule as `AddFile` / `AddDir`, no side effects, buffers large enough; the case
  flag (archive listings start with flags 0, `UnpackWholeArchive` lists through `ListArchive`, hybrids
  and sessions are distinct folders). Re-measured: saltests 27937 / 0, `iso326_probe` 28 / 0 on 8228aa00.
- **SHOULD S1** (taken): the cleaning ran on the raw `NM` bytes before `EnsureU8Name` converted a
  legacy code page name - on code page 932 a Shift-JIS second byte 0x5C / 0x7C became `_`
  (`ソフト.txt` -> `ダフト.txt`, `表示` -> `廟示`; the reviewer's byte simulation), a regression for
  genisoimage (`RR`) images; and `com\xB9` (cp1252) became `com¹` unprefixed. **Fixed**:
  `CISO9660::MakeListedName` - `EnsureU8Name` first, then `SalSuspCleanRockRidgeName` on the UTF-8
  name, for folders and files; a name the cleaning cannot hold falls back to the record's plain ISO
  9660 name (`RemoveIsoVersion` for files, shared with `ExtractFileName`). Not drivable here (ACP
  1250: single-byte, the order changes nothing) - person-step item
  `check-iso-rock-ridge-names-in-a-shift-jis-image-on-a`.
- N1 (taken): the CHANGELOG said genisoimage images keep their names as before - reworded (their
  Rock Ridge names are now made safe the same way).
- N2 (accepted, recorded): the fit pass reads each directory of a SUSP volume a second time; a read
  error's Retry / Cancel dialog (`SafeReadFile`) can appear in both passes, and Cancel in the fit
  pass leaves the rest unchecked (a later refusal then behaves as before 326 - the class of the Inbox
  item `iso-plug-in-an-entry-the-listing-refuses-ends-the-listing`).
- N3 (accepted): two names that collide after cleaning (`a:b`, `a_b`) end at the overwrite question -
  feature 087's accepted class.
- The reviewer removed the stale worktree `%TEMP%\rev326c\neg` (it held only a reviewer mutant).

Checks after S1: clang-format on the changed lines only; `.\build.cmd` BUILD SUCCEEDED; saltests
`27937 checks, 0 failed`; encoding guard `TOTAL: 0 finding(s)`; `iso326_probe` ->
`probe/result_after_review2.txt` **28 / 0**; `twins326_probe` -> `probe/result_twins_after.txt`
**8 / 0**; 322's probe -> `probe/result_322_after.txt` **18 / 0**; registry restored identical each run.
No MUST in review 2 - the review is passed (SKILL.md step 7).
