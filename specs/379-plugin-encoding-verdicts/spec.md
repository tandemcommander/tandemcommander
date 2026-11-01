# Feature Specification: every finding of the plug-in encoding scan has a verdict

**Feature Branch**: `379-plugin-encoding-verdicts`
**Created**: 2026-11-01
**Status**: Draft
**Input**: Backlog item `check-encoding-plugin-findings` - "Read the 78 findings of
check_encoding.py --plugins one by one". Continues the stopped feature 255
(`origin/255-plugin-encoding-findings`). From backlog item check-encoding-plugin-findings.

## Background (measured at 3e0da39c)

Feature 239 gave the encoding guard (`tools/check_encoding.py`) a `--plugins` option: it scans the
plug-ins with the core's rules and only reports (it never fails, the build does not run it). At
3e0da39c it reports **81 findings**, none annotated:

- 77 of feature 239's 78 findings, unchanged (file, rule and line text; line numbers moved);
- feature 239's finding in `plugins/ftp/ftputils.cpp` (`FTPListingFieldToU8`, the strict UTF-8
  probe of a listing field) is gone: feature 269 fixed that defect (backlog item
  `ftp-wtf8-name-listing-round-trip`, found by 255's review 2);
- 4 new `strict-probe-rejects-wtf8` findings in `plugins/codeview/config.cpp`
  (`CvCodePageNameToUtf8` / `CvUtf8ToCodePageName`, feature 262), which convert a conversion
  table's name between the code page and UTF-8 for the registry.

Feature 255 read all 78 at e849e68c (`verdicts.md`, 68 markers, 10 real defects in 8 backlog
items, all on `main` now) and was stopped by its second review on row 41 (the FTP site above).
Open after it: CheckVer `dialogs.cpp` row 3 (review 2 SHOULD 1) and the archive-name rows 67, 68,
75 of TAR / UnCAB / UnMIME (review 2 NOTE 1). Re-judged at 3e0da39c by reading:

- CheckVer row 3: the filter list holds module names from the update script and the registry,
  possibly UTF-8, put into and read back from an ANSI list box and composed with a code-page
  template - a latent real defect (the plug-in is off).
- TAR / UnCAB / UnMIME: the vendored 7-Zip converter (`7zip/7za/CPP/Common/UTFConvert.cpp`,
  Windows default flags 0) writes an unpaired surrogate as its 3-byte WTF-8 form, so that form can
  occur in an archive; TAR and UnMIME then read the whole name in the code page (mojibake), UnCAB
  refuses a flagged UTF-8 name - latent real defects.

## Clarifications

### Session 2026-11-01

- Q: Are real defects fixed inside this feature? → A: No - each real defect is its own backlog item
  (the item's *Approach*: "split real defects per plug-in into features"); this feature changes no
  product behaviour (autonomous run: item).
- Q: Does the build start running the plug-in scan, or does `--plugins --strict` start failing? →
  A: No - feature 239 requires the report never to fail; making it strict is the existing follow-up
  item `plugin-encoding-scan-strict-in-build` (autonomous run: conservative).
- Q: How is a false positive recorded? → A: with the guard's marker
  `// encoding-check: allow <rule> - <reason>` on the line or directly above it (autonomous run:
  rule - the guard's documented suppression).
- Q: Which verdicts of feature 255 are kept? → A: all its verdicts that its two reviews left
  standing, re-checked against the code at HEAD; row 41 is recorded as *fixed by 269*; rows 3, 67,
  68 and 75 become *real defect* (autonomous run: item *Log* - continue from 255; conservative for
  the re-judged rows: a latent defect is tracked, not hidden).
- Q: When is a strict UTF-8 probe (`strict-probe-rejects-wtf8`) a real defect? → A: when the probed
  bytes can carry the WTF-8 form of a name (from the core, or from an archive written by a tool
  that encodes an unpaired surrogate that way) and the probe's failure sends the name down a
  code-page path or refuses it; a probe of a text that is not a name and cannot hold a surrogate is
  a false positive (autonomous run: recommended - the rule's definition, feature 066, sharpened by
  255's review 2).
- Q: When is a lenient UTF-16 to UTF-8 conversion (`lossy-lenient-at-intake`) a real defect? → A:
  only when the input can hold an unpaired surrogate and the result is later used as a name; a
  text that is only shown, or valid Unicode by construction, is a false positive (autonomous run:
  recommended - feature 066).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The maintainer knows which plug-in findings are real (Priority: P1)

The maintainer runs the plug-in scan and sees only the findings that are real, unfixed defects, each
with a backlog item; every other finding is marked in the source with a reason it is harmless.

**Why this priority**: an 81-line report cannot be acted on; real defects hide among false
positives.

**Independent Test**: run `python tools/check_encoding.py --plugins`; every reported site is a
*real defect* row of the verdict table with an existing backlog item; every other site carries an
`allow` marker with the row's reason.

**Acceptance Scenarios**:

1. **Given** the 81 findings at 3e0da39c and the 78 of feature 239, **When** the feature is done,
   **Then** the verdict table lists all 82 sites (78 + 4), each *false positive* (reason),
   *real defect* (backlog slug) or *fixed* (feature).
2. **Given** the scan after the feature, **When** it is run, **Then** it reports exactly the
   *real defect* rows, and no other.
3. **Given** a real defect, **When** the maintainer opens its backlog item, **Then** it names the
   sites, the user-visible effect, whether the plug-in is shipped, and a fix direction.

### User Story 2 - A new defect of the class stands out (Priority: P2)

A later change adds a new code-page sink for a UTF-8 name; the scan reports it among few other
lines.

**Independent Test**: add one known-bad line to a plug-in (negative control), run the scan, see it
reported; remove it.

**Acceptance Scenarios**:

1. **Given** the annotated tree, **When** a new unannotated `utf8-to-legacy-sink` site is added,
   **Then** the scan reports it.

### Edge Cases

- A finding in a plug-in that is not shipped: verdict as for any other; the item says it is off.
- One statement split over several reported lines: one verdict and one marker per reported line.
- A marker never changes what the compiler sees: comment lines only, BOM and line ends kept.
- A finding of 239 that no longer exists at HEAD: recorded with what removed it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each of the 78 findings of feature 239 and each of the 4 new findings at 3e0da39c MUST
  have exactly one verdict: *false positive* (reason checkable against the code), *real defect*
  (slug of a backlog item) or *fixed* (the feature that removed it).
- **FR-002**: Every *false positive* site MUST carry `// encoding-check: allow <rule> - <reason>`
  on the reported line or the line above, so the scan no longer reports it.
- **FR-003**: Every *real defect* MUST have a backlog item naming its sites, the user-visible
  effect, whether the plug-in is shipped and a fix direction; its sites stay unannotated.
- **FR-004**: Source changes MUST be comment lines only: no behaviour of a plug-in or the core
  changes.
- **FR-005**: The core scan (`check_encoding.py --strict`) MUST stay `TOTAL: 0`; `--plugins` MUST
  stay a report that never fails (feature 239).
- **FR-006**: The verdict table MUST be kept in the feature folder, one row per site (file, line at
  HEAD, rule, shipped, verdict, reason or item).
- **FR-007**: The follow-up item `plugin-encoding-scan-strict-in-build` MUST depend on the items of
  the real defects in shipped plug-ins (including any new one).

### Key Entities

- **Finding**: a site the scan reports - plug-in, file, line, rule, text.
- **Verdict**: *false positive* + reason, *real defect* + backlog slug, or *fixed* + feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 82 of 82 sites have a verdict in the table.
- **SC-002**: The scan after the feature reports N findings, N = the number of *real defect* rows;
  the reported sites are exactly those rows.
- **SC-003**: The build still succeeds and the core guard still reports 0.
- **SC-004**: A negative control (one added bad line) is reported by the scan.

## Assumptions

- Assumption (autonomous run): a verdict is reached by reading the code and its producers and
  consumers; a GUI reproduction is not required - the real-defect items carry the reproduction to
  their own features.
- Assumption (autonomous run): plug-ins are built without UNICODE (un-suffixed Win32 calls are
  ANSI), as feature 255 measured.
- Assumption (autonomous run): feature 255's markers are carried over (SKILL.md 4.6) and each is
  re-checked against its line at HEAD before it is kept.
