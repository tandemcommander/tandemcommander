# Feature Specification: the ZIP plug-in replaces only the member that has the added file's name

**Feature Branch**: `110-zip-plugin-name-matching`
**Created**: 2026-10-05
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 5, queue entry 2 (found by feature 108, `specs/108-archive-edit-name-collision/fix-log.md`,
rows `hL1_zip`, `hL2_zip` and the review's `split_zip`): the ZIP plug-in matches member names by
`CompareStringA` + `NORM_IGNORECASE` on UTF-8 bytes - packing `ĥ.txt` into an archive holding
`Ĺ.txt` asks "overwrite?" and replaces `Ĺ.txt`; an F4 edit of one member of such a pair, an F5 of
such a file into the archive, or two edits packed in two calls delete the other member; *Skip* to
the mis-paired question can delete the edited member itself. Check delete, extract and the
opposite direction. Measured before the work (`research.md`, `probe/zipname_result_pre110.txt`);
the maintainer asked for autonomy.

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is the premise right? -> A: Yes for the update matching (`add.cpp CZipPack::MatchFiles`),
  and the old comparison is not the core's byte fold that 108 measured but a LINGUISTIC
  comparison of the UTF-8 bytes read as code-page text: on CP1250 / Czech locale 21,925 BMP pairs
  of one-character names are "one name" for it and two for the file system
  (`probe/zip_collision_set.py`; 1,890 of them differ in byte length and were kept apart only by
  a length guard). Measured on the build before (`research.md` 2): every pair kind (`ĥ`/`Ĺ`,
  `Í`/`Ý`, `ž`/`ż`, CJK, Cyrillic; in a sub-folder; in an archive folder; Unix ZIP; OEM-named ZIP)
  - F5 asks to overwrite the OTHER member and replaces it; with both members present, two
  questions, both deleted, one added; F4 of one member deletes the other (`f_hL1`, `f_hL2`); the
  108 review's `split_zip` deletes `ĥ.txt`; *Yes*, then *Skip* to the mis-paired question during an
  update deletes the edited `ĥ.txt` and stores `Ĺ.txt` twice (`f_skip`). Unix ZIP: the added file
  is renamed to the OTHER member's spelling, which does not exist on disk - "Cannot open or create
  file", nothing packed.
- Q: Delete and extract? -> A: Not affected for files: the selection identifies a file by its
  central-directory index plus its exact listed name (`common.cpp MatchFiles`, `BSearchName`) -
  measured: F8 on `ĥ.txt` keeps `Ĺ.txt`, F5 out of the archive writes only `ĥ.txt`. Folders are
  matched by the core's byte fold, the rule the core's listing used to merge folders; it stays
  until the listing changes (NEXT-WORK item 5, `CSalamanderDirectory`). One delete defect was
  found next to it: `CountFilesInRoot` (`del.cpp`) ignored case also in a Unix archive, so with
  `Dir/a.txt` and `DIR/b.txt`, deleting `a.txt` made the emptied `Dir` disappear - fixed by using
  the selection's own folder test.
- Q: The rule? -> A: Feature 092's, for ZIP member names, in a header-only helper
  (`src/common/salzipname.h`, contract `contracts/zip-member-identity.md`): two valid WTF-8 names
  are compared ordinally on UTF-16 (`CompareStringOrdinal`, case ignored where the plug-in ignored
  it) - what Windows calls one file name; two legacy (non-WTF-8) names by the old comparison
  exactly; a valid name never equals a legacy one. No byte-length guard (7 case pairs differ in
  UTF-8 length).
- Q: Case pairs? -> A: Where the plug-in was case-insensitive it stays so, and "case" is now the
  file system's case for every script: in a DOS/Windows ZIP the panel folder and the name, in a
  Unix ZIP the name only (the folder stays case-sensitive, as before). So `č.txt` added into an
  archive holding `Č.txt` now asks to overwrite it, as `a.txt` / `A.txt` always did - Windows
  cannot extract both into one folder. The old behaviour (no question, a second member Windows
  folds onto the first) is recorded as a behaviour change. ASCII: names of one printable
  character compare as before (every pair measured and asserted); longer ASCII names can change in
  the same direction - the old comparison was linguistic, and on a locale with digraphs (Czech,
  Slovak, Hungarian, Croatian ...) "ch" is one letter, so `cHata.txt` and `chata.txt` were two
  names and are one now (independent review: 1,140 equal-length pairs of up to 4 characters on a
  Czech locale, none the other way). F5 of `cHata.txt` into `{chata.txt}` now asks to overwrite
  instead of adding a second member Windows folds onto the first. NFC / NFD stay two names.
- Q: OEM / code-page member names of old archives (UTF-8 flag clear)? -> A: `ProcessName`
  converts them to UTF-8 before any comparison, so they follow the UTF-8 rule: `č.txt` stored in
  CP852 still matches an added `č.txt` (measured on both builds); `Ĺ.txt` in CP852 no longer matches
  `ĥ.txt`. Only bytes that are not valid UTF-8 after `ProcessName` (a UTF-8 flag on code-page
  bytes, a failed conversion) keep the old comparison, and never equal a UTF-8 name.
- Q: A folder pair the core's listing merges (`ĥ/` and `Ĺ/` shown as one folder)? -> A: F5 into the
  merged folder adds `ĥ/x.txt` beside `Ĺ/x.txt` (no question); before, it replaced `Ĺ/x.txt` by
  `ĥ/x.txt` after a question. Nothing is lost either way; the panel then shows two `x.txt` in the
  merged folder until the listing item is done. Recorded.
- Q: (review SF1) Several members equal to one added file, answers mixed? -> A: A member is deleted
  only if the added file replacing it is stored. Before, in a DOS/Windows ZIP, *Yes* for one member
  put it on the delete list and a later *Skip* for another member of the same name turned the whole
  file into "do not add": the first member was deleted and the new file never stored (ASCII
  `{ax, Ax, AX}` on every release; with 110 also accented case pairs). Now a *Skip* (also *Skip all*,
  or a source that cannot be opened at that question) after a *Yes* for the same file keeps only
  that member; the file is still added.
- Q: Interface, strings, configuration? -> A: No plug-in interface change (107), no new string, no
  registry change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adding a file never replaces a member with another name (Priority: P1)
**Independent Test**: an archive holding `Ĺ.txt` (and the other pair kinds, also in folders, a Unix
ZIP, an OEM-named ZIP): F5 `ĥ.txt` into it.
**Acceptance**: no overwrite question; both files in the archive afterwards.

### User Story 2 - An edit packed back replaces only its own member (Priority: P1)
**Independent Test**: an archive with `ĥ.txt` and `Ĺ.txt`: F4 on one, on the other, on both in two
temporary folders (`split_zip`), answers *Yes* and *Skip*.
**Acceptance**: every member present once with its own content; each edit in its own member; a
skipped edit leaves its member unchanged.

### User Story 3 - Names that are one name for Windows are one name for the ZIP plug-in (Priority: P2)
**Independent Test**: F5 `č.txt` into `{Č.txt}`; F5 U+2C65 `.txt` into `{U+023A .txt}`; the same into an
OEM-named ZIP.
**Acceptance**: one overwrite question; *Yes* leaves one member with the new content.

### User Story 4 - Ordinary ZIP operations are unchanged (Priority: P1)
**Independent Test**: F5 `x.txt` into `{x.txt, y.txt}` (Yes / Skip), `a.txt` into `{A.txt}` (DOS and Unix),
`č.txt` into `{č.txt}` (UTF-8 and OEM), NFC into NFD, a member whose bytes are not UTF-8; F8 and F5 out
of a pair; the probes of 108, 106, 094 and 096.
**Acceptance**: the same results as on the build before this feature.

### User Story 5 - Deleting the last file of a folder keeps the folder (Priority: P3)
**Independent Test**: a Unix ZIP with `Dir/a.txt` and `DIR/b.txt`: in `Dir`, F8 on `a.txt`.
**Acceptance**: `DIR/b.txt` and an empty `Dir/` entry remain.

### Edge Cases
- Names over 259 bytes use a heap buffer; when memory runs out only byte-identical names are equal
  (the matching adds instead of replacing - it never deletes a member it did not mean).
- The Unix branch renames the added file to the matched member's spelling (case); that spelling
  can now be longer in bytes - the name buffer grows.
- Folders in the archive whose names the core's listing merges: see Clarifications.

## Requirements *(mandatory)*
- **FR-001**: The ZIP plug-in MUST treat a member as the added file or folder only when their names
  are one name by the file system's rule (UTF-8) or by the old comparison (legacy text on both
  sides); a UTF-8 name MUST never equal a legacy one.
- **FR-002**: Case MUST be ignored exactly where it was ignored before (now the file system's case,
  for every script); a change against the old comparison MUST only ever turn "two names" into
  "one name" (names Windows sees as one file) - never the other way, never across scripts.
- **FR-003**: Deleting the files of a folder in a Unix ZIP MUST count only the files of that
  folder (case-sensitive), as the selection does.
- **FR-004**: No new string, no plug-in interface change, no configuration change.

## Success Criteria *(mandatory)*
- **SC-001**: `probe/zipname_probe.ps1` on this build: every row PASS; on `Debug_x64_pre110` the pair
  rows, the case-pair rows, `d_unixDir` and the edit rows FAIL, the ordinary rows PASS.
- **SC-002**: saltests (13,973 before) pass with the new checks; the strict encoding guard reports 0.
- **SC-003**: Debug + Release builds; the 108 probe's `hL1_zip` / `hL2_zip` pass; the probes of
  106, 094 and 096 give the same results as before.
