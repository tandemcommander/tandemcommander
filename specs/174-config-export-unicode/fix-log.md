# Fix log: 174 - the configuration export keeps every letter and never deletes an older backup

Backlog: NEXT-WORK items 5d and 5e (found by 172 and its review).

## Measured (before)

Probe `probe/cfg_content_probe.ps1` (hidden desktop, ACP 1250; fixture values written wide into
`...\0.1\Probe174`, the product's key backed up and restored): `probe/result_before.txt`.

- **Values** (row VAL): Czech letters survived (code page 1250), Cyrillic and an emoji were
  exported as `?` (`"Cyr"="?????? ???"`) and came back so; REG_EXPAND_SZ and REG_MULTI_SZ came back
  with '?' AND trailing garbage (`...???\0Ě`) - reglib read them with `RegQueryValueExA` (code
  page) while the core stores UTF-16 (`SalRegSetValueExW8`), wrote REGEDIT4, and the import's
  hex(2)/(7) handling did not match.
- **Names** (row NAME): a value or key name outside the code page made **the whole export fail**
  ("Error reading configuration from registry") - `RegEnumKeyExA` gave `????`, the open failed.
- **An older backup was deleted** (row KEEPOLD): `backup.reg` held open by another program that
  shares reading and deleting; the export could not open it for writing (CREATE_ALWAYS), reported
  the error - and `mainwnd3.cpp` then deleted the file. The same deletion followed any failed
  export (also "Error reading configuration from registry", seen in the first run: the backup was
  gone after the NAME fixture had made the export fail).
- A "Windows Registry Editor Version 5.00" (UTF-16) file imported Cyrillic as `?` (REG5):
  `ConvertIfNeeded` converted it with `CP_ACP`.
- Control: a REGEDIT4 file in code page 1250 (as every older version wrote) imported Czech
  correctly (LEGACY) - it must stay so.

## Work

- `src/reglib/src/registry.cpp` (the core's build): the system registry by the W functions; names
  as UTF-8 (a name that is not UTF-8 - from an older REGEDIT4 file - as code page,
  `SalLegacyToU8Alloc`), values through `SalRegQueryValueExW8` / `SalRegSetValueExW8` (strings
  UTF-8; legacy code-page data accepted as before), `ClearKeyAux` wide with a buffer of the longest
  value name.
- `src/reglib/src/regcopy.cpp`: one name buffer of 3 x 16,384 + 1 bytes shared by the recursion -
  with `MAX_PATH`, a longer name ended the enumeration as if there were no more (silently
  incomplete export).
- `src/reglib/src/reginmem.cpp`: the dump is composed in memory (UTF-8, a sink in place of
  `WriteFile` over the dump functions), `DumpToBuffer` returns it as a UTF-16 "Windows Registry
  Editor Version 5.00" file with its BOM (what regedit writes); REG_EXPAND_SZ / REG_MULTI_SZ data
  as UTF-16 in the hex lines; no DBCS lead-byte test on UTF-8.
- `src/reglib/src/regparse.cpp`: a v5 file becomes UTF-8 (WTF-8, BOM kept - `Parse` recognises the
  UTF-8 BOM header); the DBCS scanning only for REGEDIT4 files; hex(2)/(7) of v5 files UTF-16 ->
  UTF-8. REGEDIT4 files are parsed as before (code page; `SalRegSetValueExW8` stores code-page data
  as such).
- `src/salamdr2.cpp` `WriteExportedConfiguration`: a temporary file next to the target, written,
  flushed, then `SalReplaceWithTempW` (rule 105); failure: the target as it was, the temporary file
  deleted, `IDS_EXPORTCFG_FILEERR`; a target gone with the content only in the temporary file:
  `IDS_VIEWERCOPYKEPTTEMP` (173) names it. `src/mainwnd3.cpp`: no deletion after a failed export.

No new string, no plug-in interface change (reglib is the core's own). Build: BUILD SUCCEEDED;
`check_encoding.py` TOTAL 0.

## Review

Independent refute-first review (read-only): nothing CRITICAL; the conversion lengths (explicit
lengths count their own terminator), `DumpToBuffer`'s sizes, the hex branch's early return, the
`WriteFile` macro's scope, the v5 BOM header path, the `mbcs` flag, the hex(2)/(7) buffer reuse,
GetSize / GetValue consistency, the default value, `.hidden`, `ClearKeyAux`, the replace path and
the plug-in ABI (`CSalamanderRegistryExAbstract` is the core's own) checked.
- SHOULD-FIX, taken: the memory registry's `CreateOpenKey` copied a key name into
  `TCHAR[256]` with a bound that let one byte past it - in UTF-8 128 Cyrillic letters overran the
  stack, 129-255 failed the export; now 3 x 255 + 1 bytes, the bound leaves the terminator.
- SHOULD-FIX, taken: `SalRegQueryValueExW8` / `SalRegSetValueExW8` (`salamdr6.cpp`, core-wide)
  held a value name in `WCHAR[512]` - a longer name (a plug-in may write one) failed the whole
  export; a longer one goes to the heap now. Also the dump's key-path buffer on the heap (64 K).
  Probe rows LONG (601 / 200 Cyrillic characters): the old build fails the export, the new one
  round-trips both.
- Accepted / recorded: the export is about twice as large (UTF-16) against the import's 10 MB cap
  (real configurations ~0.2 MB); `IDS_EXPORTCFG_FILEERR` has one `%s` - the error itself is not
  shown (as before); REGEDIT4 text is taken as UTF-8 when it is valid UTF-8 (the core's usual
  guess); older than 174 and unchanged: key headers escape `"`, `\r` / `\n` escapes, `hex(1)` of
  v5 files, an `EnumValue` failure ends the copy silently.

## Measured (after)

The same probe: every row PASS (`probe/result_after.txt`, 32 / 0; before 14 / 10) - the file is UTF-16 v5, every value and
name round-trips through export and `-C` import, the LEGACY code-page file still imports Czech,
KEEPOLD: the backup is replaced in one step; KEEPLOCK (shared for reading only): the export fails,
the backup keeps its old content, no temporary file left. Registry identical after every run.
