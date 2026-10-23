# Closing report - 317-pack-name-space
Backlog item: pack-with-a-relative-archive-name-that-starts-with-a-space - Pack with a relative archive name that starts with a space drops the space
Outcome: closed

## What changed

- `src/fileswn7.cpp` `CFilesWindow::Pack`: the `SalGetFullName` call after the Pack dialog's OK
  passes `allowRelPathWithSpaces = TRUE` (as feature 316 for Unpack, as `SalParsePath` for
  Copy/Move), so a relative archive name keeps its leading spaces; every later step (the "packed
  into itself" check, the "add or overwrite?" question, Overwrite's aside, the packer, the refresh)
  uses that name.
- A name whose last part is only spaces and dots (` ..`, ` .`) is refused through the existing
  error path (`IDS_PATHISINVALID`, "The path specified is invalid.", the dialog again): kept as
  typed, the ZIP plug-in (which opens archives through `\\?\`) created files literally named ` ..`
  / ` .` - measured. Pure rule `SalPackNameIsOnlyDotsAndSpaces` in the new header-only
  `src/common/salpackname.h`; 16 checks `TestPackName317` in `src/saltests/saltests.cpp`; header
  listed in `src/vcxproj/saltests/saltests.vcxproj`.
- No new UI string, no settings, no plug-in interface change. Also: `CHANGELOG.md` (0.1.11
  unreleased) entry, and the 316 entry's limitation sentence about Pack updated; `specs/FEATURE-HISTORY.md`
  entry (index row "Archives in the core").

## Measurements (before / after, commands)

Probe `specs/317-pack-name-space/probe/pack317_probe.ps1` on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\317-pack-name-space\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\317-pack-name-space\probe\pack317_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

- Before (build of d526127f; the final probe on `main`'s Pack code): first measurement
  `result_before_v1.txt` 7 FAIL / 11; final `result_before.txt` **11 FAIL / 17 PASS** - every
  leading-space row packed into the name without the space (`report.zip` asked about and changed
  by Add), the ` ..` / ` .` rows not refused.
- Intermediate (only `allowRelPathWithSpaces`): 26 / 2 - files ` ..` / ` .` created.
- After: `result_after.txt` **28 PASS / 0 FAIL**, registry restored and identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s)
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED
- `saltests.exe`: saltests: 27456 checks, 0 failed (27,440 + 16)
- Probes: 317 28 / 0; 316's probe `regress_316.txt` 18 / 0; 241's probe `regress_241.txt` 8 / 0

## Reviews (findings and what was done)

One refute-first review: no MUST. It re-ran the probe (28 / 0) and drove 13 scratch names
(` ..\x.zip` with existing archives and Add / Overwrite, ` .\x.zip`, a tab, slash forms) - each a
packer error, nothing written or touched. SHOULD: the out-of-scope finding was not yet in the
backlog - added (`pack-archive-name-trailing-dot-or-space`). Four NOTEs accepted (tab and
` ..\x.zip` now fail in the packer, `   .zip`, closing documents) - see `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

Nothing. (Not driven, recorded: external archivers - they get the name quoted; typing with a real
keyboard - the probe sets the same text with WM_SETTEXT.)

## New Inbox items (slug - title)

- pack-archive-name-trailing-dot-or-space - Pack creates an archive with a trailing dot or space Windows tools cannot open
