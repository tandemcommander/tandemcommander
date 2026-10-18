# Fix log — feature 245 (import settings from Altap Salamander / Open Salamander)

## 2026-10-18 — specify

- Branch `245-settings-import-salamander` created from `main` at `869d9690`.
- Read-only analysis (three parallel research passes + own checks) recorded in
  `analysis.md`: core configuration inventory, plugin configuration and
  passwords, shortcuts / toolbars / associations / identity documents.
- Measured on the maintainer's machine (read-only): Altap Salamander 4.0
  (config 103) is the only genuine foreign source; `Open Salamander\5.0`
  (105) and `Newt Commander\0.1` (105) were written by fork development
  builds.
- Verified by hand: the Keyboard page states that TC command shortcuts are
  fixed (`src/lang/lang.rc:1217`); the startup `config.reg` import writes
  every key of a foreign `.reg` after one question (`src/salamdr2.cpp:3017-3060`).
- Prior work found: feature 057's standalone script and its research; this
  feature reuses its decisions and adds an in-app, translated wizard with an
  *Add* mode.
- `spec.md` written; 2 clarification questions open (FR-002, FR-032).

## 2026-10-18 — clarify

- Q1 → B: Options menu + a one-time offer at the first start of a fresh
  configuration (existence check only) — FR-002, FR-005, FR-031, edge cases,
  constitution note.
- Q2 → A: the 057 script and its tests are retired — FR-032.
- Q3 → A: append-only plugin import call, interface 108, FTP merges its own
  connections — FR-021a, FR-021b, Assumptions.
