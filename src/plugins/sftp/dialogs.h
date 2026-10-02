// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

class CSFTPServer;

// ****************************************************************************
// Dialog entry points. Implementations in dialogs.cpp.
// ****************************************************************************

// UTF-8 control text helpers (feature 010): names/paths are UTF-8 (interface
// 104) and must cross to the Unicode controls via the W API; each falls back
// to the A call on conversion failure so text is never dropped.
void SetDlgItemTextU8(HWND hwnd, int id, const char* text);
int GetDlgItemTextU8(HWND hwnd, int id, char* buf, int bufSize);
int ListBoxAddStringU8(HWND lb, const char* text);

// Dark-theme touchpoints shared by every raw dialog proc in this plugin
// (feature 036): call first in the proc; WM_INITDIALOG themes the dialog and
// returns FALSE (continue init), WM_CTLCOLOR* returns TRUE with '*result' set
// while the Dark theme is active.
BOOL SFTPThemeDlgMsg(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam, INT_PTR* result);

// Connect / bookmarks dialog. Fills 'result' with the chosen connection.
// Returns TRUE if the user pressed Connect, FALSE on Cancel. When
// 'organizeMode' is TRUE, the dialog only manages bookmarks (no connect).
BOOL ShowConnectDialog(HWND parent, BOOL organizeMode, CSFTPServer* result);

// Plaintext secrets the connect dialog just captured (avoids re-prompting when
// the user typed a password but chose not to store it). Consumed and wiped by
// the connect flow. Empty string = not provided.
extern char ConnectPlainPassword[SFTP_SECRET_BUF];
extern char ConnectPlainPassphrase[SFTP_SECRET_BUF];

// Host-key verification dialog (FR-006). 'changed' selects the "key changed"
// warning variant. Returns one of: IDB_HOSTKEY_TRUST (trust and store),
// IDB_HOSTKEY_ONCE (connect once), IDCANCEL (abort).
int ShowHostKeyDialog(HWND parent, BOOL changed, const char* host, int port,
                      const char* keyType, const char* fingerprint,
                      const char* storedFingerprint);

// Generic single password/passphrase prompt. Returns TRUE on OK.
BOOL ShowPasswordPrompt(HWND parent, const char* promptText, char* out, int outSize);

// chmod dialog. 'mode' is in/out (permission bits incl. special bits).
// 'multiple' relaxes checkbox tri-state handling for multi-selection.
// On return, *recurse / *setTime / *mtime carry the extra options.
BOOL ShowChmodDialog(HWND parent, const char* targetLabel, BOOL multiple,
                     unsigned long* mode, BOOL* recurse, BOOL* setTime, __int64* mtime);

// Owner/Group dialog (feature 018). 'hasDir' enables the recursive option.
// 'uid'/'gid' are in/out (seed = current); '*setUid'/'*setGid' report which
// field the user chose to change; '*recurse' applies to a directory subtree.
// Returns TRUE on OK (with at least one of setUid/setGid TRUE).
BOOL ShowOwnerGroupDialog(HWND parent, const char* targetLabel, BOOL hasDir,
                          unsigned long* uid, BOOL* setUid, unsigned long* gid, BOOL* setGid,
                          BOOL* recurse);

// Symlink creation dialog. Fills name+target (each MAX_PATH). Returns TRUE on OK.
BOOL ShowSymlinkDialog(HWND parent, char* name, char* target);

// Simple rename dialog. 'name' is in/out (MAX_PATH). Returns TRUE on OK.
BOOL ShowRenameDialog(HWND parent, const char* prompt, char* name);

// Resume/Overwrite/Skip prompt for an existing smaller target (FR-011).
// Returns IDYES (resume), IDNO (overwrite), IDCANCEL (skip/abort).
int ShowResumePrompt(HWND parent, const char* fileName);

// Configuration page (embedded). Runs the modal config, applying to Config.
void ShowConfigDialog(HWND parent);
