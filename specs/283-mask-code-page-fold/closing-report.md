# Closing report - 283-mask-code-page-fold
Backlog item: mask-matcher-code-page-fold - File masks fold accented letters through the code page
Outcome: closed

## What changed

- `src/common/salmaskopt.h` (new, header-only): `SalMaskOptimizeKind` - which shortcut a prepared
  mask of a mask group takes. The old classification of `CMaskGroup::PrepareMasks`, plus: an
  extension with any byte >= 0x80 is no `*.xxx` shortcut mask (it goes to `AgreeMask`, whole
  letters, NFC + `CharLowerW`). Contract `contracts/mask-optimize-kind.md`.
- `src/masks.cpp`: `PrepareMasks` uses it (`static_assert` on the values); comments at the
  `StrICmp` / table sites, which now see ASCII extension masks only.
- `src/saltests/saltests.cpp`: `TestMaskOptimize283` (40 checks).
- The two other byte loops the item named (`AgreeMaskA`, `AgreeQSMaskAux`) are reached only by
  ASCII pairs (or text that is not UTF-8) - measured, left as they are (fix-log).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\283-mask-code-page-fold\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\283-mask-code-page-fold\probe\mask283_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"` (ACP 1250, Convert of the focused file with a mask)

| Run | PASS | FAIL | Failing rows |
|---|---|---|---|
| before (main cb0d80f5) | 14 | 6 | miss, miss-hash, miss-excl, false, false-hash, nfd |
| negative control (rule disabled) | 14 | 6 | the same |
| after | 20 | 0 | - |
| review 1 | 20 | 0 | - |

Registry restored and identical after every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- Build `.\build.cmd`: `BUILD SUCCEEDED`.
- saltests: `25051 checks, 0 failed` (+40); negative control 11 failed.
- Probe: 20 / 0 (above).

## Reviews (findings and what was done)

One refute-first review, no MUST. SHOULD 1 (the differential's size was overstated; T007 asked
for lengths 0-6) fixed: 1,195,742 cases. NOTEs 2-4 accepted with reasons (Kelvin sign vs ASCII
`*.k`; the all-code-page claim rests on an emulation checked against the running ACP; accented
`*.xxx` masks cost the general matcher). NOTE 5 -> Inbox item. NOTE 6 (archive associations,
092-deferred) recorded. Details: `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

Nothing. (Optional, covered by the probe: Select with `*.čtx` in a folder holding `A.ČTX`.)

## New Inbox items (slug - title)

- mask-group-prepare-unbounded-mask-copy - A single mask longer than 259 bytes overruns the mask group preparation buffers
