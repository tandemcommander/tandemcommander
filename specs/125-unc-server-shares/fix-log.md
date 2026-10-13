# Fix log: feature 125 - from a server name to its shared folders (GitHub issue #5)

Branch `125-unc-server-shares` from `124-regedt-key-text`. Session 2026-10-13, the maintainer away.

## 1. Measure first

Probe `probe/unc_probe.ps1 -Expect measure` (hidden desktop, English UI).

| Typed | 0.1.9 (`probe/unc_measure_v019.txt`) | the same sources with `nethood=on` (`probe/unc_measure_with_nethood_plugin.txt`) |
|---|---|---|
| `\\localhost\`, `\\localhost`, `\\PC-DOMA\` | box "A share name is missing in the path specified." | `net:\\localhost` |
| `\\` | box "A server name is missing..." | `net:\`, "Scanning network..." |
| `\\tc125-no-such-host\` | the same "share name is missing" box, at once | `net:\\tc125-no-such-host`, empty, no message |
| exit afterwards | clean | Debug heap box "Detected memory leaks!" at **every** exit |

The report is confirmed; its cause is as described.

## 2. The decision about the proposed remedy

`nethood=on` makes the reported case work, and the plug-in builds unchanged (21 plug-ins). It is
not taken here - research R2 has the measured and audited reasons (forced thread termination at
exit = the leak box, a wider behaviour change than the report, encoding and buffer residue, the
predecessor's name in its texts, public claims to update). Which plug-ins ship is the
maintainer's policy (feature 007). The item with its price is in `specs/NEXT-WORK.md`.

## 3. The change (core only)

| File | Change |
|---|---|
| `src/common/saluncserver.h` (new) | pure rules: `SalUncServerOfPath`, `SalUncShareOffered`, `SalUncShareHidden`, `SalUncShareCompare`, `SalUncBuildSharePath`, `SalUncMenuText` |
| `src/salamand.h`, `src/shares.cpp` | `CUncSharesJob`: reference-counted job on a worker thread - `NetShareEnum` level 1, `WNetOpenEnumW` fallback; Debug-only seam (`contracts/probe-seam.md`) |
| `src/fileswnd.h`, `src/fileswnb.cpp` | `CFilesWindow::PickServerShare`: 400 ms quiet, then the safe wait window (existing text), menu under the directory line, `PSS_xxx` |
| `src/fileswn3.cpp` | `ChangeDir`: the fallback in the incomplete-UNC branch, only when no Network plug-in is found |
| `src/saltests/saltests.cpp` | `TestUncServer125` |
| `PRIVACY.md` | the bullet *Network drives and shared folders* says what the program now asks a named server |

No new string, no plug-in interface change, no new project file.

## 4. Traps met

- `small` is a macro of the Windows headers (`rpcndr.h`: `#define small char`) - a local named
  `small` gives "char followed by char is illegal".
- Bash here-documents collapsed `'\\'` to `'\'` in generated C++ again (CLAUDE.md warns: write
  scripts with the editor tools). All later edits went through script files.
- The popup menu is owner-drawn and the text recognition reads short names with `$` badly
  (`C$` -> `cs`). The list is therefore checked **exactly** another way: the k-th item is chosen
  with the keyboard and the path the program then tries is read from the Change Directory
  field it reopens (row L2).
- The wait window's Esc / Close use `GetAsyncKeyState` and `GetMessagePos` - not drivable on the
  hidden desktop (row W1 ESC is NOT DRIVEN, owed to a person).

## 5. Independent review (read-only, refute-first)

No blocker; four should-fix items, all applied:

| Finding | Fix |
|---|---|
| a stale Esc (the one that closed the menu or a dialog) cancels the next wait at its first poll - `UserWantsToCancelSafeWaitWindow` reads `GetAsyncKeyState`'s "pressed since the last call" bit | `GetAsyncKeyState(VK_ESCAPE)` once before the job starts, as `SalCheckPath` does |
| the worker had a `CCallStack` but no exception wrapper | `UncSharesThreadF` -> `FEH` -> `FBody`, the shape of the core's other threads |
| the thread handle was closed at once; the claim "an abandoned worker holds no lock" was wrong (its call-stack object takes the global section when the thread ends) | `HANDLES(CreateThread)` + `AddAuxThread(thread, TRUE)`; research R5 corrected |
| `PRIVACY.md` said "nothing about it is stored" - the typed path goes to the Change Directory history and the opened folder to the path history | the sentence says so |

Also applied: a server that was not found (errors 53, 51, 1231, 1232) is not asked a second time
through the fallback (another timeout); a test check that could not fail (`|| TRUE`) removed.

Recorded, not changed: when `NetShareEnum` fails after a first `ERROR_MORE_DATA` round the part
already read is shown without a hint; `CreateSafeWaitWindow` nested in an outer wait window of
the same thread would end the outer one (the same property as `SalCheckPath`); callers other
than the Change Directory dialog (command line, hot paths, the directory line, a pasted path)
now get the list where they got the error box - all user-initiated, on the main thread; the
device rule of `SalUncServerOfPath` (`\\.`, `\\?`) cannot be reached from `ChangeDir`
(`SalGetFullName` refuses those first).

## 6. Tests

| What | Result |
|---|---|
| saltests | 18,277 checks, 0 failed (18,184 before; `TestUncServer125` = 93) |
| `tools/check_encoding.py` | `TOTAL: 0` |
| Debug build, Release build (`build.cmd release`) | clean |
| Release binary: `TC_PROBE_UNC` (ASCII and UTF-16) | 0 occurrences (Debug: 3) |
| probe, fixed build (`probe/unc_result.txt`) | **PASS 26, FAIL 0, NOT DRIVEN 1, INFO 3** |
| probe, 0.1.9 (`probe/unc_measure_v019.txt`) | the error boxes of the report |
| probe, this code built with `nethood=on` (`probe/unc_result_fixed_code_with_nethood_plugin.txt`) | `\\localhost\` and `\\localhost` open `net:\\localhost` - the plug-in keeps priority (and the leak box at exit is there again) |

Rows of the fixed run: L1 (the list, Esc returns to the dialog), L2 (content and order, item by
item: `apps, DATA, Home, NETLOGON, R&D, Sdílené | ADMIN$, archiv$, C$`; printer and `IPC$`
absent; one more Down wraps to the first), P1 (seam list on `\\localhost\`, pick -> `\\localhost\C$`),
R1 (**no seam**: the real share list of this computer, pick -> `\\localhost\C$`), E1 (seam error
53), E2 (a real host that does not exist: box with `(53)` after 6 s), N1 (only a printer and
IPC: "A share name is missing"), S4 (`\\`: "A server name is missing"), W1 (seam delay 6 s:
wait window at 1.0 s with the path, the list at 6.6 s), A1 (`-l \\localhost\` on the command
line with a 3 s delay: the list comes during start-up, pick works), C1 / C2 (WM_CLOSE to the
main window with the list open / while reading: the list closes, the dialog returns, the
program answers and later exits with 0), U1 (Backspace at `\\localhost\C$`: stays, no window -
unchanged). Every row ends with exit code 0, no stray window, no report - also no Debug leak
box, unlike the plug-in.

Not driven: Esc / Close of the wait window (real keyboard and mouse) - owed to a person; a
server with visible shares on a real network; a server that refuses the list (the
`WNetOpenEnumW` fallback ran only by code reading and review).
