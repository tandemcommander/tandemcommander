# Research: feature 124 (GitHub issue #3)

## R1 - Is the report reproducible, and exactly where?

**Measured** on the Debug tree of the 0.1.9 release commit (`Debug_x64_v019`), hidden desktop,
ACP 1250, `probe/regkey_probe.ps1 -Expect before`, result `probe/regkey_result_before_v019.txt`,
crops `probe/shots/before_<lang>_{panel,info,sel}.png`.

| Language | Size column | Info line (focused key) | Info line (selection) | Find window Size cell |
|---|---|---|---|---|
| english | KEY | ok | ok | KEY |
| czech | KLÍČ ok | **KL��** | **1 vybran� kl��** | KLÍČ |
| german | Schlüssel ok | **Schl�ssel** | **1 ausgew�hlter Schl�ssel** | Schlüssel |
| french | CLE ok | ok | **1 cl� s�lectionn�e** | CLE |
| dutch | ok | ok | ok | ok |
| hungarian | ok | ok | **1 kijel�lt kulcs** | ok |
| romanian | ok | ok | ok | ok |
| slovak | KĽÚČ ok | **K���** | **1 vybran� k���** | KĽÚČ |
| spanish | ok | ok | ok | ok |

- **Decision**: the report is valid for the information line. Its claim about the Size column
  is not reproducible (see R2). The selection line is a second place with the same cause.

## R2 - Why is the Size column right today?

