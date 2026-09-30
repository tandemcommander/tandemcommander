# Remaining Work — Feature 072 (winget distribution)

**As of 2026-08-29; section P0 added 2026-09-30.** The feature itself is done and shipped: Tandem Commander
0.1.7 is submitted to the catalogue as `PavelStupka.TandemCommander`
([microsoft/winget-pkgs#426090](https://github.com/microsoft/winget-pkgs/pull/426090)),
the tooling is in `tools/winget/`, and the workflow submitted that pull request
by itself when the GitHub release was published.

Everything below is follow-up work, ordered by what it costs users. Nothing
here blocks the feature.

---

## Gate: is #426090 merged?

**Check this first — it decides whether the rest is worth starting.**

A new package waits on a human moderator; expect days. While the pull request
is open, do **not** change `tools/winget/templates/` and do **not** publish a
release: the workflow submits automatically on release publication, and a
second, unreviewed change during moderation is how the first attempt went
wrong.

Once merged (allow a few hours for the index):

```
winget install tandemcommander
winget show PavelStupka.TandemCommander
```

After that, the cost of a mistake drops sharply — a failed *update* pull
request is closed and resubmitted, with no bearing on whether the package
itself is accepted.

---

## P0 — Audit of #426090 (2026-09-30): what moderation is likely to ask next — NOT ACTED ON

**Recorded, deliberately not implemented — the maintainer decides when.** After
the `DisplayVersion` fix was pushed (PR head `a6cf23e74`, validator queued at
20:37 UTC, `New-Package` re-added), four independent read-only audits (manifest
policy, PR process/labels, repository tooling, upgrade detection) checked the
claim "nothing more is needed from the author". It holds only for the
immediate step: the re-validation runs by itself and nothing has to be
triggered. The items below are what the moderators demanded from comparable
new packages in September 2026, verified at the source (PR comments via the
GitHub API, `git`, the installed registry key, winget-cli source).

**Timing matters.** Every push to the PR removes all validation labels and
restarts validation (`.github/policies/labelManagement.issueUpdated.yml` in
winget-pkgs). A change is cheapest *before* the queued run completes; after
that each push costs another validation round and a place in the queue.

### Likely moderator requests

1. **0.1.7 does not start without the Visual C++ runtime — highest risk.**
   Tag `v0.1.7` has no `src/vcxproj/copy_vc_runtime.cmd`; `CHANGELOG.md`
   (0.1.8 section, ~line 153) states that 0.1.0–0.1.7 depend on the installed
   redistributable. The manifest declares no
   `Dependencies: PackageDependencies: Microsoft.VCRedist.2015+.x64`. The
   Azure pipeline only installs (check 08), it does not start the program, but
   the moderator launches new packages: on #425232 stephengillie reported
   *"Executable … returned exit code: -1073741515"* (DLL not found) and denelon
   later wrote *"Thank you for addressing the missing Visual C++ runtime
   dependency"*.
2. **Moderators ask for the current release.** #424958 (TestMyLogic) went
   through exactly our sequence — the same "Deterministic automation"
   `DisplayVersion` comment (build 1811), then a month later denelon: *"please
   update the submission to the current supported … release and allow
   validation to run again"*. Also #428418 and #427695 (newer release with
   security-relevant fixes). 0.1.8 is published and fixes precisely the runtime
   dependency and the antivirus findings.
3. **`PrivacyUrl` may be required (uncertain).** 26–28 Sep 2026 denelon asked
   for a privacy disclosure (policy 1.5.1) on products that store credentials —
   verified on #425232 (*"please publish a privacy disclosure for the
   application and add its URL to the manifest as `PrivacyUrl`"*), also cited
   #428798, #429341, #426614. Tandem Commander stores FTP/SFTP passwords and
   mdview fetches remote images after consent. tandemcommander.org has no
   privacy page (`/privacy/` → 404). Needs a page on the website (outside this
   repository), then `PrivacyUrl:` in `templates/locale.en-US.yaml.in`.
   **Update 2026-09-30 — prepared by feature 083:** `PRIVACY.md` (repository
   root, evidence-backed, independently reviewed) and the template line
   `PrivacyUrl: https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md`
   exist. What remains: the URL answers only after the feature is merged to
   `main` and pushed (check for 200 first), and the field reaches the PR only
   with the next push to #426090 (step 1 below). See
   `specs/083-privacy-policy-winget/closing-report.md`.

### Corrections to earlier explanations

4. **`Policy-Test-1.2` is not about the new code-signing certificate** (the PR
   comment of 2026-09-17 assumed it was). The label came from step *05 Manifest
   Policy Validation* (09:57:06–09:57:12 on 08-29), which reads manifest text
   only and ran before the installer scan: *"Validation concluded that this
   task needs to go to manual review."* On #433311 the same label was a
   "Targeted Brand" heuristic on the Description; ours names Norton Commander,
   Altap Salamander, Microsoft Edge, PowerShell, Windows Terminal. Not
   confirmable (the result JSON is an Azure artifact). Resolution is an
   administrator waiver (`@wingetbot waivers add Policy-Test-1.2`); #433311
   took 13 days. Rewording the Description is allowed but costs a validation
   round.
5. **`Validation-Guide`** is added by the policy bot together with a policy
   label; it asks nothing of the author and is removed when validation
   completes.
6. **`AppsAndFeaturesEntries.DisplayName` does not match the installer.**
   `AppVerName` is commented out (`setup/tandemcommander.iss:13`), so Inno
   Setup writes `DisplayName = "Tandem Commander <version>"` (registry on this
   machine: `Tandem Commander 0.1.8`; 077 fix-log: `Tandem Commander 0.1.7`);
   the template says `Tandem Commander`. Upgrade matching is unaffected
   (ProductCode is a strong match), but it is inaccurate, and `fix-log.md`
   (~lines 128–131) wrongly claims check 09 verified `DisplayName` and
   `DisplayVersion` — per winget-pkgs `doc/Validation.md` check 09 covers
   MSIX, icon and InstallationMetadata only. Options: set
   `UninstallDisplayName=Tandem Commander` in the `.iss` from the next release,
   or render the versioned name into the manifest.
7. **`ProductCode` should also be at installer level.** winget-pkgs schema
   1.10.0 `installer.md`: *"When AppsAndFeaturesEntries are specified, the
   ProductCode should be placed both within the installer and the
   AppsAndFeaturesEntries"*. The template has it only in the entries.

### Verified as fine

- Upgrade without `DisplayVersion`: winget-cli `Manifest.cpp`
  (`GetArpVersionRange`) builds no range without it and `CompositeSource.cpp`
  (`GetMappedInstalledVersion`) then returns the ARP version unchanged;
  ProductCode is a strong-match field. `winget list "Tandem Commander"` here
  shows `ARP\Machine\X64\{35C0B0DC-…}_is1 | 0.1.8`. Caveat (known, P2): a
  per-user (HKCU) install will not upgrade — the manifest offers only
  `Scope: machine`.
- The deterministic moderation bot
  (`Tools/ManualValidation/ManualValidationPipeline.ps1` in winget-pkgs,
  232 comments sampled) has no other rule that matches these manifests. Schema
  1.10.0 accepted, 16 tags (the limit), licence, URLs, hash, ReleaseDate,
  moniker (free) all fine.
- The `Co-Authored-By` trailer did not affect the CLA check.

### Recommended plan (when the maintainer asks)

1. **Re-point #426090 to 0.1.8** — resolves 1 and 2 and lets 6 and 7 be fixed
   in the same push: in the fork branch replace
   `manifests/p/PavelStupka/TandemCommander/0.1.7/` with `0.1.8/` rendered by
   `publish.ps1 -Version 0.1.8` from `main` (wingetcreate's formatting is not
   required), retitle the PR to
   `New package: PavelStupka.TandemCommander version 0.1.8`, comment why.
   Alternative staying on 0.1.7: add the VCRedist dependency — worse, it ships
   a version users should not get.
2. Template fixes (6, 7) in `tools/winget/templates/installer.yaml.in`
   together with step 1, so the repository and the PR stay identical.
3. `PrivacyUrl` (3) — ready since feature 083: include it in the same push as
   step 1 once `PRIVACY.md` is on `main` (URL returns 200). Rendering from
   `main` picks it up automatically.
4. **Run the 0.1.8 workflow from `main`, never from tag `v0.1.8`** — the tag's
   template still contains `DisplayVersion: {{VERSION}}` (line 43).

### Repository record fixes (no behaviour change)

- `CLAUDE.md`, 072 entry: claims `publish.ps1` refuses to generate without
  `PrivilegesRequiredOverridesAllowed` — that assertion was removed (see *Not
  remaining* below).
- `templates/installer.yaml.in:13-21` still gives the refuted "pipeline runs
  elevated" reason for the per-user failure (`publish.ps1:20-23` points to it).
- `fix-log.md` ~lines 128–131: the check-09 claim (item 6).
- `publish.ps1:194` vs `:203`: placeholders are substituted *before* comment
  lines are stripped, so a wrapped ReleaseNotes line starting with `#` (e.g.
  `#426090`) would be silently dropped. Not triggered by 0.1.8 (820 chars, no
  `#`).
- This file's Gate says "change nothing under templates" — it should mention
  the 2026-09-30 `DisplayVersion` exception.

---

## P1 — Upgrading over a running instance aborts the install — CLOSED (feature 080, 2026-09-20)

> **Closed, and the diagnosis below corrected.** The abort was caused by
> `salmon.exe`, not by the program: a process without a window cannot be closed
> by the Restart Manager, which then fails the whole request immediately —
> the main program was never asked. The helper was removed in feature 079;
> feature 080 made the close unattended-safe (no prompt, prompt refusal when
> busy), registered the program for a restart after the update, and removes
> the stale `salmon.exe` of upgraded installations (not via `[InstallDelete]`,
> which would bring exit 5 back). Updating a running 0.1.7 to 0.1.8 works.
> Record: `specs/080-restart-manager-upgrade/closing-report.md`. Note that
> quickstart §2b no longer uses `Start-Process -Wait`.
>
> The original text follows, unchanged.

**Affects real users the moment the package is in the catalogue.**

With Tandem Commander open, a silent install fails:

```
RestartManager found an application using one of our files: Tandem Commander, File Manager
Some applications could not be shut down.
Defaulting to Abort for suppressed message box (Abort/Retry/Ignore)
EXIT CODE: 5   (changes rolled back)
```

`winget upgrade` passes `/SUPPRESSMSGBOXES`, so the Abort/Retry/Ignore prompt
is answered with **Abort**. Anyone who upgrades with the program open gets a
failure. This is not a regression — the installer has always behaved this way;
it simply never mattered before, because upgrading meant running the installer
by hand and seeing the prompt.

**The fix belongs in the application, not the installer**: respond to the
Restart Manager's shutdown request (`WM_QUERYENDSESSION`, and
`RegisterApplicationRestart` if the session should come back afterwards) so
Setup can close the program and restart it. `salmon` (the bug reporter) was
also listed as holding files and needs the same treatment.

