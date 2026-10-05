# Quickstart: feature 116 - GUI runs pending

Automated (hidden desktop). Preconditions: no `tandemcommander.exe` running (also not the installed
one - every probe shares `HKCU\Software\Tandem Commander` with it); Python 3 (the log server,
standard library only). The probe starts `probe/ftplog_server.py` on **127.0.0.1:18116 only** (it
logs the bytes of USER / PASS / ACCT and refuses every login), writes its scratch under
`%TEMP%\tc116_ftp` and removes it; it re-creates the FTP bookmark `Plugins Configuration\FTP\
Bookmarks\1` for every case and sets `Delay Connect Retries` = 1 - inside the window in which it
has exported `HKCU\Software\Tandem Commander`; it restores and verifies the key at the end. No
network mapping is used or touched (A:, O:, S:, Z: stay as they are). The probe refuses to run on
the user's desktop (`Default`): start it only through the runner. The runner's own log (`-Log`) is
UTF-16; the result files (`-OutFile`) are ASCII. The passwords in the result and in the server log
are test texts only. No Master Password may be set (the probe reads the stored, scrambled password
back; with a Master Password it is AES-encrypted and the stored-bytes checks fail visibly).

`-Clipboard` (optional) lets the `show` row also press *Yes* (copy) and compare the clipboard's
Unicode text; the clipboard is shared with the user's desktop (one window station), so the probe
saves the user's clipboard text before and restores it after, also on an error (non-text
clipboard content: the comparison is skipped). **Windows clipboard history (Win+V) and the cloud
clipboard would keep the copied test password**: the probe refuses `-Clipboard` while either is
on (`HKCU\Software\Microsoft\Clipboard` `EnableClipboardHistory` / `EnableCloudClipboard` /
`CloudClipboardAutomaticUpload`) - on this machine clipboard history is on, so the commands below
run without `-Clipboard`. The probe also refuses to run while a Master Password is in use
(`Password Manager\Use Master Password`).

The builds: `build\tandemcommander\Debug_x64_116` (the maintainer's copy of this build) and
`build\tandemcommander\Debug_x64_pre116` (HEAD 79113272 before the change, = the 115 build).
`-Exe` is a parameter; nothing below depends on `Debug_x64`.

Run from the repository root in Windows PowerShell, each command wrapped by the registry check (the
export's SHA-256 must be the same before and after - `1AB614304771DBE0...` at the time of 110-115):

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc116_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc116_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\116-ftp-passwords\probe'
$E = 'build\tandemcommander\Debug_x64_116\tandemcommander.exe'
$B = 'build\tandemcommander\Debug_x64_pre116\tandemcommander.exe'
RegHash
```

1. The probe on this build (with the build before for the `compat` rows) and on the build before
   116 (about 10 minutes each - every row is its own instance; the refused rows of the build before
   wait 20 s for a login-error dialog that does not come):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_116.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\116-ftp-passwords\probe\ftppwd_probe.ps1 -Exe $E -Expect fixed -OldExe $B -OutFile $P\ftppwd_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre116.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\116-ftp-passwords\probe\ftppwd_probe.ps1 -Exe $B -Expect before -OutFile $P\ftppwd_result_pre116.txt"
RegHash
```

Single rows: `-Only uni`, `-Only type`, `-Only set`, `-Only show`, `-Only long`, `-Only prompt`,
`-Only tab`, `-Only legacy`, `-Only compat` (comma-separated for several). A python other than
`python` on PATH: `-Python <path>`.

## Expected

This build (`-Expect fixed`): every row PASS; four NOT DRIVEN rows (the proxy server dialog; the
ACCT and proxy fields of the login-error dialog; a Master Password; real keyboard / IME). Every
instance's END row PASS (exit 0, no stray window, no new crash report).

- `uni FIELD`: the Connect dialog's password field is a Unicode window.
- `type cz/cyr/cjk/emo/fw/voila/lone`: the first PASS the server receives is exactly the UTF-8
  (WTF-8 for `lone`: `...eda080...`) of the typed text, and the bookmark stores the same bytes.
- `set cyr/cjk/lone/fw`: the stored bytes are the UTF-8 of the text; the dialog closed.
- `show BOX`: the box shows the typed text exactly (`\u0416...\uD83D\uDCC1x` in the facts); with
  `-Clipboard` (only where clipboard history is off) the clipboard holds it exactly; "user text
  restored; identical=True".
- `long CZ100` (200 bytes) / `CJK100` (300 bytes): sent and stored whole, no "too long";
  `long LIMIT`: 100 x `61` sent of 105 typed; `long OVER`: refused with Windows' "too long" text,
  the dialog stayed, nothing stored; `long USER`: refused, the stored user name `probe116`.
- `prompt CZ100`: 100 Czech letters typed into the password prompt (the 101st not taken) sent
  whole.
- `tab UTF8`: the stored UTF-8 of Zhaba unchanged after tabbing through the field.
- `legacy KEEP`: the 0.1.8 blob byte-identical; `legacy RETRY`: two connections, PASS `e8 x 60`
  twice, no "too long"; `legacy RETYPE`: the second PASS is the UTF-8 of the retyped password.
- `compat FORMAT`: the build before sends the 86 bytes this build stored; `compat DOWNGRADE`: the
  build before sends the first 100 of the 200 bytes (the documented downgrade limit).

The build before (`-Expect before`): every defect row shows the defect - `uni` FALSE; `type
cyr/cjk/emo/lone` `3f...` (fw/voila the look-alikes `4142` / `766f696c61`; `cz` INFO - depends on the
keyboard layout's code page); `set` `?` stored; `show` `?` in the box; `long CZ100/CJK100` and
`prompt` "too long", nothing sent; `tab` `3f3f3f3f` stored; `legacy RETRY` "too long" after Retry,
one PASS; `legacy RETYPE` refused. Controls PASS on both: `long LIMIT`, `long OVER`, `long USER`,
`legacy KEEP`. `compat` is not driven there.

## Owed to a person (optional)

- A real keyboard pass (Czech and a non-Latin layout, an IME) in the Connect dialog and the
  login-error dialog, and *Show password* with a Master Password set.
- The SOCKS 5 limit (review T015): a SOCKS 5 proxy server entry with a password of over 255
  bytes (e.g. 130 Czech letters) - OK says "too long"; not driven by the probe (no SOCKS proxy).
- A real FTP server that accepts a non-ASCII password (e.g. vsftpd / FileZilla Server with a UTF-8
  account) - the log server only shows the bytes.