`CFilesBox` cell drawing (`src/fileswn4.cpp`, "column text is UTF-8 ... -1 = byte-wise A-call
fallback") converts the cell with `SalU8ToW`; when that fails it draws the bytes with the `A`
call, i.e. as code page. `KL\xCD\xC8` is not valid UTF-8, so the fallback draws `KLÍČ`. The
information line (`CStatusWindow`, `SalU8ToWDisplayAlloc`) has no such fallback: invalid bytes
become U+FFFD.

- **Decision**: the column must not rely on that fallback (a code-page text can be valid UTF-8
  by accident, and the fallback depends on the machine's code page); after the fix the cell is
  valid UTF-8 and takes the wide path.

## R3 - What does the proposed patch break?

`CFoundFilesData::GetText` (`finddlg.cpp`, `CI_SIZE`) does `StrToWStr(buffer, 100, KeyText)`,
and `StrToWStr` is `MultiByteToWideChar(CP_ACP, ...)`. With `KeyText` in UTF-8 the Find window
would show `KLĂŤÄŚ`. The report's patch does not touch that line.

- **Decision**: keep the wide original (`KeyTextW`) and give it to the Find window.
- **Alternative rejected**: `U8ToWStr(buffer, 100, KeyText)` there - a round trip of a text we
  already have in wide form.

## R4 - Buffer size; "never cut"

Lengths of id 1007 in all eleven translations (static check `probe/check_key_lengths.py`):
longest in UTF-16 is 9 units (`Schlüssel`), longest in UTF-8 is 12 bytes (Russian `РАЗДЕЛ`).
The old `char[10]` held 9 bytes: the German word in UTF-8 (10 bytes) would lose its last letter,
the Russian one would be cut inside a character.

- **Decision**: `WCHAR KeyTextW[32]`, `char KeyText[100]` (31 UTF-16 units give at most 93
  bytes of UTF-8, so the second conversion cannot fail when the first copy fitted). A resource
  text of 32 units or more, or an empty one, is replaced by `KEY` - refused, not shortened.
  `TRANSFER_BUFFER_MAX` is 1024, so the cell copy always fits.

## R5 - The selection templates

`ExpandPluralSelection` and the size prefix in `GetInfoLineContent` (`fs4.cpp`) take
`LoadStr(IDS_SELECTED1/2/3, IDS_SELECTEDSIZE)` into `SG->ExpandPluralString` and `SalPrintf`.
`ExpandPluralString` (`src/salamdr4.cpp`) works byte by byte and its syntax characters
(`{ } | : \`) are ASCII; UTF-8 lead and continuation bytes are all >= 0x80, so a UTF-8 template
passes through unchanged (the same holds for the plug-in's `SalPrintf`, a `vsnprintf`).
`SG->LookForSubTexts` then finds the `<...>` hot texts by ASCII delimiters as well.

- **Decision**: a local `LoadStrU8(resID, buf, size)` in the plug-in (wide resource text to
  UTF-8; when it does not fit, the code-page text is used whole, as before - no cut). Template
  buffers 200 -> 600 bytes.
- **Alternative rejected**: a new `LoadStrU8` service in the plug-in interface - the interface
  is append-only and 107 is fresh; one plug-in converting its own wide text needs no service.

## R6 - What stays out

- **Column names** (`column.Name`, `column.Description`): the core's own columns are filled with
  `LoadStr` too (`src/fileswn9.cpp`) and the header draws code-page text; they are right wherever
  the language fits the code page. Measured: only Spanish `Tamaño` loses its tilde on this
  Central European Windows (`Tamano`), in the core's columns in the same way. A core matter.
- **Message boxes of the plug-in** that put a UTF-8 registry name into a code-page template
  (`fs3.cpp` `IDS_CONFIRNNONEMPTYDELETE`, `IDS_REPLACEVAL`; `fs2.cpp` `IDS_ENUMKEY` with
  `GetErrorText`; `fs5.cpp` `IDS_CREATETARGET`): the class of GitHub issue #7 - examined with
  that feature.

## R7 - How to read owner-drawn text in a test

The panel and the information line are owner-drawn; no message returns their text.

- **Decision**: `PrintWindow` of the main window (works on the hidden desktop), crop of the
  child window's rectangle enlarged three times, `Windows.Media.Ocr` (Czech recognizer present).
  A verdict is "holds the expected word exactly" or "with diacritics folded" (the Czech
  recognizer does not know every foreign letter); every crop is saved and looked at. U+FFFD is
  recognized as some other letter, so a garbled text never matches. The Find window is a real
  list view: `LVM_GETITEMTEXTW` gives its cells exactly.
- **Alternatives rejected**: a debugger breakpoint on the drawing call (slow, fragile); a test
  host that loads `regedt.spl` with a fake `CSalamanderGeneral` (large, and it would not show
  what the user sees).

## R8 - Findings of the independent review (added the same day)

A separate agent reviewed the first fix refute-first (read-only). It confirmed the changed lines
and found that the fix did not finish the line it set out to fix:

| Finding | Evidence | Decision |
|---|---|---|
| `(Default)` is given to the panel as code-page text (`fs2.cpp`, both places that make the item) | probe rows `DEFAULT`: wrong on 0.1.9 in Czech, French, Hungarian, Slovak | fixed: `DupStrA(LoadStrW(IDS_DEFAULTVALUE))`; the same text in the overwrite question's path (`fs5.cpp`) through `LoadStrU8` |
| the data preview of `REG_SZ` / `REG_EXPAND_SZ` / `REG_MULTI_SZ` is converted with `CP_ACP`, and its `...` is placed at a byte position | probe rows `DATA`, `LONG`: wrong on 0.1.9 in all nine languages | fixed: UTF-8 preview of the first `MAX_DATASIZE` units, at most `MAX_DATASIZE` bytes with the terminator, `...` after a whole character |
| `LoadStrW` never returns NULL or an empty text (a missing string gives `ERROR LOADING WIDE STRING`) - the NULL tests were dead code and the comment "a missing text leaves KEY" was wrong | `src/salamdr2.cpp` | tests removed, comments corrected |
| `LoadStrU8`'s fallback cut the code-page text although its comment said "whole" | `regedt.cpp` | on refusal the result is an empty text; unreachable with the 600-byte buffers |
| date and time of a key come from the `A` locale functions | `fs4.cpp` | `GetDateFormatW` / `GetTimeFormatW` + UTF-8 |
| `tools/check_encoding.py` does not scan `plugins/` | the script, `sources()` | recorded; widening the guard to plug-ins is a matter for the issue #7 feature |

Left out, listed for the issue #7 feature (message boxes that mix a code-page template with a
UTF-8 name): `fs3.cpp` `IDS_CONFIRNNONEMPTYDELETE`, `IDS_REPLACEVAL`; `fs2.cpp` `IDS_ENUMKEY`;
`fs5.cpp` `IDS_CREATETARGET`, the plural copy/move texts; `utils.cpp` the error helper.
