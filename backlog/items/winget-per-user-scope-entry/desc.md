---
title: winget: offer a per-user install (--scope user), proven in Windows Sandbox first
type: improvement
status: open
severity: 3
area: build-release
source: leftover:072
who: both
created: 2026-08-29
updated: 2026-10-26
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# winget: offer a per-user install (--scope user), proven in Windows Sandbox first

## Problem

winget install --scope user is not offered. The per-user manifest entry was part of the first submission, was blamed for the first validation failure and removed - and then the machine-only manifest failed identically, which refuted that (the real defect was the disclaimer page aborting silent installs, fixed in 0.1.7). Whether a per-user entry works has never been tested. Known: Inno Setup accepts the switches (PrivilegesRequiredOverridesAllowed=dialog implies commandline); a probe with the installer's privilege configuration took /VERYSILENT /CURRENTUSER, exited 0, installed into %LOCALAPPDATA%\Programs\<AppName> without elevation and wrote the HKCU uninstall key {AppId}_is1.

## Evidence

specs/072-winget-distribution/REMAINING-WORK.md, section P2 'Per-user installation is untested, not impossible' (procedure there) and 'Not remaining' (the publish.ps1 assertion). tools/winget/templates/installer.yaml.in line ~13 comments on the removed 'Scope: user' entry; the machine entry is at ~line 57. NEXT-WORK §6, P2 (L2040). Migrated from specs/NEXT-WORK.md §6 (at 7993914c).

## Expected

Either the manifest offers a user-scope installer entry that passed Tools\SandboxTest.ps1 of a winget-pkgs clone and is submitted as a pull request of its own, or the attempt failed in the sandbox and nothing reached the catalogue (the branch dropped, the reason recorded).

## Approach

On a branch: add to tools/winget/templates/installer.yaml.in an x64 entry with 'Scope: user', the same InstallerUrl, InstallerSha256 {{SHA256}} and InstallerSwitches Custom: /CURRENTUSER (and Custom: /ALLUSERS on the machine entry if both are wanted); reinstate the PrivilegesRequiredOverridesAllowed assertion in publish.ps1 with it; run publish.ps1 -Version <current released version> (generates and validates against the published asset, no new release needed); run Tools\SandboxTest.ps1 against that directory. Windows Sandbox must be enabled (admin; not available on GitHub runners) - that run may need a person.

## Notes

microsoft/winget-pkgs#426090 was merged on 2026-10-08 and the catalogue is current (0.2.0, 2026-10-25), so nothing is under moderation any more. Still: do not add the per-user entry to tools/winget/templates/ on main before it passed the sandbox - the Publish to winget workflow submits the templates on every release publication, and an unproven change in a submission is how the first attempt went wrong. The same entry is RW072 P2 and is listed in NW §B 'Release and catalogue housekeeping'.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §5–§8 (feature 242)
- 2026-10-17 — migration review N3: migration remark replaced; not part of a re-pointing push
- 2026-10-26 — related item winget-submit-release-after-pr-426090 closed: done: #426090 merged 2026-10-08, 0.1.9, 0.1.10 and 0.2.0 submitted by the workflow and merged, the catalogue is current and works; maintainer 2026-10-26
- 2026-10-26 — unblocked: microsoft/winget-pkgs#426090 merged 2026-10-08; the catalogue holds 0.2.0, nothing is under moderation now; maintainer 2026-10-26
- 2026-10-26 — Notes: the #426090 gate replaced - the PR is merged, the sandbox-first rule stays
