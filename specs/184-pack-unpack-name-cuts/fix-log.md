# Fix log: 184 - external archivers' list names and the drop-unpack target: refused, never cut

Found by 183's review (older).

## Read (not driven: no external archiver is installed; drag & drop is not drivable here)

- The list files of the external archivers (pack `pack2.cpp`, unpack `pack1.cpp`, delete
  `pack2.cpp`): a name was copied with `lstrcpyn(namecnv, name, MAX_PATH)` - a long name was cut
  and the archiver got another file's name (unpack and delete; the pack route refused such a name
  later, review) - and the OEM branch fell back to an unbounded `CharToOem(name, namecnv)` that can
  be longer than the UTF-8 name (a CP932 lead byte in the bytes, U+FFFD under the UTF-8 code page):
  a stack overrun of `namecnv[MAX_PATH]` even with a name shorter than MAX_PATH.
- `UnpackZIPArchive` cut a drag & drop target with `lstrcpyn(path, tgtPath, MAX_PATH)` (every
  producer bounds it below MAX_PATH today - a guard for later callers).

## Work

- `src/pack1.cpp` `PackListName` (declared in `pack.h`): the list name whole or not at all - OEM by
  `SalU8ToOEM`, its legacy fallback bounded (code page -> UTF-16 -> OEM into the buffer); the three
  list builders refuse a name that does not fit with `IDS_PACKERR_PATH` ("Path to file too long").
- `src/fileswn7.cpp`: a drop target of MAX_PATH bytes or more is refused (`IDS_TOOLONGPATH`) with
  the function's cleanup.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0. 183's probe as a regression: 3 / 0
(`regress_183.txt`).

## Review

Independent refute-first review of the first version: the fileswn7 change sound; the pack change
rested on "the OEM form is never longer than the UTF-8 one", false on the `CharToOem` fallback -
taken (the bounded fallback), and the unpack and delete lists had the same pair - taken
(`PackListName` for all three). Recorded: the message names the relative name (line 363 shows
source\name); two older in-place `CharToOem` (`pack2.cpp` ~299 the source's short name, ~352 the
8.3 form).
