# Research: 7zip plug-in follow-ups

## R1 — Why updated and new configurations differ (item c)

`CSalamanderConnect::AddPanelArchiver` (`src/plugins1.cpp`) has two modes.
A plug-in that newly gains "panel view" searches **all** records for an
overlap and takes the first one over (unpacker = plug-in; with `edit` FALSE
the packer is kept). An installed plug-in calling with `updateExts` TRUE only
looks at records whose unpacker is already the plug-in and appends the missing
extensions to the **first** of them. So on an update `rar;r##` joined the
plug-in's `7z` record (packer = the plug-in → "not supported" when packing
into RAR), while the core's own `rar;r##` record (unpacker = RAR console,
which has no list command since feature 084) stays stored and is skipped by
`CPackerFormatConfig::BuildArray`.

**Decision**: in the mode *extension update, view only* the core first looks
for a record whose **external** unpacker can never browse
(`PackBrowseTable[i].ListCommand == NULL`, i.e. by design, not "not
installed") and that holds a requested extension. Such a record is taken over
for viewing (packer kept), every requested extension it holds is considered
done, and the same extensions are removed from the plug-in's other records
(this is what repairs a record joined by a development build of 087).
Extensions the plug-in already serves in any of its records are not added
again. Whatever is left goes to the unchanged legacy path, which 11 other
call sites in tar, uniso, unmime and zip rely on.

*Alternatives rejected*: a core configuration migration (a new core
configuration version for one plug-in's association);
`ForceRemovePanelArchiver` from the plug-in (it cannot tell the joined record
from an already taken-over one, and would empty the latter).

## R2 — Surrogate names (item a)

The core's converters are WTF-8 since feature 066
(`src/common/salunicode.cpp`: strict Windows conversion first, a hand-written
encoder/decoder only when it fails). The contract of 066 excluded
`src/plugins/`: `src/plugins/shared/splunicode.h` still calls
`MultiByteToWideChar` / `WideCharToMultiByte` with the "invalid characters"
flags and returns failure, so `SplU8ToWExtAlloc` returns NULL for a path with
such a name and the plug-in cannot open the file; 97 plug-in source files use
these helpers. The 7zip plug-in's own pair (`structs.h`) calls 7-Zip's
`MultiByteToUnicodeString(…, CP_UTF8)`.

**Decision**: port the core's fallback into `splunicode.h` (header-only, same
algorithm, same rejection rules) and make the 7zip plug-in's pair use it.
Parity is proven in `saltests`, which can include both.

## R3 — Updating a cleaned name (item b)

`C7zClient::UpdateMakeUpdateList` merges two sorted lists by name: the files
to add (names from the panel = cleaned) and the archive items
(`GetArchiveItemList`, raw `kpidPath`). **Decision**: `GetArchiveItemList`
stores the cleaned form (`SalArcCleanItemPath`) in `CArchiveItem::Name`. The
name is used only for matching and for the overwrite question; items that
stay are copied by index, and delete matches by index
(`DeleteMakeUpdateList`), so nothing else changes.

## R4 — Verification

Unit tests: converter parity and round trips; the extension-list helpers.
Engine probe of 087 (regression). A registry probe drives the Debug build
over three stored configurations (0.1.8-shaped, 087-development-shaped,
empty) and compares the stored association records; it backs the registry
key up and restores it. Item b lives in the plug-in's list logic, which the
engine driver does not exercise; it is covered by review, and the GUI step
is owed.
