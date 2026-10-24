# Closing report - 337-uniso-form2-partial
Backlog item: iso-plug-in-a-file-covering-part-of-a-form-2-stream-lets-the - ISO plug-in: a file covering part of a Form 2 stream lets the image be deleted
Outcome: closed

## What changed

- A Form 2 stream track (feature 335) that a listed file starts in now counts as covered only when every
  sector of it that no listed file extracts whole is an empty Form 2 sector (2324 zero bytes, read whole)
  and there are at most 300 such sectors; otherwise the listing is marked incomplete, so a whole unpack
  fails and "Delete archive after unpacking" keeps the image. 336's rule (no file starts in a stream ->
  marked) is unchanged.
- A file covers `floor(size / 2048)` sectors from its extent (review 1). A track's sectors include a last
  sector stored only in part (review 1), and a wrong track-table end fails closed: extended to the next
  track's start, the last track's to the image's sector data end (NRG chunk offset, else the file's end;
  review 2).
- `src/common/salisotrack.h` (pure rules), `src/plugins/uniso/isoimage.h/.cpp` (`MarkUncoveredStreams`,
  `NoteListedFileStarts`, `StreamGapsEmpty`, `ImageDataEnd`), `src/plugins/uniso/nrg.cpp` (`ReadNRGRoot`
  hands back the chunk offset), `src/saltests/saltests.cpp` (`TestIsoStreamPartial_337`).
- Probe `specs/337-uniso-form2-partial/probe/iso337_probe.ps1` + `img337.py`.

## Measurements (before / after, commands)

- Before (main 1c43d7d8): `iso336_probe.ps1 -Only S-VCDPART,S-VCDCOV,C-VCDCOV` - S-VCDPART (1 of 64 sectors)
  and S-VCDCOV / C-VCDCOV (8 of 64) extracted part of the stream and DELETED the image.
- Real vcdimager images: every `AVSEQnn` file starts at its track's INDEX 01 and leaves 150 empty Form 2
  sectors uncovered (fix-log *Measurement before*).
- After: `iso337_probe.ps1 -Label after-review2` PASS 74, FAIL 0 (37 rows): every partly covered stream
  (S-VCDPART, S-VCDCOV, C-VCDCOV, M-FORM2COV, S-VCDTAIL, S-VCDBYTE, C-VCDTRUNC, S-VCDMID, S-VCDTWO,
  S-VCDLAST, C-VCDLAST) keeps the image; full / gap / overlap controls deleted; 335's and 336's other rows
  unchanged.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (no UI text, no `full` build needed).
- saltests: 28,602 -> 28,693 checks, 0 failed; mutant (gaps' content ignored) 5 failed.
- Probes (hidden desktop, registry restored + identical each): `result_after_review2.txt` 74 / 0;
  `result_after_review2_foldersoff.txt` 8 / 0; real Video CDs `result_realvcd_review2.txt` 10 / 0;
  `regress_334_review2.txt` 23 / 1 (S-RAW, feature 335's intended change).
- Negative controls: gap check disabled 15 / 5 (`result_before_negative.txt`); review-1 rows on the
  earlier code 6 / 2 (`result_review1_negative.txt`); review-2 rows on the earlier code 12 / 2
  (`result_review2_negative.txt`).

## Reviews (findings and what was done)

- Review 1: MUST - a partly written last sector counted as covered (row R-BYTE) -> floor sectors; SHOULD - a
  partly stored track sector dropped (R-TRUNC) -> counted, its short read marks. Both with probe rows and
  saltests.
- Review 2: no MUST; SHOULD - a too-small last track end did not fail closed (X-NRGLAST / X-CCDLAST) ->
  the image's data end; its middle-gap / overlap / two-stream rows added; NOTE skip-on-error -> Inbox.
- Two reviewer agents ended with the session before reporting (no changes left behind); each was re-run.

## Owed to a person (with the new person-step items)

- Nothing new. (A dump of a physical Video CD is still the person step of feature 335,
  `check-feature-335-with-real-nrg-and-clonecd-dumps-of-video`.)

## New Inbox items (slug - title)

- iso-plug-in-a-whole-unpack-counts-a-skipped-file-as-success - ISO plug-in: a whole unpack counts a skipped
  file as success and deletes the image
