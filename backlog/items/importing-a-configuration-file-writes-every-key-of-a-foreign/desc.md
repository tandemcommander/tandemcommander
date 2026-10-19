---
title: Importing a configuration file writes every key of a foreign .reg file
type: bug
status: open
severity: 4
area: data-safety
source: measure:245
who: agent
created: 2026-10-18
updated: 2026-10-19
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Importing a configuration file writes every key of a foreign .reg file

## Problem

The start-up import of config.reg (installation folder, %APPDATA%/Tandem Commander or the -C parameter) accepts a .reg file that holds no Tandem Commander configuration after one question (default No) and then writes every key in it - also keys of other programs or HKEY_CLASSES_ROOT.

## Evidence

src/salamdr2.cpp:2939 ImportConfiguration at 18e0bd3c: the memory parse checks only whether the file contains our root (IDS_IMPORTCFG_NOTOURVER, line 3035); Parse(buf, sysReg, TRUE) then imports the whole file. Found while analysing feature 245 (analysis.md A11.1); not reproduced.

## Expected

Only keys under the program own root are imported (others skipped and named), or a file without our configuration is refused.

## Log

- 2026-10-18 — created (source measure:245)
- 2026-10-19 — moved to Next position 21
