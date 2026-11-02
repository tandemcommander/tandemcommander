# Closing report - 395-cpio-solo-empty-name
Backlog item: unpack-silently-drops-a-cpio-file-whose-only-name-normalizes - Unpack silently drops a cpio file whose only name normalizes to empty
Outcome: closed

## What changed

- `src/common/salcpiolink.h`: `SAL_EMPTY_NAME_SILENT / REPORT / PENDING`, `SalEmptyNameDataDecide`,
  `SalEmptyNamePendingCleared`, `SalCpioRepeatsLinkedData` (pure rules); `src/saltests/saltests.cpp`:
  `TestEmptyNameData395` (26 checks).
- `src/plugins/tar/untar.cpp`:
  - `ReadArchiveHeader`, "skip invalid names": `NameEmptyRegular` for a regular file (cpio by its
    mode, tar by its type); the binary c_dev / c_ino taken from the pre-read block;
  - `ReadOldASCIIHeader` / `ReadBinaryHeader`: device, inode and link count for odc / binary;
  - `DoUnpackArchive`: a member asked by its raw name (the mask) whose data reaches no extracted
    name is reported - at once (single name, tar), or at the end of the archive (a newc / crc group
    or an odc / binary file whose data passed unwritten; `cpioRepeats`, `ReportCpioEmptyLost`);
    the operation then fails (`refused`), so the archive is kept;
  - `WriteOutCpioGroupMember`: the pending loss of a group, settled by a later WRITE / COPY /
    REPORT;
  - `ReportEmptyName`: the system's "(123)" text + the raw name in quotes, once per operation.
- `src/plugins/tar/tar.h`: the new members and declarations.
- No UI string, dialog, plug-in interface or setting changed (no `.slt` refresh).

## Measurements (before / after, commands)

Probe `specs/395-cpio-solo-empty-name/probe/cpiosolo_probe.ps1` (fixtures `mkcpiosolo.py`) on the
hidden desktop (`tools\run_on_hidden_desktop.ps1`, Debug x64):

- before (main bb8aa693): PASS 22 / FAIL 10 (`result_before.txt`) - 9 data rows extracted only
  `ok.txt`, showed nothing and deleted the archive (the 10th: the probe's own Copy check, fixed).
- after: PASS 46 / FAIL 0 (`result_after.txt`, 23 RUN rows): 13 rows report "(123)" and keep the
  archive, 10 controls stay silent and the archive is deleted as asked.
- negative control (both report sites disabled): PASS 23 / FAIL 9 (`result_negctl.txt`) - exactly
  the 9 data rows; review 1's control with main's `tar.spl` failed the same rows.
- review 1's S1 reproduced before its fix (`result_review1_before.txt`): odc `.` + `a.txt` reported
  although `a.txt` got the data; after: silent.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- `.\build.cmd` -> BUILD SUCCEEDED
- `saltests.exe` -> 30839 checks, 0 failed (30813 at 394 + 26)
- feature probe 46 / 0; regressions 306 30 / 0, 308 12 / 0, 309 16 / 0, 310 52 / 0, 321 tar
  20 / 0, 321 unpack 12 / 0, 393 28 / 0, 394 22 / 0 (`probe/regress_*.txt`; 306 / 310 / 393 / 394
  again after the S1 fix)

## Reviews (findings and what was done)

- Review 1 (e3a27bda): no MUST. SHOULD S1 (odc / binary hard links reported although another name
  got the data) - fixed (reader fields, `SalCpioRepeatsLinkedData`, `cpioRepeats`). NOTEs: `x/..`
  (existing Next item `tar-member-name-with-dotdot-extracted-into-wrong-folder`), clang-format
  alignment (fixed), .deb may show the box per part (kept), coarse negative control (covered by
  the reviewer's).
- Review 2 (4e17495e): no MUST, no SHOULD. NOTE 1 (a truncated-inode collision in odc / binary
  counts as one file - accepted, a limit), NOTE 2 (the byte-swapped binary format is never
  detected - pre-existing, spec corrected, added to the Inbox item below), NOTE 3 (a declined
  overwrite of the other name is the user's choice - accepted), NOTE 4 (Inbox item committed with
  the closing).

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (no `## [Unreleased]` section exists in `CHANGELOG.md`; versions
  and sections are the maintainer's):

  - **Unpack deleted an archive whose file was stored under the name "." without a word** (feature 395).
    - **Before:** a TAR, cpio or rpm archive that stored a file's data only under a name such as `.`,
      `./` or an empty name (crafted archives) was unpacked without that file and without a
      message; with "Delete archive after unpacking" the archive - the only copy of the data - was
      deleted.
    - **Now:** a whole Unpack reports such a file ("The filename, directory name, or volume label
      syntax is incorrect" with the name in quotes), extracts the rest and keeps the archive. A
      `.` folder (as `find . | cpio -o` writes it), an empty file, and a file whose data another
      name of it receives stay silent as before.
    - **Limitation:** two different files of an old-format (odc / binary) cpio that share a
      truncated inode number count as one; the byte-swapped binary cpio format is not recognised
      at all.

No person-step item: every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `a-binary-cpio-member-in-the-last-512-bytes-of-the-archive-is` - A binary cpio member in the last
  512 bytes of the archive is not recognised
