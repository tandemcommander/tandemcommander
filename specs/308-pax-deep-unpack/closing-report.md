# Closing report - 308-pax-deep-unpack
Backlog item: whole-archive-unpack-of-a-pax-tar-skips-deep-members-and-may - Whole-archive Unpack of a PAX tar skips deep members and may delete the archive
Outcome: closed

## What changed

- The TAR plug-in's PAX refusal (feature 306) depends on the pass: while the panel listing is built,
  the listing's bounds (folder part / folder name over 255 bytes) apply unchanged; in every extraction
  (whole Unpack, Copy of a selection, one file) only a component over 255 UTF-16 units is refused
  (`SalPaxNameUsableU8` in `src/common/salpaxheader.h`, `CArchive::Listing` in `src/plugins/tar`).
- An extraction asked for a refused member (it matches the mask / selection) shows the system's
  "(206)" text with the whole path (once), extracts the rest and returns FALSE - the core then neither
  reports success nor deletes the archive ("Delete archive after unpacking").
- Copy of a listed folder brings its whole subtree, also members the listing cannot show.
- saltests `TestPaxNameUsable308` (+18 checks); probe `probe/unp308_probe.ps1` + `probe/mkunp308.py`;
  feature 306's probe row PAX-DEB expectation updated (Copy of `data` now extracts its deep member).
- `CHANGELOG.md`: folded into feature 306's unreleased entry ("features 306, 308").

## Measurements (before / after, commands)

- Before (aa7f08bb, main): `unp308_probe.ps1` on the hidden desktop -> `probe/result_before.txt`
  PASS 5 / FAIL 5 - whole Unpack 2 of 34 files, with Delete the archive deleted (also with a CJK(300)
  member), .deb 3 of 5, Copy of the deep folder 2 of 32.
- After: `probe/result_after.txt` PASS 12 / FAIL 0 (UNP-DEEP 34/34, UNP-DEEP-DEL 34/34 + deleted after
  all were extracted, UNP-TOOLONG-DEL ok.txt + "(206)" + kept, UNP-DEB 5/5, COPY-DEEP 32/32,
  COPY-TOOLONG + "(206)" during the copy).
- Negative controls: listing bound back in extraction + refusal ignored -> `probe/result_negctl.txt`
  7 / 5; refusal ignored + report removed -> `probe/result_negctl_report.txt` 4 / 2. Sources restored
  byte for byte, rebuilt, 12 / 0 again.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (C4267 warnings only on unchanged lines).
- `saltests.exe` -> `saltests: 27170 checks, 0 failed`.
- Probes: 308 12 / 0; 306 28 / 0 (27 / 1 before PAX-DEB's expectation was updated - `regress_306.txt`,
  `regress_306_deb.txt`); 252 16 / 0, 273 12 / 0, 275 17 / 0. Registry restored identical in every run.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. SHOULD-1 (CHANGELOG contradiction with 306's unreleased entry) -
  fixed by folding. SHOULD-2 (hand-off to branch 307 not recorded) - logged on item
  `opening-a-tar-whose-member-name-has-a-300-letter-component`. NOTEs 1, 2, 4, 5 accepted (see
  fix-log); NOTE 3 -> new Inbox item.

## Owed to a person (with the new person-step items)

- Nothing: every row is driven on the hidden desktop (no keyboard, clipboard or server involved).

## New Inbox items (slug - title)

- tar-unpack-drops-hard-links-and-deletes-archive - Unpacking a tar leaves hard-linked files out
  silently and Delete archive after unpacking then deletes the archive
