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
// a click, by the automatic level while the program runs, or at the next start;
// feature 422: never at the program's exit). The rules are in
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

// plans the verified installer of 'release' (source SALUPD_ARM_USER / _AUTOMATIC);
// an arm of the same version keeps its launch count
void UpdInstall_Arm(const CSalUpdRelease& release, DWORD source);

// Install Now: verifies the installer of 'release' again, arms it (source user) and starts it
// (kind "now"); the update close of feature 080 then ends the program. The user is told about
// every failure: UPDNOW_DAMAGED - the downloaded installer is missing or not the verified one (it
// is deleted; only the browser download is left), UPDNOW_FAILED - busy or could not be started.
#define UPDNOW_STARTED 1
#define UPDNOW_FAILED 0
#define UPDNOW_DAMAGED -1
int UpdInstall_InstallNow(HWND parent, const CSalUpdRelease& release);

// Feature 421: Download & Install on the classic form. Starts the download of 'release' (also on a
// metered connection: a click) and remembers the request; the main window ('mainWindow') takes it with
// UpdInstall_TakeInstallRequest when WM_USER_UPDATEDOWNLOAD_DONE arrives and starts the installer with
// UpdInstall_InstallNow. A verified installer already present is started at once.
#define UPDDLI_FAILED 0      // not started (the user was told when there is anything to tell)
#define UPDDLI_STARTED 1     // the installer was started (Install Now)
#define UPDDLI_DOWNLOADING 2 // the download runs; the request waits for it
int UpdInstall_DownloadAndInstall(HWND parent, HWND mainWindow, const CSalUpdRelease& release);
// IDS_UPDATE_DLI_FAILED for 'version'
void UpdInstall_ReportDownloadFailed(HWND parent, const CSalUpdVersion& version);
// drops the request; stops the download when the request started it
void UpdInstall_CancelDownloadAndInstall();
BOOL UpdInstall_IsInstallRequested(const CSalUpdVersion& version);
// TRUE (and forgets the request) when a Download & Install of 'version' waits for its download
BOOL UpdInstall_TakeInstallRequest(const CSalUpdVersion& version);
// TRUE while the download of 'version' runs: the bytes received and the asset's size
BOOL UpdInstall_GetDownloadProgress(const CSalUpdVersion& version, ULONGLONG* received, ULONGLONG* total);
// SalUpdDownloadInstallOffered for this copy and 'release'
BOOL UpdInstall_DownloadInstallOffered(const CSalUpdRelease& release);
BOOL UpdInstall_IsRefused(const CSalUpdVersion& version);
BOOL UpdInstall_InstallerRunning();
BOOL UpdInstall_IsLastInstance();
BOOL UpdInstall_HasVerified(const CSalUpdRelease& release);
// feature 422: no "Install When I Close" and no install at the exit any more

// Skip This Version: drops an arm of that version and deletes its installer
void UpdInstall_SkipVersion(const CSalUpdVersion& version);

// round 4: the user clicked Skip This Version (NoteSkipClick); TakeSkipClick answers whether it was
// that version and forgets the click (called when a download starts and when it ends)
void UpdInstall_NoteSkipClick(const CSalUpdVersion& version);
BOOL UpdInstall_TakeSkipClick(const CSalUpdVersion& version);

// Called once when start-up is complete (after the check of feature 123 was started): removes
// leftovers of the updates folder and decides an armed update (data-model.md). An update not
// installed while the program ran (feature 422: never at the exit) is completed at once: WM_USER_UPDATEINSTALL is posted to 'mainWindow',
// whose handler calls UpdInstall_CompleteArmed().
void UpdInstall_OnStartupComplete(HWND mainWindow);
void UpdInstall_CompleteArmed(HWND parent);

// review 2: the armed update as a release (version + digest) when its installer is still the
// verified one - for the offer at start-up (WM_USER_UPDATEINSTALL with wParam 1); FALSE (the arm is
// dropped) otherwise
BOOL UpdInstall_GetArmedRelease(CSalUpdRelease* release);

// reports a failed Install Now (WM_USER_UPDATEINSTALL_DONE) with OK only; feature 422: an automatic plan
// becomes offered (never started on its own again); TRUE - the caller offers the update again
BOOL UpdInstall_OnInstallerEnded(HWND parent, DWORD exitCode);
// the release whose installer Install Now / the start-up completion started, when its installer is
// still the verified one
BOOL UpdInstall_GetLaunchedRelease(CSalUpdRelease* release);

// Program exit: Shutdown abandons a running download (never waits for the network); feature 422: the
// exit never starts an installer.
void UpdInstall_Shutdown();
