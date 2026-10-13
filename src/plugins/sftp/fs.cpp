// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "sftp.h"
#include "sftputils.h"
#include "session.h"
#include "hostkeys.h"
#include "listing.h"
#include "dialogs.h"
#include "operats.h"
#include "keyload.h"
#include "logs.h"
#include "fs.h"

CPluginInterfaceForFS InterfaceForFS;

// connection parameters staged by ConnectSFTPServer for the FS that the
// subsequent ChangePanelPathToPluginFS is about to open
static CSFTPConnectParams g_PendingParams;
static BOOL g_HasPending = FALSE;

// feature 131: the one refusal of this file - a remote path that does not fit its buffer is
// not acted upon in a shortened form (the shortened path names another file or directory)
static void ShowTooLongPath(HWND parent)
{
    SalamanderGeneral->SalMessageBox(parent, LoadStr(IDS_TOOLONGPATH), LoadStr(IDS_SFTPERRORTITLE),
                                     MB_OK | MB_ICONEXCLAMATION);
}

// ---------------------------------------------------------------------------
// secret decryption helper
// ---------------------------------------------------------------------------

static void DecryptInto(const BYTE* blob, int blobSize, char* out, int outSize)
{
    out[0] = 0;
    if (blob == NULL || blobSize == 0)
        return;
    CSalamanderPasswordManagerAbstract* pm = SalamanderGeneral->GetSalamanderPasswordManager();
    if (pm == NULL)
        return;
    if (pm->IsPasswordEncrypted(blob, blobSize) && !pm->IsMasterPasswordSet())
    {
        if (!pm->AskForMasterPassword(SalamanderGeneral->GetMainWindowHWND()))
            return;
    }
    char* plain = NULL;
    if (pm->DecryptPassword(blob, blobSize, &plain) && plain != NULL)
    {
        // CF-15: never use a silently truncated secret - a wrong password/
        // passphrase would be sent with no diagnostic. Fail closed (out stays
        // empty) so the caller prompts instead.
        if ((int)strlen(plain) < outSize)
            lstrcpynA(out, plain, outSize);
        else
            out[0] = 0;
        // wipe and free the plugin-manager buffer
        SecureZeroMemory(plain, strlen(plain));
        SalamanderGeneral->Free(plain);
    }
}

// fills connect params (incl. decrypted secrets) from a saved/quick server
static void FillParamsFromServer(const CSFTPServer* srv, CSFTPConnectParams* params)
{
    memset(params, 0, sizeof(*params));
    lstrcpynA(params->Host, srv->Address != NULL ? srv->Address : "", sizeof(params->Host));
    params->Port = srv->Port > 0 ? srv->Port : SFTP_DEFAULT_PORT;
    lstrcpynA(params->User, srv->UserName != NULL ? srv->UserName : "", sizeof(params->User));
    params->AuthMethod = srv->AuthMethod;
    if (srv->KeyFile != NULL)
        lstrcpynA(params->KeyFile, srv->KeyFile, sizeof(params->KeyFile));
    params->UseCompression = srv->UseCompression;
    params->ConnectTimeoutSec = Config.ConnectTimeout;
    params->OperationTimeoutSec = Config.OperationTimeout;
    params->KeepAliveSec = srv->KeepAliveSendEvery > 0 ? srv->KeepAliveSendEvery : Config.KeepAliveSendEvery;

    if (srv->AuthMethod == saPassword && srv->SavePassword)
        DecryptInto(srv->EncryptedPassword, srv->EncryptedPasswordSize, params->Password, sizeof(params->Password));
    if (srv->AuthMethod == saPrivateKey && srv->SavePassphrase)
        DecryptInto(srv->EncryptedPassphrase, srv->EncryptedPassphraseSize, params->Passphrase, sizeof(params->Passphrase));
}

// ---------------------------------------------------------------------------
// ConnectSFTPServer
// ---------------------------------------------------------------------------

void ConnectSFTPServer(HWND parent, int panel)
{
    CSFTPServer srv;
    if (!ShowConnectDialog(parent, FALSE, &srv))
    {
        // CF-14: the dialog may have staged plaintext secrets in these globals
        // before the user cancelled; never leave a decrypted secret in memory.
        SecureZeroMemory(ConnectPlainPassword, sizeof(ConnectPlainPassword));
        SecureZeroMemory(ConnectPlainPassphrase, sizeof(ConnectPlainPassphrase));
        g_PendingParams.WipeSecrets();
        return;
    }

    FillParamsFromServer(&srv, &g_PendingParams);

    // prefer the plaintext secret the dialog just captured (avoids re-prompting
    // when the user typed a password but did not store it)
    if (ConnectPlainPassword[0] != 0)
    {
        lstrcpynA(g_PendingParams.Password, ConnectPlainPassword, sizeof(g_PendingParams.Password));
        SecureZeroMemory(ConnectPlainPassword, sizeof(ConnectPlainPassword));
    }
    if (ConnectPlainPassphrase[0] != 0)
    {
        lstrcpynA(g_PendingParams.Passphrase, ConnectPlainPassphrase, sizeof(g_PendingParams.Passphrase));
        SecureZeroMemory(ConnectPlainPassphrase, sizeof(ConnectPlainPassphrase));
    }

    // prompt for the password now if still missing (password auth only)
    if (g_PendingParams.AuthMethod == saPassword && g_PendingParams.Password[0] == 0)
    {
        char prompt[512];
        _snprintf_s(prompt, _TRUNCATE, LoadStrU8(IDS_ENTERPASSWORD), g_PendingParams.User); // feature 130: UTF-8 like the user name
        SplU8TrimTornTail(prompt);
        if (!ShowPasswordPrompt(parent, prompt, g_PendingParams.Password, sizeof(g_PendingParams.Password)))
        {
            g_PendingParams.WipeSecrets(); // CF-14: do not leave the decrypted secret behind
            return;
        }
    }
    // CF-20: for key auth, prompt for the passphrase up front only when the key
    // is actually encrypted and none was saved, so an encrypted key no longer
    // fails with a cryptic "key could not be unlocked" (and unencrypted keys are
    // not prompted). A cancelled prompt just proceeds with no passphrase.
    else if (g_PendingParams.AuthMethod == saPrivateKey && g_PendingParams.Passphrase[0] == 0 &&
             g_PendingParams.KeyFile[0] != 0 && KeyFileLooksEncrypted(g_PendingParams.KeyFile))
    {
        char prompt[512];
        _snprintf_s(prompt, _TRUNCATE, LoadStrU8(IDS_ENTERPASSPHRASE), g_PendingParams.KeyFile);
        SplU8TrimTornTail(prompt);
        ShowPasswordPrompt(parent, prompt, g_PendingParams.Passphrase, sizeof(g_PendingParams.Passphrase));
    }
    g_HasPending = TRUE;

    char userPart[3072];
    const char* initPath = (srv.InitialPath != NULL && srv.InitialPath[0]) ? srv.InitialPath : "";
    // (user and host 255 bytes each, the initial path 1023: it always fits; feature 131 checks
    // it all the same - the core refuses a user part of MAX_PATH bytes or more by itself)
    if (_snprintf_s(userPart, _TRUNCATE, "%s@%s:%d%s%s",
                    g_PendingParams.User, g_PendingParams.Host, g_PendingParams.Port,
                    (initPath[0] && initPath[0] != '/') ? "/" : "", initPath) < 0)
    {
        ShowTooLongPath(parent);
        g_HasPending = FALSE;
        g_PendingParams.WipeSecrets();
        return;
    }

    SalamanderGeneral->ChangePanelPathToPluginFS(panel, AssignedFSName, userPart);
    g_HasPending = FALSE;
    g_PendingParams.WipeSecrets();
}

// ---------------------------------------------------------------------------
// CPluginInterfaceForFS
// ---------------------------------------------------------------------------

