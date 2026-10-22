# Fix log - 310-cpio-link-members

Backlog item `cpio-unpack-drops-links-and-may-delete-archive` - "Unpacking a cpio or rpm leaves links
out silently and may delete the archive".

## Measurement before the fix (47eb6b83, `main`)

- `build.cmd` (Debug x64): BUILD SUCCEEDED.
- Fixtures `probe/mkcpio310.py` (Python 3.14): newc / crc / odc cpio laid out as GNU cpio and rpm write
  them; `C:\Windows\System32\tar.exe -tvf` (libarchive) lists them as intended (hard links shown as
  `link to a.txt`, symlinks as `-> a.txt`).
- Probe `probe/cpio310_probe.ps1` on the hidden desktop
  (`tools\run_on_hidden_desktop.ps1 ... -Label before`) -> `probe/result_before.txt`:
  **PASS 13 / FAIL 7**, registry restored and identical.
  - FAIL CPIO-HARD-DEL / CPIO-CRC-HARD-DEL: `a.txt`, `sub/b.txt` empty, archive deleted, no word.
  - FAIL CPIO-HARD-FIRST-DEL: `b.txt` empty. FAIL CPIO-HARD-DEV-DEL: `a.txt` empty.
  - FAIL CPIO-SYM-DEL: no box, archive deleted.
  - FAIL COPY-CPIO-ALL (`a.txt`, `sub/b.txt` empty), COPY-CPIO-ONE (`a.txt` empty).
  - PASS (controls): CPIO-HARD-EMPTY-DEL, CPIO-ODC-HARD-DEL, CPIO-FIFO-DEL.
- Reading: `ReadArchiveHeader` marks every non-regular cpio member `Ignored`; `ReadNewASCIIHeader`
  reads neither `c_ino` nor `c_nlink` nor the device; rpm is the same reader (`CRPM` is a stream;
  `CpioDoUnpackArchive` / `CpioUnpackOneFile` are declared in `tar.h` and defined nowhere).

## Consumers (enumerated)

- `CArchive::DoUnpackArchive` <- `UnpackArchive` (F5 Copy / drag from the opened archive) and
  `UnpackWholeArchive` (Alt+F9 Unpack, the core's "Delete archive after unpacking" acts on its result),
  both from `tardll.cpp`; `CDEBArchive` delegates to tar archives only (no cpio inside a .deb).
- `CArchive::UnpackOneFile` <- `CPluginInterfaceForArchiver::UnpackOneFile` (F3 / F4 / Enter through
  the disk cache).
- `CArchive::ListArchive`: unchanged (symlinks stay unlisted, grouped names listed with their own size).
- `ReadArchiveHeader` is shared by tar and cpio; the new code is guarded by the cpio formats.

## Analyze

- Round 1: one HIGH (F1 - FR-007 against research R6 on the data-first layout) - fixed in spec.md
  (FR-007 qualified, out-of-scope line). Round 2: no CRITICAL / HIGH.
- Accepted LOW: C1 (FR-008 checked by the encoding guard and the review); T1 ("waiting name" wording).

## Implementation

- `src/common/salcpiolink.h` (new, header-only): `SalCpioIsLinkGroupMember` (newc / crc, regular file,
  `c_nlink` > 1) and `SalCpioLinkDecide` (the table of `data-model.md`). saltests `TestCpioLink310`
  (+26 checks).
- `ReadNewASCIIHeader` reads `c_ino`, `c_nlink`, `c_devmajor`, `c_devminor` **silently** (`CpioHex8`):
  using `TxtToLong` would have shown a message and refused an archive with a non-hex field the reader
  never needed before - such a member now stays ungrouped (decided while writing it; compatibility).
- `ReadArchiveHeader`: a cpio `CP_IFLNK` member gets `LinkType = SYMTYPE` and its target (its data,
  1..4096 bytes) as `LinkName`; the bytes are counted in `Offset` (padding stays right) and the size set
  to 0. Feature 309's code in `DoUnpackArchive` then reports it (`ERROR_NOT_SUPPORTED`).
- `DoUnpackArchive`: grouped members go through `WriteOutCpioGroupMember` (map key (dev, ino) ->
  state / written target / data name / waiting names). Copies through feature 309's `WriteOutLinkCopy`;
  `FinishCpioWaiting` copies or reports the waiting names after the data member; at the trailer and at
  the end of data `WriteOutCpioEmptyNames` writes the names of groups that never carried data as empty
  files (a header with format "unknown" - no data, no padding read). Every `std` operation is guarded;
  out of memory shows the message and fails (fail closed, never an empty file).
- Trap met: `UnpackOneFile` passes `header.FileInfo.Name` as the target name, which the next
  `ReadArchiveHeader` frees - `UnpackOneCpioGroupName` copies it first (found while writing, before
  the first build).
- `UnpackOneFile`: a found grouped name with size 0 reads on (`UnpackOneCpioGroupName`); a group whose
  data passed earlier in this pass (data-first layout) -> reported ("(2)", `b.txt -> a.txt`), FALSE.

## Checks after the fix

- `build.cmd`: BUILD SUCCEEDED (the C4267 warnings at `untar.cpp` `NameLen = strlen` lines are
  pre-existing).
- `saltests.exe`: `saltests: 27237 checks, 0 failed` (27,211 before + 26).
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- Probe, with rows VIEW-CPIO-PLAIN (control), VIEW-CPIO-ONE, VIEW-CPIO-FIRST added:
  `probe/result_after.txt` **26 PASS / 0 FAIL**, registry restored and identical.
  CPIO-SYM-DEL: one box `(50) ... s.txt -> a.txt`, `t.cpio` kept. VIEW-CPIO-FIRST: one box
  `(2) ... b.txt -> a.txt`, no cached copy.
- The "Debug note: monitored handles" on the F3 rows appears for the plain control row too
  (`probe/result_view_control.txt`) and in features 095 / 097's pre-fix results: the core's viewer path,
  not this change.
- Negative control (grouping off - `IsCpioGroupMember` returning FALSE - and the symlink type not set):
  `probe/result_negctl.txt` **17 PASS / 9 FAIL** - exactly the 7 rows that failed before plus the two
  F3 rows (an empty cached copy). Source restored, rebuilt, probe re-run (26 / 0 above).
- Regressions: `probe/regress_309.txt` 16 / 0, `regress_308.txt` 12 / 0, `regress_306.txt` 28 / 0 (as
  recorded by those features).
- clang-format: `salcpiolink.h`, `untar.cpp`, `precomp.h` clean; the new saltests block formatted with
  `--lines`; the remaining drift in `tar.h` / `saltests.cpp` is pre-existing.

## Limits

- The panel listing is unchanged: names stored with size 0 show size 0; symbolic links are not listed.
- Viewing (F3) a name whose data is stored with an EARLIER name of the file is reported, not shown (no
  common writer produces that layout; Unpack / Copy handle it).
- rpm is the same reader; no rpm fixture was run (the payload is a newc cpio behind `CRPM`).
- odc / binary cpio: unchanged (they repeat the data with every name).
