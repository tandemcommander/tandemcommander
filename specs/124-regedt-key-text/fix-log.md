# Fix log: feature 124 - Registry Editor's "KEY" text (GitHub issue #3)

Branch `124-regedt-key-text` from `main` `50321995`. Session 2026-10-13, the maintainer away.

## 1. Measure first (before any change)

Control build: `build\tandemcommander\Debug_x64_v019` - a copy (without `Intermediate`) of the
Debug tree built from the 0.1.9 release commit. Probe `probe/regkey_probe.ps1` on the hidden
desktop, ACP 1250, nine languages; result `probe/regkey_result_before_v019.txt`, crops
`probe/shots/before_*`.

| What the report says | Measured |
|---|---|
| information line shows `KL��` in Czech | **confirmed**; also German (`Schl�ssel`) and Slovak (`K���`) |
| "or the Size column in the Detailed view" | **not reproducible** - the column is right in all nine languages (the panel draws a cell that is not valid UTF-8 as code page, `fileswn4.cpp`) |
| `KeyText[10]` too small for UTF-8 | true once the text is UTF-8: German needs 10 bytes + NUL, Russian 12 (`probe/check_key_lengths.py`) |
| (not in the report) | the **selection line** is garbled the same way in Czech, German, French, Hungarian, Slovak (`1 vybran� kl��`) |
| (not in the report) | the plug-in's **Find window** shows the word right today and would be **broken by the proposed patch**: `finddlg.cpp` converts `KeyText` with `CP_ACP` |

A negative control that did not fail: the Size column. It is a finding - recorded in the spec
and in the report to the issue, and the cell is made valid UTF-8 anyway so that it no longer
depends on the fallback.

## 2. The change

First fix (the report's scope plus the selection line and the Find window guard):

| File | Change |
|---|---|
| `src/plugins/regedt/regedt.h` | `KeyText[100]` (UTF-8), new `KeyTextW[32]`, `LoadStrU8(resID, buf, size)` |
| `src/plugins/regedt/fs.cpp` | `InitFS`: both forms from `LoadStrW(IDS_KEY)`; a text of 32 UTF-16 units or more leaves the initial `KEY` - never a cut text |
| `src/plugins/regedt/regedt.cpp` | `LoadStrU8`: wide resource text to UTF-8; a text that does not fit gives an empty text |
| `src/plugins/regedt/fs4.cpp` | `ExpandPluralSelection` and the size prefix of `GetInfoLineContent` take UTF-8 templates; buffers 200 -> 600 bytes |
| `src/plugins/regedt/finddlg.cpp` | Size cell of a found key copies `KeyTextW` |

Why not the report's patch as it is: (1) it leaves the selection text garbled, (2) it garbles
the Find window (negative control below).

## 3. Independent review, round 1 - the fix did not finish its own line

A separate agent (read-only, refute-first) found no fault in the changed lines and five things
around them (research R8). Re-measured on 0.1.9 with new probe rows before changing anything:

| Row | 0.1.9 |
|---|---|
| `DEFAULT` (the `(Default)` value focused) | wrong in Czech, French, Hungarian, Slovak |
| `DATA` (a text value `příliš žluťoučký kůň` focused) | wrong in **all nine languages** |
| `LONG` (a 320-byte accented text) | wrong in all nine |

Second change:

| File | Change |
|---|---|
| `src/plugins/regedt/fs2.cpp` | the `(Default)` item's name is UTF-8 (`DupStrA(LoadStrW(...))`, two places); the text-data preview is UTF-8, at most `MAX_DATASIZE` bytes with the terminator, `...` after a whole character |
| `src/plugins/regedt/fs4.cpp` | date and time of a key through `GetDateFormatW` / `GetTimeFormatW` |
| `src/plugins/regedt/fs5.cpp` | `(Default)` inside the overwrite question's path through `LoadStrU8` |
| `fs.cpp`, `regedt.cpp`, `regedt.h` | dead NULL tests removed, comments say what the code does |

No new string, no interface change, nothing outside the plug-in. 7 files, +88 / -23 lines.

## 4. Tests

Probe `probe/regkey_probe.ps1` (hidden desktop, registry key of the product exported, restored
and SHA-256-verified; a test key `HKCU\Software\TcProbe124` created and removed). Per language:
`COL` (Size column + column names), `INFO`, `DEFAULT`, `DATA`, `LONG`, `SEL`, `SEL3` (owner-drawn
text: capture + Windows text recognition at three sizes, crops kept in `probe/shots`), `FIND`
(`LVM_GETITEMTEXTW`, exact), `END` (exit code 0, no report).

| Run | Build | Result | File |
|---|---|---|---|
| control | 0.1.9 (`Debug_x64_v019`) | PASS 48, **FAIL 33** | `probe/regkey_result_before_v019.txt` |
| fix | `Debug_x64` of this branch | **PASS 81, FAIL 0** | `probe/regkey_result.txt` |
| negative control | this branch with the Find window's line as the report's patch leaves it | FIND **FAIL** in Czech, German, Slovak (`KLĂŤÄŚ`), everything else PASS | `probe/regkey_result_find_as_proposed_in_issue.txt` |

The 33 failures of the control are exactly the rows the fix is for: INFO 3 (cs, de, sk),
DEFAULT 4 (cs, fr, hu, sk), DATA 9, LONG 9, SEL 4 and SEL3 4 (cs, de, fr, sk). Hungarian's
selection text is garbled on 0.1.9 too (`kijel�lt kulcs`, crop `before_hungarian_sel.png`), but
its last word `kulcs` is plain ASCII, so the row - which checks the last word - passes there.

Recognition notes: one row of the fixed run passes as `near` (Hungarian `(Alapértelmezett)`
read with one wrong letter; the crop shows the text right). The recognizer returned nothing for
the English `1 selected key` at one size - hence three sizes per crop.

Other gates: `probe/check_key_lengths.py` 11 translations, 0 violations; `tools/check_encoding.py`
`TOTAL: 0` (it does not scan `plugins/`, so it neither flags nor guards this change); Debug build
clean (the five C4267 warnings of `fs2.cpp` are old).

Not driven: a real keyboard and a real screen (the probe posts messages on a hidden desktop);
languages that are not shipped (Russian, Ukrainian, Chinese - only the static length check);
a Windows whose code page lacks the language's letters (the fix removes the dependence; not
measured on such a machine).

