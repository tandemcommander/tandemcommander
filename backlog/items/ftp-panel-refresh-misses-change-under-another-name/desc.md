---
title: FTP: a panel is not refreshed after a change made under another name of its server
type: bug
status: open
severity: 4
area: ftp
source: review:341
who: agent
created: 2026-10-24
updated: 2026-10-30
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: a panel is not refreshed after a change made under another name of its server

## Problem

After an upload, a rename or a delete made through one name of an FTP server (`localhost`), an
FTP panel showing the same folder through another name of it (`127.0.0.1`, the server's address,
another of its addresses) is not refreshed: it keeps showing the old listing (a file just stored
is missing, a renamed file has its old name) until the user refreshes it (Ctrl+R) or changes the
folder. Since feature 341 the stale listing no longer seeds an upload into the panel (no data
loss); what remains is the wrong display.

## Evidence

By reading at 1468b771 and measured by review 2 of feature 341 (`specs/341-ftp-upload-cache-alias/fix-log.md`
*Review*; its probe copy, row SEED-ALIAS: after upload 2 to `localhost` the panel at `127.0.0.1`
was not refreshed): `CPluginFSInterface::AcceptChangeOnPathNotification`
(`src/plugins/ftp/fs3.cpp`) matches the notified path to the panel's by `FTPHasTheSameRootPath`,
which compares the `user@host:port` root as typed.

## Expected

A change made through another name with the same user and port refreshes the panel, or marks its
listing outdated so that the next use lists it again.

## Notes

Severity 4: a wrong display with a workaround (refresh). Refreshing every FTP panel of the same
user and port on every change under another name costs a `LIST` per change - an "outdated" mark
may be enough.

## Log

- 2026-10-24 — created (source review:341)
- 2026-10-30 — moved to Next position 31
