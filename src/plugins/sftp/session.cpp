// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "sftp.h"
#include "sftputils.h"
#include "logs.h"
#include "hostkeys.h"
#include "dialogs.h"
#include "keyload.h"
#include "session.h"

// ---------------------------------------------------------------------------
// process-wide libssh2 lifecycle
// ---------------------------------------------------------------------------

static BOOL SSHInitialized = FALSE;
static BOOL WinsockInitialized = FALSE;

BOOL InitSSH()
{
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0)
        return FALSE;
    WinsockInitialized = TRUE;

    if (libssh2_init(0) != 0)
    {
        WSACleanup();
        WinsockInitialized = FALSE;
        return FALSE;
    }
    SSHInitialized = TRUE;
    return TRUE;
}

void ReleaseSSH()
{
    if (SSHInitialized)
    {
        libssh2_exit();
        SSHInitialized = FALSE;
    }
    if (WinsockInitialized)
    {
        WSACleanup();
        WinsockInitialized = FALSE;
    }
}

// ---------------------------------------------------------------------------
// CSFTPDirEntry
// ---------------------------------------------------------------------------

CSFTPDirEntry::CSFTPDirEntry()
{
    Name = NULL;
    Mode = 0;
    Size = 0;
    Uid = Gid = 0;
    Mtime = 0;
    Owner = NULL;
    Group = NULL;
    HasMode = HasSize = HasMtime = FALSE;
}

CSFTPDirEntry::~CSFTPDirEntry()
{
    if (Name != NULL)
        free(Name);
    if (Owner != NULL)
        free(Owner);
    if (Group != NULL)
        free(Group);
}

// ---------------------------------------------------------------------------
// keyboard-interactive single-prompt password callback (clarification #1)
// ---------------------------------------------------------------------------

static __declspec(thread) const char* g_kbdPassword = NULL;

extern "C" void kbd_callback(const char* name, int name_len,
                             const char* instruction, int instruction_len,
                             int num_prompts,
                             const LIBSSH2_USERAUTH_KBDINT_PROMPT* prompts,
                             LIBSSH2_USERAUTH_KBDINT_RESPONSE* responses,
                             void** abstract)
{
    (void)name;
    (void)name_len;
    (void)instruction;
    (void)instruction_len;
    (void)prompts;
    (void)abstract;
    // answer every prompt with the stored password; the common case is a single
    // "Password:" prompt on servers that only offer keyboard-interactive
    for (int i = 0; i < num_prompts; i++)
    {
        const char* pwd = g_kbdPassword != NULL ? g_kbdPassword : "";
        size_t len = strlen(pwd);
        responses[i].text = (char*)malloc(len + 1);
        if (responses[i].text != NULL)
        {
            memcpy(responses[i].text, pwd, len + 1);
            responses[i].length = (unsigned int)len;
        }
        else
            responses[i].length = 0;
    }
}

// ---------------------------------------------------------------------------
// CSFTPSession
// ---------------------------------------------------------------------------

CSFTPSession::CSFTPSession()
{
    Socket = INVALID_SOCKET;
    Ssh = NULL;
    Sftp = NULL;
    Connected = FALSE;
    LogUID = -1;
    LastErrorText[0] = 0;
    Prompt = cpNone;
    memset(&HostKeyInfo, 0, sizeof(HostKeyInfo));
    TrustHostKeyOnce = FALSE;
    ServerOffersPassword = FALSE;
    CancelRequested = 0;
    InitializeCriticalSection(&SocketLock);
}

CSFTPSession::~CSFTPSession()
{
    Disconnect();
    Params.WipeSecrets();
    DeleteCriticalSection(&SocketLock);
}

void CSFTPSession::Log(const char* text)
{
    if (LogUID >= 0)
        Logs.Append(LogUID, text);
}

void CSFTPSession::LogFmt(const char* fmt, ...)
{
    if (LogUID < 0)
        return;
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    int written = _vsnprintf_s(buf, _TRUNCATE, fmt, args);
    va_end(args);
    if (written < 0)
        SplU8TrimTornTail(buf); // feature 130: a cut inside a character would make the line invalid
    Log(buf);
}

void CSFTPSession::SetLastErrorFromSsh(const char* prefix)
{
    char* msg = NULL;
    int len = 0;
    if (Ssh != NULL)
        libssh2_session_last_error(Ssh, &msg, &len, 0);
    // feature 130: 'prefix' is UTF-8 (LoadStrU8) or ASCII; the library's text is made UTF-8
    _snprintf_s(LastErrorText, _TRUNCATE, "%s%s%s", prefix != NULL ? prefix : "",
                (prefix != NULL && prefix[0]) ? ": " : "",
                CSFTPMsgText((msg != NULL && msg[0] != 0) ? msg : "unknown error").Get()); // feature 133: also for an empty text
    SplU8TrimTornTail(LastErrorText);
    // feature 051 (U7): every failure funnels through here, so this is the one
    // place that reliably notices the transport died (Connect's own failures run
    // before Connected is set, so they cannot be misread as a lost session).
    NoteTransportError(0);
}

// feature 131: libssh2 reports every refusal by the server as one session error ("SFTP
// Protocol Error", "Failed opening remote file"); why the server refused is in the status
// code of the SFTP layer. The reason is a text of the plug-in where one says it, else
// "SFTP error <code>: <name>". Any other failure (transport, timeout, memory) keeps the
// session's text. UTF-8 like every writer of LastErrorText (feature 130).
void CSFTPSession::SetLastErrorFromSftp(const char* prefix)
{
    unsigned long code = LIBSSH2_FX_OK;
    if (Ssh != NULL && Sftp != NULL && libssh2_session_last_errno(Ssh) == LIBSSH2_ERROR_SFTP_PROTOCOL)
        code = libssh2_sftp_last_error(Sftp);
    if (code == LIBSSH2_FX_OK) // not a status of the server
    {
        SetLastErrorFromSsh(prefix);
        return;
    }
    int resID = 0;
    switch (code)
    {
    case LIBSSH2_FX_PERMISSION_DENIED:
    case LIBSSH2_FX_WRITE_PROTECT:
        resID = IDS_ERR_PERMDENIED;
        break;
    case LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM:
    case LIBSSH2_FX_QUOTA_EXCEEDED:
        resID = IDS_ERR_DISKFULL;
        break;
    case LIBSSH2_FX_NOT_A_DIRECTORY:
        resID = IDS_ERR_NOTADIR;
        break;
    }
    char reason[400];
    if (resID != 0)
        SplU8CopyTrunc(reason, sizeof(reason), LoadStrU8(resID));
    else
    {
        if (_snprintf_s(reason, _TRUNCATE, LoadStrU8(IDS_ERR_GENERIC), (int)code, SftpStatusName(code)) < 0)
            SplU8TrimTornTail(reason);
    }
    if (_snprintf_s(LastErrorText, _TRUNCATE, "%s%s%s", prefix != NULL ? prefix : "",
                    (prefix != NULL && prefix[0]) ? ": " : "", reason) < 0)
        SplU8TrimTornTail(LastErrorText);
}

BOOL CSFTPSession::SetLastErrorNotConnected()
{
    SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_NOTCONNECTED));
    return FALSE;
}

