# Closing report - 333-uniso-hfs-part-missing
Backlog item: iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is - ISO plug-in: an HFS+ part of a hybrid that does not open is dropped without a mark
Outcome: closed

## What changed

- `src/common/salhfscatalog.h`: `SalHfsVolumeHeaderDeclaresHfsPlus` (a volume header declares HFS+:
  "H+", or "BD" with an embedded "H+") and `SalHfsApmEntryIsHfs` (an intact "Apple_HFS" partition map
  entry and its start).
- `src/plugins/uniso/hfs.h` / `hfs.cpp`: `CHFS::Declared`, set in `Open` from the first volume header
  read; `CHFS::DeclaredBehindDamagedMap` on the three partition-map failure returns (review 1).
- `src/plugins/uniso/udfiso.cpp` `CUDFISO::Open`: a declared HFS+ part that does not open sets 330's
  `PartMissing` - the listing is marked incomplete, a whole unpack fails, "Delete archive after
  unpacking" keeps the image. No message, no UI string (no `.slt` refresh).
- `src/saltests/saltests.cpp`: `TestHfsVolumeDeclared333` (27 checks).
- Probe `specs/333-uniso-hfs-part-missing/probe/iso333_probe.ps1` with `mkimg333.sh` (xorriso seeds:
  an ISO 9660 + HFS+ hybrid and the Ubuntu / Debian install layout with an Apple partition map holding
  the EFI image) and `img333.py` (damaged copies).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile
-ExecutionPolicy Bypass -File specs\333-uniso-hfs-part-missing\probe\iso333_probe.ps1 -Exe
build\tandemcommander\Debug_x64\tandemcommander.exe"`

- Before (e9f777da): 9 PASS / 5 FAIL - H-VER, H-CAT, H-SIZE, H-EXT: only the ISO 9660 part extracted,
  image deleted, `side.txt` (only in the HFS+ part) lost; APM-EFI failed only on an unrelated box.
- After: 20 PASS / 0 FAIL - the four damaged rows and H-APMSIG / H-APMCNT keep the image; H-OK, H-NOSIG,
  APM-EFI, APM-EFI-CNT are deleted as before. Review 1's run of the damaged-map rows on the pre-fix
  build: 2 FAIL (`probe/result_review1_apm_before_fix.txt`).
- Mutant (every header declared): saltests 10 failed; APM-EFI and H-NOSIG FAIL
  (`probe/result_mutant_declared_always.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED.
- saltests: 28,372 checks, 0 failed (28,345 before).
- Probes: 333 20 / 0; regression 322 18 / 0, 329 14 / 0, 330 30 / 0, 332 16 / 0 (`probe/regress_*.txt`).

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD 1 - a damaged partition map entry the reader does not need dropped an
  intact HFS+ volume unmarked - fixed (`DeclaredBehindDamagedMap`, three probe rows). NOTEs recorded
  (the last `Apple_HFS` entry is taken; the BD wrapper only unit-tested; no message; stale worktrees of
  older reviews left). Reviewer's negative control (main's `udfiso.cpp`): 10 / 4.
- Review 2: no MUST, no SHOULD; 21 adversarial map rows (block size 0 / 0xFFFF / 512, starts past the
  end, all counts damaged) - no box, no hang, kept where an intact HFS+ volume exists; negative control
  at the pre-fix commit fails the kept rows. NOTE 1 (damaged block 0 unmarked) recorded in the spec.

## Owed to a person (with the new person-step items)

- None. (No real keyboard or clipboard was needed; all rows were driven.)

## New Inbox items (slug - title)

- `iso-plug-in-an-ubuntu-style-install-image-with-an-apple` - ISO plug-in: an Ubuntu-style install
  image with an Apple partition map shows Cannot read sector #00000200
- `iso-plug-in-apfs-original-hfs-and-hfsx-parts-of-a-hybrid-are` - ISO plug-in: APFS, original HFS and
  HFSX parts of a hybrid are never listed - mark them? (decision)
