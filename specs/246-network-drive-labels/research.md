# 246 — Research (Phase 0)

Base: [analysis.md](analysis.md) (three independent agents, live measurement on
Windows 11 26300 in `probe/measure/`). No open "NEEDS CLARIFICATION" remained after the
spec's clarification session.

## R1. Source of the drive's name

- **Decision**: read `_LabelFromReg` (REG_SZ; REG_EXPAND_SZ taken literally) from
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\<key>`, key =
  `##` + the UNC path without its leading `\\`, every `\` replaced by `#`, trailing
  backslashes removed. Wide registry API (`RegOpenKeyExW` / `RegQueryValueExW`).
- **Rationale**: measured — an Explorer rename writes exactly this value; Explorer finds
  it case-insensitively for any letter the path is mapped to, also while the connection is
  unavailable; Group Policy Preferences write the same value. A registry read never
  touches the network.
- **Alternatives**: `SHGetFileInfoW(SHGFI_DISPLAYNAME)` / `SIGDN_PARENTRELATIVEEDITING`
  (fast in every measured state, but the state "letter listed, server dead" could not be
  measured and the shell may touch the network there; it also returns Explorer's default
  form for unnamed drives, which would change every user's menu) — rejected. Server volume
  label via `GetVolumeInformationW` — not what Explorer shows (measured) and a network
  round trip per drive — rejected. `_LabelFromDesktopINI` — empty in every measured case,
  undocumented — not read.

## R2. Shown text

- **Decision**: `Name (path)` when a name exists, else the path alone (as today); name
  equal to the path (ordinal, case-insensitive) → path alone; control characters → space;
  leading/trailing spaces trimmed; empty → none. `&` doubled for the menu (column drawn
  with prefix processing), literal in the tooltip. Built on the heap; never cut.
- **Rationale**: spec clarification Q1; keeps the path visible (two drives can share a
  name); unnamed drives byte-identical.
- **Alternatives**: name in column 2, path in column 3 (column 3 is the right-aligned
  free-space column; a long path would widen it for every drive) — rejected.

## R3. Remote path source

- **Decision**: `WNetGetConnectionW("X:")` for every remote drive letter: returns the
  path for a connected drive (`NO_ERROR`) and also for a remembered, unavailable one
  (`ERROR_CONNECTION_UNAVAIL`, measured: remote name filled, 3 ms). `ERROR_MORE_DATA` →
  retry with the size Windows asks for. Any other result → today's text path (remembered
  path from the enumeration, `GetSubstInformation`), without a name.
- **Rationale**: Unicode-exact (today's remembered path comes from the code-page
  enumeration); one call also gives the state (R4).

## R4. Disconnected state

- **Decision**: disconnected ⇔ letter missing from `GetLogicalDrives()` (today) **or**
  `WNetGetConnectionW == ERROR_CONNECTION_UNAVAIL` **or** (`WNetGetConnectionW ==
  NO_ERROR` and `WNetGetConnection3W(L"X:", NULL, WNGC_INFOLEVEL_DISCONNECTED)` returns
  `NO_ERROR` with `dwState == WNGC_DISCONNECTED`).
- **Rationale**: these are the local, non-blocking indicators Windows provides (MPR
  answers from the redirector's state; measured 2–3 ms); `WNetGetConnection3` exists for
  exactly the "disconnected" question. The states with a missing letter are what the
  measurement could produce; the other two cover "letter listed, connection broken",
  which could not be produced here (person step).
- **Alternatives**: probing the server (`GetFileAttributes`, `GetVolumeInformation`) on a
  worker thread with a timeout — adds latency and threads for a state Windows already
  reports; rejected. Shell icon index (`SHGFI_SYSICONINDEX` 9/10) — matches R4 in every
  measured state but goes through the shell; rejected.

## R5. Drive bar refresh

- **Decision**: `CDrivesList::CachedNetDisconnectedMask` (bits of remote letters judged
  disconnected, computed over all letters regardless of the hidden-drives policy, the same
  way as `CachedDrivesMask`). `RebuildDriveBarsIfNeeded` compares it as well; the menu's
  callers pass the mask of the list they just built; the refresh callers and a new call on
  main window activation (`WM_USER_END_SUSPMODE`, next to the OneDrive re-check) compute it
  fresh, with the network enumeration's error box suppressed. The copy path (second bar)
  copies the mask.
- **Rationale**: root cause G3.3 — `GetLogicalDrives() | remembered` hides a remembered
  drive's state change. Windows sends no notification when a server becomes unreachable;
  activation is when the user looks at the bar again. No timer (spec Q3).
- **Alternatives**: register `SHCNE_SERVERDISCONNECT` (no evidence Windows emits it for
  SMB mappings; can be added later); a polling timer — rejected by the spec.

## R6. Reconnection

- **Decision**: `ExecuteItem` for an inaccessible drive: if the letter is in
  `GetLogicalDrives()`, do not call `RestoreNetworkConnection` (it would answer
  `ERROR_ALREADY_ASSIGNED`); the panel's path change reconnects on access
  (`CheckAndRestoreNetworkConnection`). Otherwise take the remote name from a fresh
  `GetNetworkDrives` (code page — what `RestoreNetworkConnection` and `GetUserName` use
  today) and reconnect; no remembered entry → no reconnect attempt, the path change reports
  the error as before.
- **Rationale**: decouples reconnection from the displayed text; fixes analysis B1–B3.
- **Out of scope**: moving the reconnect chain to Unicode (backlog
  `drive-list-code-page-texts`).

## R7. Tooltip freshness

- **Decision**: `GetDriveBarToolTip` recomputes the remote text at hover time
  (`WNetGetConnectionW` + registry, both local) and copies it with `CopyToolTipAnswer`;
  falls back to the stored text.
- **Rationale**: spec clarification Q5.
