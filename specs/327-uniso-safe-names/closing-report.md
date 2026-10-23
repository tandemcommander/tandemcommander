# Closing report - 327-uniso-safe-names
Backlog item: iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe - ISO plug-in: Joliet and ISO 9660 names are not made safe before extraction
Outcome: closed

## What changed

- `src/common/salarcname.h`: `SalArcCleanItemName` (N3) - feature 087's rule for one name (control
  characters, `\` `/` `:` `<` `>` `"` `|` `?` `*` -> `_`, trailing dots / spaces -> `_`, device names
  `_`-prefixed, never cut: the first letter becomes `_` when the prefix does not fit); the shared
  `SalArcNameDetail::CleanOneName`, which `SalSuspCleanRockRidgeName` (feature 326) now calls with its
  exact old behaviour.
- `src/common/salsusp.h`: `SalIsoRemoveVersion` (review 1) - the version suffix and one separator dot
  of an ISO 9660 / Joliet file identifier, also in images without version numbers.
- `src/plugins/uniso`: every name read from the image - ISO 9660, Joliet (files and folders), UDF,
  HFS+, Xbox, the `ISO (...)` / `UDF (...)` / `HFS (...)` label folders - is made safe before it is
  listed and before it joins the descent path (`MakeSafeName`); the five readers' `UnpackFile` join the
  listed name made safe once more (`AppendSafeName`).
- `CHANGELOG.md` (0.1.11 — unreleased), `specs/FEATURE-HISTORY.md` (entry, index row "Archives").

## Measurements (before / after, commands)

- `tools\run_on_hidden_desktop.ps1 ... specs\327-uniso-safe-names\probe\iso327_probe.ps1`:
  main e50d62ad -> `probe/result_before.txt` **PASS 19, FAIL 39** (streams `12:30...`, device and
  trailing-dot names kept, `/` and `..\` names lost, the label `v\..\..\w` wrote the volume outside the
  target); branch -> `probe/result_after.txt` 58 / 0, `result_after_review1.txt` 64 / 0 (+ NOVER),
  `result_after_review2.txt` **77 / 0** (+ ULABEL, HLABEL); negative control without the label
  cleanings -> `result_review2_negative.txt` 68 / 9.
- Regressions: `iso326_probe` -> `probe/result_326_after.txt` 28 / 0; `iso322_probe` ->
  `probe/result_322_after.txt` 18 / 0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64).
- `saltests.exe` -> `saltests: 27986 checks, 0 failed` (27937 before); mutants of each part of the rule
  and of the separator rule fail (6 / 5 / 10 / 15 / 2 / 7 checks).
- Probes as above; registry restored identical after every run.
- No UI string, dialog or menu changed - no `.slt` refresh.

## Reviews (findings and what was done)

- Review 1: the launch ended with its session; its partial work found that a version-less image's
  `README.` listed as `README_` - fixed (`SalIsoRemoveVersion`, probe set NOVER). A registry backup it
  left was restored (identical) at the continued run.
- Review 2: one launch ended with its session (partial: 64 / 0, 28 / 0); the third completed - 0 MUST,
  1 SHOULD (the UDF / HFS+ label folders were not proven by any probe set - sets ULABEL / HLABEL added,
  negative control 68 / 9), 5 NOTEs (folder names cleaned at listing only - accepted; Joliet `x.` / `x`
  both `x`, spec aligned; `;` cut and `a:b` / `a_b` collision - the format's and 087's classes; the
  HFS label `sprintf` - pre-existing).

## Owed to a person (with the new person-step items)

- Nothing.

## New Inbox items (slug - title)

- `iso-plug-in-an-hfs-file-skipped-or-cancelled-at-extraction` - ISO plug-in: an HFS+ file skipped or
  cancelled at extraction leaks its read buffer.
