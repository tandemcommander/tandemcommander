---
title: FTP: upload listing cache lookup remembers a slot number instead of the listing index
type: tech-debt
status: new
severity: 1
area: ftp
source: review:385
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: upload listing cache lookup remembers a slot number instead of the listing index

## Problem

`CUploadListingsOnServer::FindPath` keeps a small cache of listing indexes it found recently (`FoundPathIndexes`). When a hit in that cache moves up to the first position, the code stores the cache slot number `i` instead of the listing index `ind`. The next lookup then starts from a wrong index. Every candidate is checked again by `FTPIsTheSameServerPath`, so the answer is still right; only the shortcut is lost (speed, no wrong result).

## Evidence

By reading at feature 385 (review 1, NOTE 3; not measured): `src/plugins/ftp/operats9.cpp` `CUploadListingsOnServer::FindPath`, the first loop: `memmove(FoundPathIndexes + 1, FoundPathIndexes, sizeof(int) * i); FoundPathIndexes[0] = i;` - `ind` is the listing index found, `i` the slot.

## Expected

The first slot gets the listing index (`FoundPathIndexes[0] = ind`); the lookup answers are unchanged.

## Notes

Severity 1: internal tidiness - the lookup still returns the right listing; it only searches more often than it needs to.

## Log

- 2026-11-02 — created (source review:385)
