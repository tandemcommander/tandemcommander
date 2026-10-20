# Quickstart - validating 264-remembered-drive-reconnect

## Prerequisites

- `build.cmd` (Debug x64) -> `BUILD SUCCEEDED`; the baseline copy of the HEAD0 tree in
  `%TEMP%\tc264base\tree` (made before the change).
- The local administrative share `\\localhost\C$` reachable for the current user (default
  on this machine; the 246 test used it).
- No running `tandemcommander.exe`.

## Unit rule

```powershell
& "build\tandemcommander\Debug_x64\saltests\saltests.exe"   # last line: saltests: <n> checks, 0 failed
```

## Probe (hidden desktop)

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\264-remembered-drive-reconnect\probe\run_after.log -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\264-remembered-drive-reconnect\probe\run264.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Baseline %TEMP%\tc264base\tree\tandemcommander.exe -OutFile specs\264-remembered-drive-reconnect\probe\result_after.txt"
```

Expected (`result_after.txt`):

| Row | Fixed build | Baseline |
|---|---|---|
| Q1 CJK + Cyrillic, unnamed | PASS: seam `RESTORE <L> <exact path>`, drive listed, panel on `<L>:\`, no message | FAIL (negative control) |
| Q2 Cyrillic, named | PASS (as Q1) | FAIL |
| L1 259 characters, Cyrillic tail | PASS (as Q1) | FAIL |
| A1 ASCII | PASS | PASS (control: nothing regressed, the fixture works) |
| U1 non-existent server | PASS: one message with Windows' real error (not "invalid"), drive not listed, panel unchanged | INFO |
| P1 panel started on `<L>:\` of a disconnected Q1-type drive | PASS: drive reconnected, panel on `<L>:\` | FAIL |
| END / REPORTS / cleanup | PASS, registry restored identical, mappings removed | |

## Owed to a person

On a machine with a password-protected share mapped as a remembered drive: pick the
disconnected drive -> Windows' credential dialog appears; Cancel -> no further message, the
drive stays disconnected; correct password -> connected. A slow / unreachable server ->
the wait window appears after ~3 s and Esc cancels it.
