# Fix log - 309-tar-link-members

Backlog item `tar-unpack-drops-hard-links-and-deletes-archive` (review:308).

## Measurement at f0187403 (main, before the feature)

- `.\build.cmd` (Debug x64) at HEAD -> up to date.
- New probe (scratch copy, now `probe/link309_probe.ps1` with fixture `probe/mklink309.py`, Python 3.14
  `tarfile`): `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine
  "powershell -NoProfile -ExecutionPolicy Bypass -File ...\link_probe.ps1 -Label before-main -Lib
  specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`
  -> `probe/result_before.txt`: **PASS 8 (7 END rows + UNP-HARD-TWIN-DEL), FAIL 6**:
  - UNP-HARD-DEL (a.txt, sub/c.txt, hard links sub/b.txt -> a.txt and ./sub/d.txt -> ./a.txt, Alt+F9 +
    "Delete archive after unpacking"): 2 of 4 files, no message, **t.tar deleted**.
  - UNP-HARD-PAX-DEL (PAX `linkpath` to CJK(40).txt; the ustar link name is the '?' fallback): 1 of 2, deleted.
  - UNP-HARD-GNU-DEL (GNU 'K' long link name to g*120.txt): 1 of 2, deleted.
  - UNP-HARD-MISSING-DEL (hard link b.txt -> missing.txt): silent, deleted.
  - UNP-SYM-DEL (symbolic link s.txt -> a.txt): silent, deleted.
  - COPY-HARD (Select All + Copy from the opened tar): 2 of 4 files, no message.
  - UNP-HARD-TWIN-DEL (hard link A.TXT -> a.txt): PASS (the link dropped; a.txt intact).
  - Registry restored, SHA-256 identical.
  - After the measurement, analyze E1 added a second symbolic link `t.txt` to UNP-SYM-DEL and the rule
    "exactly one box"; the row failed before for the silent deletion already.
- Reachability: Alt+F9 -> core unpack handler (`src/fileswn7.cpp`) -> tar
  `CPluginInterfaceForArchiver::UnpackWholeArchive` (`archiveVolumes->Add` before the unpack) ->
  `CArchive::UnpackWholeArchive` -> `DoUnpackArchive`; Copy -> `UnpackArchive` -> `DoUnpackArchive`.
  `ReadTarHeader` sets `Ignored` for LNKTYPE / SYMTYPE; the ustar `linkname` is never read, a GNU 'K'
  long link name is read and discarded, PAX `linkpath` is ignored by `salpaxheader.h`.

## Consumers enumerated (Grep in `src/plugins/tar`)

- `DoUnpackArchive`: `UnpackArchive` (Copy, drag and drop), `UnpackWholeArchive` (Alt+F9),
  `deb/deb.cpp` (control and data parts, results ANDed).
- `ReadArchiveHeader`: `ListArchive`, `UnpackOneFile`, `DoUnpackArchive`; also cpio formats (LinkType
  stays 0 for them).
- `WriteOutData`: `ListArchive` (simulate), `UnpackOneFile`, `DoUnpackArchive`.
- `SalPaxValues` / `SalPaxApply` / `SalPaxClear`: `untar.cpp` (GlobalPax, CSalPaxValuesHolder), saltests.
- `ConvertNameToU8`: `ReadArchiveHeader`, `fileio.cpp` (gzip original name).

## Analyze

- Run 1: CRITICAL 0, HIGH 0. E1 MEDIUM (one box per operation not probed) fixed - UNP-SYM-DEL has two
  symbolic links and needs exactly one box. C1 MEDIUM (archives with symbolic links now end as failed -
  a behaviour change) recorded in spec Assumptions, for the CHANGELOG. E2 LOW (target skipped at an
  overwrite question not probed - the same "not written" path as UNP-HARD-MISSING-DEL) and U1 LOW (a hard
  link naming a folder is reported because folders are not recorded) accepted.
- Run 2: no CRITICAL / HIGH / MEDIUM.

## Change

- `src/common/saltarlink.h` (new): `SalTarNormalizeNameU8` - the name normalization loop moved unchanged
  from `CArchive::ReadArchiveHeader` (member names and link names use one rule); `SalTarLinkDecide`
  (hard link + target written -> copy; hard link otherwise -> report "not found"; symbolic link -> report
  "not supported"; anything else -> none).
- `src/common/salpaxheader.h`: `SalPaxValues::LinkPath` / `LinkPathState`, the `linkpath` keyword handled
  as `path` (empty cancels, NUL refuses), freed by `SalPaxClear`; `SalPaxEffectiveLinkPath`.
