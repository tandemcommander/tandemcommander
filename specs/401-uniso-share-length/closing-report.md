# Closing report - 401-uniso-share-length
Backlog item: iso-plug-in-an-iso-9660-folder-met-again-with-a-larger - ISO plug-in: an ISO 9660 folder met again with a larger length is listed empty
Outcome: closed

## What changed

- `src/common/salisowalk.h`: `SalIsoFolderVisitKey(start, length)` - the key by which a walk recognises
  a folder met before: start and length together (64 bits).
- `src/plugins/uniso/iso9660.h` / `.cpp`: the ISO 9660 walk's visited sets (listing walk, 328's fit
  walk, count walks and their log) take that key instead of the block alone - a folder at a block met
  before with another length is walked for its own length; a loop still ends (one walk per pair).
- `src/plugins/uniso/xdvdfs.cpp`: the Xbox walk takes the shared function (the same value as before).
- `src/saltests/saltests.cpp`: `TestIsoWalk401` (19 checks).
- Probe `specs/401-uniso-share-length/probe/` (`img401.py` writes plain ISO 9660 images from scratch;
  `iso401_probe.ps1`).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\401-uniso-share-length\probe\result_<label>.txt
-CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\401-uniso-share-length\probe\iso401_probe.ps1
-Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"` - Unpack (Alt+F9) of the whole
image with "Delete archive after unpacking":

| Row | Before (main 53eb98ab) | After |
|-----|------------------------|-------|
| IS-SHARE (A 21/2048, B 21/4096) | A/A1, TOP; B empty; image deleted - FAIL | A/A1, B/A1, B/A2, TOP; image deleted - PASS |
| IS-SHARE2 (longer first) | b/a1 missing - FAIL | PASS |
| IS-LOOP (A holds L at its own block, 4096) | a/l/* missing - FAIL | a/l/a1, a/l/a2, the loop ends - PASS |
| IS-HLINK (one block, one length) | PASS (328's rule) | PASS (unchanged) |
| IS-MANY (40 lengths at one block) | 2 files - FAIL | 42 files - PASS |

Total 6 / 4 -> 10 / 0 (`result_before.txt`, `result_after.txt`, `result_after_review1.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED (no UI strings, no `full` needed).
- saltests 282,309 (recorded by 400) -> 282,328 checks, 0 failed; mutant of the key (start alone) 11 failed.
- Probes: `iso401_probe` 10 / 0; regressions `iso328_probe` 20 / 0, `iso400_probe` 48 / 0; registry
  restored identical every time.

## Reviews (findings and what was done)

Review 1 (refute-first): no MUST. Its negative control (main's uniso.spl) failed the four rows; HEAD passed.
S1 (the bound is quadratic in folder records: N = 2,000 -> 19.4 s / 525 MB) - documented in FR-003 and
the header comment, Inbox item for a listing budget. S2 (a length of 2 GiB or more -> the core's memory
box; pre-existing, now reachable also through a block met before) - Inbox item. N1-N4 recorded in
`fix-log.md`.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below to `CHANGELOG.md` (no `## [Unreleased]` section exists; versions are
  the maintainer's):

  ```text
  - **A disc image whose two folders name one directory with different lengths lists both** (feature 401).
    - **Before:** in a crafted or damaged ISO 9660 image where two folder records point to the same
      directory with different lengths, the second folder was shown empty without any message, and a
      whole Unpack with "Delete archive after unpacking" deleted the image although the files of the
      longer folder were never extracted.
    - **Now:** each folder lists the files its own record covers and Unpack extracts all of them; a
      crafted folder that points back to itself with another length still opens at once.
    - **Limitation:** an image made of many such records opens slowly; two folders with the same
      start and the same length still list the second one empty.
  ```

- Nothing else: every probe row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `iso-plug-in-an-iso-9660-folder-met-again-is-listed-empty-and` - ISO plug-in: an ISO 9660 folder met
  again is listed empty and the image deleted (measure:401)
- `iso-plug-in-a-crafted-image-of-folders-naming-one-directory` - ISO plug-in: a crafted image of
  folders naming one directory with many lengths lists slowly (review:401)
- `iso-plug-in-an-iso-9660-folder-length-of-2-gib-or-more-shows` - ISO plug-in: an ISO 9660 folder
  length of 2 GiB or more shows a stuck memory box (review:401)
