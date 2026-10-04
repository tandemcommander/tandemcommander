# Feature Specification: every edited archive member is packed back as itself

**Feature Branch**: `108-archive-edit-name-collision`
**Created**: 2026-10-04
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 5, left by feature 092 (`specs/092-name-identity-unicode/fix-log.md`,
"Recorded, not changed"): `CFileTimeStamps::AddFile` (`src/salamdr3.cpp`) identifies edited archive
members by the code-page byte fold, so on CP1250 `ĥ.txt` and `Ĺ.txt` edited from one archive collide.
Also check the inverse (one member reached under two spellings), the related look-ups of the class
and the temporary copies. Measured before the work (`research.md`,
`probe/namecoll_result_pre108.txt`); the maintainer asked for autonomy.

## Clarifications

### Session 2026-10-04

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is the premise right? -> A: Yes, and the consequence is worse than recorded (`research.md` 1).
  On the build before this feature, with two members whose UTF-8 names fold together in the code
  page (CP1250: `ĥ`/`Ĺ`, the Czech `Í`/`Ý`, `ž`/`ż`, the ideographs U+4E5D/U+4E4D, the Cyrillic
  `м`/`о` - 275 two-byte pairs and thousands of three-byte pairs on CP1250), the second F4 is not
  tracked: the disk cache deletes its freshly extracted copy right after starting the editor, the
  editor writes a new file nobody watches, and the edit is never offered for the update. With 7-Zip
  the second edit is lost; with ZIP the whole second MEMBER disappears from the archive, because the
  ZIP plug-in's own update matching (a code-page linguistic comparison) takes the first edit's name
  for the second member's and replaces it after an overwrite question. 12 of 12 pair rows fail (six
  pair kinds x ZIP and 7z).
- Q: Which rule identifies an edited member? -> A: Its temporary copy: the folder and the name on
  disk, compared by the file system's rule (092's `SalPathEqualOrdinalCI` / `SalNameEqualOrdinalCI`,
  new header `src/common/salarcedit.h`). The disk cache already gives two different members two
  different files (it never puts names equal by that rule into one folder - 092), and one member
  opened twice gets the same file; so "the same copy" is exactly "the same member". The grouping of
  copies into one packer call keeps the byte-exact folder inside the archive and compares the folder
  on disk by the same rule.
