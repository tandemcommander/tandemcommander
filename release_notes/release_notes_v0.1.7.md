# Tandem Commander 0.1.7

**Released 29 August 2026 · build 191 · Windows 11 or newer, 64-bit · installer fix**

A small release with one fix, and an honest one: **unattended installation has never worked.** Running the installer with `/VERYSILENT` or `/SILENT` aborted straight away without installing anything — in every published version from 0.1.0 to 0.1.6. If you have only ever run the installer by hand, nothing about 0.1.6 was wrong for you and there is no urgency in upgrading.

The application itself is unchanged from 0.1.6: the source code is identical, only the installer and the build number differ. Everything 0.1.6 introduced — the Code Viewer on F3, the configurable Command Shell — is exactly as it was.

## Fixed

- **Unattended installation works.** `/VERYSILENT` and `/SILENT` now install as they should. Before, they exited immediately with code 1 and, in an installation log, "Failed to proceed to next wizard page", leaving nothing installed and nothing explained. Scripted and managed deployment was therefore impossible; the installer could only be run interactively.

  The cause was the AI disclaimer page. It keeps the *Next* button disabled until you tick the checkbox — and a silent installation still walks through the wizard's pages even though it displays none of them, so it arrived at a button it could not press and gave up. The page is now skipped in a silent installation, exactly as the licence page always was.

  Interactive installation is unchanged: the disclaimer still has to be read and accepted before *Next* becomes available.

## Why this matters beyond scripted installs

This defect is also what kept Tandem Commander out of the **Windows Package Manager** catalogue. Its validation installs every submitted package unattended, so the submission for 0.1.6 failed however the package was described. With this fix the submission is being made again for 0.1.7, and once Microsoft accepts it:

```
winget install tandemcommander
winget upgrade tandemcommander
```

It installs for all users, into `Program Files`, and asks for administrator rights exactly as the installer does on its own. The downloads here and on the website are unchanged and remain the primary channel.

## Known limitations

Unchanged from 0.1.6:

- **The Code Viewer reads UTF-8, UTF-16 and your Windows code page.** Its F8 encoding menu offers a fixed list of five encodings, not the full conversion table the built-in viewer has. A file in ISO-8859-2, CP852 or a similar single-byte encoding that is not your system's may show wrong accents — open it with Alt+F3 in the built-in viewer, which handles those.
- A file name containing characters your Windows code page cannot represent is inserted into the command line with `?` in their place.
- How the *contents* of an archive are displayed is unchanged: names with accents inside an archive listing may still be shown incorrectly.
- The HTML help has not been rebranded yet; the **unrar** plugin needs `unrar.dll` and the **FTP** plugin needs OpenSSL, neither of which is shipped; ed25519 SSH keys are not supported by the SFTP plugin.

## Upgrading

- Install over the previous version — settings are preserved and nothing needs to be reconfigured.
- Plugins built for 0.1.0–0.1.6 keep working: the plugin interface is unchanged at 106.
- There is no functional reason to upgrade from 0.1.6 unless you install unattended, or you want the version that `winget` will offer.

---

Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full technical detail in `CHANGELOG.md`
