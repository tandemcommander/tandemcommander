# Probe seam - 374 (Debug builds only)

Extends the seam `TC_PROBE_DRIVES_DUMP=<file>` of features 246 / 289
(`specs/246-network-drive-labels/contracts/probe-seam.md`). Absent from Release (the whole
`ProbeDrivesDump` is `#ifdef _DEBUG`).

New lines, one per `CDrivesList::BuildData`:

```text
WSL on=<0|1> count=<n> us=<microseconds of the WSL part> fp=<hex fingerprint>
TIME bar=<0|1> us=<microseconds of the whole BuildData>
```

- `on=0`: the option is off - no registry access, `count=0`.
- The existing `ALL idx=<i> type=<t> text=<text>` lines list the new items with `type=19`
  (`drvtWSL`) and `type=20` (`drvtWSLMenu`); the existing `TIP` lines (drive bar tooltips) give
  their tooltips.

Environment `TC_PROBE_WSL_LXSS=<subkey of HKCU>` (Debug only): read the distributions from that
key instead of `Software\Microsoft\Windows\CurrentVersion\Lxss`, so that the probe can show
"no distribution", "one distribution" and unusable names without touching the real WSL
registration.
