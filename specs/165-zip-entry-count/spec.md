# Feature Specification: a ZIP archive of 65,535 entries or more gets the right count

**Feature Branch**: `165-zip-entry-count`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: found by the review of 164 (NEXT-WORK item 15): the ZIP plug-in keeps the entry counts
in the 16-bit fields of the end of central directory record.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user packs a large folder (70,000 files) into a ZIP archive, adds files to an archive of
65,000, or deletes files from an archive of 70,000 or more. Before, the archive's end record
gave a wrong number of entries (4,464 for 70,000; 464 for 66,000; 30,535 for 35,000) - a program
that trusts it lists a fraction of the files. Now the count is right, and 65,535 or more are in a
zip64 end record (APPNOTE 4.4.21-22).

**Independent Test**: `probe/zip_count_probe.ps1` (`zipcount.py` reads the end records and walks
the directory; Python's zipfile reads every archive), saltests `TestZipCount165`.

## Requirements *(mandatory)*

- **FR-001**: The plug-in counts entries in 64 bits; the end record's 16-bit fields hold the count
  or 0xFFFF from 65,535 on, and the zip64 end record (with the counts) is written then.
- **FR-002**: An archive that is changed is written with the records it has (a wrong count read
  from it is not carried on).
- **FR-003**: A self-extracting archive keeps the 16-bit counts (its stub cannot read zip64; it
  takes at most 65,535 files, as before).
- **FR-004**: No string, interface or registry change.
