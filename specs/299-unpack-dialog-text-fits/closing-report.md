# Closing report - 299-unpack-dialog-text-fits
Backlog item: unpack-with-an-external-unpacker-cuts-a-long-target-path-and - Unpack with an external unpacker cuts a long target path and mask
Outcome: closed

## What changed

- `src/dialogs.h`: `CUnpackDialog::Validate` declared.
- `src/dialogs3.cpp`: `CUnpackDialog::Validate` - the target path (`IDE_PATH`), then the mask
  (`IDE_MASK`) measured whole with `DlgItemTextFitsU8(..., MAX_PATH)` (the caller's buffers);
  refused with "The path specified is too long." (`IDS_TOOLONGPATH`), the dialog stays, the field
  whole. No new string, no buffer grown, no limit added.
- The dialog serves every unpacker of Alt+F9 (and a plug-in's unpack command), not only external
  unpackers as the item's title said.

## Measurements (before / after, commands)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\299-unpack-dialog-text-fits\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\299-unpack-dialog-text-fits\probe\unpack299_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

(the before runs used a scratch copy with `-Lib`). Before (build of 4787b56b): `result_before.txt`
PASS 7 / FAIL 3 - path-cjk (262 bytes) and path-ascii (262 characters) unpacked into the cut folder,
mask-cjk (260 bytes) unpacked a.k instead of a.kp; `result_before_both.txt` FAIL - both fields too
long with "Delete archive after unpacking": only a.k unpacked into the cut folder and a.zip deleted
(a.kp lost). After: `result_after.txt` PASS 12 / FAIL 0 - the four refuse rows refused, field whole,
nothing under the target, a.zip kept; controls ctl (mask 259 bytes) and ctl-path (path 255 bytes)
unpacked as typed. Registry restored identical in every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64): `BUILD SUCCEEDED`.
- `saltests.exe`: `saltests: 26443 checks, 0 failed`.
- Probe 299: 12 / 0 (before 4 FAIL - the negative control, the same probe on the build without the
  change). Regression: 204's `unpack_dir_probe.ps1 -Only f9-zip` 2 / 0 (`probe/regress_204.txt`).
- `git diff main -- src/lang`: empty (no new string).

## Reviews (findings and what was done)

One refute-first review: no MUST. It re-ran the probe (12 / 0). SHOULD - the dialog's default target
(the other panel's path) is copied cut with `lstrcpyn(..., MAX_PATH)` before the dialog and accepted
(its scratch probe: 2 FAIL on the fixed build): outside the item (not typed text) -> Inbox, with
NOTE 1 (a plug-in's unpack mask cut the same way) and NOTE 2 (the archive subfolder name dropped
silently). NOTE 3 (probe gaps: exact path limit, the second OK of `both`, focus) accepted with
reasons in `fix-log.md`; NOTE 4 (the message wording) as the item asks; NOTE 5 (state the archive
loss) done in FEATURE-HISTORY and CHANGELOG.

## Owed to a person (with the new person-step items)

Nothing. (Optional, `quickstart.md`: paste a long path by hand into the field - the probe sets the
text by WM_SETTEXT; typing is not needed to prove the refusal.)

## New Inbox items (slug - title)

- unpack-dialog-offers-a-long-target-panel-path-cut-and - Unpack dialog offers a long target panel path cut and unpacks into the cut folder
