// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// upddlg.h
//
// Checking for a new version (feature 123) - the windows: the notification
// about a new version (modeless), the wait dialog of a check the user asked
// for, and the answers of that check.
//
// Contract: specs/123-new-version-check/contracts/ui.md
//
//*****************************************************************************

#include "updcheck.h"
#include "gui.h"

// A hyperlink in a dialog that acts on Enter itself. A plain CHyperLink is a
// static for the dialog manager, which therefore turns Enter on the focused
// link into the default button - and that cannot be told apart from the
// default button's own access key in the dialog's IDOK handler.
class CUpdateLink : public CHyperLink
{
public:
    CUpdateLink(HWND hDlg, int ctrlID) : CHyperLink(hDlg, ctrlID) {}

protected:
    virtual LRESULT WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam);
};

// A visible notification carries this window property, so that other
// instances of the same user find it (EnumWindows + GetProp): one
// notification per user (contracts/stored-state.md, "Window property").
#define UPDATENOTICE_WINDOW_PROP L"TandemCommander.UpdateNotice"

// the About dialog while it is open (it refreshes its new-version line when a check finishes)
extern HWND UpdateAboutWindow;

// The notification window of this instance, or NULL.
HWND UpdateNotice_GetWindow();

// A notification window of any instance of this user (ours included), or NULL.
HWND UpdateNotice_FindAny();

// Shows the notification for 'release' (owner: the main window). When one is
// already open - in this or another instance - it is brought to the front
// instead ('activate' TRUE) or left alone ('activate' FALSE).
// 'activate' FALSE shows the window without taking the keyboard.
void UpdateNotice_Show(HWND mainWindow, const CSalUpdRelease& release, BOOL activate);

// Destroys this instance's notification without a question (program exit, an
// installer closing the program). The same as "Remind Me Later".
void UpdateNotice_Close();

// Hands 'url' to the default browser. On failure offers to copy the address.
// Only addresses constructed by salupdcheck.h are ever passed here.
BOOL UpdateCheck_OpenUrl(HWND parent, const char* url);

// Help > Check for New Version, and the About dialog's "Check now": starts
// the check (or joins the running one), shows the wait dialog when it takes
// longer than a moment, and answers "up to date" and the failures with a
// message. Returns FALSE when there is nothing more to do; TRUE with 'done'
// filled when the result is surNewer - the caller shows it (the main window:
// the notification; the About dialog: its line).
BOOL UpdateCheck_RunManualUI(HWND parent, CUpdateCheckDone* done);

// TRUE while UpdateCheck_RunManualUI waits: the main window then leaves
// WM_USER_UPDATECHECK_DONE to it.
BOOL UpdateCheck_ManualUIWaiting();
