# Fix log - 328-uniso-refused-entry

Backlog item `iso-plug-in-an-entry-the-listing-refuses-ends-the-listing`.

## Measurement before (main d61d0612, Debug build)

New probe `probe/iso328_probe.ps1` (hidden desktop; seed images by `probe/mkimg328.sh` in WSL
Ubuntu - genisoimage 1.1.11 fetched without root into `~/tc-genisoimage`, xorriso 1.5.6 as in 326):
one tree `a<60>/b<60>/c<60>/d<60>/e<60>/deep.txt` (305-byte Rock Ridge / Joliet folder part),
`a<60>/side.txt`, `top.txt`, `zlast/z.txt`.

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\log_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\iso328_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ...\result_before.txt"
```

`probe/result_before.txt`: RUN rows 0 PASS / 6 FAIL (END rows 6 PASS - no crash):

- G-COPY (genisoimage -R), L-COPY (the same, root SP check bytes cleared), J-COPY (genisoimage -J):
  "UnISO: Error" at the open; the listing holds `a<60>\side.txt` and `top.txt` only - the deep tree
  and `zlast\z.txt` are lost (after the error `ListDirectoryRe` descends no later folder).
- X-COPY (xorriso): no message, the whole volume under ISO 9660 names (`TOP.TXT`, `A<31>\...`) - 326's
  whole-volume fallback.
- J-UNP-DEL, G-UNP-DEL (Alt+F9, "Delete archive after unpacking"): "Error", 2 of 4 files extracted,
  the IMAGE DELETED.

Why genisoimage still hits it after 326 (record dump of gdeep.iso with a session script): the root's
`.` record carries `['SP','RR','PX','TF','CE']`, every other record starts with `RR`. 326's fit
check fails and sets `SuspVolume = FALSE`, but `SalSuspRockRidgeStart` still accepts the `RR` first
entry - the Rock Ridge names are read again and refused.

(The before run used an earlier form of the probe's "Error" box match - `Error'\]`, never matching
the box `[#32770 'UnISO'] [Static] Error`; the rows fail on their files anyway. Fixed in the probe
to `\] Error( \||$)` before the after run.)

## Decisions

See spec *Clarifications* and research R3 / R4. Analyze: two LOW findings - R4's box wording fixed
(the plug-in's `Error()` formats into 1024 bytes and would cut a path: the report uses
`ShowMessageBox` with a heap text); FR-005's "as today" for plain volumes now has one extra check
walk - accepted (same listing).

## Implementation

- `src/common/salisonamefit.h` (new, header-only): `SalIsoEntryFits`, `SalIsoPickFileName`,
  `SalIsoFolderKeepsRockRidge`, `CSalListingLeftOut` (count, first 10 whole paths, `Incomplete`,
  `Text`).
- `iso9660.cpp/.h`: `AddFileDir` asks the listing rule first and returns listed / left out / failed;
  a refused entry is noted on the image (`CISOImage::ListingLeftOut`) - no `dir->Clear`, no "Error",
  `ret` unchanged so later folders are still descended; a core refusal after the rule passed (out of
  memory) shows `IDS_ERROR` as before, without `Clear`, and marks the listing incomplete. Count walks
  (`FitCheck`) count entries that fit and entries listed (`FitCount`, `FitListed`), optionally under
  ISO 9660 names (`FitIsoNames`). The whole-volume fit check now runs for every non-Joliet volume;
  a refusal switches on `Decide` (it used to switch `SuspVolume` off). `PickDirName` / `CountUnder`
  decide a Rock Ridge folder's name; `MakeIsoName` gives a Rock Ridge record's ISO 9660 name (the
  fallback branch of `MakeListedName`, which now calls it). The walk's name buffers are one heap
  block per directory level (`NAME_BUF`).
- `uniso.cpp/.h`: `ListArchive` shows `ReportListingLeftOut` (system text 206 + paths,
  `ShowMessageBox` with a heap text) and sets `CPluginDataInterface::ListingLeftOut`;
  `UnpackWholeArchive` returns FALSE when it is set (the core then keeps the image).
- `saltests.cpp`: `TestIsoNameFit328` - the rules at their bounds, a simulator of the walk
  (`Iso328List`) on the probe's tree (xorriso / genisoimage / Joliet names) and on 400 random trees:
  never fewer entries listed nor fewer that fit than the whole-volume ISO 9660 listing, exactly the
  Rock Ridge listing when it fits whole; the report text.

### A finding on the way: listed is not enough (first after run) - reverted by review 3

The first after run (rule = the listing's rule only) gave 9 / 3: G-COPY and L-COPY copied 3 files -
the core's Copy from the archive refused `deep.txt` with "Name "deep.txt" with full path is too
long" (`fileswn7.cpp`, `IDS_NAMEISTOOLONG`: a selection is enumerated with in-image paths below
MAX_PATH, the listing takes a 255-byte folder part + a name). My first rule named the genisoimage
tree `a\b\c\d\EXXXXXXX\deep.txt` (261 bytes). Now an entry "fits" when the listing takes it and its
in-image path is below MAX_PATH (`SalIsoEntryFits`); the folder rule compares both counts (fit and
listed). Second after: `D...\E...` under `a\b\c` for both tools. (G-UNP-DEL failed on a probe bug:
the row's `$b` button handle shadowed the script's `$B` folder name - PowerShell names ignore case;
renamed `$SegA/B/C`.)

