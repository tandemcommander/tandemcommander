# Fix log - 327-uniso-safe-names

Backlog item `iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe` - ISO plug-in: Joliet and
ISO 9660 names are not made safe before extraction.

## Measurement before (main at e50d62ad)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- Reachability: a panel opens an `.iso` through the ISO plug-in (`uniso=on`); F5 extracts through
  `UnpackFile` of the reader, which joins the target path with `fileData->Name` (the listed name) by
  `SalPathAppend`; folders are created by the core from the listed folder names.
- Sites that list a name from the image (grep `AddFile(` / `AddDir(` / `DupStr` in `src/plugins/uniso`):
  - `iso9660.cpp` `ListDirectoryRe`: Joliet folders (`ConvJolietName` -> `AddFileDir`, no cleaning),
    ISO 9660 / Joliet files and ISO 9660 folders (`MakeListedName`: cleaning only for Rock Ridge);
  - `udf.cpp` `ScanDir` -> `ReadFileIdentifier` (`DecodeOSTACompressed`) -> `AddFileDir`: none;
  - `hfs.cpp` `ListDirectory`: `FixIllegalFSChars` (trailing spaces / trailing `/` removed, `\` `?`
    `*` control -> `_`; not `:` `/` `<` `>` `"` `|`, trailing dots, device names);
  - `xdvdfs.cpp` `ScanDir`: `EnsureU8Name` only;
  - `udfiso.cpp` `ListDirectory`: volume label folders `\ISO (%s)`, `\UDF (%s)`, `\HFS (%s)`
    built from the PVD / LVD identifiers and `CHFS::GetRootName` - not cleaned;
  - generated names only: `AddBootRecord` (`s01-bootdisk-...ima`), `audio.cpp` (tracks),
    `isoimage.cpp` `Session NN`.
- New probe `probe/iso327_probe.ps1` (crafted images: `probe/img327.py` patches placeholder names of
  IMAPI2 Joliet / UDF images and of an xorriso plain ISO 9660 image, builds an Xbox XDVDFS image, sets
  a primary volume identifier; `probe/mkimg327.sh` - xorriso 1.5.6 in WSL - the plain seed and an ISO
  9660 + Rock Ridge + HFS+ hybrid with Linux names; HFS+ stores `..\..\hesc.txt` as it is and
  `12:30h.txt` as `12/30h.txt`). First run: "Error Creating File" boxes were cancelled by the probe
  (Serve answers OK / Yes only), so most names were never tried - the probe now answers Skip (173).
- `tools\run_on_hidden_desktop.ps1` ... `iso327_probe.ps1 -Label before` -> `probe/result_before.txt`:
  **PASS 19, FAIL 39**; registry restored, identical.
  - JOLIET, UDF, XBOX, PLAIN: extracted only `12` (+ stream `12:30...`), `con...` as it is, the
    trailing-dot name with its dots (`jtrailaaaaa..`, `xtrail.`, `TRAILAAAAA..`), `top.txt`; the `/`
    name and the `..\..\` file and folder -> "Error Creating File (3)" (skipped, lost).
  - HFS: `.._.._hesc.txt` and `.._.._hd` PASS before (FixIllegalFSChars maps `\`); `12/30h.txt` lost,
    `con.txt`, `htrail.` as they are. END FAIL: the program did not exit in 30 s - 136 "Detected memory
    leaks!" boxes (Debug build).
  - VOL: the whole set written to `<row>\w)\set\...` - outside the target folder.
  - Opening the xorriso HFS+ hybrid (HFS, VOL): "UnISO: Cannot read sector #00000020."