**First step**: reproduce with the program open, using quickstart §2b's
command, and confirm exit 5. Then decide whether the panels' state should be
preserved across the restart — that is the design question, not the API.

Worth a feature of its own; scope is `src/`, not `setup/`.

---

## P2 — Per-user installation is untested, not impossible

`winget install --scope user` is not offered. The manifest entry was part of
the first submission, was blamed for the validation failure and removed — and
then the machine-only manifest failed identically, which refuted that. The
real defect (the disclaimer page aborting silent installs, fixed in 0.1.7)
masked everything. **Whether a per-user entry works has never actually been
tested.**

What is known: Inno Setup accepts the switches.
`PrivilegesRequiredOverridesAllowed=dialog` implies `commandline`, and a probe
built with the installer's exact privilege configuration took
`/VERYSILENT /CURRENTUSER`, exited 0, installed into
`%LOCALAPPDATA%\Programs\<AppName>` with no elevation and wrote the `HKCU`
uninstall key `{AppId}_is1`.

**No manual manifest editing is needed** — the generator has no per-scope
logic left, so the template is the whole definition. But the workflow submits
on the next release publication, so the entry must be proven *before* it lands
on `main`.

**Procedure — needs no new release**, because `publish.ps1` works against the
already-published asset:

1. On a branch, add back to `tools/winget/templates/installer.yaml.in`:
   ```yaml
     - Architecture: x64
       Scope: user
       InstallerUrl: <same as the machine entry>
       InstallerSha256: {{SHA256}}
       InstallerSwitches:
         Custom: /CURRENTUSER
   ```
   (and `Custom: /ALLUSERS` on the machine entry, if both are wanted)
