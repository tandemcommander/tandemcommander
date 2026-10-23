---
title: ISO plug-in: NRG audio track names are listed without cleaning or UTF-8 conversion
type: bug
status: new
severity: 4
area: archives
source: review:331
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: NRG audio track names are listed without cleaning or UTF-8 conversion

## Problem

An NRG (Nero) image's audio tracks are listed as `NN <CD-Text label>` with the label's bytes taken as
they are. Every other reader of the ISO plug-in has made names UTF-8 and safe since features 326 / 327
(`EnsureU8Name`, `MakeSafeName`), but this one does neither. A label `..\..\X` is listed as
`02 ..\..\X`, backslashes included. A Latin-1 label such as `Caf\xE9` (CD-Text's default character
set) is listed as invalid UTF-8, which breaks the core's WTF-8 rule for names (CLAUDE.md, 066).
Extracting audio tracks is refused ("Audio tracks cannot be extracted"), so nothing is written under
such a name. The panel still shows it, and Copy or Unpack uses it in its messages.

## Evidence

- `src/plugins/uniso/audio.cpp` `CAudio::ListDirectory` (at 0f19a673, feature 331's branch): the name
  is `SalNrgAudioTrackNameAlloc(Track + 1, label)` (`src/common/salnrgcdtext.h`); the label comes
  from `readCDTX` in `src/plugins/uniso/nrg.cpp` byte for byte. There is no `EnsureU8Name` /
  `MakeSafeName` call on that path (compare `iso9660.cpp` `MakeListedName`).
- Review 1 of feature 331 drove it on the hidden desktop with crafted NRG images (variants `bslash`
  and `latin1` of its scratch generator `img331.py`, under the reviewer's `%TEMP%\rev331\probe`, not
  kept in the repository): both images open and list "2 files", with the names shown as above.

## Expected

An audio track's listed name is made UTF-8 (CD-Text's ISO 8859-1 text converted, as the other readers
do for their names) and safe by feature 087's one-name rule (`SalArcCleanItemName`), before the
listing's rule decides. It is never cut.

## Notes

- Older than feature 331 (the reader never converted labels); found by its review.
- CD-Text may also declare other character sets (ASCII, MS-JIS) in its block info packs. The reader
  ignores the pack headers, so which character set applies needs a look at the format.

## Log

- 2026-10-24 — created (source review:331)
