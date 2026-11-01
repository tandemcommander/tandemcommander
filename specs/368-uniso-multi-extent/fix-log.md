# Fix log - 368-uniso-multi-extent

Backlog item `iso-plug-in-an-iso-9660-file-over-4-gib-stored-in-several` (source review:338).

## Measurement before (main 192383f1)

- Read: `src/plugins/uniso/iso9660.cpp` - `ListDirectoryRe` lists every file record by itself (no test of file flag
  bit 7, 0x80); `AddFileDir` stores one extent (`CFilePos::Extent`) and `DataLength` as the size;
  `CISO9660::UnpackFile` reads `Size` bytes from consecutive sectors after that extent. Every reading route
  (whole Unpack, Unpack of a selection, F5 / F3 through `UnpackOneFile`) goes `CISOImage::UnpackFile` ->
  `CISO9660::UnpackFile` (the UDF/ISO bridge dispatches ISO 9660 entries to the same reader).
- Images: `probe/img368.py` (synthetic: plain / rr / rrfirst / joliet / dirflag / brkname / brkend; BIG.BIN of three
  extents out of disc order 4096 + 2048 + 1000, SUB\PART.BIN of two extents 2048 + 500). Validated with `isoinfo`
  (WSL, cdrkit): `isoinfo -x '/BIG.BIN;1'` gives 7144 bytes with the SHA-256 `expect.json` holds.
- Real image: `probe/mkimg368.sh` (WSL Ubuntu, xorriso 1.5.6 fetched without root; genisoimage refuses a file of
  4 GiB or more: "-allow-limited-size was not specified") - `xorrisofs -iso-level 3 -R -J`, huge.bin = 4 GiB + 3000
  bytes, stored as two extents 4,294,965,248 + 5,048.
