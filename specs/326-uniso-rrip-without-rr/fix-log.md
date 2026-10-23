# Fix log - 326-uniso-rrip-without-rr

Backlog item `iso-plug-in-rock-ridge-names-of-xorriso-images-are-not-read` - ISO plug-in: Rock
Ridge names of xorriso images are not read, the ISO 9660 names are listed.

## Measurement before (main at 2c033750)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- Seed images made with feature 322's `specs/322-uniso-hfs-btree-joliet/probe/mkimg322.sh`
  (xorriso 1.5.6 in WSL Ubuntu) plus `xorriso -compliance old_rr` of the same source.
- `tools\run_on_hidden_desktop.ps1` with `specs\322-uniso-hfs-btree-joliet\probe\iso322_probe.ps1`
  on the HEAD build: 18 / 0, with
  - `RR  RUN PASS extracted: TOP.TXT` - the Rock Ridge name `top.txt` not used;
  - `RR-LONG RUN PASS ... the Rock Ridge name used False; extracted name lengths: 31`.
  Registry restored, identical (SHA-256 D36F5B06...).
- A Python dump of the root directory records (scratch script, `struct` over the image):
  - rr.iso, rrlong.iso, oldrr.iso: `.` = `SP(len 7 v1 be ef 00)` `PX` `TF` `CE`; continuation
    area (block 0x33) = `ER` `RRIP_1991A`; `FOLDER` = `PX TF NM(folder)`; `TOP.TXT;1` =
    `PX TF NM(top.txt)`; rrlong's file `PX TF NM(flags 1 = CONTINUE, 93 letters) CE`.
  - No `RR` entry anywhere, also with `-compliance old_rr`.
  - plain.iso: no System Use entries.
- Reachability: a panel opens an `.iso` through the ISO plug-in (`uniso=on`); without Joliet
  `CISO9660::ListDirectoryRe` -> `ExtractExtFileName` / `ExtractFileName` decide every name;
  `ExtractExtFileName` reads `NM` only when the first entry is `RR`.

## Decisions

- Recognise SUSP by the `SP` entry of the root's `.` record (spec Clarifications); `RR` per record
  keeps working; LEN_SKP honoured only with `SP`.
