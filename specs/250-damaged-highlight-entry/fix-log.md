# Fix log - 250-damaged-highlight-entry

Backlog item `a-damaged-highlighting-entry-hangs-the-program-at-start-up` - A damaged highlighting
entry hangs the program at start-up. Autonomous run (`/tandem-backlog-implement`), HEAD0 `36d1b3d9`.

## Measurement at HEAD (before any change)

Site: `src/mainwnd2.cpp`, `CMainWindow::LoadConfig`, the block "load colors for file highlighting":
`while (OpenKey(hHltKey, buf, hSubKey))`. `itoa(++i, buf, 10)` and `CloseKey(hSubKey)` sit only at the
end of the `if (GetValue(hSubKey, SALAMANDER_HLT_ITEM_MASKS, REG_SZ, masks, MAX_PATH))` branch; the
low-memory path after `item->Set(masks)` does `continue` - also without advancing or closing.

`GetValue` (`src/regwork.cpp`, `GetValueAux`) returns FALSE for: a missing value (silent), a value of
another type ("Unexpected value type." box, `IDS_UNEXPECTEDVALUETYPE`), any other read error such as
`ERROR_MORE_DATA` for a value over `MAX_PATH` bytes (the system error text in a box). Each of these makes
the loop re-open the same key forever; with a box, the box comes again after every OK.

Reachability: `LoadConfig` runs at every start with an existing configuration. The configuration dialog
(Colors page, `CEditListBox`) limits a mask to `MAX_PATH` (`EM_SETLIMITTEXT MAX_PATH`), and the save
(`SaveConfig`) always writes `Masks`, so a damaged entry comes only from outside: a registry edit, a
`.reg`, an import.

Other `while (OpenKey(...))` loops of the core (`find.cpp` x2, `fileswna.cpp`, `plugins2.cpp` x3,
`salamdr2.cpp` viewers/editors, `mainwnd2.cpp` packers/unpackers/associations/user menu) advance on every
round or `break` - only this loop hangs. (The user-menu loop's `break` paths leave one key open once - a
single handle, not a hang; not recorded as an item.)

### Probe `probe/hlt250_probe.ps1` (new), run on the hidden desktop

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\250-damaged-highlight-entry\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\250-damaged-highlight-entry\probe\hlt250_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

Build: `.\build.cmd` at `36d1b3d9` - BUILD SUCCEEDED. First run counted the splash window (a
button-less `#32770`) as a box and failed CONTROL; the probe now counts only windows with an OK/Cancel
button. Second run (`probe/result_before.txt`): PASS 3, FAIL 5.

| Row | Before |
|---|---|
| CONTROL (a, b, c) | PASS - main window after 3.5 s, no box; END clean; saved a,b,c |
| NOMASKS (entry 1 no Masks) | FAIL - no main window after 30 s, CPU 30.2 s |
| MIDDLE (entry 2 of 3 no Masks) | FAIL - no main window after 30 s, CPU 30.1 s |
| EMPTYKEY | FAIL - no main window after 30 s, CPU 30.2 s |
| WRONGTYPE (Masks REG_DWORD) | FAIL - 10 boxes "Unexpected value type." in 3 s, no main window |
| LONG (Masks 400 bytes) | FAIL - 10 boxes "(234) More data is available" in 3 s, no main window |

Registry restored, identical (SHA-256 98A53651...).

## Decisions

- Skip the damaged entry (not end the list) - the item allows both; skipping keeps the following
  entries (conservative).
- The read buffer stays `MAX_PATH`; an over-long masks value is reported once by the existing message
  and skipped (the dialog cannot produce one).
- No pure rule worth a `src/common/` header: the change is the loop's control flow around registry
  calls; the probe drives it end to end.
