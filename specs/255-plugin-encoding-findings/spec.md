# Feature Specification: every finding of the plug-in encoding scan has a verdict

**Feature Branch**: `255-plugin-encoding-findings`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item `check-encoding-plugin-findings` - "Read the 78 findings of
check_encoding.py --plugins one by one". From backlog item check-encoding-plugin-findings.

## Background (measured at e849e68c)

Feature 239 gave the encoding guard (`tools/check_encoding.py`) a `--plugins` option: it scans the
plug-ins with the core's rules and only reports (it never fails, the build does not run it). At
e849e68c it reports **78 findings**, the same sites as the list recorded by feature 239
(`specs/239-check-encoding-plugins/plugins_findings.txt`):

| Rule | Findings |
|---|---|
| `lossy-lenient-at-intake` | 38 |
| `utf8-to-legacy-sink` | 18 (ZIP 11) |
| `strict-probe-rejects-wtf8` | 12 |
| `mixed-composition` | 6 |
| `dead-dispinfow` | 2 |
| `ansi-template-number` | 2 |

None carries the guard's suppression marker (`// encoding-check: allow <rule> - <reason>`). Nobody
has read them: each may be a real defect (a name or text shown with lost letters or mojibake, a
file name that cannot be found again) or a false positive (the plug-in's own rules make the site
harmless - e.g. the text is ASCII by construction, the plug-in is not built as UTF-8, the value is
not a name).

11 of the 31 plug-ins are not shipped (`plugins.cfg` off: automation, checkver, demomenu, demoplug,
demoview, mmviewer, nethood, unchm, unmime, unole, unrar); findings there still get a verdict.

## Clarifications

### Session 2026-10-20

- Q: Are real defects fixed inside this feature? → A: No - each real defect becomes its own backlog
  item (grouped per plug-in and defect class), as the item's *Approach* says ("split real defects
  per plug-in into features"); this feature changes no product behaviour (autonomous run: item).
