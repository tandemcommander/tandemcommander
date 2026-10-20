---
title: The question whether to create a missing folder cuts a long path inside a letter
type: bug
status: new
severity: 2
area: long-paths
source: review:274
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# The question whether to create a missing folder cuts a long path inside a letter

## Problem

When a folder to be created does not exist yet (F7 with a name of several components, or other callers of `CheckAndCreateDirectory` that are not quiet), the program asks whether to create it. The question's text is built into a buffer of `MAX_PATH + 500` bytes and cut there without regard to UTF-8 letters: a path of roughly 700+ bytes of CJK letters ends in a broken character in the question (unlike the other messages of the same routine, which end at a whole letter). Display only; nothing is created wrongly. Feature 274 made this reachable by relative names in deep folders (it was reachable with typed absolute paths before).

## Evidence

By reading at feaa42a5 (review of feature 274, not measured): `src/salamdr3.cpp` `CheckAndCreateDirectory` - `char text[MAX_PATH + 500]; _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_CREATEDIRECTORY), dir);` without `SalU8TrimIncompleteTail(text)`; the other texts of the routine (`IDS_CREATEDIRFAILED`, `IDS_NAMEUSEDFORFILE`) call `SalU8TrimIncompleteTail`. Review notes in `specs/274-createdir-long-folder/fix-log.md` *Review*. A probe of the kind of `specs/274-createdir-long-folder/probe/createdir274_probe.ps1` (the reviewer's row SUB: `a\` + 100 CJK letters in the 288-byte folder shows the question) can drive it with a longer name.

## Expected

The question shows the whole path, or a shortened one that ends at a whole letter (CLAUDE.md: if text must be shortened, cut at a whole character); a probe row reads the question's text and finds valid UTF-8 / no replacement character.

## Log

- 2026-10-21 — created (source review:274)
