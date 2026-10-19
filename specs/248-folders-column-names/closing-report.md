# Closing report - 248-folders-column-names
Backlog item: drobna-chyba-textu-v-hlavicce-pro-zobrazeni-plochy-v-cestine - Desktop view (Folders plug-in) column headers show mojibake for accented names
Outcome: closed

## What changed

- `src/plugins/folders/fs1.cpp`, `CPluginDataInterface::GetShellColumns`: the shell's column
  name (UTF-16) is converted to the Windows code page with `SalWToCodePageWhole` instead of to
  UTF-8 (`SplWToU8`). The core draws column names in the code page (MBCS build), so the Desktop
  view's headers now read "Typ položky" / "Datum změny" instead of "Typ poloĹľky" /
  "Datum zmÄ›ny" (GitHub issue #13).
- `src/common/salcpfit.h` (new, header-only, usable by plug-ins): `SalWToCodePageWhole` - no
  best-fit; a text that does not fit is cut at a whole character (never half a surrogate pair or
  a double-byte character, never empty); a torn high surrogate at the end is dropped; no flag on
  the UTF-8 / UTF-7 system code page and a retry without it on `ERROR_INVALID_FLAGS`; a buffer of
  fewer than 2 bytes returns empty before the call (size 0 would return the needed size).
- `src/plugins/folders/folders.h`: `CShellColumn::Name` documented as code page.
- `src/saltests/saltests.cpp`: `TestCpFit248` (22 checks).
- Per the maintainer's decision: plug-in interface (`spl_com.h`, `LAST_VERSION_OF_SALAMANDER`)
  and the core unchanged; cell texts stay UTF-8 (interface 104).

## Measurements (before / after, commands)

- Before (main 7f37ec00, cs-CZ, ACP 1250): shell Desktop columns "Název", "Velikost",
  "Typ položky", "Datum změny"; UTF-8 bytes decoded as cp1250 = the reported text (Python).
- Probe (PowerShell, hidden desktop):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\248-folders-column-names\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\248-folders-column-names\probe\folders248_probe.ps1 -Expect <before|fixed> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`
  - before (`probe/result_before.txt`): PATH, NAME, CELLS, END PASS; **COL2, COL3 FAIL** (OCR
    "Typ poloĹlky", "Datum zmÄ»ny"); COL1 INFO.
  - after (`probe/result_after.txt`, final build): PASS 6, FAIL 0, COL1 INFO; header crop:
    "Název / Přípona | Velikost | Typ položky | Datum změny".
  - Registry restored and SHA-256-identical in every run.
- Byte checks (P/Invoke) of the flags and limits: fix-log *Fix* and *After review 1*.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64) → `BUILD SUCCEEDED`. (`build.cmd full` not needed: no UI string,
  resource, language or plug-in list changed.)
- `saltests` → `saltests: 24319 checks, 0 failed` (24,297 before; +22). Negative controls: best-fit
  allowed → 2 failed; one-unit cut → 2 failed; no `ERROR_INVALID_FLAGS` retry → 1 failed.
- Probe `folders248_probe.ps1`: before COL2 / COL3 FAIL → after PASS 6 / FAIL 0.

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD 2 (empty header for a name that does not fit, against
  "must not be empty") and SHOULD 3 (surrogate torn by the 29-unit read) fixed by
  `salcpfit.h`; NOTE 4 (UTF-8 system code page) handled; SHOULD 1 (duplicate columns after a
  view-mode switch, older than 248) and NOTE 7 (interface does not document column names as
  code page) → Inbox.
- Review 2: no MUST. SHOULD 1 (pair-aware cut and flag retry not pinned by checks) fixed with
  three checks, each proved by a negative control. NOTEs recorded (code points not graphemes;
  "?" on a mismatched code page; empty shell name still empty - older, not known reachable).
- Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- Answer and close GitHub issue #13 (draft in `specs/248-folders-column-names/reply.md`).
- No person-step item: the probe drove the real header on the hidden desktop; acceptance
  scenario 3 (English Windows) was not driven - its names are pure ASCII and cannot show the
  defect.

## New Inbox items (slug - title)

- `desktop-view-folders-plug-in-repeats-its-shell-columns-after` - Desktop view (Folders
  plug-in) repeats its shell columns after a view-mode switch
- `plug-in-interface-does-not-say-that-column-names-are-code` - Plug-in interface does not say
  that column names are code-page text
