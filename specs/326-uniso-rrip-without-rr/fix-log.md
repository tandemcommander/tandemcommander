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
