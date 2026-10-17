# Tandem Commander 0.1.3

**Released 18 August 2026 · build 187 · Windows 11 or newer, 64-bit**

A feature release. Coming from Altap Salamander? A new standalone utility
carries your settings over — hot paths, FTP bookmarks, user menu, colors and
more — with a backup and a one-click way back. And cloud-synced folders now
show their sync-status badges the way Windows Explorer does: in folders with
non-ASCII names (where they were missing entirely), and for items whose sync
is still in progress (the blue-arrows state, which no release ever showed).

Your settings, bookmarks and stored credentials carry over untouched, and
plugins built for 0.1.0–0.1.2 keep working — see [Upgrading](#upgrading).

---

## New: bring your settings from Altap Salamander

A standalone one-time utility copies selected settings from an existing
Altap or Servant Salamander configuration into Tandem Commander: directory
hot paths, FTP bookmarks including stored passwords, the user menu,
viewer/editor associations, colors, confirmations, view templates, and the
configurations of the plugins Tandem Commander ships.

It is built to be safe to try:

- **Your current Tandem Commander settings are backed up first**, and the
  utility generates a double-click restore script that puts everything back
  exactly as it was.
- **The Altap Salamander configuration is read-only to the tool** — it is
  never modified, so your existing installation is untouched.
- **What is not carried over is said out loud.** Archiver settings and
  window/session state are deliberately skipped; the closing summary names
  everything skipped and why.

One caution: the backup file contains any FTP passwords already saved in
Tandem Commander, so treat it with the same care as the settings themselves —
keep it private and delete it once you no longer need it.

The utility is a single downloadable file, `utils/migrate-altap-settings.cmd`
in the source repository — it is not part of the installer.

## Cloud sync badges in folders with non-ASCII names

Folders whose path contains non-ASCII characters — most visibly on cloud
drives such as Google Drive's `G:\Můj disk`, where the folder name is not the
user's choice — misbehaved three ways:

- **Sync-status badges never appeared** (synced / online-only / syncing /
  error), even though Windows Explorer showed them.
- **Files like Word documents or PDFs fell back to a generic blank icon.**
- **The window flashed a busy cursor on every activation** without any
  visible result: automatic change monitoring was silently broken, so the
  panel re-listed the folder each time you returned to the application — and
  changes made by other programs stopped appearing on their own.

All three were one regression from the Unicode and long-path rework: three
places still interpreted the panel path in the legacy 8-bit encoding, so any
path with characters like "ů" was garbled before it reached Windows.
ASCII-only paths — including typical OneDrive folders — were never affected,
which made the defect look Google Drive-specific. It was not.

## The sync-in-progress badge (blue arrows)

Items that Windows Explorer marks as *sync pending* — most visibly folders
whose contents are still uploading or downloading in OneDrive — showed no
status badge at all. This gap predates Tandem Commander and even the Open
Salamander open-sourcing: the sync provider reports this one state only
through a per-item Windows property, a channel the panels never consulted,
not through the icon overlay handlers the panels read.

The panels now fall back to that property — exactly the source Explorer
documents for its own state icon — for items no overlay handler claims inside
a cloud-synced folder, and show a sync-pending badge that clears when the
provider finishes. The badge obeys the existing icon-overlay configuration
(it can be disabled under the name `TandemCloudSyncPending`); behavior
everywhere else, including Google Drive letter drives, is unchanged.

## Upgrading

- **Your configuration is preserved.** Settings live in
  `HKCU\Software\Tandem Commander\0.1`, which is unchanged — nothing is moved
  or migrated.
- **Third-party plugins built for 0.1.0–0.1.2 keep working.** The plugin
  interface is unchanged at version 106.
- **Install over the previous version.** No uninstall needed.
- Tandem Commander remains fully separate from any Open Salamander
  installation; the two can be used side by side.

## Known limitations

Unchanged from 0.1.2:

- The HTML help has not been rebranded yet.
- Two plugins need components that are not shipped: **unrar** requires
  `unrar.dll`, and the **FTP** plugin requires OpenSSL.
- ed25519 SSH keys are not supported.

## Verification

Every change since 0.1.2 was reviewed before release by six independent
perspectives with adversarial verification of each finding. The review earned
its keep: it found and closed, before anything shipped, a rare condition where
the new badge check could freeze the window over a hung network share, and a
defect in the migration utility's restore script that could lose settings when
the backup path contained non-ASCII characters — the utility ships with both
fixes already in place. Built and checked in both Debug and Release
configurations: the unit test suite passes (1,145 tests), the migration
utility's own test harness passes (98 scenarios against real registry data),
and the cloud-badge behavior was verified by hand against Windows Explorer on
live OneDrive and Google Drive folders.

---

Tandem Commander is free software under the GNU GPL v2 or later, derived from
Open Salamander. Website: <https://tandemcommander.org> ·
Source: <https://github.com/tandemcommander/tandemcommander>

Full technical detail for this release is in `CHANGELOG.md`.
