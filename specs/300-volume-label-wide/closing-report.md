# Closing report - 300-volume-label-wide
Backlog item: volume-label-written-through-ansi-api - Drive Information writes the volume label through an ANSI API
Outcome: closed

## What changed

- `src/dialogs3.cpp` `CDriveInfo::Validate`: the label and the volume path are converted with
  `SalU8ToWAlloc` and written with `SetVolumeLabelW` (was `SetVolumeLabel` = `SetVolumeLabelA`,
  reading the UTF-8 bytes in the code page). A failed conversion writes nothing and shows the
  existing "Unable to change drive label." with `ERROR_NO_UNICODE_TRANSLATION` (or
  `ERROR_NOT_ENOUGH_MEMORY`), the dialog stays, the field marked. The panels' hands-off now
  brackets only the real call. Unchanged: 069's "unchanged label → no write", 270's too-long
  refusal, an empty label clears the label.
- `tools/check_encoding.py`: `SetVolumeLabel` added to `ANSI_NAME_API` (report-only draft rule
  `ansi-api-on-utf8-path`; `--strict` unaffected).
- `CHANGELOG.md` (0.1.11 unreleased), `specs/FEATURE-HISTORY.md` (entry, index row *Encoding*).
- No UI string added or removed.

## Measurements (before / after, commands)

| What | Before (82bf0dac) | After |
|------|-------------------|-------|
| `dumpbin /imports tandemcommander.exe` (PowerShell), `VolumeLabel` lines | `5BC SetVolumeLabelA` | `5BD SetVolumeLabelW` only (clean link; the incremental link kept a stale `SetVolumeLabelA`, fix-log *Measurement after*) |
| `python tools/check_encoding.py --rule ansi-api-on-utf8-path` | 39 (40 with the call listed, hit `dialogs3.cpp:1341`) | 39, no `SetVolumeLabel` |
| `checker_negative_control.py` | - | fixed 0 hits, old call put back 1 hit → PASS |
| `probe/vol300_probe.ps1` (hidden desktop) | PASS 6 / FAIL 0 | PASS 6 / FAIL 0 |

The probe rows drive the unelevated error path, the unchanged label and the too-long refusal -
they pass before and after; the defect itself is shown by the import table. FR-002 (a non-ASCII
mounted-folder path) is proven by the import table and by reading only.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- `.\build.cmd` (and `.\build.cmd rebuild`) → `BUILD SUCCEEDED`
- `saltests` → `saltests: 26443 checks, 0 failed`
- probe `vol300_probe.ps1` → PASS 6, FAIL 0, NOT DRIVEN 0; registry restored, SHA-256 identical

## Reviews (findings and what was done)

Review 1 (refute-first): no MUST. S1 (the checker rule is report-only, `--strict` would not catch a
returning call) → spec US3 / SC-002 reworded; no strict rule (the item asked for the list entry,
*Clarifications*). S2 (no runtime proof of FR-002) → accepted, stated above. N3
(`GetDiskFreeSpaceEx` A in `Transfer`, display only, one of 068's classified 39) - not recorded.
N4 (the label field is a code-page edit) → Inbox item; the code comment corrected. N5 (fixed
`MAX_PATH` path buffers, pre-existing, a cut path fails the write) - not recorded. N6 (the rule is a
naming heuristic) - inherent. Details: `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

`check-a-volume-label-with-accented-letters-written-by-drive` - write `Zálohy` (and an empty
label) on a USB stick or an elevated VHD through Drive Information; Explorer shows it exactly.

## New Inbox items (slug - title)

- `drive-information-turns-a-volume-label-outside-the-code-page` - Drive Information turns a volume label outside the code page into question marks
- `check-a-volume-label-with-accented-letters-written-by-drive` - Check a volume label with accented letters written by Drive Information (300)
