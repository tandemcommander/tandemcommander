// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "sftp.h"
#include "sftputils.h"
#include "keyload.h"
#include "dialogs.h"

char ConnectPlainPassword[SFTP_SECRET_BUF] = "";
char ConnectPlainPassphrase[SFTP_SECRET_BUF] = "";

// ---------------------------------------------------------------------------
// UTF-8 dialog text helpers (feature 010)
// ---------------------------------------------------------------------------

// Sets a dialog control's text from a UTF-8 string (interface 104) via the W
// API so names outside the ACP display correctly; falls back to the A call on
// conversion failure (invalid UTF-8 is still shown, never dropped).
void SetDlgItemTextU8(HWND hwnd, int id, const char* text)
{
    WCHAR* w = SplU8ToWAlloc(text);
    if (w != NULL)
        SetDlgItemTextW(hwnd, id, w);
    else
        SetDlgItemTextA(hwnd, id, text != NULL ? text : "");
    free(w);
}

// Reads a dialog control's text as UTF-8 via the W API (the A call would
// convert through the ACP and mangle names). Returns the length in bytes
// without the terminator; falls back to the A call on conversion failure.
int GetDlgItemTextU8(HWND hwnd, int id, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return 0;
    buf[0] = 0;
    HWND ctrl = GetDlgItem(hwnd, id);
    if (ctrl == NULL)
        return 0;
    int wchars = GetWindowTextLengthW(ctrl);
    if (wchars <= 0)
        return 0;
    int len = 0;
    WCHAR* w = (WCHAR*)malloc((wchars + 1) * sizeof(WCHAR));
    if (w != NULL)
    {
        if (GetWindowTextW(ctrl, w, wchars + 1) > 0)
        {
            len = SplWToU8(w, buf, bufSize);
            if (len > 0)
                len--; // exclude the terminator
        }
        free(w);
    }
    if (len == 0) // OOM or conversion failure: A fallback (never drop text)
        len = GetDlgItemTextA(hwnd, id, buf, bufSize);
    return len;
}

// Adds a UTF-8 string to a list box via the W API; A fallback on invalid UTF-8.
int ListBoxAddStringU8(HWND lb, const char* text)
{
    WCHAR* w = SplU8ToWAlloc(text);
    if (w == NULL)
        return (int)SendMessageA(lb, LB_ADDSTRING, 0, (LPARAM)text);
    int idx = (int)SendMessageW(lb, LB_ADDSTRING, 0, (LPARAM)w);
    free(w);
    return idx;
}

// ---------------------------------------------------------------------------
// dark-theme touchpoints (feature 036)
// ---------------------------------------------------------------------------

// Shared theme handling for all raw dialog procs in this plugin: themes the
// dialog on WM_INITDIALOG (and lets the proc continue with its own init) and
// colors the WM_CTLCOLOR* family while the Dark theme is active. Returns TRUE
// when the message is fully answered by the theme layer ('*result' holds the
// dialog-proc return value).
BOOL SFTPThemeDlgMsg(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam, INT_PTR* result)
{
    if (msg == WM_INITDIALOG)
    {
        SalamanderGeneral->ThemeApplyToDialog(hwnd);
        return FALSE; // theming done, the dialog continues its own init
    }
    return SalamanderGeneral->ThemeHandleCtlColor(msg, wParam, lParam, result);
}

// feature 094: reads a secret field (password, key passphrase) as UTF-8. Unlike
// GetDlgItemTextU8 it never falls back to the code-page read: a secret that
// does not fit gives an empty buffer instead of other bytes than were typed.
// The fields are limited to SFTP_SECRET_MAX_CHARS and the buffers have
// SFTP_SECRET_BUF bytes, so "does not fit" needs a text set past the limit.
static int GetDlgItemSecretU8(HWND hwnd, int id, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return 0;
    buf[0] = 0;
    HWND ctrl = GetDlgItem(hwnd, id);
    if (ctrl == NULL)
        return 0;
    int wchars = GetWindowTextLengthW(ctrl);
    if (wchars <= 0)
        return 0;
    int len = 0;
    WCHAR* w = (WCHAR*)malloc((wchars + 1) * sizeof(WCHAR));
    if (w != NULL)
    {
        if (GetWindowTextW(ctrl, w, wchars + 1) > 0)
        {
            len = SplWToU8(w, buf, bufSize);
            if (len > 0)
                len--; // exclude the terminator
            else
                SecureZeroMemory(buf, bufSize);
        }
        SecureZeroMemory(w, (wchars + 1) * sizeof(WCHAR));
        free(w);
    }
    return len;
}

// ---------------------------------------------------------------------------
// password / passphrase prompt
// ---------------------------------------------------------------------------

struct CPasswordPromptData
{
    const char* Prompt;
    char* Out;
    int OutSize;
};

static INT_PTR CALLBACK PasswordPromptProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    CPasswordPromptData* d = (CPasswordPromptData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);
    switch (msg)
    {
    case WM_INITDIALOG:
        d = (CPasswordPromptData*)lParam;
        SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)d);
        SetDlgItemTextU8(hwnd, IDT_PROMPTTEXT, d->Prompt); // contains the user name
        // feature 094: what the field accepts always fits the caller's buffer as UTF-8
        SendDlgItemMessage(hwnd, IDE_PROMPTPASSWORD, EM_LIMITTEXT,
                           min(SFTP_SECRET_MAX_CHARS, (d->OutSize - 1) / 4), 0);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        SetFocus(GetDlgItem(hwnd, IDE_PROMPTPASSWORD));
        return FALSE;
    case WM_COMMAND:
        if (LOWORD(wParam) == IDOK)
        {
            GetDlgItemSecretU8(hwnd, IDE_PROMPTPASSWORD, d->Out, d->OutSize);
            EndDialog(hwnd, IDOK);
            return TRUE;
        }
        if (LOWORD(wParam) == IDCANCEL)
        {
            EndDialog(hwnd, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

BOOL ShowPasswordPrompt(HWND parent, const char* promptText, char* out, int outSize)
{
    CPasswordPromptData d;
    d.Prompt = promptText;
    d.Out = out;
    d.OutSize = outSize;
    out[0] = 0;
    return DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_PASSWORD), parent, PasswordPromptProc, (LPARAM)&d) == IDOK;
}

// ---------------------------------------------------------------------------
// host-key verification (TOFU)
// ---------------------------------------------------------------------------

struct CHostKeyData
{
    BOOL Changed;
    const char* Host;
    int Port;
    const char* KeyType;
    const char* Fingerprint;
    const char* StoredFingerprint;
};