CPluginFSInterfaceAbstract* WINAPI CPluginInterfaceForFS::OpenFS(const char* fsName, int fsNameIndex)
{
    ActiveFSCount++;
    return new CPluginFSInterface;
}

void WINAPI CPluginInterfaceForFS::CloseFS(CPluginFSInterfaceAbstract* fs)
{
    if (fs != NULL)
    {
        ActiveFSCount--;
        delete (CPluginFSInterface*)fs;
    }
}

void WINAPI CPluginInterfaceForFS::ExecuteChangeDriveMenuItem(int panel)
{
    ConnectSFTPServer(SalamanderGeneral->GetMsgBoxParent(), panel);
}

BOOL WINAPI CPluginInterfaceForFS::ChangeDriveMenuItemContextMenu(HWND parent, int panel, int x, int y,
                                                                  CPluginFSInterfaceAbstract* pluginFS,
                                                                  const char* pluginFSName, int pluginFSNameIndex,
                                                                  BOOL isDetachedFS, BOOL& refreshMenu,
                                                                  BOOL& closeMenu, int& postCmd, void*& postCmdParam)
{
    closeMenu = FALSE;
    return FALSE;
}

void WINAPI CPluginInterfaceForFS::ExecuteChangeDrivePostCommand(int panel, int postCmd, void* postCmdParam)
{
}

void WINAPI CPluginInterfaceForFS::ExecuteOnFS(int panel, CPluginFSInterfaceAbstract* pluginFS,
                                               const char* pluginFSName, int pluginFSNameIndex,
                                               CFileData& file, int isDir)
{
    CPluginFSInterface* fs = (CPluginFSInterface*)pluginFS;
    if (isDir) // directory or up-dir: change path
    {
        if (isDir == 2) // up-dir: cut the last path component
        {
            char cur[3072];
            if (!fs->GetCurrentPathFull(cur, sizeof(cur))) // CF-7: no MAX_PATH truncation
            {
                ShowTooLongPath(SalamanderGeneral->GetMsgBoxParent()); // feature 131: nor any other
                return;
            }
            // strip a trailing slash (only the root user-part "user@host:port/" has one)
            int curLen = (int)strlen(cur);
            if (curLen > 0 && cur[curLen - 1] == '/')
                cur[curLen - 1] = 0;
            char* firstSlash = strchr(cur, '/'); // root slash (the host part has none)
            char* lastSlash = strrchr(cur, '/');
            if (lastSlash != NULL)
            {
                // Remember the sub-directory we are leaving and pass it as the
                // focus name, so the cursor lands on it in the parent instead of
                // the first item - consistent with disk paths and the FTP plugin.
                // Both Enter on ".." and Backspace route here (Execute(0) on "..").
                char focusName[MAX_PATH];
                if (strlen(lastSlash + 1) < sizeof(focusName))
                    lstrcpynA(focusName, lastSlash + 1, sizeof(focusName));
                else
                    focusName[0] = 0; // feature 131: no focus rather than the focus of a cut name
                if (lastSlash == firstSlash)
                    *(lastSlash + 1) = 0; // parent is root: keep "user@host:port/"
                else
                    *lastSlash = 0; // parent sub-dir: NO trailing slash. With one,
                                    // ChangePath's RealPath normalizes it away, so
                                    // Salamander sees a "changed path" and drops the
                                    // focus name (that is why it only worked at root).
                SalamanderGeneral->ChangePanelPathToPluginFS(panel, pluginFSName, cur, NULL, -1,
                                                             focusName[0] != 0 ? focusName : NULL);
            }
            else
            {
                SalamanderGeneral->ChangePanelPathToPluginFS(panel, pluginFSName, cur);
            }
        }
        else
        {
            char userPart[3072];
            char full[3072];
            // CF-26: build the path from the real remote name, not the panel's
            // sanitized display name (which '?'-substitutes invalid UTF-8).
            // feature 131: a path that does not fit is refused - cut, it opened another directory
            if (!fs->GetCurrentPathFull(userPart, sizeof(userPart)) || // CF-7
                _snprintf_s(full, _TRUNCATE, "%s/%s", userPart, SFTPRealName(&file)) < 0)
            {
                ShowTooLongPath(SalamanderGeneral->GetMsgBoxParent());
                return;
            }
            SalamanderGeneral->ChangePanelPathToPluginFS(panel, pluginFSName, full);
        }
    }
    else // file: Enter on a file is a no-op in v1 (F3 views via ViewFile)
    {
        SalamanderGeneral->SetUserWorkedOnPanelPath(panel);
    }
}

BOOL WINAPI CPluginInterfaceForFS::DisconnectFS(HWND parent, BOOL isInPanel, int panel,
                                                CPluginFSInterfaceAbstract* pluginFS,
                                                const char* pluginFSName, int pluginFSNameIndex)
{
    if (isInPanel)
    {
        SalamanderGeneral->DisconnectFSFromPanel(parent, panel);
        return TRUE;
    }
    SalamanderGeneral->CloseDetachedFS(parent, pluginFS);
    return TRUE;
}

void WINAPI CPluginInterfaceForFS::ConvertPathToInternal(const char* fsName, int fsNameIndex, char* fsUserPart)
{
}

void WINAPI CPluginInterfaceForFS::ConvertPathToExternal(const char* fsName, int fsNameIndex, char* fsUserPart)
{
}

// ---------------------------------------------------------------------------
// CPluginFSInterface
// ---------------------------------------------------------------------------

CPluginFSInterface::CPluginFSInterface()
{
    Host[0] = 0;
    Port = SFTP_DEFAULT_PORT;
    User[0] = 0;
    lstrcpynA(Path, "/", sizeof(Path));
    LastFailedListPath[0] = 0;
    HasParams = FALSE;
    FatalError = FALSE;
    WasConnected = FALSE;
    LogUID = -1;
}

CPluginFSInterface::~CPluginFSInterface()
{
    Session.Disconnect();
    Params.WipeSecrets();
}

void CPluginFSInterface::SetConnectParams(const CSFTPConnectParams* params)
{
    Params = *params;
    HasParams = TRUE;
}

BOOL CPluginFSInterface::MakeUserPart(const char* path, char* buf, int bufSize)
{
    // bracket IPv6 literal hosts so the "host:port" split round-trips
    BOOL ipv6 = strchr(Host, ':') != NULL;
    if (_snprintf_s(buf, bufSize, _TRUNCATE, "%s@%s%s%s:%d%s", User,
                    ipv6 ? "[" : "", Host, ipv6 ? "]" : "", Port,
                    (path != NULL && path[0]) ? path : "/") < 0)
    {
        // feature 131: it does not fit - no cut path leaves this function
        if (bufSize > 0)
            buf[0] = 0;
        return FALSE;
    }
    return TRUE;
}

BOOL CPluginFSInterface::ParseUserPart(const char* userPart, char* host, int* port, char* user,
                                       char* path, int pathSize)
{
    // format: [user@]host[:port][/path]
    const char* p = userPart;
    // feature 133: the form with two slashes ("sftp://user@host/path", what people type and
    // paste) used to end with "A host name is missing in the path specified."
    if (p[0] == '/' && p[1] == '/')
        p += 2;
    const char* at = strchr(p, '@');
    const char* slash = strchr(p, '/');
    user[0] = 0;
    if (at != NULL && (slash == NULL || at < slash))
    {
        int n = (int)(at - p);
        if (n > 255)
            n = 255;
        memcpy(user, p, n);
        user[n] = 0;
        p = at + 1;
    }
    *port = SFTP_DEFAULT_PORT;
    if (*p == '[')
    {
        // IPv6 literal: [::1] or [::1]:port ; store the address without brackets
        const char* close = strchr(p, ']');
        if (close == NULL)
            return FALSE;
        int hn = (int)(close - (p + 1));
        if (hn <= 0 || hn > 255)
            return FALSE;
        memcpy(host, p + 1, hn);
        host[hn] = 0;
        p = close + 1;
        slash = strchr(p, '/');
        if (*p == ':')
        {
            *port = atoi(p + 1);
            if (*port <= 0 || *port > 65535)
                return FALSE;
        }
    }
    else
    {
        // host[:port] - a bare colon is a port only when it precedes the path
        slash = strchr(p, '/');
        const char* hostEnd = slash != NULL ? slash : p + strlen(p);
        const char* colon = NULL;
        for (const char* q = p; q < hostEnd; q++)
            if (*q == ':')
                colon = q;
        const char* he = colon != NULL ? colon : hostEnd;
        int hn = (int)(he - p);
        if (hn <= 0 || hn > 255)
            return FALSE;
        memcpy(host, p, hn);
        host[hn] = 0;
        if (colon != NULL && colon + 1 < hostEnd)
        {
            *port = atoi(colon + 1);
            if (*port <= 0 || *port > 65535)
                return FALSE;
        }
    }
    if (slash != NULL)
    {
        if (strlen(slash) >= (size_t)pathSize) // feature 131: never a cut path
        {
            path[0] = 0;
            return FALSE;
        }
        lstrcpynA(path, slash, pathSize);
    }
    else
        lstrcpynA(path, "/", pathSize);
    return TRUE;
}

