// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// updinstall.h
//
// Automatic update (feature 420) - the part that touches Windows: the update
// level and the armed update in the registry, the installation the program
// runs from, the metered-connection test, the download worker, the
// verification of a downloaded installer and the start of the installer (on
// a click, at the program's exit, or at the next start). The rules are in
// common/salupdinstall.h (pure, tested by saltests).
//
// Contracts: specs/420-auto-update-install/contracts/*.md
//
// Threading: everything here is called from the main thread, except the
// workers (download, installer watcher). A finished download is announced to
// the main window with WM_USER_UPDATEDOWNLOAD_DONE; the main window then
// fetches the result with UpdInstall_TakeDownloadResult(). An installer
// started by Install Now that ends while the program still runs is announced
// with WM_USER_UPDATEINSTALL_DONE [exit code, 0].
//
//*****************************************************************************

#include "salupdinstall.h"
#include "updcheck.h"

// the level of Configuration > General (stored value "Update Level", read fresh)
CSalUpdLevel UpdInstall_GetLevel();
void UpdInstall_SetLevel(CSalUpdLevel level);

// the armed update (contracts/stored-state.md)
BOOL UpdInstall_LoadArm(CSalUpdArm* arm);
void UpdInstall_DropArm();
// does the arm still count (its source, the check option, the level, test mode)?
BOOL UpdInstall_ArmHonoured(const CSalUpdArm& arm);
// the check option or the level changed: an automatic arm that no longer counts is dropped
void UpdInstall_OnSettingsChanged();

// The installation the running program belongs to: an uninstall entry of the program's AppId
// whose install location is the program's folder. '*allUsers': HKLM (TRUE) or HKCU (FALSE).
// Looked up once per session.
BOOL UpdInstall_IsEligible(BOOL* allUsers);

// TRUE when Windows reports the current connection as metered (or costs data)
BOOL UpdInstall_IsMetered();

// What the main window does with a newer release found by a check: download (or reuse a
// verified installer) per SalUpdAfterCheck. Returns the decision; for suacDownload the
// download has started, or '*readyNow' is TRUE when a verified installer of that version is
// already in the updates folder (the caller offers / arms it at once).
CSalUpdAfterCheck UpdInstall_AfterCheck(HWND mainWindow, const CSalUpdRelease& release, BOOL* readyNow);

BOOL UpdInstall_IsDownloading();

struct CUpdDownloadDone
{
    BOOL Ok; // downloaded and verified
    CSalUpdRelease Release;
};

// fetches the result announced by WM_USER_UPDATEDOWNLOAD_DONE; FALSE when there is none
BOOL UpdInstall_TakeDownloadResult(CUpdDownloadDone* done);

// arms the verified installer of 'release' for the exit (source SALUPD_ARM_USER / _AUTOMATIC);
// an arm of the same version keeps its launch count
void UpdInstall_Arm(const CSalUpdRelease& release, DWORD source);

// Install Now: verifies the installer of 'release' again, arms it (source user) and starts it
// (kind "now"); the update close of feature 080 then ends the program. FALSE (the user was
// told) when the installer could not be verified or started.
BOOL UpdInstall_InstallNow(HWND parent, const CSalUpdRelease& release);

// Skip This Version: drops an arm of that version and deletes its installer
void UpdInstall_SkipVersion(const CSalUpdVersion& version);

// Called once when start-up is complete (after the check of feature 123 was started): removes
// leftovers of the updates folder and decides an armed update (data-model.md). An update the
// exit did not install is completed at once: WM_USER_UPDATEINSTALL is posted to 'mainWindow',
// whose handler calls UpdInstall_CompleteArmed().
void UpdInstall_OnStartupComplete(HWND mainWindow);
void UpdInstall_CompleteArmed(HWND parent);

// reports a failed Install Now (WM_USER_UPDATEINSTALL_DONE)
void UpdInstall_OnInstallerEnded(HWND parent, DWORD exitCode);

// Program exit: PrepareExit right after the main message loop decides whether the armed update
// is installed now (and keeps the verified file open); RunAtExit, the last statement of the
// exit, starts the installer. Shutdown abandons a running download (never waits for the network).
void UpdInstall_PrepareExit();
void UpdInstall_RunAtExit();
void UpdInstall_Shutdown();
