# Research - feature 310

## R1 How cpio writers store hard links

- Decision: in newc (`070701`) and crc (`070702`) a file with several names is a set of members with
  the same `c_ino` and device (`c_devmajor`, `c_devminor`) and `c_nlink` > 1; the data is with one of
  them, the others have `c_filesize` 0. GNU cpio (copyout, deferred links), rpm, libarchive
  (`ARCHIVE_ENTRY_LINKIFY_LIKE_NEW_CPIO`), busybox and the kernel's `gen_init_cpio` all put the data with
  the **last** name. The reader handles the data with any name (first or last), as GNU cpio's copy-in
  and libarchive do.
- Rationale: measured with fixtures laid out this way; libarchive (`tar.exe`) lists them as links.
- Alternatives: group by name order or by `c_nlink` count reached - rejected: counting breaks when the
  archive holds fewer names than `c_nlink` (a partial archive), and order differs between writers.

## R2 odc / binary cpio

- Decision: unchanged. These formats repeat the data with every name (probe row CPIO-ODC-HARD-DEL
  passes before the fix); grouping is limited to newc / crc.

## R3 Where a symbolic link's target is

- Decision: the member's data (`c_filesize` bytes). It is read in `ReadArchiveHeader` right after the
  name (aligned) when the size is 1..4096 bytes, the header's size is then 0 so the data pass reads
  nothing; `Offset` counts the bytes so the 4-byte padding stays right. Larger (malformed) targets are
  not read: the box shows an empty target, the data is skipped as before.
- Alternatives: report without a target - rejected (feature 309 shows `name -> target`).

## R4 Writing the extra names

- Decision: feature 309's `WriteOutLinkCopy` (source opened read / share-read, `SafeFileCreate` for the
  destination, identity check so a destination that is the source is never truncated). The source is the
  path written for the group's data in this operation.
- Alternatives: NTFS hard links - rejected (feature 309's decision: works on every file system, never
  ties two of the user's files together).

## R5 The name holding the data is not asked for

- Decision: when an asked name waits and the data member is not asked, the data is written under the
  first waiting name (the header's name swapped for that member's name while writing, so the overwrite
  question and the progress name the file being written); the other waiting names are copied from it.
  When no asked name waits, the data is skipped; a later asked name stored with size 0 is then reported
  ("file not found", `name -> data name`), feature 309's rule for a link whose target was not written.

## R6 Single-file extraction (F3 / Enter)

- Decision: `UnpackOneFile` reads on past a found grouped name with size 0 to the member of the same
  group carrying data and writes it under the asked name; if no later member carries data, the name is
  written empty (an empty file), unless an earlier member of the group carried data (data-first layout,
  already passed - the stream cannot go back): then the member is reported and the operation fails.
- Alternatives: a second pass over the archive for the data-first layout - rejected as larger than the
  item for a layout no common writer produces; recorded as a limit.
