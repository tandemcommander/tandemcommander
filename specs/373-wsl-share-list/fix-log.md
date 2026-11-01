# Fix log - 373-wsl-share-list

Backlog item `wsl-localhost-offers-no-share-list`: Server path of WSL (wsl.localhost) offers no
share list: error 53 skips the provider fallback.

## Measurement before (main at 5b62b037)

### The calls (PowerShell P/Invoke, the core's parameters)

Script `%TEMP%\tc-wslshares\wsl_measure.ps1` (not kept; its results are `research.md` R1).

- `\\wsl.localhost`, `\\wsl$`: `NetShareEnum` 53 in 1-17 ms; `WNetOpenEnumW` lists
  `docker-desktop`, `Ubuntu` (Plan 9 Network Provider) in 1-7 ms.
- Missing servers (`\\192.168.0.50`, `\\192.168.0.51`, `\\10.255.255.1`, `\\192.168.1.1`,
  two names that do not exist): `NetShareEnum` 53 after 1.3-21 s; `WNetOpenEnumW` asked right
  after it: 1203 in 0-6 ms. Asked first (cold): 1203 after 21,058 ms / 21,057 ms / 2,693 ms -
  the providers' question costs the full timeout when it is the first question, nothing when it
  is the second.
- `\\localhost`: `NetShareEnum` 0, 7 shares (SMB route works).

### The program (hidden-desktop probe, Debug x64 at 5b62b037, real route, no seam)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tc-wslshares\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File %TEMP%\tc-wslshares\wslshares_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Repo E:\Projects\tandemcommander"
```

(the probe was written before the branch existed; the copy in `probe/` differs only in two
names: `WslNet384` -> `WslNet373`, `nosuch-tc384-` -> `nosuch-tc373-`). Result
`probe/result_before.txt`:

| Row | What | Before |
|---|---|---|
| W1 | Change Directory `\\wsl.localhost` | box "(53) network path not found", no list |
| W2 | `\\wsl.localhost\` | list opened, Ubuntu opened - by chance: a repeated `NetShareEnum` answered 1707, which already goes to the providers |
| W3 | `\\wsl$` | box (53) |
| W4 | Backspace at `\\wsl.localhost\Ubuntu` (284) | box (53) for `\\wsl.localhost\` |
| C1 | `\\localhost` | list (control) |
| N1 | `\\nosuch-tc384-c4e17024` | box (53) after 1,324 ms |
| U1 | `\\192.0.2.1` | box (53) after 21,036 ms |

Registry restored, identical (SHA-256 5550161...60F0). The defect is reachable from Change
Directory and from the way up of 284 in the default configuration (no Network plug-in ships).

## Decisions

- Providers asked after 53 with no share, always second (research R1); 51 / 1231 / 1232 keep
  today's route (R2, conservative); both fail -> the first error 53 (R3).
- `PRIVACY.md` unchanged: the claim "asks that server, through Windows, for the list of its
  shared folders" (section *Network drives and shared folders*) stays true.
- No new UI string -> no `.slt` refresh.
