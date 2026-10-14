# Fix log: 144 - an archive's copies are never another archive's across a re-pointed letter

Backlog: `specs/NEXT-WORK.md`, *Open items at a glance* A.2 (queue 108, entry 3: the two items of
109's re-review).

## Before (measured 2026-10-14, `probe/result_pre144.txt`, `Debug_x64` at `bce0812a`)

109 probe, new case `resubst-both` (both panels on `T:\arc.zip`, `T:` re-pointed from A to B
between the opens, the archives 131 bytes each with equal write times): **FAIL** - the second
panel's F3 was given A's x.txt (the first panel's copy), its F4 edit was packed into
`B\arc.zip`: B's x.txt replaced by A's content + the edit, silently. `resubst` (the first panel
left before the re-point): PASS.

## Work

- `src/fileswnd.h`: `CFilesWindowAncestor::ZIPArchiveIdentity` (the identity read at the open),
  `ZIPArchiveCacheKeyFailed`, accessors; the comment of `SetArchiveCacheKey109`.
- `src/fileswn1.cpp`: both initialised in the constructor and forgotten in `SetZIPArchive`;
  `GetArchiveCacheKey` returns FALSE after a failed build instead of building the key from the
  name (it might be the other panel's key the choice ruled out).
- `src/fileswn2.cpp` `SetArchiveCacheKey109`: the own identity is read (as before, with volume
  traits) at every open and stored; `theirs` is the other panel's STORED identity - the other
  archive is not read by name any more (also no wait on a share that stopped answering); both
  low-memory returns set the failure flag. `SalArchiveCacheKeyChoice` unchanged.
- The 109 probe: case `resubst-both`.

## Review (refute-first agent, 2026-10-14)

No defect in the change. Taken over:

- LOW (race and cost): the identity was read by a third open after the listing - now taken
  from the handle that gives the archive's date and size (`SalFileIdentityFromHandle` +
  `SalFileIdentityVolumeTraits`) and passed to `SetArchiveCacheKey109`: one open, one file.
- NITs: comments (the key's empty state, the sticky refusal, a garbled sentence); the failure
  flag reset at the start of `SetArchiveCacheKey109` too; a redundant clear removed.
- Recorded: the refusal after a low-memory failure is silent (as every other low-memory return
  of the key); a transient identity failure at the first panel's open counts for that open (the
  safe direction).
- **MEDIUM, not this change - feature 145**: the first panel's pending F4 edits are packed, when
  it leaves the archive, into the file its name names NOW (`CFileTimeStamps` keeps the name):
  re-point the letter while R has an edit of A's member pending, and R packs it into B;
  `OfferArchiveUpdateIfNeeded` matches by name; R's F3 of a member not cached yet extracts B's
  member under R's key. Spec title narrowed to what 144 does; `specs/NEXT-WORK.md` A.2a.

## After

- Debug build clean (the `zip.cpp(5958)` C4244 warning is old - also in the 0.1.10 closing
  pass); `saltests` 21,829 / 0 (no pure rule changed); `check_encoding.py` TOTAL 0.
- `probe/result_109.txt` - the whole 109 probe on the final build: **19 PASS / 0 FAIL / 0 NOT
  DRIVEN** (109's record: 17 / 0 / 1 - `renet` is driven here and passes); `resubst-both` PASS
  (F3 in the second panel gives B's x.txt, the edit reaches B only, A untouched).
- Regressions: 108 `namecoll` 30 / 0, 108 `-CacheKeyRows` 2 / 0, 112 `diskcache_edit` 14 / 0 -
  as recorded by 112.
- On the way: a `TaskStop` of a runner left the 108 probe's test configuration in the registry;
  restored from the verified export (equal to the probe's own backup), recorded as a memory.
