# Fix log - 270-mask-filter-label-fits

Backlog item `more-typed-fields-cut-to-their-buffer-masks-filter-volume` (leftover of 251).

## Measured at 11e20a84 (main, before the feature)

Build: `.\build.cmd` (Debug x64, up to date at HEAD). Probe written for this item
(`probe/mask270_probe.ps1`, 251's driver, 098's library), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <...>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <...>\mask270_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

(first run from a scratch folder with `-Lib` pointing at 098's library; copied here unchanged
except the BOM.) M = 86 CJK letters (258 bytes). Result `probe/result_before.txt` +
`probe/result_before_hp.txt` (the hot path rows re-run after the probe learned to focus the list
view before `LVM_EDITLABEL`): PASS 14 (incl. END rows), FAIL 7:

- `sel-mask`, `unsel-mask`: `M*Q` (260 bytes) closed silently; the next Select shows `M*` (259).
- `conv-mask`: `M*Q`, CRLF: **`M.txt` converted** (2 CRLF) - the typed mask does not match it.
- `flt`, `flt-unused`: `M*` stored (with either radio).
- `vol`: 140 r-caron (280 bytes): `SetVolumeLabel` called with the cut label - "Unable to change
  drive label. Error: (5) access denied" (not elevated; the label cannot change). The label line
  is reachable (the field has no limit); a cut label (>= 86 units) exceeds every Windows file
  system's label limit, so it was never applied - but the write ran with another text.
- `hp-label`: F2, 100 CJK letters, Enter: stored 86 letters; OK closed the page.
- Controls `sel-ctl`, `conv-ctl` (`M.txt` converted, as asked), `flt-ctl`, `hp-label-ctl`: PASS.
Registry restored identical (SHA-256 BA9B23CF...) in both runs.

Consumers enumerated: see plan.md *Design*.

## Implementation

(below)
