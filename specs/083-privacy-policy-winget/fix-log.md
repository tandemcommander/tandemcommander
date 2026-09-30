# Fix Log — Feature 083 (privacy statement for the winget catalogue)

## Status

- 2026-09-30 — implementation started on branch `083-privacy-policy-winget`
  (from `main` at `7eb2fac`).
- 2026-09-30 — all 17 tasks done; nothing committed. Owed: merge + push,
  then quickstart §5 (URL 200); see closing-report.md.

## Pre-flight

**T002 — private vulnerability reporting** (2026-09-30T21:28Z):
`GET /repos/tandemcommander/tandemcommander/private-vulnerability-reporting`
→ `{"enabled": false}`. Consequence (contract C7): `PRIVACY.md` offers the
public issue tracker only; the private channel is an open item.

**T003 — facts re-verified at HEAD**:

- Product sources at HEAD are **identical to tag `v0.1.8`**
  (`git diff --stat v0.1.8 HEAD -- src setup plugins.cfg` is empty), so the
  0.1.8 Release tree (FileVersion 0.1.8, 2026-09-20) and the installed 0.1.8
  describe exactly the code the inventory was taken from; the dumpbin import
  scan in research.md stands.
- `crash-report` — confirmed: closing message "Nothing is sent anywhere"
  (`src/callstk.cpp:783`, `src/lang/texts.rc2:1893`); full command line
  (`src/bugreprt.cpp:1723`), volume name and serial number
  (`src/bugreprt.cpp:2460-2468`).
