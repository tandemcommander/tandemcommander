// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <libssh2.h>
#include <libssh2_sftp.h>

class CSFTPHostKeyList;

// one entry returned by a directory listing
struct CSFTPDirEntry
{
    char* Name;         // heap UTF-8 name (single path component)
    unsigned long Mode; // permissions incl. type bits (0 if unknown)
    unsigned __int64 Size;
    unsigned long Uid;
    unsigned long Gid;
    __int64 Mtime; // seconds since Unix epoch
    char* Owner;   // heap owner name or NULL (numeric fallback)
    char* Group;   // heap group name or NULL
    BOOL HasMode;
    BOOL HasSize;
    BOOL HasMtime;

    CSFTPDirEntry();
    ~CSFTPDirEntry();
};

// result of the host-key verification step
enum CSFTPHostKeyResult
{
    hkOk = 0,      // key trusted (known match or user accepted)
    hkAborted = 1, // user aborted / declined
    hkError = 2,   // could not obtain key
};

// how the connection ended up (for error reporting, FR-024)
enum CSFTPConnectResult
{
    crOk = 0,
    crResolveFailed,
    crConnectFailed,
    crHandshakeFailed,
    crHostKeyRejected,
    crAuthFailed,
    crAuthPassword,
    crAuthKey,
    crKeyUnlock,
    crKeyFileMissing,
    crNoAuthMethod,
    crSFTPInitFailed,
    crCancelled,
    crTimeout,
};

// feature 139: what CSFTPSession::StatEx found out
enum CSFTPStatResult
{
    sxFound = 0,    // the attributes were read
    sxNotFound = 1, // the server said: no such file / no such path
    sxError = 2,    // anything else - it is NOT known whether the item exists
};

// parameters needed to (re)establish a connection
struct CSFTPConnectParams
{
    char Host[256];
    int Port;
    char User[256];
    int AuthMethod;     // CSFTPAuthMethod
    char Password[SFTP_SECRET_BUF]; // decrypted, in-memory only
    char KeyFile[MAX_PATH];
    char Passphrase[SFTP_SECRET_BUF]; // decrypted, in-memory only
    BOOL UseCompression;
    int ConnectTimeoutSec;
    int OperationTimeoutSec;
    int KeepAliveSec;

    CSFTPConnectParams()
    {
        memset(this, 0, sizeof(*this));
        Port = 22;
    }
    void WipeSecrets()
    {
        SecureZeroMemory(Password, sizeof(Password));
        SecureZeroMemory(Passphrase, sizeof(Passphrase));
    }
};

// feature 051: what a non-interactive connect attempt needs from the user
// before it can be retried. Every dialog lives on the UI thread, so the connect
// worker never prompts - it stops and reports one of these instead (D4/D5).
enum CSFTPConnectPrompt
{
    cpNone = 0,
    cpHostKey,    // host key unknown or changed: user must confirm
    cpPassphrase, // the private key could not be unlocked
    cpPassword,   // server refused the key but offers password authentication
};

// Data the UI thread needs to render the host-key dialog for cpHostKey.
struct CSFTPHostKeyPrompt
{
    BOOL Changed; // TRUE = stored key differs (warning variant)
    char TypeName[64];
    char Fingerprint[128];
    char StoredFingerprint[128];
    char KeyB64[4096]; // blob to store when the user trusts the key
};

// ****************************************************************************
// CSFTPSession - wraps one SSH transport + SFTP subsystem (blocking mode).
// One session belongs to one panel FS or one operation worker; not shared
// across threads. The connect sequence runs on a worker thread (feature 051)
// so a stalled server can no longer freeze the application.
// ****************************************************************************

class CSFTPSession
{
protected:
    SOCKET Socket;
    LIBSSH2_SESSION* Ssh;
    LIBSSH2_SFTP* Sftp;
    BOOL Connected;

    CSFTPConnectParams Params;
    int LogUID; // session log id, -1 = none

    char LastErrorText[512]; // human-readable last error
    // feature 139: the SFTP status (SSH_FX_*) of the last failed request when the SERVER
    // answered with one; 0 when the failure was not a status (transport, timeout, memory,
    // not connected). Written wherever LastErrorText is written by an SFTP request.
    unsigned long LastSftpStatus;

    // feature 051 connect state (worker thread <-> UI thread)
    CSFTPConnectPrompt Prompt;      // what the last attempt needs from the user
    CSFTPHostKeyPrompt HostKeyInfo; // valid when Prompt == cpHostKey
    BOOL TrustHostKeyOnce;          // user accepted this key for this attempt
    BOOL ServerOffersPassword;      // password auth available as a fallback
    volatile LONG CancelRequested;  // set by the UI thread; polled by waits
    // Guards 'Socket' only: the UI thread shuts the socket down to abort a wait
    // while the connect worker may be creating or closing it.
    CRITICAL_SECTION SocketLock;

public:
    CSFTPSession();
    ~CSFTPSession();

