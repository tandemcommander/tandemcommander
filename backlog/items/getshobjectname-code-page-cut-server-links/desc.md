---
title: GetSHObjectName converts through CP_ACP and cuts at MAX_PATH (server links)
type: bug
status: open
severity: 2
area: encoding
source: leftover:128
who: agent
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [decide-ship-network-plugin-nethood]
depends-on: []
reason: -
---

# GetSHObjectName converts through CP_ACP and cuts at MAX_PATH (server links)

## Problem

`GetSHObjectName` (`shellib.cpp`) converts with `CP_ACP` into UTF-8 code and `GetSHObjectName(..., MAX_PATH)` cuts - used by the server-link branch of shortcuts, reachable only with a Network plug-in.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L542-544 and L801-802. Feature 128 (`specs/128-shortcut-target-unicode/`), 181.

## Expected

A server link's name is converted wide -> UTF-8 and kept whole.

## Notes

Reachability: the server-link branch runs only with a Network plug-in (nethood), which is off by default (`plugins.cfg`); with the default build the defect is not reachable, hence severity 2 and a low place in *Next*. If `decide-ship-network-plugin-nethood` enables the plug-in, it becomes reachable and should move up. NEXT-WORK listed it under *Code work an agent can do* with no park decision; the migration had parked it on its own judgement, the migration review (S5) reopened it.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-17 — moved to Next position 40 (reopened: migration review: parked without a recorded decision)
- 2026-10-17 — migration review S5: reachability note added
