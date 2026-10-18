# 246 — Network drive labels and disconnected-drive icons: fix log

Running log (newest at the bottom). Evidence lives in `analysis.md` and `probe/`.

## 2026-10-18 — start

- Source: a user's report (Czech, by e-mail/issue, relayed by the maintainer): a mapped
  SMB drive (Samba server) has a name in Windows ("Archiv") but Tandem Commander shows
  its UNC path (`\\SHARE_SAMBA\Share\Storage`); and the icon of such a drive does not
  change to the disconnected icon when the drive is disconnected. Same in Altap Salamander.
- Pre-analysis in the session (read-only):
  - drive menu text for `drvtRemote` is the UNC path by design
    (`src/drivelst.cpp:1816-1837`), tooltip copies it (`:2724`);
  - `DriveText + 2` is also the remote name handed to `RestoreNetworkConnection`
    (`:2455`) — the label must not replace it;
  - `drv.Accessible = (mask & i) != 0` (`:1753`): only a remembered connection absent from
    `GetLogicalDrives()` counts as disconnected; `GetDriveIcon` picks 31/33
    (`src/salamdr1.cpp:1053`);
  - the nethood plugin is unrelated (own `net:` FS item, no hook for A–Z items; off by default).
- Branch `246-network-drive-labels` created; three independent agents launched:
  static analysis of the text path, static analysis of accessibility/icon/refresh,
  empirical measurement of Windows behaviour (scratch only, cleanup required).

## 2026-10-18 — analysis results (three agents) → analysis.md

- Text path and accessibility/refresh confirmed by two independent static agents; the
  measurement agent found: Explorer's name = `MountPoints2\##…\_LabelFromReg`; every
  red-X state it could produce has the letter **absent** from `GetLogicalDrives`
  (icon 31 already in the menu); the server volume label is not used by Explorer.
- Root cause of the stale drive bar (G3.3): the bars compare only
  `GetLogicalDrives() | remembered`, which a remembered drive's state change does not alter.
- Defects in the same consumer: doubled `&` in reconnection, read past a 2-byte text,
  path cut by `DuplicateAmpersands`.

## 2026-10-18 — implementation

- `src/common/salnetdrive.h` (pure rules) + `TestNetDrive246` (+158 checks; saltests
  23,649 / 0 failed; baseline 23,491).
- `drivelst.cpp`: remote text from `WNetGetConnectionW` + `_LabelFromReg` (heap, never
  cut), `GetNetDisconnectedMask` (WNetGetConnectionW 1201 / WNetGetConnection3W
  disconnected — resolved at run time: exported by mpr.dll but absent from the 10.0.26100
  SDK headers), `CachedNetDisconnectedMask`, tooltip read at hover time, reconnection from
  `GetNetworkDrives` (never from the shown text), quiet enumeration option.
- `mainwnd3.cpp`: the bars compare the new mask; activation check (quiet).
- `toolbar6.cpp`: the second bar copies the mask.
- Debug-only probe seam `TC_PROBE_DRIVES_DUMP` (contracts/probe-seam.md).
- Build: one compile error (`CopyToolTipAnswer` needs `gui.h`), one (inline method on an
  incomplete type in `toolbar.h`) — fixed. `check_encoding.py` TOTAL 0.

## 2026-10-18 — GUI probe (`probe/run246.ps1`, hidden desktop)

- Fixed build: 37 rows, 0 FAIL (`probe/results-fixed.txt`): N1–N12 texts (unnamed,
  ASCII, Czech, Cyrillic, CJK, `&`, `#`, 300+ character text, tab, name = path, blank;
  both bars identical), T1 tooltip texts (via the seam), R1 rename while running (menu and
  tooltip, bar not rebuilt), S1–S5 state change → activation / no change / reconnect /
  Ctrl+R / menu open-close, P1–P2 reconnection from the bar (exact path, also with `&`),
  M1 no message box, exit 0, no report; cleanup verified; registry SHA-256 identical.
- T1 hover: NOT DRIVEN — the tooltip follows `GetCursorPos` / `WindowFromPoint` (real
  cursor); the seam calls the bar's tooltip function instead. Person step.
- Baseline (negative control, base commit 2875f8b2, `probe/results-baseline.txt`): the
  drive bar image does **not** change after the drive becomes unavailable + activation,
  nor after the Change Drive menu open/close (stale icon reproduced); the menu shows the
  path only for named drives (screenshot `shots/baseline_menu_names.png`).
- Probe trap found and fixed: the probe's own folder was `%TEMP%\tc246` and it is emptied
  at start — it deleted the first baseline copy; now `%TEMP%\tc246probe`, baseline in
  `%TEMP%\tc246base`.