static INT_PTR CALLBACK HostKeyProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    CHostKeyData* d = (CHostKeyData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);
    switch (msg)
    {
    case WM_INITDIALOG:
    {
        d = (CHostKeyData*)lParam;
        SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)d);
        char hostPort[320];
        _snprintf_s(hostPort, _TRUNCATE, "%s:%d", d->Host, d->Port);
        char text[1400];
        if (d->Changed)
        {
            SetWindowTextA(hwnd, LoadStr(IDS_HOSTKEY_CHANGEDTITLE));
            _snprintf_s(text, _TRUNCATE, LoadStr(IDS_HOSTKEY_CHANGEDTEXT),
                        d->KeyType, hostPort,
                        d->StoredFingerprint != NULL ? d->StoredFingerprint : "?",
                        d->Fingerprint);
            SetDlgItemTextA(hwnd, IDB_HOSTKEY_TRUST, LoadStr(IDS_HOSTKEY_ACCEPTNEW));
        }
        else
        {
            SetWindowTextA(hwnd, LoadStr(IDS_HOSTKEY_NEWTITLE));
            _snprintf_s(text, _TRUNCATE, LoadStr(IDS_HOSTKEY_NEWTEXT), hostPort, d->KeyType, d->Fingerprint);
        }
        SetDlgItemTextU8(hwnd, IDT_HOSTKEY_TEXT, text); // contains the host name
        // The warning icon is applied here rather than named in the dialog
        // template: a template-level reference would be looked up in the
        // language module, which does not hold any icons.
        //
        // Use the shell's standard warning icon rather than the plugin's own
        // warning.ico: that file holds a single 16x16 image, and this control
        // is 20x20 dialog units (~30x32 px), so it could only ever be upscaled
        // into a blur. IDI_WARNING ships at every size, stays crisp at high DPI,
        // and is the same icon a message box would show here.
        //
        // LR_SHARED: system icons are owned by the system, must not be
        // destroyed, and the handle may be reused -- so no cleanup is needed.
        HICON warnIcon = (HICON)LoadImage(NULL, IDI_WARNING, IMAGE_ICON,
                                          GetSystemMetrics(SM_CXICON),
                                          GetSystemMetrics(SM_CYICON),
                                          LR_SHARED);
        if (warnIcon != NULL)
            SendDlgItemMessage(hwnd, IDI_HOSTKEY_WARN, STM_SETICON, (WPARAM)warnIcon, 0);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        return TRUE;
    }
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDB_HOSTKEY_TRUST:
            EndDialog(hwnd, IDB_HOSTKEY_TRUST);
            return TRUE;
        case IDB_HOSTKEY_ONCE:
            EndDialog(hwnd, IDB_HOSTKEY_ONCE);
            return TRUE;
        case IDCANCEL:
            EndDialog(hwnd, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

int ShowHostKeyDialog(HWND parent, BOOL changed, const char* host, int port,
                      const char* keyType, const char* fingerprint, const char* storedFingerprint)
{
    CHostKeyData d;
    d.Changed = changed;
    d.Host = host;
    d.Port = port;
    d.KeyType = keyType;
    d.Fingerprint = fingerprint;
    d.StoredFingerprint = storedFingerprint;
    if (parent == NULL)
        parent = SalamanderGeneral->GetMsgBoxParent();
    return (int)DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_HOSTKEY), parent, HostKeyProc, (LPARAM)&d);
}

// ---------------------------------------------------------------------------
// resume prompt
// ---------------------------------------------------------------------------

int ShowResumePrompt(HWND parent, const char* fileName)
{
    char msg[1200];
    _snprintf_s(msg, _TRUNCATE, LoadStr(IDS_RESUME_OVERWRITE), fileName);
    // Yes = resume, No = overwrite, Cancel = skip
    return SalamanderGeneral->SalMessageBox(parent, msg, LoadStr(IDS_RESUME_TITLE),
                                            MB_YESNOCANCEL | MB_ICONQUESTION);
}

// ---------------------------------------------------------------------------
// rename
// ---------------------------------------------------------------------------

struct CRenameData
{
    const char* Prompt;
    char* Name;
};

static INT_PTR CALLBACK RenameProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    CRenameData* d = (CRenameData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);
    switch (msg)
    {
    case WM_INITDIALOG:
        d = (CRenameData*)lParam;
        SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)d);
        SetDlgItemTextU8(hwnd, IDT_RENAMEPROMPT, d->Prompt);
        SetDlgItemTextU8(hwnd, IDE_RENAMENAME, d->Name);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        SetFocus(GetDlgItem(hwnd, IDE_RENAMENAME));
        return FALSE;
    case WM_COMMAND:
        if (LOWORD(wParam) == IDOK)
        {
            GetDlgItemTextU8(hwnd, IDE_RENAMENAME, d->Name, MAX_PATH);
            EndDialog(hwnd, IDOK);
            return TRUE;
        }
        if (LOWORD(wParam) == IDCANCEL)
        {
            EndDialog(hwnd, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

BOOL ShowRenameDialog(HWND parent, const char* prompt, char* name)
{
    CRenameData d;
    d.Prompt = prompt;
    d.Name = name;
    return DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_RENAME), parent, RenameProc, (LPARAM)&d) == IDOK;
}

// ---------------------------------------------------------------------------
// symlink
// ---------------------------------------------------------------------------

struct CSymlinkData
{
    char* Name;
    char* Target;
};

static INT_PTR CALLBACK SymlinkProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    CSymlinkData* d = (CSymlinkData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);
    switch (msg)
    {
    case WM_INITDIALOG:
        d = (CSymlinkData*)lParam;
        SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)d);
        SetDlgItemTextU8(hwnd, IDE_SYMLINKNAME, d->Name);
        SetDlgItemTextU8(hwnd, IDE_SYMLINKTARGET, d->Target);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        return TRUE;
    case WM_COMMAND:
        if (LOWORD(wParam) == IDOK)
        {
            GetDlgItemTextU8(hwnd, IDE_SYMLINKNAME, d->Name, MAX_PATH);
            GetDlgItemTextU8(hwnd, IDE_SYMLINKTARGET, d->Target, MAX_PATH);
            if (d->Name[0] == 0 || d->Target[0] == 0)
                return TRUE;
            EndDialog(hwnd, IDOK);
            return TRUE;
        }
        if (LOWORD(wParam) == IDCANCEL)
        {
            EndDialog(hwnd, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

BOOL ShowSymlinkDialog(HWND parent, char* name, char* target)
{
    CSymlinkData d;
    d.Name = name;
    d.Target = target;
    return DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_SYMLINK), parent, SymlinkProc, (LPARAM)&d) == IDOK;
}

// ---------------------------------------------------------------------------
// chmod
// ---------------------------------------------------------------------------

struct CChmodData
{
    const char* Label;
    BOOL Multiple;
    unsigned long Mode;
    BOOL Recurse;
    BOOL SetTime;
    __int64 Mtime;
};