- Q: Which rule does the ARCHIVE apply - ZIP / 7z names are case-sensitive bytes, the panel treats
  most archives case-insensitively? -> A: Two members whose names are equal by the file system's rule
  (`Č.txt`/`č.txt`, `A.txt`/`a.txt`, the length-changing pair U+023A/U+2C65) in one folder cannot both
  be edited - the core refuses F4 on either with its existing message ("Name of this file is used for
  more than one file in archive (such files can be opened only in viewers)", feature 092's rule), so no
  edit can be lost; kept unchanged (their temporary copies could not coexist in one folder on disk and
  the packers match names case-insensitively on update). Members whose names differ by that rule
  (including an NFC and an NFD spelling) are two members and are edited and packed back separately.
- Q: The inverse - one member reached under two spellings? -> A: Measured: Change Directory to
  `arc.zip\DIR` shows the stored folder `Dir` (the listing finds folders case-insensitively) but the
  panel keeps the typed `DIR`; F4 there and F4 again after entering `Dir` gave the one member two
  temporary copies; both were packed back and the second replaced the first edit (ZIP and 7z). Fixed
  in the edit route: the folder inside the archive is taken in the spelling the listing stores
  (`GetZIPPathAsStored108`, `fileswn6.cpp`), for the disk-cache name, the name given to the archiver
  and the folder the edit is packed back into - one member, one copy, one update. The panel itself
  keeps the typed path (title, history unchanged).
- Q: Temporary copies of two members that fold together - do they share a file? -> A: No (measured):
  `ĥ.txt` and `Ĺ.txt` get two files in one `SAL*.tmp` folder; names equal by the file system's rule
  get separate folders (092's `ContainTmpName`). Nothing to change.
- Q: The ZIP plug-in's update matching? -> A: Not changed here: it is the plug-in's own name identity
  (`zip/add.cpp`, also `del.cpp`, `extract.cpp`), used by every add into a ZIP archive, not only by
  this route - a separate defect, recorded as the first queue entry of NEXT-WORK item 5 (serious: a
  member whose name folds together with an added file's is deleted after an overwrite question that
  the user did not expect). With this feature, for 7z both edits of a pair are packed back; for ZIP
  only when the two copies share one temporary folder (then both reach the plug-in in one call and
  both members end up with their own edits). Otherwise the plug-in can still lose one: an edit of
  ONE member of such a pair (probe rows `hL1_zip`, `hL2_zip`, both builds), or two copies in two
  temporary folders packed in two calls (the independent review's `split_zip` row, both builds).
  Queued as feature 110, after 109 (the disk-cache archive key).
- Q: The disk-cache keys (`CCacheDirData`, `PrepareCloseCurrentPath`)? -> A: Not touched (a separate
  later item). Measured for this route: the key is the lower-cased archive name plus the member's
  path byte for byte, so two members never share a key; recorded in `research.md` 4.
- Q: Interface, strings, configuration? -> A: No plug-in interface change (stays 107), no new string,
  no registry change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Two members whose names fold together are both packed back (Priority: P1)
**Independent Test**: an archive (ZIP, 7z) with `ĥ.txt` and `Ĺ.txt` (and the other pair kinds of the
probe, also in a sub-folder): F4 on each, change both, leave the archive, Update All, answer the
overwrite questions with Yes.
**Acceptance**: both members present once, each with its own original content and its own edit;
no other entry added.

### User Story 2 - One member opened through two spellings of its folder is one edit (Priority: P1)
**Independent Test**: Change Directory to `<arc>\DIR` (stored `Dir`), F4 on `x.txt`; Backspace,
Enter on `Dir`, F4 on `x.txt` again; leave, update.
**Acceptance**: both F4 open the same temporary copy; the archive's `Dir/x.txt` holds both edits;
no `DIR/x.txt` entry.

### User Story 3 - Members equal by the file system's rule are refused as before (Priority: P2)
**Independent Test**: `Č.txt`/`č.txt`, `A.txt`/`a.txt`, U+023A/U+2C65 in one folder: F4 on each.
**Acceptance**: the existing refusal message each time; the archive unchanged.

### User Story 4 - Ordinary edits work as before (Priority: P1)
**Independent Test**: one accented member (`článek.txt`), one member edited twice, an NFC/NFD pair;
the probes of 096, 097, 092 and 106.
**Acceptance**: the same results as on the build before this feature.

### Edge Cases
- The 092 duplicate refusal compares only the folder shown in the panel; members of two different
  folders never share a temporary folder when their names are equal by the rule.
- A folder pair that folds together in the code page (`ĥ/` and `Ĺ/`) is merged into one folder by the
  archive listing (`CSalamanderDirectory`, NEXT-WORK item 5, not this feature); the stored spelling
  taken by this feature is then the listing's (the first one) - no change from before for that case.
- The F3 viewer keeps its own disk-cache name from the typed path; after an edit through a typed
  spelling it may show the archive's content rather than the edited copy (as before).
- A plug-in that deletes the cached files itself (its own cache root) is covered by the same rule; the
  folder comparison works on its root too.

## Requirements *(mandatory)*
- **FR-001**: Two different members of one archive opened for editing MUST be tracked as two items
  and packed back each under its own name, whatever their names are in the code page.
- **FR-002**: One member opened for editing twice - also through two spellings of its folder - MUST
  be one item with one temporary copy.
- **FR-003**: The temporary copy of a tracked member MUST NOT be deleted while it is tracked; a
  copy is released only when it is the copy of an already tracked member.
- **FR-004**: Two members equal by the file system's rule in one folder MUST stay refused for
  editing with the existing message.
- **FR-005**: No new string, no plug-in interface change, no configuration change.

## Success Criteria *(mandatory)*
- **SC-001**: `probe/namecoll_probe.ps1` on this build: every core row PASS; on `Debug_x64_pre108` the
  pair rows and the typed-spelling rows FAIL. The ZIP single-edit pair rows fail on both builds (the
  plug-in's matching, recorded).
- **SC-002**: saltests (13,756 before) pass with the new checks; the strict encoding guard reports 0.
- **SC-003**: Debug + Release builds; the probes of 096 (archive edit), 097 (arcwork subset), 092
  (focus) and 106 (packself) give the same results as on the build before this feature.
