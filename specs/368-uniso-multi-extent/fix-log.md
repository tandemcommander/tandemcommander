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
