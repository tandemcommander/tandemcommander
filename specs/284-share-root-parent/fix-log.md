# Fix log - 284-share-root-parent

Backlog item `share-root-parent-offers-share-list`: `..` / Go to root in `\\server\share` does
nothing without the Network plug-in.

## Measurement before (main at e35f8588)

- Build: `build.cmd` (Debug x64, incremental, up to date).
- Code reading: see `research.md` R1 - the `..` entry of a share's root, `Execute` of `..`,
  `GotoRoot` and `OpenFocusedInOtherPanel` act only through a Network plug-in.
- Probe `probe/shareroot_probe.ps1 -Expect measure` on the hidden desktop (no `nethood.spl`,
  seam list `C$|D$|IPC$`): `probe/result_before.txt` -
  - B1 Backspace at `\\localhost\C$`: no list, no window, stays;
  - G1 Go to root: no list, stays;
  - D1 Home, Enter: opened `\\localhost\C$\$WINDOWS.~BT` (no `..` listed);
  - O1 Home, open in other panel: both panels at `\\localhost\C$\$WINDOWS.~BT`;
  - X1, E1: no list, no window (nothing to cancel, nothing refused);
  - S1 / S2 at `\\localhost\C$\Windows`: Backspace / Go to root -> `\\localhost\C$`;
  - L1 `C:\` Backspace: stays.
  - Registry restored, identical (SHA-256 A3805966...).
- Recorded in the item: `BL verify` at e35f8588.

## Decisions

- Reuse Change Directory's `\\server\` route (`ChangeDir(newDir)`) at every site - research R2.
- One pure rule `SalUncShareRootServerPath` (`saluncserver.h`) - research R3, contract.
- The plug-in test stays first at every site - research R4.
- Middle click on `..` (new tab) unchanged - spec clarification.

## Analyze

- Run 1: 0 CRITICAL, 0 HIGH; MEDIUM C1 (no probe row for "no folder share"), C3 (no check of the
  unchanged plug-in route); LOW C2 (the *Parent directory* command not driven), F1 (an unverified
  hotkey in the spec), U1 (vague negative control). All fixed: probe rows N1 and P1, T011 checks the
  plug-in branches in the diff, the hotkey removed, the negative control is `-Expect fixed` on the
  unchanged build.
- Run 2: no findings.

## Implementation

- `src/common/saluncserver.h`: `SalUncShareRootServerPath` (contract `contracts/share-root-rule.md`).
- `src/saltests/saltests.cpp`: `TestUncShareRoot284` - 40 checks (incl. exact fit / one byte
  short, a 300-byte server name refused in a `MAX_PATH` buffer).
- `src/fileswn3.cpp` `ReadDirectory`: `..` at a share's root when the plug-in test or the rule is TRUE.
- `src/fileswn2.cpp` `Execute` of `..`: `else` of the plug-in branch -> `ChangeDir("\\server\")`.
- `src/fileswn1.cpp` `GotoRoot`: after the plug-in branch, **disk panels only**,
  `ChangeDir("\\server\")`. First version had no `Is(ptDisk)`: at the root of an archive that lies
  in a share's root, `GetPath()` is the archive's folder, so *Go to root* would have offered the
  share list instead of leaving the archive to the share's root (FR-006) - fixed before building.
- `src/fileswn8.cpp` `OpenFocusedInOtherPanel`: `..` of a share's root -> the other panel gets
  `\\server\`.
- `src/shellsup.cpp` `GetCurrentDir` (found while enumerating the consumers of `..`): a drop on
  the `..` of a share's root computed the target `\\server\` (as it does with the plug-in) - now,
  without the plug-in, no target (stop cursor). Fail closed. Paste (`GetCurrentDirClipboard`)
  uses the panel's own path - not affected. Middle click (`OpenIndexInNewTab`): `CutDirectory`
  fails at a root -> nothing, unchanged. Selection / counts / sizes skip `..` by name as in every
  folder (`fileswn0/1/7.cpp`, `execute.cpp`).
- clang-format: only the comment alignment of the includes next to the new ones; the other
  differences clang-format reports in these files are older.

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `build.cmd` (Debug x64) | `BUILD SUCCEEDED` |
| unit rules | `saltests.exe` | `saltests: 25091 checks, 0 failed` (25051 before, +40) |
| negative control | probe `-Expect fixed` on the unchanged build (`probe/result_negative.txt`) | B1 P1 G1 D1 O1 X1 E1 N1 FAIL (8), S1 S2 L1 PASS - the probe tells the defect |
| probe | `-Expect fixed` (`probe/result_after.txt`) | PASS 22, FAIL 0 (11 ACT + 11 END); registry restored, identical |
| strings | `git diff main -- src/*.rc* src/lang translations` | empty - no new text |
| seam | `git diff main -- src` for `TC_PROBE` / `GetEnvironmentVariable` | none added (125's seam only) |
| plug-in route | reading the diff | every plug-in test still first, its branch unchanged; the new code runs only where it was FALSE |

Probe rows after: B1 Backspace, P1 *Parent directory* (822), G1 *Go to root* (823), D1 Home + Enter
(`..` is the first item) -> the share list, Down Down Enter -> `\\localhost\D$`, no window; O1 ->
the right panel `\\localhost\D$`, the left stays `\\localhost\C$`; X1 Esc -> stays, no window; E1
one box `Path: "\\localhost\" Error: (53) ...`; N1 one box `Path: "\\localhost\" Error: A share
name is missing in the path specified.`; S1, S2, L1 as before.

## Not driven (owed to a person)

- Drag and drop onto the `..` of a share's root shows the stop cursor (OLE drag needs the real
  mouse; not on the hidden desktop).
- The wait window's Esc / Close on a slow server reached through Backspace (the same code as
  Change Directory - 125 recorded it NOT DRIVEN too).
- A real file server (not `\\localhost`): Backspace in `\\server\share` offers its shares.
