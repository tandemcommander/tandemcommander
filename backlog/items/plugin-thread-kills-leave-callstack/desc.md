---
title: Plug-in threads ended by CThreadQueue leave their CCallStack registered
type: tech-debt
status: open
severity: 1
area: plugin-api
source: leftover:218
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Plug-in threads ended by CThreadQueue leave their CCallStack registered

## Problem

Feature 218 fixed the five core sites where a thread ended by `TerminateThread` left its `CCallStack` in `CallStacks`. Plug-in threads ended by `plugins/shared/auxtools.cpp` 173 / 222 `CThreadQueue` still leave theirs - swept only when the core ends a thread; a fix needs a plug-in service. The duplicated thread handle of a forgotten entry stays open (a Debug note).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L820-824. Feature 218 (`specs/218-callstack-terminated-threads/`), 193.

## Expected

A plug-in thread terminated by `CThreadQueue` is removed from `CallStacks` through a core service (an append-only ABI addition with a contract); no stale entry or open handle remains.

## Notes

Needs a plug-in interface addition (contract in `specs/NNN-*/contracts/`, `spl_vers.h` history).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
