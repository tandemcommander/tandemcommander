# Data model - 395-cpio-solo-empty-name

- `SCommonHeader::NameEmptyRegular` (BOOL): the member's name normalizes to nothing and it is a
  regular file - cpio: `(mode & CP_IFMT) == CP_IFREG`; tar: the type was a regular file (not
  `Ignored`, not a folder, not a link) before the empty-name branch. Reset in `Initialize`. Set
  together with `Ignored` (and `NameEmpty` for cpio, 394).
- `CArchive::SCpioGroup::EmptyLost` (bool) / `EmptyLostName` (raw name): an asked empty-named
  carrier's data passed unwritten; cleared by a later `WRITE` / `COPY` / `REPORT` of the group.
- `CArchive::DoUnpackArchive`'s `cpioRepeats` (review 1): the odc / binary hard-linked files of
  the operation (`SalCpioRepeatsLinkedData`, key device + inode as `CpioGroupKey`; the readers now
  fill `CpioDevMinor`, `CpioIno`, `CpioNLink` for odc and binary): `State` WRITTEN once an asked name
  with data passed, `EmptyLost` / `EmptyLostName` as above.
- `CArchive::EmptyNameShown` (BOOL): the "(123)" box was shown in this operation.

Decisions (`salcpiolink.h`): `SAL_EMPTY_NAME_SILENT` 0, `SAL_EMPTY_NAME_REPORT` 1,
`SAL_EMPTY_NAME_PENDING` 2.
