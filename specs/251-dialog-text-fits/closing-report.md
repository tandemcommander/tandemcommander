# Closing report - 251-dialog-text-fits
Backlog item: dialog-typed-text-cut-to-caller-buffer - Typed text cut to the caller's buffer: Make File List, user menu, viewers
Outcome: closed

## What changed

Text typed into a field that fits the field (UTF-16 units) but not the buffer the program uses
(UTF-8 bytes) is refused with "The path specified is too long." instead of being cut at a whole
character and used:
- Make File List: the file name (destination File) and the line format; a name that does not fit
  is not stored when another destination is used; its file browse refuses.
- User menu, viewers, editors: Command, Arguments, Initial directory - the items keep the whole
  text, `Validate` refuses (on OK and on leaving the page), the item selected, the field marked.
- Hot paths: path and name read whole (the code-page fallback is gone), refused at `Validate`,
  reloaded whole (`CHotPathItems::PeekName` / `PeekPath`); labels end at a whole letter.
- Drives page: new `Validate` for the "If path is inaccessible go to" path; its browse refuses.
- Edit New "Save as default" refuses; the directory menu's browse and `CCompareArgsDlg`'s browse
  refuse.
- Shared: `SalWTextFitsU8`, `SalU8TextFits` (`src/common/salunicode`), `SalWindowTextFitsU8`,
  `SalGetWindowTextU8Alloc` (`src/common/winlib`), `DlgItemTextFitsU8` (`src/dialogs.h`, 214's
  check generalised and used by 214's two dialogs).
No UI string added or removed; no plug-in interface change; no registry layout change.

## Measurements (before / after, commands)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\251-dialog-text-fits\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\251-dialog-text-fits\probe\dlg251_probe.ps1 -Exe build\tandemcommander\<Debug_x64_pre251 | Debug_x64>\tandemcommander.exe -Label <before | after>"
```

- Before (Debug x64 of c7f07bc6): PASS 26, FAIL 16 - every refusal row fails: Make File List wrote
  `out\<67 CJK letters>` instead of the typed `<…>.txt`, a line format lost `END$(CRLF)`; user menu
  Command 277 -> 258 bytes, Arguments 33,000 -> 32,769; viewer / editor Command 277 -> 258; hot path
  path / name stored as `?`; drives path 273 -> 258; Edit New default 274 -> 258; the browse buttons
  opened from a cut path; the five controls pass.
- After (this branch): PASS 42, FAIL 0; registry restored identical in every run.
- 214's probe `cm_text_probe.ps1`: 4 / 0 (`probe/regress_214.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`.
- `saltests`: `24352 checks, 0 failed` (new `TestTextFits251`); negative control (the rule loosened
  by one byte): 8 failed, reverted.
- Probe: before 26 / 16, after 42 / 0; negative control for review 1's MUST (the old hot path
  `LoadControls` restored): `hp-other*` 3 FAIL, reverted.

## Reviews (findings and what was done)

- Review 1: MUST 1 (hot path slot reloaded through fixed buffers - mojibake / cut, then stored cut)
  fixed; SHOULD 2, 3 (rows for another slot, Make File List keep / browse) added; NOTE 4 fixed;
  NOTE 6 recorded as an Inbox item; NOTE 5, 7 kept with reasons (fix-log).
- Review 2 (fresh, with review 1's findings): no MUST; SHOULD 1 (the Inbox item) added, SHOULD 2
  (spec wording of the label edit) corrected; NOTE 6 (labels) fixed at `GetDisplayName`, NOTE 7
  (`mfl-keep` seeded) done; NOTE 3-5 kept with reasons (fix-log).

## Owed to a person (with the new person-step items)

Nothing. Every probe row was driven on the hidden desktop (no keyboard, clipboard or printer
needed). Checked by reading only: the directory menu's browse (`InvokeDirectoryMenuCommand`) and
`CCompareArgsDlg`'s - the same call as the driven `drv-browse` / `mfl-browse`.

## New Inbox items (slug - title)

- more-typed-fields-cut-to-their-buffer-masks-filter-volume - More typed fields cut to their
  buffer: masks, filter, volume label, hot path label edit
