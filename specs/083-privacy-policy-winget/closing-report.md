# Closing Report — Feature 083 (privacy statement for the winget catalogue)

**Date**: 2026-09-30 · **Branch**: `083-privacy-policy-winget` · **Product
code changed**: none (FR-010).

## Delivered

| Deliverable | Where |
|---|---|
| Privacy statement, 11 sections per contract C2, describes 0.1.8 | `PRIVACY.md` |
| `PrivacyUrl` (literal, `blob/main/PRIVACY.md`) + authoring note | `tools/winget/templates/locale.en-US.yaml.in` |
| One-paragraph pointer | `README.md` § Privacy; `tools/winget/README.md` |
| Update rule (C8 triggers) + Recent Changes entry | `CLAUDE.md` *Key Facts* "Privacy statement"; *Recent Changes* 083 |
| Nine side findings, F1 first (F8 later withdrawn) | `specs/NEXT-WORK.md` item 7 |
| 072 § P0 item 3 and plan step 3 marked prepared | `specs/072-winget-distribution/REMAINING-WORK.md`, `specs/NEXT-WORK.md` item 6 |

## Evidence and verification

- **Inventory** (research.md): four independent read-only researchers (main
  app + installer; FTP/SFTP + password manager; WebView2 viewers; the other
  16 plugins) plus a `dumpbin /imports` scan of all 26 shipped modules — only
  `ftp.spl`, `sftp.spl`, `mdview.spl` and the exe (network drives/shares,
  `inet_addr`) import anything network-capable. Product sources at HEAD are
  identical to `v0.1.8` (T003).
- **Claim map** (fix-log.md): every factual sentence → evidence.
- **Independent review** (T010): 2 false claims (shell-extension
  registration — gated on a DLL 0.1.8 does not ship) and 11 overstated /
  unverifiable ones found and corrected; missing disclosures added (Windows
  Error Reporting, third-party shell extensions, Regedit LastKey, Dropbox /
  Google Drive settings read). Narrowed second pass (T010b) on every changed
  or new claim: all supported except four one-sentence issues (per-drive
  folder is cleared by Clear History; a UI label; Markdown links can open
  without a click; OneDrive), fixed and recorded in fix-log.
- **Reader test** (T011): 8/8 questions answered correctly from `PRIVACY.md`
  alone, ~6–8 minutes; eleven wording issues resolved.
- **Manifest** (T009): `publish.ps1 -Version 0.1.8` → `Manifest validation
  succeeded.`, `PrivacyUrl` rendered after `PublisherSupportUrl`, no
  `DisplayVersion`; generated directory deleted (W4).

## Quickstart outcomes (T016)

| § | Check | Result |
|---|---|---|
| 1 | Evidence coverage | every claim mapped (fix-log claim map) |
| 2 | Independent review | T010 + T010b — see fix-log |
| 3 | Reader test | 8/8, < 10 min |
| 4 | Manifest generation | validation succeeded |
| 5 | URL returns 200 | **owed after merge + push**: currently 404 (expected). Command: `curl -s -o /dev/null -w "%{http_code}\n" https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md` |
| 6 | Private channel gate | setting `enabled: false` ⇔ no `/security/advisories` link in `PRIVACY.md` — consistent |
| 7 | Update rule present | `CLAUDE.md` *Key Facts* "Privacy statement" |

## Owed to the maintainer

1. Commit, merge to `main`, push — then check § 5 returns 200.
2. Optional: enable *Settings → Security → Private vulnerability reporting*,
   then add the second contact line to `PRIVACY.md` § Contact (contract C7).
3. Decide when `PrivacyUrl` reaches microsoft/winget-pkgs#426090 —
   recommended together with re-pointing the PR to 0.1.8
   (`specs/072-winget-distribution/REMAINING-WORK.md` § P0).
4. F3 (Markdown may open the browser without a click) needs a GUI test; if
   confirmed, fix it and update `PRIVACY.md` § network in the same change.

## Lessons

- The first inventory row for the shell extension was written from the
  registration code without its `FileExists` gate — the product never runs
  that path. Evidence must include the *reachability* of the cited code in
  the shipped build, not just its existence.
- Running the reader test in parallel with the fact review saved one agent
  round without risk: it tests wording, and wording fixes were applied
  together with fact fixes in one revision.
