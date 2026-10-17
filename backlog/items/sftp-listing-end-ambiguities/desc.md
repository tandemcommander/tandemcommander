---
title: SFTP: a stopped listing shows as the directory; an empty NAME ends it
type: bug
status: parked
severity: 2
area: sftp
source: leftover:133
who: agent
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: ?
feature: -
related: []
depends-on: []
reason: Kept by feature 133: a listing stopped by the user is shown as the directory (old behaviour, kept); an empty name or NAME packet cannot be told apart from the end through `libssh2_sftp_readdir_ex`.
---

# SFTP: a stopped listing shows as the directory; an empty NAME ends it

## Problem

A listing stopped by the user (Close in the wait window) is shown in the panel as the directory; an empty name or an empty NAME packet from a broken server still reads as "end of directory".

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L661-664. Feature 133 (`specs/133-sftp-server-verify/fix-log.md`).

## Expected

A stopped or broken listing is marked incomplete (would need a libssh2 change for the NAME case).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
