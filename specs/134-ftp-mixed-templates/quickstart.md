# Quickstart: checking feature 134

Needs Python (the probe starts its own FTP server on `127.0.0.1:2134`; nothing else is contacted).

```powershell
foreach ($lang in 'czech', 'english') {
    $p = 'powershell -NoProfile -ExecutionPolicy Bypass -File specs\134-ftp-mixed-templates\probe\ftp134_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect fixed -Lang ' + $lang + ' -ServerLog ' + $env:TEMP + '\tc134_bytes_' + $lang + '.log'
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -CommandLine $p
}
python specs\134-ftp-mixed-templates\probe\compare_server_logs.py specs\134-ftp-mixed-templates\probe\server_bytes_before_czech.log $env:TEMP\tc134_bytes_czech.log
```

Expected: `Rows: PASS 31, FAIL 0, NOT DRIVEN 0` in both languages (13 rows since feature 136); `different (PORT numbers
aside): 0`. With a 0.1.10 build and `-Expect before` the Czech run shows 9 FAIL rows, the
English one 2.

## Owed to a person

Run the server by hand (`python specs\134-ftp-mixed-templates\probe\ftp134_server.py 2134 %TEMP%\ftp.log`),
set the language to Czech, and:

1. **Bookmarks, no server**: Connect to FTP Server - New, name `Žluťoučký kůň`; then Rename and
   Remove. The label "Přejmenovat ... na", the check box "Kopírovat data ze záložky ..." and the
   question "Opravdu chcete odstranit záložku ...?" show the name readable.
2. **The log**: connect to `ftp://127.0.0.1:2134/`, enter `Žluťoučký kůň`, open the log
   (Plugins > FTP Client > Show Logs): every line readable. *Save log* - the file starts with
   `EF BB BF` and reads as UTF-8 in Notepad. *Copy* - paste into Notepad.
3. **Quick Connect history**: Quick Connect to `ftp://jiří@127.0.0.1:2134/Žluťoučký kůň`, OK;
   open Connect again - the address history shows the address as typed.
4. **The list of logs** and the lists of **server types** / **proxy servers** with an accented
   name (Configuration of the FTP client).
5. Password prompt and login error need a server that asks for a password; the certificate text
   needs FTPS - with a real server when one is at hand.
