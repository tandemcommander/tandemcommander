---
title: State a deliberate minimum Windows version in the program and installer?
type: decision
status: open
severity: 2
area: build-release
source: github#6
who: person
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: -
feature: -
related: [windows-7-start-of-release-build]
depends-on: []
reason: -
---

# State a deliberate minimum Windows version in the program and installer?

## Problem

The project supports Windows 11+, but the code checks for Windows 7 (`salamdr1.cpp`) and is built for that API level, and the installer has no `MinVersion`. Feature 126 only removed an accidental start failure on Windows 7 / 8.0 (GitHub #6).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L529-533. Feature 126 (`specs/126-package-api-late-bind/`).

## Expected

(not stated in the source)

## Question

Keep "unsupported but not blocked" on older Windows, or state the floor in the program and the installer?

## Options

- A - keep the state now: Windows 11+ is the supported platform, older versions are neither tested nor blocked (126 removed the accidental start failure).
- B - state the floor: a `MinVersion` in `setup/tandemcommander.iss` and a start-up check in the program (`salamdr1.cpp`) at the chosen version.

## Recommendation

A until a reason appears: the start on Windows 7 SP1 is still unconfirmed (a person step), and a floor in the installer would refuse users for whom the program now starts. The source states no preference.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
