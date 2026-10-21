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
text; see §5 for how the probe reads it); the question is
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

### First version (7 rows, 18 checks)

| Run | Result |
|---|---|
| HEAD build before the change, Czech (`-Expect before`) | **PASS 13, FAIL 5**: CLASSCOPY / CLASSMOVE / CLASSYES ASK (no question), CLASSCOPY / CLASSMOVE STATE (merged silently; **CLASSMOVE deleted the source key** after merging it into the key with the other class) |
| fixed build, Czech / English | PASS 18, FAIL 0 / PASS 18, FAIL 0 |
| the one line put back temporarily, Czech | PASS 13, FAIL 5 (the same five) |

### Final version (after the review: 11 rows, 30 checks; the name compared exactly)

| Run | Result | Record |
|---|---|---|
| the one line put back temporarily (`sourceHKey`), rebuilt, Czech (`-Expect before`) | **PASS 19, FAIL 11**: every ASK row (no question) and the STATE of CLASSCOPY, CLASSMOVE, NESTCANCEL, NESTMOVE (merged; with Move the source deleted - in NESTMOVE also the subkey that met the other class) | `probe/move287_before_czech.txt` |
| fixed build (restored, rebuilt 16:09), Czech | **PASS 30, FAIL 0** | `probe/move287_after_czech.txt` |
| fixed build, English | **PASS 30, FAIL 0** | `probe/move287_after_english.txt` |
| regression: probe of 129, Czech, fixed build | PASS 19, FAIL 0 | `probe/wide129_regression_czech.txt` |

After the negative control the source was restored and rebuilt; `git diff main...HEAD -- src` shows
only the fix (`fs5.cpp`, 3 + / 1 -). Every run: exit code 0 of each instance, no stray window, no
crash report, fixture removed, the product's registry key restored identical (SHA-256
A3805966...2FEF).

The question as shown (Czech): title *Upozornění*, *Název:*
`HKEY_CURRENT_USER\Software\TcProbe287\Zdroj\Klíč žluťoučký` (for the subkey
`...\Klíč žluťoučký\podklíč`), the question text exactly the translation of 1068, buttons
*Ano / Vše / Storno*. The question text is a code-page string through `SalSetWindowTextU8`'s
fallback - shown right in Czech (ACP 1250).

## 5. Traps met

- **PowerShell names ignore case**: the fixture loop's `$k` hid the key name `$K` inside the
  function; the first run failed in the fixture. Loop variable renamed (`$fx`), commented.
- **`RegCreateKeyEx` gives the class to every parent it creates**: the first fixture had class
  `TřídaA` on `Zdroj` too. Parents are created first, without a class.
- **The name control and `WM_GETTEXT`** - first wrong, corrected by the review. The first version
  assumed `CStaticText` gives no text to `WM_GETTEXT` (the probe's `Box-Text` stopped at control
  172 and never asked 171) and read the name by text recognition, which drops
  `HKEY_CURRENT_USER\...\Kl` at any scale, with padding and in slices; it checked only `žluťou`
  (plus no code-page-garbled letter). A name cut after `žluťou` or another key's name would have
  passed. In fact `CStaticText::WindowProc` answers `WM_GETTEXT` with its UTF-8 bytes
  (`src/gui.cpp`, `case WM_GETTEXT`); Windows converts them with the code page for a wide caller.
  The probe now reverses that (`Painted-Text`) and compares the whole name exactly - for each
  question in order.
- **A fresh window list after an answer hides the next question**: the first NESTYES run saw one
  question, not two - the second was already open when the list of "known" windows was taken after
  the answer's pause, and the end of the row cancelled it. The list now grows only by the answered box.
- A Bash here-document collapsed backslashes in a Python edit of the probe (CLAUDE.md, 123) - the
  probe is edited with the editor only.

## 6. Checks

| Check | Result |
|---|---|
| `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)`, exit 0 |
| `.\build.cmd` (Debug x64) | `BUILD SUCCEEDED`, exit 0 (`regedt.spl` rebuilt after the change) |
| `saltests.exe` (control; the core is unchanged) | `saltests: 25167 checks, 0 failed` |
| probe 287 Czech / English (final) | 30 / 0, 30 / 0; without the fix 19 / 11 |
| probe 129 Czech | 19 / 0 |

No UI string added or removed: `build.cmd full` / `.slt` refresh not needed.

## 7. Review

One independent refute-first review (agent, read-only on the repository; its own negative control:
the old line put back, rebuilt, the question rows - no question, Copy merged, Move merged and
deleted the source; restored, rebuilt, English 18 / 0, `git diff` empty). **No MUST.**

| Finding | What was done |
|---|---|
| S1 `CHANGELOG.md`: "the warning appears before anything is copied; Cancel copies and deletes nothing" holds only for the top key - for a subkey that differs, the values above it are already copied (measured by the reviewer: `Nest\<K>` got `v`; Move kept the source whole) | changelog reworded (the subkey case and its limit stated); probe rows NESTCANCEL / NESTMOVE added |
| S2 the probe's name check checked six letters; the fix-log's reason (no `WM_GETTEXT`) was wrong | the probe reads control 171 by `WM_GETTEXT` and compares the whole name exactly; trap note corrected (§5) |
| S3 (predates 287) Move of a key onto itself through an aliased root (`HKEY_USERS\<own SID>\...` for `HKCU\...`) passes the "into itself" check (root index + text) and, with the overwrite answered *All*, deletes the key - the only copy | out of scope: Inbox item `registry-editor-move-of-a-key-onto-itself-through-hkey-users` (`review:287`) |
| N1 nested All / Yes-then-ask-again / the subkey's name | probe rows NESTALL, NESTYES (and the subkey name in NESTCANCEL / NESTMOVE) |
| N2 a target class name of 260+ characters now gets the existing read error (`MAX_PATH` buffer) instead of a silent merge; the source side already did | accepted: fails safe |
| N3 (predates, core) `CStaticText` answers a wide `WM_GETTEXT` with UTF-8 bytes - screen readers get garbled names; the painted text is right | Inbox item `screen-readers-get-garbled-names-from-the-core-path-labels` (`review:287`) |
| N4 class names compared with `CompareStringW` (locale, ignore case) | unchanged, accepted in the spec (a class name is not an identity) |
| N5 closing not done yet | done in step 8 |

No second review: the review had no MUST finding; the SHOULD changes are the probe and the
changelog text, re-run above (30 / 0 Czech and English, 19 / 11 without the fix).
