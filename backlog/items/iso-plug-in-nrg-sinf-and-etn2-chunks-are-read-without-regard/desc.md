---
title: ISO plug-in: NRG SINF and ETN2 chunks are read without regard to their size
type: bug
status: new
severity: 5
area: archives
source: review:340
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: [iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables]
depends-on: []
reason: -
---

# ISO plug-in: NRG SINF and ETN2 chunks are read without regard to their size

## Problem

The NRG (Nero) chunk loop of the ISO plug-in (`ReadNRGRoot`) relies on each chunk reader consuming
exactly its chunk; two readers do not:

- `readSINF` always reads 4 bytes, whatever the chunk's size: a SINF chunk of another size leaves the
  file position inside the chunk (or past it, for a smaller one), so the next chunk header is read from
  the wrong place and the rest of the track table is misread; a short read (end of file) is not checked
  and leaves the count uninitialised (feature 340 bounds the count where it is used, so this no longer
  reads past the track table, but the session layout is garbage).
- `readETN2` allocates `header->Size` bytes and then reads two 8-byte values at offsets 0 and 8 - past the
  buffer when the chunk is under 16 bytes (a heap over-read) - and adds one track per chunk, whatever the
  chunk's size (an ETN2 chunk of several 0x20-byte track entries lists only its first track; the existing
  item `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables` covers its wrong `End`).

## Evidence

- Review 1 of feature 340 (NOTEs 3 and 4, by reading), `specs/340-nrg-session-count/fix-log.md` section
  *Review*.
- At 2b3f0716: `src/plugins/uniso/nrg.cpp` `readSINF` (`file.Read(&count, sizeof(count), &read, ...)`, no
  `read` check, no skip of `header->Size - 4`); `readETN2` (`new BYTE[header->Size]`,
  `getLongLong(data + 0x08)`, one `AddTrack`); `ReadNRGRoot` (the chunk loop, no seek to the chunk's end
  after a known reader).
- Not measured: no image with such chunks was made.

## Expected

Every NRG chunk reader consumes exactly its chunk (the loop seeks to the chunk's end after each reader,
or each reader checks its size): a SINF chunk that is not 4 bytes, or cannot be read whole, is refused or
skipped and the listing marked incomplete; an ETN2 chunk is read as its whole number of track entries and
never past its buffer.

## Notes

- Feature 340 (session counts bounded by the track table) makes a wrong SINF count harmless to memory;
  this item is about reading the chunks themselves.
- The CUEX reader's size underflow is its own item (`iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge`).

## Log

- 2026-10-24 — created (source review:340)
