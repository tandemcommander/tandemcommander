# Feature Specification: an archive's temporary copies belong to that archive only

**Feature Branch**: `109-disk-cache-archive-key`
**Created**: 2026-10-04
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 5, queue entry 1 of feature 108 (and feature 092's "disk cache"
item): the disk cache keys an ARCHIVE by its code-page lower-cased name and compares keys with
`strcmp`; with `ĥ.zip` and `Ĺ.zip` (UTF-8 names whose bytes fold together on CP1250) open in two
panels, F4 on `x.txt` in the second opened the FIRST archive's cached copy and the update replaced
`Ĺ.zip\x.txt` with `ĥ.zip`'s content, silently (108, `-CacheKeyRows`, both builds). Also F3, the
other cache users, and the inverse (one archive through two spellings must keep one key or at least
never let two copies of one member diverge). `PrepareCloseCurrentPath` must agree with the key -
one change, both sides (092). Measured before the work (`research.md`,
`probe/diskcache_result_pre109.txt`); the maintainer asked for autonomy.

## Clarifications

### Session 2026-10-04

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is the premise right, and what else does it reach? -> A: Right, and wider (`research.md` 1-3).
  On the build before this feature: F4 in `ĥ.zip` (left) and in `Ĺ.zip` (right) gave ONE temporary
  copy; leaving the right panel packed it into `Ĺ.zip`, and leaving the left one packed it into
  `ĥ.zip` too - BOTH archives end with `ĥ.zip`'s member carrying both edits (ZIP and 7z). F3 in the
  second archive is given the first archive's file (ZIP and 7z; after an F4 in the first, with its
  unsaved-to-the-archive edit). And a third defect of the same key, found by the measurement: the
  cache is flushed by key PREFIX, so leaving `p.zip` flushed the copies of `p.zip.zip` (any archive
  whose name starts with another's); a copy being edited there was marked out of date, and the next
  F4 on it deleted the edited copy and extracted the member over it - the edit was lost without a
  word (every release).
- Q: Which key? -> A: A key built with the file system's identity rule (092): new
  `SalNameIdentityKeyAlloc` (`salunicode.cpp`) - every UTF-16 unit through the operating system's
  upper-case table (the table `CompareStringOrdinal(..., TRUE)` uses), so
  `strcmp(key(a), key(b)) == 0` exactly when `SalNameEqualOrdinalCI(a, b)`. The cache itself keeps
  comparing keys byte for byte (its documented plug-in contract: "compared case-sensitively"), so
  nothing in `cache.cpp` changes. Text that is not valid WTF-8 keeps the legacy byte fold, behind a
  0xFF byte that valid WTF-8 never holds (092's contract: legacy fold for non-WTF-8; the two tiers
  never meet).
- Q: Both sides in one change? -> A: Yes: one function produces the archive's key
  (`CFilesWindowAncestor::GetArchiveCacheKey`) for the two builders (F3 `ViewFile`, F4
  `ExecuteFromArchive`), the two flushes (leaving the archive, after an update) and the "does the
  other panel show this archive?" test before the flush (was `StrICmp` of the names - it called
  `ĥ.zip` and `Ĺ.zip` one archive). The flushes take the key + `\` - the members' names all start
  with it - which ends the prefix over-flush.
- Q: The inverse - one archive through two spellings? -> A: Measured (`research.md` 3): Change
  Directory and Enter give the archive its on-disk spelling (case and 8.3 components are taken from
  the directory enumeration, `ChangeDir`), so another case and the 8.3 name already shared one copy.
  A SUBST drive and `\\localhost\C$` did not: two copies of one member, and the second update
  replaced the first edit (after the usual overwrite question). Now the key is stored per panel when
  the archive is opened (`SetArchiveCacheKey109`): when the other panel shows an archive of the same
  size and time under a key that differs, the two are compared by the file system's identity (103 /
  107: equal usable file ids on one volume, the same snapshot, FAT/exFAT also equal metadata -
  `SalArchiveSharesCacheKey`), and if they are one file the panel takes the other panel's key: one
  copy, both edits. Anything uncertain keeps the own key (two copies, the old behaviour) - never one
  key for two files. A WebDAV path (no file ids) stays two keys. *Revised after the independent
  review (blocker):* an EQUAL key is no proof either - the other panel's key may come from a
  spelling that names another file now (a SUBST or network drive re-pointed, a hard link replaced);
  the identity is read whenever a share could happen, and an equal key without a certain identity
  (or the same name with no sign of another file - the sharing of every release) is made unique
  (`SalArchiveCacheKeyChoice`).
- Q: Does sharing a key hide a changed archive? -> A: It did, before this feature, for one path:
  with both panels on one archive, leaving or reopening it in one panel kept the copies "because the
  other panel still shows it" - also when the reopen happened because the archive had CHANGED on disk
  (another program updated it): F3 in either panel went on showing the old content (measured, rows
  `stale-same`, every release). The first version of this feature extended that to the SUBST /
  `\\localhost\C$` pair it now unifies (`probe/diskcache_result_stale_firstfix.txt`) - found by the
  author's own row before any review. Fixed for both: the copies are kept for the other panel only
  when the archive on disk still has the size and time the other panel listed (`PrepareCloseCurrentPath`,
  `SalGetFileAttributesEx`); otherwise they are flushed like after an own update.
- Q: The plug-in-facing cache API (`GetFileFromCache`, `MoveFileToCache`, `RemoveOneFileFromCache`,
  `RemoveFilesFromCache`, `AllocFileNameInCache`, `ViewFileInPluginViewer`)? -> A: Unchanged: those
  keys are built by the plug-ins and compared byte for byte, as documented in `spl_gen.h`; a plug-in
  passing code-page text gets exactly the old behaviour. Only the core's archive key changed. The
  dead `CCacheData::NameEqual` (a `StrICmp` on keys, no caller) is removed.
- Q: Persistence? -> A: None: keys live in memory only; the temporary folders are named
  `SAL<hex>.tmp` by number. No registry change, no new string, plug-in interface stays 107.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Two archives whose names fold together keep their own copies (Priority: P1)
**Independent Test**: `ĥ.zip` and `Ĺ.zip` (and `.7z`), each with `x.txt` of its own content: F4 on
`x.txt` in each (left / right panel), change both, leave both archives, update.
**Acceptance**: each archive holds its own `x.txt` with exactly its own edit; two temporary copies.

### User Story 2 - F3 shows the file of the archive it is pressed in (Priority: P1)
**Independent Test**: the same archives; F3 on `x.txt` in each (also after an F4 in the first).
**Acceptance**: the viewer gets the second archive's `x.txt`, unedited.

### User Story 3 - Leaving one archive never touches another archive's copies (Priority: P1)
**Independent Test**: `p.zip.zip` edited (F4) in the left panel; `p.zip` entered and left in the
right panel; F4 on the same member in the left panel again; leave, update.
**Acceptance**: both edits packed into `p.zip.zip`; `p.zip` unchanged.

### User Story 4 - One archive through two spellings shares one copy (Priority: P2)
**Independent Test**: one archive entered in the left panel by its path, in the right panel through
another case, its 8.3 name, a SUBST drive, `\\localhost\C$`; F4 on `x.txt` in both; leave both.
**Acceptance**: one temporary copy; `x.txt` holds both edits.

### User Story 5 - A changed archive is shown as it is now (Priority: P2)
**Independent Test**: both panels on one archive (one path; a SUBST path), F3 on `x.txt`, the
archive replaced by another program, F3 again in either panel.
**Acceptance**: the viewer gets the new content.

### User Story 6 - Ordinary cache behaviour unchanged (Priority: P2)
**Acceptance**: F3 twice on one member = one copy, not extracted again; F3 in the other panel on the
same archive = the same copy; leaving one panel keeps it, leaving the second removes it.

### Edge Cases
- A legacy plug-in passing a code-page archive name: legacy-fold key (0xFF tier), never equal to a
  valid name's key.
- The other panel's archive on a share that stopped answering: not touched unless size and time match
  (the pre-filter); then the identity read may wait like any access to that share.
- FAT/exFAT (ids follow the directory entry): shared only with equal size and times.
- A shadow copy of the archive (Previous Versions): never shares with the live file (snapshot tag).
- A case-sensitive NTFS folder holding `a.zip` and `A.zip`: one key, as for every identity decision
  of the core since 092 (the core treats them as one name) - recorded, not changed.

## Requirements *(mandatory)*

- **FR-001**: Two archives whose names differ by the file system's rule MUST never share a disk-cache
  key - for F3, F4 and the flushes.
- **FR-002**: Every builder, flush and "same archive?" test of an archive's key MUST use one function
  (both sides in one change).
- **FR-003**: Leaving an archive or updating it MUST flush only that archive's members (key + `\`).
- **FR-004**: One archive reached through two spellings SHOULD share one key; it MUST NOT share a key
  with another file on any uncertainty.
- **FR-005**: The plug-in-facing cache services, the plug-in interface (107), strings and the
  registry MUST stay unchanged; text that is not valid WTF-8 keeps the legacy fold.
- **FR-006**: Copies kept because the other panel shows the same archive MUST NOT survive a change of
  the archive on disk.

## Success Criteria *(mandatory)*

- **SC-001**: `probe/diskcache_probe.ps1`: every row PASS on this build; the twoarc rows (F4 x2, F3 x2,
  F4+F3), `alias-subst`, `alias-unc`, `prefix` and `stale-same` FAIL on `Debug_x64_pre109`.
- **SC-002**: saltests: the fold equals `CompareStringOrdinal`'s classes over all 65,536 units; key
  equality equals `SalNameEqualOrdinalCI` on tables, random strings, every pair the old key merged.
- **SC-003**: regressions unchanged: 108 namecoll, 096 archedit, 097 arcwork subset, 095 longarc.
