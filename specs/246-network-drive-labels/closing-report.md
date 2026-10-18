# 246 — Closing report: network drive names and disconnected-drive icons

**Branch** `246-network-drive-labels` (not pushed) · **Date** 2026-10-18 · run autonomously
(the maintainer delegated every decision; they are recorded in `spec.md` *Clarifications*).

## The report

"Tandem Commander (like Altap Salamander) does not show the names of network drives: a
Samba share mapped as a drive is named 'Archiv' in Windows but shown as
`\\SHARE_SAMBA\Share\Storage`; and the icon of such a drive does not change to the
disconnected icon when the drive is disconnected."

## Causes (measured — `analysis.md`)

1. **Names**: the drive list never read the drive's Windows name; it showed the remote path
   only. Explorer's name is the per-user, per-path value `_LabelFromReg` under
   `HKCU\...\Explorer\MountPoints2\##server#share#path` (written by a rename in Explorer
   or by a Group Policy drive map). The server's volume label is *not* what Explorer shows.
2. **Icon**: every "red cross" state Windows produced on the test machine (a remembered
   connection not restored) has the letter absent from `GetLogicalDrives()` — the Change
   Drive menu (rebuilt at each opening) already showed the disconnected icon. The **drive
   bars** did not: they are rebuilt only when `GetLogicalDrives() | remembered drives`
   changes, and a remembered drive switching between connected and unavailable leaves that
   value equal. Reproduced on the baseline build (bar image unchanged after the state change
   + window activation, and after Alt+F1 open/close). Additionally, a letter Windows still
   lists while reporting its connection unavailable/disconnected was always "connected".
3. In the same place: the reconnection of a disconnected drive used the menu's text as the
   remote name (a doubled `&` reached it; a name in the text would have broken it).

## What changed

- Change Drive menu and drive bar tooltip: `Name (\\server\share\path)` for a named drive;
  unnamed drives exactly as before (ASCII paths under 260 characters byte-identical);
  Unicode-exact, never cut in the menu; the tooltip (hard 5000-byte buffer) shortens only
  the name, with an ellipsis, never the path; REG_EXPAND_SZ names expanded as Explorer does;
  the tooltip reads the name at hover time (a rename shows without a rebuild).
- Disconnected icon: letter missing **or** `WNetGetConnectionW == ERROR_CONNECTION_UNAVAIL`
  **or** `WNetGetConnection3W` reports disconnected — all local answers, no server contact.
- Drive bars rebuilt when the set of disconnected network drives changes — on Change Drive
  menu open/close, refresh, and main window activation (new, quiet: no message box).
- Reconnection from the menu/bar takes the remembered path from Windows (fixes `&`).
- Code: `src/common/salnetdrive.h` (pure rules), `src/drivelst.cpp/.h`,
  `src/mainwnd3.cpp/mainwnd.h`, `src/toolbar6.cpp/toolbar.h`, `src/salamand.h`. No new UI
  string, no plug-in interface change. Debug-only probe seam `TC_PROBE_DRIVES_DUMP`.
- Documents: `CHANGELOG.md` (0.1.11 unreleased), `PRIVACY.md` (the new local read of
  Explorer's drive names; nothing stored or sent), `specs/FEATURE-HISTORY.md`.

## Evidence

| Check | Result |
|---|---|
| saltests | 23,491 → 24,297 checks, 0 failed |
| `tools/check_encoding.py` | TOTAL 0 |
| clang-format on the new code | clean (remaining deviations in `mainwnd3.cpp` pre-existing) |
| GUI probe `probe/run246.ps1`, fixed build | 0 FAIL (N1–N12 texts, T1 tooltips via the seam, R1 rename, S1–S5 state/refresh/activation, P1–P2 reconnection incl. `&`, M1 clean); cleanup verified, registry SHA-256 identical |
| Same probe, baseline (negative control) | stale bar reproduced; names absent |
| Independent black-box tests (`test-independent/`) | round 1: 65 PASS + 3 findings (fixed / out of scope); round 2: 0 FAIL (80 PASS, 1 NOT DRIVEN); round 3 (final build 7880090a, tooltip limits + menu texts): 62/62 PASS |
| Performance (SC-004) | menu +2.6 to +3.2 ms with 7 network drives incl. unreachable ones; activation no measurable cost |
| Independent refute-first reviews | round 1: 1 major + 3 minor (fixed / reworded); round 2: no serious defect, 1 cosmetic (fixed) |

## Not done / owed

- **Person step** (backlog Inbox `check-network-drive-names-and-disconnected-icons-with-a-real`):
  real SMB/Samba server switched off with a drive mapped (the state "letter listed,
  connection broken" was not producible here), the tooltip hover (needs the real cursor),
  activation speed with third-party network providers.
- **Out of scope, pre-existing** (backlog Inbox
  `remembered-network-drive-with-a-non-code-page-or-long-path`): reconnecting a remembered
  drive whose path has characters outside the code page or is longer than 259 characters.
- The reporter's "Archiv" is assumed to be a name given in Explorer (or by policy); worth
  confirming with them after the release.
- Not pushed, no release steps (maintainer).
