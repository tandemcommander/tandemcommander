# Implementation Plan: small leftovers (feature 101)

**Branch**: `101-small-leftovers` (from `100-cjk-focus-name`) | **Spec**: [spec.md](spec.md)

| Stage | Items | Files |
|---|---|---|
| S1 | tray tip (W structure, cut at a whole character); clipboard paste any length; Find UNC copy message; share matching whole path; drag image cap | mainwnd1.cpp, fileswn9.cpp, finddlg*.cpp, shares.cpp, stswnd.cpp |
| S2 | exact messages for "cannot read / too deep" in the Move link check and the walk; English strings + translations (translate.merge, certifi TLS, key in temp/deepl_key.txt; re-key bundles if ids are inserted in a used bundle; pins for formal register) | fileswn7.cpp, src/lang/*, translations/* |
| S3 | 096 probe: reliable F4 wait | specs/096-.../probe/archedit_probe.ps1 |
| S4 | gates and records | - |

Probes on the hidden desktop against `build\tandemcommander\Debug_x64_pre101`;
independent review; one commit per stage after review or one at the end.
