# Fix log - 362-uniso-udf-folder-no-descs

Backlog item `iso-plug-in-a-udf-folder-entry-without-descriptors-is-listed` (review:361, SHOULD 1 of review 2).

## Measurement before the fix (HEAD 5d74e338, Debug build, `.\build.cmd` up to date)

Sites (Grep, not line numbers): `src/plugins/uniso/udf.cpp`

- `CUDF::ReadFileEntry(Uint8*, bool, Uint16, CICBTag*, CAD*, int)` - for an empty area (L_AD 0, any valid type 0 - 3)
  stores no descriptor, writes only the terminator (Length 0, Location 0, `Offset` not set) and returns 0.
- `CUDF::MapICB(CAD, CICBTag*, CAD*)` returned 0 only for `UDF_FE_REFUSED` (361); 0 descriptors -> 1.
- Callers (enumerated with Grep `MapICB`): `CUDF::ListDirectory` (the root ICB; 0 -> `IDS_UDF_BAD_ROOT_ICB` +
  `ListingLeftOut.SetIncomplete()`), `CUDF::ScanDir` (an identifier with `UDF_DIRECTORY` listed `ADD_LISTED`;
  0 -> `ListingLeftOut.SetIncomplete()`, feature 330). No other caller; `MapICB(CAD, CFileEntry*)` is a separate
  overload (files) and is not touched.
- Reachable: Enter on the image / Alt+F9 Unpack -> `CISOImage` -> `CUDF::ListDirectory` -> `ScanDir` -> `MapICB`,
  default configuration (uniso is `on` in `plugins.cfg`).

