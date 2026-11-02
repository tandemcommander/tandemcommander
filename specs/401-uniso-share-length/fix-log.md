# Fix log - 401-uniso-share-length

Backlog item `iso-plug-in-an-iso-9660-folder-met-again-with-a-larger` - ISO plug-in: an ISO 9660 folder
met again with a larger length is listed empty.

## Measurement before (main 53eb98ab)

- Read: `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe` - `block` and `size` from the
  record; `if (!Visited->insert(block).second) return ERR_OK;` - the key is the block alone.
  `Visited` is `std::set<DWORD>*` (`iso9660.h`), the count walks' log `std::vector<DWORD>*`
  (`VisitedLog`, `CountUnder` erases its entries); the fit walk in `ListDirectory` uses its own
  `std::set<DWORD> fitVisited`, the listing walk `std::set<DWORD> visited`.
- Reachable: Unpack (Alt+F9) / panel listing of an image -> `CISOImage::ListImage` ->
  `CISO9660::ListDirectory` -> `ListDirectoryRe` (default configuration, uniso on).
- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- New images `probe/img401.py` (plain ISO 9660 written from scratch, no WSL) and probe
  `probe/iso401_probe.ps1` (style of 400's `iso400_probe.ps1`).
- `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell
  -NoProfile -ExecutionPolicy Bypass -File ...\iso401_probe.ps1 -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib ..."` -> PASS 6 / FAIL 4
  (`probe/result_before.txt`; registry restored, identical):
  - IS-SHARE: A/A1.TXT, TOP.TXT only (b/a1.txt, b/a2.txt missing), no window, image deleted
  - IS-SHARE2: b/a1.txt missing, image deleted
  - IS-LOOP: a/l/a1.txt, a/l/a2.txt missing, image deleted
  - IS-MANY: only A/A1.TXT, TOP.TXT, image deleted
  - IS-HLINK (control, 328's rule): PASS
- Defect confirmed: `BL verify` recorded.

## Decisions

- The item's *Approach*: key by block and data length (walk again), as 400's `CXDVDFS::VisitFolder`.
- Same block and same length met again: 328's behaviour kept (listed empty, not marked) - not named by
  the item (stop-rules §1 step 4); UDF / Xbox mark it since 400 - inconsistency -> Inbox item.