BOOL CSFTPSession::OpenSocket(CSFTPConnectResult* result)
{
    char portStr[16];
    _snprintf_s(portStr, _TRUNCATE, "%d", Params.Port);

    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    struct addrinfo* ai = NULL;
    if (getaddrinfo(Params.Host, portStr, &hints, &ai) != 0 || ai == NULL)
    {
        // feature 130: LastErrorText is UTF-8 (the host is; a code-page template made a mix)
        _snprintf_s(LastErrorText, _TRUNCATE, LoadStrU8(IDS_ERR_RESOLVE), Params.Host);
        SplU8TrimTornTail(LastErrorText);
        if (result != NULL)
            *result = crResolveFailed;
        return FALSE;
    }

    // feature 051 (U4): the connect timeout is a budget for the WHOLE candidate
    // list, not per address - a dual-stack host with several dead addresses used
    // to cost ConnectTimeoutSec each. The wait is sliced so a user cancel is
    // noticed promptly instead of after the full timeout (SC-004).
    //
    // feature 054: the candidates are now attempted with OVERLAP instead of
    // strictly one after another. The old loop waited on the current address
    // until the shared budget ran out and then abandoned the whole list, so a
    // single silently-dropped address (no RST, just nothing) made the host
    // unreachable even when a later address was answering immediately - the
    // reported "localhost times out but 127.0.0.1 connects" case, where the
    // IPv6 address is black-holed. Each candidate is now started a short delay
    // after the previous one WITHOUT giving up on it, every pending socket is
    // waited on together, and the first to complete wins (RFC 8305 "Happy
    // Eyeballs", which is what browsers do with dual-stack hosts). The budget
    // is still shared, so a host where every address is dead fails in the same
    // bounded time as before.
    const DWORD totalBudgetMs = (DWORD)(Params.ConnectTimeoutSec > 0 ? Params.ConnectTimeoutSec : 20) * 1000;
    const DWORD sliceMs = 250;   // also the cancel-poll cadence (see below)
    const DWORD staggerMs = 250; // delay before bringing the next candidate in
    const DWORD startTick = GetTickCount();

    // Pending candidates. FD_SETSIZE caps what one select() can watch; a host
    // with more addresses than that simply gets them in waves as earlier ones
    // drop out, which is still strictly better than the old behaviour.
    struct CCandidate
    {
        SOCKET Socket;
        const struct addrinfo* Addr;
    };
    CCandidate pending[FD_SETSIZE];
    int pendingCount = 0;

    SOCKET s = INVALID_SOCKET;
    const struct addrinfo* winner = NULL;
    struct addrinfo* next = ai; // the next candidate not yet started
    BOOL cancelled = FALSE;
    BOOL timedOut = FALSE;
    BOOL anyRefused = FALSE; // at least one candidate answered with an error
    DWORD lastStartTick = 0;

    while (s == INVALID_SOCKET && !cancelled && !timedOut)
    {
        DWORD now = GetTickCount();

        // (1) start the next candidate when it is due: immediately if nothing is
        //     pending (so a healthy host is as fast as it ever was), otherwise
        //     once the stagger has elapsed
        while (next != NULL && pendingCount < FD_SETSIZE &&
               (pendingCount == 0 || now - lastStartTick >= staggerMs))
        {
            struct addrinfo* p = next;
            next = next->ai_next;
            SOCKET cand = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
            if (cand == INVALID_SOCKET)
                continue;
            u_long nonblock = 1;
            ioctlsocket(cand, FIONBIO, &nonblock);
            lastStartTick = now;
            int cr = connect(cand, p->ai_addr, (int)p->ai_addrlen);
            if (cr == 0) // connected straight away
            {
                s = cand;
                winner = p;
                break;
            }
            if (WSAGetLastError() != WSAEWOULDBLOCK)
            {
                closesocket(cand); // refused or unusable - not worth waiting on
                anyRefused = TRUE;
                continue;
            }
            pending[pendingCount].Socket = cand;
            pending[pendingCount].Addr = p;
            pendingCount++;
        }
        if (s != INVALID_SOCKET)
            break;

        if (pendingCount == 0 && next == NULL)
            break; // every candidate has been tried and none is still pending

        // (2) wait on ALL pending candidates at once, in short slices. The slice
        //     is what keeps cancellation prompt: RequestCancel can only shut
        //     down the session's member socket, which does not exist yet here,
        //     so polling is the only way a cancel is noticed during connect.
        if (IsCancelRequested())
        {
            cancelled = TRUE;
            break;
        }
        DWORD elapsed = GetTickCount() - startTick;
        if (elapsed >= totalBudgetMs)
        {
            timedOut = TRUE;
            break;
        }
        DWORD remaining = totalBudgetMs - elapsed;
        DWORD waitMs = remaining < sliceMs ? remaining : sliceMs;
        if (next != NULL && waitMs > staggerMs)
            waitMs = staggerMs; // wake up in time to start the next candidate

        fd_set wfds, efds;
        FD_ZERO(&wfds);
        FD_ZERO(&efds);
        for (int i = 0; i < pendingCount; i++)
        {
            FD_SET(pending[i].Socket, &wfds);
            FD_SET(pending[i].Socket, &efds);
        }
        struct timeval tv;
        tv.tv_sec = (long)(waitMs / 1000);
        tv.tv_usec = (long)((waitMs % 1000) * 1000);
        int sel = select(0, NULL, &wfds, &efds, &tv);
        if (sel <= 0)
            continue; // slice expired (or select failed) - keep waiting / start the next

        // (3) collect the results: the first candidate that reports success wins,
        //     the ones that report an error are dropped from the pending set
        for (int i = 0; i < pendingCount;)
        {
            SOCKET cand = pending[i].Socket;
            if (!FD_ISSET(cand, &wfds) && !FD_ISSET(cand, &efds))
            {
                i++;
                continue;
            }
            int soErr = 0;
            int soLen = sizeof(soErr);
            getsockopt(cand, SOL_SOCKET, SO_ERROR, (char*)&soErr, &soLen);
            if (soErr == 0 && s == INVALID_SOCKET)
            {
                s = cand;
                winner = pending[i].Addr;
            }
            else
            {
                closesocket(cand);
                anyRefused = TRUE;
            }
            pending[i] = pending[--pendingCount]; // drop it from the pending set
        }
    }

    // Close every candidate that lost the race - nothing else will collect them
    // (Disconnect only ever closes the session's own socket).
    for (int i = 0; i < pendingCount; i++)
    {
        if (pending[i].Socket != s)
            closesocket(pending[i].Socket);
    }
    pendingCount = 0;

    if (s != INVALID_SOCKET && winner != NULL)
    {
        // The address that answered is worth recording: this loop used to log
        // nothing, which is why a host whose first address was black-holed
        // looked like a plain timeout.
        char addrText[NI_MAXHOST] = "";
        if (getnameinfo(winner->ai_addr, (socklen_t)winner->ai_addrlen, addrText,
                        sizeof(addrText), NULL, 0, NI_NUMERICHOST) != 0)
            addrText[0] = 0;
        LogFmt("Connected to %s:%d", addrText[0] != 0 ? addrText : Params.Host, Params.Port);
    }

    // feature 051 (D4/F3): the winning socket deliberately STAYS non-blocking.
    // With a blocking OS socket, libssh2's blocking API never enters
    // _libssh2_wait_socket, so libssh2_session_set_timeout is not enforced and
    // recv() can block forever on a black-holed connection. Keeping the socket
    // non-blocking makes every later libssh2 call honour that timeout.

    // freeaddrinfo only after the loop is done with the addresses: a pending
    // candidate holds a pointer into this list for the whole wait.
    freeaddrinfo(ai);
    winner = NULL; // dangling past freeaddrinfo - do not use below

    if (s == INVALID_SOCKET)
    {
        if (cancelled)
        {
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_CANCELLED));
            if (result != NULL)
                *result = crCancelled;
            return FALSE;
        }
        // feature 054: a budget that ran out is only a timeout when nothing ever
        // answered. If some address did answer - with a refusal - that is the more
        // useful thing to tell the user, even if a different address was still
        // being waited on when the budget expired.
        if (timedOut && !anyRefused)
        {
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_TIMEOUT));
            if (result != NULL)
                *result = crTimeout;
            return FALSE;
        }
        _snprintf_s(LastErrorText, _TRUNCATE, LoadStrU8(IDS_ERR_CONNECT), Params.Host, Params.Port);
        SplU8TrimTornTail(LastErrorText);
        if (result != NULL)
            *result = crConnectFailed;
        return FALSE;
    }
    EnterCriticalSection(&SocketLock);
    Socket = s;
    LeaveCriticalSection(&SocketLock);
    // A cancel that arrived while the socket was being created would have found
    // no socket to shut down - honour it here instead of starting the handshake.
    if (IsCancelRequested())
    {
        SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_CANCELLED));
        if (result != NULL)
            *result = crCancelled;
        return FALSE;
    }
    return TRUE;
}

