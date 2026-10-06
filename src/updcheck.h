// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// updcheck.h
//
// Checking for a new version (feature 123) - the part that touches Windows:
// the stored state, the worker thread and the one HTTPS request. The rules
// are in common/salupdcheck.h (pure, tested by saltests); the windows are in
// upddlg.h.
//
// Contracts: specs/123-new-version-check/contracts/update-source.md
//            specs/123-new-version-check/contracts/stored-state.md
//
// Threading: everything here is called from the main thread, except the
// worker body. A finished check is announced to the main window with
// WM_USER_UPDATECHECK_DONE (no parameters); the main window then fetches the
// result with UpdateCheck_TakeResult().
//
//*****************************************************************************

#include "salupdcheck.h"

// what the program remembers (HKCU\<root>\Update Check), read fresh at every use
struct CUpdateState
{
    BOOL CheckAtStartup; // default TRUE

    BOOL HasLastAttempt;
    ULONGLONG LastAttempt; // UTC FILETIME of the last claimed check
    BOOL LastAttemptAnswered;

    BOOL HasLastSuccess;
    ULONGLONG LastSuccess; // UTC FILETIME of the last valid answer

    BOOL HasLatest;
    CSalUpdVersion Latest;
    ULONGLONG LatestPublished; // UTC FILETIME, 0 when unknown

    BOOL HasSkipped;
    CSalUpdVersion Skipped;
};

// reads the stored state; a missing, mistyped or unparsable value is its default
void UpdateCheck_LoadState(CUpdateState* state);

// each writes one value at once; a store that cannot be written is not an error
void UpdateCheck_SetCheckAtStartup(BOOL on);
void UpdateCheck_SetSkippedVersion(const CSalUpdVersion& version);

// the version of the running program
void UpdateCheck_GetInstalledVersion(CSalUpdVersion* version);

// what the About dialog shows, from the stored state alone (no request)
CSalUpdKnownState UpdateCheck_GetKnownState(CUpdateState* state);

// a long date in the user's locale for a UTC FILETIME (local time zone); FALSE when it cannot be formatted
BOOL UpdateCheck_FormatDate(ULONGLONG utcFileTime, WCHAR* buf, int bufSize);

// the result of a finished check
struct CUpdateCheckDone
{
    CSalUpdResult Result;
    CSalUpdRelease Release; // valid for surNewer / surUpToDate
    BOOL Manual;            // the user asked for it (or joined a running automatic check)
};

// Called once when start-up is complete: starts the automatic check when the
// option is on and a check may be due. Reads the registry only; the request
// (and the load of winhttp.dll) happens on the worker thread.
void UpdateCheck_OnStartupComplete(HWND mainWindow);

// Starts a check the user asked for, or joins the running automatic one. The
// answer arrives as WM_USER_UPDATECHECK_DONE with Manual == TRUE. Returns
// FALSE when the worker could not be started (the caller reports it).
BOOL UpdateCheck_StartManual(HWND mainWindow);

BOOL UpdateCheck_IsRunning();

// Gives up the running check: its result is announced at once - surCancelled,
// or surUnreachable when 'timedOut' (the caller stopped waiting) - and the
// worker is let go; whatever it still learns is dropped. Returns immediately.
void UpdateCheck_Cancel(BOOL timedOut);

// Fetches the result announced by WM_USER_UPDATECHECK_DONE; FALSE when there
// is none (it was already taken).
BOOL UpdateCheck_TakeResult(CUpdateCheckDone* done);

// Program exit: gives up a running check without waiting for anything.
// Nothing is announced afterwards.
void UpdateCheck_Shutdown();
