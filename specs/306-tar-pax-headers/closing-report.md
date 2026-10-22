# Closing report - 306-tar-pax-headers
Backlog item: tar-plug-in-ignores-pax-extended-headers - tar plug-in ignores PAX extended headers: long or non-ASCII names listed under the ustar fallback name
Outcome: closed

## What changed

- `src/common/salpaxheader.h` (new, header-only): PAX record parser (`SalPaxNextRecord`, `SalPaxApply`),
  `size` / `mtime` value rules, precedence (member over global, empty value cancels), and the refusal
  rules `SalPaxPathHasTooLongComponentU8` / `SalPaxNameFitsListingU8` (component over 255 UTF-16
  units; folder part or folder name over the panel listing's `MAX_PATH - 5` bytes, with the listing's
  prefix).
- `src/plugins/tar/untar.cpp`: `ReadTarHeader` reads `x` / `g` headers (<= 1 MiB) and applies `path`,
  `size`, `mtime` to the member; malformed headers refuse the archive with the existing header error;
  `ReadArchiveHeader` resets the global values at the first header of every pass, refuses PAX names the
  listing cannot hold (member `Ignored`, "(206)" + the path once per listing / whole-archive unpack) and
  adds the 100-ns fraction to the time. New message boxes use `LoadStrU8`.
- `src/plugins/tar/tar.h`: `SCommonHeader::MTimeFrac`, `NameFromPax`; `CArchive::GlobalPax`,
  `ReportRefusedNames`, `RefusedNameShown`, `ListingPrefixLen` + `SetListingPrefixLen`.
- `src/plugins/tar/deb/deb.cpp`: the two parts get their listing prefix length (`control\`, `data\`).
- `src/saltests/saltests.cpp`: `TestPaxHeader306`.
- No UI strings, no plug-in interface change.

## Measurements (before / after, commands)

Probe `specs/306-tar-pax-headers/probe/pax306_probe.ps1` (fixtures `mkpax306.py`, Python 3.14
`tarfile`), on the hidden desktop through `tools\run_on_hidden_desktop.ps1`:

- before (main 8c6f4d68): `probe/result_before.txt` PASS 13 / FAIL 9 - cut folder, "(123) invalid
  name" for CJK names, PAX size / mtime / global mtime ignored; GNU-TOOLONG crashed the program.
- after (final build): `probe/result_after.txt` **PASS 28 / FAIL 0** (14 rows + their END rows: PAX-LONG,
  -CJK, -TWINS, -DEEP, -MTIME, -SIZE, -GLOBAL, GIT-COMMENT, GNU-LONG, PAX-TOOLONG, -PATHPART, -255DIR,
  -LIMIT, -DEB).
- negative controls: PAX branch disabled `probe/result_negctl.txt` 12 / 8; refusal disabled
  `probe/result_negctl_refusal.txt` - the program crashes; listing checks disabled
  `probe/result_negctl_listing.txt` 5 / 3.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd`: BUILD SUCCEEDED (Debug x64).
- `saltests.exe`: 27152 checks, 0 failed.
- Probes: 306 28 / 0; regressions 252 16 / 0, 273 12 / 0, 275 17 / 0. Every run restored the registry
  (SHA-256 identical).

## Reviews (findings and what was done)

- Review 1: MUST-1 (deep PAX paths failed the whole listing - a regression against 0.1.10) fixed with
  `SalPaxNameFitsListingU8`; SHOULD-1 (probe rows for the listing limits) added; NOTEs 1-4 accepted as
  limits, NOTE 5 (probe copied when the archive had not opened) fixed.
- Review 2 (with the previous findings): no MUST; SHOULD-1 (.deb listing prefix) fixed; NOTE 1
  (FILETIME overflow at the last representable second) and NOTE 2 (`LoadStrU8` for the new boxes)
  fixed; NOTE 3 accepted (FR-007); NOTE 4 regressions re-run.

## Owed to a person (with the new person-step items)

- nothing: every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `opening-a-tar-whose-member-name-has-a-300-letter-component` - Opening a tar whose member name has a
  300-letter component crashes the program (measure:306; also the GNU deep-path listing failure).
