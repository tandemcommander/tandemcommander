# Fix log - 285-share-list-sign-in

Backlog item `share-list-offers-sign-in`: a server's share list that needs a password shows only
the Windows error. Autonomous run (`/tandem-backlog-implement`), HEAD0 `eb173f7f`.

## Measurement before (at eb173f7f, on main)

- Read: `CFilesWindow::ChangeDir` (fileswn3.cpp, `IDS_SHARENAMEMISSING` without a Network plug-in)
  -> `PickServerShare` (fileswnb.cpp) -> `CUncSharesJob::Read` (shares.cpp). A refused list
  (`Count == 0`, `Error` e.g. 5) -> `IDS_PATHERRORFORMAT` box, `PSS_ERRORSHOWN`; no sign-in.
  Since 284 Backspace / Go to root / `..` in a share's root take the same route.
- The full share path's sign-in: `CheckAndConnectUNCNetworkPath` -> `RestoreNetworkConnection(parent,
  NULL, root)` -> on Windows 7+ the ANSI `WNetAddConnection3(..., CONNECT_INTERACTIVE)` (research R1).
- `WNetAddConnection3W` without a dialog (PowerShell P/Invoke, current credentials): `\\localhost`,
  `\\localhost\IPC$`, `\\PC-DOMA`, `\\PC-DOMA\IPC$`, type ANY or DISK -> 5; `\\nosuchserver-tc` ->
  64; `WNetCancelConnection2W` afterwards -> 2250 (nothing was left connected).
- Built Debug at HEAD (`.\build.cmd`, exit 0). New probe `probe/signin_probe.ps1` (hidden desktop,
  seams of 125 + the planned sign-in seam, which HEAD does not have):

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\signin_probe.ps1 -Repo E:\Projects\tandemcommander -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe"
  ```

  `probe/result_before.txt`: A1, A2, C1, F1, W1, K1 - one box "Path: \\localhost\ Error: (5)
  Access denied", no list, sign-ins 0; N1 - box (53); R1 - list, `\\localhost\D$`. 8 END PASS,
  registry restored and identical. Defect confirmed (`BL verify`).

## Decisions

- Sign-in = Windows' dialog via `WNetAddConnection3W(CONNECT_INTERACTIVE)` to `\\server\IPC$`
  (RESOURCETYPE_ANY), wide; messages as `RestoreNetworkConnection` for an unmapped path; once per
  opening; no `CONNECT_UPDATE_PROFILE` (spec Clarifications, research R1-R3).
- `PRIVACY.md` not changed: every claim stays true (research R4); naming the sign-in there is left
  to the maintainer.
- The run was interrupted after the plan (the after_plan auto-commit returned exit 4 once; re-run,
  it committed `a4f1422b`). No probe was running; no registry backup was left.

## Implementation

- Analyze (2 passes): pass 1 - C1 MEDIUM (no task checked FR-010 "no new string"), C2 MEDIUM
  (constitution: CHANGELOG entry), C3 LOW (clang-format), C4 LOW (FR-006 plug-in route only by
  reading); all fixed in tasks.md (T007, T010, T013). Pass 2: 0 CRITICAL, 0 HIGH, coverage 100%.
- `src/common/saluncserver.h`: `SalUncShareListStep` (SHOW / NOTHING / SIGNIN / ERROR) and
  `SalUncSignInTarget` (`\\server\IPC$` through `SalUncBuildSharePath`: refused, never cut).
- `src/saltests/saltests.cpp`: `TestUncShareListSignIn285` (+31 checks).
- `src/drivelst.cpp`: `SignInToUncServerW` - `WNetAddConnection3W(parent, {RESOURCETYPE_ANY,
  target}, NULL, NULL, CONNECT_INTERACTIVE)`, results CONNECTED (also ALREADY_ASSIGNED /
  DEVICE_ALREADY_REMEMBERED) / CANCELLED / ERRORSHOWN; messages: 1219 -> `IDS_CREDENTIALCONFLICT`
  (body via `LoadStrU8`), extended error with provider text -> `ShowExtendedNetErrorW`, else
  `GetErrorText`; title `IDS_NETWORKERROR`. Debug seam inside `#ifdef _DEBUG`.
- `src/consts.h`: declarations (`IsLogonFailureErr` was only file-local by use, now declared).
- `src/fileswnb.cpp` `PickServerShare`: the 125 job + wait inside `while (TRUE)`; Esc primed each
  round; `SALUNC_LIST_SIGNIN` -> job released, sign-in, round 2 with `signInTried`; target not
  built -> the job's error shown (job kept for it). After the loop the 125 code by `step`.
- Formatting: clang-format (VS 2022 LLVM) on the changed lines only (`--lines`); the loop body
  re-indented, nothing else moved.
