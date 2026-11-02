# Fix log - 402-uniso-xbox-name-bound

Backlog item `iso-plug-in-an-xbox-entry-name-can-be-read-past-the-end-of` (source review:400, NOTE 3).

## Measurement before (main 76e8f098)

- Site: `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir` - the loop `while ((offset + 0x0E) <= size ...)`,
  `BYTE len = GET_BYTE(data, offset + 0x000D)`, `strncpy_s(fileName, (char*)data + offset + 0x000E, len)`:
  `offset + 0x0E + len` never compared with `size` (the buffer is `new BYTE[size]`).
- Reachable: Unpack / open of any Xbox image - `CISOImage::ListImage` -> `CXDVDFS::ListDirectory` ->
  `ScanDir` for the root and every folder (default configuration, uniso is on).
- `.\build.cmd` (incremental, nothing to rebuild), then the new probe on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell
  -NoProfile -ExecutionPolicy Bypass -File <scratch>\iso402_probe.ps1 -Exe build\...\tandemcommander.exe
  -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label before -OutFile ..."` (the probe was
  written in the session's scratchpad before the branch existed; copied to `probe/` unchanged;
  `probe/result_before.txt`). Images by `probe/img402.py` (written from scratch, no WSL).
- Result: PASS 6 / FAIL 4 (5 END rows pass, XD-EDGE pass):
  - XD-NAME `files 3: top.txt, zlast/z.txt, zzýýýý`, no window, image deleted;
  - XD-OVER1 `zzý`; XD-MAX `zzýýýýÝÝ`; XD-SUB `a/zzýýýý`;
    each no window, image deleted - the name took the Debug heap's no-man's-land bytes (0xFD) and freed
    fill (0xDD) after the directory buffer, through `EnsureU8Name`'s byte fallback as `ý` / `Ý`.
  - XD-EDGE (the name `zz` ends exactly at the end of the root's 60 bytes): top.txt, zlast/z.txt, zz;
    no window; image deleted - PASS (the control for the bound's off-by-one).
- The Debug heap reported nothing (no assertion, no bug report): a read is not checked.

## Decisions

- Root: a damaged record ends the walk of its directory with ERR_CONTINUE (entries before it listed, the
  listing marked incomplete via `ListDirectory`'s `walked != ERR_OK`), also in the root - the image opens
  (the Xbox root's read failure already returns ERR_CONTINUE). A sub-folder's CONTINUE / TERMINATE are the
  same to its parent (`SalIsoWalkAfterChild`).
- Box: `IDS_ERROR_LISTING_IMAGE` with the directory's sector, `SalIsoWalkBoxQuiet(Walk, false)` (once per
  walk) - no new string, no translation work.
