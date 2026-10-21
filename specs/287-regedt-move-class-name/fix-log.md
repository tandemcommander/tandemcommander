# Fix log: feature 287 - Registry Editor, Move of a key and the "class name differs" question

Branch `287-regedt-move-class-name` from `main` at 243174e4. Autonomous run of backlog item
`regedit-key-name-buffer-size-and-move-rows` (left from feature 129), 2026-10-21.

## 1. Measure first (at 243174e4, before any change)

| What the item says | Found at HEAD |
|---|---|
| `fs3.cpp:218` passes `MAX_KEYNAME` as the size of a `3 * MAX_KEYNAME` buffer | **already fixed by feature 131** (d041841a): `AcceptChangeOnPathNotification` passes `sizeof(key)`, `sizeof(path2)`, `path1` has the size of `path2`, with a comment "feature 131: the sizes passed are the sizes of the buffers"; 131's record `specs/131-plugin-defect-batch/items/regedt.md` §8 (effect unreachable: nobody posts a registry path). Nothing to change |
| Move of a key was not driven | true: feature 129's probe drove Copy only (CREATE, SELF) |
| the "class name differs" question was not driven | **it cannot appear at all**: `CopyOrMoveKey` (`src/plugins/regedt/fs5.cpp`) reads the target's class name with `SafeQueryInfoKey(sourceHKey, ...)` - the source key again - so the comparison is always equal. Upstream since 3945ecf7 (the first Open Salamander commit has the same line) |

Reachability: F5 / F6 (`CopyOrMoveFromFS`) of a key into a key that already holds a key of the same
name with another class name -> `SafeCreateKey` (`RegCreateKeyExW` opens the existing key and keeps
its class) -> the check. Quick Rename (F2) also calls `CopyOrMoveKey`, but `TestKey` refuses an
existing target before, so it never meets a different class.

Consumers of the changed line (Grep `CopyOrMoveKey`): `fs3.cpp` QuickRename, `fs5.cpp`
CopyOrMoveFromFS, its own recursion. `SafeQueryInfoKey` callers: `fs5.cpp` (the two in
`CopyOrMoveKey`), `fs3.cpp` / `fs.cpp` listing (unchanged).

Texts of the question (read before writing the probe): the name is `FormatWideU8("%ls\\%ls")`
(UTF-8, feature 129) shown by the core's `CStaticText` (`IDS_FILENAME` = 171; it paints its own
text, `WM_GETTEXT` gives nothing -> the probe reads it by text recognition); the question is
`LoadStr(IDS_COPYCLASSNAME)` (code page) set with `SalSetWindowTextU8` (`IDS_ERROR` = 172), which
falls back to the code-page path for text that is not UTF-8 - the probe compares it with the
translation.

## 2. Decisions

- Fix: `SafeQueryInfoKey(targetHKey, targetRoot, target, targetClassName, ...)`. `targetHKey` is
  opened with `KEY_WRITE | KEY_READ` by `SafeCreateKey` just before (KEY_READ has
  KEY_QUERY_VALUE). The error of a failed query then names the target, as the other target
  errors of the function do.
- No header under `src/common/`: the decision (`CompareStringW` of two class names) is unchanged.
- No new strings, no interface change.

## 3. The change

`src/plugins/regedt/fs5.cpp`, `CopyOrMoveKey`: `SafeQueryInfoKey(targetHKey, targetRoot, target,
targetClassName, ...)` (was `sourceHKey, sourceRoot, source`), with a comment naming 287.

## 4. Probe `probe/move287_probe.ps1`

Rows and fixture: `contracts/probe-rows.md`, `data-model.md`. Command (PowerShell tool):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\287-regedt-move-class-name\probe\result_after_czech.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\287-regedt-move-class-name\probe\move287_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Lang czech -OutFile specs\287-regedt-move-class-name\probe\move287_after_czech.txt"
```

| Run | Result | Record |
|---|---|---|
| build without the fix, Czech (`-Expect before`) | **PASS 13, FAIL 5**: CLASSCOPY / CLASSMOVE / CLASSYES ASK (no question), CLASSCOPY / CLASSMOVE STATE (merged silently; **CLASSMOVE deleted the source key** after merging into the key with the other class) | `probe/move287_before_czech.txt` |
| fixed build, Czech | **PASS 18, FAIL 0** | `probe/move287_after_czech.txt` |
| fixed build, English | **PASS 18, FAIL 0** | `probe/move287_after_english.txt` |
| regression: probe of 129, Czech, fixed build | PASS 19, FAIL 0 | `probe/wide129_regression_czech.txt` |

The negative control was run twice: first on the HEAD build before the change (the probe's first
complete version, 13 / 5), then with the final probe on a build where the one line was put back
temporarily (13 / 5 again, the same five rows); the fix was restored and rebuilt, and the Czech run
repeated on that binary (18 / 0). Every run: exit code 0 of each instance, no stray window, no
crash report, fixture removed, the product's registry key restored identical (SHA-256
A3805966...2FEF).

The question as shown (Czech): title *Upozornění*, *Název:* `HKEY_CURRENT_USER\Software\TcProbe287\Zdroj\Klíč žluťoučký`
(screenshot `probe/question_name_czech.png`, checked by eye: whole and right), the question text
exactly the translation of 1068, buttons *Ano / Vše / Storno*. The question text is a code-page
string through `SalSetWindowTextU8`'s fallback - shown right in Czech (ACP 1250).

## 5. Traps met

- **PowerShell names ignore case**: the fixture loop's `$k` hid the key name `$K` inside the
  function; the first run failed in the fixture. Loop variable renamed (`$fx`), commented.
- **`RegCreateKeyEx` gives the class to every parent it creates**: the first fixture had class
  `TřídaA` on `Zdroj` too. Parents are created first, without a class.
- **Text recognition cannot read this name line whole**: `CStaticText` paints its text (no
  `WM_GETTEXT`), and the recognizer drops `HKEY_CURRENT_USER\...\Kl` at any scale (3, 2, 1.5, 1),
  with padding, and in 2 / 3 / 4 slices (measured on the saved capture). It reads `žluťou` every
  time. The row checks that part exactly, and that no letter of a code-page reading of UTF-8
  appears. Negative control of that check (offline, the same functions): the right name passes; its
  cp1250 reading, its cp437 reading and the name without accents fail.
- A Bash here-document collapsed backslashes in a Python edit of the probe (CLAUDE.md, 123) - the
  probe is edited with the editor only.

## 6. Checks

| Check | Result |
|---|---|
| `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)`, exit 0 |
| `.\build.cmd` (Debug x64) | `BUILD SUCCEEDED`, exit 0 (`regedt.spl` rebuilt after the change) |
| `saltests.exe` (control; the core is unchanged) | `saltests: 25167 checks, 0 failed` |
| probe 287 Czech / English | 18 / 0, 18 / 0 |
| probe 129 Czech | 19 / 0 |

No UI string added or removed: `build.cmd full` / `.slt` refresh not needed.
