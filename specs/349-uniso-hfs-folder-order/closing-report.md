# Closing report - 349-uniso-hfs-folder-order
Backlog item: iso-plug-in-an-hfs-folder-whose-id-is-lower-than-its-parent - ISO plug-in: an HFS+ folder whose ID is lower than its parent lists its contents at the root
Outcome: closed

## What changed

- `src/common/salisonamefit.h`: `CSalHfsFolderOrder` - the folder records of one HFS+ listing (catalog ID,
  parent ID, record index); `Pending(parentId)` gives the folders above a record not taken yet, outermost
  first, or reports a loop of parents; reserved IDs below 16 (TN1150) are not kept (review 1).
- `src/plugins/uniso/hfs.cpp` / `hfs.h`: `CHFS::ListDirectory` collects the folder records first and takes a
  record's pending folders before the record (`CHFS::TakePending`); the old per-record body is
  `CHFS::ListRecord`, unchanged. A loop of parents: its folders left out with their subtrees, the listing
  marked incomplete (a whole unpack fails, the image is kept), no message.
- `src/saltests/saltests.cpp`: `TestHfsFolderOrder349`.
- Probe `specs/349-uniso-hfs-folder-order/probe/` (`iso349_probe.ps1`, `mkimg349.sh`, `img349.py`).
- No UI string, no resource, no plug-in interface change.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\349-uniso-hfs-folder-order\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\349-uniso-hfs-folder-order\probe\iso349_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

| Row | `main` (5cf6564a) | after |
|---|---|---|
| H-OK (control) | PASS | PASS |
| H-MOVE (a into b into c) | FAIL - a.txt, b.txt, sub/s.txt at the HFS+ root | PASS - c/b/a/..., image deleted |
| H-LONG (k into n4, k left out) | FAIL - k.txt, kd/kd.txt at the root | PASS - nothing of k, one "(206)", image kept |
| H-CYCLE (a, b each the other's parent) | FAIL - misplaced, image deleted | PASS - a, b left out, image kept, no box |
| H-STRAY (review 1: a record with ID 2) | - | PASS - as before 349 |

Before 5 / 3 (8 rows), after 10 / 0 (10 rows); registry restored identical every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64).
- saltests -> 29,182 checks, 0 failed; mutants: no walk 17 failed, no loop guard 17, reserved rule removed 6.
- Probes: 349 10 / 0; regressions 322 18 / 0, 329 14 / 0, 332 16 / 0, 333 20 / 0, 339 20 / 0 (before and
  after the review-1 fix).
- No `.slt` refresh (no UI text changed); `build.cmd full` not needed.

## Reviews (findings and what was done)

Review 1 (refute-first agent): MUST 0. SHOULD S1 - a damaged folder record with the root's reserved ID 2 was
taken before every root record (whole volume under it, image deleted) - fixed (reserved IDs not kept,
host-order IDs, saltests cases, probe row H-STRAY). NOTE N1 (the saltests model is a copy of the loop - the
probe proves the reader) recorded; N2 (a not-handled record takes pending folders before the listing ends)
accepted, recorded in the spec; N3 person step created; N4 regressions re-run. Reviewer's negative control:
uniso.spl of 95fdd8e8 -> 5 / 3.

## Owed to a person (with the new person-step items)

- `check-feature-349-with-a-mac-made-hfs-image-holding-a-moved` - check with a Mac-made HFS+ image holding
  a folder moved into a newer folder.
- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it is not added there.

CHANGELOG entry (for the next release's section):

- **Files of a folder moved on a Mac were unpacked at the root of a disc image's HFS+ part** (feature 349).
  - **Before:** in a disc image with an HFS+ part, a folder made first and moved (on a Mac) into a newer folder had its files listed at the root of `HFS (...)`, and Copy or Unpack wrote them there; when the moved folder was left out because its path was too long, its files still appeared at the root.
  - **Now:** every file is listed and unpacked in its own folder whatever the order in which the image stores them; a left-out folder takes its whole contents with it. Folders of a damaged image that are each other's parents are left out with their contents, and Unpack with "Delete archive after unpacking" keeps such an image.
  - **Limitation:** a file whose folder record is missing or damaged is still listed at the root of `HFS (...)`; checked with crafted images only, not yet with one made on a Mac.

## New Inbox items (slug - title)

- `check-feature-349-with-a-mac-made-hfs-image-holding-a-moved` - Check feature 349 with a Mac-made HFS+ image holding a moved folder (person step)
