---
title: Start the 0.1.10 build on Windows 7 SP1 / Server 2008 R2 SP1 (GitHub #6)
type: person-step
status: open
severity: 2
area: build-release
source: leftover:126
who: person
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [decide-windows-version-floor]
depends-on: []
reason: -
---

# Start the 0.1.10 build on Windows 7 SP1 / Server 2008 R2 SP1 (GitHub #6)

## Problem

Feature 126 removed an accidental start failure on Windows 7 / 8.0; a start on Windows 7 SP1 / Server 2008 R2 SP1 is not testable in the development environment.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L855-856. Feature 126 (`specs/126-package-api-late-bind/`).

## Expected

The program starts on Windows 7 SP1 / Server 2008 R2 SP1.

## Steps

- [ ] Start the 0.1.10 build on Windows 7 SP1 or Server 2008 R2 SP1 (the reporter of GitHub #6 is asked)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-17 — source changed from github#6 to leftover:126 at migration: the issue itself is the decision item decide-windows-version-floor
