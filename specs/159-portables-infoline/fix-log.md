# Fix log: 159 - the Portables information line

Backlog: `specs/NEXT-WORK.md` 10b (found by 157's review).

## Cause (by reading)

`CWpdFsDeviceLevel::GetInfoLineContent` (`plugins/portables/wpdfsdevicelevel.cpp`) built "N vybrané
zařízení" from `SalamanderGeneral->LoadStr` and copied "Žádná zařízení" with `::LoadString` - both
code page - and the core draws the information line as UTF-8 (`CStatusWindow::SetText`). Device
names on the same line were UTF-8 already (`CP_UTF8`). Not driven: the information line exposes no
text; owed to a person: Portables in Czech, a device selected and none connected.

## Work

`SplLoadStrU8` (`splloadstru8.h`, as `fxfs.cpp` since 130) for both texts.

## Review (refute-first agent, 2026-10-14)

No defect: `SplLoadStrU8` keeps each text for the plug-in's lifetime (a critical section, no ring
buffer; a code-page fallback only on low memory); `TCHAR` is `char` in this plug-in (no UNICODE in
its project or props), the core's buffer is `char[1000]`; device names UTF-8 at intake, hot-text
offsets in bytes. The plug-in's other code-page texts reach sinks that convert them (052). Found,
pre-existing (NEXT-WORK 10c): `IDS_SELECTEDDEVICEFMT` "{!}%d selected device{2:s|0||1|s}" names a
parameter that does not exist - `ExpandPluralString` stops at the brace: always "N selected
device", and every translation copies the English "s" suffix.

## After

- Debug build clean; `check_encoding.py` TOTAL 0.
