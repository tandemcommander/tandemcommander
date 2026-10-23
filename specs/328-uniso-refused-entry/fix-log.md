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

### A finding on the way: listed is not enough (first after run)

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