static void ChmodModeToControls(HWND hwnd, unsigned long mode)
{
    CheckDlgButton(hwnd, IDC_UR, (mode & 0400) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_UW, (mode & 0200) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_UX, (mode & 0100) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_GR, (mode & 0040) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_GW, (mode & 0020) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_GX, (mode & 0010) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_OR, (mode & 0004) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_OW, (mode & 0002) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_OX, (mode & 0001) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_SETUID, (mode & 04000) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_SETGID, (mode & 02000) ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(hwnd, IDC_STICKY, (mode & 01000) ? BST_CHECKED : BST_UNCHECKED);
}

static unsigned long ChmodControlsToMode(HWND hwnd)
{
    unsigned long m = 0;
    if (IsDlgButtonChecked(hwnd, IDC_UR))
        m |= 0400;
    if (IsDlgButtonChecked(hwnd, IDC_UW))
        m |= 0200;
    if (IsDlgButtonChecked(hwnd, IDC_UX))
        m |= 0100;
    if (IsDlgButtonChecked(hwnd, IDC_GR))
        m |= 0040;
    if (IsDlgButtonChecked(hwnd, IDC_GW))
        m |= 0020;
    if (IsDlgButtonChecked(hwnd, IDC_GX))
        m |= 0010;
    if (IsDlgButtonChecked(hwnd, IDC_OR))
        m |= 0004;
    if (IsDlgButtonChecked(hwnd, IDC_OW))
        m |= 0002;
    if (IsDlgButtonChecked(hwnd, IDC_OX))
        m |= 0001;
    if (IsDlgButtonChecked(hwnd, IDC_SETUID))
        m |= 04000;
    if (IsDlgButtonChecked(hwnd, IDC_SETGID))
        m |= 02000;
    if (IsDlgButtonChecked(hwnd, IDC_STICKY))
        m |= 01000;
    return m;
}

static INT_PTR CALLBACK ChmodProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    CChmodData* d = (CChmodData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);
    switch (msg)
    {
    case WM_INITDIALOG:
    {
        d = (CChmodData*)lParam;
        SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)d);
        SetDlgItemTextU8(hwnd, IDT_CHMODTARGET, d->Label); // remote file name
        ChmodModeToControls(hwnd, d->Mode);
        char octal[8];
        FormatOctalMode(d->Mode, octal);
        SetDlgItemTextA(hwnd, IDE_OCTAL, octal);
        EnableWindow(GetDlgItem(hwnd, IDE_MTIME), FALSE);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        return TRUE;
    }
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDC_UR:
        case IDC_UW:
        case IDC_UX:
        case IDC_GR:
        case IDC_GW:
        case IDC_GX:
        case IDC_OR:
        case IDC_OW:
        case IDC_OX:
        case IDC_SETUID:
        case IDC_SETGID:
        case IDC_STICKY:
        {
            unsigned long m = ChmodControlsToMode(hwnd);
            char octal[8];
            FormatOctalMode(m, octal);
            SetDlgItemTextA(hwnd, IDE_OCTAL, octal);
            return TRUE;
        }
        case IDE_OCTAL:
            if (HIWORD(wParam) == EN_CHANGE)
            {
                char txt[16];
                GetDlgItemTextA(hwnd, IDE_OCTAL, txt, sizeof(txt));
                unsigned long m;
                if (ParseOctalMode(txt, &m))
                    ChmodModeToControls(hwnd, m);
            }
            return TRUE;
        case IDC_SETTIME:
            EnableWindow(GetDlgItem(hwnd, IDE_MTIME), IsDlgButtonChecked(hwnd, IDC_SETTIME));
            return TRUE;
        case IDOK:
        {
            char txt[16];
            GetDlgItemTextA(hwnd, IDE_OCTAL, txt, sizeof(txt));
            unsigned long m;
            if (ParseOctalMode(txt, &m))
                d->Mode = m;
            else
                d->Mode = ChmodControlsToMode(hwnd);
            d->Recurse = IsDlgButtonChecked(hwnd, IDC_RECURSE);
            d->SetTime = IsDlgButtonChecked(hwnd, IDC_SETTIME);
            if (d->SetTime)
            {
                char mt[64];
                GetDlgItemTextA(hwnd, IDE_MTIME, mt, sizeof(mt));
                // accept a Unix epoch seconds value; empty -> now
                if (mt[0] != 0)
                    d->Mtime = _atoi64(mt);
                else
                {
                    FILETIME ft;
                    GetSystemTimeAsFileTime(&ft);
                    d->Mtime = FileTimeToUnixTime(&ft);
                }
            }
            EndDialog(hwnd, IDOK);
            return TRUE;
        }
        case IDCANCEL:
            EndDialog(hwnd, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

BOOL ShowChmodDialog(HWND parent, const char* targetLabel, BOOL multiple,
                     unsigned long* mode, BOOL* recurse, BOOL* setTime, __int64* mtime)
{
    CChmodData d;
    d.Label = targetLabel;
    d.Multiple = multiple;
    d.Mode = *mode;
    d.Recurse = FALSE;
    d.SetTime = FALSE;
    d.Mtime = 0;
    if (DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_CHMOD), parent, ChmodProc, (LPARAM)&d) != IDOK)
        return FALSE;
    *mode = d.Mode;
    *recurse = d.Recurse;
    *setTime = d.SetTime;
    *mtime = d.Mtime;
    return TRUE;
}

// ---------------------------------------------------------------------------
// owner / group (feature 018)
// ---------------------------------------------------------------------------

struct COwnerGroupData
{
    const char* Label;
    BOOL HasDir; // enable the recursive option
    unsigned long Uid, Gid;
    BOOL SetUid, SetGid;
    BOOL Recurse;
};

static void OwnerGroupSyncEnable(HWND hwnd)
{
    EnableWindow(GetDlgItem(hwnd, IDE_OG_OWNER), IsDlgButtonChecked(hwnd, IDC_OG_SETOWNER));
    EnableWindow(GetDlgItem(hwnd, IDE_OG_GROUP), IsDlgButtonChecked(hwnd, IDC_OG_SETGROUP));
}

static INT_PTR CALLBACK OwnerGroupProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    COwnerGroupData* d = (COwnerGroupData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);
    switch (msg)
    {
    case WM_INITDIALOG:
    {
        d = (COwnerGroupData*)lParam;
        SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)d);
        SetDlgItemTextU8(hwnd, IDT_OG_TARGET, d->Label != NULL ? d->Label : "");
        SetDlgItemInt(hwnd, IDE_OG_OWNER, d->Uid, FALSE);
        SetDlgItemInt(hwnd, IDE_OG_GROUP, d->Gid, FALSE);
        CheckDlgButton(hwnd, IDC_OG_SETOWNER, d->SetUid ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hwnd, IDC_OG_SETGROUP, d->SetGid ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hwnd, IDC_OG_RECURSE, d->Recurse ? BST_CHECKED : BST_UNCHECKED);
        EnableWindow(GetDlgItem(hwnd, IDC_OG_RECURSE), d->HasDir); // recursion only for directories
        OwnerGroupSyncEnable(hwnd);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        return TRUE;
    }
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDC_OG_SETOWNER:
        case IDC_OG_SETGROUP:
            OwnerGroupSyncEnable(hwnd);
            return TRUE;
        case IDOK:
        {
            BOOL setUid = IsDlgButtonChecked(hwnd, IDC_OG_SETOWNER);
            BOOL setGid = IsDlgButtonChecked(hwnd, IDC_OG_SETGROUP);
            if (!setUid && !setGid)
            {
                SalamanderGeneral->SalMessageBox(hwnd, LoadStr(IDS_OG_NEEDFIELD),
                                                 LoadStr(IDS_OG_TITLE), MB_OK | MB_ICONEXCLAMATION);
                return TRUE;
            }
            d->SetUid = setUid;
            d->SetGid = setGid;
            d->Uid = GetDlgItemInt(hwnd, IDE_OG_OWNER, NULL, FALSE);
            d->Gid = GetDlgItemInt(hwnd, IDE_OG_GROUP, NULL, FALSE);
            d->Recurse = d->HasDir && IsDlgButtonChecked(hwnd, IDC_OG_RECURSE);
            EndDialog(hwnd, IDOK);
            return TRUE;
        }
        case IDCANCEL:
            EndDialog(hwnd, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

BOOL ShowOwnerGroupDialog(HWND parent, const char* targetLabel, BOOL hasDir,
                          unsigned long* uid, BOOL* setUid, unsigned long* gid, BOOL* setGid,
                          BOOL* recurse)
{
    COwnerGroupData d;
    d.Label = targetLabel;
    d.HasDir = hasDir;
    d.Uid = *uid;
    d.Gid = *gid;
    d.SetUid = FALSE;
    d.SetGid = FALSE;
    d.Recurse = FALSE;
    if (DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_OWNERGROUP), parent, OwnerGroupProc, (LPARAM)&d) != IDOK)
        return FALSE;
    *uid = d.Uid;
    *gid = d.Gid;
    *setUid = d.SetUid;
    *setGid = d.SetGid;
    *recurse = d.Recurse;
    return TRUE;
}

// ---------------------------------------------------------------------------
// configuration
// ---------------------------------------------------------------------------

