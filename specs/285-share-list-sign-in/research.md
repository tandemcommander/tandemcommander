# Research - 285 share list sign-in

## R1 What the full share path's sign-in is (measured by reading at eb173f7f)

`CheckAndConnectUNCNetworkPath` (drivelst.cpp): the root `\\server\share` cannot be listed and
the error is of the logon-failure class (`IsLogonFailureErr`: access denied, logon failure,
account restriction / hours / workstation, expired or must-change password, disabled account,
not granted, trust failures, ill-formed / invalid password, bad user name, no such user,
downgrade detected, extended error) or `IsAdminShareExtraLogonFailureErr` -> 
`RestoreNetworkConnection(parent, NULL, root)`. On Windows 7 and later (`Windows7AndLater`, always
true on the supported systems) `connectInteractive = TRUE`, so the loop calls
`WNetAddConnection3(parent, ns{RESOURCETYPE_DISK, NULL, root, NULL}, NULL, NULL,
CONNECT_INTERACTIVE)` - Windows' own credential dialog, on the UI thread. Results:

| Result | What the user sees |
|---|---|
| `ERROR_CANCELLED` | nothing; the path change ends |
| `ERROR_SESSION_CREDENTIAL_CONFLICT` | `IDS_CREDENTIALCONFLICT`, title `IDS_NETWORKERROR` |
| `ERROR_ALREADY_ASSIGNED` | taken as connected |
| logon-failure class, `ERROR_EXTENDED_ERROR` with a provider text | "provider: (code) text", title `IDS_NETWORKERROR` |
| logon-failure class otherwise | `GetErrorText(err)`, title `IDS_NETWORKERROR` (for an unmapped path always) |
| another error (not `ERROR_DEVICE_ALREADY_REMEMBERED`) | `GetErrorText(err)`, title `IDS_NETWORKERROR` |
| success | connected (it also posts `WM_USER_DRIVES_CHANGE`) |

`name == NULL` -> no `CONNECT_UPDATE_PROFILE`: the connection is not remembered.

- **Decision**: the sign-in of the share list does exactly this, with the same messages.
- **Rejected**: calling `RestoreNetworkConnection` itself - its strings are code-page (`char`,
  `NETRESOURCEA`, `WNetAddConnection3` = A): a server name outside the code page would become `?`
  (the item's *Notes*; CLAUDE.md "never pass names to an `A` API"). Feature 264 did the same for
  mapped letters (`RestoreNetworkDriveW`).
- **Added after the review (SHOULD 1)**: `CONNECT_PROMPT`. The full share path connects the very
  share that refused, so Windows' first silent try with the current identity fails and the dialog
  follows. Here the target (`IPC$`) is not what refused (the list is): the current identity may
  connect `IPC$` silently while the list stays refused - no dialog, the same error, and a
  connection left for the session. `CONNECT_PROMPT` (valid with `CONNECT_INTERACTIVE`) makes
  Windows ask in every case, which is what the route needs: the current identity was refused
  already.
- **Not copied**: `WM_USER_DRIVES_CHANGE` after success - a connection to `IPC$` maps no drive;
  the drive bars have nothing to rebuild.

## R2 The sign-in target

A server is signed in to through its inter-process share `\\server\IPC$` (`net use \\server\IPC$`
is the classic form; the Network plug-in passed the server's own resource `\\server`). Measured on
this machine with `WNetAddConnection3W` without a dialog and the current credentials:
`\\localhost`, `\\localhost\IPC$`, `\\PC-DOMA`, `\\PC-DOMA\IPC$` each with `RESOURCETYPE_ANY` and
`RESOURCETYPE_DISK` -> 5 (the server was reached and refused), an unknown server -> 64; no
connection was left (`WNetCancelConnection2W` -> 2250 "not connected").

- **Decision**: `\\server\IPC$`, `RESOURCETYPE_ANY` (IPC$ is not a disk share), built by the pure
  rule `SalUncSignInTarget` from the server name (UTF-8) and converted whole to UTF-16.
- **Rejected**: `\\server` alone - accepted the same way here, but not documented for
  `WNetAddConnection3`; `RESOURCETYPE_DISK` for IPC$ - a wrong type for that share.

## R3 Once, and where in the route

`PickServerShare` reads the list on a worker (`CUncSharesJob`); the main thread waits (400 ms
quiet, then the wait window with Esc). The sign-in must run on the main thread (the dialog's
parent is the panel; `CONNECT_INTERACTIVE` is not allowed on another thread - drivelst.cpp says
so). Decision: a loop of at most two rounds - round 1 reads the list; refused with a logon failure
-> the job is released, the sign-in runs, then round 2 reads the list again with a fresh job and
the same wait; round 2 never offers the sign-in again (`SalUncShareListStep(..., signInTried)`).
`GetAsyncKeyState(VK_ESCAPE)` is primed before each round (the 125 trap: an Esc pressed earlier,
here in Windows' dialog, must not cancel the wait).

## R4 Privacy and stored data

The program types, keeps and shows no name or password: Windows' dialog collects them and Windows
connects; a *Remember my credentials* box is Windows' and stores in the Windows Credential
Manager. `PRIVACY.md` claims checked to stay true: "when you open a network location, Windows
connects to it", "Passwords for network drives are entered in a Windows dialog and are saved only
if you choose so there, by Windows", "The program handles no name or password for it". Not
changed by the run (maintainer-owned); whether to name the sign-in is recorded for the maintainer.

## R5 The probe

The real dialog cannot be driven on the hidden desktop (Windows' credential UI; a person's step).
A Debug-only seam inside `SignInToUncServerW` answers instead of Windows and logs the target, so
the route and every message path are driven: `TC_PROBE_UNC_SIGNIN` (the result code),
`TC_PROBE_UNC_SIGNIN_KEEP` (do not clear the list error after a success), `TC_PROBE_UNC_SIGNIN_LOG`
(file; one UTF-8 line per attempt with the target). On a seam success the seam clears
`TC_PROBE_UNC_ERROR` in the process so round 2 answers with `TC_PROBE_UNC_SHARES`.
