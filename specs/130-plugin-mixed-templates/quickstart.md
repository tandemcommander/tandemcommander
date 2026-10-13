# Quickstart: checking feature 130

```powershell
# unit checks
build\tandemcommander\Debug_x64\saltests\saltests.exe

# the GUI probe (hidden desktop; refuses while tandemcommander.exe runs)
$p = 'powershell -NoProfile -ExecutionPolicy Bypass -File specs\130-plugin-mixed-templates\probe\plugmix_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -CommandLine $p
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -CommandLine ($p + ' -Lang slovak -Only ZIPTEST,7ZTEST')
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -CommandLine ($p + ' -Lang english')
```

Expected: Czech `PASS 19, FAIL 0`; Slovak `PASS 4, FAIL 0`; English `PASS 19, FAIL 0`. On 0.1.9
(`-Expect before`): Czech fails CSUM, DBV, PVW, PEV; Slovak fails ZIPTEST and 7ZTEST; English
passes with the same texts.

By hand (Czech): Plugins > Checksum > Calculate, Save over an existing file named
`Příliš žluťoučký kůň.sha256` - the question names the file; F3 on `Příliš žluťoučký kůň.png` -
the title of the PictView window holds the name.