// feature 051 (FR-003/SC-004): abort whatever the session is waiting for.
// Closing the socket is the only reliable way to make an in-flight libssh2
// blocking call return at once; the worker then unwinds through its normal
// error paths.
void CSFTPSession::RequestCancel()
{
    InterlockedExchange(&CancelRequested, 1);
    EnterCriticalSection(&SocketLock);
    if (Socket != INVALID_SOCKET)
        shutdown(Socket, SD_BOTH); // wakes a pending recv/send; handle stays valid
    LeaveCriticalSection(&SocketLock);
}

BOOL CSFTPSession::EvaluateHostKey(CSFTPHostKeyList* trustStore, CSFTPConnectResult* result)
{
    size_t keyLen = 0;
    int keyType = 0;
    const char* keyBlob = libssh2_session_hostkey(Ssh, &keyLen, &keyType);
    if (keyBlob == NULL || keyLen == 0)
    {
        lstrcpynA(LastErrorText, "Server did not present a host key.", sizeof(LastErrorText));
        if (result != NULL)
            *result = crHostKeyRejected;
        return FALSE;
    }

    const char* typeName = "ssh-unknown";
    switch (keyType)
    {
    case LIBSSH2_HOSTKEY_TYPE_RSA:
        typeName = "ssh-rsa";
        break;
    case LIBSSH2_HOSTKEY_TYPE_DSS:
        typeName = "ssh-dss";
        break;
    case LIBSSH2_HOSTKEY_TYPE_ECDSA_256:
        typeName = "ecdsa-sha2-nistp256";
        break;
    case LIBSSH2_HOSTKEY_TYPE_ECDSA_384:
        typeName = "ecdsa-sha2-nistp384";
        break;
    case LIBSSH2_HOSTKEY_TYPE_ECDSA_521:
        typeName = "ecdsa-sha2-nistp521";
        break;
    case LIBSSH2_HOSTKEY_TYPE_ED25519:
        typeName = "ssh-ed25519";
        break;
    }

    char* keyB64 = Base64Encode((const unsigned char*)keyBlob, (int)keyLen);
    if (keyB64 == NULL)
    {
        if (result != NULL)
            *result = crHostKeyRejected;
        return FALSE;
    }

    char fingerprint[128];
    BOOL haveFingerprint = FALSE;
    const char* sha = libssh2_hostkey_hash(Ssh, LIBSSH2_HOSTKEY_HASH_SHA256);
    if (sha != NULL)
    {
        FormatSHA256Fingerprint((const unsigned char*)sha, fingerprint, sizeof(fingerprint));
        haveFingerprint = TRUE;
    }
    else
        lstrcpynA(fingerprint, "SHA256:?", sizeof(fingerprint));

    char storedFp[128];
    storedFp[0] = 0;
    CSFTPHostKeyMatch m = trustStore->Match(Params.Host, Params.Port, keyB64, storedFp, sizeof(storedFp));

    BOOL ok = FALSE;
    if (m == hkmMatch)
    {
        LogFmt("Host key verified (%s %s).", typeName, fingerprint);
        ok = TRUE;
    }
    else
    {
        // CF-21: an unknown or changed key must be verifiable out-of-band by the
        // user. If no SHA-256 fingerprint could be computed, fail closed instead
        // of asking the user to trust "SHA256:?". (An exact blob match above needs
        // no fingerprint, so this only blocks the interactive trust path.)
        if (!haveFingerprint)
        {
            lstrcpynA(LastErrorText,
                      "Cannot verify the server's host key: no fingerprint available.",
                      sizeof(LastErrorText));
            if (result != NULL)
                *result = crHostKeyRejected;
            free(keyB64);
            return FALSE;
        }
        if (TrustHostKeyOnce)
        {
            // The user already confirmed this key on the UI thread for the current
            // connect (feature 051: the worker re-runs the attempt afterwards).
            LogFmt("Host key %s (%s) accepted by the user.", typeName, fingerprint);
            ok = TRUE;
        }
        else
        {
            // feature 051 (D4): no dialogs on the worker thread - hand the decision
            // to the UI thread, which prompts and retries the attempt.
            HostKeyInfo.Changed = (m == hkmMismatch);
            lstrcpynA(HostKeyInfo.TypeName, typeName, sizeof(HostKeyInfo.TypeName));
            lstrcpynA(HostKeyInfo.Fingerprint, fingerprint, sizeof(HostKeyInfo.Fingerprint));
            lstrcpynA(HostKeyInfo.StoredFingerprint, (m == hkmMismatch) ? storedFp : "",
                      sizeof(HostKeyInfo.StoredFingerprint));
            lstrcpynA(HostKeyInfo.KeyB64, keyB64, sizeof(HostKeyInfo.KeyB64));
            Prompt = cpHostKey;
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_HOSTKEYDECLINED));
            if (result != NULL)
                *result = crHostKeyRejected;
        }
    }
    free(keyB64);
    return ok;
}

// CF-9: read a whole file (given a UTF-8 path) into a heap buffer via the W file
// API, so non-ASCII / long private-key paths work (libssh2's *_fromfile opens
// via the ANSI CRT, which mangles such paths). Returns TRUE with *data/*len set;
// the caller frees *data (and should wipe it - it holds private-key bytes).
static BOOL ReadKeyFileU8(const char* u8path, char** data, DWORD* len)
{
    *data = NULL;
    *len = 0;
    WCHAR* w = SplU8ToWExtAlloc(u8path);
    if (w == NULL)
        return FALSE;
    HANDLE h = CreateFileW(w, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                           FILE_ATTRIBUTE_NORMAL, NULL);
    free(w);
    if (h == INVALID_HANDLE_VALUE)
        return FALSE;
    LARGE_INTEGER size;
    if (!GetFileSizeEx(h, &size) || size.QuadPart <= 0 || size.QuadPart > (64 * 1024 * 1024))
    {
        CloseHandle(h);
        return FALSE;
    }
    DWORD n = (DWORD)size.QuadPart;
    char* buf = (char*)malloc(n);
    if (buf == NULL)
    {
        CloseHandle(h);
        return FALSE;
    }
    DWORD got = 0;
    BOOL ok = ReadFile(h, buf, n, &got, NULL) && got == n;
    CloseHandle(h);
    if (!ok)
    {
        // CF-14 / feature 051 (U9): the buffer may already hold part of the
        // private key - wipe before releasing it, like the success path does.
        SecureZeroMemory(buf, n);
        free(buf);
        return FALSE;
    }
    *data = buf;
    *len = n;
    return TRUE;
}