2. `publish.ps1 -Version <current released version>` — generates and validates
3. `Tools\SandboxTest.ps1` from a winget-pkgs clone against that directory —
   the environment that rejected it twice. Windows Sandbox must be enabled;
   it is not available on GitHub runners, so this cannot be automated.
4. Passes → merge and submit as a pull request of its own. Fails → drop the
   branch; nothing reached the catalogue.

---

## P3 — `checkver` points at upstream and there is no update feed

The legacy `checkver` plugin still checks Open Salamander's site, and is
disabled in `plugins.cfg` anyway. With winget in place, updates are handled
for anyone who installs from the catalogue — but not for anyone who downloaded
the installer from the website.

Two ways out, and the choice is a product decision:

- point `checkver` at the GitHub Releases API, or
- drop it and treat winget as the update channel, saying so on the website.

Noted in `architecture/10-plugin-maintenance-outlook.md:90`.

---

## P4 — Node.js 20 deprecation warning in every workflow run

`actions/checkout@v4` and `actions/upload-artifact@v4` run on Node 20, which
GitHub has deprecated; the runner forces Node 24 and prints a warning on every
run. It is cosmetic today and will not stay that way.

All four workflows are affected — `winget-publish.yml`, `pr-msbuild.yml`,
`auto-label-author.yml`, `pr-comments-guard.yml` (the last two through
`actions/github-script@v7`). Bump them together, so the repository does not
end up with two conventions.

---

## Not remaining, recorded so it is not re-litigated

- **The version boundary for scope switches** (`$UserScopeSinceVersion`) was
  removed and must not come back: Inno Setup's `dialog` override implies
  `commandline`, so every released version accepts the switches. See plan.md
  D6.
- **The `PrivilegesRequiredOverridesAllowed` assertion** in `publish.ps1` was
  removed with the per-user entry. If P2 reinstates the entry, reinstate the
  assertion with it — it exists to stop the manifests advertising an install
  mode the installer would reject.
- **Manifest schema 1.10.0 is accepted** by the catalogue, although the pull
  request template mentions 1.12.
