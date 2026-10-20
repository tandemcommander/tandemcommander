# Research: 252 - 7-Zip, TAR and SFTP listings declare case sensitivity

## R1 - Always case-sensitive, or only with twins?

- **Decision**: 7-Zip and TAR: case-sensitive only when the listing holds case twins. SFTP: always.
- **Rationale**: the flag also makes typed archive paths case-exact. An archive without twins gains
  nothing from the flag; keeping it case-insensitive keeps today's behaviour there - a path typed in
  another case still works (stop-rules §1 step 4, constitution II). Corrected after review 252: an
  archive whose entries spell one folder in two cases ("Docs\a.txt", "DOCS\b.txt") has twins by this
  rule and is split into two folders just as "always" would split it - a known, visible change for
  such (rare) archives; no data is lost (each folder holds its own entries and extracts them).
  SFTP servers are file systems on which twins can appear at any time; the item names the exact SFTP
  site and FTP already declares it always.
- **Alternatives**: always case-sensitive (FTP style) for archives - rejected (changes every 7z/rar
  archive); by the host OS like ZIP's Unix rule - rejected (a 7z made on Windows from a case-sensitive
  folder holds twins without Unix attributes; RAR / tar host data not uniform).

## R2 - When to decide (one read of the archive)

- **Decision**: build with the flag set; after the listing, clear it unless twins exist.
- **Rationale**: the case-insensitive build merges folders "D" and "d" while adding - afterwards the
  twins are invisible; re-reading a compressed TAR doubles the listing time. Without twins the
  case-sensitive tree equals the case-insensitive one (merges only join equal names).
- **Alternatives**: collect all paths first and pre-scan (needs a copy of every item's data or a
  second pass); Clear + re-list like ZIP's Unix restart (a second read).

## R3 - Which "same name" rules

- **Decision**: twins = byte-different and equal by `SalNameOrderCompareCI` OR by the legacy byte
  fold `LegacyCompareCI`.
- **Rationale**: the core uses both on archive names when the flag is clear: `SalDirStrCmp` =
  `StrICmp` (legacy fold, ANSI code page per byte - in cp1250 "Ê" C3 8A and "Ú" C3 9A fold equal)
  while building the tree and comparing paths; `CNames` (`SalNameCompareOrdinalCI`) for selections,
  hidden names and the paste lookup. A pair equal by either rule is confused somewhere.
- **Alternatives**: one rule only - leaves the other confusion.

## R4 - Where the 7-Zip / TAR hooks go

- 7-Zip: `C7zClient::ListArchive` (used by the panel listing, `UnpackWholeArchive`, and every other
  listing of the plug-in). Extraction is by item index - unaffected.
- TAR: `CPluginInterfaceForArchiver::ListArchive` in `tardll.cpp` around `archive->ListArchive(NULL,
  dir)` - every `CArchiveAbstract` (tar, cpio, rpm, deb, single stream). `UnpackWholeArchive` of TAR
  does not build a tree (byte-exact name matching) - unaffected.
- The core keeps the flag across a panel refresh (`fileswn0.cpp` copies `GetFlags()`) and lists
  again through the plug-in on a real reload - the decision is re-made each listing.

## R5 - Measurement possibilities

- Fixtures: Python `tarfile` (TAR with A.txt / a.txt, D/x.txt / d/y.txt); `C:\Program Files\7-Zip\7z.exe`
  from a case-sensitive folder (`fsutil file setCaseSensitiveInfo`).
- Observable through the panel's case sensitivity: Hide Selected Names, Store / Restore Selection,
  then Copy (F5) into a case-sensitive target folder - which twins arrive.
- Not drivable here: the clipboard Paste route (no clipboard on the hidden desktop, needs the shell
  extension), SFTP (the test container is not running) - owed to a person.