// feature 051 (U8): classify an authentication failure by the libssh2 error
// CODE, not by substring-matching the message. The old heuristics were
// case-sensitive ("unable to" never matched libssh2's "Unable to ..."), so a
// key that could not be loaded was reported as "server rejected the key".
enum CSFTPAuthFailure
{
    afKeySide,    // key could not be read/parsed/decrypted - our side
    afServerSide, // the key was sent and the server refused it
    afTransport,  // connection-level problem
};

static CSFTPAuthFailure ClassifyAuthFailure(int rc, int lastErrno)
{
    int code = (rc != 0) ? rc : lastErrno;
    switch (code)
    {
    case LIBSSH2_ERROR_FILE:
    case LIBSSH2_ERROR_KEYFILE_AUTH_FAILED:
    case LIBSSH2_ERROR_METHOD_NOT_SUPPORTED:
    case LIBSSH2_ERROR_DECRYPT:
    case LIBSSH2_ERROR_ALLOC:
        return afKeySide;
    case LIBSSH2_ERROR_SOCKET_SEND:
    case LIBSSH2_ERROR_SOCKET_RECV:
    case LIBSSH2_ERROR_SOCKET_TIMEOUT:
    case LIBSSH2_ERROR_SOCKET_DISCONNECT:
    case LIBSSH2_ERROR_TIMEOUT:
        return afTransport;
    case LIBSSH2_ERROR_AUTHENTICATION_FAILED:
    case LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED:
    default:
        return afServerSide;
    }
}

BOOL CSFTPSession::Authenticate(HWND parent, CSFTPConnectResult* result)
{
    // discover which methods the server offers
    char* authList = libssh2_userauth_list(Ssh, Params.User, (unsigned int)strlen(Params.User));
    BOOL hasPassword = authList != NULL && strstr(authList, "password") != NULL;
    BOOL hasKbd = authList != NULL && strstr(authList, "keyboard-interactive") != NULL;
    BOOL hasPublicKey = authList != NULL && strstr(authList, "publickey") != NULL;

    if (Params.AuthMethod == saPrivateKey)
    {
        if (!hasPublicKey && authList != NULL)
        {
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_NOAUTHMETHOD));
            if (result != NULL)
                *result = crNoAuthMethod;
            return FALSE;
        }
        // CF-9: the key path is UTF-8; check existence via the W API (the ANSI
        // one mangles non-ACP paths and would falsely report "not found").
        WCHAR* wKeyFile = SplU8ToWExtAlloc(Params.KeyFile);
        BOOL keyExists = wKeyFile != NULL && GetFileAttributesW(wKeyFile) != INVALID_FILE_ATTRIBUTES;
        free(wKeyFile);
        if (!keyExists)
        {
            _snprintf_s(LastErrorText, _TRUNCATE, LoadStrU8(IDS_ERR_KEYFILEMISSING), Params.KeyFile);
            SplU8TrimTornTail(LastErrorText);
            if (result != NULL)
                *result = crKeyFileMissing;
            return FALSE;
        }
        // feature 017 (K1) / feature 051 (FR-007): reject a key file this build
        // cannot use up front - format AND, for OpenSSH containers, the algorithm
        // inside - instead of handing it to libssh2 and surfacing a cryptic
        // low-level error (or, before the pem.c fix, hanging on it).
        int keyReason = 0;
        char keyType[64] = "";
        if (!KeyFileSupported(Params.KeyFile, &keyReason, keyType, sizeof(keyType)))
        {
            if (keyReason == IDS_ERR_KEYTYPEUNSUP && keyType[0] != 0)
                _snprintf_s(LastErrorText, _TRUNCATE, LoadStrU8(keyReason), keyType); // keyType: ASCII, from the key file's header
            else
                SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText),
                               LoadStrU8(keyReason != 0 ? keyReason : IDS_ERR_AUTHKEY));
            if (result != NULL)
                *result = crAuthKey;
            return FALSE;
        }
        // CF-9: load the key bytes via the W API and authenticate from memory so
        // non-ASCII / long key paths work (libssh2's *_fromfile uses ACP fopen).
        // libssh2 derives the public key from the private key (pubkey data NULL).
        char* keyData = NULL;
        DWORD keyDataLen = 0;
        if (!ReadKeyFileU8(Params.KeyFile, &keyData, &keyDataLen))
        {
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_AUTHKEY));
            if (result != NULL)
                *result = crAuthKey;
            return FALSE;
        }

        int rc = libssh2_userauth_publickey_frommemory(
            Ssh, Params.User, strlen(Params.User), NULL, 0, keyData, keyDataLen,
            Params.Passphrase[0] ? Params.Passphrase : NULL);
        SecureZeroMemory(keyData, keyDataLen); // wipe private-key bytes
        free(keyData);
        if (rc == 0)
        {
            Log("Authenticated with private key.");
            return TRUE;
        }

        // feature 051: this runs on the connect worker, so it never prompts - it
        // classifies the failure and tells the UI thread what to ask for (D5).
        CSFTPAuthFailure failure = ClassifyAuthFailure(rc, libssh2_session_last_errno(Ssh));
        if (failure == afKeySide)
        {
            // FR-005: a key that cannot be decrypted is not a rejected key.
            Log("Private key could not be loaded or unlocked.");
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_KEYUNLOCK));
            if (result != NULL)
                *result = crKeyUnlock;
            if (KeyFileLooksEncrypted(Params.KeyFile))
                Prompt = cpPassphrase; // ask for the passphrase and retry
            return FALSE;
        }
        if (failure == afTransport)
        {
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_CONNLOST));
            if (result != NULL)
                *result = crTimeout;
            return FALSE;
        }

        // FR-006: the server refused the key. When it also offers password
        // authentication, the UI thread offers that instead of sending the user
        // back into the connection profile.
        Log("Server rejected the private key.");
        SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_AUTHKEY));
        if (result != NULL)
            *result = crAuthKey;
        if (hasPassword)
        {
            ServerOffersPassword = TRUE;
            Prompt = cpPassword;
        }
        return FALSE;
    }

    // password method: try plain password, then single-prompt keyboard-interactive
    if (hasPassword || authList == NULL)
    {
        int rc = libssh2_userauth_password_ex(Ssh, Params.User, (unsigned int)strlen(Params.User),
                                              Params.Password, (unsigned int)strlen(Params.Password), NULL);
        if (rc == 0)
        {
            Log("Authenticated with password.");
            return TRUE;
        }
    }
    if (hasKbd)
    {
        g_kbdPassword = Params.Password;
        int rc = libssh2_userauth_keyboard_interactive_ex(Ssh, Params.User,
                                                          (unsigned int)strlen(Params.User), &kbd_callback);
        g_kbdPassword = NULL;
        if (rc == 0)
        {
            Log("Authenticated with keyboard-interactive.");
            return TRUE;
        }
    }

    SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_AUTHPASSWORD));
    if (result != NULL)
        *result = crAuthPassword;
    return FALSE;
}