## Checks

- Build: `.\build.cmd` -> BUILD SUCCEEDED.
- saltests: `saltests: 28026 checks, 0 failed` (27,986 on main; +40 in `TestIsoNameFit328`).
  Negative control of the rule: `SalIsoFolderKeepsRockRidge` returning always true (an earlier form of
  the test) -> 6 failed (the deep.iso paths, `worse == 0`).
- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format: the changed ranges formatted (`--lines`); the remaining findings of the files are
  older lines.
- Probe `probe/iso328_probe.ps1` after -> `probe/result_after.txt`: **PASS 12, FAIL 0** (6 RUN + 6 END;
  before 0 / 6 RUN rows). Names: G / L `a\b\c\D<8>\E<8>\deep.txt`, X `a\b\c\D<31>\E<31>\deep.txt`,
  `top.txt`, `zlast\z.txt`, `a<60>\side.txt` lower case; J: the "(206)" box (Czech system text on this
  machine) with the path of `deep.txt`, three files; J-UNP-DEL image kept; G-UNP-DEL all four files,
  image deleted.
- Negative control (probe `result_negctl.txt`): `Decide` never set and `UnpackWholeArchive` not failing
  -> 7 / 5: G/X/L-COPY lose `deep.txt` (left out under Rock Ridge names), J-UNP-DEL and G-UNP-DEL delete
  the image after a partial unpack. Code restored with `git checkout HEAD --` and rebuilt.
- Regressions (`probe/regress_*.txt`): 326 `iso326_probe` 28 / 0 (DEEP: `deep.txt` extracted), 326
  `twins326_probe` 8 / 0, 327 `iso327_probe` 77 / 0, 322 `iso322_probe` 18 / 0.

## Limits

- J-COPY: the Joliet folder `e<60>` (listed, its contents left out) is 304 bytes deep; a Copy from the
  root asks "Name ... with full path is too long" for it (the core's own box, OK skips it) - Joliet
  has no other name; a copy from a deeper folder reaches it.
- A sibling's Rock Ridge name equal to another entry's ISO 9660 fallback name is not resolved.
- UDF, Xbox, HFS+ and audio readers keep their old refusal handling: Inbox
  `iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses`.
- The report is shown at every listing of the image (the panel lists an archive again after a change
  of its file), as the old "Error" was.

## Review

### Review 1 (stopped reviewer - partial work)

The first review agent ended with the session before reporting (task status `stopped`). The run was
continued: its scratch folder `%TEMP%\rev328` held its work, and `%TEMP%\tcrev328_backup.reg` -
the registry key exported now had the same SHA-256 as that backup (4F221E76...), nothing to restore;
the backup was removed. Its partial findings:

- `result_head.txt`: our probe at HEAD 12 / 0 (confirmed).
- **MUST (DoS)**: crafted loop images (genisoimage plain / `-R` / `-J` of folders `a`, `b`, the root's
  folder records patched to point to the root - a cycle with two branches per level): at HEAD the
  program stayed busy (no answer to WM_NULL in 5 s, CPU 7 s at 7 s, 152.9 s at 153 s, 296 MB for
  Joliet); on main's code (`negexe`) "Error" in 0.6 s, responsive. Cause: on main the first refused
  entry ("Error") turned `ret` into `ERR_CONTINUE`, which stopped every later descent - that bounded
  the exponential walk of a cycle (and of any directory referenced twice) by accident; a left-out entry
  no longer stops anything. Reproduced at our HEAD by the new rows LOOP-RR / LOOP-J.
- Fix: every walk (fit check, listing, each count walk) keeps the set of directory blocks it met
  (`CISO9660::Visited`, `std::set<DWORD>`); a directory met again is listed as an empty folder and
  not walked. A count walk starts from a copy of its listing walk's set (the directories the listing
  met before stay empty there too). Legitimate images never reference a directory twice ('.' / '..'
  are skipped before).
- Probe: rows LOOP-RR (gdeep.iso, PVD root folders AXXXXXXX, ZLAST) and LOOP-J (new seed `jloop.iso`,
  genisoimage -J of folders `a`, `b` - the first LOOP-J on jdeep.iso's 60-letter names did not fail
  without the fix: the depth bound ends that cycle after four levels; recorded as a negative control
  that did not fail, re-thought). After: `probe/result_after_review1.txt` **16 / 0**, LOOP rows CPU 0.6 s.
  Negative control (the visited check disabled): `probe/result_negctl_loop.txt` LOOP-RR and LOOP-J FAIL
  (no answer, CPU 21.5 s at 15 s). Regressions again: 326 28 / 0, 326 twins 8 / 0, 327 77 / 0, 322 18 / 0;
  saltests 28,026 / 0; encoding guard 0.
- A fresh review is launched with this partial work in its prompt.

### Review 2 (stopped reviewer - partial work)

