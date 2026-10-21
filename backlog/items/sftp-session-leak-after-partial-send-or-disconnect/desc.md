---
title: SFTP: a stalled upload or a server disconnect leaks the whole session
type: bug
status: new
severity: 3
area: sftp
source: leftover:220
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: [sftp-leaks-and-waits-after-broken-connection]
depends-on: []
reason: -
---

# SFTP: a stalled upload or a server disconnect leaks the whole session

## Problem

Two ways an SFTP session is still not freed when it ends, both inside libssh2: (1) when an earlier request (a stalled upload) left a packet only partly sent, the repeated teardown step of feature 220 is refused (libssh2 will not start a new packet while one is half sent) - the SFTP structure, the channel and the session leak; (2) when the server sends SSH_MSG_DISCONNECT while SFTP is up, the channel's close is skipped and the SFTP structure leaks. The Debug build reports the leak at exit; in a Release build the memory stays allocated until exit.

## Evidence

By reading at d727a28f:
- `src/plugins/sftp/session.cpp` `CSFTPSession::Disconnect`, comment of feature 220: "Not covered (libssh2): a partly sent packet of an earlier request (a new packet is refused), ..., a server's SSH_MSG_DISCONNECT."
- (1) `src/common/dep/libssh2/src/transport.c` `_libssh2_transport_send` / `send_existing` (a pending partial write must complete before a new packet; after `shutdown(SD_BOTH)` it never does).
- (2) `src/common/dep/libssh2/src/packet.c` `_libssh2_packet_add`, `case SSH_MSG_DISCONNECT`: sets `LIBSSH2_SOCKET_DISCONNECTED` and returns; the channel's close callback (`libssh2_sftp_dtor`) is then not reached by the teardown (upstream `channel.c`).
- Records: `specs/220-sftp-leftovers/fix-log.md` *Review* (both named as not covered), probe `probe/fakessh.py` (217's proxy, mode `stallT`), `probe/sftp220_stall_probe.ps1`.
- Split out of `sftp-leaks-and-waits-after-broken-connection` parts (c) and (d).

## Expected

A session whose upload stalled with a partly sent packet, and a session the server ended with SSH_MSG_DISCONNECT, are both freed completely when the panel leaves them or the program ends: the Debug build reports no leak at exit; a healthy teardown is unchanged.

## Approach

Local libssh2 patches (as in 217 / 220, listed in `src/common/dep/libssh2/readme.txt`): on a socket already shut or disconnected, the teardown frees the channel / SFTP structure / session without sending (drop the pending partial packet; run the channel's close callback on disconnect). Reproduce first with new `fakessh.py` modes: stall the server's window during an upload of a large file (the partial send), and inject SSH_MSG_DISCONNECT after the SFTP subsystem started; Debug leak report at exit as the measure. Check against 220's stall probe and 217's probe for regressions.

## Notes

Not verified by a run - both cases are 220's review's reading. Severity 3: memory until exit, no wrong result.

## Log

- 2026-10-21 — created (source leftover:220)