// CF-4: pin modern algorithms so deprecated ones (arcfour/RC4, 3des-cbc,
// diffie-hellman-group1-sha1, hmac-md5, hmac-sha1, ssh-rsa/SHA-1, ssh-dss) are
// never negotiated - even against a server that only offers them. Each list
// keeps the interoperability floor (ecdh + DH group14/16/18, chacha20/AES-CTR,
// HMAC-SHA2, ecdsa/rsa-sha2). Non-fatal: libssh2 filters each list against the
// compiled-in methods and, if a whole list ends up unsupported, that method
// type simply keeps its library default.
static void ApplyAlgorithmPreferences(LIBSSH2_SESSION* ssh)
{
    libssh2_session_method_pref(ssh, LIBSSH2_METHOD_KEX,
                                "ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,"
                                "diffie-hellman-group-exchange-sha256,"
                                "diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,"
                                "diffie-hellman-group14-sha256");
    const char* ciphers = "chacha20-poly1305@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr";
    libssh2_session_method_pref(ssh, LIBSSH2_METHOD_CRYPT_CS, ciphers);
    libssh2_session_method_pref(ssh, LIBSSH2_METHOD_CRYPT_SC, ciphers);
    const char* macs = "hmac-sha2-256,hmac-sha2-512";
    libssh2_session_method_pref(ssh, LIBSSH2_METHOD_MAC_CS, macs);
    libssh2_session_method_pref(ssh, LIBSSH2_METHOD_MAC_SC, macs);
    libssh2_session_method_pref(ssh, LIBSSH2_METHOD_HOSTKEY,
                                "ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,"
                                "rsa-sha2-256,rsa-sha2-512");
}

// feature 051 (D4): one complete NON-INTERACTIVE connect attempt. Runs on the
// connect worker thread, so it must never show UI: when the user has to decide
// something it stops and sets 'Prompt', and the UI thread retries the attempt
// with the answer applied.
BOOL CSFTPSession::ConnectAttempt(CSFTPHostKeyList* trustStore, CSFTPConnectResult* result)
{
    if (result != NULL)
        *result = crOk;
    Prompt = cpNone;
    ServerOffersPassword = FALSE;

    LogFmt("Connecting to %s:%d as %s ...", Params.Host, Params.Port, Params.User);

    if (!OpenSocket(result))
    {
        Log(LastErrorText);
        return FALSE;
    }

    Ssh = libssh2_session_init_ex(NULL, NULL, NULL, this);
    if (Ssh == NULL)
    {
        lstrcpynA(LastErrorText, "Cannot create SSH session.", sizeof(LastErrorText));
        Disconnect();
        return FALSE;
    }
    libssh2_session_set_blocking(Ssh, 1);
    long timeoutMs = (Params.OperationTimeoutSec > 0 ? Params.OperationTimeoutSec : 30) * 1000L;
    libssh2_session_set_timeout(Ssh, timeoutMs);

    ApplyAlgorithmPreferences(Ssh);

    // CF-27: honor the user's compression setting (previously a dead option -
    // the flag was never applied). Must be set before the handshake.
    if (Params.UseCompression)
        libssh2_session_flag(Ssh, LIBSSH2_FLAG_COMPRESS, 1);

    if (libssh2_session_handshake(Ssh, Socket) != 0)
    {
        SetLastErrorFromSsh(LoadStrU8(IDS_ERR_HANDSHAKE));
        Log(LastErrorText);
        if (result != NULL)
            *result = crHandshakeFailed;
        Disconnect();
        return FALSE;
    }

    if (!EvaluateHostKey(trustStore, result))
    {
        Log(LastErrorText);
        Disconnect();
        return FALSE;
    }

    if (!Authenticate(NULL, result))
    {
        Log(LastErrorText);
        Disconnect();
        return FALSE;
    }

    Sftp = libssh2_sftp_init(Ssh);
    if (Sftp == NULL)
    {
        SetLastErrorFromSsh(LoadStrU8(IDS_ERR_SFTPINIT));
        Log(LastErrorText);
        if (result != NULL)
            *result = crSFTPInitFailed;
        Disconnect();
        return FALSE;
    }

    if (Params.KeepAliveSec > 0)
        libssh2_keepalive_config(Ssh, 1, Params.KeepAliveSec);

    Connected = TRUE;
    Log("SFTP session established.");
    return TRUE;
}

// ---------------------------------------------------------------------------
// feature 051 (D4): connect on a worker thread, prompt+decide on the UI thread
// ---------------------------------------------------------------------------

struct CSFTPConnectThreadCtx
{
    CSFTPSession* Session;
    CSFTPHostKeyList* TrustStore;
    CSFTPConnectResult Result;
    BOOL Ok;
};

unsigned __stdcall SFTPConnectThreadProc(void* param)
{
    CSFTPConnectThreadCtx* ctx = (CSFTPConnectThreadCtx*)param;
    CALL_STACK_MESSAGE_NONE
    ctx->Ok = ctx->Session->ConnectAttempt(ctx->TrustStore, &ctx->Result);
    return 0;
}

// Runs one attempt on a worker thread. The UI thread shows the plugin's standard
// wait window and polls its Close button; pressing it cancels the attempt by
// shutting the socket down, so a stalled server can no longer freeze the app
// (FR-002) and cancel takes effect in about a second (SC-004).
BOOL CSFTPSession::RunConnectAttemptOnWorker(HWND parent, CSFTPHostKeyList* trustStore,
                                             CSFTPConnectResult* result)
{
    InterlockedExchange(&CancelRequested, 0);

    CSFTPConnectThreadCtx ctx;
    ctx.Session = this;
    ctx.TrustStore = trustStore;
    ctx.Result = crOk;
    ctx.Ok = FALSE;

    uintptr_t th = _beginthreadex(NULL, 0, SFTPConnectThreadProc, &ctx, 0, NULL);
    if (th == 0)
    {
        // cannot spawn the worker - fall back to a direct attempt so the feature
        // still works (it is then as blocking as it was before this change)
        return ConnectAttempt(trustStore, result);
    }

    HANDLE hThread = (HANDLE)th;
    char waitText[512];
    _snprintf_s(waitText, _TRUNCATE, LoadStrU8(IDS_CONNECTING), Params.Host); // feature 130: UTF-8 like the host
    SplU8TrimTornTail(waitText);
    SalamanderGeneral->CreateSafeWaitWindow(waitText, LoadStr(IDS_PLUGINNAME), 500, TRUE,
                                            SalamanderGeneral->GetMainWindowHWND());
    for (;;)
    {
        if (WaitForSingleObject(hThread, 100) == WAIT_OBJECT_0)
            break;
        if (SalamanderGeneral->GetSafeWaitWindowClosePressed())
        {
            if (!IsCancelRequested())
                Log("Connect cancelled by the user.");
            // Re-issued every poll: the socket may not have existed yet when the
            // first cancel arrived (worker still resolving/connecting).
            RequestCancel();
        }
    }
    SalamanderGeneral->DestroySafeWaitWindow();
    ::CloseHandle(hThread); // the Win32 one - CSFTPSession has its own CloseHandle

    if (result != NULL)
        *result = ctx.Result;
    if (!ctx.Ok && IsCancelRequested())
    {
        SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_CANCELLED));
        if (result != NULL)
            *result = crCancelled;
    }
    (void)parent;
    return ctx.Ok;
}

