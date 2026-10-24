# Fix log - 339-uniso-hfs-fork-content

Backlog item `iso-plug-in-an-hfs-file-whose-data-is-compressed-or-only-in` - ISO plug-in: an HFS+ file whose
data is compressed or only in its resource fork extracts empty.

## Measurement before (main 75fc0f43, Debug x64, `build.cmd` up to date)

- Sites: `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory` (`fd.Size = dataFork.logicalSize`) and
  `CHFS::UnpackFile` (`fork = &rec.file->dataFork` only, `bFileComplete` stays TRUE for an empty data fork).
  Reached from Unpack (Alt+F9) -> `UnpackWholeArchive` -> `ExtractAllItems` -> `CUDFISO`/`CHFS::UnpackFile`,
  and from Copy (F5) / view of a single file -> `UnpackFile`.
- Seed: feature 332's `mkimg332.sh` (WSL Ubuntu, xorriso -hfsplus, `a/side.txt` hidden from ISO 9660 - only
  in the HFS+ part). Copies by `probe/img339.py` (side.txt's HFS+ file record): rsrc (content only in the
  resource fork), comp (UF_COMPRESSED 0x20 in the BSD owner flags + data in the resource fork), compin
  (UF_COMPRESSED, both forks empty), flag (UF_COMPRESSED, data fork kept), nomode (UF_COMPRESSED, file mode 0),
  both (resource fork beside the data fork), comp2 (side.txt and HFS+ top.txt compressed).
- Command (PowerShell, from the repository root; the draft lived in `%TEMP%\tc339work` then):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\339-uniso-hfs-fork-content\probe\result_before.txt -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\339-uniso-hfs-fork-content\probe\iso339_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"`
- Result `probe/result_before.txt`: PASS 12, FAIL 6 (9 RUN rows). H-RSRC / H-COMP / H-COMPIN: side.txt
  written EMPTY, no box, image DELETED (the content lost); H-FLAG: the data fork written, image deleted;
  H-SKIPALL: side.txt and top.txt written empty, image deleted; H-CANCEL: no box to cancel, image deleted.
  Controls H-OK / H-NOMODE / H-BOTH pass (every file, image deleted). Registry restored, identical hash.
- `BL verify` recorded.

## Decisions

See spec *Clarifications*: refuse (count as not extracted) instead of decompressing; a Skip / Skip all /
Cancel box per refused file (silent after Skip all); the decision as a pure rule; both-forks files unchanged
(Inbox); TN1150's uninitialised BSD information (file mode type bits 0) -> the flag is not read.

## Analyze

- Run 1: no CRITICAL / HIGH. MEDIUM C1 (FR-003's untouched existing target had no row) -> row H-EXIST added
  to T007; LOW U1 (symbolic link) -> a unit check in T003. MEDIUM C2 accepted: Copy (F5) and view of a
  single file reach the same `CHFS::UnpackFile`; the probe drives the whole unpack only (as 338).

## Implementation

- `src/common/salhfscatalog.h`: `SalHfsFileContentKind(rec, avail)` -> `SAL_HFSFILE_DATA / COMPRESSED /
  RESOURCE_ONLY / SHORT` (UF_COMPRESSED in byte 41 when the file mode's type bits are not 0; else empty data
  fork + non-empty resource fork; records under 248 bytes SHORT).
- `src/plugins/uniso/hfs.cpp` `CHFS::UnpackFile`: after the record checks, before the name / buffer /
  `SafeFileCreate`: not DATA -> `DialogError(BUTTONS_SKIPCANCEL, name, LoadStrU8(1062 | 1063), LoadStr(IDS_ERROR))`
  when `silent == 0` (Skip all sets `silent = 1`, Cancel -> `UNPACK_CANCEL`), else `UNPACK_ERROR`; nothing created.
- Strings `IDS_ERR_HFS_FILE_COMPRESSED` 1062, `IDS_ERR_HFS_FILE_RSRC_ONLY` 1063 (free slots of bundle 66,
  `uniso.rh2` / `lang/lang.rc2`).
- `saltests`: `TestHfsFileContent339`, 28,740 -> 28,761 checks, 0 failed. Mutants (header edited, rebuilt,
  restored byte-exact): flag never read 5 failed, file-mode check dropped 3, resource-fork rule dropped 4, flag
  read from byte 40 6, resource size read from the low half only 1. (First mutant attempt did not build: the
  PowerShell writer added a second BOM - fixed the writer, not a finding.)

## Measurement after

- Probe after (same command, `-Label after`), `probe/result_after.txt`: PASS 20, FAIL 0 (10 RUN rows incl.
  H-EXIST). H-RSRC / H-COMP / H-COMPIN / H-FLAG: one "Error" box with the new text, Skip: side.txt not written,
  image KEPT; H-SKIPALL: one box, side.txt and HFS top.txt not written; H-CANCEL: unpack stopped, image kept;
  H-EXIST: the user's side.txt stays OLD, no overwrite question; H-OK / H-NOMODE / H-BOTH as before.
- First after-run 13 / 7: every row's files and image were right, the box regex required "side.txt" in the
  window text - the dialog's file-name field is a `CStaticText` the probe cannot read. The regex now matches the
  caption 'Error' and the message (recorded in the probe header).
- Regression: `iso332_probe` 16 / 0 (`probe/regress_332.txt`), `iso333_probe` 20 / 0 (`probe/regress_333.txt`).
- Not driven: Copy (F5) / view of a single refused file (same `UnpackFile`; analyze C2).

## Translations

- Step 0: new ids 1062, 1063 (STRINGTABLE:4), none changed; `english_fallback` rows before: 0 in every language.
- Build, `build_langs.cmd --export-templates --module uniso`; dry run 2 unique gaps / ~228 chars per language
  (8 languages); merge `--formality prefer_more --budget 5648`: DeepL 1,936 characters, 0 validation failures.
- Read back: no informal register. Pins (`translations/ui-overrides.json`, `_feature_339`): cs 1062 and sk 1062
  ("nebude extrahován/extrahovaný" as string 1058), de 1063 ("entpackt" as 1054 / 1058), es 1062 / 1063
  ("fichero", "no será extraído" as 1058; DeepL dropped a full stop and left a space before the line break).
  Merge again (pins applied as human), `slt --verify` byte-exact (298 files), `build.cmd full` BUILD SUCCEEDED.
  Layout drift: none (only the two rows per `.slt` / `.origin` changed; "controls widened to fit: 24" are not
  written for this module's committed files).

## Checks

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `build.cmd` / `build.cmd full` -> BUILD SUCCEEDED; saltests 28,761 / 0.

## Inbox

- `iso-plug-in-an-hfs-file-with-data-and-a-resource-fork-loses` (decision, measure:339): the resource fork of a
  file that also has data is dropped while the image is deleted.
