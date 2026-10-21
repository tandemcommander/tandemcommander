# Closing report - 287-regedt-move-class-name
Backlog item: regedit-key-name-buffer-size-and-move-rows - Registry Editor: fs3.cpp passes a third of the key-name buffer size
Outcome: closed

## What changed

- The item's first part - `fs3.cpp` (`AcceptChangeOnPathNotification`) passing `MAX_KEYNAME` as
  the size of a `3 * MAX_KEYNAME` buffer - was **already fixed by feature 131** (d041841a). Recorded,
  not changed.
- Measuring the item's second part found a real defect: the Registry Editor's "Class name of the key
  cannot be copied to the target key" question **could never appear**, because `CopyOrMoveKey`
  (`src/plugins/regedt/fs5.cpp`) read the target's class name from the source key. Copy / Move into
  a key of the same name with another class merged silently; Move then deleted the source. Now the
  target key's class name is read (one argument list: `targetHKey, targetRoot, target`).
- A hidden-desktop probe `probe/move287_probe.ps1` drives Move of a key with a Czech name, the
  move-into-itself message and the class-name question (Copy / Move, Cancel / Yes / All, a subkey
  that differs, equal classes, a new target), in Czech and English, with the whole name of the key
  in each question compared exactly.
- `CHANGELOG.md`: an entry under 0.1.11 — unreleased.
- No new strings, no interface change, nothing stored.

## Measurements (before / after, commands)

Command (PowerShell tool, hidden desktop):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\287-regedt-move-class-name\probe\result_after_czech.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\287-regedt-move-class-name\probe\move287_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Lang czech -OutFile specs\287-regedt-move-class-name\probe\move287_after_czech.txt"
```

| Build | Czech | English |
|---|---|---|
| HEAD 243174e4 (first probe version, 7 rows) | PASS 13, FAIL 5 (no question; merged; CLASSMOVE deleted the source) | - |
| the one line put back (final probe, 11 rows) | PASS 19, FAIL 11 (every question row; the merges) | - |
| fixed | PASS 30, FAIL 0 | PASS 30, FAIL 0 |

Every run: registry restored identical (SHA-256), fixture removed, exit code 0, no stray window, no
crash report. Details: `fix-log.md` §4.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64): `BUILD SUCCEEDED` (`regedt.spl` rebuilt after the change).
- `saltests`: `25167 checks, 0 failed` (control; the core is unchanged).
- Probe 287: 30 / 0 Czech, 30 / 0 English; without the fix 19 / 11.
- Regression: probe of 129 (Czech) 19 / 0.

## Reviews (findings and what was done)

One independent refute-first review; no MUST. It repeated the negative control itself.
- S1 the changelog said "before anything is copied / Cancel copies nothing" - true only for the top
  key: reworded, nested rows added.
- S2 the probe checked only six letters of the name and the fix-log wrongly said the control gives
  no text: the probe now reads the control (`WM_GETTEXT`, reversed code-page conversion) and
  compares the whole name; fix-log corrected.
- S3 Move onto itself through `HKEY_USERS\<SID>` deletes the key (predates 287): Inbox item.
- N1 nested All / Yes: probe rows added. N2 a 260+ character class name now gets the existing read
  error (fails safe): accepted. N3 `CStaticText` gives garbled names to a wide `WM_GETTEXT`
  (screen readers): Inbox item. N4 locale comparison of class names: accepted.

## Owed to a person (with the new person-step items)

Nothing. Every row was driven on the hidden desktop (no keyboard, clipboard or server needed).

## New Inbox items (slug - title)

- `registry-editor-move-of-a-key-onto-itself-through-hkey-users` - Registry Editor: Move of a key onto itself through HKEY_USERS deletes the key
- `screen-readers-get-garbled-names-from-the-core-path-labels` - Screen readers get garbled names from the core path labels (CStaticText)
