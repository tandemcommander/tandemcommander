---
title: UnCAB: one UTF-8 cabinet name with an unpaired surrogate makes the whole cabinet fail
type: bug
status: open
severity: 5
area: archives
source: measure:379
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: [tar-wtf8-names-read-in-code-page]
depends-on: []
reason: -
---

# UnCAB: one UTF-8 cabinet name with an unpaired surrogate makes the whole cabinet fail

## Problem

The UnCAB plug-in (shipped) checks a cabinet entry's name with a strict UTF-8 probe. When the entry carries `_A_NAME_IS_UTF`, a name that fails the probe is refused (`CabNameToU8` returns FALSE); the notify callback then returns -1, which aborts `FDICopy`, so `ListArchive` shows an FDI error and fails: **one such entry makes the whole cabinet impossible to open**, and an extraction stops part-way. A Windows packer that writes an unpaired surrogate (a name NTFS allows) as the 3-byte WTF-8 form, as the vendored 7-Zip converter does, produces exactly such a name. Without the flag (`fdintPARTIAL_FILE`) the same bytes are read in the code page - another name.

## Evidence

Found by feature 379 (`specs/379-plugin-encoding-verdicts/fix-log.md`, *Re-judged rows*; feature 255's review 2 NOTE 1), by reading at 3e0da39c: `src/plugins/uncab/uncab.cpp` `CabNameToU8` (`validU8` from the strict probe; `isUTF && !validU8` -> FALSE; otherwise `CP_ACP`); `src/plugins/7zip/7za/CPP/Common/UTFConvert.cpp` `Utf16_To_Utf8` (3-byte form of an unpaired surrogate with the Windows default flags 0). Reported by `python tools/check_encoding.py --plugins` (`strict-probe-rejects-wtf8`, `uncab/uncab.cpp`). Not measured: which CAB writers produce such names; no cabinet was built.

## Expected

A cabinet entry whose UTF-8 name is valid WTF-8 is listed and extracted under that exact name; a flagged name that is not even WTF-8 is still refused; `check_encoding.py --plugins` no longer reports `uncab/uncab.cpp`.

## Approach

Accept the WTF-8 form in the probe (as the core's `SalU8ToW` does) and keep the refusal for anything else. A fixture needs a CAB writer that stores the name bytes as given (makecab with a UTF-8 directive file, or a small FCI program).

## Notes

Severity at the lower end of the band: only names with an unpaired surrogate, and the packer path is shown by reading only. Sibling items: `tar-wtf8-names-read-in-code-page`, `unmime-wtf8-name-read-in-code-page`.

## Log

- 2026-11-01 — created (source measure:379)
- 2026-11-01 — Problem corrected and severity 4 -> 5 after review 1 of feature 379 (the refusal aborts the whole cabinet)
- 2026-11-01 — severity and title after review 1 of feature 379
- 2026-11-01 — moved to Next position 2
