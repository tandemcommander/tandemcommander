---
title: ISO plug-in: HFS+ names with an unpaired surrogate are changed to U+FFFD
type: bug
status: open
severity: 2
area: archives
source: measure:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [uniso-hfs-btree-trust-and-joliet-cut, uniso-joliet-file-names-wtf8-garbled]
depends-on: []
reason: -
---

# ISO plug-in: HFS+ names with an unpaired surrogate are changed to U+FFFD

## Problem

The ISO plug-in (UnISO) converts HFS+ names (UTF-16) to UTF-8 with a lenient
`WideCharToMultiByte(CP_UTF8, 0, ...)`, so an unpaired surrogate in a name becomes U+FFFD. The
listing shows a different name than the image holds, the file is extracted under that name, and
two names that differ only in their unpaired surrogates become one name (the second extraction
asks to overwrite the first). The Joliet and UDF readers of the same plug-in convert with the
WTF-8 `SplWToU8` first (feature 089); HFS+ was left out. (Joliet *file* names are then damaged by
`EnsureU8Name` - item `uniso-joliet-file-names-wtf8-garbled`; HFS+ does not call it.) The root
folder name (`GetRootName`) has the same conversion.

## Evidence

By reading, at e849e68c: `src/plugins/uniso/hfs.cpp` `CHFS::GetRootName` and the directory
listing loop below it (both `WideCharToMultiByte(CP_UTF8, 0, fileNameW, nameLen + 1, ...)`); for
comparison `iso9660.cpp` `ConvJolietName` and `udf.cpp` `DecodeOSTACompressed`. Reported by
`python tools/check_encoding.py --plugins` (`lossy-lenient-at-intake`, 2 lines); verdicts in
`specs/255-plugin-encoding-findings/verdicts.md` (branch `255-plugin-encoding-findings`).

## Expected

An HFS+ image holding `Lone<U+D800>.txt` lists and extracts that name unchanged (WTF-8 in the
program, the lone surrogate on NTFS); `check_encoding.py --plugins` no longer reports `hfs.cpp`.

## Approach

`SplWToU8` (`splunicode.h`) as in `iso9660.cpp`. The listing buffer holds 3 bytes per unit; the
root name buffer does not (`udfiso.cpp`, `char rootName[128]` for up to 255 units - a long
non-ASCII HFS+ volume name is refused and no label shown; review 2 of 255) - refuse or use a heap
buffer, never cut.
A fixture image needs a tool that writes HFS+ with an ill-formed name (or a patched image).

## Notes

macOS writes HFS+ names from valid Unicode, so such names come only from other tools or damaged
images; severity is low for that.

## Log

- 2026-10-20 — created (source measure:255)
- 2026-10-20 — set related=uniso-hfs-btree-trust-and-joliet-cut,uniso-joliet-file-names-wtf8-garbled
- 2026-10-20 — moved to Inbox
- 2026-10-20 — moved to Next position 85
