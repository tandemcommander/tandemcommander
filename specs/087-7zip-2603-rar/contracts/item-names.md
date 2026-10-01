# Contract: cleaning names taken from an archive (087, FR-013/014)

Module: `src/common/salarcname.h` — header-only, pure, no globals; included
by the 7zip plugin and `saltests`. Text is UTF-8 (the plugin converts the
engine's UTF-16 `kpidPath` with `UStringToU8` first).

## N1 — `SalArcCleanItemPath(const char* in, char* out, int outSize)` → BOOL

Produces a **relative** path made of clean components, separated by `\`.

1. `/` is treated as `\`.
2. A leading drive (`X:`), a UNC/device prefix (`\\server\share\`,
   `\\?\`, `\\.\`) and any leading `\` are removed.
3. The path is split at `\`; empty components and `.` are dropped;
   **`..` components are dropped** (never climb).
4. In each remaining component:
   - `:` → `_` (no alternate data stream can be addressed);
   - `<`, `>`, `"`, `|`, `?`, `*` and characters `< 0x20` → `_`;
   - trailing dots and spaces are replaced by `_` (Windows would strip them,
     which could merge two names or produce an empty one);
   - a component equal (case-insensitive) to a reserved device name — `CON`,
     `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`, also followed by a
     dot and an extension — gets a `_` prefix.
5. If nothing remains, the result is `_` (an item always has a name).
6. Bytes ≥ 0x80 are copied unchanged (UTF-8 sequences are never split; a
   multi-byte character never contains an ASCII delimiter).

Returns FALSE (and an empty `out`) only when `outSize` is too small; the
result is never longer than the input + 1 + (one `_` per component).
Idempotent: cleaning a clean path returns it unchanged.

## N2 — `SalArcDetectFormat(const BYTE* head, int headLen)` → int

`1` = 7z (`37 7A BC AF 27 1C`), `2` = RAR 1.5–4 (`52 61 72 21 1A 07 00`),
`3` = RAR5 (`52 61 72 21 1A 07 01 00`), `0` = unknown. Reads at most 8 bytes.

## N3 — `SalArcIsRarExtension(const char* name)` → BOOL

TRUE for `.rar` (case-insensitive). Volume detection for display:
`SalArcRarVolumeIndex(name)` returns the 1-based part number of
`*.partN.rar` (N ≥ 1), 1 for a plain `.rar`, N + 2 for `.rNN`, 0 otherwise —
used only to warn when a non-first part is opened.

## N4 — where it is applied

| Site | What |
|---|---|
| `7zclient.cpp` `AddFileDir` (listing) | the panel name = `SalArcCleanItemPath(kpidPath)`; items with `kpidIsAltStream` = true are skipped |
| `extract.cpp` `GetStream` | `NameInArchive` is cleaned again before `SalPathAppend` (defence in depth) |
| `7zclient.cpp` (open) | the handler CLSID comes from `SalArcDetectFormat` of the first bytes |

## N5 — tests (`saltests`, `TestArcNames087`)

Every rule above, plus a hostile corpus: `..\..\x`, `a\..\..\b`, `C:\x`,
`\\srv\sh\x`, `\\?\C:\x`, `/etc/passwd`, `a:b`, `x::$DATA`, `con`, `CON.txt`,
`nul.`, `a.`, `a ` , `a\.\b`, `.\.\`, `""`, control characters, UTF-8 names
(Czech, Chinese, emoji), very long names (buffer limit), and idempotence.