    void SetLogUID(int uid) { LogUID = uid; }
    int GetLogUID() const { return LogUID; }

    BOOL IsConnected() const { return Connected; }
    const char* GetLastErrorText() const { return LastErrorText; }
    // feature 139: see LastSftpStatus (valid after a request that reported a failure through
    // GetLastErrorText(); plain Stat does not set it - StatEx does)
    unsigned long GetLastSftpStatus() const { return LastSftpStatus; }

    // Establishes the transport, verifies the host key (via 'trustStore' and,
    // when interaction is needed, prompting through 'parent'), authenticates,
    // and starts the SFTP subsystem. 'result' receives a precise outcome.
    // Returns TRUE only on a fully usable SFTP session.
    BOOL Connect(HWND parent, const CSFTPConnectParams* params,
                 CSFTPHostKeyList* trustStore, CSFTPConnectResult* result);

    // Re-establishes a dropped session using the stored params (FR-023).
    BOOL Reconnect(HWND parent, CSFTPHostKeyList* trustStore, CSFTPConnectResult* result);

    void Disconnect();

    // Resolves the server's home / a relative path to an absolute one.
    BOOL RealPath(const char* path, char* absPath, int absPathSize);

    // Lists 'path'. Appends heap-owned CSFTPDirEntry* to 'entries'. 'cancel'
    // (if not NULL) is polled to allow the caller to abort a huge listing.
    BOOL ListDir(const char* path, TIndirectArray<CSFTPDirEntry>* entries,
                 volatile BOOL* cancel);

    // stat/lstat: fills a single entry's attributes. Leaves the error text alone - except
    // when the connection is lost by (or before) this request (feature 140): FALSE then
    // means "not known", never "no such file" - a caller that acts on FALSE asks IsConnected().
    BOOL Stat(const char* path, BOOL followSymlink, LIBSSH2_SFTP_ATTRIBUTES* attrs);
    // feature 139: stat/lstat that tells "nothing of that name" from "could not be found out".
    // sxError sets GetLastErrorText() / GetLastSftpStatus(); a caller that is about to write
    // must not take it for "nothing there".
    CSFTPStatResult StatEx(const char* path, BOOL followSymlink, LIBSSH2_SFTP_ATTRIBUTES* attrs);
    BOOL ReadLink(const char* path, char* target, int targetSize);

    BOOL Mkdir(const char* path, long mode);
    BOOL Rmdir(const char* path);
    BOOL Unlink(const char* path);
    // feature 139: 'replace' TRUE = an existing target is replaced where the server can do it
    // (the caller has the user's consent); FALSE = the request can never replace anything -
    // the server refuses an existing target (Quick Rename, a new file put in place)
    BOOL Rename(const char* from, const char* to, BOOL replace);
    BOOL Symlink(const char* target, const char* linkPath);
    BOOL Chmod(const char* path, unsigned long mode);
    // feature 018: change owner (uid) and/or group (gid); an unset field is kept
    BOOL Chown(const char* path, unsigned long uid, unsigned long gid, BOOL setUid, BOOL setGid);
    BOOL SetMTime(const char* path, __int64 mtime);

    // File transfer primitives (blocking). Handles are opaque.
    LIBSSH2_SFTP_HANDLE* OpenRead(const char* path);
    LIBSSH2_SFTP_HANDLE* OpenWrite(const char* path, long mode, BOOL append);
    // feature 139: creates a NEW file for writing (WRITE | CREAT | EXCL): fails when anything
    // of that name exists - nothing is followed, nothing is truncated
    LIBSSH2_SFTP_HANDLE* OpenWriteNew(const char* path, long mode);
    void SeekWrite(LIBSSH2_SFTP_HANDLE* h, unsigned __int64 offset);
    __int64 Read(LIBSSH2_SFTP_HANDLE* h, char* buf, int len);
    __int64 Write(LIBSSH2_SFTP_HANDLE* h, const char* buf, int len);
    void CloseHandle(LIBSSH2_SFTP_HANDLE* h);
    // feature 139: the close of a written file can report that the data did not get to the
    // disk; FALSE = the server (or the transport) reported an error - GetLastErrorText() says
    // which. The handle must not be used again either way (the library frees it once the
    // server answered or the request could not be sent; after a timeout of the answer it
    // stays allocated - nothing here can release it).
    // feature 140: on a session that is dead (or gone) neither close calls the library - the
    // close would wait for the timeout again, on a handle whose own request may be half done.
    // CloseHandleChecked then returns FALSE. The handle's memory stays allocated for good:
    // the library frees a handle only in its close (sftp.c, sftp_shutdown: "TODO ... kill any
    // remaining sftp handles").
    BOOL CloseHandleChecked(LIBSSH2_SFTP_HANDLE* h);

