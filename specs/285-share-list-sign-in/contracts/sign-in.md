# Contract: the sign-in of a refused share list (feature 285)

Internal to the core (no plug-in interface change).

## SignInToUncServerW (drivelst.cpp, declared in consts.h)

```text
int SignInToUncServerW(HWND parent, const WCHAR* target);   // target = "\\server\IPC$"
```

- Calls `WNetAddConnection3W(parent, {dwType RESOURCETYPE_ANY, lpLocalName NULL, lpRemoteName
  target, lpProvider NULL}, NULL, NULL, CONNECT_INTERACTIVE)` on the caller's (UI) thread - no
  `CONNECT_UPDATE_PROFILE`, no password or user name from the program.
- Returns `SIGNIN_CONNECTED`, `SIGNIN_CANCELLED` (nothing shown) or `SIGNIN_ERRORSHOWN`.
- Messages (title `IDS_NETWORKERROR`), as `RestoreNetworkConnection` for an unmapped path:
  1219 -> `IDS_CREDENTIALCONFLICT`; `ERROR_EXTENDED_ERROR` with a provider text -> "provider:
  (code) text" (wide, `ShowExtendedNetErrorW`); any other error -> `GetErrorText(err)`.

## PickServerShare (fileswnb.cpp)

At most two rounds of the 125 list; between them, when `SalUncShareListStep` says
`SALUNC_LIST_SIGNIN`, the sign-in to `SalUncSignInTarget(server)`. Results map to `PSS_*`:
connected -> round 2; cancelled -> `PSS_CANCELLED`; error shown -> `PSS_ERRORSHOWN`; target not
built -> the list's error, `PSS_ERRORSHOWN`.

## Debug-only seam (absent from Release - string search at the gates)

Read by `SignInToUncServerW` on each call (main thread):

| Variable | Effect |
|---|---|
| `TC_PROBE_UNC_SIGNIN_LOG` | when set: the target is appended to this file as one UTF-8 line (also when Windows is asked) |
| `TC_PROBE_UNC_SIGNIN` | when set: Windows is not asked; the decimal value is the result of `WNetAddConnection3W` |
| `TC_PROBE_UNC_SIGNIN_KEEP` | when set with a result 0: `TC_PROBE_UNC_ERROR` stays (the list is refused again); without it a result 0 clears `TC_PROBE_UNC_ERROR` in the process, so the next list answers `TC_PROBE_UNC_SHARES` |
