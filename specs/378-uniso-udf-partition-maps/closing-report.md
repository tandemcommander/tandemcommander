# Closing report - 378-uniso-udf-partition-maps
Backlog item: iso-plug-in-a-crafted-udf-partition-map-count-reads-past-the - ISO plug-in: a crafted UDF partition map count reads past the descriptor buffer
Outcome: closed

## What changed

- `src/common/salisoudfmaps.h` (new, header-only): `SalIsoUdfPartitionMapMinLen`, `SalIsoUdfLvdMapsFit` - the
  partition maps of a logical volume descriptor are taken only when every declared map lies in
  [440, min(sector, 440 + map table length)) with its header, a length >= 2 and >= the bytes read from its type
  (type 1: 6, type 2: 44).
- `src/plugins/uniso/udf.cpp` / `udf.h`: `CUDF::ReadLVD` returns `BOOL` and checks the rule before any map is
  recorded; `CUDF::Open` refuses the volume (`IDS_ERROR_LISTING_IMAGE`, the descriptor's sector, `quiet`
  honoured) and sets `CUDF::MapsRefused`.
- `src/plugins/uniso/udfiso.cpp`: `CUDFISO::Open` marks the listing incomplete when the UDF part was refused
  (also without the UDF anchor at 256 and on ISO 9660 + HFS / APFS tracks) - a whole unpack keeps the image.
- `src/saltests/saltests.cpp`: `TestIsoUdfMaps_378` (+38 checks, a guard-page check, a grid).
- Probe `specs/378-uniso-udf-partition-maps/probe/iso378_probe.ps1` + `img378.py`.
- No UI string, resource, plug-in interface, registry or installer change.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\378-uniso-udf-partition-maps\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\378-uniso-udf-partition-maps\probe\iso378_probe.ps1 -Exe <build>\tandemcommander.exe -Label <label>"`

- Before (frozen copy of the main 514396d3 build): 11 / 7 - every crafted UDF-only image (count 100000, map
  length 0, table 4, maps of 255 bytes off the sector, 268 maps + count 300) extracted `a.txt` with no window and
  the image was deleted; the bridge with count 100000 extracted both parts. On the later rows: R-NBCOUNT (no
  anchor) both parts, deleted. Review 2 ran all 22 rows on it: 15 / 7.
- After: 22 / 0 (`result_after3.txt`) - the crafted images are refused ("Error reading directory structure at
  sector #00000022. Incomplete content of ISO image."), nothing extracted from the UDF part, image kept; the
  well-formed IMAPI2FS UDF 2.01 / 2.50 / bridge images unchanged.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`.
- `saltests.exe` -> `saltests: 30275 checks, 0 failed` (main: 30237). Negative controls: table bound removed ->
  4 failed; header bound removed -> 0xC0000005 at the guard page.
- Probes: `iso378_probe` 22 / 0; regressions `iso356_probe` 56 / 0, `iso358_probe` 52 / 0, `iso361_probe` 24 / 0,
  `iso377_probe` 12 / 0 (356 and 358 again after review 1's fix: 56 / 0, 52 / 0). Registry restored and identical
  every run.

## Reviews (findings and what was done)

- Review 1: MUST - an ISO 9660 + UDF image without the UDF anchor at 256 whose descriptor is refused was
  deleted by a whole unpack after only the ISO part was extracted -> `MapsRefused` flag, rows C-NB201 /
  R-NBCOUNT. SHOULD - no test caught the header bound -> guard-page saltests; SHOULD - the grid's helper was a
  second statement of the rule, not the old reader -> renamed. NOTE - count high bytes -> checks added; others
  accepted (fix-log *Review*).
- Review 2: no MUST / SHOULD. NOTE 1 (ISO 9660 + HFS / APFS tracks) fixed; NOTE 2 formatting fixed; NOTE 3 -> Inbox;
  NOTE 4 probe tooling trap recorded in `quickstart.md`.

## Owed to a person (with the new person-step items)

- The CHANGELOG has no `## [Unreleased]` section (versions are the maintainer's): add this entry when the
  next release section is made:

  ```text
  - **A damaged UDF disc image could make the ISO plug-in read past its buffer** (feature 378).
    - **Before:** a UDF disc image whose volume descriptor declared more partition maps than it holds (or a
      map of length 0) was opened as if it were valid: the plug-in read past the descriptor it had read and, with
      a map length of 0, could record billions of partition maps; such an image unpacked whatever the bytes past
      the descriptor happened to give and "Delete archive after unpacking" deleted it.
    - **Now:** the partition maps are read only inside the descriptor and its declared map table; a descriptor
      whose maps do not fit is refused with "Error reading directory structure at sector #..." - a UDF-only image
      does not open, an ISO 9660 + UDF image lists its ISO 9660 part, and a whole unpack keeps the image.
    - **Limitation:** checked with images written by Windows' IMAPI2FS; an image whose first volume descriptor
      is damaged is refused even when a later copy would be valid.
  ```

- No person-step item: the change is driven fully by the hidden-desktop probe (Unpack); Enter goes through the
  same image open.

## New Inbox items (slug - title)

- `iso-plug-in-an-iso-9660-udf-image-written-by-windows-is-kept` - ISO plug-in: an ISO 9660 + UDF image written
  by Windows is kept after a whole unpack (measure:378)
- `iso-plug-in-an-unknown-udf-partition-map-type-leaves-its` - ISO plug-in: an unknown UDF partition map type
  leaves its translation undefined (review:378)