// UI-side orchestrator: repeats the non-interactive attempt, servicing whatever
// the previous one asked the user for (host key, passphrase, password fallback).
// Every dialog is shown here, on the UI thread; the worker never prompts.
BOOL CSFTPSession::Connect(HWND parent, const CSFTPConnectParams* params,
                           CSFTPHostKeyList* trustStore, CSFTPConnectResult* result)
{
    if (params != NULL && params != &Params)
        Params = *params;

    TrustHostKeyOnce = FALSE;
    const int MAX_ROUNDS = 5; // host key + passphrase retries + password fallback
    for (int round = 0; round < MAX_ROUNDS; round++)
    {
        CSFTPConnectResult res = crOk;
        if (RunConnectAttemptOnWorker(parent, trustStore, &res))
        {
            if (result != NULL)
                *result = crOk;
            return TRUE;
        }
        if (result != NULL)
            *result = res;
        if (res == crCancelled || Prompt == cpNone || parent == NULL)
            return FALSE;

        if (Prompt == cpHostKey)
        {
            int choice = ShowHostKeyDialog(parent, HostKeyInfo.Changed, Params.Host, Params.Port,
                                           HostKeyInfo.TypeName, HostKeyInfo.Fingerprint,
                                           HostKeyInfo.Changed ? HostKeyInfo.StoredFingerprint : NULL);
            if (choice == IDB_HOSTKEY_TRUST)
            {
                trustStore->Trust(Params.Host, Params.Port, HostKeyInfo.TypeName,
                                  HostKeyInfo.KeyB64, HostKeyInfo.Fingerprint);
                LogFmt("Host key %s (%s) accepted and stored.", HostKeyInfo.TypeName,
                       HostKeyInfo.Fingerprint);
            }
            else if (choice != IDB_HOSTKEY_ONCE)
            {
                Log("Host key rejected by user - connection aborted.");
                SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_ERR_HOSTKEYDECLINED));
                if (result != NULL)
                    *result = crHostKeyRejected;
                return FALSE;
            }
            TrustHostKeyOnce = TRUE; // accepted for the remainder of this connect
            continue;
        }

        if (Prompt == cpPassphrase)
        {
            // FR-005: the key could not be unlocked - ask again and retry.
            char prompt[1024];
            _snprintf_s(prompt, _TRUNCATE,
                        LoadStrU8(Params.Passphrase[0] ? IDS_ENTERPASSPHRASE_RETRY : IDS_ENTERPASSPHRASE),
                        Params.KeyFile);
            SplU8TrimTornTail(prompt);
            SecureZeroMemory(Params.Passphrase, sizeof(Params.Passphrase));
            if (!ShowPasswordPrompt(parent, prompt, Params.Passphrase, sizeof(Params.Passphrase)))
                return FALSE; // cancelled: keep the key-unlock error
            continue;
        }

        if (Prompt == cpPassword)
        {
            // FR-006: the server refused the key but offers password auth.
            char prompt[512];
            _snprintf_s(prompt, _TRUNCATE, LoadStrU8(IDS_ENTERPASSWORD), Params.User);
            SplU8TrimTornTail(prompt);
            SecureZeroMemory(Params.Password, sizeof(Params.Password));
            if (!ShowPasswordPrompt(parent, prompt, Params.Password, sizeof(Params.Password)))
                return FALSE; // declined: the attempt ends with the key error
            Params.AuthMethod = saPassword;
            continue;
        }
        return FALSE;
    }
    return FALSE;
}

BOOL CSFTPSession::Reconnect(HWND parent, CSFTPHostKeyList* trustStore, CSFTPConnectResult* result)
{
    Disconnect();
    LogFmt(LoadStrU8(IDS_RECONNECTING), Params.Host); // feature 130: the log is one UTF-8 text
    return Connect(parent, &Params, trustStore, result);
}

void CSFTPSession::Disconnect()
{
    // feature 051 (U5): tearing a session down talks to the server three times
    // (sftp_shutdown, session_disconnect, session_free). On a host that went
    // silent each of those used to wait out the full operation timeout, so
    // closing a panel could stall for a minute and a half. Give teardown a short
    // deadline - and none at all once the session is known dead or cancelled.
    if (Ssh != NULL)
    {
        long teardownMs = (Connected && !IsCancelRequested()) ? 2000L : 1L;
        libssh2_session_set_timeout(Ssh, teardownMs);
    }
    if (Sftp != NULL)
    {
        libssh2_sftp_shutdown(Sftp);
        Sftp = NULL;
    }
    if (Ssh != NULL)
    {
        libssh2_session_disconnect(Ssh, "Bye");
        libssh2_session_free(Ssh);
        Ssh = NULL;
    }
    EnterCriticalSection(&SocketLock);
    if (Socket != INVALID_SOCKET)
    {
        closesocket(Socket);
        Socket = INVALID_SOCKET;
    }
    LeaveCriticalSection(&SocketLock);
    Connected = FALSE;
}

BOOL CSFTPSession::RealPath(const char* path, char* absPath, int absPathSize)
{
    if (Sftp == NULL)
        return FALSE;
    // libssh2 does not NUL-terminate; reserve a byte and always terminate
    int rc = libssh2_sftp_realpath(Sftp, path, absPath, absPathSize - 1);
    if (rc <= 0)
    {
        // fall back to the requested path
        lstrcpynA(absPath, (path != NULL && path[0]) ? path : "/", absPathSize);
        return path != NULL && path[0] != 0;
    }
    if (rc >= absPathSize)
        rc = absPathSize - 1;
    absPath[rc] = 0;
    return TRUE;
}

#ifdef _DEBUG
// feature 133, probe seam (debug builds only): TC_SFTP_PROBE_LIST_FAIL = "<suffix>;<entry>;<times>"
// makes the read of the <entry>-th name (counted without "." and "..") of a directory whose
// path ends with <suffix> fail, for the first <times> listings of such a directory in this
// process. Returns the entry number to fail at, or 0.
static int ProbeListFailAt(const char* path)
{
    static int timesLeft = -1; // -1 = the variable was not read yet
    static char suffix[200];
    static int entry = 0;
    if (timesLeft == -1)
    {
        char buf[300];
        timesLeft = 0;
        DWORD n = GetEnvironmentVariableA("TC_SFTP_PROBE_LIST_FAIL", buf, sizeof(buf));
        if (n > 0 && n < sizeof(buf))
        {
            char* s1 = strchr(buf, ';');
            char* s2 = s1 != NULL ? strchr(s1 + 1, ';') : NULL;
            if (s2 != NULL && (size_t)(s1 - buf) < sizeof(suffix))
            {
                *s1 = 0;
                lstrcpynA(suffix, buf, sizeof(suffix));
                entry = atoi(s1 + 1);
                timesLeft = atoi(s2 + 1);
            }
        }
    }
    if (timesLeft <= 0 || entry <= 0)
        return 0;
    size_t pl = strlen(path), sl = strlen(suffix);
    if (pl < sl || strcmp(path + pl - sl, suffix) != 0)
        return 0;
    timesLeft--;
    return entry;
}
#endif // _DEBUG

