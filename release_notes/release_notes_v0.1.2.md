# Tandem Commander 0.1.2

**Released 7 August 2026 · build 186 · Windows 11 or newer, 64-bit**

A maintenance release. The SFTP plugin's dialogs and connection handling are
reworked for reliability, plugin names render correctly in every language, and
all machine-translated interface text was re-done with knowledge of where each
string appears. The release shipped after an independent multi-perspective
stability and security review of every change since 0.1.1, with the full build
and all automated tests passing.

Your settings, bookmarks and stored credentials carry over untouched, and
plugins built for 0.1.0/0.1.1 keep working — with one deliberate exception for
Quick Connect passwords, see [Upgrading](#upgrading).

---

## Fixed in the SFTP plugin

- **The plugin's settings could not be opened at all.** Pressing Configure in
  Plugins Manager left the application unresponsive with nothing on screen to
  close — the settings window existed but had no title bar or frame and sat
  outside the window it belonged to, so it was clipped away entirely. It is now
  an ordinary window with a title and OK/Cancel, like every other plugin's
  settings.
- **Connecting to a host whose first address is unreachable now works.** When a
  host name offered several addresses and the first silently dropped traffic,
  the whole connect time was spent waiting on it — typically `localhost` on a
  machine whose IPv6 loopback is filtered, which failed after the full timeout
  while `127.0.0.1` connected instantly. Addresses are now attempted with a
  slight overlap and the first to answer wins. A host that really is
  unreachable still fails within the configured timeout, never a multiple of it.
- **Text was cut off in the plugin's dialogs in every non-English language.**
  Controls were sized for English, so longer translations were truncated
  mid-word — in Czech the key-file label read "Soubor s" and the passphrase
  label "Heslo ke". 26 controls across six dialogs were affected; they are now
  sized for the longest translation that ships. No wording changed — the
  translations were always correct, only their display was not.
- **The password prompt could not fit its own message**, and **two controls in
  the plugin's settings overlapped each other** — the "show octal mode" option
  sat on top of the permissions-column choices.

## Changed in the SFTP plugin

- **The connect dialog is sized for the language in use.** Labels used to be
  given room for the longest translation of every shipped language at once,
  leaving a wide empty band in most languages. The dialog now measures the
  labels it actually shows and sits them next to their fields.
- **Quick Connect no longer remembers anything, and can no longer store a
  password.** It exists for one-off connections: every field starts empty each
  time, nothing about it is written to your settings, and "save password",
  "save passphrase" and "Save" are unavailable while it is selected — those
  belong to bookmarks. A Quick Connect password saved by an earlier version is
  **deleted** the first time this version loads the plugin. Bookmarks are
  unaffected.
- **A bookmark can now be created and saved empty.** The server address and
  port are required only when you actually connect, so you can name an entry
  and fill in the details later.

## Plugin names in non-English UI

With the interface in Czech, Plugins Manager showed garbled names of plugins
that were not currently loaded ("HromadnĂ© pĹ™ejmenovĂˇnĂ­" instead of
"Hromadné přejmenování"); loading a plugin "healed" its row until the next
start. The cached name and the name obtained from a loaded plugin carried two
different text encodings, and the list drew the raw bytes. Plugin metadata now
has one defined encoding everywhere, which also fixes every message composed
with a plugin name. Existing configurations display correctly as they are —
nothing is migrated or rewritten.

The build guard that checks display encoding can no longer be skipped silently:
it used to print "SKIPPED" when Python was missing — the exact hole this defect
shipped through — and now fails the build instead.

## Translations

Every interface string that had been machine-translated word-by-word — without
knowing where in the program it appears — was re-translated with its context:
which dialog or menu it lives in, what kind of control it labels, and what its
neighbours say. This fixes the class of errors where a correct word for the
wrong meaning was chosen, the same defect 0.1.1 fixed for the SFTP plugin,
now applied product-wide: about 3,300 strings across the file manager and 18
plugins in all eight non-English languages. Human-made translations were not
touched.

One example got its own fix: **the ZIP plugin is named "ZIP" in every
language.** Machine translation had turned the name into the postal code —
"PSČ" (Czech, Slovak), "Code postal" (French), "Código postal" (Spanish) — and
the name is now pinned as untranslatable, so a future re-translation cannot
undo it.

## Upgrading

- **Your configuration is preserved.** Settings live in
  `HKCU\Software\Tandem Commander\0.1`, which is unchanged — with one deliberate
  exception: a password saved for SFTP **Quick Connect** by an earlier version
  is deleted on first load (see above). Bookmarks and their saved passwords are
  untouched.
- **Third-party plugins built for 0.1.0/0.1.1 keep working.** The plugin
  interface is unchanged at version 106.
- **Install over the previous version.** No uninstall needed.
- Tandem Commander remains fully separate from any Open Salamander
  installation; the two can be used side by side.

## Known limitations

Unchanged from 0.1.1:

- The HTML help has not been rebranded yet.
- Two plugins need components that are not shipped: **unrar** requires
  `unrar.dll`, and the **FTP** plugin requires OpenSSL.
- ed25519 SSH keys are not supported.

## Verification

Every change since 0.1.1 was reviewed before release by six independent
perspectives (memory safety, concurrency, network security, credential
handling, text encoding, tooling and data) with adversarial verification of
each finding. Built and checked in both Debug and Release configurations: the
unit test suite passes (1,145 tests), the SFTP plugin's automated scenarios
pass against a live SSH server under a hang watchdog and a leak check,
key-format fixtures pass (66 cases), translation round-trip and version checks
are clean, and the application was smoke-tested in Czech and English.

---

Tandem Commander is free software under the GNU GPL v2 or later, derived from
Open Salamander. Website: <https://tandemcommander.org> ·
Source: <https://github.com/tandemcommander/tandemcommander>

Full technical detail for this release is in `CHANGELOG.md`.
