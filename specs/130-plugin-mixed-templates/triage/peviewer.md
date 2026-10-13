# Triage: peviewer (feature 130)

Read: all 22 lines with `LoadStr` (`peviewer.cpp`, `pefile.cpp`), `cfgdlg.cpp`, `cfg.cpp`, the
stream class in `pefile.h`, the three `%ls` places. No build, nothing run.

## 1. How the names are encoded

- The viewed file's name is UTF-8: `peviewer.cpp:294-299` (`SplU8ToWExtAlloc(name)` +
  `CreateFileW`, comment "'name' is UTF-8 since plugin interface 104"); the temporary file too
  (`peviewer.cpp:410-413`).
- The dump is written with the narrow CRT (`CFileStream::fprintf` -> `vfprintf`,
  `pefile.h:101-107`) into a text file the internal viewer shows.

## 2. Compositions

| Place | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `peviewer.cpp:307`, `322`, `338`, `354` (`MapFileToMemory`) | `IDS_ERR_OPEN_FILE` (cp; Czech `Nelze otevřít soubor %s.`) | name UTF-8 | `SalMessageBox` | **FIXED** x4: `LoadStrU8`, tail trim after the bounded `_sntprintf` |
| `peviewer.cpp:434` caption of the dump's viewer | `"%s - %s"` | name UTF-8, `IDS_PLUGIN_NAME` (cp; Czech `Prohlížeč spustitelných souborů`) | `CSalamanderPluginInternalViewerData::Caption`, `WholeCaption = TRUE` -> core `viewer3.cpp:52-55, 101-104` (`SalU8ToWAlloc` -> `SalSetWindowTitleW`, else the code page) | **FIXED**: `LoadStrU8`, trim |
| `peviewer.cpp:419` | `IDS_EXCEPTION` (cp) | name UTF-8 | `SalMessageBox` | RECORDED - unreachable: `DumpFileInfo` returns `TRUE` on every path (`pefile.cpp:1189`), so the branch never runs; left as it is |
| `peviewer.cpp:144-151` About | literal with `VERSINFO_COPYRIGHT` | `IDS_PLUGIN_NAME`, `IDS_PLUGIN_DESCRIPTION` (cp) | `SalMessageBox` | RIGHT AS IT IS (no name; the `©` of the literal is one code-page byte in the binary - the projects are compiled without `/utf-8` - so the text is code page as a whole. Not verified by a build) |
| `pefile.cpp:1177` | `"%s"` | `IDS_HIDDEN_SECTIONS` (cp) alone | the dump file | RIGHT AS IT IS (no composition; the dump is code-page text) |
| `peviewer.cpp:122-127`, `447-448`, `cfg.cpp` list titles | constant texts | - | core / list box | RIGHT AS IT IS |

Counts: **5 sites fixed** (2 rows), 4 right as they are, 1 recorded (unreachable).

`LoadStrU8` was added to `peviewer.cpp:70` (the plug-in's `LoadStr` has no declaration in a
header - it is used in this file only - so neither has `LoadStrU8`).

## 3. How to reach the fixed places (Czech)

1. **Caption** (easiest): F3 on `Žluťoučký kůň.exe` / `.dll` with the PE Viewer as the viewer:
   the title of the dump window reads `<name> - Prohlížeč spustitelných souborů`; before, the
   name was garbled (the title was not valid UTF-8 and went through the code page). English is
   the control (identical before and after).
2. **Cannot open** (`Nelze otevřít soubor <name>.`): plain F3 does **not** get there -
   `CanViewFile` (`peviewer.cpp:458-467`) maps the file silently first and declines, and the
   core takes another viewer. The message needs `ViewFile` without that check: the viewer
   chosen by hand (View With > Portable Executable Viewer) on an accented-name file that cannot
   be mapped - a zero-length `Příliš žluťoučký.dll` (`CreateFileMapping` fails,
   `peviewer.cpp:332-338`) or a file another program holds without sharing. Whether the core
   skips `CanViewFile` for a viewer chosen by hand was not read - to be confirmed when the
   probe row is written.

## 4. Other defects seen (not fixed)

1. **Narrow `%ls`** (`pefile.cpp:1819`, `2317`, `2499`) - not fixed, as instructed. The texts
   are converted by the CRT in the "C" locale (the plug-in never calls `setlocale`): a letter
   up to U+00FF is written as the single byte of its value (Latin-1 - right only where the
   code page is 1252 for that letter), and at the first letter above U+00FF the conversion
   fails and that `fprintf` call ends there (feature 129 measured this for `vsprintf`; for
   `vfprintf` it is read, not measured). What the dump loses:
   - `1819` (version resource, `StringFileInfo` key such as `CompanyName`): the key is cut at
     that letter; the `:`, the padding, the value and the line end come from separate calls
     (`1822-1832`) and are still written - the line reads `    <start of key>:   <value>`.
   - `2317` (`Runtime Version:`): the rest of the version string **and the `\n`** are lost -
     the next line of the dump is glued to this one.
   - `2499` (.NET assembly references): the rest of the name **and the `\n`** are lost - the
     next reference continues on the same line.
   The standard keys and names are ASCII; a file with a localized key or assembly name is
   needed to see it.
2. `pefile.cpp:1830` (and `1735-1746`, `dump_res.cpp:13`): version-resource **values** and
   resource names go through `WideCharToMultiByte(CP_ACP)` - a letter outside the code page
   becomes `?` (a Japanese `FileDescription` on a Czech system).
3. `peviewer.cpp:432-435`: the core cuts the caption at `MAX_PATH - 1` bytes
   (`viewer3.cpp:52`), so a long path loses the plug-in's name at the end of the title
   (display only, trimmed at a whole character by the core).
4. `peviewer.cpp:412-414`: `_wfopen` / `_tfopen` result is not checked before `DumpFileInfo`
   and `fclose` (`outStream == NULL` when the temporary file cannot be opened).
