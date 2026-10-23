# Closing report - 316-unpack-subdir-space
Backlog item: unpack-into-a-subfolder-named-after-an-archive-whose-name - Unpack into a subfolder named after an archive whose name starts with a space drops the space
Outcome: closed

## What changed

`src/fileswn7.cpp` `CFilesWindow::Unpack`: the `SalGetFullName` call after the Unpack dialog's OK
passes `allowRelPathWithSpaces = TRUE` (as `SalParsePath` does for Copy/Move targets), so a relative
target keeps its leading spaces. An existing folder of that name receives the files; a new one is
refused by the existing create rule (`CheckAndCreateDirectory`, `manualCrDir = TRUE`: "Error Creating
Directory", invalid name, the dialog again) - the refusal the absolute entry already got. No new UI
string, no settings, no plug-in interface change. Also: `CHANGELOG.md` (0.1.11 unreleased) entry,
`specs/FEATURE-HISTORY.md` entry (index row "Archives in the core").

## Measurements (before / after, commands)

Probe `specs/316-unpack-subdir-space/probe/unpack316_probe.ps1` on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\316-unpack-subdir-space\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\316-unpack-subdir-space\probe\unpack316_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

- Before (build of b125acf7): first measurement `result_before_v1.txt` 5 FAIL / 9; the final probe
  `result_before.txt` **6 FAIL / 12 PASS** - every leading-space row unpacked into the folder
  without the space (also when ` ssss` existed, and when a file ` ssss` existed).
- After: `result_after.txt` **18 PASS / 0 FAIL**, registry restored and identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s)
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED
- `saltests.exe`: saltests: 27440 checks, 0 failed
- Probes: 316 18 / 0; 315's probe `regress_315.txt` 22 / 0

## Reviews (findings and what was done)

One refute-first review: no MUST, no SHOULD. It re-ran the probe (18 / 0) and drove scratch rows
(`' ..'`, `' .'`, `' ..\x'`, a tab, archives `' ...zip'` / `' ..zip'`, `' ssss\new'`) - all refused or
correct, nothing written outside. Five NOTEs accepted (see `fix-log.md` *Review*).

## Owed to a person (with the new person-step items)

Nothing. (Not driven, recorded: the cursor's next focus after unpacking into ` ssss` - read;
typing with a real keyboard - the probe sets the same text with WM_SETTEXT.)

## New Inbox items (slug - title)

- pack-with-a-relative-archive-name-that-starts-with-a-space - Pack with a relative archive name that starts with a space drops the space
