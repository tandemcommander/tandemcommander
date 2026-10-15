# Fix log: 240 - dragging a folder with a too long name into an archive says why

Backlog (228's review): in `DragDropToArcOrFS` (drag & drop / paste into an archive or plug-in FS)
`CSalamanderDirectory::AddDir` refuses a folder name over 255 bytes (222 - 86+ CJK letters); the
refusal ended the drop silently.

## Work (`src/fileswna.cpp`, by reading)

`AddDragDropItem` reports a folder refused for its length; the drop shows "Cannot finish operation
because of too long name" (`IDS_TOOLONGNAME`, the copy / move error title) before it ends. Only
folders: a disk file's name always fits `AddFile` (at most 765 bytes), so its failure is low memory
(silent, as before).

Not driven (drag & drop / clipboard). Build: BUILD SUCCEEDED.

## Review

Refute-first review: no MUST. Taken: the test for folders only (a long-named file's low-memory
failure would have shown "too long name"); comments. **Not covered here - the next item (241)**: a
too-long folder NESTED in a dragged folder, and F5 / Shift+F5 of such a folder into an archive, end in
`ReadDirectoryTree` (`fileswn7.cpp` ~1141 / 1325) with `SALENUM_ERROR` and no message - the ZIP
plug-in then most likely "succeeds" packing nothing. The message names no item (a new string would
be needed).
