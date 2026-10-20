---
title: Check that Change Attributes refuses to encrypt or decrypt a junction (253)
type: person-step
status: new
severity: 4
area: data-safety
source: leftover:253
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check that Change Attributes refuses to encrypt or decrypt a junction (253)

## Problem

Feature 253 refuses an encryption change of a junction / directory symbolic link (the system's
encrypt / decrypt service would follow the link and encrypt / decrypt the TARGET folder). The
refusal was never run: the build machine has no EFS certificate and encrypting would have created
one in the user's certificate store, so the probe row ENC is NOT DRIVEN.

## Evidence

`specs/253-attrs-link-own-entry/fix-log.md` (*Owed to a person*, *Review* SHOULD 2),
`specs/253-attrs-link-own-entry/quickstart.md` step 5; probe
`specs/253-attrs-link-own-entry/probe/attrs_link253_probe.ps1` row ENC; the code is `DoChangeAttrs`
in `src/worker.cpp` (`SalAttrsLinkRefusesEncryption`, `src/common/salreparse.h`).

## Expected

Encrypt / decrypt on a junction shows the "Error Changing Encryption" error for the junction; the target
folder's encryption never changes; other selected entries are encrypted / decrypted as before.

## Steps

Needs a machine (or test account) where an EFS certificate exists or may be created, NTFS, and a
throw-away folder, e.g. `C:\tc253` holding `tgt\T.TXT`, `plain\P.TXT` and a junction made with
`mklink /J C:\tc253\j C:\tc253\tgt`.

- [ ] Focus `j`, Change Attributes (Ctrl+F2), tick Encrypted, OK -> an "Error Changing Encryption" box names `j` with "The request is not supported."; Skip -> `cipher C:\tc253` shows `tgt` unencrypted (U), `T.TXT` unencrypted.
- [ ] Select `j` and `plain`, the Encrypt command (`CM_ENCRYPT`) -> the error for `j` only; Skip -> `plain` and `P.TXT` are encrypted (E), `tgt` and `T.TXT` are not.
- [ ] Encrypt `tgt` with Explorer (Properties, Advanced, Encrypt contents), then on `j` use Decrypt -> no error appears when `j`'s own state already says "not encrypted" (nothing to change), and `tgt` stays encrypted. (If `j` itself shows encrypted - e.g. made inside an encrypted folder - Decrypt shows the same refusal and `tgt` stays encrypted.)
- [ ] Clean up: decrypt and delete `C:\tc253` (`rmdir C:\tc253\j` first, it removes only the junction).

## Log

- 2026-10-20 — created (source leftover:253)