- Probe `probe/iso368_probe.ps1` on the hidden desktop, Debug x64 build of main:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log <tmp>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <tmp>\iso368_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -BigSeed <tmp>\bigseed ..."
  ```

  Result (`probe/result_before.txt`): PASS 10 (END rows), FAIL 10 (every RUN row). Each record listed as its own
  file; whole Unpack: 2-3 "Confirm File Overwrite" boxes, BIG.BIN 1000 bytes (the last part), PART.BIN 500, the
  image kept (338's WroteOverOwn); F5: BIG.BIN 1000 of 7144; G-BIG: huge.bin 5048 bytes, one overwrite box, kept.
  The broken chains: the parts listed as files (BIG.BIN 2048 + BIH.BIN; PART.BIN parts).

## Decisions

- Grouping by raw identifier (bytes + length) of consecutive file records; name, date, attributes from the first.
- A broken chain (next record another identifier, a folder, or the directory's end with the bit set) -> the file
  left out, `Error(IDS_ERROR_LISTING_IMAGE, FitCheck, block)`, `ListingLeftOut.SetIncomplete()` (not the walk's
  `ret`: an `ERR_CONTINUE` stops the descent into later folders). No new UI string.
- Extents in another track than the first, or a first track that stores Form 2 data (raw / 2336 Mode 2): handled as
  a broken chain (fails closed; 366/367's per-sector Form 2 handling and 336/337's coverage stay untouched).

## Implementation

- `src/common/salisoextent.h` (new, header-only): `SalIsoRecordContinues`, `SalIsoExtentSectors`,
  `SalIsoExtentSectorBytes`, `SalIsoExtentsSize`, `SalIsoExtentChain` + `SalIsoChainRecord` / `SalIsoChainClose` /
  `SalIsoChainEnd`, `SalIsoChainReadable` (contract `contracts/salisoextent.md`).
- `isoimage.h`: `CFilePos::Extents` / `ExtentCount` (malloc-ed, freed by the new destructor; copy deleted - every
  CFilePos is `new`-ed and released by `delete (CFilePos*)` in `uniso.cpp` or AddFileDir's failure paths);
  `CISOImage::ChainReadable` (`isoimage.cpp`): the first extent's track (`SalIsoTrackOfExtent`, at most 255 as
  `GetTrackFromExtent`'s byte), every extent in it and at or after its `ExtentOffset`, not a Form 2 layout.
- `iso9660.cpp`: the file branch of `ListDirectoryRe` moved unchanged into `AddFileRecord` (name, Rock Ridge / ISO
  choice, XA attributes, AddFileDir); the loop keeps a `SalIsoExtentChain` - HELD records are skipped, DONE lists the
  first record (re-read from the directory data, already checked) with the extents, a broken or unreadable chain goes
  to `ChainNotListed` (box quiet in fit checks; `SetIncomplete` only outside them), the directory's end checks for an
  open chain. `AddFileDir` lists a chain with the summed size and a copy of the extents (no Form 2, no examine).
  `UnpackFile` reads a chain extent by extent (`SalIsoExtentSectorBytes`), the single-extent path unchanged.
- Trap: `new (std::nothrow)` does not compile in the plug-in (its debug `new` macro) - malloc / free.
- Routes: Unpack of a selection (`UnpackArchive`) and View / F3 and Copy / F5 (`UnpackOneFile`) reach
  `CISOImage::UnpackFile` -> `CISO9660::UnpackFile` like the whole Unpack (`ExtractAllItems`); the UDF/ISO bridge
  dispatches ISO 9660 entries to the same reader. F5 is driven by the probe (C-PLAIN, C-JOLIET).

## Checks

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED (the C4267 warning at `fd.NameLen = strlen` is pre-existing) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 29,999 -> **30,063 checks, 0 failed** (`TestIsoMultiExtent_368`, 64 checks) |
| negative control (unit) | header mutated: a chain never broken (`same = true`) and every sector 2048 bytes | **11 failed**; header restored, 0 failed |
| probe after | `probe/iso368_probe.ps1 -BigSeed %TEMP%\tc368work\bigseed` | `probe/result_after.txt` **PASS 20, FAIL 0** (before: 10 / 10); G-BIG huge.bin 4,294,970,296 bytes with the source's SHA-256, image deleted |
| regression 338 | `specs/338-.../probe/iso338_probe.ps1` | `probe/regress_338.txt` 24 / 0 (as recorded) |
| regression 367 | `specs/367-.../probe/iso367_probe.ps1 -ImgDir %TEMP%\tc367img` | `probe/regress_367.txt` 40 / 0 (as recorded) |
| regression 337 | 337's own probe / 367's port `iso337_r367_probe.ps1` | `regress_337.txt` 54 / 20 - the same 20 rows 367 recorded as its intended change (337's synthetic expectations of 2048-byte content); `regress_337_r367.txt` **74 / 0** |
| encoding | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| clang-format | VS 2022 clang-format on the changed lines | only pre-existing differences left |

No UI string, menu or dialog changed: no `.slt` refresh needed.

## Review

Review 1 (independent agent, refute-first, HEAD 8f8f21c6): **no MUST, no SHOULD.**

- Re-ran: saltests 30,063 / 0; probe rows U-PLAIN, U-BRKNAME, U-BRKEND, C-JOLIET PASS; G-BIG with `-BigSeed` PASS
  (huge.bin 4,294,970,296 bytes, source SHA-256, the hard-linked image deleted, the seed intact).
- Its own images (cdrkit `isoinfo -x` agrees on each SHA-256): U-SPLIT (records split across a directory sector
  boundary by zero padding), U-ZEROMID (a middle extent of length 0), U-ODDMID (a first extent of 1000 bytes) - PASS.
  **Ported into `probe/img368.py` / `probe/iso368_probe.ps1`.**
- Negative control: `uniso.spl` rebuilt in a worktree with `chained = FALSE` (lists the summed size, reads one
  contiguous run): U-PLAIN, U-ODDMID, C-PLAIN fail with wrong content - the probe catches a fix that only sums sizes.
- NOTEs (recorded, no change): (1) a broken chain shows "Error reading directory structure at sector #N" although the
  directory was read; the box does not name the file (the spec's choice - no new string); (2) the real xorriso image
  stores its extents contiguously - only the out-of-order synthetic images prove reading in record order (keep them);
  (3) no end-to-end row for a chain refused by `ChainReadable` (saltests only), View (F3), Unpack of a selection -
  confirmed by code to reach the same reader; (4) a chain on a raw Mode 2 Form 1 image (CD-ROM XA .bin) and a single
  record carrying bit 7 with no following record are now left out with the box (fail closed, documented);
  (5) the reader still ignores a section's extended attribute record length and interleave (file unit / gap size),
  as the single-extent path always did.

After the port: `probe/result_after_review1.txt` **PASS 26, FAIL 0** (13 RUN rows incl. G-BIG), registry restored +
identical.
