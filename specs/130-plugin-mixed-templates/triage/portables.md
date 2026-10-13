# Triage: portables (feature 130)

Read: every resource-text use in the plug-in's own sources (`fx.cpp`, `fxfs.cpp`,
`wpdfsdevicelevel.cpp`; the plug-in loads texts with `CFxString::LoadString` / `Format(id)`,
`::LoadString` and once `SalamanderGeneral->LoadStr` - a search for `LoadStr(` alone finds one
line), plus `Format`, `StringCch*`, `ShowMessageBox`, `SalMessageBox`. `wtl/*.h` (the WTL
library: 6 `LoadString` wrappers) was not triaged - library code, none of it called with a
name by the plug-in's sources. No build, nothing run.

## 1. How the names are encoded

- `CFxString` is `ATL::CStringT<char>` (`fx.h:83`): `LoadString` / `Format(UINT)` load with the
  `A` API - **code page**.
- Device and object names are converted from UTF-16 with `CP_UTF8` (`wpdhelpers.h:32-35`,
  `device.cpp:69-72`); the path the core hands over (`userPart`) is UTF-8. So a path of this
  file system is UTF-8.
- `FxGetWin32ErrorDescription` is `FormatMessageA` (`fx.cpp:759-790`) - code page;
  `FxGetErrorDescription` gives that, or a text of the plug-in's own resources (code page), or
  `0x%08X`.

## 2. Compositions

| Place | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `fxfs.cpp:767-785` `ShowChangePathError` | `IDS_FX_CHANGEPATHERRORFMT` (cp; **every** translation has typographic quotes: `Cesta: „%s“ ... Chyba: %s`) | `fsName:path` UTF-8; error text code page (`FormatMessageA` / resource) | `SalamanderGeneral->ShowMessageBox` | **FIXED**: template by `SplLoadStrU8(SalamanderGeneral, FxGetLangInstance(), id)`, the error text through `SplLegacyToU8Alloc`, `CFxString::Format` (heap, never cut) |
| `fx.cpp:187-205` About | literal with `VERSINFO_COPYRIGHT` | plug-in name and description (cp) | `SalMessageBox` | RIGHT AS IT IS (all code page, no name) |
| `wpdfsdevicelevel.cpp:254-262` info line, selected devices | `IDS_SELECTEDDEVICEFMT` (cp, plural) | number | the panel's information line (`buffer`) | RIGHT AS IT IS (number + code page) |
| `wpdfsdevicelevel.cpp:285` | `IDS_NODEVICEINFOLINE` alone (`::LoadString` A) | - | information line | RIGHT AS IT IS |
| `wpdfsdevicelevel.cpp:266-280`, `fx.cpp:630-650` info line of a device | none - manufacturer, model / name (UTF-8) joined by `", "` | - | information line | RIGHT AS IT IS (no resource text) |
| `fx.cpp:370-376` | plug-in name, description | - | core | RIGHT AS IT IS |
| `fx.cpp:798-807` | error description alone | - | caller | RIGHT AS IT IS (the piece converted in the fixed row) |

Counts: **1 fixed**, 6 rows right as they are, 0 recorded.

No `LoadStrU8` function was added (the plug-in has no `LoadStr` of its own either - it uses
`CFxString`); the one place calls `SplLoadStrU8` directly. `fxfs.cpp` includes
`<splloadstru8.h>`.

## 3. How to reach the fixed place

Any translated user interface (all of them have a non-ASCII quote in the template), a phone or
camera connected whose name or a folder of it has a letter outside ASCII - or simply a typed
path: Change Directory (Shift+F7) to `wpd:\Žluťoučký kůň` (a device / folder that does not
exist). The box `Cesta: „wpd:\...“ / Chyba: ...` showed the path garbled before (and with an
ASCII path it showed the Windows error text right by accident of everything being code page).
The fs name (`wpd` here) is whatever the plug-in registered - take it from the panel.
Without any device connected the typed path is still refused with this box (read:
`fxfs.cpp:285`, `333`; not measured).

## 4. Other defects seen (not fixed)

1. `wpdfsdevicelevel.cpp:261`: `StringCchPrintf(buffer, 1000, buf, selectedDirs)` and `285`
   `::LoadString(..., buffer, 1000)` assume the caller's buffer is 1,000 characters (the
   interface's contract for the information line - not checked here).
2. `fx.cpp:759-790`: `FormatMessage` with language id 0 and `FORMAT_MESSAGE_IGNORE_INSERTS` -
   an `HRESULT` that is not a Win32 error has no text and the box shows `0x8xxxxxxx` only.
3. `fxfs.cpp:774-775`: `GetBuffer(MAX_PATH)` for `GetPluginFSName` - fine for an fs name.