- `src/plugins/tar/precomp.h`: `<string>`, `<unordered_set>` before the Debug `new` macro.
- `src/plugins/tar/tar.h` / `untar.cpp`:
  - `SCommonHeader::LinkType` / `LinkName` (reset by `Initialize`). `ReadTarHeader`: a GNU 'K' long link
    name is kept (it was read and discarded), a PAX `linkpath` beats it, else the ustar `linkname` (100
    bytes, terminated here); LNKTYPE / SYMTYPE stay `Ignored` (listing unchanged). `ReadArchiveHeader`
    decodes (`ConvertNameToU8`) and normalizes the link name like the member name; a member whose name
    normalizes to nothing keeps no link type (stays without effect, as before).
  - `WriteOutData(..., BOOL* written)`: TRUE when a file was created and closed.
  - `DoUnpackArchive`: a set of the archive names written by this operation (files and reproduced
    links; out of memory = not recorded = the link is reported). A link member asked for (mask /
    selection) and not refused by 306/308: per `SalTarLinkDecide` - `WriteOutLinkCopy`, or
    `ReportLinkMember` + `refused` (the operation returns FALSE after the rest, the core keeps the
    archive). Its `WriteOutData` (advance only) runs without the "Skipping" progress line.
  - `WriteOutLinkCopy`: the source (the file written earlier) opened `GENERIC_READ`, share `FILE_SHARE_READ`
    only; an existing destination that `SalFileIdMatch` says is the source -> nothing written, counted as
    reproduced; otherwise `SafeFileCreate` (overwrite question / Skip / Cancel as for every member, the
    shown size is the source's), copy, the member's time and attributes; an incomplete copy is deleted;
    a source that cannot be opened is reported and refuses the operation.
  - `ReportLinkMember`: `GetErrorText(err)` + blank line + `name -> link name`, whole (heap), title
    "TAR Plugin Error", once per operation (`LinkReportShown`).
  - `UnpackOneFile`: a link member asked for is reported and fails (unreachable from the listing).
  - `MakeFileInfo(..., const CQuadWord* size = NULL)`.
- `src/saltests/saltests.cpp`: `TestTarLink309`, 31 checks (normalization incl. `./`, `//`, `/abs`,
  `../../empty`, trailing separator, UTF-8 bytes; linkpath precedence / cancel / NUL / independence from
  path / last record wins; the decision table).
- Trap met: a Bash here-document inserting the tests collapsed doubled backslashes and the `\x..` escapes (CLAUDE.md 123);
  rewritten from a script file made with the editor, checked with `cat -A`.

## Checks after the change

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (C4267 only on the unchanged `NameLen = strlen(...)` lines, as in 308).
- `saltests.exe` -> `saltests: 27201 checks, 0 failed` (27170 before, +31).
- Probe `link309_probe.ps1 -Label after` -> `probe/result_after.txt` **PASS 14, FAIL 0** (before 8 / 6):
  UNP-HARD-DEL 4/4 nothing asked, t.tar deleted; UNP-HARD-PAX-DEL 2/2; UNP-HARD-GNU-DEL 2/2;
  UNP-HARD-MISSING-DEL ok.txt, one box "(2) ... b.txt -> missing.txt", t.tar KEPT; UNP-SYM-DEL a.txt,
  one box "(50) ... s.txt -> a.txt" (two symbolic links), t.tar KEPT; UNP-HARD-TWIN-DEL a.txt 'A',
  nothing asked, deleted; COPY-HARD 4/4. Registry restored identical.
- Regressions: 308 probe `probe/regress_308.txt` 12 / 0; 306 probe `probe/regress_306.txt` 28 / 0.

## Negative controls (sources restored byte for byte afterwards - `cmp` with the saved copy - rebuilt, re-measured)

- (A) `refused = TRUE` removed from both report branches of `DoUnpackArchive` + (B) `IsNameWritten`
  always false -> `probe/result_negctl.txt` PASS 7 (END) / FAIL 7: every hard-link row misses its copies
  (B, a "(2)" box instead), UNP-HARD-MISSING-DEL and UNP-SYM-DEL delete t.tar (A), UNP-HARD-TWIN-DEL shows
  a box, COPY-HARD 2/4.
- (C) the identity check of `WriteOutLinkCopy` disabled -> `probe/result_negctl_identity.txt`
  (`-Only UNP-HARD-TWIN-DEL`) FAIL: an overwrite question and the "(32) ... used by another process"
  box from `SafeFileCreate` (the share-read-only source handle refused the write) - a.txt still 'A'
  (the second guard holds), the archive kept.
- Restored build: `probe/result_after_restored.txt` PASS 14 / FAIL 0.

## Left as is (outside the item)

- Link members are still not listed in the panel (the item asks about extraction).
- cpio archives (also read by the plug-in): symbolic links in cpio stay skipped silently - not a tar
  link member; Inbox item (measure:309).
- A hard link whose target was overwritten later in the same operation by another member of the same
  name copies what is on disk then (as a real hard link would show).
