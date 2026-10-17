---
title: Encrypted ZIP and SFTP passwords by hand: AES round trip, accented passwords
type: person-step
status: open
severity: 5
area: archives
source: leftover:094
who: person
created: 2026-10-01
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [sftp-test-container-rows-133, real-keyboard-ime-pass-093-124-130]
depends-on: []
reason: -
---

# Encrypted ZIP and SFTP passwords by hand: AES round trip, accented passwords

## Problem

Two features about archive and plug-in passwords owe person steps: 086 (unique ZIP AES salts) needs an encrypted ZIP round trip through the Pack dialog; 094 (ZIP and SFTP password encoding) needs a real keyboard with Cyrillic and accented passwords, archives from other systems, and a real OpenSSH server with an accented password and a key passphrase, ideally also on a double-byte or UTF-8 code-page system.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'The features' own quickstart.md person steps' ('086 (an encrypted ZIP round trip)', '094') and §B 'Environment or hardware' ('a real OpenSSH server with a key passphrase and a double-byte or UTF-8 code-page system (094)') (at 7993914c). Steps: specs/086-zip-aes-salt/quickstart.md 'Owed to a person (needs the Pack dialog)' 1-7 (probe specs/086-zip-aes-salt/probe/zip_salts.py); specs/094-plugin-password-encoding/quickstart.md 'Owed to a person (Release build, a real keyboard)' 1-7.

## Expected

086: zip_salts.py reports repeats: 0, 7-Zip tests every archive OK, extraction byte-identical, an 0.1.8 archive still opens. 094: every step as its quickstart says; results in each fix-log.

## Notes

The SFTP test container (localhost:2222) can serve the accented-password row if its account is set up so; a key with an accented passphrase and a DBCS / UTF-8 code-page system are the parts that need other hardware or setup.

## Steps

- [ ] 086: pack AES-256 twice (a1, a2), restart, twice more (a3, a4), AES-128 once (b1), ZIP 2.0 twice (z1, z2) with password Zz086test
- [ ] 086: python specs/086-zip-aes-salt/probe/zip_salts.py on all seven - repeats: 0; 7z t -pZz086test on each - Everything is Ok; extract in Tandem Commander - byte-identical (fc /b); an encrypted archive made by 0.1.8 still opens
- [ ] 094 step 1: ZIP classic and AES-256 with a Cyrillic password on a Czech Windows; a wrong Cyrillic word of the same length says 'incorrect password'
- [ ] 094 step 2: pack with heslo-ř, open in 7-Zip with heslo-ř
- [ ] 094 steps 3-4: an encrypted ZIP from an earlier version; one made on Linux or macOS with an accented password (zip -e, 7z a -tzip -p...)
- [ ] 094 steps 5-6: a self-extracting archive with a password; Test archive and F3 inside an encrypted ZIP
- [ ] 094 step 7: SFTP to a real OpenSSH server with an accented password, and with a key whose passphrase has accented letters
- [ ] 094 environment: the same on a system with a double-byte or UTF-8 code page

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
