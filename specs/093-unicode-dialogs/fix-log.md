# Fix log: feature 093 - Unicode dialogs (encoding cluster B-1)

Branch `093-unicode-dialogs`, based on `092-name-identity-unicode`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T001 - baseline

- saltests before the feature: 12,828 / 0. Strict guard `TOTAL: 0`.
- `probe/B1Probe.cs` + `result.txt`: the Win32 semantics the feature rests on
  (research sections 1.3, 1.4), measured on this machine (code page 1250).
