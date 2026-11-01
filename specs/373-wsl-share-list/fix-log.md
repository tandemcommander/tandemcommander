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

## Callers (T001)

- `CUncSharesJob::Start` / `Read`: only `CFilesWindow::PickServerShare` (`src/fileswnb.cpp`),
  called from `CFilesWindow::ChangeDir` (`src/fileswn3.cpp`, the branch for a server-only UNC
  path without a Network plug-in). The way up of 284 (`..`, Backspace, Parent directory, Go to
  root, Open in other panel) hands `\server\` to that `ChangeDir`; 285 reads the list again
  after the sign-in through the same `Start`.
- `job->Error` is read only in `PickServerShare`: `SalUncShareListStep(Count, Error,
  IsLogonFailureErr(Error), ...)` and the error box (`GetErrorText(job->Error)`). 53 is not of
  the logon-failure class, so the sign-in of 285 is never offered for it (saltests check).
- `CUncSharesJob::FreeAbandoned` (193, `salamdr1.cpp`): unaffected.

## Implementation

- `src/common/saluncserver.h`: `SalUncServerNotFoundErr` (today's `notFound` set),
  `SalUncShareListAsksProviders` (53 with no share now asks the providers; 51 / 1231 / 1232
  still not), `SalUncProviderListError` (the rule of 125, moved).
- `src/shares.cpp` `CUncSharesJob::Read`: the three rules replace the inline test; the provider
  loop itself is unchanged. Route per case = `data-model.md` (only "53, no share" changes).
- `src/saltests/saltests.cpp`: `TestUncShareListProviders373`, 35 checks.
- clang-format: the changed ranges are clean (`clang-format --lines`).

## Probe fix (before the after-run)

The first `-Expect fixed` run of the negative control failed C1, N1, U1 although the program
behaved correctly: a Change Directory typed in the dialog that fails or is cancelled reopens the
dialog, which `Serve` records as a window. The verdicts now leave that entry out (it stays in the
facts). Rerun below.

## Measurement after / negative control

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\373-wsl-share-list\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\373-wsl-share-list\probe\wslshares_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect fixed"
```

| Row | negative (main build, `result_negative.txt`) | after (`result_after.txt`) |
|---|---|---|
| W1 `\wsl.localhost` | FAIL - (53) box | PASS - list after 12 ms, `\wsl.localhost\Ubuntu` |
| W2 `\wsl.localhost\` | PASS (1707 by chance) | PASS - list after 6 ms |
| W3 `\wsl$` | FAIL - (53) box | PASS - list after 7 ms, `\wsl$\Ubuntu` |
| W4 Backspace at `\wsl.localhost\Ubuntu` | FAIL - (53) box | PASS - list after 129 ms, Esc stays |
| C1 `\localhost` | PASS | PASS |
| N1 missing name | PASS - (53) after 1,335 ms | PASS - (53) after 1,346 ms |
| U1 `\192.0.2.1` | PASS - (53) after 21,113 ms | PASS - (53) after 21,020 ms |

Negative: PASS 11 / FAIL 3 (W1, W3, W4); after: PASS 14 / FAIL 0. Times to the error unchanged
(before 1,265-1,335 ms and 21,006-21,113 ms over three runs): no second timeout. Each run
restored the registry and verified it identical; the export hash differs between the runs of
13:39 (5550161...) and 13:43 (6AA0889...) - the key changed between them (saltests and the build
ran in between); each probe compares against its own backup.

## Checks

- `.\build.cmd` -> `BUILD SUCCEEDED` (Debug x64).
- saltests -> `saltests: 30155 checks, 0 failed` (+35).
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- No UI string, menu or dialog changed -> no `.slt` refresh; `build.cmd full` not needed.
