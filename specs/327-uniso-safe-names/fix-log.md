# Fix log - 327-uniso-safe-names

Backlog item `iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe` - ISO plug-in: Joliet and
ISO 9660 names are not made safe before extraction.

## Measurement before (main at e50d62ad)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- Reachability: a panel opens an `.iso` through the ISO plug-in (`uniso=on`); F5 extracts through
  `UnpackFile` of the reader, which joins the target path with `fileData->Name` (the listed name) by
  `SalPathAppend`; folders are created by the core from the listed folder names.
- Sites that list a name from the image (grep `AddFile(` / `AddDir(` / `DupStr` in `src/plugins/uniso`):
  - `iso9660.cpp` `ListDirectoryRe`: Joliet folders (`ConvJolietName` -> `AddFileDir`, no cleaning),
    ISO 9660 / Joliet files and ISO 9660 folders (`MakeListedName`: cleaning only for Rock Ridge);
  - `udf.cpp` `ScanDir` -> `ReadFileIdentifier` (`DecodeOSTACompressed`) -> `AddFileDir`: none;
  - `hfs.cpp` `ListDirectory`: `FixIllegalFSChars` (trailing spaces / trailing `/` removed, `\` `?`
    `*` control -> `_`; not `:` `/` `<` `>` `"` `|`, trailing dots, device names);
  - `xdvdfs.cpp` `ScanDir`: `EnsureU8Name` only;
  - `udfiso.cpp` `ListDirectory`: volume label folders `\ISO (%s)`, `\UDF (%s)`, `\HFS (%s)`
    built from the PVD / LVD identifiers and `CHFS::GetRootName` - not cleaned;
  - generated names only: `AddBootRecord` (`s01-bootdisk-...ima`), `audio.cpp` (tracks),
    `isoimage.cpp` `Session NN`.
- New probe `probe/iso327_probe.ps1` (crafted images: `probe/img327.py` patches placeholder names of
  IMAPI2 Joliet / UDF images and of an xorriso plain ISO 9660 image, builds an Xbox XDVDFS image, sets
  a primary volume identifier; `probe/mkimg327.sh` - xorriso 1.5.6 in WSL - the plain seed and an ISO
  9660 + Rock Ridge + HFS+ hybrid with Linux names; HFS+ stores `..\..\hesc.txt` as it is and
  `12:30h.txt` as `12/30h.txt`). First run: "Error Creating File" boxes were cancelled by the probe
  (Serve answers OK / Yes only), so most names were never tried - the probe now answers Skip (173).
- `tools\run_on_hidden_desktop.ps1` ... `iso327_probe.ps1 -Label before` -> `probe/result_before.txt`:
  **PASS 19, FAIL 39**; registry restored, identical.
  - JOLIET, UDF, XBOX, PLAIN: extracted only `12` (+ stream `12:30...`), `con...` as it is, the
    trailing-dot name with its dots (`jtrailaaaaa..`, `xtrail.`, `TRAILAAAAA..`), `top.txt`; the `/`
    name and the `..\..\` file and folder -> "Error Creating File (3)" (skipped, lost).
  - HFS: `.._.._hesc.txt` and `.._.._hd` PASS before (FixIllegalFSChars maps `\`); `12/30h.txt` lost,
    `con.txt`, `htrail.` as they are. END FAIL: the program did not exit in 30 s - 136 "Detected memory
    leaks!" boxes (Debug build).
  - VOL: the whole set written to `<row>\w)\set\...` - outside the target folder.
  - Opening the xorriso HFS+ hybrid (HFS, VOL): "UnISO: Cannot read sector #00000020."

## speckit-analyze

- Run 1: 0 CRITICAL, 0 HIGH; MEDIUM U1 (T011 said "appended" for the HFS label folder, which
  `udfiso.cpp` writes with `sprintf(path, ...)` over the path) - fixed in tasks.md; LOW L1 (the edge
  case "a Joliet `..` name -> `__`" has no probe row) accepted - the unit case `..` -> `__` covers it.
- Run 2: 0 CRITICAL, 0 HIGH, 0 MEDIUM; coverage 9 / 9.

## Implementation

- `src/common/salarcname.h`: `SalArcNameDetail::CleanOneName(name, size, overwriteWhenFull)` - feature
  326's per-name rule moved here; `SalArcCleanItemName` (N3, contract `contracts/item-name.md`) calls it
  with `overwriteWhenFull = true`: a device name whose `_` prefix does not fit gets `_` as its first
  letter (same length, never cut, never dropped).
- `src/common/salsusp.h`: `SalSuspCleanRockRidgeName` = `CleanOneName(..., false)` - its refusal when the
  prefix does not fit (and 326's fallback to the plain ISO 9660 name) unchanged; TestSusp326 passes.
- `src/plugins/uniso/uniso.h/.cpp`: `MakeSafeName` (listing) and `AppendSafeName` (extraction: the
  listed name cleaned again into a heap copy, then `SalPathAppend`).
- Listing sites: `iso9660.cpp` `MakeListedName` (every ISO 9660 / Joliet name; the Rock Ridge fallback
  name too) and Joliet folders after `ConvJolietName`; `udf.cpp` `ScanDir` after `ReadFileIdentifier`;
  `hfs.cpp` `ListDirectory` after `FixIllegalFSChars` (kept); `xdvdfs.cpp` `ScanDir` after
  `EnsureU8Name`; `udfiso.cpp` the `ISO (...)`, `UDF (...)`, `HFS (...)` label folders. Each site
  cleans before `AddFileDir` / `AddDir` and before the name joins the descent path.
- Extraction joins: `UnpackFile` of `iso9660.cpp`, `udf.cpp`, `hfs.cpp`, `xdvdfs.cpp`, `rawfs.cpp`
  through `AppendSafeName` (CLAUDE.md: cleaned at listing and again at extraction).
- `udfiso.cpp`: the HFS label keeps its existing `sprintf(path, ...)` (it writes over the path, a
  session folder before it is lost - pre-existing, multi-session HFS+ hybrids only; not changed here).

## Checks

- `.\build.cmd` -> BUILD SUCCEEDED (C4267 warnings at `fd.NameLen = strlen(...)` lines, pre-existing).
- `saltests.exe` -> `saltests: 27973 checks, 0 failed` (27937 before; TestArcItemName327 adds 36).
- Negative control (scratch `mutate.py`, each mutant alone on the original `salarcname.h`, rebuilt):
  no-sep -> 6 failed, no-colon -> 5, no-trail -> 10, no-prefix -> 15, no-overwrite -> 2; restored
  byte-identical (SHA-256 compared), rebuilt, 0 failed. (A first loop applied the mutants cumulatively -
  discarded and re-run.)
- clang-format (VS 2022 LLVM) on the changed lines only (scratch `fmtlines.py`, `--lines` from
  `git diff -U0 main`): no change beyond them.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe after -> `probe/result_after.txt`: **PASS 58, FAIL 0** (before 19 / 39): JOLIET, UDF, XBOX,
  PLAIN, HFS, VOL - every NAME row the safe name with its content (`.._.._jesc.txt`, `12_30jaaa.txt`,
  `_con.txtjaaa`, `jtrailaaaaa__`, `j_slasha.txt`, `.._.._jd\inner.txt`, ...), OUTSIDE none, STREAMS
  none; VOL extracts into `ISO (v_.._.._w)\set`. Registry restored, identical.
- Regressions: feature 326's probe -> `probe/result_326_after.txt` **28 / 0**; feature 322's probe ->
  `probe/result_322_after.txt` **18 / 0**.
- No UI string, dialog or menu changed: no `.slt` refresh.

## Side observations (T016)

- "Cannot read sector #00000020" at the open of an xorriso HFS+ hybrid: still there on the fixed build;
  already an item (`iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot`, feature 322's
  record shows it too) - no new item.
- The 136 "Detected memory leaks!" boxes after the HFS set: `CHFS::UnpackFile` returns on Skip /
  Cancel without freeing its read buffer (hfs.cpp, `if (toSkip) return UNPACK_ERROR;`). Gone in the
  after run only because no HFS+ name is refused any more -> Inbox item
  `iso-plug-in-an-hfs-file-skipped-or-cancelled-at-extraction` (`measure:327`).

## Review

### Review 1 - the launch stopped without a report (session ended); its partial work taken

- The reviewer (launched after 4b71cd98) re-ran `iso327_probe.ps1` -> 58 / 0 (`%TEMP%\rev327\result_rev.txt`),
  built mutants of the rule (`%TEMP%\rev327\mut`: no_ctrl, no_quote, no_trailing_space, no_empty,
  prefix_off_by_one, none) and made plain ISO 9660 images without version numbers (xorriso
  `-compliance omit_version`, `-as mkisofs -N`: identifiers `README.`, `MAKEFILE.`, `A.TXT`), then ran
  feature 326's probe, which was cut off when the session ended (its log `p326b.log` stops at SEMI,
  every row so far PASS). Its registry backup `%TEMP%\tc326_backup.reg` (19:59) was left: restored at
  the continued run (`reg delete` + `reg import` of `HKCU\Software\Tandem Commander`, re-exported,
  SHA-256 identical 1BAE2EEF... - the same state every finished probe of the reviewer restored; a
  first attempt deleted and imported only the `0.1` subkey, then the whole key was restored), the
  backup file removed. Not counted as a review round (SKILL.md step 7); a fresh review follows.
- **Finding from the partial work (regression, treated as MUST)**: on the branch build the
  version-less image lists `MAKEFILE_` and `README_` (`%TEMP%\rev327\resultN2.txt`, row MINUSN) - the
  separator dot of an empty extension (ISO 9660 7.5.1: `NAME.` without `;1`) was taken for a trailing
  dot of the name. **Fixed**: `SalIsoRemoveVersion` (salsusp.h) - the version suffix and one separator
  dot are removed before the safe-name rule (`RemoveIsoVersion` now calls it; files only, never Rock
  Ridge names or folders); a dot beyond the separator is still `_` (`TRAILAAAAA..;1` -> `TRAILAAAAA_`,
  Joliet `jtrailaaaaa_`; UDF / Xbox / HFS+ names have no version suffix and keep `..` -> `__`). The old
  `RemoveIsoVersion` removed the dot only when the first dot stood right before `;` (`A.B.;1` stayed
  `A.B.`) - now `A.B`.
- Checks after: `.\build.cmd` BUILD SUCCEEDED; saltests `27986 checks, 0 failed` (+13); mutant
  "separator dot kept" -> 7 failed, restored byte-identical, 0 failed; probe set NOVER added (xorriso
  omit_version) -> `probe/result_after_review1.txt` **PASS 64, FAIL 0** (NOVER `A.TXT`, `MAKEFILE`,
  `README`); feature 326's probe -> `probe/result_326_after.txt` **28 / 0**; 322's ->
  `probe/result_322_after.txt` **18 / 0**; registry restored identical each run.

### Review 2 - two more launches stopped with their sessions; the third (foreground) completed

- Launch 2 (after 8af7a0f0, `%TEMP%\rev327b`): `iso327_probe` 64 / 0 and `iso326_probe` 28 / 0, both
  restored the registry identically; then the session ended. No registry backup of this run was left.
- Launch 3 (foreground, completed): **0 MUST, 1 SHOULD, 5 NOTE.**
  - Confirmed: every listing site and descent path cleans names read from the image (ISO 9660, Joliet
    files and folders, UDF, HFS+ incl. its root label record, Xbox, the three label folders);
    extraction finds data by `CFilePos`, not by name; the 326 fit pass sees the same names; buffers
    hold the device prefix everywhere (the overwrite fallback is unreachable from the plug-in);
    `SalSuspCleanRockRidgeName` equivalent to before. Negative control (copy, `MakeSafeName` removed
    from `MakeListedName`) -> probe 59 / 5 (the `\` rows; the `:` / device / dot / `/` rows are masked by
    the second cleaning at extraction).
  - **SHOULD S1 (taken)**: no probe set covered the `UDF (<label>)` and `HFS (<label>)` folders
    (`udfiso.cpp`). **Added** sets ULABEL (IMAPI2 ISO 9660 + UDF, label `u:\..\..\x` patched in both
    identifiers by `img327.py udflabel`) and HLABEL (the xorriso hybrid with the label TC327HFSLB, its
    HFS+ name patched to `h:\..\..\y` by `img327.py hfslabel`). Negative control in the tree (both
    label `MakeSafeName` calls removed, rebuilt; `udfiso.cpp` restored from a byte copy afterwards,
    `git diff main` shows only the feature's lines) -> `probe/result_review2_negative.txt` **68 / 9**:
    both sets wrote outside the target (`<row>\x)\set\top.txt`, `<row>\y)\set\...`). (That run's
    expected folder names were still mine and wrong - `u_.._.._x`; `:` and `\` both give `_`, so the
    right name is `u__.._.._x` - corrected; the OUTSIDE rows of the negative run fail either way.)
    After -> `probe/result_after_review2.txt` **PASS 77, FAIL 0** (`UDF (u__.._.._x)\set\top.txt`,
    `HFS (h__.._.._y)\set\...`); registry restored identical.
  - N2 (accepted): the second cleaning at extraction covers file names only; folder names reach
    `UnpackDir` / `ExtractAllItems` from the listing, which cleans every one (FR-006 names files only).
  - N3 (taken in the spec): `SalIsoRemoveVersion` also strips one trailing dot of a Joliet file name
    without `;1` - Joliet `x.` and `x` both list as `x` (the overwrite question; `x.;1` did so before 327);
    a file `..` / `.` -> `_`. Spec acceptance scenario 1 (`jtrailaaaaa_`) and the edge cases updated.
  - N4 (pre-existing, unchanged): a crafted ISO 9660 / Joliet name is cut at its first `;` (Joliet
    forbids `;`; versions `A;1` / `A;2` list as one name) - the version suffix rule of the format.
  - N5 (accepted, as feature 087): `a:b` and `a_b` collide - the core lists both, extraction asks.
  - N6 (pre-existing, recorded above): the HFS label's `sprintf(path, ...)` drops a session prefix.
- No MUST in review 2 - the review is passed (SKILL.md step 7).