BOOL CSFTPSession::ListDir(const char* path, TIndirectArray<CSFTPDirEntry>* entries, volatile BOOL* cancel)
{
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
#ifdef _DEBUG
    int probeFailAt = ProbeListFailAt(path);
    int probeRead = 0;
#endif

    LIBSSH2_SFTP_HANDLE* dir = libssh2_sftp_opendir(Sftp, path);
    if (dir == NULL)
    {
        SetLastErrorFromSftp("opendir");
        return FALSE;
    }

    char nameBuf[2048];
    char longEntry[2048];
    LIBSSH2_SFTP_ATTRIBUTES attrs;
    // feature 133: the listing is complete only when the server said "no more entries". A
    // failed read and low memory used to leave the loop like the end of the directory did -
    // the part read so far was returned as the whole directory. A stop asked by the user
    // stays what it was: TRUE with the caller's 'cancel' set (every caller looks at it).
    BOOL complete = FALSE;
    BOOL stopped = FALSE;
    for (;;)
    {
        if (cancel != NULL && *cancel)
        {
            stopped = TRUE;
            break;
        }
        // also honor the safe-wait-window Close button so huge listings can be
        // aborted (GetSafeWaitWindowClosePressed is FALSE when no window is up)
        if (SalamanderGeneral->GetSafeWaitWindowClosePressed())
        {
            if (cancel != NULL)
                *cancel = TRUE;
            stopped = TRUE;
            break;
        }
        memset(&attrs, 0, sizeof(attrs));
        // CF-13: readdir_ex returns the NAME length only, not the longentry
        // length, and libssh2 does not NUL-terminate longentry. Zero the whole
        // buffer first so a terminator always follows the copied bytes (and a
        // missing longname does not reuse the previous entry's owner/group).
        memset(longEntry, 0, sizeof(longEntry));
        int rc = libssh2_sftp_readdir_ex(dir, nameBuf, sizeof(nameBuf) - 1, longEntry, sizeof(longEntry) - 1, &attrs);
#ifdef _DEBUG
        if (rc > 0 && probeFailAt > 0 && !(rc <= 2 && nameBuf[0] == '.' && (rc == 1 || nameBuf[1] == '.')) &&
            ++probeRead == probeFailAt)
            rc = LIBSSH2_ERROR_SOCKET_TIMEOUT; // the seam: this read "failed"
#endif
        CSftpReadDirStep step = SftpReadDirStep(rc);
        if (step == rdsEnd)
        {
            complete = TRUE;
            break;
        }
        if (step == rdsError)
        {
            // the reason, before closedir replaces the session's status. The library does not
            // record an error for every failure of this call (a name that does not fit the
            // buffer returns its code and leaves the session's last error as it was - the text
            // of some earlier failure), so the session's text is used only when it belongs to
            // this code.
            if (Ssh != NULL && libssh2_session_last_errno(Ssh) == rc)
                SetLastErrorFromSftp("readdir");
            else if (rc == LIBSSH2_ERROR_BUFFER_TOO_SMALL)
                SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_TOOLONGPATH));
            else
                _snprintf_s(LastErrorText, _TRUNCATE, "readdir: libssh2 error %d", rc);
            break;
        }
        nameBuf[rc] = 0;

        if (IsDotOrDotDot(nameBuf))
            continue;

        CSFTPDirEntry* e = new CSFTPDirEntry;
        if (e == NULL)
        {
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LOW_MEMORY);
            break;
        }
        e->Name = _strdup(nameBuf);
        if (e->Name == NULL) // CF-19: e->Name is dereferenced when building paths
        {
            delete e;
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LOW_MEMORY);
            break;
        }
        if (attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS)
        {
            e->Mode = attrs.permissions;
            e->HasMode = TRUE;
        }
        if (attrs.flags & LIBSSH2_SFTP_ATTR_SIZE)
        {
            e->Size = attrs.filesize;
            e->HasSize = TRUE;
        }
        if (attrs.flags & LIBSSH2_SFTP_ATTR_UIDGID)
        {
            e->Uid = attrs.uid;
            e->Gid = attrs.gid;
        }
        if (attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME)
        {
            e->Mtime = (__int64)attrs.mtime;
            e->HasMtime = TRUE;
        }
        // parse owner/group text from the long listing entry (v3 style:
        // "perms links owner group size date name")
        if (longEntry[0] != 0)
        {
            char* tok = longEntry;
            char* fields[8];
            int nf = 0;
            while (nf < 8)
            {
                while (*tok == ' ' || *tok == '\t')
                    tok++;
                if (*tok == 0)
                    break;
                fields[nf++] = tok;
                while (*tok != 0 && *tok != ' ' && *tok != '\t')
                    tok++;
                if (*tok != 0)
                    *tok++ = 0;
            }
            if (nf >= 4)
            {
                e->Owner = _strdup(fields[2]);
                e->Group = _strdup(fields[3]);
            }
        }
        entries->Add(e);
        if (!entries->IsGood())
        {
            entries->ResetState();
            delete e;
            SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LOW_MEMORY);
            break;
        }
    }
    libssh2_sftp_closedir(dir);
    return complete || stopped;
}

BOOL CSFTPSession::Stat(const char* path, BOOL followSymlink, LIBSSH2_SFTP_ATTRIBUTES* attrs)
{
    if (Sftp == NULL)
        return FALSE;
    memset(attrs, 0, sizeof(*attrs));
    int rc = libssh2_sftp_stat_ex(Sftp, path, (unsigned int)strlen(path),
                                  followSymlink ? LIBSSH2_SFTP_STAT : LIBSSH2_SFTP_LSTAT, attrs);
    return rc == 0;
}

BOOL CSFTPSession::ReadLink(const char* path, char* target, int targetSize)
{
    if (Sftp == NULL)
        return FALSE;
    int rc = libssh2_sftp_symlink_ex(Sftp, path, (unsigned int)strlen(path), target, targetSize - 1,
                                     LIBSSH2_SFTP_READLINK);
    if (rc <= 0)
        return FALSE;
    target[rc] = 0;
    return TRUE;
}

BOOL CSFTPSession::Mkdir(const char* path, long mode)
{
    // feature 131: every failure leaves its own reason (the message of the caller showed the
    // text of an earlier failure, or none)
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
    if (libssh2_sftp_mkdir_ex(Sftp, path, (unsigned int)strlen(path), mode) != 0)
    {
        SetLastErrorFromSftp(NULL);
        return FALSE;
    }
    return TRUE;
}

BOOL CSFTPSession::Rmdir(const char* path)
{
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
    if (libssh2_sftp_rmdir_ex(Sftp, path, (unsigned int)strlen(path)) != 0)
    {
        SetLastErrorFromSftp(NULL);
        return FALSE;
    }
    return TRUE;
}

BOOL CSFTPSession::Unlink(const char* path)
{
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
    if (libssh2_sftp_unlink_ex(Sftp, path, (unsigned int)strlen(path)) != 0)
    {
        SetLastErrorFromSftp(NULL);
        return FALSE;
    }
    return TRUE;
}

BOOL CSFTPSession::Rename(const char* from, const char* to)
{
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
    LogFmt("Rename %s -> %s", from, to);
    // Prefer the atomic, overwrite-capable posix-rename@openssh.com extension
    // (OpenSSH and most servers advertise it); it returns OP_UNSUPPORTED quickly
    // when absent, so the fallback is cheap. The standard SSH_FXP_RENAME only
    // carries the OVERWRITE flag for SFTP v5+, and libssh2 negotiates v3 - so a
    // plain rename there cannot overwrite an existing target (modern OpenSSH then
    // fails the rename with SSH_FX_FAILURE), which is why F2 rename onto an
    // existing name failed.
    int rc = libssh2_sftp_posix_rename_ex(Sftp, from, (unsigned int)strlen(from),
                                          to, (unsigned int)strlen(to));
    if (rc != 0)
        rc = libssh2_sftp_rename_ex(Sftp, from, (unsigned int)strlen(from),
                                    to, (unsigned int)strlen(to),
                                    LIBSSH2_SFTP_RENAME_OVERWRITE);
    if (rc != 0)
    {
        // capture the real libssh2 error - Rename previously returned FALSE
        // without setting LastErrorText, so "Cannot rename ..." showed no reason.
        SetLastErrorFromSftp(NULL); // feature 131: the server's status, not only "SFTP Protocol Error"
        Log(LastErrorText);
    }
    return rc == 0;
}

