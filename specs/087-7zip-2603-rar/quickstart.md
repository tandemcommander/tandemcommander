# Quickstart: verifying feature 087

## Automated (implementation session; results in `fix-log.md`)

| What | How | Expected |
|---|---|---|
| unit tests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `0 failed` (`TestArcNames087`) |
| engine formats | `probe\7zdrive.exe formats <path>\7za.dll` | exactly `7z`, `Rar`, `Rar5` |
| RAR fixtures | `probe\build_7zdrive.cmd`, then `python probe\run_engine_probe.py <path>\7za.dll` | every fixture in `specs\084-archiver-cleanup\probe\fixtures\rar\` lists and extracts byte-identical to the reference extraction by `C:\Program Files\7-Zip\7z.exe`; damaged / missing-volume / wrong-password cases fail cleanly |
| 7z corpus | same script | plain, solid, encrypted data, encrypted names, Unicode names: list + extract identical; archives created by the driver through `IOutArchive` test OK in `7z.exe` |
| memory bound | same script (`MEM`, copies made by `probe\make_bigdict.py`) | a RAR5 header declaring 128 GiB is refused; 2 GiB is refused under `-mem=1073741824` and allowed by default |
| compression settings | same script (`props`) | all 4,722 combinations of the dialog's tables accepted |
| engine threads | `7zdrive create/extract ... -spl=probe\obj\spl\7zip.spl` (T025) | `engine threads NOT wrapped 0`; with the unmodified `7z.dll` of 7-Zip the check fails |
| version | About text, `7za.dll` file version | 26.03 |
| no helper | `dir build\...\plugins\7zip` | no `7zwrapper.dll` |
| imports / runtime | `tools\check_runtime_deps.py` (run by `build.cmd release`) | closure OK |

## Owed to a person (GUI)

Back up `HKCU\Software\Tandem Commander` first.

1. **Clean machine** (Windows Sandbox with the Release tree mapped read-only;
   no WinRAR, no 7-Zip): Enter on each RAR fixture → browse; F3 a file; F5 out;
   Alt+F9; encrypted ones prompt (a Czech password works on a Czech
   Windows; characters outside the code page cannot be typed - FR-010);
   `test_read_format_rar5_unicode.rar` reports 2 links not unpacked; `part1` of the multi-part sets extracts across parts; damaged
   archive → error, no crash.
2. **Associations** (Configuration ▸ *Archives Associations in Panels*):
   - fresh configuration: the `rar;r##` row has the 7-Zip plugin as viewer
     and RAR (WinRAR) as packer;
   - over a 0.1.8 configuration: `rar;r##` joins the plugin's `7z` row (the
     core's own `rar;r##` row stays, unused); copying a file into an open RAR
     archive says updates are not supported; *Pack* (Alt+F5) with *RAR
     (WinRAR)* still works when WinRAR is installed. Restart twice: nothing
     is added again (configuration version 4).
3. **7z regression**: create (levels, solid on/off, password, encrypt names),
   add, delete, test, extract — on archives from 0.1.8 and new ones; open the
   new ones in 7-Zip.
4. **Hostile names**: `probe\obj\7zdrive.exe hostile <7za.dll> hostile.7z`,
   then open it in the panel (the names shown are the cleaned ones) and
   unpack it into an empty folder; nothing appears outside it, no `:stream`
   exists (`dir /r`).
4b. **Unpack and delete** a 7z with a wrong password, and one with a damaged
   file: the archive is **kept**. *Unpack and delete* on
   `test_read_format_rar5_multiarchive.part01.rar` (a copy of the set):
   all eight parts are deleted.
4c. **Wrong password, RAR5** (`test_read_format_rar5_encrypted.rar`, any
   password): one message, no file left in the target, and the next F5 asks
   for the password again. The same with a wrong password on an encrypted 7z:
   the *delete or keep* question, then the next operation asks again.
4d. **Skip, then Cancel**: unpack a large solid 7z into a folder that already
   holds its first file, choose *Skip* for it, then press Cancel while the
   progress runs — the existing file is still there.
5. **Read-only RAR**: F8 / adding a file into an open RAR → "not supported".
6. **Updated installation** (installer over 0.1.8): `plugins\7zip\7zwrapper.dll`
   is gone.
