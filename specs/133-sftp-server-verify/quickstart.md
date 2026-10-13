# Quickstart: checking feature 133

Needs Docker Desktop running and the container `tandem-sftp` (`docker ps` shows
`0.0.0.0:2222->22/tcp`); the probe prepares and removes `/home/tctest/tc133` itself.

```powershell
src\plugins\sftp\test\build_and_run.cmd          # 101 passed, 0 failed

$p = 'powershell -NoProfile -ExecutionPolicy Bypass -File specs\133-sftp-server-verify\probe\sftp133_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect fixed'
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -CommandLine $p
```

Expected: `Rows: PASS 30, FAIL 0, NOT DRIVEN 0` (15 rows, each with its END line). On a Release
build the three LIST rows are NOT DRIVEN (the seam is debug-only). `-Expect before` only records
(use it with a 0.1.9 build).

## Owed to a person (not drivable on the hidden desktop)

Connect to the test server (`sftp://tctest@localhost:2222/home/tctest`, password in the session
notes), prepare with `docker exec -i -u tctest tandem-sftp bash -s < specs\133-sftp-server-verify\probe\fixture133.sh`:

1. **Upload into a read-only directory**: local panel on a file, the other panel in
   `tc133/ro4`, F5. Expected: the message ends with "Permission denied.".
2. **Stale reason**: in `tc133/ro1` F2 on `f.txt`, new name `g.txt` (fails); then go up and F8
   on `p4` (a directory that cannot be removed). Expected: the second message has its own
   reason, not the rename's.
3. **Quick Rename to a long name**: in `tc133/p1/deep` F2 on `file.txt`, a new name of 250
   letters. Expected: renamed to all 250 letters (`docker exec ... ls` shows it).

Remove the fixture afterwards: `... bash -s clean < fixture133.sh`.
