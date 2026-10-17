---
title: FTP: server reply cut inside a character; Logs window caret counts bytes
type: bug
status: open
severity: 2
area: ftp
source: leftover:134
who: agent
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: server reply cut inside a character; Logs window caret counts bytes

## Problem

Left by feature 134 (FTP mixed templates): a server reply is cut inside a character by its 300 / 700-byte buffer; the Logs window's caret arithmetic is in bytes (UTF-8 log); the core's `PrintDiskSize` mode 2 is mixed in itself.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L618-623. Features 134 (`specs/134-ftp-mixed-templates/`) and 136 (`specs/136-ftp-verify-rows/fix-log.md`, section 3).

## Expected

Server replies are shortened at a whole character; the Logs window's caret moves by characters; `PrintDiskSize` mode 2 produces one encoding.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
