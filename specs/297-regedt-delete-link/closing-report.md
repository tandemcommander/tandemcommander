# Closing report - 297-regedt-delete-link
Backlog item: registry-editor-delete-or-move-deletes-a-linked-key - Registry Editor: Delete or Move of a key holding a registry link deletes the linked key
Outcome: closed

## What changed

- `src/plugins/regedt/fs3.cpp` `DeleteKey`: at every level, a registry link is removed as the link
  itself (`SafeDeleteRegLink`: `REG_OPTION_OPEN_LINK` + `DELETE`, re-checked on that handle,
  `NtDeleteKey`); nothing is enumerated or deleted through it. A dangling link and a link without
  its value are removed the same way.
- `src/plugins/regedt/fs5.cpp` `CopyOrMoveKeyRec`, a Move (F6, drag and drop, Quick Rename): at every
  level, a link source key is refused before anything of it is read or written, with the existing box
  "Unable to remove the original registry key." + "The request is not supported." (Retry / Skip /
  Skip All / Cancel). Skip keeps the link and its parents in the source. Copy (F5) is unchanged.
- How a link is told (`OpenedRegKeyIsLink`, `RegKeyIsLink`, `SafeRegKeyIsLink`): opened as a link
  vs. opened by name - another key or none = a link (292's identity helpers). It reads no values and
  asks only `KEY_ENUMERATE_SUB_KEYS`. 296's target check uses the same test.
- No UI string, no plug-in interface change. `regedt.h` declares the two shared helpers.

## Measurements (before / after, commands)

- Before (49147f36, `probe/link297_before.txt`): 16 PASS / 14 FAIL. The linked key `Jinde` was lost in
  7 rows: F8 of a tree with a link, F8 of the link itself, F6, F6 + Skip, F6 of the link, Quick Rename
  of the link, and F8 through HKCR.
- After: `probe/link297_after.txt` **40 PASS / 0 FAIL / 0 NOT DRIVEN** (English), and
  `probe/link297_after_czech.txt` 40 / 0 (Czech). The registry was restored identical each time.
- Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\297-regedt-delete-link\probe\result_after_review.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\297-regedt-delete-link\probe\link297_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\297-regedt-delete-link\probe\link297_after.txt"`

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard: `TOTAL: 0 finding(s)`. Build Debug x64: BUILD SUCCEEDED.
- saltests: `26304 checks, 0 failed`.
- Probes: 297's 40 / 0 (English and Czech). Regression probes: 296's 47 / 0, 294's 24 / 0,
  292's 33 / 0. The registry was restored identical in every run.
- Negative controls: both link tests off, 14 FAIL (first version); the identity test always "no
  link", 15 FAIL.
- The review's rows run on the first version: 4 FAIL.

## Reviews (findings and what was done)

One refute-first review, **no MUST**:
- SHOULD 1: a link was told by its value; a plain key holding `SymbolicLinkValue` was taken for a
  link. **Fixed**: the identity test, rows FAKEDEL / FAKEMOVE / NOVALDEL.
- SHOULD 2: Delete needed value-read access on every key. **Fixed**: only `KEY_ENUMERATE_SUB_KEYS`,
  row ACLDEL.
- NOTE 3: a selected dangling link cannot be deleted by itself. Accepted, recorded as a limit.
- NOTE 4: a Move is split per level. Accepted, recorded as a limit.
- NOTE 5: duplicated logs. Accepted; they are the runner's logs.

## Owed to a person (with the new person-step items)

Nothing: everything was driven on the hidden desktop with real registry links.

## New Inbox items (slug - title)

- registry-editor-copy-or-find-through-a-link-to-an-ancestor - Registry Editor: Copy or Find through a link to an ancestor walks in a loop
