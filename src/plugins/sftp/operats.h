// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

class CSFTPSession;

// ****************************************************************************
// File operations (download / upload / delete / chmod). v1 runs them
// synchronously on the calling thread with a cancellable wait window; the
// design leaves room for the worker-thread queue described in research.md.
// Each returns TRUE on full success, FALSE on error/cancel (a message has
// already been shown for genuine errors).
// ****************************************************************************

// feature 133: the error box of a failed operation - the template 'fmtID' (one or two "%s"),
// the path or name and the reason. The text is never cut (it was composed in 1,200 bytes: a
// long path was cut and the reason behind it lost).
// 'logUID' other than -1: the message also goes to that session's log.
void SFTPShowPathError(HWND parent, int fmtID, const char* path, const char* reason, int logUID = -1);

// Recursively downloads the panel's selected/focused items from 'remoteDir'
// into 'targetLocalPath'. 'move' additionally deletes the source on success.
BOOL SFTPDownloadFromPanel(HWND parent, CSFTPSession* session, int panel,
                           const char* remoteDir, const char* targetLocalPath, BOOL move);

// Uploads files/dirs enumerated by 'next'/'nextParam' (relative to
// 'sourcePath') into remote 'targetRemoteDir'. 'move' deletes local source.
BOOL SFTPUploadToFS(HWND parent, CSFTPSession* session, const char* sourcePath,
                    SalEnumSelection2 next, void* nextParam, const char* targetRemoteDir, BOOL move);

// Recursively deletes the panel's selected/focused items from 'remoteDir'.
BOOL SFTPDeleteFromPanel(HWND parent, CSFTPSession* session, int panel, const char* remoteDir);

// Applies a chmod (and optional mtime) to the panel's selection under
// 'remoteDir'. Opens the chmod dialog; returns TRUE when changes were applied.
BOOL SFTPChangeAttrsFromPanel(HWND parent, CSFTPSession* session, int panel, const char* remoteDir);
// feature 018: change owner/group of the panel selection (recursive for dirs)
BOOL SFTPChangeOwnerFromPanel(HWND parent, CSFTPSession* session, int panel, const char* remoteDir);
