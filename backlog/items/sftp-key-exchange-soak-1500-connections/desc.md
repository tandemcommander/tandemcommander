---
title: SFTP: run about 1,500 connections to show the key-exchange failure gone
type: tech-debt
status: new
severity: 3
area: sftp
source: leftover:217
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [sftp-leaks-and-waits-after-broken-connection]
depends-on: []
reason: -
---

# SFTP: run about 1,500 connections to show the key-exchange failure gone

## Problem

Feature 217 fixed the intermittent SFTP connection failure "SSH handshake failed: Unable to exchange encryption keys" (about one key exchange in 256: WinCNG hashed a shared secret with a leading zero as a non-minimal mpint). The fix was shown with a proxy that forces the failure and with 20 normal connections; a run long enough to show the natural 1-in-256 failure gone (about 1,500 connections, where about six failures were expected before the fix) is still owed.

## Evidence

- `specs/217-sftp-failed-handshake/fix-log.md`: "Not driven (about 1,500 ...)"; `probe/result_after_real20.txt` (20 normal connections, clean); `probe/sftp217_probe.ps1` parameter `-Repeat` (row REAL: the real server, `$Repeat` connections).
- Test server: Docker container `tandem-sftp` on localhost:2222 (memory: env quirks).
- Split out of `sftp-leaks-and-waits-after-broken-connection` part (e).

## Expected

`sftp217_probe.ps1` (or a variant) run on the hidden desktop against the container with about 1,500 connections: no "Unable to exchange encryption keys", no leak box, a clean exit; the result file recorded under a feature's `probe/`.

## Approach

Probe only, no code change expected. Run on the current Debug build (with 217's local libssh2 patches), back up and restore the registry as the probe does; split into batches if one process run gets too long. A failure seen is a new finding (`measure:NNN`), with the server's log (`docker logs tandem-sftp`).

## Notes

Needs Docker Desktop running (a run can start it with `docker desktop start`). Severity 3 as the source item.

## Log

- 2026-10-21 — created (source leftover:217)
