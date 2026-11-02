# Research - 393-cpio-long-name

Measured at af18dc21 (`main`), Debug x64.

## R1 - Where the cpio name escapes the check

- Decision: apply the existing refusal in `CArchive::ReadArchiveHeader` (`src/plugins/tar/untar.cpp`)
  also when the header was read by a cpio reader (`header.Format` is one of `e_NewASCII`,
  `e_CRCASCII`, `e_OldASCII`, `e_Binary`, `e_SwapBinary`), with the unchanged shared decision
  `SalPaxNameUsableU8(name, isDir, ListingPrefixLen, Listing)` (`src/common/salpaxheader.h`, saltests
  since 306 / 308 / 321).
- Rationale: all cpio formats end in `ReadCpioName` (names up to 10000 bytes) and pass the same
  normalization as tar names; the refusal block runs after the normalization, where the format is
  known. The rpm payload is a cpio read by the same `CArchive` (`CRPM` is a decompress stream).
- Alternatives: a new `NameFromCpio` flag set in `ReadCpioName` (one more field for a fact the
  format already tells); refusing in `ListArchive` only (would not cover extractions' 255-unit rule
  and the "asked for a refused member fails" rule of 308).

## R2 - A cpio folder is known by its mode, not by a trailing slash

- Decision: the `isDir` given to the check is `header.IsDir || (cpio && (Mode & CP_IFMT) == CP_IFDIR)`.
- Rationale: for cpio, `header.IsDir` is set from the mode only AFTER the refusal block ("now handle
  cpio"); GNU cpio writes folders without a trailing slash. With `IsDir` FALSE a nested folder whose
  own name is over the listing's 255 bytes (e.g. 100 CJK letters, 300 bytes) would not be refused
  and its `AddDir` would fail the whole listing again. At the top level the folder rule does not
  bound the name (321), so the order matters only inside folders.
- Alternatives: move the mode-to-type block before the refusal (changes the order for every
  format; more risk for no gain).

## R3 - A refused name that carries the data of a hard-linked file (newc / crc)

- Decision: a refused member stays a member of its (device, inode) group (`IsCpioGroupMember`
  accepts `NameRefused`), and `DoUnpackArchive` hands it to the group logic as *not asked*
  (`found && !NameRefused`); the refusal itself is reported by the existing 308 code
  (`ReportRefusedName`, the operation fails).
- Rationale: feature 310's group logic writes the data to a waiting asked name when the carrier is
  not asked (`SAL_CPIO_LINK_WRITE_FOR_WAITING`) and reports waiting names whose data was lost.
  Treating the refused carrier as `Ignored` would hide the data from the group: the waiting names
  would be written EMPTY at the trailer (`WriteOutCpioEmptyNames`) with success - a wrong file.
  `UnpackOneFilePass` already returns at a found refused member; a not-found one feeds
  `cpioDataSeen` / `UnpackOneCpioGroupName` through `IsCpioGroupMember`, which now sees it.
- Alternatives: leave it (wrong empty files in a rare case the fix itself makes reachable - before,
  the archive did not open at all).

## R4 - Probe

- Decision: a new probe `specs/393-cpio-long-name/probe/cpio393_probe.ps1` with the fixture writer
  `mkcpio393.py` (newc / odc writers and the rpm wrapper of 310's `mkcpio310.py`, the deep tree of
  321's `mkunp321.py`), built on `specs/321-tar-long-component/probe/unp321_probe.ps1` (Unpack and
  Copy rows) with a "(206) at opening" check.
- Regression: probes of 310 (cpio / rpm links), 321 (`tar321_probe`, `unp321_probe`), 306, 308, 309.
