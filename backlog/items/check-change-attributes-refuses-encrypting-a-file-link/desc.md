---
title: Check that Change Attributes refuses to encrypt or decrypt a file symbolic link (272)
type: person-step
status: new
severity: 4
area: data-safety
source: leftover:272
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [check-that-change-attributes-refuses-to-encrypt-or-decrypt-a]
depends-on: []
reason: -
---

# Check that Change Attributes refuses to encrypt or decrypt a file symbolic link (272)

## Problem

Feature 272 refuses an encryption change of a file symbolic link (the system's encrypt / decrypt
service would follow the link and encrypt / decrypt the TARGET file). The refusal was never run:
the build machine has no EFS certificate and encrypting would have created one in the user's
certificate store, so the probe row ENC is NOT DRIVEN.

## Evidence

`specs/272-attrs-file-link/fix-log.md` (*Owed to a person*, *Review* NOTE 4),
`specs/272-attrs-file-link/quickstart.md` step 5; probe
`specs/272-attrs-file-link/probe/attrs_flink272_probe.ps1` row ENC; the code is `DoChangeAttrs` in
`src/worker.cpp` (`SalAttrsEntryIsLink`, `SalAttrsLinkRefusesEncryption`,
`src/common/salreparse.h`).

## Expected

Encrypt / decrypt on a file symbolic link shows the "Error Changing Encryption" error for the link;
the target file's encryption never changes; other selected entries are encrypted / decrypted as
before.

## Steps

Needs a machine (or test account) where an EFS certificate exists or may be created, NTFS, and a
throw-away folder, e.g. `C:\tc272` holding `tgt\T.TXT`, `P.TXT` and a file link made with
`mklink C:\tc272\f.txt C:\tc272\tgt\T.TXT` (Developer Mode or an elevated prompt). Can be done in
the same session as the junction check of the related item (253).

- [ ] Focus `f.txt`, Change Attributes (Ctrl+F2), tick Encrypted, OK -> an "Error Changing Encryption" box names `f.txt` with "The request is not supported."; Skip -> `cipher C:\tc272\tgt` shows `T.TXT` unencrypted (U).
- [ ] Select `f.txt` and `P.TXT`, the Encrypt command (`CM_ENCRYPT`) -> the error for `f.txt` only; Skip -> `P.TXT` is encrypted (E), `T.TXT` is not.
- [ ] Encrypt `tgt\T.TXT` with Explorer (Properties, Advanced, Encrypt contents), then on `f.txt` use Decrypt -> no error when `f.txt`'s own state says "not encrypted" (nothing to change), and `T.TXT` stays encrypted.
- [ ] Clean up: decrypt and delete `C:\tc272` (deleting `f.txt` removes only the link).

## Log

- 2026-10-21 — created (source leftover:272)