BOOL CSFTPSession::Symlink(const char* target, const char* linkPath)
{
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
    // libssh2_sftp_symlink(sftp, orig, linkpath): create 'linkpath' pointing to 'orig'
    int rc = libssh2_sftp_symlink_ex(Sftp, target, (unsigned int)strlen(target),
                                     (char*)linkPath, (unsigned int)strlen(linkPath), LIBSSH2_SFTP_SYMLINK);
    if (rc != 0)
        SetLastErrorFromSftp(NULL);
    return rc == 0;
}

BOOL CSFTPSession::Chmod(const char* path, unsigned long mode)
{
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
    LIBSSH2_SFTP_ATTRIBUTES attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.flags = LIBSSH2_SFTP_ATTR_PERMISSIONS;
    attrs.permissions = mode;
    if (libssh2_sftp_stat_ex(Sftp, path, (unsigned int)strlen(path), LIBSSH2_SFTP_SETSTAT, &attrs) != 0)
    {
        SetLastErrorFromSftp(NULL);
        return FALSE;
    }
    return TRUE;
}

BOOL CSFTPSession::Chown(const char* path, unsigned long uid, unsigned long gid,
                         BOOL setUid, BOOL setGid)
{
    // feature 018: change owner/group via SFTP setstat with UID/GID. An unset
    // field is left intact by first reading the current attrs and only
    // overriding the requested one(s).
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
    if (!setUid && !setGid) // nothing to change (the dialog refuses it before)
    {
        SplU8CopyTrunc(LastErrorText, sizeof(LastErrorText), LoadStrU8(IDS_OG_NEEDFIELD));
        return FALSE;
    }
    LIBSSH2_SFTP_ATTRIBUTES attrs;
    memset(&attrs, 0, sizeof(attrs));
    // start from the current uid/gid so a "leave unchanged" field keeps its value
    if (libssh2_sftp_stat_ex(Sftp, path, (unsigned int)strlen(path), LIBSSH2_SFTP_STAT, &attrs) != 0)
        memset(&attrs, 0, sizeof(attrs));
    attrs.flags = LIBSSH2_SFTP_ATTR_UIDGID;
    if (setUid)
        attrs.uid = uid;
    if (setGid)
        attrs.gid = gid;
    if (libssh2_sftp_stat_ex(Sftp, path, (unsigned int)strlen(path), LIBSSH2_SFTP_SETSTAT, &attrs) != 0)
    {
        SetLastErrorFromSftp(NULL);
        return FALSE;
    }
    return TRUE;
}

BOOL CSFTPSession::SetMTime(const char* path, __int64 mtime)
{
    if (Sftp == NULL)
        return SetLastErrorNotConnected();
    LIBSSH2_SFTP_ATTRIBUTES attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.flags = LIBSSH2_SFTP_ATTR_ACMODTIME;
    attrs.mtime = (unsigned long)mtime;
    attrs.atime = (unsigned long)mtime;
    if (libssh2_sftp_stat_ex(Sftp, path, (unsigned int)strlen(path), LIBSSH2_SFTP_SETSTAT, &attrs) != 0)
    {
        SetLastErrorFromSftp(NULL);
        return FALSE;
    }
    return TRUE;
}

LIBSSH2_SFTP_HANDLE* CSFTPSession::OpenRead(const char* path)
{
    if (Sftp == NULL)
    {
        SetLastErrorNotConnected();
        return NULL;
    }
    LIBSSH2_SFTP_HANDLE* h = libssh2_sftp_open_ex(Sftp, path, (unsigned int)strlen(path), LIBSSH2_FXF_READ, 0, LIBSSH2_SFTP_OPENFILE);
    if (h == NULL)
        SetLastErrorFromSftp(NULL); // feature 131: the reason shown by "Cannot download ..."
    return h;
}

LIBSSH2_SFTP_HANDLE* CSFTPSession::OpenWrite(const char* path, long mode, BOOL append)
{
    if (Sftp == NULL)
    {
        SetLastErrorNotConnected();
        return NULL;
    }
    unsigned long flags = LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT;
    if (append)
        flags |= LIBSSH2_FXF_APPEND;
    else
        flags |= LIBSSH2_FXF_TRUNC;
    LIBSSH2_SFTP_HANDLE* h = libssh2_sftp_open_ex(Sftp, path, (unsigned int)strlen(path), flags, mode, LIBSSH2_SFTP_OPENFILE);
    if (h == NULL)
        SetLastErrorFromSftp(NULL); // feature 131: the reason shown by "Cannot upload ..."
    return h;
}

void CSFTPSession::SeekWrite(LIBSSH2_SFTP_HANDLE* h, unsigned __int64 offset)
{
    if (h != NULL)
        libssh2_sftp_seek64(h, offset);
}

__int64 CSFTPSession::Read(LIBSSH2_SFTP_HANDLE* h, char* buf, int len)
{
    if (h == NULL)
        return -1;
    __int64 n = libssh2_sftp_read(h, buf, len);
    if (n < 0)
        NoteTransportError((int)n); // feature 051 (U7): notice a dropped transport
    return n;
}

__int64 CSFTPSession::Write(LIBSSH2_SFTP_HANDLE* h, const char* buf, int len)
{
    if (h == NULL)
        return -1;
    // libssh2_sftp_write may accept only part of the buffer; caller loops
    __int64 n = libssh2_sftp_write(h, buf, len);
    if (n < 0)
        NoteTransportError((int)n);
    return n;
}

void CSFTPSession::CloseHandle(LIBSSH2_SFTP_HANDLE* h)
{
    if (h != NULL)
        libssh2_sftp_close_handle(h);
}

void CSFTPSession::Keepalive(int* secondsToNext)
{
    int next = 0;
    if (Ssh != NULL)
    {
        // feature 051 (U3): the keepalive runs on the UI thread from the FS timer.
        // On a peer that vanished silently the send used to stall for the whole
        // operation timeout, once per tick. Bound it tightly - a keepalive is
        // worth at most a moment, and losing one tick is harmless.
        long saved = (Params.OperationTimeoutSec > 0 ? Params.OperationTimeoutSec : 30) * 1000L;
        libssh2_session_set_timeout(Ssh, 2000);
        int rc = libssh2_keepalive_send(Ssh, &next);
        libssh2_session_set_timeout(Ssh, saved);
        if (rc != 0)
            NoteTransportError(rc); // a dead transport must not look alive
    }
    if (secondsToNext != NULL)
        *secondsToNext = next;
}

// feature 051 (U7): mark the session dead when a libssh2 call reports a
// transport-level failure. 'Connected' used to be cleared only by Disconnect(),
// so after a cable pull or server restart IsConnected() kept returning TRUE,
// EnsureConnected() short-circuited, and every following operation failed with a
// raw libssh2 error and no way to recover short of closing the panel.
void CSFTPSession::NoteTransportError(int rc)
{
    int code = rc;
    if (code == 0 && Ssh != NULL)
        code = libssh2_session_last_errno(Ssh);
    switch (code)
    {
    case LIBSSH2_ERROR_SOCKET_SEND:
    case LIBSSH2_ERROR_SOCKET_RECV:
    case LIBSSH2_ERROR_SOCKET_TIMEOUT:
    case LIBSSH2_ERROR_SOCKET_DISCONNECT:
    case LIBSSH2_ERROR_TIMEOUT:
        if (Connected)
        {
            Log("Connection to the server was lost.");
            Connected = FALSE; // EnsureConnected() will offer to reconnect
        }
        break;
    default:
        break;
    }
}
