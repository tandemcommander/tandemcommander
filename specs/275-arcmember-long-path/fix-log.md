# Fix log: 275 - F3 / F4 of archive members whose path inside the archive has 520+ bytes

Backlog item `f3-f4-refuse-archive-members-whose-path-inside-the-archive` (source leftover:260).

## Measured at HEAD (66245537, on `main`, before the feature)

- `.\build.cmd` (Debug x64, up to date), then on the hidden desktop
  `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` -> 16 PASS / 0 FAIL
  (`%TEMP%\tc275scratch\result_260_at_head.txt`). Row ARCCAP: a ZIP member of 200 CJK letters +
  `.txt` (604 bytes / 204 units) - F3: "Unable to unpack file from archive to temporary directory
  because resulting filename is too long." although the temporary path (about 249 units) fits
  feature 260's rule. The defect is present.
- Sites (Grep `2 \* MAX_PATH` / `IDS_UNPACKTOOLONGNAME`): `src/fileswn5.cpp` `ViewFile` (F3)
  `strlen(dcFileName + dcKeyLen + 1) >= 2 * MAX_PATH`; `src/fileswn6.cpp` `ExecuteFromArchive`
  (F4 / Enter) `strlen(nameInArchive) >= 2 * MAX_PATH`. These are the only two callers of
  `PackUnpackOneFile` (`src/pack1.cpp`).
- Bound of the input: `CSalamanderDirectory::AddFile` / `AddDir` (`src/zip.cpp`) refuse a path part
  over `MAX_PATH - 5` bytes and a name over 255 UTF-16 units -> a path inside the archive has at
  most about 251 + 1 + 765 bytes.
- Plug-in interface: every loaded plug-in is built for >= 104 (<= 103 refused at load); 104's
  promise is name components of 3 * 255 bytes and long paths; F5 hands such names to archivers
  since 222. Lifting the core test changes no interface.

## Consumers enumerated (fix protocol)

`PackUnpackOneFile` -> plug-in route `CPluginData::UnpackOneFile` (`plugins1.cpp`, no limit; only
the archive-name check of 097) -> `CPluginInterfaceForArchiver::UnpackOneFile` of the plug-in; or
the external-archiver route (`pack1.cpp`): `PackExpandCmdLine` into `cmdLine[PACK_CMDLINE_MAXLEN]`
(1040 bytes) - `ExpandVarString` refuses with "Expanded string is too large." + IDS_PACKERR_CMDLNERR;
the move target is on the heap. No cut.

Audit of the archivers' `UnpackOneFile` (independent agent, by reading):

| plug-in | 700 bytes | site |
|---|---|---|
| ZIP | works (stored name compared in a 64 KiB heap buffer; target on the heap) | - |
| 7-Zip | works (member by index; `nameInArchive` unused; heap target, refusing append) | - |
| tar / deb / rpm / cpio / streams | works (`strcmp` against heap names; GNU long names up to 10000 bytes) | - |
| uniso | works (heap `CU8PathBuf`, refusing `SalPathAppend` + message) | - |
| uncab | works (at most 765 bytes reach it) | `rootDir[U8_MAX_CAB_NAME]` + `lstrcpyn` = a silent cut at 769+ (hardening, FR-003) |
| unrar (off) | overflows already at 260+ | Inbox item exists (`unrar-plug-in-a-member-name-over-259-bytes-overflows-a-stack`) |
| unchm (off) | overflows already at 260+; a refused join reports success | -> new Inbox item |
| unole / unmime / demoplug (off) | no length issue reachable | - |

Found on the way (not this item): the tar plug-in ignores PAX `x` / `g` headers in the listing
(`untar.cpp`) - a long PAX path is listed under the ustar fallback name -> to verify, Inbox item.
The uniso listing builds paths in `char path[4 * MAX_PATH + 2]` with unbounded `strcat` - only
reachable if the core's listing ever accepted folder parts over 255 bytes (noted in the contract).