The second review agent also ended with the session (status `stopped`, no report); no registry
backup left, the key's SHA-256 unchanged (4F221E76...). Its scratch `%TEMP%\rev328b` held only
`mk2.sh`: stress images for the decision mode's count walks - `wide.iso` (20,000 Rock Ridge folders
`folder_with_a_long_name_<i>` at the root, one file each, plus the deep tree that puts the volume into
decision mode), `widenodeep.iso` (the same without it) and a chain (100 levels of one-letter folders,
20,000 files at level 100, 20 more levels, a 200-letter name at the bottom).

Found by reading what it aimed at (my own SHOULD-level findings, fixed):

- review 1's fix copied the listing's visited set for every count walk - with 20,000 decided root
  folders that is quadratic. Now a count walk marks its directories in the same set and takes them
  out afterwards (`VisitedLog`).
- every Rock Ridge folder in decision mode ran a count walk of its whole subtree, also when its Rock
  Ridge name is not longer than the ISO 9660 name (where it is kept anyway) - a deep chain of short
  names walked its subtree once per level. Now no count walk then; the subtree stays in decision mode
  (the same names: in a subtree that fits whole every decision keeps Rock Ridge). The saltests
  simulator mirrors it (`TestIsoNameFit328` 0 failed).

Measured (`%TEMP%\rev328\loop_probe.ps1` of review 1 as `stress_probe.ps1`, hidden desktop; main =
review 1's build of d61d0612's uniso in `%TEMP%\rev328\negexe`), CPU at the open, all responsive:

| image | this build | main |
|---|---|---|
| wide.iso (decision mode) | 11.3 s | 16.4 s ("Error") |
| widenodeep.iso | 10.8 s | 10.2 s |
| chain.iso (`mkchain.sh`, the chain part of mk2.sh) | 0.7 s | 0.7 s |

After: `probe/result_after_review2.txt` 16 / 0; 326 28 / 0, 327 77 / 0 again; saltests 28,026 / 0.

### Review 3 (completed; run in the foreground so it reports before the turn ends)

- **MUST** (fixed): the reach criterion of the first after run (`SalIsoEntryFits`: an in-image path
  below MAX_PATH) renamed Rock Ridge FILES the listing takes to their ISO 9660 8.3 names and switched
  a volume the listing takes whole into decision mode. The core's "Name ... with full path is too
  long" check (`fileswn7.cpp`) only covers members reached through a selected folder, counted from the
  panel's current folder - a skippable box, not a reason to rename; main kept the real names. Measured
  by the reviewer (`%TEMP%\rev328c\mk3.sh`, `name_probe.ps1`; copied as `probe/result_review3_before.txt`):
  a 265-byte `Archive\2019\Proceedings of the International Workshop\Session 3\<196 letters>.pdf` and a
  262-byte Cyrillic name came out as `A_STUDY_.PDF` / `________.TXT` (xorriso: 31-letter ISO names), the
  image deleted. My first after run's G-COPY "failure" that led to the criterion was that same core
  box (deep.txt 261 bytes deep, copied from the root) - not a defect of the listing.
  Fix: back to the listing's rule only (`salisonamefit.h`: `SalIsoEntryFits` and the "fit" counts
  removed; `SalIsoPickFileName` = Rock Ridge if listed, else ISO 9660, else left out;
  `SalIsoFolderKeepsRockRidge(fits, rrLen, isoLen, listedRr, listedIso)`; the plug-in's `FitListed`
  removed, `CountUnder` returns the listed count). saltests: a listed Rock Ridge file keeps its name
  (`\Archive\2019` + 196 letters, a 250-byte folder part + `deepn1.txt`); the genisoimage deep tree is
  `a\b\c\d\EXXXXXXX\deep.txt` again; 28,018 / 0.
- Probe: G-COPY / L-COPY now pass when deep.txt is copied OR the core's own Copy box names deep.txt
  under `a<60>\b<60>\c<60>\` (G-UNP-DEL extracts it: `a\b\c\d\E<8>\deep.txt`); new rows LONG-G /
  LONG-X (`glong.iso` / `xlong.iso`, the reviewer's 265-byte name) - exactly that name extracted,
  nothing asked, image deleted. `probe/result_after_review3.txt` **20 / 0**. The review-2 build (the
  reach rule) is the negative control of LONG-* (`result_review3_before.txt`: the 8.3 names).
  Regressions: 326 28 / 0, 326 twins 8 / 0, 327 77 / 0, 322 18 / 0.
- NOTEs taken as limits: a long chain of 10-letter Rock Ridge names whose deepest level only fits
  under ISO 9660 names gets ISO 9660 names from level 1 down (FR-004's "no fewer entries" first); a
  directory met twice (crafted only) is listed empty without marking the listing incomplete (its
  content is listed once); an out-of-memory refusal of the core shows one "Error" per entry; a whole
  unpack fails whenever something was left out, also when the mask would not select it (fails
  closed). Confirmed by the reviewer: the original claims, the loop fix, the undo log, buffers; a
  30-level stress chain 2.0 s CPU (main 0.8 s, "Error").
