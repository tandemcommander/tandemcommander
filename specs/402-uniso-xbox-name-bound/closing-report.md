# Closing report - 402-uniso-xbox-name-bound
Backlog item: iso-plug-in-an-xbox-entry-name-can-be-read-past-the-end-of - ISO plug-in: an Xbox entry name can be read past the end of its directory
Outcome: closed

## What changed

- `src/common/salisoxboxentry.h` (new, header-only): `SalIsoXboxEntryHeadFits` and `SalIsoXboxEntryFits` -
  an Xbox directory entry's 14-byte head and its whole name lie in the directory's bytes, computed in 64
  bits without wrap; the next entry's offset (the name's end rounded up to 4).
- `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir`: the loop and padding checks by the head rule; before
  the name is copied, the entry rule - a name that does not lie whole in the directory is a damaged record:
  the walk's one box (`IDS_ERROR_LISTING_IMAGE`, existing text), the directory's walk ends with
  ERR_CONTINUE (entries before it listed; in the root the image opens), the listing marked incomplete, so a
  whole unpack with "Delete archive after unpacking" keeps the image. The next offset from the rule.
- `src/saltests/saltests.cpp`: `TestIsoXboxEntry402` (55 checks).
- No UI string, dialog or menu changed (no `.slt` refresh); no plug-in interface change.

## Measurements (before / after, commands)

- Before (main 76e8f098, Debug build): `iso402_probe` via `tools\run_on_hidden_desktop.ps1` - PASS 6 /
  FAIL 4: XD-NAME / XD-OVER1 / XD-MAX / XD-SUB listed and extracted `zz` + heap bytes (`zzýý...`),
  no box, image deleted; control XD-EDGE PASS. `probe/result_before.txt`.
- After: PASS 10 / FAIL 0 - one box "Error reading directory structure at sector #00000021" (#22 for
  XD-SUB), only the readable files extracted, image kept; XD-EDGE unchanged. `probe/result_after.txt`.
- Negative controls: the name bound off - saltests 17 failed, probe 6 / 4 (`probe/result_negctl.txt`);
  review 1's (the listing mark off, own worktree and build) - probe 6 / 4.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (one upstream warning C4267 at xdvdfs.cpp:119, untouched).
- saltests: 282,383 checks, 0 failed (main: 282,328).
- Probes: `iso402_probe` 10 / 0; regressions `iso400_probe` 48 / 0 (`probe/regress_400.txt`),
  `iso401_probe` 10 / 0 (`probe/regress_401.txt`); every run restored the registry with an identical hash.

## Reviews (findings and what was done)

- Refute-first review 1: no MUST, no SHOULD. NOTE 1 (saltests walk is a model; the probe proves the
  plug-in) accepted; NOTE 2 (a name with a NUL inside is cut) and NOTE 3 (a huge claimed folder size is
  allocated before the read) -> Inbox; NOTE 4 (closing records) done; NOTE 5 (old worktrees of other
  features) left alone.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below to the next release's section (`CHANGELOG.md` has no `## [Unreleased]`
  section; versions and sections are the maintainer's / `/tandem-release`'s):

  - **A damaged Xbox disc image no longer lists names made of bytes that are not in the image** (feature 402).
    - **Before:** when a folder of an Xbox (XDVDFS) image ended inside the name of its last entry, the ISO
      plug-in read the rest of the name from the program's memory: the file was listed and extracted under
      a garbled name, nothing was reported, and Unpack with "Delete archive after unpacking" deleted the
      image.
    - **Now:** such an entry is treated as a damaged record: the error "Error reading directory structure"
      is shown once, the entries before it and the rest of the image are still listed and extracted, and
      the image is kept.
    - **Limitation:** the rest of that folder after the damaged entry is not listed.

- No person-step item: everything was driven on the hidden desktop.

## New Inbox items (slug - title)

- `iso-plug-in-an-xbox-entry-name-with-a-nul-byte-inside-is` - ISO plug-in: an Xbox entry name with a NUL
  byte inside is listed cut at the NUL
- `iso-plug-in-an-xbox-folder-entry-claiming-a-huge-size` - ISO plug-in: an Xbox folder entry claiming a
  huge size allocates it before reading
