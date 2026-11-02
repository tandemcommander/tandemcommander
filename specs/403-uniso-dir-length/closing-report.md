# Closing report - 403-uniso-dir-length
Backlog item: iso-plug-in-an-iso-9660-folder-length-of-2-gib-or-more-shows - ISO plug-in: an ISO 9660 folder length of 2 GiB or more shows a stuck memory box
Outcome: closed

## What changed

- `src/common/salisowalk.h`: `SAL_ISO_DIR_MAX_LENGTH` (256 MiB), `SalIsoDirLengthReadable`,
  `SalIsoDirLastBlock` (64-bit, no wrap), `SalIsoDirTake` / `SalIsoDirGive` (the buffers a walk holds at
  once, review 1).
- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe`: the folder record's length is a `DWORD`;
  before the allocation: the length rule, the last sector of a multi-sector folder read (1 byte), the
  budget of held buffers - any failing is a folder that cannot be read (the existing box once per walk,
  the listing marked incomplete, later folders walked, the image kept by a whole Unpack). `int` only
  after the checks. `iso9660.h`: `DirBytesHeld`; `isoimage.h`: `GetSectorUserSize()`.
- `src/saltests/saltests.cpp`: `TestIsoDirLength403` (50 checks).
- No UI string, no plug-in interface change, no translation refresh needed.

## Measurements (before / after, commands)

- Before (main 618dae27, `probe/result_before.txt`): `iso403_probe` 6 PASS / 6 FAIL - IS-NEG (0xFFFFF800),
  IS-NEG2 (401 review's isoneg), IS-MIN (0x80000000): the memory box "Insufficient memory to allocate
  18446744073709549568 bytes"; Ignore -> an uncaught exception, the program closed with a bug report;
  nothing extracted, the image kept.
- After (`probe/result_final.txt`, final binaries): 16 PASS / 0 FAIL - every damaged row one "Error
  reading directory structure" box, the other files extracted, the image kept; IS-EDGE (a valid 3-sector
  folder ending at the image's last sector) extracted whole, no window, image deleted.
- Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\403-uniso-dir-length\probe\result_final.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\403-uniso-dir-length\probe\iso403_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label final"`

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`.
- saltests 282,383 (402) -> `saltests: 282433 checks, 0 failed`.
- Probes: iso403 16 / 0; regression 328 20 / 0, 400 48 / 0, 401 10 / 0, 402 10 / 0 (before and after the
  review-1 fix); registry restored and identical every run.
- Negative controls: main (6 / 6); mutants of the length and room rules (saltests 15 failed); the budget
  off (saltests 6 failed, IS-DEEP FAIL - no box, the image deleted).

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD - nested readable folders of 256 MiB each held one buffer per level (measured
  256 MiB more a level) -> fixed with the held-buffer budget; NOTE - the probe proved only the 2 GiB part
  -> rows IS-DEEP, IS-OVER added; NOTEs on NRG negative offsets (bounded), Joliet / UDF-hybrid not probed
  (same function), sibling readers (existing Inbox items) - accepted.
- Review 2: no MUST. SHOULD - a readable subfolder of exactly 256 MiB is refused (ancestors' buffers
  count) -> FR-006 and the edge case reworded, saltests checks added; NOTEs (results before a rebuild -
  re-run; met-again after a refusal; unbounded time - existing Inbox item; seek cost) - accepted.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below to the next release's section (`CHANGELOG.md` has no `## [Unreleased]`
  section; versions are the maintainer's):

  ```text
  - **A damaged disc image could end the program with an "Insufficient memory" box** (feature 403) - an
    ISO 9660 (also Joliet or UDF-hybrid) image one of whose folders claimed a length of 2 GiB or more made
    the ISO plug-in ask for an impossible amount of memory; both Abort and Ignore in the box ended Tandem
    Commander. Now such a folder, one larger than 256 MiB, one running past the end of the image, or
    nested folders whose buffers together would pass 256 MiB, is a folder that cannot be read: one "Error
    reading directory structure" message, the rest of the image is listed and extracted, and Unpack with
    "Delete archive after unpacking" keeps the image. Limit: a folder below the root gets at most 256 MiB
    less the folders above it - far beyond any real disc.
  ```

- No person-step item: nothing needs a real keyboard, clipboard or another machine.

## New Inbox items (slug - title)

- none (the sibling readers' allocations and the listing time budget are existing items:
  `iso-plug-in-an-xbox-folder-entry-claiming-a-huge-size`, `iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size`,
  `iso-plug-in-a-crafted-image-of-folders-naming-one-directory`)
