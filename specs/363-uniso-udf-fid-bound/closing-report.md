# Closing report - 363-uniso-udf-fid-bound

Backlog item: iso-plug-in-a-udf-file-identifier-with-a-long-implementation - ISO plug-in: a UDF file identifier with a long implementation-use field reads past its buffer
Outcome: closed

## What changed

- `src/common/salisoudfentry.h`: new rule `SalIsoUdfFidLength(held, pos, lFI, lIU, len)` - a UDF File Identifier
  Descriptor (38 bytes + L_IU + L_FI, padded to 4) is read only when it lies whole in the bytes the walk holds;
  computed by subtracting from what is left (no wrap).
- `src/plugins/uniso/udf.cpp` / `udf.h`: `CUDF::ReadFileIdentifier(sector, held, ...)` asks the rule and returns 0
  without decoding the name when refused; `CUDF::ScanDir` passes `sizeof(directory) - p` and on 0 takes the existing
  invalid-tag path - "Invalid UDF Tag ID.", the folder's walk ends, the listing is marked incomplete (feature 330), so
  a whole unpack with "Delete archive after unpacking" keeps the image. No new UI string, no ABI change.
- `src/saltests/saltests.cpp`: `TestIsoUdfFid_363` (24 value checks + a 4-check grid model of the walk).
- Probe `probe/iso363_probe.ps1`, `probe/img363.py`, `probe/mkbig363.sh`.

## Measurements (before / after, commands)

- Before (main 443ee778, Debug): `iso363_probe` **12 / 8** - no window; the name read past the buffer listed as `_`;
  the image deleted in all five damaged unpack rows (`probe/result_before.txt`).
- After: **20 / 0** (`probe/result_after.txt`); with review 1's multi-sector rows **24 / 0**
  (`probe/result_after_review1.txt`). Command:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\363-uniso-udf-fid-bound\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\363-uniso-udf-fid-bound\probe\iso363_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED (no `full` needed: no string, resource or language change).
- `saltests` 29,720 -> **29,748 checks, 0 failed**; negative control (no bound) 18 failed.
- Probes: 363 24 / 0; regressions 330 30 / 0, 361 24 / 0, 362 34 / 0; registry restored and identical every run.

## Reviews (findings and what was done)

- Review 1: no MUST. Re-ran before (12 / 8 on an old `uniso.spl`) and after (20 / 0); five rule mutants each failed
  saltests (4 - 18). SHOULD 1 - no valid multi-sector folder in the probe: rows L-BIG / C-BIG added (`mkbig363.sh`),
  24 / 0. NOTE 1 (an over-one-block identifier that fits is read) - as specified; NOTE 2 (closing) - done; NOTE 3 (a
  check without `len == 0`) - tightened.

## Owed to a person (with the new person-step items)

- The changelog: `CHANGELOG.md` has no `## [Unreleased]` section (the tree is at the released 0.2.0); the run does
  not create one. Entry to add under the next version's heading:

  ```text
  - **A damaged UDF disc image could make the ISO plug-in read past its buffer, list made-up `_` entries, and Unpack with "Delete archive after unpacking" deleted the image** (feature 363).
    - **Before:** a file identifier in a UDF folder says how long its "implementation use" field and its name are, and the ISO plug-in believed it. With a damaged length (up to 64 KB) the name was read from memory past the folder data the plug-in holds; it came out empty and the entry was listed as `_` (a folder `_`, an empty file `_`), the listing went on without a mark, and a whole Unpack (Alt+F9) with "Delete archive after unpacking" extracted a wrong tree and deleted the image.
    - **Now:** such an identifier is refused like an identifier with an invalid tag: "Invalid UDF Tag ID." is shown, the rest of that folder is not read, the listing is marked incomplete, and a whole Unpack extracts everything readable and keeps the image. Valid images list and unpack exactly as before.
    - **Limitation:** an identifier longer than UDF allows but still inside the read data is read as before. Not tried with an image damaged by a real medium.
  ```

## New Inbox items (slug - title)

- none
