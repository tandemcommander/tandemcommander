# Research: feature 129

## R1 - Is the defect reachable, and what exactly happens? (measured, 2026-10-13)

`probe/wide_probe.ps1` on the build before the fix and on 0.1.9 (`probe/wide_result_before_v019.txt`),
Czech, registry names with Czech letters (`Klíč žluťoučký 1`):

| Situation | Seen |
|---|---|
| Copy of a key to a target under a key that does not exist | a box titled *Kopírovat* with **Ano / Ne and no text** |
| Copy of a key into its own subkey | a box titled *Chyba při kopírování klíče registru* with **OK / Storno and no text** |
| Change Directory to a key that does not exist | `Nelze otevřít klíč registru "HKEY_CURRENT_USER\Software\TcProbe129\Klí Systém nemůže nalézt uvedený soubor.` - cut after `í`, the closing quote lost |
| F3 on the value `v` of two keys | both viewers show `...\SAL61B.tmp\_v` - **one file**; with ASCII key names two files |

- Decision: valid, and wider than the note that started it (the cache name).
- Why the cut is after `í` and not at the first accented letter: the "C" locale converts
  U+0000-U+00FF by value, so `í` (U+00ED) passes and `č` (U+010D) fails. A name in German or
  French worked by accident; Czech, Polish, Greek, Cyrillic, CJK names did not.
- `_vsnprintf_s` (the plug-in's `SalPrintf`) returns -1 and an empty buffer; `vsprintf`
  (`ErrorHelper`) stops at the letter. Both shown by `TestWideInserts129`'s first check.

## R2 - How to compose

- Decision: an explicit expansion (`src/common/salwideinserts.h`), UTF-8 out.
- Alternatives: (a) the runtime's UTF-8 locale - version dependent, fails for surrogate pairs;
  (b) wide formatting (`_vsnwprintf_s` with `LoadStrW`) - right for `%ls`, but `%s` means a wide
  string there, a trap for the next template; (c) convert every insert at every call site by
  hand - six copies of the same code.

## R3 - What else is composed this way in the plug-in

`grep '%ls'`: the templates `IDS_OPENKEY`, `IDS_OPENKEY2`, `IDS_ACCESS`, `IDS_CANTCOPYTOITSELF2`,
`IDS_CANTMOVETOITSELF2`, `IDS_CREATETARGET` (no other specification in them, English and all
translations) and two literal formats (`fs3.cpp` `"%s:\\%ls\\%ls"`, `fs5.cpp` `"%ls\\%ls"`).
All six call sites are changed. The wide `SalPrintfW` sites are right as they are.

## R4 - The cache name must stay what it was for ASCII

`ViewFile` built `fsName:\ROOT\key` and appended the value's name with `SalPathAppend`. The new
composition gives the same bytes for ASCII names, the registry root included (`ROOT\` + name) -
checked by a unit check against the old `_snprintf_s` result and by the control row `VIEWA`.
