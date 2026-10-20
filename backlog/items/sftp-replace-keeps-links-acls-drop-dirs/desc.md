---
title: SFTP upload replace: links split, ACLs lost, drop folders fail, .tcpart left
type: bug
status: open
severity: 4
area: sftp
source: review:139
who: agent
created: 2026-10-14
updated: 2026-10-20
verified: 2026-10-20 2807bbc4
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# SFTP upload replace: links split, ACLs lost, drop folders fail, .tcpart left

## Problem

Left by the final review of feature 139 (upload replaces a server file only by a complete new one - temporary name, size confirmed, rename): a replaced server file with other hard links is split from them (SFTP v3 does not report the link count); ACLs and extended attributes are not carried; a write-only "drop" directory fails the size confirmation; orphaned `.tcpart-*` files are named in the message or the log, not cleaned up later.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L643-659. Feature 139 (`specs/139-sftp-no-silent-overwrite/fix-log.md`, final review 2026-10-13).

## Expected

An upload into a write-only directory succeeds (or says why); the limits on hard links and ACLs are either handled or stated to the user; orphaned `.tcpart-*` files are found and offered for cleanup.

## Notes

All older than the 0.1.10 cycle per the source. The write-only drop directory is the function that fails (severity 4); the others are limits of SFTP v3.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — verified at 2807bbc4: GUI probe on a stat-refusing test server: drop upload fails (Permission denied at the first lstat), no limits in the question, .tcpart left after a cut; OpenSSH 0733 drop works; hard link split by replay
