# Fix log: 228 - drag & drop (or paste) into an archive lists the whole source folder

Backlog (found by 222's audit): `CFilesWindow::DragDropToArcOrFS` (`fileswna.cpp:396`) copies the
source folder (`SrcPath`, `SAL_MAX_PATH_UTF8` bytes) into `char path[MAX_PATH + 10]` with
`lstrcpyn(..., MAX_PATH)` and lists `path\*` to collect the dragged items' data (sizes, times,
attributes - the directory and link flags included) into the list the operation works with.

## Read (not driven)

The route needs a real OLE drag & drop (`shellsup.cpp` ~170-217 posts `WM_USER_DROPTOARCORFS`) or
the clipboard (Ctrl+C in a deep folder, Ctrl+V into an archive panel: `ClipboardPasteToArcOrFS`,
`fileswn9.cpp:513/547`) - neither exists on the hidden desktop: a step owed to a person.

What the cut did, for a source folder deeper than 259 bytes (cut by bytes):
- inside a component, no such folder: "Cannot read directory" naming the cut path - nothing done;
- at a component's end: an ancestor folder listed; a sibling whose name starts the same
  ("...\Projekt" for "...\Projekt - kopie") - the most realistic case: every dragged name found
  there, no question asked, and the items' data taken from the other folder. The content packed
  was right (every consumer gets the whole `SrcPath` since 098), but **the link flag the 099 check
  reads came from the other folder: a junction among the dragged items, a plain folder of that name
  in the other one - a Move into a ZIP passed the check and deleted what lies behind the junction**;
  a wrong directory flag only made the operation fail; sizes and times are cosmetic. External
  archivers refuse such a source anyway (`PackUniversalCompress`, 098); plug-in archivers (ZIP, 7-Zip,
  TAR) and plug-in file systems were exposed.

## Work

`src/fileswna.cpp`: the listing uses a `CSalMaxPathBuffer` holding the whole `SrcPath` ("\*" that
does not fit: refused "too long", unreachable in practice); the "Cannot read directory" messages are
built on the heap (`CSalHeapString::Printf`) since the path in them may now be long. Drag & drop and
paste now behave like F5 / F6 from such a folder.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Review

Refute-first review: no MUST. Taken: the consequences above corrected (my first note claimed the
old message could overrun its buffer - it could not, the cut path was at most 259 bytes; and "the
parent" - an ancestor or a sibling), the paste route named, the refusal's title (Copy / Move error
as the function's other refusal). Older defects recorded in `specs/NEXT-WORK.md`: **a duplicate
case-insensitive match (a case-sensitive folder holding a.txt and A.txt) overruns `nameFound` and
packs or moves the unselected file too** (`fileswna.cpp` ~465 / 585); a folder name over 255 bytes
makes the operation end silently (`AddDir` refuses, 222); the FTP upload's link size from a cut path
(`fs5.cpp:1149`); `IsSimpleSelection`'s too-long message and code-page fallback (`shellib.cpp`
~497-510).
