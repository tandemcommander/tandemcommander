# Closing report - 263-import-foreign-reg-keys
Backlog item: importing-a-configuration-file-writes-every-key-of-a-foreign - Importing a configuration file writes every key of a foreign .reg file
Outcome: closed

## What changed

- The start-up import of a configuration file (config.reg next to the exe, in
  `%APPDATA%\Tandem Commander`, or `-C`) writes and deletes only keys in
  `HKEY_CURRENT_USER\Software\Tandem Commander\0.1`. A file that names any other key (another
  program's key, `HKEY_CLASSES_ROOT`, a delete line of another key), or holds no key under the root,
  is refused as a whole before anything is written, with the existing message "Unable to import the
  specified file. It is not a configuration file." (`IDS_IMPORTCFG_NOTREG`). The question "Do you
  want to import it anyway?" (`IDS_IMPORTCFG_NOTOURVER`) is no longer asked; its string stays in the
  resources, unused (no translation refresh needed).
- Bare key lines of the root's parents (`[HKCU\Software]`, `[HKCU\Software\Tandem Commander]`), which
  the program's own export writes, are accepted and create nothing; a value under them or a delete
  line of them refuses the file (review 1).
- Sources: `src/common/salregroot.h` (new, pure rules `SalRegKeyIsInsideRoot`,
  `SalRegKeyIsParentOfRoot`), `src/reglib/src/regparse.{h,cpp}` (`RPE_KEY_OUTSIDE_ROOT`, the
  restriction parameter of `Parse`), `src/salamdr2.cpp` (`ImportConfiguration`),
  `src/saltests/saltests.cpp` (`TestRegImportRoot263`).

## Measurements (before / after, commands)

Probe `probe/import263_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`, the
command in `quickstart.md`):

- before (`0e36adce`, `probe/result_before.txt`): PASS 7, FAIL 3 - MIXED (foreign key written, no
  message), NOROOT (written after Yes), DELETE (another program's key deleted, no message).
- after (`probe/result_after3.txt`): PASS 26, FAIL 0, NOT DRIVEN 0 - rows OURS, OWNDEL, MIXED,
  NOROOT, DELROOTONLY, EMPTY, DELETE, HKCR, EXPORTSHAPE, PARENTVAL, PARENTDEL, EXPORTCLEAR (clear-key
  export of the whole current configuration), REALBACKUP (the newest real feature 245 backup, proven
  imported by a marker key). Registry restored identical in every run (SHA-256 `A46438BF...`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`
- `.\build.cmd`: `BUILD SUCCEEDED` (two older C4018 warnings at `salamdr2.cpp:1058/1066`)
- `saltests.exe`: `saltests: 24694 checks, 0 failed`; negative control (boundary broken by hand):
  2 failed
- probe: 26 / 0 (above); `BL check`: `TOTAL: 0`

## Reviews (findings and what was done)

- Review 1: MUST - every real export / 245 backup was refused (the dump's parent key lines);
  SHOULD - no probe row used real program output. Fixed (`SalRegKeyIsParentOfRoot`, five probe rows
  incl. a real backup); spec, contract, research corrected.
- Review 2 (with review 1's findings): no MUST. SHOULD - rows for the files the old question let
  through without a foreign key (DELROOTONLY, EMPTY) and a NOROOT judge checking the message: done.
  NOTES - REALBACKUP proof by a marker key, a UTF-8 name check in saltests: done; naming the key in
  the message and the help text: Inbox item; trace names the value line (cosmetic); pre-existing
  `CKey::Dump` quoting of `"` in key names (unaffected).

## Owed to a person (with the new person-step items)

Nothing - every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- a-refused-configuration-file-does-not-say-which-key-is - A refused configuration file does not say which key is outside the program root
