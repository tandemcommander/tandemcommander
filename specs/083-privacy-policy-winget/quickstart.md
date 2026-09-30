# Quickstart: validating the privacy statement

Proves the feature end to end. References: [contracts/privacy-statement.md](contracts/privacy-statement.md),
[contracts/winget-privacyurl.md](contracts/winget-privacyurl.md), [data-model.md](data-model.md).

## Prerequisites

- Repository on branch `083-privacy-policy-winget` (or `main` after merge).
- Windows PowerShell 5.1 and `winget` (for `winget validate`).
- Network access to github.com (the generator downloads the released
  installer to hash and verify it).

## 1. Evidence coverage (SC-002)

1. Open `research.md` § Data-surface inventory and `fix-log.md` § Claim map.
2. Every inventory row has ≥ 1 evidence item and a `statement_section`.
3. Every claim in `PRIVACY.md` appears in the claim map with ≥ 1 surface id
   or an `attribution`/`scope` mark.

Expected: 0 rows without evidence, 0 claims without mapping.

## 2. Independent claim review (SC-003)

A reviewer who did not write the document (a separate agent session) receives
`PRIVACY.md`, the inventory and the claim map, re-opens the cited evidence and
marks each claim `supported` / `overstated` / `false`.

Expected: all `supported`; any other verdict is fixed and re-reviewed.

## 3. Reader test (SC-004)

A reader unfamiliar with the code base answers from `PRIVACY.md` alone:
(1) telemetry/accounts? (2) when is the network used, and who receives what?
(3) what is stored and where? (4) how are saved passwords protected, with and
without a master password? (5) what does uninstall leave? (6) which parts are
governed by others? (7) how to remove all data? (8) whom to contact?

Expected: 8/8 correct, under 10 minutes.

## 4. Manifest generation (W1, W2)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\winget\publish.ps1 -Version 0.1.8
```

Expected: `Manifest validation succeeded.`; the rendered
`tools\winget\manifests\0.1.8\PavelStupka.TandemCommander.locale.en-US.yaml`
contains the `PrivacyUrl` line exactly as in W1. The script writes into
`tools\winget\manifests\0.1.8\`; do not commit that directory from this
feature (W4) — `git restore`/delete it after the check.

## 5. Reachability (W3) — after merge and push only

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md
```

Expected: `200`.

## 6. Private channel gate (C7)

```bash
curl -s https://api.github.com/repos/tandemcommander/tandemcommander/private-vulnerability-reporting
```

Expected: `"enabled": true` if and only if `PRIVACY.md` links to
`/security/advisories/new`.

## 7. Update rule present (FR-007)

`CLAUDE.md` names `PRIVACY.md` and lists the C8 triggers.
