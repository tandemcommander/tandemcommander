# Fix log: 211 - Disk Map never hands the shell another item's path

Backlog (left by 131): Disk Map's `CZFile::GetFullName` / `GetRelativeName` skip a path part that
does not fit and append the next - another item's path, handed to the shell menu.

## Measured (before)

The map scans with a 1,563-byte path buffer (`CZRoot::PopulateThreadProc`, `PopulateDir`: a
folder is listed while its path leaves room for one name), but the full name of an item is built
into 781-byte buffers (`GUI.DiskMapView.h`: the shell file menu and the default command). A part
that did not fit was skipped and the rest appended - for a file of a long name the FILE's name was
the part skipped, so it got its FOLDER's path.

Probe `probe/diskmap_long_probe.ps1` (143's driver: the map of the row's folder, a right press at
the middle selects the only big file, the keyboard's context-menu request opens the shell's file
menu, Delete is chosen and its confirmation read, then answered No), the build at 210
(`probe/result_before.txt`):
- **deep** (a folder chain of 687 bytes, a file of a 114-letter name - its full name 802 bytes):
  the file's Delete asked **"Delete folder - Do you want to PERMANENTLY delete this folder?
  cccc..."** - the whole folder holding the file, permanently (a path that long does not go to the
  Recycle Bin). Answered No; nothing deleted.
- ctl (a short folder, a file): Windows deleted exactly that file without asking (no confirmation
  is configured here) - the control row's criterion takes that as right.

## Work

`src/plugins/diskmap/DiskMap/`:
- `TreeMap.FileData.CZFile.cpp` / `.h`: `GetFullName` and `GetRelativeName` go through
  `GetNameAux`, which fails as a whole when any part does not fit: 0 and an empty buffer - never a
  path with a part missing;
- `GUI.DiskMapView.h`: no shell file menu (a beep) and no default command for such an item;
- `TreeMap.FileData.CZRoot.h`: the cluster size is not asked for a root whose name does not fit;
- (review) `GUI.ShellMenu.h`: the three conversions for the shell (file menu, folder menu, default
  command) by `SplU8ToW` (WTF-8) and never through `CP_ACP` - a name with a lone surrogate was
  read through the code page as other letters, the path of ANOTHER file (rule 104);
  `GUI.MainWindow.h` "Focus in Panel": the file menu's buffer, a beep when the name does not fit
  (its BOOL result was compared with `MAX_PATH`); `Utils.CZString.h`: the log names an item in a
  buffer of the scan's size (the "Path is too long." entries name exactly the items that do not
  fit 781 bytes); `GetNameAux` protected; the default command beeps too.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 4 / 0 (the final build): deep - no file menu (a beep), the file and its
folder kept; ctl as before. Regression: 143's Disk Map probe 34 / 0 (`probe/regress_143.txt`).

## Review

Refute-first review: accept - the bounds hold (the root is at most 779 bytes, every folder of the
tree at most 781, every item at most 1,547; the scan's own append cannot skip); every caller of
`GetFullName` / `GetRelativeName` checked: the file menu and the default command refuse, the
core's focus gets nothing for an empty name, the directory line's relative name always fits, the
rest is display. Taken: the `CP_ACP` fallback of the shell menu (older), "Focus in Panel"'s small
buffer and silent failure, the log's empty names (above). Decision kept: items whose full names
have 781-1,547 bytes get no shell menu - widening it would hand more over-`MAX_PATH` paths to
third-party menu handlers that cut them (a cut prefix can be another item). NITs recorded: the
tooltip's title and the icon / type lookups of such items are empty (display only); a folder of
exactly 781 bytes gets no file menu (its directory-line menu works); the default command and
F / Space on the deep item are not driven.
