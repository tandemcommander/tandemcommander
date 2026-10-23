---
title: Check ISO Rock Ridge names in a Shift-JIS image on a Japanese-locale Windows
type: person-step
status: new
severity: 4
area: archives
source: leftover:326
who: person
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: [iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe]
depends-on: []
reason: -
---

# Check ISO Rock Ridge names in a Shift-JIS image on a Japanese-locale Windows

## Problem

Feature 326 makes Rock Ridge names safe for Windows (`SalSuspCleanRockRidgeName`). Its review 2
found that cleaning the raw bytes changed legacy Shift-JIS names: a second byte 0x5C or 0x7C belongs
to a letter, and turning it into `_` gave another letter (`ソフト.txt` -> `ダフト.txt`). Feature
326 now cleans the UTF-8 name after the code page conversion (`CISO9660::MakeListedName`). This
machine runs code page 1250, so the fix could not be driven on a Japanese system; it was proven by
reading the code and the reviewer's byte simulation only.

## Evidence

- `specs/326-uniso-rrip-without-rr/fix-log.md`, section *Review*, review 2 (fourth launch), S1;
  the reviewer's simulation `%TEMP%\rev326e\sjis.py` (not kept in the repository).
- `src/plugins/uniso/iso9660.cpp` `CISO9660::MakeListedName` (`EnsureU8Name`, then the cleaning).

## Expected

On Windows with the system locale (language for non-Unicode programs) Japanese, the Rock Ridge
names of a Shift-JIS image are listed and extracted with their own letters; a name with a real
`\` or `:` is still renamed with `_`.

## Steps

- [ ] On Linux, make an image whose Rock Ridge names are Shift-JIS bytes, for example:
      `mkdir src && printf 'S' > "src/$(printf '\x83\x5c\x83\x74\x83\x67').txt" && printf 'C' > 'src/a:b.txt' && genisoimage -R -input-charset sjis -o sjis.iso src`
      (or xorriso with `-in_charset SJIS -out_charset SJIS`) - expected: the image holds the names
      `ソフト.txt` (bytes 83 5C 83 74 83 67) and `a:b.txt`.
- [ ] On Windows set *Language for non-Unicode programs* to Japanese (restart), open `sjis.iso` in
      Tandem Commander - expected: the panel shows `ソフト.txt` (not `ダフト.txt`) and `a_b.txt`.
- [ ] Copy both files out with F5 - expected: `ソフト.txt` with content `S`, `a_b.txt` with `C`,
      no overwrite question, nothing outside the target folder.
- [ ] Set the locale back.

## Log

- 2026-10-23 — created (source leftover:326)
