---
title: FTP: should the plug-in ask a server whether it speaks UTF-8 (FEAT)?
type: decision
status: new
severity: 3
area: ftp
source: leftover:288
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: should the plug-in ask a server whether it speaks UTF-8 (FEAT)?

## Problem

Feature 288 gives each FTP server its own name encoding (unknown / UTF-8 / legacy / mixed), learned only from the names its listings show. Until a listing shows a name with letters outside ASCII the server is unknown and gets new names in UTF-8, so a folder created or a path typed right after connecting to an old code-page server (IIS 6, old Serv-U) still arrives garbled there. The FTP standard way to know is to ask: `FEAT` lists ` UTF8` on a server that speaks UTF-8 (RFC 2640; WinSCP and FileZilla ask and also send `OPTS UTF8 ON`). The plug-in sends neither today; sending them is a change of the program's network communication, which is the maintainer's decision.

## Evidence

- `specs/288-ftp-per-server-encoding/spec.md` *Clarifications* (the FEAT question) and *Assumptions*; `fix-log.md` *Decisions* and *Limits*; probe row UNK-MKD of `probe/ftp288_probe.ps1` (`result_after_review2.txt`: an unknown legacy server still gets `MKD` in UTF-8).
- `grep` of `src/plugins/ftp` at 92b9926e: no `FEAT`, no `OPTS UTF8` command is sent; the test server `specs/215-ftp-long-name-command/probe/ftpmini.py` already answers `FEAT` (with ` UTF8` in its UTF-8 mode).
- Where it would go: after the login, beside `SYST` (`ctrlcon1.cpp` sends `SYST` through `PrepareFTPCommand(NULL, .., ftpcmdSystem, ..)`; workers `operats6.cpp`), the answer set as evidence on the server's `CFTPServerEnc` (`ftputils.cpp`).

## Expected

The maintainer decides A or B (below); with B, a feature that sends `FEAT` once per connection, takes ` UTF8` as UTF-8 evidence (and no ` UTF8` on a server that answers `FEAT` as weak legacy evidence or none), and updates `PRIVACY.md` if the maintainer considers it a change of network communication.

## Question

Should the FTP plug-in send `FEAT` (and possibly `OPTS UTF8 ON`) after logging in, to learn whether a server speaks UTF-8 before any listing?

## Options

- **A — keep listening only (as now).** No new command; an unknown server gets UTF-8 until a listing shows a non-ASCII name. Costs: on an old code-page server, a folder created or a path typed before the first such listing arrives garbled.
- **B — send `FEAT` after login.** A server answering ` UTF8` is a UTF-8 server at once. Costs: one more command per connection (a few old servers answer `500` - harmless, logged); a server without ` UTF8` in its answer is not necessarily legacy (many byte-transparent UNIX servers omit it), so this mostly confirms UTF-8 servers, which already get UTF-8; `PRIVACY.md` may need a line.
- **C — B plus `OPTS UTF8 ON`.** Some servers (IIS 7.5+, Serv-U) switch to UTF-8 names only after it; costs as B, and a server that accepts it changes its own behaviour for the session.

## Recommendation

A for now: the cases B would decide (a UTF-8 server) already get UTF-8, and the case that matters (an old code-page server) does not announce itself in `FEAT`. Revisit with C if a user reports an IIS / Serv-U server that lists in the code page until `OPTS UTF8 ON`.

## Log

- 2026-10-21 — created (source leftover:288)
