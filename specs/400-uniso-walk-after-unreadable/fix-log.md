# Fix log - 400-uniso-walk-after-unreadable

Backlog item `iso-plug-in-after-a-folder-that-cannot-be-read-no-later` (leftover of 330).

## Measurement before (main at aaf95b94)

- `.\build.cmd` (Debug x64, up to date) at aaf95b94.
- Hidden desktop: `tools\run_on_hidden_desktop.ps1 ... iso330_probe.ps1 -Exe build\...\tandemcommander.exe
  -Label before-walk -Only RD-EXT,RD-REC,UD-EXT,UD-TAG,XD-EXT` -> PASS 10 / FAIL 0 under 330's
  expectations, i.e. the defect present:
  - RD-EXT, RD-REC, XD-EXT: `files 1: top.txt` (zlast/z.txt never listed), one box, image kept;
  - UD-EXT, UD-TAG: the ISO 9660 part's three files + `UDF (TC330)/top.txt` only, one box, image kept.
  - Registry restored, identical (SHA-256 0014109...20B4).
- Code at HEAD: `iso9660.cpp` `CISO9660::ListDirectoryRe`, `udf.cpp` `CUDF::ScanDir`,
  `xdvdfs.cpp` `CXDVDFS::ScanDir` descend a listed folder only `if (ret == ERR_OK)`; a nested failure
  sets `ret = ERR_CONTINUE` for the rest of the directory, and it is returned to every ancestor.
- `BL verify` recorded.

## Decisions

See spec *Clarifications*: one box per file system walk; a damaged folder's own tail is not walked;
out of memory / core refusal still stop later descents; UDF and Xbox walks get a visited set (328's
rule).

## speckit-analyze

- Run 1: 0 CRITICAL, 0 HIGH; MEDIUM I1 (FR-003 vs the unchanged core-refusal boxes) fixed in spec.md;
  LOW C1 (FR-007 covered by the build), C2 (no row for a hybrid with both parts damaged - follows from
  one walk per file system) accepted.