- `pwd-scramble` / `pwd-aes` — confirmed (`src/pwdmngr.h:74-77`: "otherwise
  they are only scrambled").
- `ftp-history` (F1) — confirmed: `src/plugins/ftp/dialogs1.cpp:925-931`
  restores the raw typed Address ("history stores what the user typed") and
  stores it in `HostAddressHistory` during Quick Connect.
- `net-mdview-img` — confirmed: `WinHttpOpen(L"OpenSalamander-mdview", …)`
  at `src/plugins/mdview/webglue.cpp:96`.
- Uninstall — confirmed: `setup/tandemcommander.iss` sections are `[Setup]
  [Languages] [CustomMessages] [Tasks] [Files] [Icons] [Run] [Code]` — no
  `[Registry]`, no `[UninstallDelete]`.

No inventory row changed.

**T004** — F1–F9 recorded as `specs/NEXT-WORK.md` item 7.

## Claim map

Every factual sentence of `PRIVACY.md` → inventory ids in `research.md`
(or `scope` / `attribution`, contract C5/C6). Verdict column filled by the
independent review (T010).

| # | PRIVACY.md section — claim | Evidence (research.md ids / decisions) | Verdict |
|---|---|---|---|
| S1 | Summary — no accounts, telemetry, analytics, advertising; nothing sent to the project | net-none-core, net-installer, dumpbin import table, D (16 plugins: no network API) | supported |
| S2 | Summary — network only when you ask | all `net-*` rows | unverifiable (F3) → **hedged**: "each started by something you do" |
| S3 | Summary — stored data stays on your computer | all stored rows | minor → "stays in your Windows user profile" (roaming) |
| S4 | Summary — scope (program + installer + bundled plugins; not website/repo/catalogue/other plugins) | scope (C5), R5 | supported |
| C1 | Settings in `HKCU\Software\Tandem Commander` | cfg-main | supported |
| C2 | Settings contents incl. panel tabs (archive/FTP/SFTP locations), hot paths, user menu, viewers/editors/archivers, plugin settings | cfg-main, plugin-cfg | supported |
| C3 | Saved on exit (*Save configuration on exit*, default on) or on explicit save | cfg-main (`mainwnd2.cpp:7138`, `dialogs4.cpp:273`, `lang.rc:104`) | supported |
| C4 | History examples (masks, searched text, copy/move targets, changed-to folders, command line, compared files, viewed pictures, registry paths, FTP addresses) | hist-main, plugin-cfg, ftp-history | supported |
| C5 | History page: *Save history*, two *Command line history* options, *Clear History* | hist-main; `lang.rc:1572-1588` | overstated → **rewritten**: history on by default, Working Directories option added |
| C6 | Viewer's last search text kept even with history off | viewer-find | overstated → **rewritten**: several values kept with history off, not cleared by Clear History |
| C7 | *Options → Export Configuration* writes everything incl. stored passwords | cfg-export; `texts.rc2:149` | supported |
| C8 | Windows keeps hot paths in the jump list | jumplist | supported |
| C9 | Bookmarks: address, port, user, starting folder, similar details | ftp-bookmarks, sftp-bookmarks | supported |
| C10 | SFTP stores key file location, never the key | sftp-bookmarks (`session.cpp:535-566,672`) | supported |
| C11 | SFTP remembers trusted server fingerprints | sftp-hostkeys | supported |
| C12 | FTP anonymous e-mail, default `name@someserver.com`, plain text | ftp-anon | supported |
| C13 | Connection logs in memory only unless the user saves/copies | ftp-logs, sftp-memory | supported |
| C14 | Crash report written to `%LOCALAPPDATA%\Tandem Commander`, program tells where | crash-report (`callstk.cpp:724-783`) | supported |
| C15 | Reports never sent | crash-report; net-none-core | supported |
| C16 | Report contents: open folder/file names, full command line, loaded program files, Windows/hardware, drive names + serial numbers | crash-report (`bugreprt.cpp:1413-1565,1723,2460-2468`) | overstated (list too short) → **rewritten**: + memory excerpts, drive size/free space/device target |
| C17 | User name usually appears in paths | crash-report (inference from profile paths, stated as "usually") | supported |
| C18 | Program never deletes reports | crash-report | supported |
| C19 | WebView2 data in `%LOCALAPPDATA%\Tandem Commander\WebView2` (caches, internal databases) | wv2-udf | supported |
| C20 | Internal addresses without file names | wv2-udf (`webhost.cpp:588-602`) | supported |
| C21 | Program does not clear the folder | wv2-udf | supported |
| C22 | Temp working copies in `%TEMP%`, removed when not needed / at close, crash leftovers → offer to delete at next start | temp-cache, plugin-temp | overstated → **scoped** to working folders; removal step broadened (SAL/PACK/MFL) |
| C23 | Passwords saved only with *Save password* (SFTP also passphrase) | ftp-secrets, sftp-secrets; `ftp lang.rc:213`, `sftp lang.rc2:149` | overstated → **rewritten**: Save passphrase, FTP proxy Save password |
| C24 | With Master Password: AES-256, key derived from it | pwd-aes | supported |
| C25 | Master Password never stored; in memory until close | pwd-verifier (`pwdmngr.h:98`) | supported |
| C26 | Without Master Password: obfuscated, method public, recoverable | pwd-scramble | supported |
| C27 | FTP Quick Connect address with password saved in plain text; *Clear History* removes | ftp-history (F1); `ftp.cpp:1021-1041` | overstated (too narrow) → **rewritten**: Quick Connect + Change Directory + command line; removal at next save |
| C28 | Cancelled Master Password prompt → SFTP password obfuscated only | sftp-secrets (F7) | supported |
| C29 | Network-drive passwords: Windows dialog, saved by Windows only if chosen | net-drives | supported |
| C30 | Never contacts the internet on its own: no update checks, telemetry, crash uploads | net-none-core, D, R5 (checkver not shipped), dumpbin table | unverifiable (F3) → **hedged** ("does not contact the internet on its own") |
| C31 | FTP: server/proxy entered; unencrypted incl. password; no FTPS in this version; anonymous sends `anonymous` + e-mail | net-ftp | supported |
| C32 | SFTP: encrypted SSH; banner `SSH-2.0-libssh2_1.11.1_DEV`; trust prompt on first connect / key change | net-sftp | supported |
| C33 | Remote images only after *View → Load Remote Images*, per window, not remembered; host receives IP, time, address, `OpenSalamander-mdview`; nothing else from the document; other internet loads blocked | net-mdview-img, net-viewers-blocked; `mdview lang.rc2:45` | unverifiable (F3) → **hedged**: "designed to block", proxy/redirect added, links in documents moved here |
| C34 | Network drives: Windows connects | net-drives | supported |
| C35 | Program links open on click; point to tandemcommander.org / GitHub except PictView home page + support address (pictview.com); Markdown links open in browser/mail and go where the author pointed | net-browser, net-mdview-links | unverifiable (F3) → **split**: program links (click) vs document links |
| C36 | *Files → Email* passes files to the mail program | net-mail; `texts.rc2:26,36` | supported |
| C37 | Portables identifies the program to a device by name and version | net-portables | wrong string/trigger → **rewritten**: "Windows Portable Devices for Tandem Commander" + plugin version, when you open a device |
| C38 | Windows handles network drives/credentials, jump list, cloud status icons (provider software) | attribution; jumplist, net-drives | supported |
| C39 | WebView2 provided by Microsoft; diagnostic data, crash reports, updates governed by Microsoft/Windows settings; program turns off background networking, sync, component updates, SmartScreen; does not change diagnostic collection | attribution; net-wv2-ms (`webhost.cpp:47-48,259-261`); R10 | supported |
| C40 | External archivers only if configured | net-archivers | overstated (archivers pre-configured) → **rewritten** |
| C41 | Plugins from other sources not covered | scope | supported |
| C42 | Source-only plugins incl. an update checker contacting the original Open Salamander site; not installed | R5; D (`checkver/internet.cpp:14-15`) | supported |
| C43 | Installer downloads nothing; copies files, shortcuts, uninstall registration | net-installer | supported |
| C44 | Program registers its shell extension when it runs | shellext-reg | false → **removed** (registration gated on `utils\salext*.dll`, not shipped) |
| C45 | Uninstall leaves: registry key, `%LOCALAPPDATA%` folder, `%APPDATA%` folder (export default), shell-extension registration (no personal data except program location), crash leftovers in temp | inventory header (`.iss` sections), cfg-export, shellext-reg, temp-cache | false (shell-ext bullet) → bullet **removed** |
| C46 | Removal steps | locations of all stored rows | overstated → **rewritten** (see C22, C6; jump list line) |
| C47 | 0.1.0–0.1.7 crash helper, upload off in every release, local only; removed in 0.1.8 | R8 (CLAUDE.md feature 079) | supported |
| C48 | Contact: issue tracker, public | R4, T002 | supported |
| C49 | Describes 0.1.8 | R8; T003 (sources = `v0.1.8`) | supported |

**Claims added by the T010/T011 revision** (re-reviewed in T010b):

| # | Claim | Evidence | Verdict |
|---|---|---|---|
| N1 | Locations open via Explorer address bar / `regedit` | general Windows behaviour (instruction, not a product claim) | instruction (not a product claim) |
| N2 | Panel/tab locations can include server name and user name | cfg-main (tab list, `paneltabs`); sftp `sftp:user@host` form (research B) | supported (T010b) |
| N3 | Values kept with history off, not removed by Clear History: viewer last search, last folder per drive, Registry Editor and PictView last locations | viewer-find; `mainwnd2.cpp:1379-1393`; `regedt.cpp:358,403`; `pictview.cpp:945,976-990`; `viewer.cpp:1609-1626` | overstated → fixed in T010b |
| N4 | *Open in Regedit* sets the key Regedit opens at | regedt-lastkey (`regedt/fs5.cpp:1108-1119`) | wrong label → fixed in T010b |
| N5 | Program reads Dropbox / Google Drive local settings to show their folders; nothing sent | `drivelst.cpp:1375-1395`; `shiconov.cpp:120` | incomplete → OneDrive added in T010b |
| N6 | WebView2 caches can include viewed documents/images | wv2-udf; mdview served without `no-store` (hedged "can") | supported (T010b) |
| N7 | Forgotten Master Password → protected passwords unrecoverable | `lang.rc:2039` | supported (T010b) |
| N8 | Clear History takes effect at the next configuration save | `dialogs4.cpp:4249-4254` | supported (T010b) |
| N9 | Windows Error Reporting handles crashes the program cannot, per Windows settings | attribution; no WER opt-out in `src/` (T010) | supported (T010b) |
| N10 | Third-party shell extensions run inside the program | attribution; shell integration (T010) | supported (T010b) |
| N11 | External archivers run when an archive format is handled by an installed external program | net-archivers; `packers.cpp:202-240` | supported (T010b) |
| N12 | Changes visible in the file's repository history | `PRIVACY.md` is versioned in git | supported (T010b) |

## Independent review

**T010** (2026-09-30): a separate agent re-opened the evidence for all 53
claims and searched `src/` for unaccounted network use (none found; the 20
shipped plugins equal `plugins.cfg =on`). Verdicts are in the claim map.
**Two claims were false** — the shell-extension registration (C44/C45: gated
on `utils\salext*.dll`, which 0.1.8 does not ship; the inventory row had
missed the `FileExists` gate) — and eleven overstated or unverifiable (crash
report contents too short; plain-text passwords also via Change Directory and
the command line; F3 makes "blocked"/"only on click" unverifiable for
Markdown; history exceptions; temp cleanup scope; passphrase/proxy
checkboxes; Portables string; archivers pre-configured; roaming profile).
Missing disclosures added: WER, third-party shell extensions, Regedit
LastKey, Dropbox/Google Drive settings read. All confirmed by the
coordinator at the source before editing (`salamdr1.cpp:4384-4398`,
`dialogs3.cpp:1198-1203`, `dialogs4.cpp:4249-4254`, `portables/device.cpp:182`,
`portables/versinfo.rh2:29`, `sftp lang.rc2:156`). Research row
`shellext-reg` and NEXT-WORK F8 corrected (F8 withdrawn); F1 widened.

**T010b** (2026-09-30) — narrowed second pass by a separate agent over every
changed or new claim (C5, C6, C16, C22, C23, C27, C30, C33, C35, C37, C40,
C46, S2, S3, N2–N11), all UI labels re-checked against the resource files:
all supported except four, each confirmed by the coordinator and fixed:

1. N3/C6 — the last folder per drive **is** removed by *Clear History*
   (`dialogs4.cpp:4257-4258` → `InitDefaultDir()`); sentence split.
2. N4 — "*Open in Regedit*" is not a UI label; now **Commands → Open Folder →
   Active Folder** (Shift+F3) (`texts.rc2:101-102`, `regedt/fs5.cpp:1097-1119`).
3. F3 wording — Markdown links now say "normally when you click them, though
   a document can also trigger this by itself" (`webhost.cpp:266-281` has no
   `IsUserInitiated` check). The code fix (check `get_IsUserInitiated`) is
   recorded under F3.
