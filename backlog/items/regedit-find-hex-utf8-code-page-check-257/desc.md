---
title: Registry Editor Find: confirm quoted hex letters with a UTF-8 code page
type: person-step
status: new
severity: 3
area: other-plugins
source: leftover:257
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor Find: confirm quoted hex letters with a UTF-8 code page

## Problem

Feature 257 makes a `'...'` text of a HEX-mode Registry Editor search become all the code-page
bytes of its letters (a letter of 2+ bytes was one 0x00 byte). The 2-byte case is proven by
`saltests` with code page 65001 / 932 only; the measuring machine has code page 1250, where the
GUI rows are controls. Switching the system's ANSI code page to UTF-8 needs a restart, so a
person confirms it in the GUI.

## Evidence

`specs/257-regedt-find-words-hex/fix-log.md`, section *After* ("Not driven here"); probe
`specs/257-regedt-find-words-hex/probe/find_words_hex_probe.ps1`, rows HEX-CP and HEX-CP-BYTES
(the probe writes the value with the machine's ANSI code page bytes and prints the code page).

## Expected

On a machine with the UTF-8 ANSI code page the HEX rows pass: the quoted C-caron is C4 8D in the
pattern and the value is found.

## Notes

Do it on a test machine or VM: the setting changes the whole system. Turn it back off afterwards.

## Steps

- [ ] Settings → Time & language → Language & region → Administrative language settings → Change
      system locale → check "Beta: Use Unicode UTF-8 for worldwide language support", restart →
      `Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage` shows ACP 65001.
- [ ] Run the probe through `tools\run_on_hidden_desktop.ps1` as in
      `specs/257-regedt-find-words-hex/quickstart.md` step 3 (a Debug build of 257 or later) →
      the header line reads `ACP : 65001; the quoted text's bytes: C4 8D 41 42`, every row PASS
      (HEX-CP and HEX-CP-BYTES found `probe257hx1`), the registry restored identical.
- [ ] By hand instead of the probe: in Registry Editor create a REG_BINARY value with the bytes
      `01 C4 8D 41 42 02`, open Find (Look at: Data, HEX-mode), search `'čAB'` → the value is
      found; with a build before 257 it is not.
- [ ] Uncheck the UTF-8 option again and restart.

## Log

- 2026-10-20 — created (source leftover:257)
