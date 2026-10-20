# Research - 264-remembered-drive-reconnect

## R1 - How far can a remembered remote path reach? (measured)

`probe/measure_longpath.ps1 -Scan` (no GUI; maps a free letter to `\\localhost\C$\<fixture>`,
remembered; cleanup verified against a snapshot; result `probe/result_measure_longpath.txt`):

| remote length (UTF-16 units) | `WNetAddConnection2W` |
|---|---|
| 200 ... 259 | 0, `WNetGetConnectionW` returns it exactly |
| 260, 261, 262, 270, 300, 400, 1000 | 67 `ERROR_BAD_NET_NAME` |

For a 250-character remembered path ending in Cyrillic, after cancelling the connection
(kept remembered): `WNetGetConnectionW` 1201 with the exact path; the **wide** enumeration
(`WNetOpenEnumW(RESOURCE_REMEMBERED)`) returns it exactly; the **ANSI** enumeration returns
`...qqq?????` (code page `?`); `HKCU\Network\Z\RemotePath` holds it exactly;
`WNetAddConnection3W(NULL, exact path, CONNECT_UPDATE_PROFILE)` reconnects it (0, listed).

- **Decision**: Windows itself keeps at most 259 UTF-16 units of remote path (this redirector;
  another provider may differ). "Long" in the item is therefore a path that fits Windows but
  not the program's byte buffers: more than 259 bytes in the code page (DBCS systems) or in
  UTF-8 (every non-ASCII character takes 2-3 bytes; a 259-character Cyrillic path is ~500
  bytes). The fix keeps the path wide from Windows to Windows on the heap, so no length of
  ours applies; where UTF-8 is needed (the "listed" recovery, the probe seam) it is a heap
  conversion (`SalWToU8Alloc`). A remote path Windows refuses (260+) cannot exist as a
  remembered connection made through these APIs; the probe's L1 row uses 259 characters.

## R2 - Which reconnection mechanism?

- **Decision**: a wide port of the existing reconnection of a mapped letter (Windows 7+
  branch of `RestoreNetworkConnection` with `name != NULL`): exact wide remote path from the
  wide enumeration of remembered connections; saved user name and provider from
  `HKCU\Network\<letter>` read wide (matched to the path as before); the first attempt in the
  background thread (`WNetAddConnection3W`, `CONNECT_UPDATE_PROFILE`) under the Esc wait
  window; on a logon failure Windows' interactive dialog (`WNetAddConnection3W` with
  `CONNECT_INTERACTIVE | CONNECT_UPDATE_PROFILE`, on the UI thread with the parent window);
  the same messages.
- **Rationale**: it changes only the encoding and the buffers - every branch, flag, message
  and the wait window stay as they are (constitution II, item *Expected*: "the password
  dialog and the saved user name keep working"). Measured in R1: `WNetAddConnection3W` with
  the exact path reconnects.
- **Alternative considered**: `WNetRestoreSingleConnectionW(hwnd, L"X:", fUseUI)`. Needs no
  path, but with `fUseUI = TRUE` it must run on the UI thread with the parent window, so the
  first attempt would either block the UI (losing the Esc wait window for a slow server) or
  need two different APIs (background without UI, then foreground with UI) whose behaviour
  with saved user names, providers and extended errors is not measured here. Rejected as the
  less conservative option (clarification 1).

## R3 - Which consumers change?

Enumerated with Grep (`fix-log.md`, *Sites and consumers*):

- `CDrivesList::ExecuteItem` (drive menu / drive bar pick of a disconnected remembered
  letter): exact wide path + the new wide reconnection; seam line `RESTORE <L> <path>` now
  prints the exact path in UTF-8.
- `CheckAndRestoreNetworkConnection` (panel path change, `salamdr5.cpp` x2): letter not
  listed -> the new wide reconnection; letter listed (the Vista-after-hibernation recovery)
  -> the exact path in UTF-8 for `SalCheckPath` (which takes UTF-8; the code-page bytes it
  got before were wrong even for Czech characters).
- Unchanged: `RestoreNetworkConnection` itself (still used for UNC roots without a letter
  and by the Network plug-in through `zip.cpp`), `CheckAndConnectUNCNetworkPath`,
  `GetNetworkDrives` (mask users: `BuildData`, `mainwnd3.cpp`, `bugreprt.cpp`; the remembered
  path it copies stays the fallback text of `BuildData`, related item
  `drive-list-code-page-texts`).
- `NonBlockingWNetAddConnection3` keeps its ANSI interface for its two remaining callers; a
  wide twin shares its thread, its re-entrance lock and its wait loop.

## R4 - Saved user name and provider

`GetUserName` (drivelst.cpp) reads `RemotePath`, `UserName`, `ProviderName` of
`HKCU\Network\<letter>` with the code-page registry API into fixed buffers and uses them only
when `RemotePath` is "the same path" (`IsTheSamePath`: case-insensitive by the code-page
byte table, one leading and one trailing backslash ignored).

- **Decision**: a wide twin: values read with `RegQueryValueExW` on the heap (any length;
  REG_SZ only, as before), `RemotePath` compared with a pure rule
  `SalNetDriveSameRemote` (salnetdrive.h, saltests): ordinal case-insensitive
  (`CompareStringOrdinal`, the file system's rule - CLAUDE.md "the same name"), one trailing
  backslash on either side ignored. A user name or provider that cannot be read is treated
  as absent, as before.
- Read-only: nothing new is stored. `CONNECT_UPDATE_PROFILE` keeps updating the profile as
  before.

## R5 - The probe

`probe/run264.ps1`, in the style of the 246 independent test (which it extends): remembered
disconnected drives Q1 (CJK + Cyrillic, unnamed), Q2 (Cyrillic, named), L1 (259 characters,
Cyrillic tail - longer than 259 bytes in UTF-8), A1 (ASCII, negative control: must pass in
both builds), U1 (remembered path pointing at a non-existent server - the real error, not
"invalid name"), P1 (panel started on `Z:\` of a disconnected Q1 drive -> reconnect on
path change). Run against the fixed build and the baseline copy of HEAD0
(`%TEMP%\tc264base\tree`): Q1/Q2/L1/P1 must FAIL on the baseline (negative control).
The credential dialog and Esc need a keyboard and a password-protected share: NOT DRIVEN,
owed to a person.
