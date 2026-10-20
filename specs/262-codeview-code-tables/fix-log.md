# Fix log - 262 Code Viewer code tables

Backlog item `codeview-code-tables-for-single-byte-files` (070 review F16, FR-024).

## Measurement before (HEAD bf05ffc9, main)

- Site: `src/plugins/codeview/intake.cpp` `CvLoadFile` - `UINT codePage = CP_ACP;`, a forced
  `cvEncAnsi` also `CP_ACP`; `CvDecode` decodes `cvEncAnsi` with `MultiByteToWideChar(codePage)`.
  No call of `EnumConversionTables` / `GetConversionTable` in the plug-in.
- Menu: `viewer.cpp` `CViewerWindow` builds *Encoding* from a fixed five-entry array;
  `CycleEncoding` wraps modulo 5; `CM_ENCODING_FIRST + i < +5` in `WM_COMMAND`.
- Reachable: F3 on a `.bat` / `.ini` / source file opens the Code Viewer (default claimed types);
  a file without BOM that is not valid UTF-8 / UTF-16 takes the `cvEncAnsi` path.
- Machine: ACP 1250 (`[Text.Encoding]::Default.CodePage`, `HKLM\...\Nls\CodePage\ACP`).
- Reproduction (Python, the same decode the plug-in does with CP_ACP = 1250):
  `cp852.bat` first line as cp1250 -> "Pý˘lię §luśouźkě k…ĺ Łpŕl Ô belsk‚ ˘dy" (correct, cp852:
  "Příliš žluťoučký kůň úpěl ďábelské ódy"); `iso8859-2.ini` as cp1250 -> "Přílią ľlu»oučký kůň"
  (correct: "Příliš žluťoučký kůň").
- Built-in viewer (for parity): `CCodeTables::InitMenu` lists every table of the active
  `convert\<dir>\convert.cfg`; `SetCodeType` -> `CodeTable` applied to bytes, drawn with `TextOut`
  (A, ANSI font) = system code page; default conversion `Configuration.DefaultConvert` (*Set as
  default*), `CodePageAutoSelect` TRUE by default.

## Decisions

See spec *Clarifications* (autonomous run). Persisting the name: the plug-in registry facade is UTF-8
(`SalRegSetValueExW8`), so the code-page name is converted on save / load (research R3).
