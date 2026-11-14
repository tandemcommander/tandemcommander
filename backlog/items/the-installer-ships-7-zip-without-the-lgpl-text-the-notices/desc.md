---
title: The installer ships 7-Zip without the LGPL text the notices promise
type: bug
status: new
severity: 6
area: build-release
source: review:428
who: agent
created: 2026-11-14
updated: 2026-11-14
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# The installer ships 7-Zip without the LGPL text the notices promise

## Problem

The installed program contains 7-Zip (`plugins\7zip\7za.dll`, GNU LGPL 2.1), and `doc/third_party.txt` says the LGPL is "a copy of which is included with this software" - but the installer (`setup/tandemcommander.iss`) installs no LGPL text and no 7-Zip licence. Distributing an LGPL binary without its licence text is a licence obligation not met. Feature 428 fixed it for the portable ZIP only (it now carries `doc\license\license_lgpl21.txt` and `doc\license\7zip_license.txt`).

## Evidence

Found by the independent review of feature 428 (`specs/428-portable-build/fix-log.md`, section "three independent refute-first reviews", finding B4). Sources of the texts: `src/plugins/7zip/7za/DOC/copying.txt` (LGPL 2.1) and `src/plugins/7zip/7za/DOC/License.txt` (7-Zip's licence with the unRAR restriction). `doc/license/` holds bsd3, gpl, gpl3, mit and zlib only. The portable package rule: `tools/portable/make_portable_zip.py` (the two `extra.append` lines for 7-Zip), checked by `specs/428-portable-build/probe/zip_check.py` Z2.

## Expected

The installer installs the same licence files as the portable ZIP (the GPL text, `doc\third_party.txt`, `doc\license\*.txt` including the LGPL 2.1 text and 7-Zip's licence), and the uninstaller removes them. `PRIVACY.md` (*Installing and uninstalling*) is updated in the same change, because what the installer writes changes.

## Log

- 2026-11-14 — created (source review:428)
