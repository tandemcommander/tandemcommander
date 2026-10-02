# Quickstart: feature 094 - ZIP and SFTP passwords

## Automated

```
saltests.exe                                   13,032 checks, 0 failed (TestZipPassword094)
python specs\094-plugin-password-encoding\probe\zipfix.py --selftest      fixture generator
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\094-plugin-password-encoding\probe\zip_gui_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
... the same with probe\sftp_gui_probe.ps1 (needs python with paramiko; see its header)
```

The GUI probes save and restore `HKCU\Software\Tandem Commander`; close an
installed Tandem Commander first.

## Owed to a person (Release build, a real keyboard)

1. Pack a ZIP archive (classic encryption, then AES-256) with a Cyrillic
   password on a Czech Windows; unpack it with that password: works; with
   another Cyrillic word of the same length: "incorrect password".
2. Pack with `heslo-ř`; open the archive in 7-Zip with `heslo-ř`.
3. Open an encrypted ZIP archive you made with an earlier version (any
   password): it opens with the password you used.
4. An encrypted ZIP archive made on Linux or macOS with an accented password
   (`zip -e`, `7z a -tzip -p...`): it opens.
5. A self-extracting archive with a password: create it, run it, enter the
   password.
6. Test archive and F3 on a file inside an encrypted ZIP archive.
7. SFTP: connect to a real server with a password containing accented
   letters; a key with a passphrase containing accented letters.