4. N5 — OneDrive added (`drivelst.cpp:1544-1548`).

After these four one-sentence edits no claim is unsupported. The edits are
literal applications of the reviewer's corrections, each verified at the
cited lines, so no third pass was run.

## Reader test

**T011** (2026-09-30, run in parallel with T010 to save time — it tests
wording, not facts). A separate agent with access to `PRIVACY.md` only
answered the eight questions of quickstart §3: **8/8 correct, ~6–8 minutes**
(SC-004 met). It found every password weakness (including the exported
configuration) and correctly read the contact channel as public.

Wording issues reported, and how they are handled (applied together with the
T010 corrections):

| Issue | Action |
|---|---|
| "shell extension" unexplained — the reader guessed "right-click menu entries" (wrong: it is the copy hook for dragging/copying out of archives) | explain the term in plain words |
| `%LOCALAPPDATA%` / `%APPDATA%` / registry path not explained | one line: type into the Explorer address bar; Registry Editor |
| "obfuscated … method is part of the public source code" too technical | plainer wording ("scrambled, not encrypted") |
| SSH version string unexplained | add "(no personal information)" |
| "This will be fixed." vague | "in a future version" |
| forgotten Master Password not covered | add: protected passwords cannot be recovered (`lang.rc:2039`) |
| no link to Microsoft's privacy information | link Microsoft Learn *Data and privacy in WebView2* (research R10) |
| panel/tab history may contain server and user names | say so (research: cfg-main, sftp) |
| how changes are announced | one line: changes are visible in the repository history |
| private channel, named person | not added — C7 gate (setting disabled); maintainer's open item |
| does Clear History remove the viewer's last search text | not claimed — not established by the evidence |

## Manifest validation

**T009** (2026-09-30): `publish.ps1 -Version 0.1.8` (no `-Submit`) re-downloaded
and verified the published installer, rendered the three manifests and
reported `Manifest validation succeeded.` The locale manifest line 9 is
`PrivacyUrl: https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md`
(directly after `PublisherSupportUrl`, contract W1); the new authoring comment
did not reach the output (0 matches); the installer manifest carries no
`DisplayVersion`. The generated `tools/winget/manifests/0.1.8/` was deleted
afterwards (contract W4).

## Open items

- Maintainer: enable *Settings → Security → Private vulnerability
  reporting*; then add the private contact line to `PRIVACY.md` § Contact
  (contract C7) and re-check with the API call above.
