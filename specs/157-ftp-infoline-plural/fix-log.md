# Fix log: 157 - the FTP client's information line

Backlog: `specs/NEXT-WORK.md` 10a (found by 156's review).

## Cause (by reading)

`plugins/ftp/fs4.cpp` (the information line, "size in bytes" branch, files only) calls
`SalamanderGeneral->ExpandPluralBytesFilesDirs` - the plug-in API (`zip.cpp`) called the core's
function without u8: the plural template came from `LoadStr` (code page), the number from
`NumberToStr` (UTF-8 thousands separator). The core draws the information line as UTF-8
(`CStatusWindow::SetText`, `SalU8ToWDisplayAlloc`): in Czech "bajt? v 3 vybran?ch souborech".
Feature 134 had fixed the blocks branch of the same function (`LoadStrU8`).

Not driven: the information line exposes no text to a probe (it draws itself); a pixel compare
with an FTP server was judged out of proportion for a one-argument change of an established
pattern. Owed to a person: an FTP panel with a bytes column, three files selected, Czech UI.

## Work

`CSalamanderGeneral::ExpandPluralBytesFilesDirs` passes u8 = TRUE; `spl_gen.h` says the text is
UTF-8; contract `contracts/expand-plural-bytes-utf8.md` (interface 107 unchanged; the only real
caller is the FTP client - demoplug and regedt only in commented-out examples).

## Review (refute-first agent, 2026-10-14)

No defect: `LookForSubTexts` takes byte offsets and the core maps them onto the UTF-16 mirror
(`stswnd.cpp`), the click-to-copy uses that mirror; output at most ~220 bytes of FTP's 1000; the
core's own information line already makes this exact call. Pre-existing, unrealistic: the core's
`number[50]` with a 20-digit value and a user-defined three-character non-ASCII separator.
**Found, the same class (NEXT-WORK 10b):** the Portables plug-in's information line at the device
level loads `IDS_SELECTEDDEVICEFMT` (`SalamanderGeneral->LoadStr`) and `IDS_NODEVICEINFOLINE`
(`::LoadString`) in the code page - "vybran? za?ízení".

## After

- Debug build clean; `check_encoding.py` TOTAL 0.
