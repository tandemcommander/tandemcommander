# Fix log: 160 - drop and paste into an archive with a long name

Backlog: `specs/NEXT-WORK.md` item 12 (097's two refused routes).

## Reachability (by reading)

- **Clipboard copy FROM an archive** (`CSalShExtPastedData::ArchiveFileName[MAX_PATH]`) and paste
  of such data (into Explorer or a panel) need the shell extension (`salext*.dll`, the copy hook):
  it is **not shipped** (083 removed its registration) - unreachable in the product; not changed.
  Found while reading it, also unreachable while the extension is not shipped (recorded in
  NEXT-WORK): the copy hook is the code-page `ICopyHookA` (`shellext/copyhook.c`, the W hook is not
  exposed) and cuts the Explorer target at `MAX_PATH`; the core copies that target into
  `tgtPath[MAX_PATH]` (`mainwnd3.cpp`, the field holds `2 * MAX_PATH`) and `DoPasteOperation` into
  `pathBuf[MAX_PATH]` - a long or non-ASCII target folder would be cut / mis-read.
- **Drop or paste INTO an archive** (`CTmpDragDropOperData::ArchiveOrFSName[MAX_PATH]`, OLE drop
  target - no shell extension): reachable through an archive panel (plug-ins of interface 107 open
  such archives since 097) and a drop onto an archive file in a disk panel. Refused since 097
  ("The path specified is too long"). Not drivable here: an OLE drag needs a mouse, a paste the
  clipboard (both NOT DRIVEN on the hidden desktop, as in 097/119).

## Work

- `fileswnd.h`: `ArchiveOrFSName` a heap copy (constructor / destructor); `NameTooLong` only for the
  path inside the archive (still 259 bytes - 097).
- `shellsup.cpp` `DoDragDropOper`: `DupStr` of the name (low memory: the drop is dropped, traced).
- `fileswna.cpp` `DragDropToArcOrFS`: the two uses through the 620-byte `text` (the folder for the
  change notification, the error message) via `CSalHeapString`; **review:**
  `ArchiveNameFitsPacker160` asks the packer (external: refused at 260+; a plug-in: loaded and
  `PackArchiveNameFitsHandler` with its interface version) BEFORE the empty-archive handling.

## Review (refute-first agent, 2026-10-14)

No blocker. Taken over: (LOW, introduced) an empty archive of a 260+ byte name dropped onto in a
disk panel with an external packer was deleted and recreated (times, ACL, a hard link lost) before
the packer refused - the packer is asked first now. Recorded: low memory cancels the drop with a
trace only (pre-existing pattern); the struct owns a raw pointer with the implicit copy operations
(created with `new` and freed once - no copy exists). Confirmed: every other consumer takes the
name as a pointer or a heap string; no route cuts it (external archivers refused in
`PackUniversalCompress`, older plug-ins in `CPluginData::PackToArchive`, ZIP/7z/TAR take it - 097
drove adding up to 7,000 bytes).

## After

- Debug build clean; `check_encoding.py` TOTAL 0.
- Regression: 119 `packleft_probe` 104/0 (`probe/regress_packleft119_160.txt`); 097 `arcwork_probe`
  (archives of long paths; it drives no drop) 390/0, 21 n/a (`probe/regress_arcwork097_160.txt`,
  recorded after the commit).
- Owed to a person: drop files onto a ZIP of a 260+ byte path (an archive panel and a disk panel),
  and onto an empty `.rar` of such a path (refused, the file untouched).
