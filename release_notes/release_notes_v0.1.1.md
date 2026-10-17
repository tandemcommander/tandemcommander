# Tandem Commander 0.1.1

**Released 5 August 2026 · build 185 · Windows 11 or newer, 64-bit**

A bug-fix release. If you connect to SFTP servers with a private key, this is
the release you want: in 0.1.0 that froze the whole application and you had to
kill it. Everything else in the release hardens the SFTP plugin around that
defect, and the plugin's texts now read correctly in the eight shipped
languages.

Your settings, bookmarks and stored credentials carry over untouched, and
plugins built for 0.1.0 keep working — see [Upgrading](#upgrading).

---

## The main fix: connecting with a private key

In 0.1.0, opening an SFTP connection that authenticated with a private key made
the application stop responding for good. The key format was the trigger: keys
in the **OpenSSH format**, which is what `ssh-keygen` has produced by default
since OpenSSH 7.8 (2018), sent the bundled SSH library into an endless loop
looking for a header the file does not contain — and because the connection was
established on the same thread that draws the user interface, the application
went down with it.

Fixed at every level: the library can no longer loop on a key it does not
understand, OpenSSH-format keys are now genuinely supported, and no SFTP
operation runs where it can freeze the application.

**Private keys that work now**

| Format | Key types |
|---|---|
| OpenSSH (`BEGIN OPENSSH PRIVATE KEY`) | RSA, ECDSA — with or without a passphrase |
| Classic PEM (`BEGIN RSA PRIVATE KEY`) | RSA — with or without a passphrase |

A passphrase-protected classic PEM key failed in 0.1.0 even when the passphrase
was correct, because it never reached the decryption step. That works now too.

**Keys that are refused — and now say so before connecting**

PKCS#8 keys (`BEGIN PRIVATE KEY`), PuTTY `.ppk` files, and **ed25519** keys.
This build uses Windows' own cryptography, which cannot do ed25519. Instead of
a cryptic failure later on, you get the reason and the way out — for example
`ssh-keygen -p -m PEM -f <keyfile>` to convert a PKCS#8 key.

## Also fixed in the SFTP plugin

- **A wrong or missing passphrase asks again** instead of abandoning the
  connection attempt.
- **If the server rejects your key**, you are offered password authentication
  when the server allows it, rather than being sent back to edit the connection.
- **Error messages tell the truth.** A key that could not be read used to be
  reported as "server rejected the key" — the two are now told apart.
- **A dropped connection is noticed.** After a network drop or a server restart
  the session used to look alive while every operation failed with a raw error,
  and closing the panel was the only way out. The session is now recognised as
  dead and the next operation reconnects.
- **Nothing hangs the application any more.** Connecting shows a wait window
  that cancels in about a second; every network wait has a real time limit (the
  configured timeout was silently not being applied); viewing a remote file with
  F3 can be interrupted; closing a panel on a server that went silent no longer
  stalls; and the connect timeout now covers all of a host's addresses together
  instead of applying to each one in turn.
- **A memory leak on every connection.** Small, but present in every session —
  including password logins — since before 0.1.0.

## Translations

Short interface labels were being machine-translated one word at a time, with
no idea where they appear. In Czech the connect dialog called the server
address field *Moderátor* (a talk-show host), the key file field *Klíčový* (a
dangling adjective), the New-bookmark button *Novinka* (a news item), and
labelled both the password and the passphrase field *Heslo:*.

The translation process now tells the engine where each string is used and what
role it plays, a curated list overrides it wherever the wording still needs a
human, and duplicate keyboard shortcuts inside a dialog are resolved
automatically — Windows cycles between two controls that share a shortcut
instead of activating either.

**Scope**: the SFTP plugin's texts were re-translated this way in all eight
shipped languages (English, Czech, German, French, Dutch, Hungarian, Romanian,
Slovak, Spanish). Other parts of the application keep the translations they
had; they will improve when they are next re-translated.

## Upgrading

- **Your configuration is preserved.** Settings live in
  `HKCU\Software\Tandem Commander\0.1`, which is unchanged — nothing is moved
  or migrated.
- **Third-party plugins built for 0.1.0 keep working.** The plugin interface is
  unchanged at version 106.
- **Install over 0.1.0.** No uninstall needed.
- Tandem Commander remains fully separate from any Open Salamander
  installation; the two can be used side by side.

## Known limitations

Unchanged from 0.1.0:

- The HTML help has not been rebranded yet.
- Two plugins need components that are not shipped: **unrar** requires
  `unrar.dll`, and the **FTP** plugin requires OpenSSL.
- ed25519 SSH keys are not supported (see above).

## Verification

Built and checked in the Release configuration: 206 shipped binaries, all
reporting version 0.1.1 (x64), and language modules verified against the
binaries they belong to. The SFTP plugin's automated test suite passes against
a live SSH server — every supported key type, plus the failure cases (wrong
passphrase, unauthorised key, unsupported key, unresponsive server) — under a
watchdog that fails the run on a hang and on a memory leak.

---

Tandem Commander is free software under the GNU GPL v2 or later, derived from
Open Salamander. Website: <https://tandemcommander.org> ·
Source: <https://github.com/tandemcommander/tandemcommander>

Full technical detail for this release is in `CHANGELOG.md`.
