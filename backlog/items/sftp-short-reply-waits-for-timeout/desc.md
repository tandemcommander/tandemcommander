---
title: SFTP: a server reply shorter than the protocol allows waits for the timeout
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

# SFTP: a server reply shorter than the protocol allows waits for the timeout

## Problem

When an SFTP server (or something between it and the program) sends a reply shorter than the protocol allows, the request that waits for it is left half done until the plug-in's timeout (30 s by default) runs out; then the session is ended as dead (feature 140). No wrong answer is given - the user only waits, and then loses the connection - although the broken reply is known at once.

## Evidence

By reading at d727a28f (not reproduced):
- `src/common/dep/libssh2/src/sftp.c` `sftp_packet_add`: a packet of fewer than 5 bytes returns `LIBSSH2_ERROR_OUT_OF_BOUNDARY` and is dropped - the request id it carried is never answered, so the waiting `sftp_packet_require*` loop runs until the session timeout (suspected site; other "too short" checks of the reply parsers return `LIBSSH2_ERROR_SFTP_PROTOCOL`, which 140's `SftpRcIsDeadTransport` treats as not dead).
- Records: `specs/140-sftp-dead-session/` (left by 140: "a reply shorter than the protocol allows leaves a request half-done until the next timeout (no wrong answer, a wait)"); `specs/220-sftp-leftovers/fix-log.md` *Review*: "Not measured here".
- Split out of `sftp-leaks-and-waits-after-broken-connection` part (a).

## Expected

A reply shorter than the protocol allows ends its request at once with a reason (the session judged dead or the request refused, never a later request answered with it); no request waits for a timeout it does not need. A probe row with a proxy that shortens one reply shows the failure within a second.

## Approach

Measure first: a `fakessh.py` mode (217 / 220's proxy) cannot rewrite encrypted SFTP replies, so the reproduction needs another seam - e.g. a debug-only seam in the plug-in or a test of libssh2's `sftp_packet_add` / `sftp_packet_read` in the plug-in's `test/` harness. Then a local libssh2 patch (listed in `readme.txt`) that turns a too-short packet into a hard error of the waiting request, and check how `SftpRcIsDeadTransport` judges it.

## Notes

The exact site is suspected, not confirmed; 140 named the symptom without a site.

## Log

- 2026-10-21 — created (source leftover:140)
- 2026-10-21 — severity as the source item
- 2026-10-21 — moved to Next position 59
- 2026-10-23 — related item sftp-leaks-and-waits-after-broken-connection closed: split into: sftp-open-handles-of-lost-connection-leak, sftp-session-leak-after-partial-send-or-disconnect, sftp-short-reply-waits-for-timeout, sftp-key-exchange-soak-1500-connections (and the related sftp-a-copy-posted-right-after-a-failed-upload-and-its) - the parts replace it; maintainer 2026-10-23