## 5. Independent review, round 2 (the second change)

No blocker. Applied: `pd->DataSize = 0` before the preview is stored (it kept the constructor's
4 when there was nothing to show - harmless only because the one reader tests `Data` first);
`fs5.cpp` tested the *target's* name while converting the *source's* (an old slip in a line the
change touches: copying the `(Default)` value onto a named one showed the source without a
name); a stale comment in `utils.h`. Final build re-probed in English and Czech:
`probe/regkey_result_final_build_cs_en.txt`, PASS 18 / FAIL 0.

Visible differences besides the encoding, accepted: the preview is limited to 199 **bytes**
(it was 199 UTF-16 units), so a text with many non-ASCII letters is shortened earlier; a text
value without a terminating NUL shows its last character (it was dropped); the preview stops at
an embedded NUL.

Recorded, not changed: a malformed `REG_MULTI_SZ` with a single terminator shows a trailing
space (`fs2.cpp` uses `==` where `finddlg.cpp` uses `>=`).

## Second verification (2026-10-13, asked for by the maintainer)

Everything was built again from scratch (`build.cmd rebuild full`, Debug and Release), the
probes were run again on the fresh build and on the 0.1.9 control, and one independent agent
per feature was told to refute the fix and to write tests of its own.

Probe on the fresh build, all nine languages: **PASS 81, FAIL 0** (`probe/regkey_result_verify2.txt`);
0.1.9: FAIL 31 (the text recognition reads two rows differently from run to run; the failing
rows are the same kinds). This also answers the agent's remark that the 81-row run predated the
second change and feature 127's edits of `fs2.cpp` / `fs3.cpp` / `utils.cpp`.

Found by the agent (its own fuzz of the preview code: 400,000 inputs, no overflow, always valid
UTF-8, `...` exactly when text is lost; English output byte-identical to 0.1.9):

- **A regression of this feature, fixed.** *Copy Name* / *Copy Full Name* / *Copy Path*
  (`fs3.cpp`) hand the panel's text to the core's `CopyTextToClipboard`, which takes code-page
  text. Key and value names were UTF-8 there since interface 104 (so any accented name was
  already copied garbled); 124 added the translated `(Default)` name to that. Now
  `CopyU8TextToClipboard` converts and calls `CopyTextToClipboardW`.
- **Same class one line below the fixed one, fixed.** `finddlg.cpp` converted the core's number
  text (UTF-8, the group separator of the Czech format is U+00A0) with the code page: a found
  value of 1,234 bytes showed `1Â 234`. Now `U8ToWStr`. The probe's values were under 1,000 bytes.
- **Recorded (NEXT-WORK D), older than this feature:** the plug-in's `%ls` messages
  (`fs5.cpp:869` `IDS_CREATETARGET`, `fs5.cpp:1014`, `ErrorHelper` in `regedt.cpp`) do not "lose
  letters outside the code page" - in the C locale `_vsnprintf_s` fails at the first non-ASCII
  letter: the question whether to create the target key is an **empty** Yes/No box for a name
  like `Tést`, `ErrorHelper` stops the text at that letter.
- Wrong in the answer to the issue, corrected there: "exactly the rows listed" (the table did
  not list the nine LONG rows; the Hungarian selection row passes on 0.1.9); the 199-byte limit
  of the preview is now mentioned; the `%ls` messages are not handled by #7.
- Not covered by the probe, owed to a person: the clipboard commands above (the hidden desktop
  cannot read the clipboard); the size prefix of the selection text (`IDS_SELECTEDSIZE`, shown
  only for values of 1,000 bytes and more).
