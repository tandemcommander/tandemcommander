# Fix log: feature 129 - Registry Editor, wide inserts in narrow texts

Branch `129-regedt-wide-inserts` from `128-shortcut-target-unicode`. Session 2026-10-13. Found
by the second verification of 124-128 (an agent reading the plug-in); the maintainer asked for
the fix ("the most serious of what is left").

## 1. Measure first

`probe/wide_probe.ps1`, Czech, on the build before the change and on 0.1.9
(`probe/wide_result_before_v019.txt`): **4 rows fail**.

| Row | Seen on 0.1.9 |
|---|---|
| CREATE - Copy of a key to a target under a key `Cíl řx` that does not exist | a box *Kopírovat* with **Ano / Ne and no text** |
| SELF - Copy of a key into its own subkey | a box *Chyba při kopírování klíče registru* with **OK / Storno and no text** |
| OPENKEY - Change Directory to a key that does not exist | `Nelze otevřít klíč registru "HKEY_CURRENT_USER\Software\TcProbe129\Klí Systém nemůže nalézt uvedený soubor.` |
| VIEW - F3 on `v` of two keys `Klíč žluťoučký 1 / 2` | both viewers on `...\SAL61B.tmp\_v`: **one cache file for two values** |

The control rows with ASCII names pass. The note that started this spoke of two message boxes;
measuring found the cache name as well, which is not a text but a key of a lookup.

Cause: `%ls` in a narrow printf is converted with the "C" locale. Letters up to U+00FF pass by
value (so `é`, `í`, `ü` worked by accident), the first letter above fails the call:
`_vsnprintf_s` returns -1 and an empty buffer (the plug-in's `SalPrintf`), `vsprintf` stops
there (`ErrorHelper`).

## 2. The change

| File | Change |
|---|---|
| `src/common/salwideinserts.h` (new) | `SalWideInsertsUsed / Count / ExpandTo / ExpandAlloc` (`%ls` -> UTF-8 of the next wide insert, whole text on the heap), `SalWideLowerToU8Alloc` |
| `regedt.h`, `regedt.cpp`, `precomp.h` | `FormatWideU8` (template or id); `ErrorHelper` sends a template with `%ls` to `ErrorHelperWide` (template loaded wide by id, inserts from the argument list, the reason by `FormatMessageW`); other templates keep the old path |
| `fs5.cpp` | the create-target question, the self-copy / self-move message, the name in the "class name differs" question |
| `fs3.cpp` | `AllocCacheName`: the disk cache name of a viewed value, composed wide, lower case, UTF-8, heap |
| `saltests.cpp` | `TestWideInserts129` |

No new strings, no interface change.

## 3. Traps met

- The probe's own answers changed the registry: "press the first button with one of these ids"
  took OK before Cancel (the window's order), re-ran the copy and at exit answered Yes. Answers
  now go by the given order, each copy row rebuilds the fixture, and a STATE row checks that
  nothing was created.
- `.txt`-less registry values open in the internal viewer; its title is the cache file - that
  is what made the shared file visible without reading the screen.
- The text recognition reads `FIRST111` as `FIRSTIII`; the values are `ALPHA` / `OMEGA`.
- Python in a Bash here-document lost the backslashes of the probe edits once more; edits go
  through script files.

## 4. Independent review (read-only, refute-first) - one real defect in the first version

- **Fixed: the cache name could still be shared.** The first version composed the name as
  UTF-8 and kept `SG->ToLowerCase` on it. That is a byte table of the code page (`CharLowerA`):
  on code page 1250 it turns the continuation byte 8A into 9A, AA into BA and so on, so
  `Software\ê` and `Software\ú` (C3 AA / C3 BA) became one name - **pairs that were distinct
  on 0.1.9** (letters up to U+00FF were single bytes there). Proved by the reviewer's own
  program, then by the new probe row `VIEWFOLD` on the first version
  (`probe/wide_result_first_version_fold.txt`: one file). Now the name is composed wide and
  folded with `CharLowerBuffW` before the conversion (`SalWideLowerToU8Alloc`); unit checks
  for those pairs.
- **Fixed:** when the template cannot be loaded again (low memory), `ErrorHelperWide` shows the
  system's reason alone instead of mixing the code-page template with UTF-8 names.
- Notes, kept: for three unusual ASCII cases the cache name differs from the old one (a value
  name with a leading backslash, an empty value name, the same at the registry root) - the old
  form merged `\name` with `name`; nothing else builds this name, so nothing depends on it.
  `finddlg.cpp:1551` passes a regular-expression error text as a format string (old).
- Sound: exactly six templates have `%ls`, in English and all eleven translations, none mixed
  with another specification, argument types and order right at the four `ErrorL` calls; no
  fixed-size limit in the core's disk cache for the unique name; every exit frees; the
  question fails closed.
- Other narrow `%ls` in the tree (not this plug-in), recorded in NEXT-WORK: `peviewer/pefile.cpp`
  (version resource names in the dump); call-stack and trace texts in FTP, `shellib.cpp`,
  `olespy.cpp`.

## 5. Tests

| What | Result | Record |
|---|---|---|
| probe, 0.1.9, Czech | PASS 15, **FAIL 4** | `probe/wide_result_before_v019.txt` |
| probe, final build, Czech | **PASS 19, FAIL 0** | `probe/wide_result_czech.txt` |
| probe, final build, English | **PASS 19, FAIL 0** | `probe/wide_result_english.txt` |
| regression: probe of 124 (Registry Editor, 9 languages) | PASS 81, FAIL 0 | on the fixed build |
| regression: probe of 127 (Czech) | PASS 19, FAIL 0, 3 not driven (clipboard) | on the first version of the fix |
| saltests | 18,447 checks, 0 failed (18,395 before; `TestWideInserts129` = 52) | |
| `tools/check_encoding.py` | `TOTAL: 0` (it does not read the plug-ins) | |
| Debug and Release builds | clean | |

Rows of the probe: OPENKEY (text starts with the whole sentence and key, holds the Windows
reason), VIEWA / VIEW / VIEWSEQ / VIEWFOLD (two cache files; each viewer its own data, read
from a capture), CREATE and SELF (the box text exactly; after No / Cancel the fixture holds
its 7 keys), END rows (exit code 0, no stray window, no report).

Not driven: Move (it shares the code with Copy; its message differs by one word); the
"class name differs" question (needs two keys with different class names); a name outside the
Basic Multilingual Plane on screen (unit checks only).
