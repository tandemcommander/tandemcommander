---
title: Two builds of one commit give different binaries (no /Brepro, build-time strings)
type: tech-debt
status: new
severity: 4
area: build-release
source: measure:428
who: agent
created: 2026-11-14
updated: 2026-11-14
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Two builds of one commit give different binaries (no /Brepro, build-time strings)

## Problem

The constitution's principle I says every environment MUST produce identical binaries from the same source revision. Two `build.cmd full release rebuild portable` runs of the same commit gave 215 of 624 files that differ: the linker's COFF, debug-directory and export time stamps, the PDB GUID and age, the header check sum (the projects do not link with `/Brepro`), the core's `Built: __DATE__, __TIME__` string, and the time-based version number in `plugins\plugins.ver`. The normal edition's binaries differ the same way. A release can therefore not be rebuilt bit for bit and compared with the published one.

## Evidence

Measured in feature 428 (`specs/428-portable-build/fix-log.md`, "SC-005, two builds of one commit"): 409 files identical, 215 differing only in those fields. `specs/428-portable-build/probe/zip_check.py` (`normalize`, check Z8b) zeroes exactly these fields to compare two builds; with a real code change in between it reports the changed file (negative control).

## Expected

Decide whether bit-identical builds are wanted. If so: link and compile with `/Brepro` (or fixed time stamps), replace the `__DATE__ __TIME__` build string with a value fixed by the build (for example the commit time), make `plugins.ver`'s version deterministic, and let `zip_check.py` Z8 / `tree_manifest.py` compare raw bytes. If not: amend principle I of the constitution to what is achieved (the same files apart from build stamps).

## Log

- 2026-11-14 — created (source measure:428)