static INT_PTR CALLBACK ConfigProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    switch (msg)
    {
    case WM_INITDIALOG:
    {
        SetDlgItemInt(hwnd, IDE_CONNECTTIMEOUT, Config.ConnectTimeout, FALSE);
        SetDlgItemInt(hwnd, IDE_OPTIMEOUT, Config.OperationTimeout, FALSE);
        SetDlgItemInt(hwnd, IDE_KEEPALIVE, Config.KeepAliveSendEvery, FALSE);
        SetDlgItemInt(hwnd, IDE_KEEPALIVESTOP, Config.KeepAliveStopAfter, FALSE);
        SetDlgItemInt(hwnd, IDE_CONNRETRIES, Config.ConnectRetries, FALSE);
        SetDlgItemInt(hwnd, IDE_RETRYDELAY, Config.RetryDelay, FALSE);
        SetDlgItemInt(hwnd, IDE_RESUMEOVERLAP, Config.ResumeOverlap, FALSE);
        SetDlgItemInt(hwnd, IDE_RESUMEMINSIZE, Config.ResumeMinFileSize, FALSE);
        CheckRadioButton(hwnd, IDC_COLVIEW_RIGHTS, IDC_COLVIEW_ATTR,
                         Config.ColumnView == cvUnixRights ? IDC_COLVIEW_RIGHTS : IDC_COLVIEW_ATTR);
        CheckDlgButton(hwnd, IDC_SHOWOCTAL, Config.ShowOctal ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hwnd, IDC_ENABLELOG, Config.EnableLogging ? BST_CHECKED : BST_UNCHECKED);
        SetDlgItemInt(hwnd, IDE_LOGMAXSIZE, Config.LogMaxSize, FALSE);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        return TRUE;
    }
    case WM_COMMAND:
        if (LOWORD(wParam) == IDOK)
        {
            Config.ConnectTimeout = GetDlgItemInt(hwnd, IDE_CONNECTTIMEOUT, NULL, FALSE);
            Config.OperationTimeout = GetDlgItemInt(hwnd, IDE_OPTIMEOUT, NULL, FALSE);
            Config.KeepAliveSendEvery = GetDlgItemInt(hwnd, IDE_KEEPALIVE, NULL, FALSE);
            Config.KeepAliveStopAfter = GetDlgItemInt(hwnd, IDE_KEEPALIVESTOP, NULL, FALSE);
            Config.ConnectRetries = GetDlgItemInt(hwnd, IDE_CONNRETRIES, NULL, FALSE);
            Config.RetryDelay = GetDlgItemInt(hwnd, IDE_RETRYDELAY, NULL, FALSE);
            Config.ResumeOverlap = GetDlgItemInt(hwnd, IDE_RESUMEOVERLAP, NULL, FALSE);
            Config.ResumeMinFileSize = GetDlgItemInt(hwnd, IDE_RESUMEMINSIZE, NULL, FALSE);
            Config.ColumnView = IsDlgButtonChecked(hwnd, IDC_COLVIEW_RIGHTS) ? cvUnixRights : cvAttributes;
            Config.ShowOctal = IsDlgButtonChecked(hwnd, IDC_SHOWOCTAL);
            Config.EnableLogging = IsDlgButtonChecked(hwnd, IDC_ENABLELOG);
            Config.LogMaxSize = GetDlgItemInt(hwnd, IDE_LOGMAXSIZE, NULL, FALSE);
            EndDialog(hwnd, IDOK);
            return TRUE;
        }
        if (LOWORD(wParam) == IDCANCEL)
        {
            EndDialog(hwnd, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

void ShowConfigDialog(HWND parent)
{
    DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_CONFIG), parent, ConfigProc, 0);
}

// ---------------------------------------------------------------------------
// connect / bookmarks
// ---------------------------------------------------------------------------

struct CConnectData
{
    BOOL OrganizeMode;
    CSFTPServer* Result;
    HWND Hwnd;
    // feature 017: password/passphrase edit "dirty" tracking. When an entry has a
    // stored secret, the field shows a fixed-length placeholder (so it is visibly
    // non-empty without revealing the real length); the secret is only re-read as
    // a NEW password when the user actually edits the field (Dirty == TRUE).
    BOOL PwdDirty;
    BOOL PassDirty;
    BOOL SuppressDirty; // TRUE while loading fields programmatically (ignore EN_CHANGE)
};

// feature 017: fixed-length mask shown when a password/passphrase is stored but
// not revealed. Its length is constant (does NOT match the real secret length)
// and its content is never used as a password (guarded by the Dirty flag and an
// explicit content check). Eight chars -> eight bullets in the ES_PASSWORD box.
#define SFTP_SECRET_PLACEHOLDER "********"

static int ConnectSelectedItemData(HWND hwnd); // defined with the bookmark-list helpers

// The auth method decides which credential controls apply. feature 053 adds a
// second condition for the two save-secret options: only a bookmark can store a
// secret, so they stay disabled while the transient quick-connect row is selected.
// Every enable rule for these controls lives here, because the auth radio buttons
// re-run this function and would otherwise undo a rule applied elsewhere.
static void ConnectSetAuthMode(HWND hwnd, int authMethod)
{
    BOOL pwd = (authMethod == saPassword);
    BOOL canSaveSecrets = (ConnectSelectedItemData(hwnd) >= 0); // >= 0 == a bookmark
    EnableWindow(GetDlgItem(hwnd, IDE_PASSWORD), pwd);
    EnableWindow(GetDlgItem(hwnd, IDC_SAVEPASSWORD), pwd && canSaveSecrets);
    EnableWindow(GetDlgItem(hwnd, IDE_KEYFILE), !pwd);
    EnableWindow(GetDlgItem(hwnd, IDB_BROWSEKEY), !pwd);
    EnableWindow(GetDlgItem(hwnd, IDE_PASSPHRASE), !pwd);
    EnableWindow(GetDlgItem(hwnd, IDC_SAVEPASSPHRASE), !pwd && canSaveSecrets);
}

static void ConnectLoadServerToFields(HWND hwnd, const CSFTPServer* s)
{
    CConnectData* d = (CConnectData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);
    if (d != NULL)
        d->SuppressDirty = TRUE; // programmatic fill: do not mark the fields dirty
    SetDlgItemTextU8(hwnd, IDE_HOSTADDRESS, s->Address != NULL ? s->Address : "");
    SetDlgItemInt(hwnd, IDE_PORT, s->Port > 0 ? s->Port : SFTP_DEFAULT_PORT, FALSE);
    SetDlgItemTextU8(hwnd, IDE_USERNAME, s->UserName != NULL ? s->UserName : "");
    CheckRadioButton(hwnd, IDC_AUTHPASSWORD, IDC_AUTHKEY,
                     s->AuthMethod == saPrivateKey ? IDC_AUTHKEY : IDC_AUTHPASSWORD);
    // feature 017: show a fixed-length placeholder when a secret is stored, so
    // it is visibly non-empty without leaking the real length
    SetDlgItemTextA(hwnd, IDE_PASSWORD,
                    (s->SavePassword && s->EncryptedPassword != NULL) ? SFTP_SECRET_PLACEHOLDER : "");
    CheckDlgButton(hwnd, IDC_SAVEPASSWORD, s->SavePassword ? BST_CHECKED : BST_UNCHECKED);
    SetDlgItemTextU8(hwnd, IDE_KEYFILE, s->KeyFile != NULL ? s->KeyFile : "");
    SetDlgItemTextA(hwnd, IDE_PASSPHRASE,
                    (s->SavePassphrase && s->EncryptedPassphrase != NULL) ? SFTP_SECRET_PLACEHOLDER : "");
    CheckDlgButton(hwnd, IDC_SAVEPASSPHRASE, s->SavePassphrase ? BST_CHECKED : BST_UNCHECKED);
    SetDlgItemTextU8(hwnd, IDE_INITIALPATH, s->InitialPath != NULL ? s->InitialPath : "");
    ConnectSetAuthMode(hwnd, s->AuthMethod);
    if (d != NULL)
    {
        d->PwdDirty = FALSE;
        d->PassDirty = FALSE;
        d->SuppressDirty = FALSE;
    }
}

// reads dialog fields into 's'; encrypts typed secrets. When 'forConnect', also
// copies the plaintext into ConnectPlainPassword/Passphrase for the immediate
// connect (so a New/Rename-bookmark action never leaves a stale password that a
// later connect to a different server could pick up).
static BOOL ConnectReadFields(HWND hwnd, CSFTPServer* s, const CSFTPServer* selectedBookmark, BOOL forConnect)
{
    char host[256], user[256], keyfile[MAX_PATH], initpath[1024];
    GetDlgItemTextU8(hwnd, IDE_HOSTADDRESS, host, sizeof(host));
    GetDlgItemTextU8(hwnd, IDE_USERNAME, user, sizeof(user));
    GetDlgItemTextU8(hwnd, IDE_KEYFILE, keyfile, sizeof(keyfile));
    GetDlgItemTextU8(hwnd, IDE_INITIALPATH, initpath, sizeof(initpath));
    int port = GetDlgItemInt(hwnd, IDE_PORT, NULL, FALSE);
    // feature 053: a server address and a valid port are needed to CONNECT, not to
    // create or save a bookmark - a user may name an entry first and fill in the
    // details later (FR-006/FR-007). Off the connect path an empty or nonsense
    // port becomes the default instead of being stored as 0.
    if (forConnect)
    {
        if (host[0] == 0)
        {
            SalamanderGeneral->SalMessageBox(hwnd, LoadStr(IDS_HOSTNAMEMISSING),
                                             LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
            return FALSE;
        }
        if (port <= 0 || port > 65535)
        {
            SalamanderGeneral->SalMessageBox(hwnd, LoadStr(IDS_INVALIDPORT),
                                             LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
            return FALSE;
        }
    }
    else if (port <= 0 || port > 65535)
        port = SFTP_DEFAULT_PORT;

    int authMethod = IsDlgButtonChecked(hwnd, IDC_AUTHKEY) ? saPrivateKey : saPassword;
    // an empty field means "no value", the same way KeyFile and InitialPath below
    // are stored - otherwise an empty string in memory would come back as NULL
    // after a restart (the registry writer skips empty strings)
    s->Set(NULL, host[0] ? host : NULL, port, user[0] ? user : NULL);
    s->AuthMethod = authMethod;
    s->SetString(&s->KeyFile, keyfile[0] ? keyfile : NULL);
    s->SetString(&s->InitialPath, initpath[0] ? initpath : NULL);
    // feature 053: quick connect can never store a secret. The checkboxes are
    // disabled for it, but EnableWindow does not change what IsDlgButtonChecked
    // reports, so the flags are forced here as well - that is what keeps the
    // encryption branches below (and any master-password prompt) from running.
    BOOL canSaveSecrets = (ConnectSelectedItemData(hwnd) >= 0); // >= 0 == a bookmark
    s->SavePassword = canSaveSecrets && IsDlgButtonChecked(hwnd, IDC_SAVEPASSWORD);
    s->SavePassphrase = canSaveSecrets && IsDlgButtonChecked(hwnd, IDC_SAVEPASSPHRASE);

    if (forConnect)
    {
        ConnectPlainPassword[0] = 0;
        ConnectPlainPassphrase[0] = 0;
    }

    CSalamanderPasswordManagerAbstract* pm = SalamanderGeneral->GetSalamanderPasswordManager();
    // feature 017: a field is a NEWLY typed secret only if the user actually
    // edited it (Dirty) and it is not the stored-secret placeholder. Otherwise
    // the stored blob is kept/reused (see the 'else if' branches below).
    CConnectData* dd = (CConnectData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);

    if (authMethod == saPassword)
    {
        char pwd[SFTP_SECRET_BUF];
        GetDlgItemSecretU8(hwnd, IDE_PASSWORD, pwd, sizeof(pwd));
        // "typed" iff the user actually edited the field (Dirty). When not dirty
        // the field holds either nothing or the fixed placeholder for a stored
        // secret - both mean "keep/reuse the existing blob", never a new password.
        // Never treat the stored-secret placeholder as a newly typed password,
        // even if the field was made dirty (caret moved past the select-all) or
        // the dialog data is missing - otherwise "********" would overwrite the
        // saved blob or be sent to the server (CF-11).
        BOOL pwdTyped = (pwd[0] != 0) && strcmp(pwd, SFTP_SECRET_PLACEHOLDER) != 0 &&
                        (dd == NULL || dd->PwdDirty);
        if (pwdTyped)
        {
            if (forConnect)
                lstrcpynA(ConnectPlainPassword, pwd, sizeof(ConnectPlainPassword));
            // feature 085 (F7): with a Master Password in use but not entered, a
            // cancelled (or failed) prompt used to save the password anyway - only
            // scrambled, the weaker form the user chose a Master Password to avoid.
            // Now it is not saved at all and "Save password" is cleared, as the FTP
            // plugin has always done; the connection still uses ConnectPlainPassword.
            if (s->SavePassword && pm != NULL && pm->IsUsingMasterPassword() &&
                !pm->IsMasterPasswordSet() && !pm->AskForMasterPassword(hwnd))
            {
                s->SavePassword = FALSE;
                CheckDlgButton(hwnd, IDC_SAVEPASSWORD, BST_UNCHECKED);
            }
            if (s->SavePassword && pm != NULL)
            {
                BOOL enc = pm->IsUsingMasterPassword() && pm->IsMasterPasswordSet();
                BYTE* blob = NULL;
                int blobSize = 0;
                if (pm->EncryptPassword(pwd, &blob, &blobSize, enc) && blob != NULL)
                {
                    s->SetBlob(&s->EncryptedPassword, &s->EncryptedPasswordSize, blob, blobSize);
                    SalamanderGeneral->Free(blob);
                }
            }
            SecureZeroMemory(pwd, sizeof(pwd));
        }
        else if (s->SavePassword && selectedBookmark != NULL && selectedBookmark->SavePassword &&
                 selectedBookmark->EncryptedPassword != NULL)
        {
            // feature 017: reuse the stored blob when the password field is left
            // blank AND "Save password" is still on. Gating on s->SavePassword
            // (the current checkbox) means unchecking it clears the saved secret
            // (FR-007) instead of silently keeping it.
            s->SetBlob(&s->EncryptedPassword, &s->EncryptedPasswordSize,
                       selectedBookmark->EncryptedPassword, selectedBookmark->EncryptedPasswordSize);
        }
    }
    else // key
    {
        char pass[SFTP_SECRET_BUF];
        GetDlgItemSecretU8(hwnd, IDE_PASSPHRASE, pass, sizeof(pass));
        BOOL passTyped = (pass[0] != 0) && strcmp(pass, SFTP_SECRET_PLACEHOLDER) != 0 &&
                         (dd == NULL || dd->PassDirty);
        if (passTyped)
        {
            if (forConnect)
                lstrcpynA(ConnectPlainPassphrase, pass, sizeof(ConnectPlainPassphrase));
            // feature 085 (F7): the same rule for the key passphrase
            if (s->SavePassphrase && pm != NULL && pm->IsUsingMasterPassword() &&
                !pm->IsMasterPasswordSet() && !pm->AskForMasterPassword(hwnd))
            {
                s->SavePassphrase = FALSE;
                CheckDlgButton(hwnd, IDC_SAVEPASSPHRASE, BST_UNCHECKED);
            }
            if (s->SavePassphrase && pm != NULL)
            {
                BOOL enc = pm->IsUsingMasterPassword() && pm->IsMasterPasswordSet();
                BYTE* blob = NULL;
                int blobSize = 0;
                if (pm->EncryptPassword(pass, &blob, &blobSize, enc) && blob != NULL)
                {
                    s->SetBlob(&s->EncryptedPassphrase, &s->EncryptedPassphraseSize, blob, blobSize);
                    SalamanderGeneral->Free(blob);
                }
            }
            SecureZeroMemory(pass, sizeof(pass));
        }
        else if (s->SavePassphrase && selectedBookmark != NULL && selectedBookmark->SavePassphrase &&
                 selectedBookmark->EncryptedPassphrase != NULL)
        {
            // feature 017: mirror the password reuse/clear rule for the passphrase
            s->SetBlob(&s->EncryptedPassphrase, &s->EncryptedPassphraseSize,
                       selectedBookmark->EncryptedPassphrase, selectedBookmark->EncryptedPassphraseSize);
        }
    }
    return TRUE;
}

// feature 017: item-data convention for the bookmark list.
//   QC_ITEM (-1) = the "Quick Connect" pseudo-row; >= 0 = index into Config.Bookmarks.
#define QC_ITEM (-1)

static void ConnectFillBookmarkList(HWND hwnd)
{
    HWND lb = GetDlgItem(hwnd, IDL_BOOKMARKS);
    SendMessage(lb, LB_RESETCONTENT, 0, 0);
    // feature 017 (U3): a visible "Quick Connect" row makes the scratch entry an
    // explicit, selectable target instead of an invisible "no selection" mode
    int qc = ListBoxAddStringU8(lb, LoadStr(IDS_QUICKCONNECT));
    SendMessage(lb, LB_SETITEMDATA, qc, (LPARAM)QC_ITEM);
    for (int i = 0; i < Config.Bookmarks.Count; i++)
    {
        CSFTPServer* s = Config.Bookmarks[i];
        // feature 053: a bookmark may legitimately have no address, so the fallback
        // checks for a non-empty one - otherwise such an entry would draw a blank row
        const char* name = (s->ItemName != NULL && s->ItemName[0]) ? s->ItemName
                                                                   : ((s->Address != NULL && s->Address[0]) ? s->Address : "(unnamed)");
        int idx = ListBoxAddStringU8(lb, name);
        SendMessage(lb, LB_SETITEMDATA, idx, i);
    }
}

// feature 017: the entry currently selected in the list. Returns the
// Config.Bookmarks index (>= 0), QC_ITEM for Quick Connect, or LB_ERR for none.
static int ConnectSelectedItemData(HWND hwnd)
{
    HWND lb = GetDlgItem(hwnd, IDL_BOOKMARKS);
    int sel = (int)SendMessage(lb, LB_GETCURSEL, 0, 0);
    if (sel == LB_ERR)
        return LB_ERR;
    return (int)SendMessage(lb, LB_GETITEMDATA, sel, 0);
}

// feature 017: resolve the item data to the persistent entry it edits.
static CSFTPServer* ConnectEntryForItemData(int itemData)
{
    if (itemData == QC_ITEM)
        return &Config.QuickConnect;
    if (itemData >= 0 && itemData < Config.Bookmarks.Count)
        return Config.Bookmarks[itemData];
    return NULL;
}

// feature 017 (P3/U1): commit the current dialog fields into a persistent entry,
// preserving its bookmark name (ConnectReadFields nulls ItemName via Set). The
// entry's own stored blob is offered as the reuse fallback so an unchanged
// password field keeps the saved secret. Returns FALSE on validation error.
static BOOL ConnectCommitToEntry(HWND hwnd, CSFTPServer* entry, BOOL forConnect)
{
    CSFTPServer tmp; // separate object: avoids self-aliasing in SetBlob reuse
    if (!ConnectReadFields(hwnd, &tmp, entry, forConnect))
        return FALSE;
    char* savedName = (entry->ItemName != NULL) ? _strdup(entry->ItemName) : NULL;
    BOOL ok = entry->CopyFrom(&tmp);
    entry->SetString(&entry->ItemName, savedName); // restore name (CopyFrom took tmp's NULL)
    if (savedName != NULL)
        free(savedName);
    return ok;
}

// feature 017: select the list row whose item data matches (falls back to the
// Quick Connect row at index 0).
static void ConnectSelectItemData(HWND hwnd, int itemData)
{
    HWND lb = GetDlgItem(hwnd, IDL_BOOKMARKS);
    int n = (int)SendMessage(lb, LB_GETCOUNT, 0, 0);
    for (int i = 0; i < n; i++)
        if ((int)SendMessage(lb, LB_GETITEMDATA, i, 0) == itemData)
        {
            SendMessage(lb, LB_SETCURSEL, i, 0);
            return;
        }
    SendMessage(lb, LB_SETCURSEL, 0, 0);
}

// feature 017 (U4): Rename/Delete apply to real bookmarks only; Quick Connect
// cannot be renamed or removed.
// feature 053: Save and the two save-secret options are bookmark-only too - quick
// connect is transient, so there is nothing to save into and no secret may be
// stored. This runs after the list selection is set, which is why the enable rules
// live here and not in ConnectLoadServerToFields (at WM_INITDIALOG the fields are
// loaded before the row is selected).
// feature 056: Duplicate (IDB_COPYBOOKMARK) is bookmark-only as well. It copies an
// entry's STORED blob, but feature 053 made Quick Connect transient and empty for
// the dialog's whole lifetime, so duplicating the QC row produced an empty bookmark
// and silently discarded whatever the user had typed. "New" is the path that turns
// the current fields into a bookmark; Duplicate needs a real stored entry.
static void ConnectUpdateButtons(HWND hwnd)
{
    int data = ConnectSelectedItemData(hwnd);
    BOOL isBookmark = (data >= 0);
    EnableWindow(GetDlgItem(hwnd, IDB_RENAMEBOOKMARK), isBookmark);
    EnableWindow(GetDlgItem(hwnd, IDB_REMOVEBOOKMARK), isBookmark);
    EnableWindow(GetDlgItem(hwnd, IDB_COPYBOOKMARK), isBookmark);
    EnableWindow(GetDlgItem(hwnd, IDB_SAVEBOOKMARK), isBookmark);
    if (!isBookmark)
    {
        // uncheck as well as disable: IsDlgButtonChecked ignores EnableWindow, so a
        // greyed-out box would still report whatever a bookmark left checked
        CheckDlgButton(hwnd, IDC_SAVEPASSWORD, BST_UNCHECKED);
        CheckDlgButton(hwnd, IDC_SAVEPASSPHRASE, BST_UNCHECKED);
    }
    // re-apply the enable rules now that the selection is known
    ConnectSetAuthMode(hwnd, IsDlgButtonChecked(hwnd, IDC_AUTHKEY) ? saPrivateKey : saPassword);
}

// feature 054: size the label column from the language that is actually loaded.
//
// The template can only carry one width, so feature 053 had to size this column
// for the longest translation of ALL shipped languages - which left every other
// language with a wide empty band between its labels and the fields. The right
// width is only knowable at run time (it depends on the language, the dialog
// font and the DPI), so it is measured here: the widest label wins, plus a small
// margin, and the field column and the dialog follow. Fields keep their width -
// the dialog grows or shrinks instead, so nothing is ever clipped or squeezed.
//
// This is the only run-time relayout in the plugin; keep it here rather than
// generalising it, and keep it to the one column it is about.
static void ConnectFitLabelColumn(HWND hwnd)
{
    // the labels of the right-hand column, in the order they appear
    static const int labelIDs[] = {IDT_HOSTADDRESS, IDT_USERNAME, IDT_PASSWORD,
                                   IDT_KEYFILE, IDT_PASSPHRASE, IDT_INITIALPATH};
    // everything that starts at the field column and must move with it
    static const int fieldIDs[] = {IDE_HOSTADDRESS, IDE_USERNAME, IDC_AUTHPASSWORD,
                                   IDC_AUTHKEY, IDE_PASSWORD, IDC_SAVEPASSWORD,
                                   IDE_KEYFILE, IDB_BROWSEKEY, IDE_PASSPHRASE,
                                   IDC_SAVEPASSPHRASE, IDE_INITIALPATH};
    const int paddingPx = 12; // breathing room between a label and its field

    HWND firstLabel = GetDlgItem(hwnd, labelIDs[0]);
    HWND firstField = GetDlgItem(hwnd, fieldIDs[0]);
    if (firstLabel == NULL || firstField == NULL)
        return;

    // Measure through a LABEL's own DC with a LABEL's own font. Measuring on the
    // dialog's DC gave the stock system font's metrics - noticeably narrower than
    // "MS Shell Dlg" at this size - and every label came out too small to hold its
    // own text.
    HFONT font = (HFONT)SendMessage(firstLabel, WM_GETFONT, 0, 0);
    if (font == NULL)
        font = (HFONT)SendMessage(hwnd, WM_GETFONT, 0, 0);
    HDC dc = GetDC(firstLabel);
    if (dc == NULL)
        return;
    HFONT oldFont = font != NULL ? (HFONT)SelectObject(dc, font) : NULL;

    int widest = 0;
    for (int i = 0; i < (int)(sizeof(labelIDs) / sizeof(labelIDs[0])); i++)
    {
        WCHAR text[256];
        int len = GetDlgItemTextW(hwnd, labelIDs[i], text, (int)(sizeof(text) / sizeof(text[0])));
        if (len <= 0)
            continue;
        // '&' marks the accelerator and is not drawn ("&&" draws as one '&'), so
        // measuring the raw text would over-estimate every label by one character
        WCHAR drawn[256];
        int drawnLen = 0;
        for (int c = 0; c < len; c++)
        {
            if (text[c] == L'&')
            {
                if (c + 1 < len && text[c + 1] == L'&')
                    drawn[drawnLen++] = L'&', c++; // "&&" is a literal ampersand
                continue;
            }
            drawn[drawnLen++] = text[c];
        }
        SIZE sz;
        if (GetTextExtentPoint32W(dc, drawn, drawnLen, &sz) && sz.cx > widest)
            widest = sz.cx;
    }
    if (oldFont != NULL)
        SelectObject(dc, oldFont);
    ReleaseDC(firstLabel, dc);
    if (widest <= 0)
        return;

    // where the labels start and where the fields start today, in client pixels
    RECT rc;
    POINT labelLeft, fieldLeft;
    GetWindowRect(firstLabel, &rc);
    labelLeft.x = rc.left;
    labelLeft.y = rc.top;
    ScreenToClient(hwnd, &labelLeft);
    GetWindowRect(firstField, &rc);
    fieldLeft.x = rc.left;
    fieldLeft.y = rc.top;
    ScreenToClient(hwnd, &fieldLeft);

    int wantedFieldLeft = labelLeft.x + widest + paddingPx;
    int delta = wantedFieldLeft - fieldLeft.x; // negative shrinks, positive grows
    if (delta == 0)
        return;

    // never let the dialog grow past the work area: clamp instead, which at worst
    // leaves the current (already non-clipping) layout
    if (delta > 0)
    {
        RECT dlgRc;
        GetWindowRect(hwnd, &dlgRc);
        RECT work;
        SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0);
        int room = (work.right - work.left) - (dlgRc.right - dlgRc.left);
        if (delta > room)
            delta = room > 0 ? room : 0;
        if (delta == 0)
            return;
    }

    HDWP dwp = BeginDeferWindowPos(
        (int)(sizeof(labelIDs) / sizeof(labelIDs[0]) + sizeof(fieldIDs) / sizeof(fieldIDs[0])));
    // widen every label to the measured width so the column stays aligned
    for (int i = 0; i < (int)(sizeof(labelIDs) / sizeof(labelIDs[0])); i++)
    {
        HWND w = GetDlgItem(hwnd, labelIDs[i]);
        if (w == NULL)
            continue;
        RECT r;
        GetWindowRect(w, &r);
        POINT pt = {r.left, r.top};
        ScreenToClient(hwnd, &pt);
        if (dwp != NULL)
            dwp = DeferWindowPos(dwp, w, NULL, pt.x, pt.y, widest, r.bottom - r.top,
                                 SWP_NOZORDER | SWP_NOACTIVATE);
    }
    // move the field column, keeping every field's width
    for (int i = 0; i < (int)(sizeof(fieldIDs) / sizeof(fieldIDs[0])); i++)
    {
        HWND w = GetDlgItem(hwnd, fieldIDs[i]);
        if (w == NULL)
            continue;
        RECT r;
        GetWindowRect(w, &r);
        POINT pt = {r.left, r.top};
        ScreenToClient(hwnd, &pt);
        if (dwp != NULL)
            dwp = DeferWindowPos(dwp, w, NULL, pt.x + delta, pt.y, r.right - r.left,
                                 r.bottom - r.top, SWP_NOZORDER | SWP_NOACTIVATE);
    }
    if (dwp != NULL)
        EndDeferWindowPos(dwp);

    // the port label/field pair and the bottom buttons sit to the right of the
    // field column, so they move with it too
    static const int trailingIDs[] = {IDT_PORT, IDE_PORT, IDB_CONNECT, IDB_SAVEBOOKMARK, IDCANCEL};
    for (int i = 0; i < (int)(sizeof(trailingIDs) / sizeof(trailingIDs[0])); i++)
    {
        HWND w = GetDlgItem(hwnd, trailingIDs[i]);
        if (w == NULL)
            continue;
        RECT r;
        GetWindowRect(w, &r);
        POINT pt = {r.left, r.top};
        ScreenToClient(hwnd, &pt);
        SetWindowPos(w, NULL, pt.x + delta, pt.y, 0, 0,
                     SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    }

    // finally resize the dialog by the same amount and re-centre it
    RECT dlgRc;
    GetWindowRect(hwnd, &dlgRc);
    SetWindowPos(hwnd, NULL, 0, 0, (dlgRc.right - dlgRc.left) + delta,
                 dlgRc.bottom - dlgRc.top, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
}

static void BrowseForKey(HWND hwnd)
{
    // the key-file path is UTF-8 (interface 104) -> use the W common dialog (feature 010)
    char u8file[MAX_PATH];
    WCHAR file[MAX_PATH];
    GetDlgItemTextU8(hwnd, IDE_KEYFILE, u8file, sizeof(u8file));
    if (SplU8ToW(u8file, file, MAX_PATH) == 0)
        file[0] = 0;
    OPENFILENAMEW ofn;
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = hwnd;
    ofn.lpstrFilter = L"All files\0*.*\0Private keys\0*.pem;*.ppk;*.key;id_*\0";
    ofn.lpstrFile = file;
    ofn.nMaxFile = MAX_PATH;
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_HIDEREADONLY;
    if (GetOpenFileNameW(&ofn))
        SetDlgItemTextW(hwnd, IDE_KEYFILE, file);
}

static INT_PTR CALLBACK ConnectProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    CConnectData* d = (CConnectData*)GetWindowLongPtr(hwnd, GWLP_USERDATA);
    switch (msg)
    {
    case WM_INITDIALOG:
    {
        d = (CConnectData*)lParam;
        SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)d);
        d->Hwnd = hwnd;
        // feature 094: see SFTP_SECRET_MAX_CHARS
        SendDlgItemMessage(hwnd, IDE_PASSWORD, EM_LIMITTEXT, SFTP_SECRET_MAX_CHARS, 0);
        SendDlgItemMessage(hwnd, IDE_PASSPHRASE, EM_LIMITTEXT, SFTP_SECRET_MAX_CHARS, 0);
        // feature 053: quick connect is transient - it must not carry anything over
        // from a previous dialog session. Reset() (not Clear()) is required: Clear()
        // would leave the last port, auth method and save-secret flags behind.
        Config.QuickConnect.Reset();
        ConnectFillBookmarkList(hwnd);
        if (d->OrganizeMode)
        {
            SetWindowTextA(hwnd, LoadStr(IDS_MENU_ORGANIZEBOOKMARKS));
            SetDlgItemTextA(hwnd, IDB_CONNECT, "Close");
        }
        // feature 017 (U3): seed from the last-used entry and select its row.
        // Quick Connect is item 0; a saved bookmark selects its own row.
        if (Config.LastBookmark > 0 && Config.LastBookmark <= Config.Bookmarks.Count)
        {
            int bi = Config.LastBookmark - 1;
            ConnectLoadServerToFields(hwnd, Config.Bookmarks[bi]);
            ConnectSelectItemData(hwnd, bi);
        }
        else
        {
            ConnectLoadServerToFields(hwnd, &Config.QuickConnect);
            ConnectSelectItemData(hwnd, QC_ITEM);
        }
        ConnectUpdateButtons(hwnd);
        // feature 054: fit the label column to this language's texts. Runs last,
        // after every control carries its final text, and re-centres the dialog
        // itself - so the MultiMonCenterWindow below is only for the case where
        // the layout needs no adjustment at all.
        ConnectFitLabelColumn(hwnd);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        return TRUE;
    }
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDC_AUTHPASSWORD:
            ConnectSetAuthMode(hwnd, saPassword);
            return TRUE;
        case IDC_AUTHKEY:
            ConnectSetAuthMode(hwnd, saPrivateKey);
            return TRUE;
        case IDB_BROWSEKEY:
            BrowseForKey(hwnd);
            return TRUE;
        case IDE_PASSWORD:
            // feature 017: track real edits vs the stored-secret placeholder
            if (HIWORD(wParam) == EN_CHANGE)
            {
                if (d != NULL && !d->SuppressDirty)
                    d->PwdDirty = TRUE;
            }
            else if (HIWORD(wParam) == EN_SETFOCUS)
            {
                if (d != NULL && !d->PwdDirty) // select the placeholder so the first keystroke replaces it
                    SendMessage((HWND)lParam, EM_SETSEL, 0, -1);
            }
            return TRUE;
        case IDE_PASSPHRASE:
            if (HIWORD(wParam) == EN_CHANGE)
            {
                if (d != NULL && !d->SuppressDirty)
                    d->PassDirty = TRUE;
            }
            else if (HIWORD(wParam) == EN_SETFOCUS)
            {
                if (d != NULL && !d->PassDirty)
                    SendMessage((HWND)lParam, EM_SETSEL, 0, -1);
            }
            return TRUE;
        case IDL_BOOKMARKS:
            if (HIWORD(wParam) == LBN_SELCHANGE)
            {
                // feature 017: load the selected entry (Quick Connect or a
                // bookmark) into the fields and update which buttons apply
                int data = ConnectSelectedItemData(hwnd);
                CSFTPServer* entry = ConnectEntryForItemData(data);
                if (entry != NULL)
                    ConnectLoadServerToFields(hwnd, entry);
                ConnectUpdateButtons(hwnd);
            }
            else if (HIWORD(wParam) == LBN_DBLCLK)
            {
                // feature 017 (U5): double-click a row = Connect
                if (!d->OrganizeMode)
                    SendMessage(hwnd, WM_COMMAND, MAKEWPARAM(IDB_CONNECT, 0), 0);
            }
            return TRUE;
        case IDB_NEWBOOKMARK:
        {
            // feature 017: "Save as new bookmark" - snapshot the current fields
            // (incl. a just-typed+encrypted password) under a new name
            char name[MAX_PATH] = "";
            if (ShowRenameDialog(hwnd, LoadStr(IDS_BOOKMARKNAME), name) && name[0] != 0)
            {
                CSFTPServer* s = new CSFTPServer;
                if (s != NULL && ConnectReadFields(hwnd, s, NULL, FALSE)) // new bookmark: don't touch connect globals
                {
                    s->SetString(&s->ItemName, name);
                    Config.Bookmarks.Add(s);
                    ConnectFillBookmarkList(hwnd);
                    ConnectSelectItemData(hwnd, Config.Bookmarks.Count - 1);
                    ConnectUpdateButtons(hwnd);
                }
                else
                    delete s;
            }
            return TRUE;
        }
        case IDB_COPYBOOKMARK:
        {
            // feature 017 (U2): Duplicate - copy the selected entry's STORED data
            // (not the possibly-edited fields) into a new named bookmark. Wires
            // the previously dead IDB_COPYBOOKMARK control.
            int data = ConnectSelectedItemData(hwnd);
            CSFTPServer* src = ConnectEntryForItemData(data);
            if (src == NULL)
                return TRUE;
            char name[MAX_PATH];
            lstrcpynA(name, src->ItemName != NULL ? src->ItemName : (src->Address != NULL ? src->Address : ""), sizeof(name));
            if (ShowRenameDialog(hwnd, LoadStr(IDS_BOOKMARKNAME), name) && name[0] != 0)
            {
                CSFTPServer* s = new CSFTPServer;
                if (s != NULL && s->CopyFrom(src))
                {
                    s->SetString(&s->ItemName, name);
                    Config.Bookmarks.Add(s);
                    ConnectFillBookmarkList(hwnd);
                    ConnectSelectItemData(hwnd, Config.Bookmarks.Count - 1);
                    ConnectLoadServerToFields(hwnd, s);
                    ConnectUpdateButtons(hwnd);
                }
                else
                    delete s;
            }
            return TRUE;
        }
        case IDB_SAVEBOOKMARK:
        {
            // feature 017 (U1/P3): commit the current fields (incl. a typed and
            // encrypted password) into the selected entry - the explicit "save
            // edits back to this bookmark/quick-connect" action that was missing
            int data = ConnectSelectedItemData(hwnd);
            CSFTPServer* entry = ConnectEntryForItemData(data);
            if (entry != NULL && ConnectCommitToEntry(hwnd, entry, FALSE))
            {
                ConnectFillBookmarkList(hwnd);
                ConnectSelectItemData(hwnd, data);
                ConnectUpdateButtons(hwnd);
                SalamanderGeneral->SalMessageBox(hwnd, LoadStr(IDS_BOOKMARKSAVED),
                                                 LoadStr(IDS_SFTPPLUGINTITLE), MB_OK | MB_ICONINFORMATION);
            }
            return TRUE;
        }
        case IDB_RENAMEBOOKMARK:
        {
            int data = ConnectSelectedItemData(hwnd);
            if (data < 0)
                return TRUE; // Quick Connect cannot be renamed
            CSFTPServer* s = Config.Bookmarks[data];
            char name[MAX_PATH];
            lstrcpynA(name, s->ItemName != NULL ? s->ItemName : "", sizeof(name));
            if (ShowRenameDialog(hwnd, LoadStr(IDS_BOOKMARKNAME), name) && name[0] != 0)
            {
                s->SetString(&s->ItemName, name);
                ConnectFillBookmarkList(hwnd);
                ConnectSelectItemData(hwnd, data);
                ConnectUpdateButtons(hwnd);
            }
            return TRUE;
        }
        case IDB_REMOVEBOOKMARK:
        {
            // feature 017 (U4): confirm before deleting; Quick Connect is not removable
            int data = ConnectSelectedItemData(hwnd);
            if (data < 0)
                return TRUE;
            if (SalamanderGeneral->SalMessageBox(hwnd, LoadStr(IDS_CONFIRM_DELETEBOOKMARK),
                                                 LoadStr(IDS_CONFIRM_DELETE_TITLE),
                                                 MB_YESNO | MB_ICONQUESTION) != IDYES)
                return TRUE;
            Config.Bookmarks.Delete(data);
            if (Config.LastBookmark == data + 1)
                Config.LastBookmark = 0;
            else if (Config.LastBookmark > data + 1)
                Config.LastBookmark--;
            ConnectFillBookmarkList(hwnd);
            ConnectSelectItemData(hwnd, QC_ITEM);
            ConnectLoadServerToFields(hwnd, &Config.QuickConnect);
            ConnectUpdateButtons(hwnd);
            return TRUE;
        }
        case IDB_CONNECT: // also "Close" in organize mode
        {
            if (d->OrganizeMode)
            {
                EndDialog(hwnd, IDCANCEL);
                return TRUE;
            }
            // feature 017 (P2/P3): connect using the current fields AND persist
            // them onto the selected entry, so a save-password-on-connect sticks.
            int data = ConnectSelectedItemData(hwnd);
            CSFTPServer* entry = ConnectEntryForItemData(data);
            if (entry == NULL)
                entry = &Config.QuickConnect; // no selection -> quick connect
            if (ConnectCommitToEntry(hwnd, entry, TRUE) &&
                d->Result != NULL && d->Result->CopyFrom(entry))
            {
                // feature 053: remember the entry only once the fields validated -
                // a failed connect must not make an unusable entry the one the
                // dialog seeds next time
                Config.LastBookmark = (data >= 0) ? data + 1 : 0;
                // the request now lives in d->Result; quick connect keeps nothing
                if (data == QC_ITEM || entry == &Config.QuickConnect)
                    Config.QuickConnect.Reset();
                EndDialog(hwnd, IDOK);
            }
            return TRUE;
        }
        case IDCANCEL:
            EndDialog(hwnd, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

BOOL ShowConnectDialog(HWND parent, BOOL organizeMode, CSFTPServer* result)
{
    CConnectData d;
    d.OrganizeMode = organizeMode;
    d.Result = result;
    d.Hwnd = NULL;
    d.PwdDirty = FALSE;
    d.PassDirty = FALSE;
    d.SuppressDirty = FALSE;
    return DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_CONNECT), parent, ConnectProc, (LPARAM)&d) == IDOK;
}
