// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "sftp.h"
#include "logs.h"
#include "dialogs.h"

CLogs Logs;

CLogData::CLogData()
{
    UID = -1;
    Name = NULL;
    Text = NULL;
    TextLen = 0;
    TextAlloc = 0;
}

CLogData::~CLogData()
{
    if (Name != NULL)
        free(Name);
    if (Text != NULL)
        free(Text);
}

CLogs::CLogs() : Data(5, 5)
{
    InitializeCriticalSection(&Lock);
    NextUID = 0;
    LogsWindow = NULL;
}

CLogs::~CLogs()
{
    DeleteCriticalSection(&Lock);
}

BOOL CLogs::Enabled()
{
    return Config.EnableLogging;
}

int CLogs::CreateLog(const char* name)
{
    if (!Config.EnableLogging)
        return -1;

    EnterCriticalSection(&Lock);
    // feature 051 (U10): logs used to be created per connection and never
    // released, so a long-running session accumulated one log object (name plus
    // up to LogMaxSize of text) per connect and the Logs window filled with dead
    // entries. Keep the most recent ones and drop the oldest beyond the cap.
    const int MAX_KEPT_LOGS = 32;
    while (Data.Count >= MAX_KEPT_LOGS)
    {
        Data.Delete(0);
        if (!Data.IsGood())
        {
            Data.ResetState();
            break;
        }
    }
    CLogData* log = new CLogData;
    if (log == NULL)
    {
        LeaveCriticalSection(&Lock);
        return -1;
    }
    log->UID = NextUID++;
    log->Name = _strdup(name != NULL ? name : "");
    Data.Add(log);
    if (!Data.IsGood())
    {
        Data.ResetState();
        delete log;
        LeaveCriticalSection(&Lock);
        return -1;
    }
    int uid = log->UID;
    LeaveCriticalSection(&Lock);
    return uid;
}

CLogData* CLogs::FindByUID(int uid)
{
    for (int i = 0; i < Data.Count; i++)
        if (Data[i]->UID == uid)
            return Data[i];
    return NULL;
}

void CLogs::Append(int uid, const char* text)
{
    if (uid < 0 || text == NULL)
        return;

    // feature 130: the whole log is shown as ONE text (UTF-8 when valid, else through the code
    // page), so every line is stored as UTF-8 - a line that is not (a remote name in another
    // encoding) would turn all the others into garbage
    CSFTPMsgText lineU8(text);
    text = lineU8.Get();

    EnterCriticalSection(&Lock);
    CLogData* log = FindByUID(uid);
    if (log != NULL)
    {
        // prepend a wall-clock timestamp
        SYSTEMTIME st;
        GetLocalTime(&st);
        char line[600];
        int n = _snprintf_s(line, _TRUNCATE, "%02d:%02d:%02d  ", st.wHour, st.wMinute, st.wSecond);
        int textLen = (int)strlen(text);
        int need = n + textLen + 3;

        // cap the buffer to the configured max (KB); drop the oldest half if over
        int maxBytes = Config.LogMaxSize > 0 ? Config.LogMaxSize * 1024 : 256 * 1024;

        if (log->TextLen + need + 1 > log->TextAlloc)
        {
            int newAlloc = log->TextAlloc == 0 ? 4096 : log->TextAlloc * 2;
            while (newAlloc < log->TextLen + need + 1)
                newAlloc *= 2;
            char* nt = (char*)realloc(log->Text, newAlloc);
            if (nt != NULL)
            {
                log->Text = nt;
                log->TextAlloc = newAlloc;
            }
        }
        if (log->Text != NULL && log->TextLen + need + 1 <= log->TextAlloc)
        {
            memcpy(log->Text + log->TextLen, line, n);
            log->TextLen += n;
            memcpy(log->Text + log->TextLen, text, textLen);
            log->TextLen += textLen;
            log->Text[log->TextLen++] = '\r';
            log->Text[log->TextLen++] = '\n';
            log->Text[log->TextLen] = 0;

            if (log->TextLen > maxBytes && log->TextLen > 8192)
            {
                // trim oldest half to a line boundary
                int cut = log->TextLen / 2;
                char* nl = strchr(log->Text + cut, '\n');
                if (nl != NULL)
                    cut = (int)(nl - log->Text) + 1;
                memmove(log->Text, log->Text + cut, log->TextLen - cut + 1);
                log->TextLen -= cut;
            }
        }
    }
    LeaveCriticalSection(&Lock);

    // ask the logs window (if open) to refresh
    if (LogsWindow != NULL)
        PostMessage(LogsWindow, WM_APP + 1, uid, 0);
}

