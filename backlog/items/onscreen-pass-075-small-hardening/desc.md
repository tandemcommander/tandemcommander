---
title: On-screen pass of 075 (small hardening): scenarios S1-S5 and gate G6
type: person-step
status: open
severity: 3
area: viewer
source: leftover:075
who: person
created: 2026-09-02
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [onscreen-pass-codeview-070-074]
depends-on: []
reason: -
---

# On-screen pass of 075 (small hardening): scenarios S1-S5 and gate G6

## Problem

Feature 075 (small hardening batch: conversion-name copy, unset default, NULL conversion name, the viewer title under a long accented path, the File Comparator header) was verified by code and tests; its GUI half - scenarios S1-S5 and the leak / handle gate G6 - is owed.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'On-screen sweeps' ('075 S1-S5 + G6') and §3 '075' (~line 1120) (at 7993914c). Steps: specs/075-fix-small-hardening/quickstart.md S1 (D1, FR-002), S2 (D2, FR-003), S3 (D3, FR-004), S4 (D4, FR-005), S5 (D5, FR-006), gate G6.

## Expected

S1-S5 accepted and G6 shows no new leak or handle line against HEAD; recorded in 075's fix-log.

## Steps

- [ ] S1 - the conversion-name copy (075 quickstart.md)
- [ ] S2 - the unset default
- [ ] S3 - NULL conversion name
- [ ] S4 - the viewer title under a long accented path
- [ ] S5 - the File Comparator header
- [ ] G6 - Debug build: start, open the viewer on any file, open the File Comparator on two files, close all, exit; the debugger output / TRACE server shows no new leak or handle line

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
