# Closing report - 368-uniso-multi-extent
Backlog item: iso-plug-in-an-iso-9660-file-over-4-gib-stored-in-several - ISO plug-in: an ISO 9660 file over 4 GiB stored in several extents extracts wrong
Outcome: closed

## What changed

- `src/common/salisoextent.h` (new): the pure rule - a file record continues in the next one when it carries the
  multi-extent bit (never a folder); a directory walk's chain holds the consecutive records of one raw identifier
  until the last (bit clear) and lists them as one file; another identifier, a folder or the directory's end breaks
  it; the read plan of an extent (sectors, bytes per sector); the summed size; whether the reader can read a chain
  (one track, at or after its first disc address, 32-bit sectors, not a Form 2 layout).
- `src/plugins/uniso/iso9660.cpp` / `.h`: `ListDirectoryRe` keeps the chain; a complete chain is listed once under
  the first record's name (Rock Ridge / Joliet / ISO 9660 as before) with the summed 64-bit size; a broken or
  unreadable chain is left out with the existing "Error reading directory structure" box and the listing marked
  incomplete (a whole Unpack fails, the image is kept); the file-record listing moved unchanged into
  `AddFileRecord`; `UnpackFile` reads a chain extent by extent in record order.
- `src/plugins/uniso/isoimage.h` / `.cpp`: `CFilePos::Extents` / `ExtentCount` (owned) and
  `CISOImage::ChainReadable`.
- `src/saltests/saltests.cpp`: `TestIsoMultiExtent_368` (64 checks).
- No UI string, dialog or setting changed; plug-in interface unchanged.

## Measurements (before / after, commands)

- Probe `specs/368-uniso-multi-extent/probe/iso368_probe.ps1` on the hidden desktop (images `probe/img368.py`; the
  real xorriso `-iso-level 3 -R -J` image with a 4 GiB + 3000 byte file by `probe/mkimg368.sh` in WSL Ubuntu,
  passed with `-BigSeed`):
  - main 192383f1: `probe/result_before.txt` PASS 10 / FAIL 10 - every RUN row failed: each extent listed as a file of
    its own, overwrite boxes, BIG.BIN 1000 of 7144 bytes, the 4 GiB file 5048 bytes, F5 copied one part.
  - feature: `probe/result_after.txt` 20 / 0; after review 1's rows `probe/result_after_review1.txt` **26 / 0**
    (huge.bin 4,294,970,296 bytes with the source's SHA-256, no box, the image deleted; broken chains absent, box,
    image kept).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED.
- saltests: 29,999 -> **30,063 checks, 0 failed**; the rule mutated (a chain never broken, every sector 2048 bytes):
  11 failed.
- Regression probes: 338 24 / 0, 367 40 / 0, 337 with 367's expectations (`iso337_r367_probe.ps1`) 74 / 0; 337's
  own probe 54 / 20 - the same 20 rows feature 367 recorded as its intended change.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST, no SHOULD. Its three extra images (records split across a directory sector,
  a middle extent of length 0, a first extent not of whole sectors) pass and were ported into the probe. Its
  negative control (a reader that only sums the sizes) fails U-PLAIN, U-ODDMID, C-PLAIN. NOTEs recorded in
  `fix-log.md` (the broken-chain box does not name the file; the real image's extents are contiguous; F3 / Unpack
  of a selection / a chain refused by `ChainReadable` have no GUI row; a chain on a raw Mode 2 image is left out;
  interleave ignored as before).

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (CHANGELOG.md has no `## [Unreleased]` section):

```text
- **A file of 4 GiB or more in a disc image was extracted as a small fragment** (feature 368).
  - **Before:** an ISO 9660 image that stores a file in several parts (every file of 4 GiB or more on a DVD or
    Blu-ray image made by xorriso, mkisofs, ImgBurn and others) showed the file once per part, and unpacking or
    copying it left only one part - for example 5,048 bytes of a 4 GiB file - after "Confirm File Overwrite"
    questions; the image was kept.
  - **Now:** such a file is listed once with its whole size and extracted whole, its parts joined in order.
  - **Limits:** when the image's directory lacks the file's last part, the file is left out with the message
    "Error reading directory structure" and "Delete archive after unpacking" keeps the image; the same happens to
    such a file on a raw CD image of Mode 2 sectors.
```

- No person-step item: the change was measured on a real xorriso image with a 4 GiB + 3000 byte file.

## New Inbox items (slug - title)

- none
