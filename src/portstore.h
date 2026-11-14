// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// portstore.h
//
// Feature 428: the settings store of the portable edition (TC_PORTABLE).
//
// The portable program never writes the Windows registry. At start it builds a private registry
// hive (RegLoadAppKeyW - invisible to the rest of Windows) in
// %TEMP%\TandemCommander-portable-<scope>\session.dat from settings\tandemcommander.reg next to
// the executable (the program's own export format), and the whole program and every plug-in run
// on that hive through SalCfgBaseKey() (consts.h). Every change of the hive is written back to the
// file (2 s after the last change, at once after SaveConfig, at exit) - through a temporary file
// and SalReplaceWithTempW, the previous file kept as tandemcommander.reg.bak - with the program
// folder inside string values written as $(PortableDir). When the last process of a copy exits, the
// session folder is removed.
//
// Contract: specs/428-portable-build/contracts/settings-store.md; decisions: research.md R-01..R-05.
//
//*****************************************************************************

#ifdef TC_PORTABLE

// first in WinMainBody, before anything reads a setting or creates a named object; FALSE = the
// program must not start (a message was shown); it never falls back to the user's registry
BOOL PortableStore_Open();

// at the very end of WinMainBody: the last persist (only when the hive changed), the hive closed,
// the session folder removed by the last process of this copy
void PortableStore_Close();

// synchronous persist; called right after CMainWindow::SaveConfig returns
void PortableStore_PersistNow();

// FR-013: Options > Import Configuration of the portable edition - the chosen file is checked as an
// import would check it and kept as settings\import.reg; the next start that no other process of
// this copy shares imports it (ApplyPendingImport, where the installed edition imports config.reg)
// and deletes it
void PortableStore_ImportConfigurationCommand(HWND parent);
void PortableStore_ApplyPendingImport();

// FALSE when the settings cannot be saved (the folder is read-only, a save failed)
BOOL PortableStore_IsWritable();

// <program folder>\settings (wide and UTF-8); the folder may not exist yet
const WCHAR* PortableStore_SettingsDirW();
const char* PortableStore_SettingsDirU8();

// %TEMP%\TandemCommander-portable-<scope> (exists while the program runs)
const WCHAR* PortableStore_SessionDirW();

// "_P<scope>" - the suffix of the named kernel objects of this copy (FR-011a)
const char* PortableStore_ScopeSuffix();

// once the main window is up: lets the store post WM_USER_PORTABLE_NOTE to it (a message that
// waited for the language module: a restored or damaged settings file, settings that cannot be
// saved) and posts it now when one is pending
void PortableStore_AttachMainWindow(HWND mainWnd);

// in WM_USER_PORTABLE_NOTE when the main window is free: shows each pending message once
void PortableStore_ShowPendingNotes(HWND parent);

// FR-015a: a password is being stored without a master password - the note is shown once per
// session when the main window is free (PortableShowPasswordNote, pwdmngr.cpp); any thread
void PortableStore_RequestPasswordNote();
void PortableShowPasswordNote(HWND parent); // pwdmngr.cpp

#ifdef _DEBUG
// the round-trip seam of the gate test (specs/428-portable-build/probe/roundtrip_gate.py):
// tandemcommander.exe --portabletest-roundtrip <src.dat> <dump.reg> <dst.dat> <programDir>
// TRUE when the command line asked for it ('*exitCode' = 0 on success)
BOOL PortableStore_RunSelfTest(int* exitCode);
#endif

// "<base>_P<scope>" - the name of a kernel object shared only by the processes of THIS copy
// (FR-011a: copies from different folders and the installed program never see each other); the
// pointer stays valid for the whole run
const char* PortableScopedName(const char* base);
const WCHAR* PortableScopedNameW(const WCHAR* base);

#else // TC_PORTABLE

inline const char* PortableStore_ScopeSuffix() { return ""; }
inline const char* PortableScopedName(const char* base) { return base; }
inline const WCHAR* PortableScopedNameW(const WCHAR* base) { return base; }

#endif // TC_PORTABLE