- Q: Does the build start running the plug-in scan, or does `--plugins --strict` start failing? →
  A: No - feature 239 requires the option to report without failing; this feature makes the report
  hold only the findings that are tracked as real defects, so the scan *can* become strict once
  those items are closed; making it strict is recorded as a follow-up item (autonomous run:
  conservative - keeps 239's FR-001 and `build.cmd` unchanged).
- Q: How is a false positive recorded? → A: With the guard's existing marker
  `// encoding-check: allow <rule> - <reason>` on the line or the line above, a reason a reader can
  check (autonomous run: rule - the guard's documented suppression mechanism, used throughout the
  core).
- Q: When is a lenient UTF-16 to UTF-8 conversion (`lossy-lenient-at-intake`) a real defect? → A:
  Only when the input can hold an unpaired surrogate (a file name from the file system, an archive
  or a device) **and** the result is later used as a name - to open, find, compare or hand back to
  the core; a converted text that is only shown, or whose input is valid Unicode by construction
  (resource strings, ASCII, generated text), is a false positive (autonomous run: recommended - the
  rule's own definition, "U+FFFD baked into a name destroys its identity", feature 066).
- Q: When is a strict UTF-8 probe (`strict-probe-rejects-wtf8`) a real defect? → A: Only when the
  probed bytes can be a WTF-8 name handed over by the core (a lone surrogate's 3-byte form) and the
  probe's failure sends the name down a code-page path; bytes that come from an archive, a
  protocol or a file's contents, where the WTF-8 form cannot arise, are a false positive
  (autonomous run: recommended - the rule's definition, feature 066).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The maintainer knows which plug-in findings are real (Priority: P1)

The maintainer runs the plug-in scan and sees only findings that are real, unfixed defects, each of
which has a backlog item that says what the user would see and how to fix it. Every other finding is
marked in the source with a reason why it is harmless.

**Why this priority**: today the 78-line report cannot be acted on; real defects (lost letters in a
plug-in's dialog) hide among false positives.

**Independent Test**: run `python tools/check_encoding.py --plugins`; every reported site is listed
in the verdict table as "real defect" with an existing backlog item; every other site of the
original 78 carries an `allow` marker with a reason.

**Acceptance Scenarios**:

1. **Given** the 78 findings at e849e68c, **When** the feature is done, **Then** the verdict table
   in the feature folder lists all 78, each as *false positive* (with the reason) or *real defect*
   (with the backlog item's slug).
2. **Given** the scan after the feature, **When** it is run, **Then** it reports exactly the
   findings whose verdict is *real defect*, and no other.
3. **Given** a real defect, **When** the maintainer opens its backlog item, **Then** it names the
   site(s), what the user sees (or which file operation fails), whether the plug-in is shipped, and
   a fix direction.

---

### User Story 2 - A new defect of the class stands out (Priority: P2)

A later change to a plug-in adds a new lossy conversion or a code-page sink for a UTF-8 name. The
scan reports it among few or no other lines, so it is noticed.

**Why this priority**: the guard is only useful when its report is short.

**Independent Test**: temporarily add one known-bad line to a plug-in (negative control), run the
scan, see it reported; remove it.

**Acceptance Scenarios**:

1. **Given** the annotated tree, **When** a new unannotated `utf8-to-legacy-sink` site is added,
   **Then** the scan reports it.

### Edge Cases

- A finding in third-party code skipped by the scan: not in the 78; out of scope.
- A finding whose line is a fail-safe (e.g. a lenient conversion used only after a strict one
  failed, or only for a display string that is never used to find a file): false positive with
  that reason.
- A finding in a plug-in that is not shipped: verdict as for any other; a real defect's item says
  the plug-in is off, which lowers its severity.
- One statement split over several lines reported twice (e.g. a measuring call and a converting
  call): each reported line gets its own verdict; one marker per reported line.
- A marker must not change what the compiler sees: comments only.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each of the 78 findings MUST have exactly one verdict: *false positive* (with a
  reason that can be checked against the code) or *real defect* (with the slug of a backlog item
  in *Inbox*).
- **FR-002**: Every *false positive* site MUST carry the guard's marker
  `// encoding-check: allow <rule> - <reason>` on the reported line or the line above, so the scan
  no longer reports it.
- **FR-003**: Every *real defect* MUST be recorded as a backlog item (grouped per plug-in and
  defect class), naming the sites, the user-visible effect, whether the plug-in is shipped, and a
  fix direction; its sites stay unannotated so the scan keeps reporting them.
- **FR-004**: The feature MUST NOT change the behaviour of any plug-in or of the core: source
  changes in plug-ins are comments only.
- **FR-005**: The core scan (`check_encoding.py --strict`) MUST stay `TOTAL: 0`, and `--plugins`
  MUST stay a report that never fails (feature 239).
- **FR-006**: The verdict table MUST be kept in the feature folder, one row per finding (file,
  line at e849e68c, rule, verdict, reason or item).
- **FR-007**: Making the plug-in scan strict (in the build, for the shipped plug-ins) MUST be
  recorded as a follow-up backlog item that depends on the real-defect items.

### Key Entities

- **Finding**: a site the scan reports - plug-in, file, line, rule, the line's text.
- **Verdict**: *false positive* + reason, or *real defect* + backlog item slug.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 78 of 78 findings have a verdict in the table.
- **SC-002**: The scan after the feature reports N findings, where N is the number of rows with
  verdict *real defect*; the reported sites are exactly those rows.
- **SC-003**: The build of the whole tree still succeeds and the core guard still reports 0.
- **SC-004**: A negative control (one added bad line) is reported by the scan.

## Assumptions

- Assumption (autonomous run): a verdict is reached by reading the code and its callers (how the
  text is produced, whether it is a name, which code page the receiving window uses, whether the
  plug-in's project is built with UNICODE); a GUI reproduction is not required for a verdict -
  the real-defect items carry the reproduction to their own features.
- Assumption (autonomous run): plug-ins are built without UNICODE (un-suffixed Win32 calls are
  ANSI), as the core; this is checked per plug-in where a verdict depends on it.
- Assumption (autonomous run): text that is ASCII by construction (numbers, fixed English
  identifiers, hex) is harmless in any sink.