void CLogs::AppendFmt(int uid, const char* fmt, ...)
{
    if (uid < 0)
        return;
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    int written = _vsnprintf_s(buf, _TRUNCATE, fmt, args);
    va_end(args);
    if (written < 0)
        SplU8TrimTornTail(buf); // feature 130: a cut inside a character would make the line invalid
    Append(uid, buf);
}

void CLogs::ClearLog(int uid)
{
    EnterCriticalSection(&Lock);
    CLogData* log = FindByUID(uid);
    if (log != NULL && log->Text != NULL)
    {
        log->Text[0] = 0;
        log->TextLen = 0;
    }
    LeaveCriticalSection(&Lock);
    if (LogsWindow != NULL)
        PostMessage(LogsWindow, WM_APP + 1, uid, 0);
}

// ---------------------------------------------------------------------------
// Logs dialog (modal). Left: connection list; right: selected log text.
// ---------------------------------------------------------------------------

static void LogsFillConnections(HWND hwnd, int selectUID)
{
    HWND lb = GetDlgItem(hwnd, IDL_LOGCONNECTIONS);
    SendMessage(lb, LB_RESETCONTENT, 0, 0);
    Logs.Enter();
    int selectIndex = 0;
    for (int i = 0; i < Logs.GetCount(); i++)
    {
        CLogData* d = Logs.GetAt(i);
        int idx = ListBoxAddStringU8(lb, d->Name != NULL ? d->Name : "(log)"); // name is user@host (UTF-8)
        SendMessage(lb, LB_SETITEMDATA, idx, d->UID);
        if (d->UID == selectUID)
            selectIndex = idx;
    }
    Logs.Leave();
    if (Logs.GetCount() > 0)
        SendMessage(lb, LB_SETCURSEL, selectIndex, 0);
}

static void LogsShowSelected(HWND hwnd)
{
    HWND lb = GetDlgItem(hwnd, IDL_LOGCONNECTIONS);
    int sel = (int)SendMessage(lb, LB_GETCURSEL, 0, 0);
    if (sel == LB_ERR)
    {
        SetDlgItemTextA(hwnd, IDE_LOGTEXT, "");
        return;
    }
    int uid = (int)SendMessage(lb, LB_GETITEMDATA, sel, 0);
    Logs.Enter();
    CLogData* d = Logs.FindByUID(uid);
    const char* text = (d != NULL && d->Text != NULL) ? d->Text : "";
    SetDlgItemTextU8(hwnd, IDE_LOGTEXT, text); // log lines carry remote paths (UTF-8)
    Logs.Leave();
    // scroll to bottom
    HWND edit = GetDlgItem(hwnd, IDE_LOGTEXT);
    int len = GetWindowTextLengthW(edit); // EM_SETSEL indexes UTF-16 units (feature 010)
    SendMessage(edit, EM_SETSEL, len, len);
    SendMessage(edit, EM_SCROLLCARET, 0, 0);
}

static INT_PTR CALLBACK LogsProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (SFTPThemeDlgMsg(hwnd, msg, wParam, lParam, &themeResult))
        return themeResult;
    switch (msg)
    {
    case WM_INITDIALOG:
        Logs.RegisterWindow(hwnd);
        LogsFillConnections(hwnd, (int)lParam);
        LogsShowSelected(hwnd);
        SalamanderGeneral->MultiMonCenterWindow(hwnd, GetParent(hwnd), TRUE);
        return TRUE;
    case WM_APP + 1: // a log changed
        LogsShowSelected(hwnd);
        return TRUE;
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDL_LOGCONNECTIONS:
            if (HIWORD(wParam) == LBN_SELCHANGE)
                LogsShowSelected(hwnd);
            return TRUE;
        case IDB_LOGCLEAR:
        {
            HWND lb = GetDlgItem(hwnd, IDL_LOGCONNECTIONS);
            int sel = (int)SendMessage(lb, LB_GETCURSEL, 0, 0);
            if (sel != LB_ERR)
            {
                int uid = (int)SendMessage(lb, LB_GETITEMDATA, sel, 0);
                Logs.ClearLog(uid);
                LogsShowSelected(hwnd);
            }
            return TRUE;
        }
        case IDOK:
        case IDCANCEL:
            Logs.RegisterWindow(NULL);
            EndDialog(hwnd, IDOK);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

void ShowLogsDialog(HWND parent, int showUID)
{
    DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_LOGS), parent, LogsProc, (LPARAM)showUID);
}
