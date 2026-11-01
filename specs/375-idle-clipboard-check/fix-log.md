# Fix log - 375-idle-clipboard-check

Backlog item `every-activation-of-the-program-blocks-it-150-ms-in-the-idle`. Run started at
`main` `e1b1e2c9` (2026-11-01).

## Measurements before the change (HEAD `e1b1e2c9`, Debug x64)

### Feature 372's probe, row LOCAL, unchanged

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <tmp>\local_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\372-wsl-activation-freeze\probe\act372_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before375 -Only LOCAL"
```

PASS, longest 3.1 ms, **no wait > 16 ms** on any of 5 activations. The 140 ms block that 372
recorded on the same row (15+140..142 ms, `specs/372-.../probe/result_after2.txt`) did not occur.
No code on the path changed since (`git log 50c47081..HEAD -- src/mainwnd1.cpp src/mainwnd3.cpp
src/fileswn9.cpp src/salamdr1.cpp`: nothing). So the block depends on the machine's state.

### Clipboard primitives (`probe/clip_primitives.ps1`, read-only)

OpenClipboard / GetClipboardData(CF_TEXT) / CloseClipboard, the `IsTextOnClipboard` loop as
written, `IsClipboardFormatAvailable`, `OleGetClipboard` + `EnumFormatEtc`; the clipboard held
text owned by Chrome:

- user's desktop and hidden desktop (`probe/primitives_free_hidden.txt`): every query <= 1.1 ms
  (first call), then <= 0.1 ms. The hidden desktop is **not** slower (the item's note).
- another process holding the clipboard open (`probe/clip_hold.ps1`: `OpenClipboard` with a hidden
  form window, content unchanged) (`probe/primitives_held.txt`): `OpenClipboard` fails with
  error 5 (ERROR_ACCESS_DENIED) at once; `OleGetClipboard` fails at once with `0x800401D0`
  (CLIPBRD_E_CANT_OPEN, 0.6 ms); the `IsTextOnClipboard` loop (10 x `Sleep(10)`, each ~15.5 ms at
  the default timer resolution) **155-165 ms** - the 153.9 / 154.2 ms of 372's instrumentation.
  (A holder that opens with a NULL window did not block other openers on this Windows build - the
  helper uses a window.)

### New probe `probe/act375_probe.ps1` (`probe/result_before.txt`)

Row LOCAL of act372 (800-file local folder, WM_ACTIVATEAPP FALSE/TRUE, WM_NULL pings every 2 ms),
twice: FREE (clipboard as it is) and HELD (the helper holds the clipboard open for the row).

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <...>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <...>\act375_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <...>\fix_probe_lib.ps1"
```

| Row | Waits per activation | Longest | Verdict (< 30 ms) |
|---|---|---|---|
| FREE | none > 16 ms | 0.4-2.3 ms | PASS |
| HELD | 15+142, 15+142, 15+142, 15+140, 15+141 | 142 ms | FAIL |

Registry restored, identical SHA-256. HELD reproduces 372's signature exactly: the block happens
whenever another program keeps the clipboard open at the activation (at 372's time some program
did so on this machine for hours). Probe trap met: a local `$holder` variable in a function
shadowed the script parameter `$Holder` (PowerShell names are case-insensitive) - the parameter is
now `$HoldScript`.

### Where the wait is

`CMainWindow_RefreshCommandStates` (`src/mainwnd1.cpp`), block `if (IdleCheckClipboard)`:
`ClipboardPaste(FALSE, TRUE)` (OleGetClipboard - fails fast), `IsTextOnClipboard()` (the retry
loop - **the wait**), `ClipboardPasteLinks(TRUE)` (= ClipboardPaste, fast), 
`ClipboardPasteToArcOrFS(TRUE, ...)` (OleGetClipboard - fast). Result when busy today: every value
FALSE after the 150 ms (ClipboardPaste also clears the panels' cut-to-clipboard marks because no
files were seen - existing behaviour, unchanged, out of scope).

Consumers (stop-rules §2.2): `IsTextOnClipboard` is called by `CMainWindow_RefreshCommandStates`
(idle, the activation path) and by `CFilesWindow::RestoreGlobalSelection` (`fileswn1.cpp`, the
user's *Restore Selection* command opening a dialog) - the latter keeps its retry.
`IdleCheckClipboard = TRUE` is set by 19 sites (activation, dialogs closing, paste operations,
...); no clipboard change listener exists (`grep WM_CLIPBOARDUPDATE|WM_DRAWCLIPBOARD`: none).
`WM_USER_ENTERMENULOOP` calls `OnEnterIdle` so menus show fresh enablers.
