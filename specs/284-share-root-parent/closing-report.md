# Closing report - 284-share-root-parent
Backlog item: share-root-parent-offers-share-list - `..` / Go to root in \\server\share does nothing without the Network plug-in
Outcome: closed

## What changed

- The root of `\\server\share` lists `..` also without a Network plug-in (`ReadDirectory`,
  `src/fileswn3.cpp`).
- Executing that `..` (Enter, double click, Backspace, Ctrl+PgUp, *Parent directory*), *Go to root*
  in a share's root (disk panels) and *Open in other panel* on that `..` hand `\\server\` to the
  panel's `ChangeDir`, which since feature 125 offers the server's shares (`src/fileswn2.cpp`,
  `src/fileswn1.cpp`, `src/fileswn8.cpp`).
- Dropping onto that `..` is refused (stop cursor) instead of aiming at `\\server\`
  (`GetCurrentDir`, `src/shellsup.cpp`).
- Pure rule `SalUncShareRootServerPath` in `src/common/saluncserver.h` (refuses, never cuts),
  40 saltests checks (`TestUncShareRoot284`).
- With a Network plug-in every route is the old code (its test stays first). No new string, no
  stored data, no new kind of network communication.

## Measurements (before / after, commands)

- Before (main e35f8588): `shareroot_probe.ps1 -Expect measure` -> Backspace, *Go to root*, Esc,
  error rows: nothing happens at `\\localhost\C$`; Home + Enter opens `$WINDOWS.~BT` (no `..`)
  (`probe/result_before.txt`). Negative control `-Expect fixed` on the unchanged build: 8 FAIL
  (B1 P1 G1 D1 O1 X1 E1 N1), 14 PASS (`probe/result_negative.txt`).
- After: `-Expect fixed` -> PASS 22, FAIL 0 (`probe/result_after.txt`): every way up opens the share
  list, the pick opens `\\localhost\D$`, the left panel stays at `C$` for *Open in other panel*, Esc
  stays, error 53 and "no folder share" show one message naming `\\localhost\`, the controls
  (`\\localhost\C$\Windows` Backspace / Go to root, `C:\` Backspace) unchanged. Registry restored,
  identical (SHA-256 A3805966...).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`
- `build.cmd` (Debug x64): `BUILD SUCCEEDED`
- `saltests.exe`: `25091 checks, 0 failed` (25051 before, +40)
- Probe: 22 PASS / 0 FAIL / 0 NOT DRIVEN (before: 14 / 8)
- `build.cmd full` not needed: no string, resource, language or plug-in list changed.

## Reviews (findings and what was done)

One refute-first review: no MUST, no SHOULD; six NOTEs accepted (fix-log *Review*): holding
Backspace ends at the share list; *Go to root* at a share's root asks the server; archive and
plug-in cases by reading; middle click on `..` unchanged; 125's "share name is missing" text;
bookkeeping written at closing.

## Owed to a person (with the new person-step items)

- `share-root-up-284-person-rows` - drop onto the `..` of a share's root (stop cursor), Backspace in
  a real file server's share, Esc in the wait window of a slow server.

## New Inbox items (slug - title)

- share-root-up-284-person-rows - Share root way up (284) by hand: drop onto .., a real server, Esc in the wait
