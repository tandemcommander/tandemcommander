# Closing report - 377-uniso-udf-metadata-order
Backlog item: iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs - ISO plug-in: a UDF 2.50 image written by Windows (IMAPI2FS) does not list
Outcome: closed

## What changed

- `src/plugins/uniso/udf.cpp` `CUDF::ReadPartitionMap`: for a `*UDF Metadata Partition` map only the metadata
  file's location is recorded (`CPartitionMap::MetadataFileLocation`, `HasMetadataFile`, `udf.h`).
- `CUDF::ReadSupportingTables`, case `mapMetadata`: reads the metadata file entry after the whole main volume
  descriptor sequence - the same read, error box and 361 refusal as before, now with the partition's start
  known also when the logical volume descriptor precedes the partition descriptor (IMAPI2FS UDF 2.50).
- `specs/356-uniso-udf-rest/probe/iso356_probe.ps1`: row `N-U250` (expected the defect) is now `C-U250`.
- No UI string, no resource, no plug-in interface change (no `.slt` refresh).

## Measurements (before / after, commands)

- Before (main aac7105e): `iso356_probe.ps1 -Only N-U250,C-PLAIN` - the 2.50 image: "Cannot read sector
  #00000000." + "Error reading directory structure at sector #FF567539. Incomplete content of ISO image.",
  nothing extracted, kept.
- `iso377_probe.ps1` through `tools\run_on_hidden_desktop.ps1`: before 10 / 2 (C-U250, C-U250SUB FAIL; the
  PD-first control C-U250SWAP PASS), after 12 / 0 (`probe/result_after.txt`), after review 1 12 / 0
  (`probe/result_after2.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `.\build.cmd` → `BUILD SUCCEEDED`.
- `saltests.exe` → `saltests: 30237 checks, 0 failed` (no new rule - research R3).
- Regressions: 356 56 / 0, 358 52 / 0, 361 24 / 0 (and 24 / 0 again after review 1); registry restored and
  identical after every run.

## Reviews (findings and what was done)

Review 1: no MUST (negative control with main's `uniso.spl`: 10 / 2). SHOULD S1 (an unknown map's unset `Type`
could start the moved read) fixed with `HasMetadataFile`. NOTE N1 (unbounded partition map count, older) →
Inbox. Other NOTEs accepted and recorded in `fix-log.md` *Review*.

## CHANGELOG entry (no `## [Unreleased]` section in CHANGELOG.md - for the maintainer)

```text
- **A UDF 2.50 disc image written by Windows did not open in the ISO plug-in** (feature 377).
  - **Before:** an image of UDF revision 2.50 (the revision of Blu-ray discs) written by Windows' own image writer showed "Cannot read sector #00000000." and "Error reading directory structure ... Incomplete content of ISO image." and listed no file; nothing could be extracted (the image was kept).
  - **Now:** it lists and unpacks like the same files written as UDF 2.01, and Unpack with "Delete archive after unpacking" deletes it once everything is extracted.
  - **Limitation:** tested with images written by Windows only; no real Blu-ray disc image was available.
```

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry above (no `[Unreleased]` section exists; versions are the maintainer's).
- A real Blu-ray (UDF 2.50) image is still checked by the existing person step
  `check-feature-356-with-real-udf-only-disc-images-blu-ray-dvd` - no new person-step item.

## New Inbox items (slug - title)

- `iso-plug-in-a-crafted-udf-partition-map-count-reads-past-the` - ISO plug-in: a crafted UDF partition map
  count reads past the descriptor buffer (review:377).
