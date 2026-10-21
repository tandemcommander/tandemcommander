# Research - feature 284

## R1 Where the four ways up go today (measured at e35f8588)

- Listing: `CFilesWindow::ReadDirectory` (`fileswn3.cpp`) computes `upDir` for a UNC path as
  "something after the share"; at a share's root it is TRUE only when
  `Plugins.GetFirstNethoodPluginFSName()` (then `UNCRootUpDir = TRUE`: the `..` entry is made
  without a `FindFirstFile`, with the fixed 1602 date).
- Backspace / Ctrl+PgUp / `CM_ACTIVEPARENTDIR` / `CM_LPARENTDIR` / `CM_RPARENTDIR` ->
  `CtrlPageUpOrBackspace` (`fileswn0.cpp`) -> `Execute(0)` only when `Dirs->At(0)` is `..`.
  Enter / double click on `..` -> `Execute` the same way.
- `Execute` of `..` (`fileswn2.cpp`): `CutDirectory` fails at a share's root; then only the plug-in
  route (`EnsureShareExistsOnServer` + `ChangePathToPluginFS(net:, \\server, focus share)`).
- `GotoRoot` (`fileswn1.cpp`; `CM_ACTIVEROOTDIR` / `CM_LROOTDIR` / `CM_RROOTDIR`, keyboard and the
  directory-line edit): `IsUNCRootPath && plug-in` -> plug-in root; else `ChangePathToDisk(root)` -
  the same share's root again.
- `OpenFocusedInOtherPanel` (`fileswn8.cpp`, `CM_OPEN_IN_OTHER_PANEL[_ACT]`): `..` on a UNC root
  with the plug-in -> `net:\\server`; without it `\\server\share\..`, reachable only once `..` is
  listed.
- `OpenIndexInNewTab` (`paneltabs.cpp`, middle click): `..` at a root does nothing - stays (spec).
- Probe `shareroot_probe.ps1 -Expect measure`: rows B1, G1, X1, E1 "nothing happens"; D1 and O1 open
  the first folder (no `..`); S1, S2, L1 as expected (`result_before.txt`).

## R2 Reuse Change Directory's route rather than calling PickServerShare at each site

- Decision: each site hands `\\server\` to `ChangeDir(newDir)` (the panel's own; the other panel's
  for *Open in other panel*).
- Rationale: `ChangeDir` already does, for `\\server\`: normalisation, `SalGetFullName` ->
  `IDS_SHARENAMEMISSING` + `callNethood`, the plug-in check, `PickServerShare`, the wait window,
  the error message naming the path, the "share name is missing" message when no folder share is
  offered, the never-cut refusal, and the change to the picked share (feature 125, probed). One
  route = the behaviour "exactly as Change Directory" (FR-002) by construction; no new string.
- With `newDir != NULL` every failure returns FALSE without reopening the dialog; Esc in the list
  (`PSS_CANCELLED`) returns FALSE silently - the panel stays.
- Alternatives: calling `PickServerShare` + `ChangePathToDisk` at each site - four copies of the
  result handling (rejected: duplication, risk of diverging messages).

## R3 The rule: "a share's root, and its server path"

- Decision: `SalUncShareRootServerPath(path, buf, size)`: TRUE for `\\server\share` and
  `\\server\share\` (backslashes only, as panel paths are), server not empty and not the device
  prefixes `.` / `?`, share not empty, nothing after the share; writes `\\server\` - refused (FALSE,
  empty buffer) when it does not fit, never cut.
- Why not `IsUNCRootPath`: it is TRUE also for `\\server` (no share) and does not give the server.
- The sites use a `MAX_PATH` buffer: `PickServerShare` takes a server name below `MAX_PATH` bytes
  anyway; a longer one (a long internationalised DNS name) is refused - no `..`, nothing new, as
  before (spec edge case).

## R4 The plug-in stays first

Every site keeps its plug-in test in front; the new branch runs only where the plug-in test was
FALSE (FR-005). The plug-in is not built by default (`nethood=off`); with it, the route is the old
code, verified by reading (125 measured the plug-in's own leak at exit - not repeated).

## R5 Consumers of a `..` entry at a share's root

The entry already exists there with the plug-in (since the predecessor), so the panel code handles
it: `UNCRootUpDir` skips `FindFirstFile`; `CtrlPageUpOrBackspace`, `Execute`,
`OpenFocusedInOtherPanel`, `OpenIndexInNewTab` are the consumers that act on `..` by name and are
covered above. Selection, copy, drag and drop skip `..` as in every folder. The refresh at a change
of the plug-in set (`plugins1.cpp`) re-reads UNC roots - harmless now that the entry is there
either way.
