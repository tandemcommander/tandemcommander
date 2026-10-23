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
