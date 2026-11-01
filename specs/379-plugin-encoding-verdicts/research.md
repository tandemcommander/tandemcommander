# Research: 379 - verdicts for the plug-in encoding scan

## R1 - Reuse feature 255's verdicts

- Decision: carry over 255's 68 markers (SKILL.md 4.6), keep every verdict its two reviews left
  standing, re-check each marker whose file `main` changed since 255.
- Rationale: the item's *Log* says to continue from 255; 77 of the 78 findings are unchanged in file,
  rule and text at HEAD (fix-log, *Measurement*).
- Alternatives: re-read all 78 from scratch - repeats recorded work the skill says not to repeat
  unless HEAD changed the site.

## R2 - Row 41 (FTP listing field probe)

- Decision: verdict *fixed* (feature 269); the marker is not carried.
- Rationale: the probe is gone at HEAD (`SalFtpListingFieldIsU8`), the scan no longer reports it.

## R3 - CheckVer row 3

- Decision: *real defect, latent* (plug-in off), own item.
- Rationale: module names reach the list box from the registry (UTF-8 facade) and the update script
  (treated as UTF-8 by `logwnd.cpp`) and are composed with a code-page template - 255's reason
  ("code page like the template") holds only for ASCII names (255 review 2 SHOULD 1).

## R4 - TAR / UnCAB / UnMIME archive-name probes (rows 67, 68, 75)

- Decision: *real defect, latent*, one item per plug-in.
- Rationale: the vendored 7-Zip `Utf16_To_Utf8` writes an unpaired surrogate as its 3-byte form with
  the Windows default flags (`g_Unicode_To_UTF8_Flags = 0`), so 255's premise "the WTF-8 form does
  not arise in an archive" does not hold; the probe then reads the whole name in the code page (TAR,
  UnMIME) or refuses the entry (UnCAB with `_A_NAME_IS_UTF`).
- Alternatives: keep them false positives with a weaker reason - would hide a reachable (if rare)
  wrong name in two shipped plug-ins; review 2 already doubted it.

## R5 - Code Viewer `config.cpp` (4 new findings)

- Decision: *false positive*, markers with reason (379).
- Rationale: a conversion table's name (code-page bytes from `EnumConversionTables`, feature 262)
  stored in the registry as UTF-8; it is not a name from the core and cannot hold a surrogate; a
  name that does not convert exactly is stored / read as `""` (the system code page).

## R6 - The strict-scan follow-up

- Decision: `plugin-encoding-scan-strict-in-build` gets the new items of shipped plug-ins (TAR,
  UnCAB) as `depends-on`.
- Rationale: FR-007; the strict scan can only become strict once every shipped real defect is fixed.
