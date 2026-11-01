---
title: TAR: a name with an unpaired surrogate stored as WTF-8 is read as another name
type: bug
status: new
severity: 4
area: archives
source: measure:379
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: [uncab-wtf8-flagged-name-refused, unmime-wtf8-name-read-in-code-page]
depends-on: []
reason: -
---

# TAR: a name with an unpaired surrogate stored as WTF-8 is read as another name

## Problem

The TAR plug-in (shipped) decides per name whether the archive's bytes are UTF-8 with a strict probe (`MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, ...)`); anything that fails it is read in the system code page. A Windows file name may hold an unpaired surrogate (NTFS allows it), and a Windows packer that converts UTF-16 to UTF-8 the way the vendored 7-Zip converter does writes it as the 3-byte WTF-8 form (`ED A0 80` for U+D800). The strict probe rejects that, so the whole name - every other letter too - is re-read in the code page: the listing shows mojibake (cp1250: `a<U+D800>č.txt` becomes something like `aí €ÄŤ.txt`) and extraction creates a file under that other name.

## Evidence

Found by feature 379 (`specs/379-plugin-encoding-verdicts/fix-log.md`, *Re-judged rows*; feature 255's review 2 NOTE 1), by reading at 3e0da39c: `src/plugins/tar/tardll.cpp` `ConvertNameToU8` (strict probe, then `CP_ACP`); `src/plugins/7zip/7za/CPP/Common/UTFConvert.cpp` `Utf16_To_Utf8` writes an unpaired surrogate as 3 bytes unless `Z7_UTF_FLAG_TO_UTF8_SURROGATE_ERROR` is set, and `g_Unicode_To_UTF8_Flags` is `0` on `_WIN32`. Reported by `python tools/check_encoding.py --plugins` (`strict-probe-rejects-wtf8`, `tar/tardll.cpp`). Not measured: whether 7-Zip's TAR writer (or another packer) routes names through that converter; no archive was built.

## Expected

A TAR entry whose name is valid WTF-8 (UTF-8 plus encoded unpaired surrogates) is listed and extracted under that exact name, as the core shows names; a name that is neither WTF-8 nor UTF-8 still takes the code-page fallback; `check_encoding.py --plugins` no longer reports `tar/tardll.cpp`.

## Approach

First build a fixture: a TAR whose name holds `ED A0 80` (Python `tarfile` with `encoding='utf-8', errors='surrogatepass'`), and check what the listing shows today. Then accept the WTF-8 form in the probe (a WTF-8 validator from `splunicode.h` / `SplU8ToW`-style decoding) and pass such bytes through verbatim.

## Notes

Severity at the lower end of the band: the name must hold an unpaired surrogate, which ordinary names never do, and the packer path is shown by reading only. Sibling items: `uncab-wtf8-flagged-name-refused`, `unmime-wtf8-name-read-in-code-page`.

## Log

- 2026-11-01 — created (source measure:379)
- 2026-11-01 — linked its sibling items (379)
