# Fix log - 283 mask code page fold

Backlog item `mask-matcher-code-page-fold`. Autonomous run, started 2026-10-21 at main cb0d80f5.

## Measurement before (main cb0d80f5)

Sites named by the item, located by function (lines move):

| Site (src/masks.cpp) | Reached when | UTF-8 name? |
|---|---|---|
| `AgreeMaskA` `LowerCase[*filename] == LowerCase[*mask]` (2 lines) | `AgreeMask`: name and mask both ASCII (`SalIsASCII`), or `SalU8ToWAlloc` fails (not UTF-8) | no - `AgreeMaskW` (NFC + `CharLowerW`) |
| `AgreeQSMaskAux` `LowerCase[...]` | only caller `fileswn0.cpp` `AgreeQSMaskU8`, when mask and name are both ASCII | no |
| `CMaskGroup::AgreeMasks` `StrICmp(ext, mask + 3)` - include, exclude, table | every mask `PrepareMasks` marks `MASK_OPTIMIZE_EXTENSION` (`*.xxx`) | **yes** |
| `COMPUTEMASKGROUPHASH` (`LowerCase` of the extension's first three bytes) | >= 10 extension include masks | **yes** |

Reachability: `CMaskGroup::AgreeMasks` is called from Select/Unselect (fileswn1.cpp), the panel
filter (fileswn3.cpp), highlighting (fileswn4.cpp), Convert (fileswn5.cpp via `CCriteriaData`),
Copy/Move/Find criteria (fileswn6.cpp, fileswna.cpp), unpacker choice (fileswn7.cpp, fileswnb.cpp),
Find (find.cpp, finddlg1.cpp), Recycle Bin masks (worker.cpp `RecycleMasks`), the viewer
(viewer2.cpp), zip.cpp, mainwnd5.cpp, dialogs4.cpp, cfgdlg.h and the plug-in service.

Probe (written for this feature, in the style of 270's `mask270_probe.ps1`, driver 098's library):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\283-mask-code-page-fold\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\283-mask-code-page-fold\probe\mask283_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

Debug build of cb0d80f5, ACP 1250: **PASS 14, FAIL 6** (registry restored, identical hash):
- `miss` `A.ČTX` / `*.čtx`: "There is no file that matches the specified file mask"
- `miss-hash` the same after ten ASCII masks (table): no match
- `miss-excl` `|*.čtx` converted `A.ČTX`
- `false` `*.ĥ` **converted** `x.Ĺ` (UTF-8 C4 A5 / C4 B9; CP1250 0xA5 Ą folds to 0xB9 ą)
- `false-hash` the same through the table
- `nfd` `A.C`+U+030C+`TX` / `*.čtx`: no match
- controls `same`, `ascii`, `ascii-hash`, `ascii-no`: PASS.

## Decisions

- Fix in the classification only: an extension that is not all ASCII is not an EXTENSION mask
  (it goes to `AgreeMask`). Rule in `src/common/salmaskopt.h`, contract
  `contracts/mask-optimize-kind.md`. ASCII masks byte for byte unchanged.
- The two unreachable byte loops stay (their guard comments already state the condition).
- analyze: E2 (SC-004 speed has no own task) accepted - ASCII groups keep the identical shortcut
  and table (differential check T007); an accented `*.xxx` costs what any accented mask costs.

## Implementation

- `src/common/salmaskopt.h` (new): `SalMaskOptimizeKind` - the old classification of
  `CMaskGroup::PrepareMasks` (the `*` / `*.*` test still `lstrcmpA`) + an extension byte >= 0x80
  makes the mask `SAL_MASKOPT_NONE`.
- `src/masks.cpp`: `PrepareMasks` calls it (`hashableMasks` counts only EXTENSION include masks,
  as before); `static_assert` that the values equal `MASK_OPTIMIZE_*`; comments at the table key
  and in `AgreeMasks`. The `StrICmp` sites and `COMPUTEMASKGROUPHASH` are unchanged - they now see
  ASCII extension masks only. The encoding guard did not flag them (before or after).
- `src/saltests/saltests.cpp`: `TestMaskOptimize283` - 40 checks: the contract's table (25), the
  old shortcut's measured defects under emulated CP1250 / CP1252 tables (`ČTX`/`čtx` unequal,
  `Ĺ`/`ĥ` and `Ě`/`Ċ` equal) and the new route for those masks (8), the emulated table equals the
  process's real `CharLowerA` table (1), a differential over 597,871 generated masks x 2 modes =
  1.2 M cases (alphabet `* ? # . a B 1` + C4 8D, lengths 0-6 - widened from 0-5 after review 1: ASCII masks classified as before, others as
  before or NONE, some do change) (4), no continuation byte 0x80-0xBF folds to ASCII in any ANSI
  code page installed (874, 932, 936, 949, 950, 1250-1258) (2).
- clang-format: `salmaskopt.h` and `masks.cpp` clean; in `saltests.cpp` only the new block was
  formatted (`--lines`), the file's older unformatted parts left as they are.

