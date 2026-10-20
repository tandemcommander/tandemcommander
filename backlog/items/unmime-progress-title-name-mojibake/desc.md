---
title: UnMIME: the extraction progress title shows a non-ASCII mail file name as mojibake
type: bug
status: new
severity: 1
area: other-plugins
source: measure:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# UnMIME: the extraction progress title shows a non-ASCII mail file name as mojibake

## Problem

UnMIME (not shipped: `plugins.cfg` unmime=off) titles its extraction progress dialog
"Unpacking Mail File - %s" from the code-page `LoadStr` template and the UTF-8 name of the mail
file. In a translation whose template has letters outside ASCII (Czech: "Extrahování e-mail
souboru - %s"), the composed title is not valid UTF-8, the core's progress dialog
(`SalSetWindowTextU8`, `dialogs3.cpp`) falls back to the code page, and a mail file name with
non-ASCII letters becomes mojibake. English is not affected.

## Evidence

By reading, at e849e68c: `src/plugins/unmime/unmime.cpp`, both `_snprintf_s(title, _TRUNCATE,
LoadStr(IDS_EXTRTITLE), SalamanderGeneral->SalPathFindFileName(fileName))` sites (unpack of
selected files and unpack of the whole archive); the Czech template in
`translations/czech/unmime.slt`. Reported by `python tools/check_encoding.py --plugins`
(`mixed-composition`); verdict in `specs/255-plugin-encoding-findings/verdicts.md` (branch `255-plugin-encoding-findings`).

## Expected

Czech UI: extracting from `zpráva-žluťoučký.eml` shows the progress title with the name spelled
correctly; `check_encoding.py --plugins` no longer reports `unmime.cpp`.

## Approach

`LoadStrU8` (`splloadstru8.h`) for the template, as feature 130 did in 13 other plug-ins; keep the
bounded buffer and trim a torn tail with `SplU8TrimTornTail`.

## Notes

The plug-in is not shipped and the effect needs a translation, hence severity 1.

## Log

- 2026-10-20 — created (source measure:255)
