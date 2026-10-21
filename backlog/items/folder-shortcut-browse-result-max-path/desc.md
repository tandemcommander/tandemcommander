---
title: Folder-shortcut code gets only a MAX_PATH Browse result
type: bug
status: in-progress
severity: 3
area: long-paths
source: leftover:194
who: agent
created: 2026-10-15
updated: 2026-10-21
verified: 2026-10-21 7537240b
effort: S
feature: 286
related: []
depends-on: []
reason: -
---

# Folder-shortcut code gets only a MAX_PATH Browse result

## Problem

`shellib.cpp`'s folder-shortcut code gets only a Browse result of `MAX_PATH` bytes, so a folder shortcut whose target is a long UTF-8 path cannot be followed whole. Feature 194 fixed the drop-target code for shortcuts (`shellsup.cpp`) and left this one.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L546-548 (shell calls that return paths, 128). Feature 194 (`specs/194-drop-shortcut-target/`).

## Expected

A folder shortcut whose target needs more than 259 bytes is followed whole (heap buffer, `SalShellLinkGetPathU8`-style) or refused with `IDS_TOOLONGPATH`, never cut.

## Notes

Reachability not measured in the source; measure first (rule: measure before fixing).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-21 — verified at 7537240b: probe at 7537240b: a picked folder of 90 CJK letters (>260 bytes UTF-8) comes back as a code-page ? path, accepted; ResolveNetHoodPath leaves a folder shortcut with a >=MAX_PATH-byte target unfollowed (code)
- 2026-10-21 — run started, feature 286
