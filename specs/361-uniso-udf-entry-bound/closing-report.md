# Closing report - 361-uniso-udf-entry-bound
Backlog item: iso-plug-in-a-damaged-udf-file-entry-hangs-the-listing-or - ISO plug-in: a damaged UDF file entry hangs the listing or reads past its sector
Outcome: closed

## What changed

- `src/common/salisoudfentry.h` (new, header-only): `SalIsoUdfEntryDescs` - the descriptor area of a UDF file entry
  inside its sector, the descriptor size (8 / 16 / 20, 0 = embedded data), or a refusal (reserved type 4 - 7, also
  with L_AD 0; area outside the sector, 64-bit without wrap; a descriptor cut by the area's end). Built on feature
  360's `SalIsoUdfVatDescArea` / `SalIsoUdfVatDescSize`.
- `src/plugins/uniso/udf.cpp`, `udf.h`: the general reader `CUDF::ReadFileEntry(data, bEFE, part, icbTag, ad,
  maxAds)` asks the rule first and returns `UDF_FE_REFUSED`; its walk always advances and stays in the sector.
  Callers: `MapICB` returns 0 (root "Bad root ICB"; a sub-folder listed empty, listing incomplete - 330);
  `UnpackFile` shows the existing "File ... cannot be extracted. Mismatch between file size and ICB blocks." and
  fails the file; `ReadPartitionMap` keeps no metadata extents. Well-formed entries are read exactly as before.
- `src/saltests/saltests.cpp`: `TestIsoUdfEntry_361`.
- No UI string, no dialog, no plug-in ABI change.

CHANGELOG entry (the file has no `## [Unreleased]` section - owed to the maintainer):

```text
- **ISO plug-in: a damaged UDF disc image no longer makes Tandem Commander stop answering** (feature 361). A UDF
  folder or file entry that declared a reserved allocation-descriptor type made the program hang while the image
  was opened or unpacked, and an entry whose descriptor area reached past its sector was read past the buffer (a
  crash with a bug report). Such an entry is now treated as unreadable: a damaged root folder shows "Bad root
  ICB", a damaged sub-folder is left empty and the listing is marked incomplete, a damaged file is not extracted
  ("cannot be extracted") - and Unpack with "Delete archive after unpacking" keeps the image. An entry whose
  descriptor area is not a whole number of descriptors is refused too.
```

## Measurements (before / after, commands)

Probe `probe/iso361_probe.ps1` (hidden desktop; seeds mk_cdr.img by `specs/356-uniso-udf-rest/probe/mkudf356.sh`,
ud.iso by `specs/330-iso-unreadable-folder/probe/mkimg330.sh`, imapi250.iso by
`specs/356-uniso-udf-rest/probe/imapiudf356.ps1 -Revision 0x250`; damaged copies by `probe/img361.py`):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\361-uniso-udf-entry-bound\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\361-uniso-udf-entry-bound\probe\iso361_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

- Before (73bb1246's build, `result_before.txt`): **11 PASS / 13 FAIL** - L/R-ROOT5, L/R-FOLD5 and R-FILE5 hung
  (WM_NULL False); L/R-FOLDLEA an access violation in uniso.spl with a bug report; controls PASS.
- After (`result_after.txt`, and on the final build `result_after2.txt`): **24 / 0** - "Bad root ICB" / no window /
  "cannot be extracted" as specified, every damaged image kept, the controls extracted whole and deleted.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `.\build.cmd` → BUILD SUCCEEDED (the one warning C4267 is older).
- `saltests` → `29700 checks, 0 failed` (29,661 before). Mutants: reserved types taken 11 failed, no sector bound
  10 failed, a 32-bit area 3 failed.
- Probes: `iso361_probe` 24 / 0; regressions `iso330_probe` 30 / 0, `iso360_probe` 50 / 0; registry restored and
  identical every run.
- No translation work (no UI string or dialog changed).

## Reviews (findings and what was done)

- Review 1: MUST - a stray file `F250` committed in the repository root (left by a manual seed test) → removed;
  NOTE - a saltests check named a 32-bit wrap that did not wrap → three wrapping checks (mutant 3 fails 3); NOTEs on
  the stricter refusal (the spec's decision), the metadata caller without a probe row (recorded deviation), no row
  for embedded data past the sector (covered by saltests and the reviewer's guard-page harness: 23,232 entries, 0
  faults).
- Review 2: no MUST; SHOULD - a folder entry with L_AD 0 is listed empty unmarked and the image deleted (older,
  outside the item) → Inbox; NOTE - `ReadFileIdentifier` reads past `ScanDir`'s buffer (older) → Inbox.
- Housekeeping noticed by review 1 (not this feature's): git worktrees of earlier reviews are still registered
  (`%TEMP%\rev325\neg`, `rev328`, `rev330`, `rev332`, `rev335`, `rev341r3`,
  `.claude/worktrees/agent-a396b9b63fdf41c5a`) - the maintainer may `git worktree prune` / remove them.

## Owed to a person (with the new person-step items)

- The CHANGELOG entry above (no `## [Unreleased]` section in `CHANGELOG.md`; versions are the maintainer's).
- No person-step item: every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `iso-plug-in-a-udf-folder-entry-without-descriptors-is-listed` - ISO plug-in: a UDF folder entry without
  descriptors is listed empty and the image deleted (review:361)
- `iso-plug-in-a-udf-file-identifier-with-a-long-implementation` - ISO plug-in: a UDF file identifier with a long
  implementation-use field reads past its buffer (review:361)
