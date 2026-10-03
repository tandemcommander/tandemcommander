# Implementation Plan: long-path overruns (feature 098)

**Branch**: `098-long-path-overruns` (from `097-archive-long-path`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Defect | Change | Evidence |
|---|---|---|---|
| S1 | D1 directory-line crash | `CHotTrackItem` fields (`stswnd.h`) from `WORD` to `int` (offsets, character counts, pixel widths) and the arithmetic in `stswnd.cpp` that uses them | probe: walk to 20,000+ characters and back, hot-track click |
| S2 | D2 + clipboard paste | `fileswn3.cpp` `shortenedPath` sized for the path, bounded copy; `fileswn9.cpp` `ClipboardPastePath` refuses instead of cutting | probe: Change Directory with 300- and 1,000-byte file paths |
| S3 | D4 packing walk + external packer | `CPanelTmpEnumData::WorkPath` and its five fill sites hold any supported length (heap); `_ReadDirectoryTree` reports a failure instead of returning success; `pack2.cpp` refuses a source folder that does not fit before `strcpy` | probe: pack nested folders from 300- and 1,000-byte folders into ZIP and 7z, read back |
| S4 | D3 7zip plug-in | `_snprintf_s` for the item message (`extract.cpp`) and the ISO caption (`7zip.cpp`); other unbounded formats in the plug-in fed by names | probe: ISO image at a 2,100-byte path through the 7zip plug-in |
| S5 | gates | Debug + Release, saltests, guard, probes 095-097, records | - |

Pre-change Debug build preserved as `build\tandemcommander\Debug_x64_pre098` for
the negative controls. No interface change, no strings.