BOOL CPluginFSInterface::EnsureConnected(HWND parent)
{
    if (Session.IsConnected())
        return TRUE;
    if (!HasParams)
        return FALSE;

    // feature 051 (U7): a session that was established and then lost its
    // transport comes back here with Connected == FALSE. Tear the dead session
    // down first so the reconnect starts from a clean state (data model I3);
    // this is the path that makes the previously dead Reconnect() reachable.
    if (WasConnected)
    {
        Session.Disconnect();
        if (LogUID >= 0)
            Logs.AppendFmt(LogUID, LoadStrU8(IDS_RECONNECTING), Host); // feature 130: the log is one UTF-8 text
        WasConnected = FALSE;
    }

    Params.ConnectTimeoutSec = Config.ConnectTimeout;
    Params.OperationTimeoutSec = Config.OperationTimeout;
    if (Params.KeepAliveSec == 0)
        Params.KeepAliveSec = Config.KeepAliveSendEvery;

    if (LogUID < 0)
    {
        char label[320];
        _snprintf_s(label, _TRUNCATE, "%s@%s:%d", User, Host, Port);
        LogUID = Logs.CreateLog(label);
        Session.SetLogUID(LogUID);
    }

    CSFTPConnectResult result = crOk;
    if (!Session.Connect(parent, &Params, &HostKeys, &result))
    {
        if (result != crHostKeyRejected && result != crCancelled)
            SalamanderGeneral->SalMessageBox(parent, Session.GetLastErrorText(),
                                             LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        FatalError = TRUE;
        return FALSE;
    }
    FatalError = FALSE;
    WasConnected = TRUE; // feature 051: a later loss of transport means reconnect

    // arm the keepalive timer (FSE_TIMER re-arms it); one tick per keepalive
    // interval keeps idle sessions alive behind NAT/firewalls (FR-022)
    int ka = Config.KeepAliveSendEvery > 0 ? Config.KeepAliveSendEvery : 60;
    SalamanderGeneral->AddPluginFSTimer(ka * 1000, this, 0);
    return TRUE;
}

BOOL WINAPI CPluginFSInterface::GetCurrentPath(char* userPart)
{
    // feature 131: no success with a cut path (ChangePath keeps the current path within
    // MAX_PATH, so this fails only if that rule is ever broken)
    return MakeUserPart(Path, userPart, MAX_PATH);
}

// CF-7: full-size variant for the plugin's own navigation, which uses 3072-byte
// buffers. The SDK GetCurrentPath contract mandates a MAX_PATH buffer, so it
// would silently truncate a long remote path and navigate to the wrong place.
BOOL CPluginFSInterface::GetCurrentPathFull(char* buf, int bufSize)
{
    return MakeUserPart(Path, buf, bufSize);
}

BOOL WINAPI CPluginFSInterface::GetFullName(CFileData& file, int isDir, char* buf, int bufSize)
{
    if (isDir == 2) // up-dir: current path minus last component
    {
        char parent[3072];
        lstrcpynA(parent, Path, sizeof(parent));
        char* slash = strrchr(parent, '/');
        if (slash != NULL && slash != parent)
            *slash = 0;
        else
            strcpy(parent, "/");
        return MakeUserPart(parent, buf, bufSize);
    }
    char full[3072];
    // CF-26: use the real remote name, not the sanitized panel display name.
    // feature 131: no success with a cut name (the core uses it as a path)
    if (PosixPathAppend(Path, SFTPRealName(&file), full, sizeof(full)) == NULL)
    {
        if (bufSize > 0)
            buf[0] = 0;
        return FALSE;
    }
    return MakeUserPart(full, buf, bufSize);
}

BOOL WINAPI CPluginFSInterface::GetFullFSPath(HWND parent, const char* fsName, char* path, int pathSize, BOOL& success)
{
    // treat 'path' as a relative or absolute POSIX path on the current server
    // feature 131: a result that does not fit is an error shown here ('success' FALSE), not
    // a cut path the core would then change to; 'path' is written only when all of it fits
    char abs[3072];
    char userPart[3072];
    BOOL fits;
    if (path[0] == '/')
    {
        fits = strlen(path) < sizeof(abs);
        if (fits)
            lstrcpynA(abs, path, sizeof(abs));
    }
    else
        fits = PosixPathAppend(Path, path, abs, sizeof(abs)) != NULL;
    if (fits)
        fits = MakeUserPart(abs, userPart, sizeof(userPart));
    if (fits)
        fits = strlen(fsName) + 1 + strlen(userPart) < (size_t)pathSize;
    if (!fits)
    {
        ShowTooLongPath(parent);
        success = FALSE;
        return TRUE;
    }
    _snprintf_s(path, pathSize, _TRUNCATE, "%s:%s", fsName, userPart);
    success = TRUE;
    return TRUE;
}

BOOL WINAPI CPluginFSInterface::GetRootPath(char* userPart)
{
    // feature 131: through MakeUserPart - not cut, and an IPv6 host gets its brackets like
    // every other path of this FS (without them ParseUserPart cannot read the path back)
    return MakeUserPart("/", userPart, MAX_PATH);
}

BOOL WINAPI CPluginFSInterface::IsCurrentPath(int currentFSNameIndex, int fsNameIndex, const char* userPart)
{
    char host[256], user[256], path[3072];
    int port;
    if (!ParseUserPart(userPart, host, &port, user, path, sizeof(path)))
        return FALSE;
    return _stricmp(host, Host) == 0 && port == Port && strcmp(user, User) == 0 &&
           strcmp(path, Path) == 0;
}

BOOL WINAPI CPluginFSInterface::IsOurPath(int currentFSNameIndex, int fsNameIndex, const char* userPart)
{
    char host[256], user[256], path[3072];
    int port;
    if (!ParseUserPart(userPart, host, &port, user, path, sizeof(path)))
        return FALSE;
    // same server identity => our path
    if (Host[0] == 0)
        return TRUE; // fresh FS, adopt any path
    return _stricmp(host, Host) == 0 && port == Port && strcmp(user, User) == 0;
}

// feature 140: the session was lost by a request of ChangePath. Connects again - once per
// call ('*reconnected'); TRUE = the caller repeats its requests. FALSE = the change of path
// fails: the reconnect failed or was stopped (EnsureConnected has shown why), or this is the
// second loss in one call (shown here).
BOOL CPluginFSInterface::ReconnectLostInChangePath(BOOL* reconnected)
{
    HWND parent = SalamanderGeneral->GetMsgBoxParent();
    if (*reconnected)
    {
        SalamanderGeneral->SalMessageBox(parent, Session.GetLastErrorText(), LoadStr(IDS_SFTPERRORTITLE),
                                         MB_OK | MB_ICONEXCLAMATION);
        return FALSE;
    }
    *reconnected = TRUE;
    return EnsureConnected(parent);
}

BOOL WINAPI CPluginFSInterface::ChangePath(int currentFSNameIndex, char* fsName, int fsNameIndex,
                                           const char* userPart, char* cutFileName, BOOL* pathWasCut,
                                           BOOL forceRefresh, int mode)
{
    if (pathWasCut != NULL)
        *pathWasCut = FALSE;
    if (cutFileName != NULL)
        cutFileName[0] = 0;

    char host[256], user[256], path[3072];
    int port;
    if (!ParseUserPart(userPart, host, &port, user, path, sizeof(path)))
    {
        // feature 131: ParseUserPart also refuses a path that does not fit (it was cut); the
        // core hands in less than MAX_PATH bytes, so this is a guard
        SalamanderGeneral->SalMessageBox(SalamanderGeneral->GetMsgBoxParent(),
                                         LoadStr(strlen(userPart) >= sizeof(path) ? IDS_TOOLONGPATH : IDS_HOSTNAMEMISSING),
                                         LoadStr(IDS_SFTPERRORTITLE), MB_OK | MB_ICONEXCLAMATION);
        return FALSE;
    }

    // first open: adopt identity + pending params
    if (Host[0] == 0)
    {
        lstrcpynA(Host, host, sizeof(Host));
        Port = port;
        lstrcpynA(User, user, sizeof(User));
        if (g_HasPending && _stricmp(g_PendingParams.Host, host) == 0 &&
            g_PendingParams.Port == port && strcmp(g_PendingParams.User, user) == 0)
        {
            SetConnectParams(&g_PendingParams);
        }
        else
        {
            // Reconnect from history / command line / Alt+F12 without staged
            // params. feature 051 (U14): reuse the matching bookmark's
            // authentication method first - defaulting to a password prompt made
            // key-only servers (PasswordAuthentication no) impossible to reach
            // this way, and asked for a password nobody had.
            const CSFTPServer* known = NULL;
            for (int i = 0; i < Config.Bookmarks.Count; i++)
            {
                const CSFTPServer* b = Config.Bookmarks[i];
                if (b->Address != NULL && _stricmp(b->Address, host) == 0 &&
                    (b->Port > 0 ? b->Port : SFTP_DEFAULT_PORT) == port &&
                    b->UserName != NULL && strcmp(b->UserName, user) == 0)
                {
                    known = b;
                    break;
                }
            }
            if (known != NULL)
            {
                FillParamsFromServer(known, &Params);
                HasParams = TRUE;
            }
            else
            {
                memset(&Params, 0, sizeof(Params));
                lstrcpynA(Params.Host, host, sizeof(Params.Host));
                Params.Port = port;
                lstrcpynA(Params.User, user, sizeof(Params.User));
                Params.AuthMethod = saPassword;
                HasParams = TRUE;
            }
            // a password is prompted here only when that is the chosen method and
            // none was stored; key auth prompts for a passphrase on demand instead
            if (mode != 1 && Params.AuthMethod == saPassword && Params.Password[0] == 0)
            {
                char prompt[512];
                _snprintf_s(prompt, _TRUNCATE, LoadStrU8(IDS_ENTERPASSWORD), user);
                SplU8TrimTornTail(prompt);
                if (!ShowPasswordPrompt(SalamanderGeneral->GetMsgBoxParent(), prompt,
                                        Params.Password, sizeof(Params.Password)))
                    return FALSE;
            }
        }
    }

    if (!EnsureConnected(SalamanderGeneral->GetMsgBoxParent()))
        return FALSE;

    // resolve and verify the requested path exists (and is a directory)
    // feature 140: a request that times out (or breaks the transport) ends the session; what
    // follows is not sent, and a stat that is not answered is not "no such directory" - the
    // loop below used to cut the path down to the root on it. The session is then connected
    // again (EnsureConnected, what the next operation would do anyway) and the path is
    // resolved once more, ONCE: returning FALSE would make the core leave the file system on
    // a refresh. Only when the reconnect fails (it says why itself) or the new connection is
    // lost too (said here) does the change of path fail.
    char abs[3072];
    char fitProbe[MAX_PATH];
    BOOL reconnected = FALSE;
RESOLVE_PATH:
    if (pathWasCut != NULL)
        *pathWasCut = FALSE;
    if (cutFileName != NULL)
        cutFileName[0] = 0;
    if (!Session.RealPath(path, abs, sizeof(abs)))
        lstrcpynA(abs, path, sizeof(abs)); // same size as 'path': fits
    if (!Session.IsConnected())
    {
        if (!ReconnectLostInChangePath(&reconnected))
            return FALSE;
        goto RESOLVE_PATH;
    }

    // feature 131: the current path must fit the core's MAX_PATH buffer for a user part
    // (GetCurrentPath; the core also refuses to change to a longer one). The server's
    // resolved form can be longer than what was asked for (a symbolic link to a deep
    // directory): GetCurrentPath then gave the core a CUT path, and the 3072-byte buffers of
    // rename / create directory / view could overflow. Such a resolved form is not adopted -
    // the path stays as requested, which names the same directory and fits.
    if (!MakeUserPart(abs, fitProbe, sizeof(fitProbe)))
        lstrcpynA(abs, path, sizeof(abs));

    // try to list to confirm the path; on failure, cut the last component
    for (;;)
    {
        // loop-breaker: if this is exactly the path ListCurrentPath just failed
        // to list (e.g. permission denied), do not re-offer it - shorten it, so
        // Salamander does not call ListCurrentPath on it again and again
        if (LastFailedListPath[0] != 0 && strcmp(abs, LastFailedListPath) == 0)
        {
            char* slash = strrchr(abs, '/');
            if (slash == NULL || (slash == abs && abs[1] == 0))
                return FALSE; // even the root failed - fall back to a fixed drive
            if (slash == abs)
                abs[1] = 0; // cut "/x" -> "/"
            else
                *slash = 0;
            if (pathWasCut != NULL)
                *pathWasCut = TRUE;
            continue;
        }

        LIBSSH2_SFTP_ATTRIBUTES attrs;
        if (Session.Stat(abs, TRUE, &attrs))
        {
            if ((attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) && !SFTP_S_ISDIR(attrs.permissions))
            {
                // it's a file: cut to parent, optionally return the file name
                char* slash = strrchr(abs, '/');
                if (slash != NULL && mode == 3 && cutFileName != NULL)
                    lstrcpynA(cutFileName, slash + 1, MAX_PATH);
                if (slash != NULL && slash != abs)
                    *slash = 0;
                else
                    strcpy(abs, "/");
                if (pathWasCut != NULL)
                    *pathWasCut = TRUE;
                continue;
            }
            break; // directory ok
        }
        if (!Session.IsConnected()) // feature 140: not answered - not "does not exist" (see above)
        {
            if (!ReconnectLostInChangePath(&reconnected))
                return FALSE;
            goto RESOLVE_PATH;
        }
        // path does not exist: cut last component and retry (modes 1/2/3)
        char* slash = strrchr(abs, '/');
        if (slash == NULL || slash == abs)
        {
            strcpy(abs, "/");
            break;
        }
        *slash = 0;
        if (pathWasCut != NULL)
            *pathWasCut = TRUE;
    }

    // feature 131: (the requested path with the port and the brackets written out can still
    // be a few bytes over) - refuse, the current path of this FS is never one that gets cut
    if (!MakeUserPart(abs, fitProbe, sizeof(fitProbe)))
    {
        ShowTooLongPath(SalamanderGeneral->GetMsgBoxParent());
        return FALSE;
    }
    lstrcpynA(Path, abs, sizeof(Path));
    return TRUE;
}

BOOL WINAPI CPluginFSInterface::ListCurrentPath(CSalamanderDirectoryAbstract* dir,
                                                CPluginDataInterfaceAbstract*& pluginData,
                                                int& iconsType, BOOL forceRefresh)
{
    if (!EnsureConnected(SalamanderGeneral->GetMsgBoxParent()))
        return FALSE;

    CSFTPListingData* listing = new CSFTPListingData;
    if (listing == NULL)
        return FALSE;

    dir->SetValidData(VALID_DATA_SIZE | VALID_DATA_DATE | VALID_DATA_TIME |
                      VALID_DATA_ATTRIBUTES | VALID_DATA_HIDDEN | VALID_DATA_ISLINK | VALID_DATA_EXTENSION);
    dir->SetFlags(SALDIRFLAG_IGNOREDUPDIRS);

    TIndirectArray<CSFTPDirEntry> entries(128, 128);
    volatile BOOL cancel = FALSE;
    SalamanderGeneral->CreateSafeWaitWindow(LoadStr(IDS_PLUGINNAME), LoadStr(IDS_PLUGINNAME), 1000, TRUE,
                                            SalamanderGeneral->GetMainWindowHWND());
    BOOL listed = Session.ListDir(Path, &entries, &cancel);
    SalamanderGeneral->DestroySafeWaitWindow();

    if (!listed)
    {
        // remember which path failed so the follow-up ChangePath shortens it
        // (SDK: after ListCurrentPath returns FALSE, ChangePath must change the
        // path) - this is what stops the error dialog from repeating forever
        lstrcpynA(LastFailedListPath, Path, sizeof(LastFailedListPath));
        if (!cancel) // a user-cancelled listing is not an error worth a dialog
        {
            SFTPShowPathError(SalamanderGeneral->GetMsgBoxParent(), IDS_ERR_LISTDIR, Path, Session.GetLastErrorText());
        }
        delete listing;
        return FALSE;
    }
    LastFailedListPath[0] = 0; // this path listed fine

    dir->SetApproximateCount(entries.Count + 1, 4);

    // add the up-dir ".." (unless at the root) so the user can go up a level;
    // Salamander recognizes a directory named ".." as the up-dir and enables
    // Backspace / the up-dir symbol at the top of the panel
    if (strcmp(Path, "/") != 0)
    {
        CFileData up;
        memset(&up, 0, sizeof(up));
        up.Name = (char*)SalamanderGeneral->Alloc(3);
        if (up.Name != NULL)
        {
            strcpy(up.Name, "..");
            up.NameLen = 2;
            up.Ext = up.Name + 2;
            up.Attr = FILE_ATTRIBUTE_DIRECTORY;
            up.PluginData = 0; // no per-row data for the up-dir
            if (!dir->AddDir(NULL, up, NULL))
                SalamanderGeneral->Free(up.Name);
        }
    }

    for (int i = 0; i < entries.Count; i++)
    {
        CSFTPDirEntry* e = entries[i];
        CFileData fd;
        BOOL isDir = FALSE;
        if (!CSFTPListingData::FillFileData(fd, e, &isDir))
            continue;
        // fill link target for symlinks (for Info line / navigation)
        if (fd.IsLink)
        {
            char target[2048];
            char linkPath[3072];
            if (PosixPathAppend(Path, e->Name, linkPath, sizeof(linkPath)) != NULL && // (does not fit: no target shown)
                Session.ReadLink(linkPath, target, sizeof(target)))
            {
                CSFTPItemData* d = (CSFTPItemData*)fd.PluginData;
                if (d != NULL)
                {
                    d->LinkTarget = _strdup(target);
                    LIBSSH2_SFTP_ATTRIBUTES ta;
                    if (Session.Stat(linkPath, TRUE, &ta) && (ta.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS))
                        d->LinkIsDir = SFTP_S_ISDIR(ta.permissions);
                    else if (Session.IsConnected()) // feature 140: a stat that ended the session says nothing about the link
                        d->LinkBroken = TRUE;
                }
            }
        }
        // per-entry pluginData is NULL for FS (the panel's data interface is the
        // one returned via 'pluginData' below); passing 'listing' here would make
        // Salamander release each row's PluginData twice -> double free
        BOOL added;
        if (isDir)
            added = dir->AddDir(NULL, fd, NULL);
        else
            added = dir->AddFile(NULL, fd, NULL);
        if (!added)
        {
            CSFTPListingData::FreeItemData(fd);
            if (fd.Name != NULL)
                SalamanderGeneral->Free(fd.Name);
        }
    }

    pluginData = listing;
    iconsType = pitFromRegistry;
    return TRUE;
}

BOOL WINAPI CPluginFSInterface::TryCloseOrDetach(BOOL forceClose, BOOL canDetach, BOOL& detach, int reason)
{
    detach = FALSE; // do not keep detached sessions in v1
    return TRUE;
}

void WINAPI CPluginFSInterface::Event(int event, DWORD param)
{
    if (event == FSE_TIMER)
    {
        if (Session.IsConnected())
        {
            int next = 0;
            Session.Keepalive(&next);
            // re-arm for the next interval
            int ka = Config.KeepAliveSendEvery > 0 ? Config.KeepAliveSendEvery : 60;
            SalamanderGeneral->AddPluginFSTimer(ka * 1000, this, 0);
        }
    }
}

void WINAPI CPluginFSInterface::ReleaseObject(HWND parent)
{
    SalamanderGeneral->KillPluginFSTimer(this, TRUE, 0); // no timer must fire on a dead FS
    Session.Disconnect();
}

DWORD WINAPI CPluginFSInterface::GetSupportedServices()
{
    return FS_SERVICE_COPYFROMFS | FS_SERVICE_MOVEFROMFS |
           FS_SERVICE_COPYFROMDISKTOFS | FS_SERVICE_MOVEFROMDISKTOFS |
           FS_SERVICE_DELETE | FS_SERVICE_QUICKRENAME | FS_SERVICE_CREATEDIR |
           FS_SERVICE_CHANGEATTRS | FS_SERVICE_VIEWFILE |
           FS_SERVICE_GETCHANGEDRIVEORDISCONNECTITEM | FS_SERVICE_GETFSICON |
           FS_SERVICE_GETNEXTDIRLINEHOTPATH | FS_SERVICE_GETPATHFORMAINWNDTITLE |
           FS_SERVICE_ACCEPTSCHANGENOTIF | FS_SERVICE_COMMANDLINE |
           FS_SERVICE_CONTEXTMENU; // feature 018: right-click file/dir menu (its absence is why right-click did nothing)
}

BOOL WINAPI CPluginFSInterface::GetChangeDriveOrDisconnectItem(const char* fsName, char*& title, HICON& icon, BOOL& destroyIcon)
{
    // Put the connection text in the wide "name" column (leading TAB = empty
    // drive-letter column), mirroring the FTP plugin. Otherwise the long
    // "user@host:port" sits in the narrow first column, whose width is the max
    // across all drive rows, and stretches the whole Change-Drive panel.
    char buf[512];
    _snprintf_s(buf, _TRUNCATE, "\t%s@%s:%d", User, Host, Port);
    title = SalamanderGeneral->DupStr(buf);
    icon = NULL; // the FS icon is supplied separately via GetFSIcon
    destroyIcon = FALSE;
    return TRUE;
}

HICON WINAPI CPluginFSInterface::GetFSIcon(BOOL& destroyIcon)
{
    destroyIcon = FALSE;
    return SFTPIcon;
}

void WINAPI CPluginFSInterface::GetDropEffect(const char* srcFSPath, const char* tgtFSPath,
                                              DWORD allowedEffects, DWORD keyState, DWORD* dropEffect)
{
}

void WINAPI CPluginFSInterface::GetFSFreeSpace(CQuadWord* retValue)
{
    *retValue = CQuadWord(0xFFFFFFFF, 0xFFFFFFFF); // free space unknown
}

BOOL WINAPI CPluginFSInterface::GetNextDirectoryLineHotPath(const char* text, int pathLen, int& offset)
{
    // find the next '/' after 'offset' within the path portion
    const char* colon = strchr(text, ':');
    int start = colon != NULL ? (int)(colon - text) + 1 : 0;
    if (offset < start)
        offset = start;
    for (int i = offset + 1; i < pathLen; i++)
    {
        if (text[i] == '/')
        {
            offset = i;
            return TRUE;
        }
    }
    return FALSE;
}

void WINAPI CPluginFSInterface::CompleteDirectoryLineHotPath(char* path, int pathBufSize)
{
}

BOOL WINAPI CPluginFSInterface::GetPathForMainWindowTitle(const char* fsName, int mode, char* buf, int bufSize)
{
    if (mode == 1) // directory name only
    {
        const char* base = PosixBaseName(Path);
        lstrcpynA(buf, (base[0] != 0) ? base : "/", bufSize);
        return TRUE;
    }
    return FALSE;
}

void WINAPI CPluginFSInterface::ShowInfoDialog(const char* fsName, HWND parent)
{
    char msg[600];
    _snprintf_s(msg, _TRUNCATE, "Server: %s\nPort: %d\nUser: %s\nPath: %s", Host, Port, User, Path);
    SalamanderGeneral->SalMessageBox(parent, msg, LoadStr(IDS_PLUGINNAME), MB_OK | MB_ICONINFORMATION);
}

// deferred "cd" target, filled by ExecuteCommandLine and consumed by
// ExecuteDeferredCd (via PostMenuExtCommand) so the path change happens OUTSIDE
// any FS-interface method (calling ChangePanelPathToPluginFS from within one is
// forbidden - it can free 'this')
static char g_DeferredCdUserPart[3072] = "";

void ExecuteDeferredCd()
{
    if (g_DeferredCdUserPart[0] == 0)
        return;
    char up[3072];
    lstrcpynA(up, g_DeferredCdUserPart, sizeof(up));
    g_DeferredCdUserPart[0] = 0;
    SalamanderGeneral->ChangePanelPathToPluginFS(PANEL_SOURCE, AssignedFSName, up);
}

BOOL WINAPI CPluginFSInterface::ExecuteCommandLine(HWND parent, char* command, int& selFrom, int& selTo)
{
    // support a simple "cd <path>" - the actual path change is DEFERRED (posted)
    // because ChangePanelPathToPluginFS must not run inside an FS-interface method
    while (*command == ' ')
        command++;
    if (_strnicmp(command, "cd ", 3) == 0)
    {
        // feature 131: a target that does not fit is refused, not cut (MakeUserPart leaves
        // the deferred path empty then, and nothing is posted)
        const char* target = command + 3;
        BOOL fits;
        if (target[0] == '/')
            fits = MakeUserPart(target, g_DeferredCdUserPart, sizeof(g_DeferredCdUserPart));
        else
        {
            char abs[3072];
            fits = PosixPathAppend(Path, target, abs, sizeof(abs)) != NULL &&
                   MakeUserPart(abs, g_DeferredCdUserPart, sizeof(g_DeferredCdUserPart));
        }
        if (fits)
            SalamanderGeneral->PostMenuExtCommand(SFTPCMD_DEFERREDCD, TRUE);
        else
        {
            g_DeferredCdUserPart[0] = 0;
            ShowTooLongPath(parent);
        }
    }
    command[0] = 0;
    selFrom = selTo = 0;
    return TRUE;
}

// feature 139: do two names of one directory differ only in the case of letters (and are not
// byte-equal)? Compared as UTF-16 by the ordinal rule; a name that cannot be converted or does
// not fit answers FALSE (it is then handled as another name).
static BOOL QuickRenameOnlyCaseDiffers(const char* oldName, const char* newName)
{
    if (strcmp(oldName, newName) == 0)
        return FALSE;
    WCHAR wOld[1024], wNew[1024];
    if (SplU8ToW(oldName, wOld, _countof(wOld)) <= 0 || SplU8ToW(newName, wNew, _countof(wNew)) <= 0)
        return FALSE;
    return CompareStringOrdinal(wOld, -1, wNew, -1, TRUE) == CSTR_EQUAL;
}

BOOL WINAPI CPluginFSInterface::QuickRename(const char* fsName, int mode, HWND parent, CFileData& file,
                                            BOOL isDir, char* newName, BOOL& cancel)
{
    cancel = FALSE;
    if (mode == 1)
        return FALSE; // use the standard rename dialog

    // mode == 2: newName holds the new name
    if (!EnsureConnected(parent))
        return FALSE;
    char from[3072], to[3072];
    // feature 131: a cut 'from' renamed another item, a cut 'to' gave it another name
    if (PosixPathAppend(Path, SFTPRealName(&file), from, sizeof(from)) == NULL || // real (unsanitized) remote name
        PosixPathAppend(Path, newName, to, sizeof(to)) == NULL)
    {
        ShowTooLongPath(parent);
        return FALSE;
    }
    if (strcmp(from, to) == 0)
        return TRUE; // the same name: nothing to do
    // feature 139: a name that exists already is refused - the rename used to go through the
    // replacing posix-rename extension and the other file was gone without a word. The link
    // itself is asked about (lstat): a dangling link holds the name too. The check is ours:
    // that a plain rename request refuses an existing target is what OpenSSH does, not a
    // promise of every server - so an lstat that could not tell (any failure other than "no
    // such file") refuses the rename as well.
    LIBSSH2_SFTP_ATTRIBUTES targetAttrs;
    CSFTPStatResult target = Session.StatEx(to, FALSE, &targetAttrs);
    if (target == sxError)
    {
        SFTPShowPathError(parent, IDS_ERR_RENAME, file.Name, Session.GetLastErrorText());
        return FALSE;
    }
    BOOL replace = FALSE;
    if (target == sxFound)
    {
        // A name that differs only in the case of letters: on a case-insensitive server the
        // name found is this very item, on a case-sensitive one it is another file. The
        // directory's listing tells: another file has an entry spelled exactly like the new
        // name. Without such an entry the replacing request is the right one (it "replaces"
        // the item by itself and so changes the case); a listing that fails or is not
        // complete refuses the rename.
        BOOL sameItem = FALSE;
        if (QuickRenameOnlyCaseDiffers(SFTPRealName(&file), newName))
        {
            TIndirectArray<CSFTPDirEntry> entries(64, 64);
            volatile BOOL stopped = FALSE;
            if (!Session.ListDir(Path, &entries, &stopped) || stopped)
            {
                SFTPShowPathError(parent, IDS_ERR_RENAME, file.Name,
                                  stopped ? "the directory could not be read whole." : Session.GetLastErrorText());
                return FALSE;
            }
            // (second review) not only an entry spelled exactly like the new name: ANY entry
            // other than the renamed item that equals the new name up to case may be what the
            // server would replace (a server that folds case and still lists two spellings).
            // Only when the old name is the sole such entry is the name found the item itself.
            sameItem = TRUE;
            const char* oldName = SFTPRealName(&file);
            for (int i = 0; i < entries.Count; i++)
            {
                const char* entryName = entries[i]->Name;
                if (strcmp(entryName, oldName) == 0)
                    continue;
                if (strcmp(entryName, newName) == 0 || QuickRenameOnlyCaseDiffers(entryName, newName))
                {
                    sameItem = FALSE;
                    break;
                }
            }
        }
        if (!sameItem)
        {
            SFTPShowPathError(parent, IDS_ERR_RENAME, file.Name, "a file or directory of that name already exists.");
            return FALSE;
        }
        replace = TRUE;
    }
    if (!Session.Rename(from, to, replace))
    {
        SFTPShowPathError(parent, IDS_ERR_RENAME, file.Name, Session.GetLastErrorText());
        return FALSE;
    }
    SalamanderGeneral->PostRefreshPanelFS(this, FALSE);
    return TRUE;
}

void WINAPI CPluginFSInterface::AcceptChangeOnPathNotification(const char* fsName, const char* path, BOOL includingSubdirs)
{
}

BOOL WINAPI CPluginFSInterface::CreateDir(const char* fsName, int mode, HWND parent, char* newName, BOOL& cancel)
{
    cancel = FALSE;
    if (mode == 1)
        return FALSE; // use the standard dialog

    if (!EnsureConnected(parent))
        return FALSE;
    char full[3072];
    // feature 131: a cut path created a directory of another name ('newName' has at most
    // 2 * MAX_PATH bytes, so only the join with the current path can fail)
    BOOL fits;
    if (newName[0] == '/')
    {
        fits = strlen(newName) < sizeof(full);
        if (fits)
            lstrcpynA(full, newName, sizeof(full));
    }
    else
        fits = PosixPathAppend(Path, newName, full, sizeof(full)) != NULL;
    if (!fits)
    {
        ShowTooLongPath(parent);
        return FALSE;
    }
    if (!Session.Mkdir(full, 0755))
    {
        SFTPShowPathError(parent, IDS_ERR_MKDIR, newName, Session.GetLastErrorText());
        return FALSE;
    }
    SalamanderGeneral->PostRefreshPanelFS(this, FALSE);
    lstrcpynA(newName, PosixBaseName(full), 2 * MAX_PATH);
    return TRUE;
}

void WINAPI CPluginFSInterface::ViewFile(const char* fsName, HWND parent,
                                         CSalamanderForViewFileOnFSAbstract* salamander, CFileData& file)
{
    if (!EnsureConnected(parent))
        return;

    char remote[3072];
    char uniqueName[3200];
    // feature 131: a cut remote path showed another file; a cut unique name is the cache key
    // of another file (its cached copy would be shown)
    if (PosixPathAppend(Path, SFTPRealName(&file), remote, sizeof(remote)) == NULL || // real remote name
        _snprintf_s(uniqueName, _TRUNCATE, "%s:%s@%s:%d%s", fsName, User, Host, Port, remote) < 0)
    {
        ShowTooLongPath(parent);
        return;
    }

    // feature 140: only a regular file is read (see DownloadOneFileImpl in operats.cpp): the
    // view of a device or a FIFO - also behind a link - filled the cache without an end. What
    // the listing shows as a regular file is not asked about again.
    CSFTPItemData* itemData = (CSFTPItemData*)file.PluginData;
    if (itemData == NULL || !itemData->HasMode || !SFTP_S_ISREG(itemData->Mode))
    {
        LIBSSH2_SFTP_ATTRIBUTES viewAttrs;
        BOOL known = Session.Stat(remote, TRUE, &viewAttrs);
        if (!Session.IsConnected()) // the request ended the session: nothing more is sent
        {
            SFTPShowPathError(parent, IDS_ERR_DOWNLOAD, file.Name, Session.GetLastErrorText());
            return;
        }
        if (known && SftpDownloadKind((viewAttrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) != 0, viewAttrs.permissions) == sdkSpecial)
        {
            SFTPShowPathError(parent, IDS_ERR_DOWNLOAD, file.Name, "not a regular file (a device, FIFO or socket).");
            return;
        }
    }

    BOOL fileExists = FALSE;
    const char* cacheName = salamander->AllocFileNameInCache(parent, uniqueName, file.Name, NULL, fileExists);
    if (cacheName == NULL)
        return;

    BOOL newFileOK = FALSE;
    CQuadWord newFileSize(0, 0);
    if (!fileExists)
    {
        // download into the cache path
        wchar_t wpath[4096];
        // CF-18: do not open CreateFileW on an uninitialized buffer. feature 131: SplU8ToW
        // (WTF-8 like the core's names) leaves an empty path on failure; CreateFileW then
        // fails and FreeFileNameInCache below still runs (the 'return' here skipped it).
        SplU8ToW(cacheName, wpath, 4096);
        HANDLE lf = CreateFileW(wpath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        if (lf != INVALID_HANDLE_VALUE)
        {
            LIBSSH2_SFTP_HANDLE* h = Session.OpenRead(remote);
            if (h != NULL)
            {
                char buf[64 * 1024]; // CF-23: call-local; a static I/O buffer is a re-entrancy hazard
                __int64 total = 0;
                BOOL ok = TRUE;
                // feature 051 (F7): viewing a large or slow remote file used to run
                // to completion with no way out - no wait window, no cancel test.
                // The total time is bounded only by size/bandwidth, so the user
                // must be able to abort it like any other transfer.
                char waitText[512];
                _snprintf_s(waitText, _TRUNCATE, LoadStrU8(IDS_DOWNLOADINGFILE), file.Name); // feature 130: UTF-8 like the name
                SplU8TrimTornTail(waitText);
                SalamanderGeneral->CreateSafeWaitWindow(waitText, LoadStr(IDS_PLUGINNAME), 500, TRUE,
                                                        SalamanderGeneral->GetMainWindowHWND());
                for (;;)
                {
                    if (SalamanderGeneral->GetSafeWaitWindowClosePressed())
                    {
                        ok = FALSE; // '!newFileOK' below removes the partial cache entry
                        break;
                    }
                    __int64 n = Session.Read(h, buf, sizeof(buf));
                    if (n < 0)
                    {
                        ok = FALSE;
                        break;
                    }
                    if (n == 0)
                        break;
                    DWORD w = 0;
                    if (!WriteFile(lf, buf, (DWORD)n, &w, NULL) || w != (DWORD)n)
                    {
                        ok = FALSE; // disk full - do not register a truncated cache copy as valid
                        break;
                    }
                    total += n;
                }
                SalamanderGeneral->DestroySafeWaitWindow();
                Session.CloseHandle(h);
                newFileOK = ok;
                newFileSize.SetUI64((unsigned __int64)total);
            }
            CloseHandle(lf);
        }
    }

    HANDLE fileLock = NULL;
    BOOL fileLockOwner = FALSE;
    if (fileExists || newFileOK)
        salamander->OpenViewer(parent, cacheName, &fileLock, &fileLockOwner);
    salamander->FreeFileNameInCache(uniqueName, fileExists, newFileOK, newFileSize, fileLock, fileLockOwner, !newFileOK);
}

BOOL WINAPI CPluginFSInterface::Delete(const char* fsName, int mode, HWND parent, int panel,
                                       int selectedFiles, int selectedDirs, BOOL& cancelOrError)
{
    cancelOrError = FALSE;
    if (mode == 1)
        return FALSE; // let Salamander show the standard confirmation

    if (!EnsureConnected(parent))
    {
        cancelOrError = TRUE;
        return TRUE;
    }
    if (!SFTPDeleteFromPanel(parent, &Session, panel, Path))
        cancelOrError = TRUE;
    SalamanderGeneral->PostRefreshPanelFS(this, FALSE);
    return TRUE;
}

BOOL WINAPI CPluginFSInterface::CopyOrMoveFromFS(BOOL copy, int mode, const char* fsName, HWND parent,
                                                 int panel, int selectedFiles, int selectedDirs,
                                                 char* targetPath, BOOL& operationMask,
                                                 BOOL& cancelOrHandlePath, HWND dropTarget)
{
    operationMask = FALSE;
    cancelOrHandlePath = FALSE;

    if (mode == 1)
    {
        // suggest the other panel's path if it is a windows path
        return FALSE; // use the standard dialog with the suggested target
    }
    if (mode != 2 && mode != 3 && mode != 5)
        return FALSE;

    if (!EnsureConnected(parent))
    {
        cancelOrHandlePath = TRUE;
        return TRUE;
    }

    // only windows target paths are supported for download; mode 3 passes
    // "path\0mask\0" - the double-NUL leaves the directory part in localTarget
    // (the core's buffer for the target has 2 * MAX_PATH bytes, so it fits; feature 131: a
    // longer one is refused, a cut target would be another directory)
    char localTarget[2 * MAX_PATH];
    if (strlen(targetPath) >= sizeof(localTarget))
    {
        ShowTooLongPath(parent);
        cancelOrHandlePath = TRUE;
        return TRUE;
    }
    lstrcpynA(localTarget, targetPath, sizeof(localTarget));

    BOOL done = SFTPDownloadFromPanel(parent, &Session, panel, Path, localTarget, !copy);
    // feature 138: a move removes sources from the server also when it does not end whole - the
    // panel is refreshed either way (it kept showing items that were gone)
    if (!copy)
        SalamanderGeneral->PostRefreshPanelFS(this, FALSE);
    if (!done)
        cancelOrHandlePath = TRUE;
    return TRUE;
}

BOOL WINAPI CPluginFSInterface::CopyOrMoveFromDiskToFS(BOOL copy, int mode, const char* fsName, HWND parent,
                                                       const char* sourcePath, SalEnumSelection2 next,
                                                       void* nextParam, int sourceFiles, int sourceDirs,
                                                       char* targetPath, BOOL* invalidPathOrCancel)
{
    if (invalidPathOrCancel != NULL)
        *invalidPathOrCancel = FALSE;

    if (mode == 1)
    {
        // provide the current FS path (WITH the fs-name prefix) as the suggested
        // target for the standard Copy dialog - "user@host:.." alone is not a
        // valid FS path and the default target would be rejected
        // feature 131: a target that does not fit is not offered cut - the dialog then opens
        // with an empty target (FALSE in mode 1)
        char up[3072];
        if (!MakeUserPart(Path, up, sizeof(up)) || strlen(fsName) + 1 + strlen(up) >= 2 * MAX_PATH)
        {
            targetPath[0] = 0;
            return FALSE;
        }
        _snprintf_s(targetPath, 2 * MAX_PATH, _TRUNCATE, "%s:%s", fsName, up);
        return TRUE;
    }

    if (!EnsureConnected(parent))
    {
        if (invalidPathOrCancel != NULL)
            *invalidPathOrCancel = TRUE;
        return FALSE;
    }

    // parse the target FS path -> remote directory on THIS server
    char host[256], user[256], rpath[3072];
    int port;
    const char* up = targetPath;
    const char* colon = strchr(targetPath, ':');
    if (colon != NULL)
        up = colon + 1;
    if (!ParseUserPart(up, host, &port, user, rpath, sizeof(rpath)) ||
        _stricmp(host, Host) != 0 || port != Port || strcmp(user, User) != 0)
    {
        // CF-12: different server OR different user - do not silently run the
        // upload over this session under the wrong identity (mirror IsOurPath,
        // which also compares the user).
        return FALSE;
    }

    BOOL done = SFTPUploadToFS(parent, &Session, sourcePath, next, nextParam, rpath, !copy);
    // feature 139: an upload that did not end whole has put files on the server too - the
    // panel is refreshed either way (it showed nothing of them)
    SalamanderGeneral->PostRefreshPanelFS(this, FALSE);
    if (!done)
    {
        if (invalidPathOrCancel != NULL)
            *invalidPathOrCancel = TRUE;
        return FALSE;
    }
    return TRUE;
}

BOOL WINAPI CPluginFSInterface::ChangeAttributes(const char* fsName, HWND parent, int panel,
                                                 int selectedFiles, int selectedDirs)
{
    if (!EnsureConnected(parent))
        return FALSE;
    if (!SFTPChangeAttrsFromPanel(parent, &Session, panel, Path))
        return FALSE;
    SalamanderGeneral->PostRefreshPanelFS(this, FALSE);
    return TRUE;
}

void WINAPI CPluginFSInterface::GetAllowedDropEffects(int mode, const char* tgtFSPath, DWORD* allowedEffects)
{
    if (allowedEffects != NULL)
        *allowedEffects &= (DROPEFFECT_COPY | DROPEFFECT_MOVE);
}

// feature 018: private context-menu command ids (kept below the +5000 range
// used for Salamander standard commands so the two never collide)
#define CTXCMD_CHOWN 4001

void WINAPI CPluginFSInterface::ContextMenu(const char* fsName, HWND parent, int menuX, int menuY, int type,
                                            int panel, int selectedFiles, int selectedDirs)
{
    // feature 018: build a right-click menu for panel items. Mirrors the FTP
    // plugin: enumerate Salamander's standard panel commands (View/Copy/Move/
    // Delete/Rename/Change Attributes/...) with ids shifted by +5000, then append
    // our own "Change Owner/Group" item. Change Attributes appears automatically
    // because FS_SERVICE_CHANGEATTRS is set.
    if (type != fscmItemsInPanel)
        return; // path/panel menus not provided for now

    HMENU menu = CreatePopupMenu();
    if (menu == NULL)
        return;

    MENUITEMINFO mi;
    char nameBuf[200];
    BOOL isFocusedDir = FALSE;
    SalamanderGeneral->GetPanelFocusedItem(panel, &isFocusedDir);

    int i = 0;
    int index = 0, salCmd = 0, type2 = sctyUnknown, lastType = sctyUnknown;
    BOOL enabled = FALSE;
    while (SalamanderGeneral->EnumSalamanderCommands(&index, &salCmd, nameBuf, sizeof(nameBuf), &enabled, &type2))
    {
        if (!enabled || salCmd == SALCMD_OPEN || // "open" is not useful here (dirs open by Enter)
            (type2 == sctyForFocusedFile && isFocusedDir) ||
            (type2 != sctyForFocusedFile && type2 != sctyForFocusedFileOrDirectory &&
             type2 != sctyForSelectedFilesAndDirectories))
            continue;
        if (type2 != lastType && lastType != sctyUnknown) // separator between command groups
        {
            memset(&mi, 0, sizeof(mi));
            mi.cbSize = sizeof(mi);
            mi.fMask = MIIM_TYPE;
            mi.fType = MFT_SEPARATOR;
            InsertMenuItem(menu, i++, TRUE, &mi);
        }
        lastType = type2;
        memset(&mi, 0, sizeof(mi));
        mi.cbSize = sizeof(mi);
        mi.fMask = MIIM_TYPE | MIIM_ID | MIIM_STATE;
        mi.fType = MFT_STRING;
        mi.wID = salCmd + 5000;
        mi.dwTypeData = nameBuf;
        mi.cch = (UINT)strlen(nameBuf);
        mi.fState = MFS_ENABLED;
        InsertMenuItem(menu, i++, TRUE, &mi);
    }

    // our own Change Owner/Group item (after a separator)
    char chownItem[200];
    lstrcpynA(chownItem, LoadStr(IDS_MENU_CHOWN), sizeof(chownItem));
    if (i > 0)
    {
        memset(&mi, 0, sizeof(mi));
        mi.cbSize = sizeof(mi);
        mi.fMask = MIIM_TYPE;
        mi.fType = MFT_SEPARATOR;
        InsertMenuItem(menu, i++, TRUE, &mi);
    }
    memset(&mi, 0, sizeof(mi));
    mi.cbSize = sizeof(mi);
    mi.fMask = MIIM_TYPE | MIIM_ID | MIIM_STATE;
    mi.fType = MFT_STRING;
    mi.wID = CTXCMD_CHOWN;
    mi.dwTypeData = chownItem;
    mi.cch = (UINT)strlen(chownItem);
    mi.fState = MFS_ENABLED;
    InsertMenuItem(menu, i++, TRUE, &mi);

    DWORD cmd = TrackPopupMenuEx(menu, TPM_RETURNCMD | TPM_LEFTALIGN | TPM_RIGHTBUTTON,
                                 menuX, menuY, parent, NULL);
    DestroyMenu(menu);

    if (cmd >= 5000)
    {
        // a Salamander standard command (incl. Change Attributes) - let the core run it
        SalamanderGeneral->PostSalamanderCommand(cmd - 5000);
    }
    else if (cmd == CTXCMD_CHOWN)
    {
        if (EnsureConnected(parent) && SFTPChangeOwnerFromPanel(parent, &Session, panel, Path))
            SalamanderGeneral->PostRefreshPanelFS(this, FALSE);
    }
}