    // Sends a keepalive if due; returns seconds until the next one is needed.
    void Keepalive(int* secondsToNext);

    // feature 051 (U7): marks the session dead when 'rc' (or the session's last
    // error) is a transport-level failure, so the next operation can reconnect
    // instead of failing forever against a dead transport. Pass 0 to classify
    // the session's last error.
    // feature 140: which codes those are: SftpRcIsDeadTransport for a code a call returned,
    // SftpErrnoIsDeadTransport for the session's last error (sftputils.h). From then on
    // every request method fails at once without calling the library, GetLastErrorText()
    // says that the connection was lost and GetLastSftpStatus() is 0 - until Disconnect /
    // Reconnect (the FS reconnects at the start of the next operation, as before).
    void NoteTransportError(int rc);

    // feature 051 (FR-003/SC-004): abort an in-progress connect or operation.
    // Called from the UI thread while a worker blocks in libssh2: closing the
    // socket makes the pending wait fail immediately instead of running to its
    // timeout. Safe to call when nothing is in flight.
    void RequestCancel();
    BOOL IsCancelRequested() const { return CancelRequested != 0; }

protected:
    BOOL OpenSocket(CSFTPConnectResult* result);
    // Non-interactive host-key check: verifies against the trust store and, when
    // the user must decide, fills 'HostKeyInfo' and sets Prompt = cpHostKey.
    BOOL EvaluateHostKey(CSFTPHostKeyList* trustStore, CSFTPConnectResult* result);
    BOOL Authenticate(HWND parent, CSFTPConnectResult* result);
    // One complete non-interactive connect attempt (socket, handshake, host key,
    // auth, sftp_init). Runs on the connect worker thread; never shows UI.
    BOOL ConnectAttempt(CSFTPHostKeyList* trustStore, CSFTPConnectResult* result);
    // Runs ConnectAttempt on a worker thread while the UI thread waits with a
    // cancellable wait window (feature 051, D4).
    BOOL RunConnectAttemptOnWorker(HWND parent, CSFTPHostKeyList* trustStore,
                                   CSFTPConnectResult* result);
    void SetLastErrorFromSsh(const char* prefix);
    // feature 131: the reason of a failed SFTP request (the server's status code where
    // there is one, else the session's error text); every SFTP operation that fails
    // calls it, so GetLastErrorText() never holds the text of an earlier failure
    void SetLastErrorFromSftp(const char* prefix);
    // feature 131: "not connected" as the reason; returns FALSE for 'return' statements
    BOOL SetLastErrorNotConnected();
    // feature 140: "The connection to the server was lost." as the reason ('detail', may be
    // NULL, follows in brackets); clears the SFTP status; returns FALSE for 'return' statements
    BOOL SetLastErrorLost(const char* detail);
    // feature 140, the gate of every request: TRUE = nothing may be sent - the session was
    // never established (Sftp == NULL: "not connected") or it was marked dead (Connected
    // FALSE: "the connection was lost"). After a timed-out request the library would give the
    // late answer of that request to the next one of its kind. 'quiet': the error text and
    // the status are left alone (plain Stat, ReadLink, RealPath).
    BOOL NoRequest(BOOL quiet = FALSE);
    // feature 140: called after a request failed with the library's RETURN code 'rc' (0 = not
    // known: the session's last error decides, by the narrow list). Marks the session dead when that is a dead
    // transport; then the error text says that the connection was lost, with the text this
    // failure left ('textIsSet') or the library's own text as the detail.
    void NoteFailure(int rc, BOOL textIsSet);
    // feature 140: the libssh2 code of a pointer-returning call that has just failed (0 = not known)
    int FailedPointerCallCode();
    // feature 140: SetLastErrorFromSftp + NoteFailure; returns FALSE for 'return' statements
    BOOL RequestFailed(int rc, const char* prefix);
#ifdef _DEBUG
    // feature 140, probe seam: the request "timed out" (see ProbeTimeoutAt in session.cpp)
    void ProbeTimedOut();
#endif
    void Log(const char* text);
    void LogFmt(const char* fmt, ...);

    friend unsigned __stdcall SFTPConnectThreadProc(void* param);
};

// process-wide libssh2 init / shutdown (called from the plugin entry/release)
BOOL InitSSH();
void ReleaseSSH();
