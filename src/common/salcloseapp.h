// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcloseapp.h
//
// Closing for an update - the pure part (feature 080).
//
// An installer (a package manager, Inno Setup) that has to replace files of a
// running program asks Windows' Restart Manager to close it. The Restart
// Manager sends every top-level window of the process
//
//   WM_QUERYENDSESSION (wParam 0, lParam ENDSESSION_CLOSEAPP)   "can you close?"
//   WM_ENDSESSION      (wParam 1/0, lParam ENDSESSION_CLOSEAPP) "close now" / "never mind"
//
// and then waits up to 30 s for the process to end (measured, see
// specs/080-restart-manager-upgrade/research.md R2). Nobody kills the process
// and nobody sits at the machine, so the program must either close without
// asking anything or decline at once.
//
// This module decides. It knows nothing about the core: the main window
// fills a plain snapshot and gets a decision back, which makes the rules
// testable without a GUI (saltests, TestCloseApp080). It has no side effects.
//
// Contract: specs/080-restart-manager-upgrade/contracts/close-request.md
//           specs/080-restart-manager-upgrade/contracts/restart-registration.md
//
//*****************************************************************************

// TRUE when a session message (WM_QUERYENDSESSION / WM_ENDSESSION) with this
// 'lParam' is an installer's close request: ENDSESSION_CLOSEAPP set,
// ENDSESSION_CRITICAL not set, and the session is not shutting down
// ('sessionShuttingDown' = GetSystemMetrics(SM_SHUTTINGDOWN) != 0).
// Everything else - sign-out, shutdown, critical shutdown, Windows closing
// programs for servicing - is NOT covered and keeps its own handling.
BOOL SalIsCloseAppRequest(LPARAM lParam, BOOL sessionShuttingDown);

// what a top-level window of our process is, as far as the core can tell
enum CSalCloseAppWindowKind
{
    scawMain,           // the main window
    scawInternalViewer, // a window of the internal viewer (closed by the exit sequence without questions)
    scawFind,           // a Find dialog (asked by the exit sequence; searching ones are counted separately)
    scawHelp,           // the HTML Help window (lives in our process, goes away with it)
    scawOther           // anything else: a plug-in's window, a dialog, a tooltip...
};

struct CSalCloseAppWindow
{
    BOOL Visible;  // IsWindowVisible
    DWORD Style;   // GWL_STYLE
    DWORD ExStyle; // GWL_EXSTYLE
    CSalCloseAppWindowKind Kind;
};

// TRUE when 'w' is a window the core cannot account for: visible, of kind
// scawOther, and a real window - i.e. not a captionless tool / no-activate
// window (tooltips, save-bits and IME windows never count; a captionless
// full-screen viewer does)
BOOL SalCloseAppWindowIsForeign(const CSalCloseAppWindow& w);

// read-only picture of the program at the moment of the request
struct CSalCloseAppSnapshot
{
    BOOL StartupFinished;     // the main window may be closed at all (start-up completed)
    BOOL CloseInProgress;     // a close of the main window is already under way
    BOOL Busy;                // the main thread is inside something (modal dialog, menu, command) or the main window is disabled
    BOOL InsidePlugin;        // the main thread is inside a plug-in call
    int FileOperations;       // running file operations (progress dialogs)
    int FindSearching;        // Find windows with a search in progress
    BOOL ArchiveEditsPending; // files opened from an archive may have to be packed back (either panel)
    BOOL PluginFSOpen;        // a panel shows a plug-in file system, or a detached one exists
    const CSalCloseAppWindow* Windows; // all top-level windows of the process (may be NULL when WindowCount == 0)
    int WindowCount;
};

enum CSalCloseAppDecision
{
    scadAgree,            // the instance can close now without asking anybody anything
    scadStartupOrClosing, // D1
    scadBusy,             // D2
    scadInsidePlugin,     // D3
    scadFileOperations,   // D4
    scadFindSearching,    // D5
    scadArchiveEdits,     // D6
    scadPluginFS,         // D7
    scadForeignWindow     // D8
};

// the first matching reason in the order D1..D8 wins, so that the trace names
// the most fundamental obstacle; total, no side effects
CSalCloseAppDecision SalCloseAppDecide(const CSalCloseAppSnapshot& s);

// constant ASCII name of a decision, for the trace
const char* SalCloseAppDecisionName(CSalCloseAppDecision d);

// Composes the command line for RegisterApplicationRestart: identity, not
// location. "-t <prefix>" when the instance was started with a title prefix,
// "-i <n>" when it was started with an icon index (0..3), nothing else - the
// panels' directories and the tabs come back from the stored configuration.
// The prefix is quoted the way the program's own tokenizer (GetCmdLine) reads
// it: enclosed in double quotes, a literal double quote doubled.
// A part that does not fit into 'out' is left out whole, never cut (a cut
// quoted argument would not parse). 'outLen' counts the terminating zero;
// pass RESTART_MAX_CMD_LINE. Returns FALSE only when 'out' cannot even hold
// an empty string; then nothing is written.
BOOL SalRestartCommandLine(WCHAR* out, int outLen, BOOL hasTitlePrefix, const WCHAR* titlePrefix,
                           BOOL hasIconIndex, int iconIndex);
