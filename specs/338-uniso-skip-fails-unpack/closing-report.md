# Closing report - 338-uniso-skip-fails-unpack
Backlog item: iso-plug-in-a-whole-unpack-counts-a-skipped-file-as-success - ISO plug-in: a whole unpack counts a skipped file as success and deletes the image
Outcome: closed

## What changed

- New header-only rules `src/common/salisounpack.h`: `SalIsoFileUnpackResult` (a file not written whole is
  not extracted, also when no box set the result), `CSalIsoWholeUnpackTally` / `SalIsoWholeUnpackSucceeded`
  (a whole unpack succeeds only when nothing was cancelled, left unextracted or written over, and the
  listing was complete), `CSalIsoWrittenFiles` (identities of the files the unpack wrote; fails closed).
- ISO plug-in: the five readers' `UnpackFile` (iso9660, rawfs, udf, xdvdfs, hfs - HFS+ also: extents ending
  before the size, a listed non-file record) end with the per-file rule; `CISOImage::ExtractAllItems`
  tallies file and folder results and checks each existing target's identity against the files already
  written; `UnpackWholeArchive` returns the tally's verdict (the listing's 328 mark kept).
- No UI string, no dialog, no plug-in interface change; Copy (F5) unchanged.

## Measurements (before / after, commands)

- Probe `probe/iso338_probe.ps1` through `tools\run_on_hidden_desktop.ps1` (`-NonInteractive -Lib <098 lib>`):
  main 0cec8e25 `probe/result_before.txt` PASS 10 / FAIL 6 (R-SKIP, R-SKIPALL, C-SKIP, O-SKIP, TWINS, D-SKIP:
  image deleted) -> `probe/result_after.txt` 18 / 0 -> with review 1's rows `probe/result_after_review1.txt`
  24 / 0 (12 RUN rows).
- Negative controls: both rules mutated `probe/result_negative.txt` 10 / 6; readers' rule alone
  `probe/result_negative_reader.txt` R-SILENT FAIL; reviewer's build of main 15 / 9 on its 12 rows.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64).
- saltests 28,693 -> 28,740 checks, 0 failed (`TestIsoWholeUnpack_338`; mutants fail 5).
- Probes: 338 24 / 0; regressions 330 30 / 0 (`probe/regress_330.txt`), 337 74 / 0 (`probe/regress_337.txt`).
- clang-format of the changed lines only: clean.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. SHOULD 1 (HFS+ compressed / resource-fork-only files extract empty) and
  SHOULD 2 (ISO 9660 multi-extent files) -> Inbox; NOTEs: header comment on identity matching corrected,
  REUNPACK / HARDLINK / TWINS-ALL rows ported into the probe, two pre-existing defects -> Inbox, fail-closed
  cases (8.3 clash, folders outside the mask) accepted. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- Nothing. Every probe row was driven on the hidden desktop (overwrite / skip / error boxes are dialogs the
  probe answers).

## New Inbox items (slug - title)

- iso-plug-in-an-hfs-file-whose-data-is-compressed-or-only-in - ISO plug-in: an HFS+ file whose data is compressed or only in its resource fork extracts empty
- iso-plug-in-an-iso-9660-file-over-4-gib-stored-in-several - ISO plug-in: an ISO 9660 file over 4 GiB stored in several extents extracts wrong
- iso-plug-in-cancel-in-the-error-creating-directory-box-does - ISO plug-in: Cancel in the Error Creating Directory box does not stop a whole unpack
- iso-plug-in-a-udf-file-whose-track-does-not-open-is-left - ISO plug-in: a UDF file whose track does not open is left partly written in the target
