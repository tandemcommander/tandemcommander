# Quickstart: verifying feature 087

## Automated (implementation session; results in `fix-log.md`)

| What | How | Expected |
|---|---|---|
| unit tests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `0 failed` (`TestArcNames087`) |
| engine formats | `probe\7zdrive.exe formats <path>\7za.dll` | exactly `7z`, `Rar`, `Rar5` |
| RAR fixtures | `probe\run_engine_probe.cmd` | every fixture in `specs\084-archiver-cleanup\probe\fixtures\rar\` lists and extracts byte-identical to the reference extraction by `C:\Program Files\7-Zip\7z.exe`; damaged / missing-volume / wrong-password cases fail cleanly |
| 7z corpus | same script | plain, solid, encrypted data, encrypted names, Unicode names: list + extract identical; archives created by the driver through `IOutArchive` test OK in `7z.exe` |
| memory bound | same script | a RAR5 fixture with a dictionary > the limit is refused, no allocation spike |
| version | About text, `7za.dll` file version | 26.03 |
| no helper | `dir build\...\plugins\7zip` | no `7zwrapper.dll` |
| imports / runtime | `tools\check_runtime_deps.py` (run by `build.cmd release`) | closure OK |

## Owed to a person (GUI)

Back up `HKCU\Software\Tandem Commander` first.

1. **Clean machine** (Windows Sandbox with the Release tree mapped read-only;
   no WinRAR, no 7-Zip): Enter on each RAR fixture → browse; F3 a file; F5 out;
   Alt+F9; encrypted ones prompt (try a Czech password on an English
   Windows); `part1` of the multi-part sets extracts across parts; damaged
   archive → error, no crash.
2. **Upgrade path**: start the new build over a 0.1.8 configuration →
   Configuration ▸ Plugins ▸ 7-Zip: RAR registered once; Options ▸ Archives
   associations: `rar` viewer = 7-Zip plugin, packer = RAR (WinRAR) if installed.
3. **7z regression**: create (levels, solid on/off, password, encrypt names),
   add, delete, test, extract — on archives from 0.1.8 and new ones; open the
   new ones in 7-Zip.
4. **Hostile names**: extract `probe\hostile\*.7z` / `*.rar` (built by
   `probe\make_hostile.py`) into an empty folder; nothing appears outside it,
   no `:stream` exists (`dir /r`).
5. **Read-only RAR**: F8 / adding a file into an open RAR → "not supported".
6. **Updated installation** (installer over 0.1.8): `plugins\7zip\7zwrapper.dll`
   is gone.
