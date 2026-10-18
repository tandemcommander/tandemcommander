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

## 2026-10-18 — review round 1 (independent refute-first agent, code only)

No critical defect; memory paths, mask consistency, encoding and callers checked correct.
Findings and what was done:

1. **Major — tooltip fallback overflow**: the stored text of a network drive is no longer
   capped at ~MAX_PATH; the fallback `strcpy(text, DriveText + 2)` into the 5000-byte
   tooltip buffer could overflow when the name is huge (policy / registry) and the live
   query fails at hover time (drive deleted before the bar rebuilt). → bounded copy
   (`DupStr` + `RemoveAmpersands` + `CopyToolTipAnswer`, whole characters).
2. **Minor — message box still reachable on activation**: the quiet check's rebuild ran a
   non-quiet `BuildData` → `GetNetworkDrives(showErrors)`. → `quiet` passed through
   `RebuildDrives` → `CreateDriveButtons` → `BuildData`.
3. **Minor — FR-009 overstated**: reconnection now takes the remembered path from Windows,
   but that path is still the code-page, `MAX_PATH`-cut form of 0.1.10 (A enumeration,
   A `RestoreNetworkConnection`) — not a regression. → FR-009 and the code comment
   corrected; the chain stays with backlog `drive-list-code-page-texts` (note added).
4. **Minor — SC-002 literally false** for non-ASCII / long unnamed remembered paths (now
   exact instead of `?` / cut). → SC-002 reworded as an intended difference.
- Risks taken: `stackBuf[0] = 0` before `WNetGetConnectionW`; the Debug seam's tooltip
  calls gated on the variable; third-party network providers answering
  `WNetGetConnectionW` slowly on activation — not measurable here (person step / limitation);
  the `#` key collision is Explorer's own scheme; bidi controls in names are cosmetic.
- saltests: the state truth-table loop was tautological → replaced by hand-counted totals
  (90 / 55 / 10) and the unlisted rule; duplicate row removed; deeper trailing-backslash key
  case added.

## 2026-10-18 — independent black-box test, round 1 (`test-independent/`)

65 PASS on 23248aa9; findings:
- **T-E9**: a 2,000-character CJK name (policy/registry) cut the tooltip at the 5000-byte
  buffer and lost the path. → the tooltip shortens only the NAME (whole character +
  U+2026); the menu keeps the whole text.
- **PK-Q1/Q2**: a remembered drive whose path has characters outside the code page does not
  reconnect (`RESTORE Z ...\unnamed_???_?????`); baseline identical → out of scope, backlog
  `remembered-network-drive-with-a-non-code-page-or-long-path` (Inbox).
- REG_EXPAND_SZ: Explorer shows the name expanded → now expanded.
- Correction to the analysis: the baseline shows `?` for non-code-page paths also for a
  *connected* drive, not only a remembered one.
- Performance (7 network drives, 12 samples, baseline/fixed alternating): menu opening
  9.2 → 12.4 ms median (+3.2, SC-004 limit +50); activation work 166.3 → 163.8 ms (no cost).

## 2026-10-18 — review round 2 and test round 2

- Review round 2: the five round-1 fixes verified correct; one cosmetic edge (a name equal to
  a > 4999-byte path would get a stray ellipsis) → the shortening moved into the header
  (`SalNetDriveNameShown`, `SalNetDriveU8Len`, `SalNetDriveNameUnitsForLimit`) with saltests
  (property loop over every limit). Risks recorded: a bar rebuilt by the activation check in
  a nested message loop of a reconnection (not reachable today: no message loop after a
  successful connection); a listed letter whose `GetDriveType` is NO_ROOT_DIR stays "fixed"
  (pre-existing, consistent).
- Test round 2 (82b32159): 0 FAIL — 80 PASS, 1 NOT DRIVEN (hover); C9 tooltip boundaries
  (exact fit / one over, ASCII, emoji, `&`, CJK at every byte offset, mixed) all PASS;
  menu +2.6 ms; cleanup verified.
- saltests 24,297 / 0 failed; probe 0 FAIL on 7880090a.

## 2026-10-18 — test round 3 and builds

- Independent test round 3 on 7880090a (tooltip limits incl. name = path, expansion, 19 menu texts): 62/62 PASS, cleanup verified.
- `build.cmd full` (Debug, language modules): BUILD SUCCEEDED (no UI string changed).
- `build.cmd release`: BUILD SUCCEEDED; the Release exe contains no `TC_PROBE_DRIVES_DUMP` (seam is Debug-only) and does contain the feature (`_LabelFromReg`).
