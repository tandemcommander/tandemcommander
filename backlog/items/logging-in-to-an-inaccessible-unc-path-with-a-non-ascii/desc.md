---
title: Logging in to an inaccessible UNC path with a non-ASCII share name uses code-page APIs
type: bug
status: open
severity: 3
area: encoding
source: measure:264
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Logging in to an inaccessible UNC path with a non-ASCII share name uses code-page APIs

## Problem

When a panel changes to a UNC path (`\\server\share\...`) that cannot be listed (for example
because the user has to log in to the server first), Tandem Commander checks the share root
and connects to it so that Windows can ask for a user name and password. The share root is
taken from the panel path, which is UTF-8, but it is handed to the code-page (ANSI) Windows
calls. A server or share name with any non-ASCII character (even a Czech one on a Czech
system) then reaches Windows as different bytes: the check and the connection go to a name
that does not exist, and the user gets an error instead of the login dialog.

## Evidence

At 6821f604, `src/drivelst.cpp`, `CheckAndConnectUNCNetworkPath` (line 1236), callers
`SalCheckAndRestorePath` and the path-change loop in `src/salamdr5.cpp`
(`CheckAndConnectUNCNetworkPath(parent, path, pathInvalid, ...)`):
- line 1250: `FindFirstFile(root, &data)` - the ANSI call with the UTF-8 root
  (`root` is built from `UNCPath` by `GetRootPath`);
- line 1267: `NonBlockingWNetAddConnection3(err, &ns, ...)` with `ns.lpRemoteName = root` - the
  ANSI `WNetAddConnection3` in the helper thread;
- line 1283: `RestoreNetworkConnection(parent, NULL, root)` - the ANSI `NETRESOURCE` /
  `WNetAddConnection3(... CONNECT_INTERACTIVE ...)`.
Found by reading while implementing feature 264 (which made the reconnection of a remembered
drive letter wide, `RestoreNetworkDriveW`); not measured.

## Expected

Connecting to an inaccessible UNC path whose server or share name holds non-ASCII
characters checks and connects exactly that path, and Windows' login dialog appears as it
does for an ASCII name.

## Notes

Not verified by a measurement: it needs a share with a non-ASCII name that refuses the
current user's credentials (the local `\\localhost\C$` accepts them, so the login branch
is not reached). Feature 264 added the wide twins this fix can reuse in `src/drivelst.cpp`:
`NonBlockingWNetAddConnection3W` (thread shared with the ANSI one) and the wide flow of
`RestoreNetworkDriveW`; `RestoreNetworkConnection` is also reached from the Network plug-in
through `src/zip.cpp` with an ANSI `NETRESOURCE` (plug-in interface - do not change its
signature).

## Log

- 2026-10-20 — created (source measure:264)
- 2026-10-20 — related item remembered-network-drive-with-a-non-code-page-or-long-path done in feature 264
- 2026-10-20 — moved to Next position 43
