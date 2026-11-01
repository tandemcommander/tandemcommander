# Fix log - 370-nrg-info-sessions

Backlog item `iso-plug-in-the-image-information-of-an-nrg-image-reads-past`.

## Measurement before (main at 2c1c1279, Debug x64 build of HEAD)

- Site: `src/plugins/uniso/viewer.cpp` `CISOImage::DumpInfo` - the walk over `Tracks` reads
  `Session[session]` whenever `i == limit`, with no `session < Session.Count` check, the count as `int`.
- Reachable: F3 / View on an `.nrg` file (uniso is the default viewer of `*.nrg`, `uniso.cpp`
  `AddViewer`) -> `CPluginInterfaceForViewer::ViewFile` -> `image->DumpInfo(outStream)` -> the internal
  viewer shows `iso_dump.txt` from the disk cache.
- Readers of `Session` enumerated (Grep `Session[`, `Session.Count`, `Session.Add`, `AddSessionTracks`):
  `img.cpp` (CCD, guarded by 352's `SalIsoCcdLayoutTrusted`), `isoimage.cpp` `ListTracks` (340's
  `SalIsoSessionTracks`), `viewer.cpp` `DumpInfo` (the defect). Writers: `nrg.cpp` `readSINF` (unsigned
  DWORD as int; no SINF chunk = no session), `img.cpp` (counts from the CCD track table), `isoimage.cpp`
  plain detection (`Session.Add(1)` with its one track).
- Probe `probe/iso370_probe.ps1` (new; images by `probe/img370.py` and 334's `img334.py multi_extra`),
  F3 by `WM_COMMAND 742` on the focused image, the dump read from the disk cache while the viewer is open,
  reduced to a skeleton (N sessions, S session, n tracks of the session, T track, U = the new line):

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\370-nrg-info-sessions\probe\result_before_log.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\370-nrg-info-sessions\probe\iso370_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile E:\Projects\tandemcommander\specs\370-nrg-info-sessions\probe\result_before.txt"
  ```

  `result_before.txt`: **PASS 6 / FAIL 10**, registry restored identical.

  | Row | counts / tracks | before |
  |---|---|---|
  | F-FIT | 1,1 / 2 | PASS `N2 S1 n1 T1 S2 n1 T2` |
  | F-ZERO | 0,2 / 2 | FAIL `N2 S1 n0 T1 T2` - session 2 missing |
  | S-OVER | 1,2 / 2 | FAIL `N2 S1 n1 T1 S2 n2 T2` |
  | S-SHORT | 1 / 2 | FAIL - Debug `TRACE_C ... Index is out of range (index = 1, Count = 1)` |
  | S-NONE | - / 2 | FAIL - `Index is out of range (index = 0, Count = 0)` |
  | S-NEG | 0xFFFFFFFF,2 / 2 | FAIL `N2 S1 n-1 T1 T2` - session 2 missing |
  | S-NEGEND | 1,0xFFFFFFFF / 2 | FAIL `N2 S1 n1 T1 S2 n-1 T2` |
  | S-EXTRA3 | 1,1 / 3 | FAIL - `Index is out of range (index = 2, Count = 2)` |

## Decisions

- Walk the sessions with feature 340's `SalIsoSessionTracks` (the listing's rule); "Number of tracks"
  shows the tracks the session gets (keeps `%d` valid in every translation).
- Tracks no session covers: under one new line `IDS_INFO_NO_SESSION` (1157, free slot of bundle 72)
  "\nTracks not in any session\n" - the item allows it; without a heading they would read as tracks of
  the last session.
- analyze U1 (accepted): an image of 0 tracks with session counts now shows its sessions with 0 tracks
  (before: none) - showing every declared session is what FR-002 asks; not measured (no probe image).
- analyze I1: the old walk is not in a header, so the negative control is the probe's before run.

## Implementation

- `src/plugins/uniso/viewer.cpp` `CISOImage::DumpInfo`: walks `Session` (`s < Session.Count`), each
  session `n = SalIsoSessionTracks(first, (unsigned int)Session[s], Tracks.Count, fits)` tracks printed
  under its heading and "Number of tracks: n"; then, when `first < Tracks.Count`, `IDS_INFO_NO_SESSION`
  and the remaining tracks. A track's lines moved unchanged into `CISOImage::DumpTrackInfo` (declared in
  `isoimage.h`).
- `uniso.rh2` / `lang/lang.rc2`: `IDS_INFO_NO_SESSION 1157` "\nTracks not in any session\n" (free slot of
  bundle 72).
- `src/common/salisotrack.h`: header comment line for 370 (rule unchanged).
- `src/saltests/saltests.cpp`: `TestIsoSessionDump_370` - `Iso370Dump` walks as the dump does and gives
  the probe's skeleton; 13 rows (the eight probe images, more sessions than tracks, two counts of 2^31,
  no tracks, a plain ISO). Only the new block formatted with clang-format (the file has 2,120 lines of
  pre-existing drift on `main`, left alone).

## Measurement after

- `.\build.cmd` -> BUILD SUCCEEDED; `saltests.exe` -> `saltests: 30091 checks, 0 failed`.
- Probe after (`probe/result_after.txt`, same command with `-Label after`): **PASS 16 / FAIL 0**, registry
  restored identical. Every skeleton as wanted: F-FIT `N2 S1 n1 T1 S2 n1 T2` (unchanged), F-ZERO
  `N2 S1 n0 S2 n2 T1 T2`, S-OVER `N2 S1 n1 T1 S2 n1 T2`, S-SHORT `N1 S1 n1 T1 U T2`, S-NONE `N0 U T1 T2`,
  S-NEG `N2 S1 n2 T1 T2 S2 n0`, S-NEGEND `N2 S1 n1 T1 S2 n1 T2`, S-EXTRA3 `N2 S1 n1 T1 S2 n1 T2 U T3`.
- Negative control: the before run on the unchanged build (`probe/result_before.txt`, FAIL 10) - the
  probe tells the defect from the fix.
- Regression: feature 340's probe (listing untouched) `probe/regress_340.txt` PASS 14 / FAIL 0.
- `.\build.cmd full` -> BUILD SUCCEEDED; `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).

