# Research: 260 - archive cache long names, gzip name

## R1 - Which limit for the temporary copy?

- Decision: the whole path (cache folder + name) has at most `MAX_PATH - 1` (259) UTF-16 units.
- Rationale: viewers, editors, the shell and the archiver plug-ins open the copy through wide APIs
  without the `\\?\` prefix; 259 units is what they all take. The old rule counted UTF-8 bytes - a
  name of 90 CJK letters (94 units) failed at about 210 bytes.
- Alternatives: long-path support (`\\?\`) for every consumer - out of scope (every archiver
  plug-in, viewer, editor); shortening the temporary name - rejected for F4 (the copy is packed back
  under its disk name: a cut name would become a new member) and unnecessary for F3.

## R2 - Who gets the long mode?

- Decision: only the core's F3 (`CFilesWindow::ViewFile`-path in `fileswn5.cpp`) and F4
  (`ExecuteFromArchive` in `fileswn6.cpp`) of archive members.
- Rationale: the plug-in services (`src/zip.cpp` disk-cache callers) return the temporary path to
  plug-ins built against the interface, which may copy it into a 260-byte buffer; the User Menu
  batch name is short. Interface changes are maintainer-owned.
- Alternatives: change the rule for every caller - rejected (plug-in compatibility).

## R3 - Consumers of the longer path (enumerated)

- `CCacheData` stores `TmpName` with `DupStr` (heap) - fine; `CCacheData::GetName` copies only the
  folder part (`char dir[MAX_PATH]`, the cache folder is < MAX_PATH) - fine.
- `CCacheDirData::ContainTmpName` / `GetName` - `char tmpFullName[MAX_PATH]` -> heap.
- F3: `char tmpPath[MAX_PATH]` = folder part - fine; the viewer gets the UTF-8 path like a disk file.
- F4: `char buf[MAX_PATH]` = folder part - fine; `UnpackedAssocFiles.AddFile` stores heap strings.
- `CFileTimeStamps::CheckAndPackAndClear`: `char buf[2 * MAX_PATH + 100]` with `_snprintf_s
  _TRUNCATE` - a 259-unit path may have up to 777 bytes: it would be CUT and the change check would
  look at another path -> heap.
- `CFileTimeStamps::CopyFilesTo`: `char name[MAX_PATH]` + `SalPathAppend` refuses (message
  `IDS_TOOLONGNAME`) - it would refuse every long-name copy; the wide buffers `WCHAR[MAX_PATH]` are
  right for the shell call -> UTF-8 on the heap, "too long" when the wide path exceeds 259 units.
- Packing back: `PackCompress` gets the cache folder and the names - the same route as packing a
  disk file with a long name (F5 into an archive).

## R4 - gzip stored name

- Decision: read the ORIG_NAME bytes whole into a heap buffer bounded at 64 KiB (a header field
  without a limit; beyond the bound the name is "too long" and the rest is skipped); keep the
  existing "last part after '/'" and ':' -> '_' handling; after the decoding (`ConvertNameToU8`) a
  name over 255 UTF-16 units (`SalNameTooLongForFileSystemU8`, header-only `salmaskname.h`) makes
  `GetStreamHeader` refuse with `GetErrorText(ERROR_FILENAME_EXCED_RANGE)` under the "GZip Error"
  title - both the listing and the extraction go through it.
- Rationale: the item - "refused, never extracted under a cut name"; no new UI string.
- Alternatives: fall back to the archive's own name (what `gunzip` does without `-N`) - rejected:
  the item says refused, and a silent name change is a guess.

## R5 - Long folders inside archives

- Decision: no change. Every route reports (see spec *Measured before*).
