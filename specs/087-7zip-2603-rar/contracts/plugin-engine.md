# Contract: the 7zip plugin and the engine (087, FR-006–FR-015)

## P1 — Loading and creating handlers

`7za.dll` is loaded from the plugin's folder with a wide path. Handlers are
created with `CreateObject(&clsid, &IID_IInArchive / IID_IOutArchive, …)`:

| Format | CLSID |
|---|---|
| 7z | `23170F69-40C1-278A-1000-000110070000` |
| RAR 1.5–4 | `23170F69-40C1-278A-1000-000110030000` |
| RAR5 | `23170F69-40C1-278A-1000-000110CC0000` |

The CLSID for opening comes from `SalArcDetectFormat` on the archive's first
8 bytes; a file whose signature does not match a registered format fails to
open with the plugin's "not an archive / unsupported" message. Creating and
updating use 7z only.

## P2 — Callback classes (source port, behaviour unchanged)

`CArchiveOpenCallbackImp`, `CExtractCallbackImp`, `CArchiveUpdateCallback`,
`CRetryableOutFileStream`, `CRetryableInFileStream` use the 26.03 macros
(`Z7_IFACES_IMP_UNK_n`, `Z7_IFACE_COM7_IMP`, `Z7_COM7F_IMF`), as
`UI/Client7z/Client7z.cpp` does. New interfaces exposed:

| Class | Adds |
|---|---|
| open callback | `IArchiveOpenVolumeCallback` (P3), `ICryptoGetTextPassword` (wide, P4), `IArchiveRequestMemoryUseCallback` (P5) |
| extract callback | `IArchiveRequestMemoryUseCallback` (P5) |

## P3 — Volumes

`GetProperty(kpidName)` → the file name of the volume the engine is
currently on (initially the opened file); `GetStream(name)` → an
`IInStream` on `<archive folder>\name` opened read-only with a wide path,
`S_FALSE` if it does not exist (the handler then reports a missing volume).
Both RAR naming schemes are produced by the handler itself (`RarVol.h`).

## P4 — Passwords

The prompt accepts any Unicode text; `CryptoGetTextPassword(BSTR*)` returns it
as UTF-16 (`SysAllocString`). A cancelled prompt returns `E_ABORT`. The
remembered password for the session is kept as UTF-16 and wiped on close.

## P5 — Memory requests

`RequestMemoryUse(flags, indexType, index, path, requiredSize, allowedSize*,
answerFlags*)`: allowed when `requiredSize ≤ min(4 GiB, physical memory / 2)`;
otherwise refused (`NRequestMemoryAnswerFlags::k_Limit_Exceeded`), and the
operation ends with the plugin's out-of-memory error. No dialog.

## P6 — Names

Every `kpidPath` passes through `SalArcCleanItemPath` (contract
`item-names.md`); alternate-stream items are not listed.

## P7 — RAR is read-only

Pack/update/delete on an archive whose handler is RAR or RAR5 → the plugin's
existing "operation not supported for this archive" message; nothing is
written.

## P8 — Registration (configuration version 4)

`CURRENT_CONFIG_VERSION` 3 → 4. Panel archiver extensions become
`7z;rar`; the custom unpacker mask `*.7z;*.rar`; both gated on
`ConfigVersion < 4` so a configuration the user edited is touched once. The
custom packer stays `7z`. With WinRAR's console installed, feature 084's RAR
packer stays the packer for `rar` (the core keeps packer and viewer roles
separate — 084 contract M2).