### Unreachable sites (research R1) - left as they are

- `AgreeMaskA`: `AgreeMask` calls it only when `SalIsASCII(filename) && SalIsASCII(mask)`, or
  when `SalU8ToWAlloc` fails for one of them (not UTF-8 - the transitional byte fallback).
- `AgreeQSMaskAux`: only `fileswn0.cpp` `AgreeQSMaskU8` calls `AgreeQSMask`, and only when
  `SalIsASCII(mask) && SalIsASCII(filename)`.

### Names starting with a dot / with several dots (spec Edge Cases)

An accented `*.xxx` mask now goes through `AgreeMask(fileName, "*.xxx", hasExtension)`. `*`
matches any prefix, `.xxx` must be the end of the name: `a.b.čtx` matches (as the shortcut did
with ext = after the last dot); `.čtx` matches (`*` empty) whether the caller says it has an
extension or not (the shortcut's `.cvspass` special case gave the same); a name without a dot
never matches (`hasExtension == FALSE` lets only `*.` / `*.*` tails pass). Same answers as the
shortcut gave for ASCII.

## Verification

| Check | Command | Result |
|---|---|---|
| build | PowerShell `.\build.cmd` | `BUILD SUCCEEDED`, exit 0 |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 25051 checks, 0 failed` (25,011 + 40) |
| saltests negative control | the `>= 0x80` test disabled in `salmaskopt.h`, rebuilt | `25051 checks, 11 failed` (the 8 accented table rows, the 2 new-route checks, `changed > 0`) - restored |
| probe negative control | the same build, `probe/result_negative_control.txt` | PASS 14, FAIL 6 - the six rows of the before run |
| probe after | `probe/result_after.txt` | **PASS 20, FAIL 0**, NOT DRIVEN 0; registry restored + identical (SHA-256 A3805966...) |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)`, exit 0 |

## Review

**Review 1** (independent agent, refute-first, at 50d7ba68): **no MUST**. It rebuilt, saltests
25051 / 0 failed, encoding guard 0, re-ran the probe on the hidden desktop (`probe/result_review.txt`:
PASS 20, FAIL 0, registry restored + identical), and ran its own negative control (dropping the
`'.'` stop of the ASCII path in `salmaskopt.h`: 2 checks failed - the `*.a.b` table row and
`asciiMismatch == 0`; header restored byte for byte and rebuilt). Callers enumerated (core and
plug-ins): every one passes `NULL` or the part after the last dot as the extension, so
`AgreeMask(name, "*.xxx", ...)` answers as the old shortcut did for the same letters; only false
folds (`ĥ`/`Ĺ`) disappear; the Recycle Bin masks now recycle `A.ČTX` for `*.čtx` instead of
deleting it permanently.

- SHOULD 1 - the fix-log said "1.2 M masks, lengths 0-5" but the loop ran 0-5 (132,860 cases) and
  T007 asked for 0-6. **Fixed**: the loop runs 0-6 (1,195,742 cases); saltests 25051 / 0 failed
  (12 s for the whole suite); this log corrected.
- NOTE 2 - ASCII `*.ext` masks still compare bytes with a UTF-8 extension; three characters NFC-
  normalize to ASCII (U+212A Kelvin -> `K`, U+037E -> `;`, U+1FEF -> `` ` ``), so `*.k` misses
  `x.` + U+212A while `*k` matches it. Accepted (spec Assumptions / Edge Cases: an ASCII extension
  mask vs an accented extension keeps the byte comparison; under the file system's rule a
  character outside ASCII is never the same name as an ASCII letter - 092). The `AgreeMasks`
  comment says "as AgreeMask does for an ASCII name" - accurate.
- NOTE 3 - the "every code page" claim is checked against the real `CharLowerA` table only for the
  running ACP (1250); for the other pages the emulation is used. Accepted and stated here: the
  emulation is the documented behaviour of `CharLowerA` (code page -> UTF-16 -> lower case -> code
  page), and it matched the real table byte for byte in 1250.
- NOTE 4 - an accented `*.xxx` mask now costs the general matcher's conversions and allocations
  per name (also highlighting masks, per painted item). Accepted by spec SC-004 / Clarification 3;
  not measured.
- NOTE 5 - pre-existing, outside the item: `PrepareMasks` copies one mask into
  `char maskBuf[MAX_PATH]` / `buf[MAX_PATH]` without a bound while the group holds 1001 bytes.
  **New Inbox item** `mask-group-prepare-unbounded-mask-copy` (review:283), not reproduced.
- NOTE 6 - `CPackerFormatConfig::PackIsArchive` (`src/pack3.cpp`) folds archive-name bytes through
  `LowerCase` (bucket + compare), deferred by 092 with an allow comment. Outside the item (not a
  mask group); reachable only with a user-defined accented archive extension (the shipped ones are
  ASCII). Recorded here, no item.

One review was enough (no MUST).
