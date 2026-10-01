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

`GetProperty(kpidName)` → always the file name of the opened file (the
first part); the handler derives the names of the other parts from it.
`GetStream(name)` → an `IInStream` on `<archive folder>\name` opened
read-only with a wide path, `S_FALSE` if it does not exist (the handler then
reports a missing volume) or if `name` contains `\`, `/` or `:`.
Both RAR naming schemes are produced by the handler itself (`RarVol.h`).
Every part opened is recorded (`C7zClient::OpenedVolumes`): *Unpack and
delete* hands all of them to the core, so the whole set is deleted, not only
the first part.

## P4 — Passwords

The prompt is the plugin's ANSI dialog (cluster B-1): its text is in the
system code page and is converted to UTF-16 with the code page
(`GetUnicodeString`); `CryptoGetTextPassword(BSTR*)` returns it as UTF-16
(`SysAllocString`). Characters outside the code page cannot be entered
(revised during implementation; spec FR-010). A cancelled prompt returns `E_ABORT`. The
password remembered for the open archive is kept as UTF-16 and its buffer is
overwritten when the archive is closed (`Wipe_and_Empty`; 0.1.8 assigned a
shorter text, which left the tail of a longer password); transient copies
made for one operation are not wiped.

## P5 — Memory requests

`RequestMemoryUse(flags, indexType, index, path, requiredSize, allowedSize*,
answerFlags*)`: allowed when `requiredSize ≤ min(4 GiB, physical memory / 2)`;
otherwise refused (`NRequestMemoryAnswerFlags::k_Limit_Exceeded`), and the
operation ends with the plugin's out-of-memory error. No dialog.

## P6 — Names

Every `kpidPath` passes through `SalArcCleanItemPath` (contract
`item-names.md`); alternate-stream items are not listed.

## P6b — Links and aborted items

Items with a non-empty `kpidSymLink` or `kpidHardLink`, and items whose
attributes carry the Unix symbolic-link mode (RAR4 and Unix-made 7z archives
have no link property), are listed but never extracted (no stream is
returned; their operation result is ignored); after the operation the plugin
reports how many link entries were skipped, and the operation does not count
as complete.

**Results** (`SetOperationResult`), extraction:

| Result | What the plugin does |
|---|---|
| `kOK` | file time and attributes set |
| `kWrongPassword` (RAR5) | the file just created is deleted, one message, the remembered password is forgotten, the operation stops (`E_ABORT`) |
| `kUnsupportedMethod` | message, the file is deleted |
| any other (data or CRC error, unexpected end, damaged headers, …) | the *delete or keep* question, as 0.1.8 asked for a data error only |
| any non-OK result for an item that has no output file of its own (skipped at the overwrite prompt, not selected) | counted, nothing deleted |

Any non-OK result makes the operation incomplete (the caller reports
failure, so the core deletes nothing). After an operation with errors that
used a password, the remembered password is forgotten: 7z reports a wrong
password as a plain data error, and the next operation must ask again.

**Cancel**: only the file this callback opened for the *current* item is
deleted (`HaveOutFile`). 0.1.8 deleted "the last named file" whenever any
stream had ever been created — after *Skip* at the overwrite prompt that was
the user's own existing file.

## P7 — RAR is read-only

Pack/update/delete on an archive whose handler is RAR or RAR5 → the plugin's
existing "operation not supported for this archive" message; nothing is
written.

## P8 — Registration (configuration version 4)

`CURRENT_CONFIG_VERSION` 3 → 4. The custom unpacker mask becomes
`*.7z;*.rar` once (`ConfigVersion < 4`); the custom packer stays `7z`. RAR is
registered for **view only**: `AddPanelArchiver("rar;r##", FALSE, updateExts)`
with `updateExts` true only for configurations 1–3.

*As built* (the first text of this section and 084 contract M2 expected one
outcome for both cases; reading `plugins1.cpp` `AddPanelArchiver` showed two):

| Case | Result |
|---|---|
| the plug-in is installed for the first time | the core's `rar;r##` record is taken over: unpacker = the plug-in, packer stays WinRAR (index 1) |
| an installed plug-in is upgraded (configuration 1–3) | the core only lets a plug-in extend **its own** record: `rar;r##` joins the plug-in's `7z` record, whose packer is the plug-in — packing into a RAR archive from the panel ends with "Update operations are not supported". The core's `rar;r##` record stays stored and is skipped at runtime (084 FR-017), so nothing claims `rar` twice |

*Pack* (Alt+F5) with *RAR (WinRAR)* is unaffected in both cases.
