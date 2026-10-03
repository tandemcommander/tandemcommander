# Implementation Plan: moving into an archive never deletes files behind a link

**Branch**: `099-move-into-archive-links` (from `098-long-path-overruns`) | **Spec**: [spec.md](spec.md)

1. Inventory (reading): every route from a disk panel into an archive or a
   plug-in file system that deletes the sources afterwards - F6 into an
   archive panel (`fileswn*` copy/move to archive), drag and drop with Move
   (`fileswna.cpp` around `PackCompress(..., move, ...)`), the Pack dialog
   (scanned since Open Salamander, fail-closed since 098), moves into plug-in
   file systems (who deletes the sources and how the files are enumerated).
2. One shared check: the silent scan of `CFilesWindow::Pack` (098) moved into
   a helper used by every route; "link found or not everything checked" ->
   the existing link warning, and the route does what the warning says
   (cancel, or copy without deleting).
3. Probe on the hidden desktop: F6 of a folder holding a junction, of the
   junction itself, of a selection with an unreadable folder, and of a plain
   selection, into ZIP and 7z; the build before the fix as the control
   (`build\tandemcommander\Debug_x64_pre099`).
4. Independent review; gates (Debug + Release, saltests, guard, probes of
   095-098); records; commit.
