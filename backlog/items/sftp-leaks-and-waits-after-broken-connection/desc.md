---
title: SFTP: leaks and waits after a lost or broken connection
type: bug
status: open
severity: 3
area: sftp
source: leftover:220
who: agent
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# SFTP: leaks and waits after a lost or broken connection

## Problem

Left by features 140, 217 and 220: (a) a reply shorter than the protocol allows leaves a request half-done until the next timeout (no wrong answer, a wait); (b) one unclosed handle per lost connection stays allocated until exit - handles of a dead session are not closed through libssh2 (140's choice: a leak, never a double free); (c) in libssh2: a partly sent packet of an earlier request makes the repeated teardown step refuse - the session still leaks; (d) a server's SSH_MSG_DISCONNECT while SFTP is up leaks the SFTP structure (upstream `channel.c`); (e) owed: about 1,500 connections to show the 1-in-256 key-exchange failure gone (fixed by 217).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L651-655 and L757-768. Features 140 (`specs/140-sftp-dead-session/`), 217 (`specs/217-sftp-failed-handshake/`, `probe/fakessh.py`, `sftp217_probe.ps1`), 220 (`specs/220-sftp-leftovers/`, `fakessh.py` `stallT`). Test server: Docker container `tandem-sftp` on localhost:2222.

## Expected

A run of about 1,500 connections against the container shows no key-exchange failure; a lost connection, a short reply or a server DISCONNECT leaves no leaked session / handle (Debug build reports no leak at exit) and no request waits for a timeout it does not need.

## Approach

(c) and (d) are inside libssh2 - local patches as in 217; (e) is a probe an agent can run against the container.

## Log

- 2026-10-13 — the key-exchange failure ("SSH handshake failed: Unable to exchange encryption keys") seen a second time on the 0.1.9 build, on the ninth connection of a probe run; leak boxes followed and the program did not end within 30 s - root cause fixed by feature 217 on 2026-10-15
- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