New probe `probe/iso362_probe.ps1` (on 361's), `probe/img362.py` (sets L_AD 0), `probe/mkimg362.sh` (control seed
with a real empty folder):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\362-uniso-udf-folder-no-descs\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\362-uniso-udf-folder-no-descs\probe\iso362_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before-5d74e338"
```

Result `probe/result_before.txt`: **PASS 15, FAIL 7**, registry restored + identical.

| Row | Before |
|---|---|
| L-ROOTLAD0 / L-ROOTEMB0 | no window (want "Bad root ICB") - FAIL |
| R-ALAD0 (a L_AD 8 -> 0) | UDF a/side.txt missing, no window, image **deleted** - FAIL |
| R-AEMB0 (a type 0 -> 3, L_AD 0) | same - FAIL |
| R-ZLAD0 (zlast L_AD 8 -> 0) | UDF zlast/z.txt missing, image **deleted** - FAIL |
| R-ROOTLAD0 (ud root L_AD 0) | ISO part only, no window, image **deleted** - FAIL |
| R-ROOTEMB0 (mk_cdr root, type 3, L_AD 40 -> 0) | nothing, no window, image **deleted** - FAIL |
| L-UE, C-UD, C-UE, C-MKCDR (controls) | PASS (real empty folder e listed and extracted; images deleted) |

## Analyze

No CRITICAL / HIGH. LOW I1 (T007/T008 `[P]` but probes run one after another - accepted), LOW U1 (FR-005 has no
own task - covered by T009 and the review).

## Implementation

- T002 `src/common/salisoudfentry.h`: `SalIsoUdfFolderEntryWalkable(int stored)` - true for `stored > 0` or `-1`
  (embedded data, only for a non-empty area), false for 0 (L_AD 0, any valid type) and every other negative value
  (the refusal `UDF_FE_REFUSED` = -2).
- T003 `src/saltests/saltests.cpp`: `TestIsoUdfFolderEntry_362` - the values, and a grid model of the reader's result
  (L_EA x L_AD x type 0 - 7 x FE/EFE, on `SalIsoUdfEntryDescs`): walked == accepted and L_AD > 0; the writers' real
  shapes (short 8, long 16, embedded 40) walked. saltests 29,700 -> **29,711 checks, 0 failed**.
  Negative control: the rule set to the old behaviour (`stored != -2`) -> **3 failed** (`!Walkable(0)`,
  `!Walkable(-3)`, `rule`); restored -> 0 failed.
- T004 `src/plugins/uniso/udf.cpp` `CUDF::MapICB(CAD, CICBTag*, CAD*)`: `if (!SalIsoUdfFolderEntryWalkable(n)) return 0;`
  (was `n == UDF_FE_REFUSED`). Both callers already handle 0 (root "Bad root ICB" + incomplete; sub-folder
  incomplete, not descended). The Release-build walk from the terminator's unset `Offset` (item's note) is no
  longer reached for such an entry.
- Trap: clang-format (VS 2022 LLVM) on the three files re-aligned unrelated trailing comments in `udf.cpp` and
  reflowed ~2,000 lines of `saltests.cpp` (the files are not fully formatted to that version) - undone with a
  script that kept only this feature's hunks; the diff is 75 + / 2 -.

## After the fix

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED (the C4267 warning at `udf.cpp` `ReadFileEntry(BYTE[], bool, CFileEntry*)` is older) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 29,711 checks, 0 failed |
| probe | `iso362_probe.ps1 -Label after` -> `probe/result_after.txt` | **PASS 22, FAIL 0** (before 15 / 7); registry identical |
| regression 330 | `iso330_probe.ps1` -> `probe/regress_330.txt` | PASS 30, FAIL 0 (as 361's regress_330) |
| regression 361 | `iso361_probe.ps1` -> `probe/regress_361.txt` | PASS 24, FAIL 0 (as recorded) |
| encoding | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |

Rows after: L-ROOTLAD0 / L-ROOTEMB0 "Bad root ICB"; R-ALAD0 / R-AEMB0 / R-ZLAD0 the other files extracted, no window,
image **kept**; R-ROOTLAD0 "Bad root ICB", ISO 9660 part extracted, kept; R-ROOTEMB0 "Bad root ICB", kept; controls
L-UE, C-UD, C-UE (real empty folders e extracted), C-MKCDR unchanged (deleted).

No UI string, dialog or resource changed - no `.slt` refresh (stop-rules 2.13 not triggered).

## Review

### Review 1 (refute-first, general-purpose agent, HEAD d9df08bd) - no MUST

- Re-ran: callers enumerated independently (the same two); saltests 29,711 / 0; the negative control reasoned
  through; the feature's probe from a copy 22 / 0 (before 15 / 7); registry identical; `git status` empty.
- SHOULD 1 - a folder entry with L_AD 8 whose only descriptor has extent length 0 still walked 0 bytes: listed empty,
  no mark, image deleted (folder a 88 -> 0, root 172 -> 0). By ECMA-167 4/12 a length-0 extent ends the descriptor
  sequence - the entry describes no byte, the item's own harm. **Fixed here** (the clarification "unchanged" was
  this run's own conservative answer, not a maintainer's decision; it kept the data loss):
  `SalIsoUdfFolderEntryWalkable(int stored, unsigned long long firstLen)` - walkable only when something is stored
  and the first descriptor's length (extent length without the type bits; the embedded data's length) is > 0;
  `MapICB` passes `file->Length` and does not read `file` for a refused entry (`n == UDF_FE_REFUSED ||`).
  saltests group extended with first-extent lengths: **29,715 checks, 0 failed**; negative control (the length
  clause disabled) -> **3 failed** (`!Walkable(1, 0)`, `!Walkable(-1, 0)`, `rule`), restored -> 0.
  Probe: kinds `alen0` / `rootlen0` (img362.py), rows L-ROOTLEN0, R-ALEN0, R-ROOTLEN0. On the first-fix build
  (d9df08bd): `probe/result_before_review1.txt` **3 FAIL** (no "Bad root ICB", images deleted); on the final build:
  `probe/result_after_review1.txt` **PASS 28, FAIL 0**, registry identical. Regressions again: 330 **30 / 0**,
  361 **24 / 0**.
- SHOULD 2 - a folder in more than one extent is read only to its first extent (`MapICB` reads one descriptor), the
  rest unlisted, no mark, image deleted (reviewer: 40-file root split 2,048 + 872 -> 68 of 80 files, deleted). Older
  than 362, outside the item: Inbox `iso-plug-in-a-udf-folder-stored-in-more-than-one-extent-is` (review:362).
- NOTE 1 - the saltests group models the reader instead of calling udf.cpp; the wiring is proven by the probe's
  before / after runs (they discriminate). Accepted (plug-in code is not linked into saltests).
- NOTE 2 - `UDF_DELETED` is never tested: deleted folder identifiers are listed and descended. Not measured; not
  this item - left as a note (no Inbox item without a measurement).
- NOTE 3 - the clang-format undo confirmed (source diff only the intended hunks).

### Review 2 (refute-first, general-purpose agent, HEAD 1c528005) - no MUST

- Re-ran: saltests 29,715 / 0; the feature's probe 28 / 0; a negative control - `uniso.spl` built from d9df08bd in a
  worktree, swapped into a copy of the build tree: L-ROOTLEN0, R-ALEN0, R-ROOTLEN0 FAIL there, R-ALAD0 / C-UD PASS
  (the probe discriminates); probe 356 56 / 0 (the roots of every mkudffs media type); Windows IMAPI2FS images (UDF
  1.02 / 1.50 / 2.00 / 2.01, an empty folder, a 13,960-byte folder, 123 files): 28 folder entries all walked, the
  smallest 40 bytes; whole unpack extracts all and deletes. `file->Length` is always written before it is read
  (refused: not read; L_AD 0: the terminator's 0; a descriptor: masked length; embedded: L_AD). Extent types 1 - 3 with
  a length: walked as before (no regression). Callers the same two.
- SHOULD 1 - a first extent of 1 - 37 bytes cannot hold the parent's identifier but was walked: listed empty, no mark,
  image deleted (measured with 20: folder a, the root). **Fixed here** (same harm, inside the item):
  `SAL_ISO_UDF_MIN_FID` = 38, `firstLen >= 38` (the smallest identifier; every writer measured writes 40 or more).
  saltests **29,720 / 0**; negative control (the length clause back to `> 0`) -> **5 failed**, restored -> 0.
  Probe kinds `alen20` / `rootlen20`, rows L-ROOTLEN20, R-ALEN20, R-ROOTLEN20: on the review-1 build
  `probe/result_before_review2.txt` **3 FAIL** (images deleted, no "Bad root ICB"); final build
  `probe/result_after_review2.txt` **PASS 34, FAIL 0**, registry identical. Regressions: 330 **30 / 0**, 361 **24 / 0**,
  356 **56 / 0** (its recorded result).
- The general case (an identifier that crosses the folder's declared end anywhere, `ScanDir`) is not this item and was
  not measured as a separate harm - not recorded.
- NOTE 2 - IMAPI 2.50 images fail before the folder reader (older, Inbox item exists
  `iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs`). NOTE 3 - the grid check restates the rule; the probe is
  the wiring evidence. NOTE 4 - leftover worktrees of older reviews (`%TEMP%/rev325` ...) - not this feature's.
