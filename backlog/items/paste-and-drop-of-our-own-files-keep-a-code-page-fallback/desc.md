---
title: Paste and drop of our own files keep a code-page fallback for a name on low memory
type: bug
status: open
severity: 3
area: encoding
source: review:259
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Paste and drop of our own files keep a code-page fallback for a name on low memory

## Problem

Paste and drag & drop of files into a disk folder (our own copy / move routine, `CImpDropTarget::ProcessClipboardData`) store each source and map name through `CCopyMoveRecord::AllocChars`. When the UTF-8 conversion fails, the wide overload converts the name through the ANSI code page (`WideCharToMultiByte(CP_ACP, ...)` - best-fit mapping, "voilà" -> "voila" = another file, a Move would act on it), and the narrow overload keeps the raw code-page bytes as if they were UTF-8. `SalWToU8Alloc` takes every UTF-16 text (WTF-8, feature 066), so the wide fallback is reached only on low memory; its comment ("invalid UTF-16") is out of date. Feature 259 removed the same fallbacks from `IsSimpleSelection`; these two were outside its item.

## Evidence

By reading at 16c7b517: `src/shellib.cpp:101-121` `CCopyMoveRecord::AllocChars(const wchar_t*)` (CP_ACP fallback), `src/shellib.cpp:82-99` `CCopyMoveRecord::AllocChars(const char*)` (raw bytes when `LegacyAToU8Alloc` fails). Found by the review of feature 259 (`specs/259-long-name-refusals/fix-log.md` *Review*, SHOULD 2, and *Limits left*).

## Expected

A failed conversion leaves the record without a name (NULL) and the caller refuses the operation (as for low memory - the caller already stops when a record cannot be created); no code-page or raw-byte name ever reaches the copy / move. The wide overload's comment says what really fails.

## Notes

Check the callers of `CCopyMoveRecord` (`ProcessClipboardData` wide / ANSI loops, the `mapA` / `mapW` map names) for how a NULL `FileName` / `MapName` is treated before changing - a NULL `MapName` means "no map name" today, so a failed map conversion must be told apart from "none".

## Log

- 2026-10-20 — created (source review:259)
- 2026-10-20 — moved to Next position 46
