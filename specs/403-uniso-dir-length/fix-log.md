# Fix log - 403-uniso-dir-length

Backlog item `iso-plug-in-an-iso-9660-folder-length-of-2-gib-or-more-shows` - ISO plug-in: an ISO 9660
folder length of 2 GiB or more shows a stuck memory box.

## Measurement before (main 618dae27)

- Site: `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe` - `int size = root->DataLength;`
  then `char* data = new char[size];`. The only check before was `size == 0`.
- Callers (Grep `ListDirectoryRe`): `CISO9660::ListDirectory` (the fit walk and the listing walk), the
  count walk (`iso9660.cpp` ~669), and itself for every subfolder. Joliet (`Ext == extJoliet`) and the
  ISO 9660 part of a UDF hybrid (`CUDFISO::ListDirectory` -> `ISO->ListDirectory`) use the same function
  - the one site. File extraction (`CISO9660::UnpackFile`) reads a sector at a time
  (`new BYTE[sectorUserSize]`) - no allocation by a file's `DataLength`.
- Reachable from the user: Unpack (Alt+F9) of an image in the panel, or opening it (Enter).
- `.\build.cmd` (up to date), then the new probe on the hidden desktop:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\iso403_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
  ```

  Result `probe/result_before.txt`: 6 PASS / 6 FAIL. IS-NEG (0xFFFFF800), IS-NEG2 (401 review's
  `isoneg`), IS-MIN (0x80000000): "Insufficient memory to allocate 18446744073709549568 bytes"; the
  probe answers Ignore, the core asks "Do you really want to pass memory allocation error ...", Yes ->
  the allocation throws (MSVC `new` on a NULL from the handler), nothing catches it: "A problem has
  occurred, forcing Tandem Commander to close" + bug report; nothing extracted, the image kept. So the
  item understated it: Ignore also ends the program, not only Abort. Controls PASS: IS-HUGE (0x7FFFF800 -
  a 2 GiB buffer is allocated, the read fails at the image end, one box), IS-PAST, IS-EDGE.
- Registry restored and identical (SHA-256 equal).

## Decisions

- The rule `SalIsoDirLengthReadable` (pure, `src/common/salisowalk.h`, the header of 400 / 401): a length
  1 .. 256 MiB. Above it (also every length >= 2 GiB) the folder is a folder that cannot be read.
- Past the end: for a folder of more than one sector, its last sector is read (1 byte copied) before
  the buffer is allocated; a failed read = the same error path. The last block is computed in 64 bits
  (`SalIsoDirLastBlock`), a block past 0xFFFFFFFF refused.
- The error path is the existing one of a failed `ReadBlock`: the box once per walk (quiet in the fit /
  count walks), ERR_TERMINATE (ERR_CONTINUE for the root), the listing marked by `ListDirectory`.
