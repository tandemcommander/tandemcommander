# Fix log: 223 - the ISO plug-in checks the lengths an image gives; Rock Ridge names are read whole

Backlog (found by 222's review): `uniso` `hfs.cpp` copies an HFS+ catalog name into
`wchar_t fileNameW[256]` up to a length read from the image; `iso9660.cpp` Rock Ridge parsing with
an entry length under 5 made `strncat` unbounded (a length of 0 looped).

## Work (defensive; checked by reading and by valid images)

`src/plugins/uniso/`:
- `hfs.cpp`: a catalog name over the 255 units of its structure is skipped (`GetRootName`,
  `ListDirectory`);
- `iso9660.cpp` `ExtractExtFileName`: a whole entry header inside the record; an entry shorter than
  its header or past the record ends the parsing; NM parts appended only while they fit; the ST
  terminator ends an area; (first review) the record's end was computed one byte short - fixed
  (it would have dropped the Rock Ridge name of many valid images);
- `iso9660.cpp` `ListDirectoryRe`: a record must lie inside the data read and hold its name;
  (review) the earlier safety check frees the data it returns from;
- `iso9660.cpp`: a Rock Ridge name that goes on in a continuation area (CE) is read from there
  (within one sector, at most 8 hops) - measured: a file of a 200-letter name was listed and
  extracted as 146 letters (also on the code before this feature); when the name cannot be read
  whole the plain ISO 9660 name is used, never a cut one; (second review) the area is read only
  while the name is not yet whole.

Not driven with a damaged image (owed: a fuzzing pass - not done here).

Build: BUILD SUCCEEDED.

## Measured

Probe `probe/iso223_probe.ps1` (valid images only): ISO-F5 - an IMAPI2 image (ISO 9660 + Joliet),
`top.txt` extracted; RR-LONG - a `genisoimage -R` image (made in a throw-away Debian container) with
a 200-letter name, extracted under the whole name. Before (`probe/result_before.txt`, the original
uniso): RR-LONG FAIL - extracted as 146 letters. After (`probe/result_after.txt`): 4 / 0.

## Review

First review: rejected - the record end one byte short (above, fixed). Second review: accept - the
CE fields and the block conversion as the directory extents, the area bounds within the sector,
the CONTINUE flag, ST, padding. Taken: hop only for an unfinished name; the leak of the earlier
check. Recorded in `specs/NEXT-WORK.md`: the HFS+ B-tree loader (`hfs.cpp` ~676-715, 454) trusts
the image's node numbers, links and record offsets (out-of-bounds reads, a link cycle loops while
memory grows); Joliet file names cut at their UCS-2 byte length (`iso9660.cpp` `lstrcpyn(fileName,
src, LengthOfFileIdentifier + 1)` - mostly-CJK names).
