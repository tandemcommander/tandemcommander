---
title: SFTP: a Copy posted right after a failed upload and its reconnect may open nothing
type: bug
status: open
severity: 3
area: sftp
source: measure:258
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: ?
feature: -
related: [sftp-leaks-and-waits-after-broken-connection]
depends-on: []
reason: -
---

# SFTP: a Copy posted right after a failed upload and its reconnect may open nothing

## Problem

After an upload to an SFTP panel failed because the server dropped the connection, the core shows its Copy dialog again (cancelled), the panel refreshes and the plug-in reconnects (host key question answered). A Copy command (727) posted to the main window right after that opened no dialog at all - twice, on the build before feature 258 and on 258's first build. The same command, posted after one more round trip (Change Directory opened and cancelled), worked. Not known whether a real user's F5 at that moment is lost too, or whether only the probe's posted command arrives too early.

## Evidence

Feature 258, `specs/258-sftp-drop-folder-upload/fix-log.md` ("Probe trap"), probe `specs/258-sftp-drop-folder-upload/probe/sftp258_probe.ps1` row CUT (the `Get-Loc` before a repeated command is the workaround), test server `probe/dropsftp.py` (`/cut` drops the transport at the close of an upload). `probe/result_before.txt`, row CUT: dialogs end with `host key || --- run 2` - nothing after the second command. Review 1 of 258, NOTE-7.

## Expected

Either the cause is found and a command given after the reconnect is never lost (a probe row without the workaround passes), or it is shown to be the probe's timing only (a key press through the real input path works at once) and the item is closed.

## Notes

Not verified with a real keyboard. Severity 3: at worst the user presses F5 again. Related to the SFTP reconnect handling (`EnsureConnected`, `ReconnectLostInChangePath` in `src/plugins/sftp/fs.cpp`) - by guess only.

## Log

- 2026-10-20 — created (source measure:258)
- 2026-10-20 — moved to Next position 49