## Translations (stop-rules 2.13)

- Step 0: one new entry, `IDS_INFO_NO_SESSION` (STRINGTABLE 1157) of module `uniso`; no changed entry
  (step 2 not needed); no leftover `english_fallback` rows in any `uniso.origin`.
- Export: `src\vcxproj\build_langs.cmd --export-templates --module uniso` -> template row
  `1157,0,"\nTracks not in any session\n"`.
- Dry run: 1 unique gap, ~29 chars in each of the 8 enabled languages.
- Merge `--formality prefer_more --budget 2464`: DeepL characters sent 344; validation failures 0.
- Read-back against the module's terms (strings 1152-1156): de "Spuren, die zu keiner Sitzung gehoren",
  fr "Pistes n'appartenant a aucune session", nl "Tracks die niet in een sessie voorkomen", es "Pistas que
  no pertenecen a ninguna sesion" - kept (machine). Pinned (`translations/ui-overrides.json`, uniso,
  `_feature_370`): cs "Stopy, ktere nepatri do zadne sekce" (DeepL "Skladby ... relaci"), sk "Stopy, ktore
  nepatria do ziadnej sekcie" (DeepL "relacii"), hu "Savok, amelyek egyik menethez sem tartoznak" (DeepL
  "szamok ... munkamenetben"), ro "Track-uri care nu fac parte din nicio sesiune" (DeepL "Piese").
  (Diacritics omitted in this log; the files hold them.)
- Merge again (pins applied as human); `python -m translate.slt --verify` -> round-trip byte-exact (298
  files). Re-laid-out controls: 0 - every `uniso.slt` changed in row 1157 only.

## Review

Refute-first review 1 (independent agent): **no MUST, no SHOULD**.
- Re-ran saltests (30091 / 0) and the probe on the branch build: 16 / 0, registry identical.
- Its own negative control: `main` (2c1c1279) in a worktree, only `uniso.vcxproj` built into its own folder,
  the old `uniso.spl` swapped into a copied runtime tree: 6 / 10, the same rows and messages as
  `probe/result_before.txt`.
- Callers and writers of `Session` enumerated independently (the only caller of `DumpInfo` is the F3 view);
  read-only view, no user data at risk; only row 1157 (and the template's VERSION stamp, the tool's normal
  output) changed in the `.slt` files; the texts use the module's terms.
- NOTE 1: `Iso370Dump` in saltests is a copy of the loop, so it re-checks `SalIsoSessionTracks`, not
  `viewer.cpp` - the probe is the proof (already analyze I1). Accepted.
- NOTE 2: a crafted NRG with many empty SINF chunks now prints a heading for each (about 40 bytes of text
  for each 12-byte chunk) where the old walk printed at most one a track - FR-002 ("every session the
  image declares"); linear, a hostile image only, into a temporary file. Accepted, not an Inbox item.
- NOTE 3: the `.slt` VERSION stamp moved 194 -> 195 with the refresh (normal); an empty track table with a
  session prints "Session 1 / Number of tracks: 0" (analyze U1, no way to reach found). Accepted.
- The reviewer saw an installed Tandem Commander started from Explorer while its first probe ran (the
  maintainer's own start); the restored key compared identical afterwards.
