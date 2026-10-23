---
title: SFTP: files open when a connection is lost stay allocated until exit
type: bug
status: open
severity: 3
area: sftp
source: leftover:140
who: agent
created: 2026-10-21
updated: 2026-10-23
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# SFTP: files open when a connection is lost stay allocated until exit

## Problem

When an SFTP connection is lost (a timeout, a broken link, a server that stops answering) while a remote file or directory is open - a download, an upload, a listing - the handle of that file stays allocated until the program ends: one leaked libssh2 handle per lost connection, reported by the Debug build at exit. Feature 140 chose this on purpose (a leak, never a double free): handles of a dead session are not closed through libssh2, and `libssh2_sftp_shutdown` does not free the handles still on its list.

## Evidence

By reading at d727a28f:
- `src/plugins/sftp/session.cpp` `CSFTPSession::CloseHandle` and `CloseHandleChecked`: `NoRequest` on a dead session returns before `libssh2_sftp_close_handle` - the handle is never touched again.
- `src/common/dep/libssh2/src/sftp.c` `sftp_shutdown`: "TODO: We should consider walking over the sftp_handles list and kill any remaining sftp handles ..." - then `_libssh2_channel_free`; `libssh2_sftp_dtor` frees only the partial / readdir packets and the SFTP structure.
- Records: `specs/140-sftp-dead-session/` (plan.md "released by Disconnect"; FEATURE-HISTORY 140 "a leak until exit, never a double free"), `specs/220-sftp-leftovers/fix-log.md` *Review* ("SFTP handles left open on a dead session are not freed (`sftp.c` TODO)").
- Split out of `sftp-leaks-and-waits-after-broken-connection` part (b).

## Expected

A connection lost while a remote file or directory is open leaves no allocated handle: the Debug build reports no leak at exit after such a loss, and no handle of a freed session can ever be used or freed again (no use after free, no double free).

## Approach

A local libssh2 patch (as in 217 / 220, listed in `src/common/dep/libssh2/readme.txt`): free the handles still on `sftp->sftp_handles` (their buffers and pending requests) in the teardown, without sending a close. First enumerate every holder of a `LIBSSH2_SFTP_HANDLE*` in the plug-in (`fs.cpp`, `operats.cpp`, `listing.cpp`, `session.cpp`) and prove none can pass the pointer to libssh2 after `Disconnect` - especially after `Reconnect` (`ChangePath`), where `NoRequest` is FALSE again and a stale pointer would reach the freed structure. Reproduce with 220's `probe/fakessh.py` `stallT` during a download of a large file and the Debug leak report at exit.

## Notes

Reverses 140's recorded choice only in its means (the leak), not its rule (never a double free). Severity 3: memory until exit, no wrong result.

## Log

- 2026-10-21 — created (source leftover:140)
- 2026-10-21 — moved to Next position 57
- 2026-10-23 — related item sftp-leaks-and-waits-after-broken-connection closed: split into: sftp-open-handles-of-lost-connection-leak, sftp-session-leak-after-partial-send-or-disconnect, sftp-short-reply-waits-for-timeout, sftp-key-exchange-soak-1500-connections (and the related sftp-a-copy-posted-right-after-a-failed-upload-and-its) - the parts replace it; maintainer 2026-10-23
