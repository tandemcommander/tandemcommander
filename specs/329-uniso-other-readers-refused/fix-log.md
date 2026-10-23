# Fix log - feature 329 (backlog item iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses)

## Measurement before the fix (main aa939af0, branch at 61c5a0b5 - no code changed)

Code trace: ListArchive -> `CISOImage::ListImage` -> `CUDFISO::ListDirectory` (ISO 9660 / UDF / HFS+
parts of a hybrid) or `CUDF` / `CXDVDFS` / `CHFS` / `CAudio::ListDirectory`. The sites of the item are
unchanged since 328 (research R5 left them):

- `udf.cpp` `CUDF::AddFileDir`: a refused `AddDir` / `AddFile` -> `Error(IDS_ERROR)`, FALSE (fd.Name
  leaked); `ScanDir` returns `ERR_TERMINATE`, the parent turns it into `ERR_CONTINUE` and "descend
  only when everything is OK" skips every later folder of the walk.
- `xdvdfs.cpp` `CXDVDFS::AddFileDir` / `ScanDir`: the same with `return ERR_CONTINUE` (the rest of the
  folder dropped).
- `hfs.cpp` `CHFS::ListDirectory`: `Error(IDS_ERR_TOO_LONG_PATH)`, `return FALSE` - every later catalog
  record dropped. A plain "continue" would not do: a child whose parent folder is not in `pFolders`
  falls back to the HFS+ root path (`path = rootPath`).
- `audio.cpp` `CAudio::AddFileDir`: `dir->Clear(pluginData)` + "Error".
- `uniso.cpp` `UnpackWholeArchive` fails only when `CPluginDataInterface::ListingLeftOut` is set -
  set only from `CISOImage::ListingLeftOut.Incomplete`, which only the ISO 9660 reader fills.

Probe `probe/iso329_probe.ps1` (new; seeds by `probe/mkimg329.sh` in WSL - genisoimage `-udf`,
xorriso `-hfsplus on` - and `probe/img329.py` - an XDVDFS image and a two-track audio NRG), on the
Debug build of the branch start (= main):

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tc329_log_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe>\iso329_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile <probe>\result_before.txt"
```

-> `probe/result_before.txt`: **RUN rows PASS 0 / 7**:

- U-COPY / U-UNP-DEL (UDF part of the hybrid): "UnISO: Error" at the open; `UDF (TC329)` holds only
  `a<59x>\side.txt`, `top.txt` - `zlast\z.txt` lost; the unpack with "Delete archive after
  unpacking" deleted the image.
- X-COPY / X-UNP-DEL (Xbox): the same ("Error", z.txt lost, image deleted).
- H-COPY / H-UNP-DEL (HFS+ part of an xorriso hybrid): "This disk image contains a too long path
  ...", z.txt lost, image deleted.
- A-OPEN (audio NRG, 2nd track labelled 253 x L): "Error", the listing empty (Select All: "No
  matches found").
- END rows of the U / X runs: ~135 "Detected memory leaks!" boxes at exit (Debug heap) - compare
  after the fix (the refused path leaks `fd.Name`).
- "Cannot read sector #00000020" at the open of the HFS+ hybrid: known, Inbox item
  `iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot` (322 / 327) - not this feature.

## speckit-analyze

- Run 1: 0 CRITICAL / HIGH; MEDIUM I1 (SC-001 still said "audio, when the crafted image opens") fixed
  in spec.md; LOW U1 (T009's negative control is the before run, result_before.txt 0 / 7) accepted -
  the independent review builds its own negative control.
- Run 2 (after the fix): 0 findings above LOW.
