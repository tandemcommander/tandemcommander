# Research - 263 import foreign registry keys

## R1 Where the restriction goes

- **Decision**: in `Parse()` itself, as an optional parameter, applied in both passes.
- **Rationale**: delete lines (`[-key]`) leave no trace in the memory registry (the key does not
  exist there), so a check of the memory tree after the first pass cannot see them; only the parser
  sees every line. Applying it to the writing pass too (FR-004) means the registry can never be
  touched outside the root, even if the check pass were changed later.
- **Alternatives**: enumerate the memory registry's top-level keys after pass 1 (misses delete
  lines); a separate line scanner in `ImportConfiguration` (a second .reg grammar to keep in step
  with the parser - continuation lines, MBCS lead bytes, `\` escapes).

## R2 What is "inside"

- **Decision**: root key `HKEY_CURRENT_USER` (the parser's own prefix match, case-insensitive) and
  the name after it equal to the root or starting with root + `\`, ASCII case-insensitive. An empty
  name (`[HKEY_CURRENT_USER]`), an empty root and NULL are outside.
- **Rationale**: the registry compares names case-insensitively; our root is ASCII, so ASCII folding
  is exact for every name that byte-wise starts with it. Names the registry might fold onto our
  root through non-ASCII letters (e.g. U+017F) are refused - fail closed, never the other way.
- **Alternatives**: `SalPathHasPrefixOrdinalCI` (file-system rule; a registry key is not a path and
  the core rule needs no Unicode folding here).

## R3 How a refusal is reported

- **Decision**: `IDS_IMPORTCFG_NOTREG` ("Unable to import the specified file. It is not a
  configuration file.\n\nFile: %s"), through the existing error switch (new case
  `RPE_KEY_OUTSIDE_ROOT`; the no-root case sets `RPE_NOT_REG_FILE`). The first offending key goes
  to the trace log (`TRACE_E` in the parser, inside the core build).
- **Rationale**: an existing, translated text that is true for these files; no new string (084).
- **Alternatives**: a new text naming the key (translation refresh - not a run's step; recorded as a
  leftover); keeping `IDS_IMPORTCFG_NOTOURVER` (its *Yes* could only write foreign keys now).

## R4 Callers of `Parse()`

- Grep `Parse(` over `src/`: `src/salamdr2.cpp` (the two passes of `ImportConfiguration`) and
  `src/reglib/src/tester.cpp` (stand-alone tester of the REGLIBA project, not in `salamand.sln`).
  The new parameter has a default (NULL = no restriction), so the tester compiles unchanged.
- Callers of `ImportConfiguration`: only `WinMainBody` (`src/salamdr1.cpp`), at every start, for
  `config.reg` next to the exe, in `%APPDATA%\Tandem Commander`, or the `-C` file.

## R5 Our own export

- `ExportConfiguration` (`src/salamdr2.cpp`) copies only `HKEY_CURRENT_USER\<SALAMANDER_ROOT_REG>`
  (`CopyBranch`) and, with *clear key before import*, writes the delete line of that root first -
  both inside the root. `SALAMANDER_ROOT_REG` = `SalamanderConfigurationRoots[0]` (single root
  since 032). So the program's own files are never refused.
