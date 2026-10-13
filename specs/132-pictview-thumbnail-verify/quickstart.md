# Quickstart: checking feature 132

```powershell
build\tandemcommander\Debug_x64\saltests\saltests.exe

# the library alone (Python with Pillow); the work folder also holds the probe's case files
python specs\132-pictview-thumbnail-verify\probe\exifdll_measure.py build\tandemcommander\Debug_x64\plugins\pictview\exif.dll $env:TEMP\tc132cases

# the command in the program, on the hidden desktop
$p = 'powershell -NoProfile -ExecutionPolicy Bypass -File specs\132-pictview-thumbnail-verify\probe\thumb132_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Cases ' + $env:TEMP + '\tc132cases -KeepDir ' + $env:TEMP + '\tc132keep'
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -CommandLine $p
python specs\132-pictview-thumbnail-verify\probe\check_outputs.py $env:TEMP\tc132keep
```

Expected: `cases with a loss reported as success: 0`; `PASS 16, FAIL 0`; `bad files: 0`.

Mode `-Expect oldlib`: copy the `exif.dll` of a 0.1.9 build over
`build\...\plugins\pictview\exif.dll` for the run (and put the new one back) - the rows XMP,
XMPONLY, TRAILER, FILL8 must end "unchanged" with the message shown.

By hand, owed before a release: Update Thumbnail on real camera files (see `fix-log.md`,
section 7).
