# Contract - reconnecting a remembered drive (feature 264)

Internal to the core (`src/drivelst.cpp`); no plug-in interface changes.

## SalNetDriveSameRemote (src/common/salnetdrive.h, header-only, saltests)

```text
BOOL SalNetDriveSameRemote(const WCHAR* a, const WCHAR* b)
```

- TRUE when `a` and `b` name the same remote path: ordinal, case-insensitive comparison
  (`CompareStringOrdinal(..., TRUE)`), after dropping **one** trailing backslash from each.
- FALSE when either is NULL; two empty strings are equal (TRUE) - the caller never passes
  an empty remote path.
- No length limit, nothing cut, nothing allocated.

## GetRememberedNetDriveRemoteW (static)

- Input: drive letter `A`-`Z` / `a`-`z`.
- Output: malloc'd wide remote path of the remembered disk connection of that letter
  (`RESOURCE_REMEMBERED`, `RESOURCETYPE_DISK`), exactly as Windows returns it; NULL when
  the letter is not remembered, its remote path is empty, or memory / the enumeration fails.
- The caller frees it.

## RestoreNetworkDriveW (consts.h)

```text
BOOL RestoreNetworkDriveW(HWND parent, char drive, const WCHAR* remote)
```

- Reconnects `drive:` to exactly `remote` (never shortened, never converted) and returns
  TRUE on success, also when the drive turns out to be connected already
  (`ERROR_ALREADY_ASSIGNED`) or remembered already (`ERROR_DEVICE_ALREADY_REMEMBERED`);
  FALSE on cancel or error (the user has been told, except after Cancel).
- Flow (the Windows 7+ flow of `RestoreNetworkConnection` for a mapped letter):
  1. saved user name / provider: `HKCU\Network\<drive>` when its `RemotePath` is
     `SalNetDriveSameRemote` to `remote`;
  2. background attempt `WNetAddConnection3W(NULL, ..., CONNECT_UPDATE_PROFILE)` under the
     wait window `IDS_TRYINGRECONNECTESC` (3 s delay, Esc cancels -> FALSE, no message);
  3. `ERROR_SESSION_CREDENTIAL_CONFLICT` -> `IDS_CREDENTIALCONFLICT`, FALSE;
  4. a logon failure -> its message (extended error: `provider: (code) text` in UTF-8;
     a bad user name / password: no message) and one interactive attempt
     `WNetAddConnection3W(parent, ..., CONNECT_INTERACTIVE | CONNECT_UPDATE_PROFILE)`
     (Windows' credential dialog; Cancel -> FALSE, no message); a second logon failure ->
     FALSE;
  5. other errors -> `GetErrorText(err)` under `IDS_NETWORKERROR`, FALSE;
  6. success -> `WM_USER_DRIVES_CHANGE` posted to the main window, TRUE.

## NonBlockingWNetAddConnection3W (static)

- Same semantics as `NonBlockingWNetAddConnection3` (returns FALSE on Esc / shutdown /
  thread failure, else TRUE with `err` set), wide. Shares the thread object, the
  re-entrance lock and the wait for a previous attempt with the ANSI function.
- Its strings (local name, remote path, user name, provider) are heap copies owned by the
  thread parameters; they are released after the thread has ended - by this call on normal
  completion, or by the next attempt (ANSI or wide) after it waited for the thread.

## Probe seam (Debug only, `TC_PROBE_DRIVES_DUMP`, contract of feature 246)

- `RESTORE <L> <remote>` - `<remote>` is now the exact remote path in UTF-8 (was the
  code-page form); `NORESTORE <L> not-remembered` / `NORESTORE <L> listed` unchanged.
