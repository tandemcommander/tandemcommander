# Closing report - 278-regedt-find-regexp-cp
Backlog item: regedit-find-regexp-multibyte-code-page-buffer - Registry Editor Find: regexp misses text past the code-page length of a value
Outcome: closed

## What changed

- `src/common/salregfind.h`: `SalRegFindTextToCodePage(text, units, codePage, out, outSize)` -
  counts the code-page bytes of a text (`out == NULL`), or converts it whole and returns the
  count; -1 when it cannot be converted or does not fit (never a partial result).
- `src/plugins/regedt/finddlg.cpp`, `CFindThread::Test`, regexp branch: counts with `CP_ACP`,
  reserves the count, converts, searches the converted count; a failed conversion is no match.
  Callers (value name, value data, key name) unchanged; `WStrToStr` unchanged.
- `src/saltests/saltests.cpp`: `TestRegFindTextToCodePage278`.

## Measurements (before / after, commands)

- Before (python ctypes `WideCharToMultiByte`, main at cffe5eca): code page 65001, `čččč bar`
  (8 units) into 8 bytes → 0 (needs 12), `bar` absent from the 8 scanned bytes; into a larger
  reused space → 12 bytes, 8 scanned, `bar` absent. 932 and 1250: 8 bytes, `bar` found.
- After (saltests): 65001 → 12 bytes searched, ending `bar`; 932 `ああ bar` → 8 bytes from 6
  units, `bar` beyond the unit count found; 1250 → 8 bytes as before; too small space → -1.
- The GUI under a multi-byte code page was not driven (this machine: ACP 1250).

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- Build `.\build.cmd`: `BUILD SUCCEEDED`.
- saltests: `24954 checks, 0 failed`; negative control (the rule sized by units): `12 failed`.
- Feature 257's probe `find_words_hex_probe.ps1` on the hidden desktop: before 9 PASS / 0 FAIL,
  after 9 PASS / 0 FAIL (a regression control on 1250 - it cannot tell the old code from the new;
  registry restored, identical hash both times). Results in `probe/`.

## Reviews (findings and what was done)

One refute-first review, no MUST. SHOULD 1 (the viewer's export in `fs3.cpp` has the same
unit-sized buffer) → Inbox item. SHOULD 2 (the call site is proven by reading, not by an
automated check) → stated in `fix-log.md`, the person step covers it. NOTE 3 → quickstart step 4
covers names and keys. NOTEs 4-6 recorded in `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- `registry-editor-find-confirm-a-regexp-finds-the-end-of-a-non` - Registry Editor Find: confirm
  a regexp finds the end of a non-ASCII text on UTF-8 (the UTF-8 system locale, a restart; can be
  done together with `regedit-find-hex-utf8-code-page-check-257`).

## New Inbox items (slug - title)

- `registry-editor-view-of-a-text-value-cut-text-and-a-stray` - Registry Editor View of a text
  value: cut text and a stray byte on a UTF-8 code page.
- (person step, in Inbox for triage) `registry-editor-find-confirm-a-regexp-finds-the-end-of-a-non`
  - Registry Editor Find: confirm a regexp finds the end of a non-ASCII text on UTF-8.
