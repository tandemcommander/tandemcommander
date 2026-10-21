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
