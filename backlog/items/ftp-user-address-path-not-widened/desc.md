---
title: FTP: user name, address and initial path keep their buffers (refused, never cut)
type: tech-debt
status: rejected
severity: 2
area: ftp
source: leftover:116
who: agent
created: 2026-10-05
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: feature 116, 2026-10-05 (listed under NEXT-WORK §C Decided - not to do): user name, address and initial path are not widened - they are parts of the plug-in's paths; 104's refusal ("too long", the dialog stays open, the stored value stays) remains, nothing is cut.
---

# FTP: user name, address and initial path keep their buffers (refused, never cut)

## Problem

An FTP user name, address or initial path whose UTF-8 form exceeds its buffer (100 bytes for a user name - 51+ Czech letters) is not taken: Connect and Close say "too long" and keep the dialog open. Feature 116 widened the secrets (301 bytes) but not these three fields, because they are parts of the plug-in's paths.

## Evidence

specs/NEXT-WORK.md item 5, queue 104 entry 3 (L1749-1777 at 7993914c): "User name, address and initial path NOT widened (parts of the plug-in's paths) - 104's refusal stays"; `specs/116-ftp-passwords/research.md`, `fix-log.md`. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L482, at 7993914c).

## Expected

(not stated in the source)

## Log

- 2026-10-05 — feature 116: user name, address and initial path not widened; 104's refusal stays
- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