- `specs/125-unc-server-shares/contracts/probe-seam.md`: the three new variables listed.

## Checks after

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | `BUILD SUCCEEDED`, exit 0 (only the old warnings of salamdr2.cpp / zip.cpp) |
| unit rules | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 25122 checks, 0 failed` (25091 before, +31) |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| no new string | `git diff main --stat -- src/texts.rh2 src/lang/` | empty |
| probe | `run_on_hidden_desktop.ps1 ... signin_probe.ps1 -Expect fixed` -> `probe/result_after.txt` | PASS 16, FAIL 0 (A1, A2, C1, F1, W1, K1, N1, R1 ACT + END), registry restored + identical |
| Release seam | `.\build.cmd release` (`BUILD SUCCEEDED`); byte search of `Release_x64\tandemcommander.exe` (14:10) | `TC_PROBE_UNC_SIGNIN` / `TC_PROBE_UNC_ERROR` absent (UTF-16 and UTF-8); `IPC$` present - the seam is Debug-only, the route is in |
| negative control | probe copy with the expected target `\\localhost\IPC` (wrong), `-Only A1,R1` -> `probe/result_negative.txt` | A1 FAIL, R1 PASS, exit 1 - the target check bites |

Before -> after: A1 / A2 "(5) Access denied" box, 0 sign-ins -> 1 sign-in to `\\localhost\IPC$`,
list, `\\localhost\D$`, no box; C1 box -> no box, the dialog again; F1 -> one "Network Error (1326)";
W1 -> one "Multiple connections ..."; K1 -> one sign-in, then the "(5)" box (no second offer);
N1 / R1 unchanged, 0 sign-ins.

- US2 (T007) by reading: `fileswn1.cpp` GotoRoot, `fileswn2.cpp` Execute of `..`, `fileswn8.cpp`
  open in other panel, `shellsup.cpp` (drop target - refused, no change of path) - all hand
  `\\server\` to `ChangeDir`; `PickServerShare` has the single caller `fileswn3.cpp` (the
  `IDS_SHARENAMEMISSING` branch), where `Plugins.GetFirstNethoodPluginFSName` is tried first
  (`goto CHANGE_AGAIN_NO_DLG`) - with a Network plug-in the new code is never reached (FR-006).
- NOT DRIVEN (owed to a person): Windows' real credential dialog against a real file server that
  refuses the list - sign in, Cancel / Esc in the dialog, a wrong password, *Remember my
  credentials*.

## Review

### Review 1 (independent agent, refute-first)

No MUST. Re-ran saltests (25122 / 0), the encoding guard (0), the probe (16 PASS), the Release
string search (absent); own probe variant with a CJK server `\\中文tc\` (cancel: target logged
exactly `\\中文tc\IPC$`), a non-class error 64 (no sign-in, one "(64)" box) and a negative control
(error 64 expected to sign in -> FAIL, as it should). Callers enumerated: `PickServerShare` has one
caller; job references balanced on every exit; target buffer always fits.

- **SHOULD 1** - without `CONNECT_PROMPT` Windows first tries the current identity; `IPC$` is not
  what refused (the list is), so a silent success would give no dialog, the same "(5)" again and a
  session connection left behind. **Fixed**: `CONNECT_INTERACTIVE | CONNECT_PROMPT`
  (`drivelst.cpp`, comment there; consts.h, plan, research R1, contract updated). The real dialog
  stays a person's row (the silent-success case can only be seen on a real server).
- **SHOULD 2** - `PRIVACY.md` not changed in the same change. Maintainer-owned (stop-rules §1
  public claims) and every claim stays true (research R4) -> decision item for the maintainer.
- NOTE - the person rows of 285 are not in the backlog -> a new `person-step` item at closing
  (the existing `real-file-server-person-rows` is another item; not edited).
- NOTE - the sign-in blocks the UI thread without the Esc wait window, like the full share path's
  sign-in; accepted (it is Windows' modal dialog).
- NOTE - a sign-in failing outside the logon class shows the Windows error under "Network Error"
  without the server's name, as the full share path does; accepted (FR-004 "the same messages").
- NOTE - probe covered only error 5 and ASCII names -> **added** rows L1 (list refused 1326,
  sign-in, list) and U1 (CJK server, cancel, the exact target logged).
- NOTE - `LoadStrU8` vs `LoadStr` for the conflict text; kept `LoadStrU8` (the UTF-8 sink rule).

After the fixes: `.\build.cmd` `BUILD SUCCEEDED` (exe 14:25 after the source 14:24); saltests
25122 / 0 failed; encoding guard 0; probe `probe/result_after.txt` **PASS 20, FAIL 0** (A1, A2, C1,
F1, W1, K1, N1, R1, L1, U1 ACT + END), registry restored + identical. No MUST -> no second review
needed (SKILL.md step 7).
