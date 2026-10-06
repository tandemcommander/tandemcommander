// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <winhttp.h>

#include "mainwnd.h"
#include "updcheck.h"

// winhttp.dll is delay-loaded (sal_base.props): a program that never checks -
// the option is off - never loads it, and when it is loaded, it is loaded by
// the worker thread. Every WinHTTP call is made on the worker.
#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "delayimp.lib")

// stored state: HKCU\<configuration root>\Update Check (contracts/stored-state.md)
static const WCHAR* const UPDCHECK_SUBKEY = L"Update Check";
static const WCHAR* const UPDCHECK_VAL_ATSTARTUP = L"Check At Startup";
static const WCHAR* const UPDCHECK_VAL_LASTATTEMPT = L"Last Attempt";
static const WCHAR* const UPDCHECK_VAL_ANSWERED = L"Last Attempt Answered";
static const WCHAR* const UPDCHECK_VAL_LASTSUCCESS = L"Last Success";
static const WCHAR* const UPDCHECK_VAL_LATEST = L"Latest Version";
static const WCHAR* const UPDCHECK_VAL_PUBLISHED = L"Latest Published";
static const WCHAR* const UPDCHECK_VAL_SKIPPED = L"Skipped Version";

// one claim per interval across the instances of one logon session
static const WCHAR* const UPDCHECK_MUTEX = L"Local\\TandemCommanderUpdateCheck";

// timeouts of the request (contracts/update-source.md); the whole request is bounded by UPDCHECK_DEADLINE_MS
#define UPDCHECK_RESOLVE_MS 4000
#define UPDCHECK_CONNECT_MS 4000
#define UPDCHECK_SEND_MS 2000
#define UPDCHECK_RECEIVE_MS 8000
#define UPDCHECK_DEADLINE_MS 12000 // the whole request, from the first step to the last byte

//
// ****************************************************************************
// stored state
//

static BOOL UpdGetKeyPath(WCHAR* path, int pathSize)
{
    const char* root = SalamanderConfigurationRoots[0]; // ASCII by definition
    if (root == NULL)
        return FALSE;
    int n = 0;
    while (root[n] != 0)
    {
        if (n >= pathSize - 1 || (unsigned char)root[n] >= 0x80)
            return FALSE;
        path[n] = (WCHAR)root[n];
        n++;
    }
    path[n] = 0;
    return (int)(n + 1 + wcslen(UPDCHECK_SUBKEY)) < pathSize &&
           wcscat_s(path, pathSize, L"\\") == 0 && wcscat_s(path, pathSize, UPDCHECK_SUBKEY) == 0;
}

static BOOL UpdOpenKey(BOOL forWrite, HKEY* key)
{
    WCHAR path[300];
    if (!UpdGetKeyPath(path, _countof(path)))
        return FALSE;
    if (forWrite)
    {
        return NOHANDLES(RegCreateKeyExW(HKEY_CURRENT_USER, path, 0, NULL, REG_OPTION_NON_VOLATILE,
                                         KEY_READ | KEY_WRITE, NULL, key, NULL)) == ERROR_SUCCESS;
    }
    return NOHANDLES(RegOpenKeyExW(HKEY_CURRENT_USER, path, 0, KEY_READ, key)) == ERROR_SUCCESS;
}

static BOOL UpdReadDword(HKEY key, const WCHAR* name, DWORD* value)
{
    DWORD type = 0;
    DWORD data = 0;
    DWORD size = sizeof(data);
    if (NOHANDLES(RegQueryValueExW(key, name, NULL, &type, (BYTE*)&data, &size)) != ERROR_SUCCESS ||
        type != REG_DWORD || size != sizeof(data))
        return FALSE;
    *value = data;
    return TRUE;
}

static BOOL UpdReadQword(HKEY key, const WCHAR* name, ULONGLONG* value)
{
    DWORD type = 0;
    ULONGLONG data = 0;
    DWORD size = sizeof(data);
    if (NOHANDLES(RegQueryValueExW(key, name, NULL, &type, (BYTE*)&data, &size)) != ERROR_SUCCESS ||
        type != REG_QWORD || size != sizeof(data))
        return FALSE;
    *value = data;
    return TRUE;
}

// reads a short ASCII text value; anything else (other type, too long, non-ASCII) is "absent"
static BOOL UpdReadText(HKEY key, const WCHAR* name, char* text, int textSize)
{
    WCHAR data[64];
    DWORD type = 0;
    DWORD size = sizeof(data) - sizeof(WCHAR);
    if (NOHANDLES(RegQueryValueExW(key, name, NULL, &type, (BYTE*)data, &size)) != ERROR_SUCCESS ||
        type != REG_SZ || (size % sizeof(WCHAR)) != 0)
        return FALSE;
    int len = (int)(size / sizeof(WCHAR));
    data[len] = 0; // the stored text need not be terminated
    len = (int)wcslen(data);
    if (len >= textSize)
        return FALSE;
    for (int i = 0; i < len; i++)
    {
        if (data[i] < 0x20 || data[i] >= 0x7F)
            return FALSE;
        text[i] = (char)data[i];
    }
    text[len] = 0;
    return TRUE;
}

static void UpdWriteDword(HKEY key, const WCHAR* name, DWORD value)
{
    NOHANDLES(RegSetValueExW(key, name, 0, REG_DWORD, (const BYTE*)&value, sizeof(value)));
}

static void UpdWriteQword(HKEY key, const WCHAR* name, ULONGLONG value)
{
    NOHANDLES(RegSetValueExW(key, name, 0, REG_QWORD, (const BYTE*)&value, sizeof(value)));
}

static void UpdWriteText(HKEY key, const WCHAR* name, const char* text)
{
    WCHAR data[64];
    int len = (int)strlen(text);
    if (len >= _countof(data))
        return;
    for (int i = 0; i <= len; i++)
        data[i] = (WCHAR)(unsigned char)text[i];
    NOHANDLES(RegSetValueExW(key, name, 0, REG_SZ, (const BYTE*)data, (DWORD)((len + 1) * sizeof(WCHAR))));
}

static ULONGLONG UpdNow()
{
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    return ((ULONGLONG)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
}

void UpdateCheck_LoadState(CUpdateState* state)
{
    memset(state, 0, sizeof(*state));
    state->CheckAtStartup = TRUE;

    HKEY key;
    if (!UpdOpenKey(FALSE, &key))
        return;
    ULONGLONG now = UpdNow();
    DWORD dw;
    if (UpdReadDword(key, UPDCHECK_VAL_ATSTARTUP, &dw))
        state->CheckAtStartup = dw != 0;
    ULONGLONG qw;
    // a time in the future is kept here and judged by SalUpdAutoCheckDue (it makes a check due)
    if (UpdReadQword(key, UPDCHECK_VAL_LASTATTEMPT, &qw))
    {
        state->HasLastAttempt = TRUE;
        state->LastAttempt = qw;
        if (UpdReadDword(key, UPDCHECK_VAL_ANSWERED, &dw))
            state->LastAttemptAnswered = dw != 0;
    }
    if (UpdReadQword(key, UPDCHECK_VAL_LASTSUCCESS, &qw) && qw <= now)
    {
        state->HasLastSuccess = TRUE;
        state->LastSuccess = qw;
    }
    char text[SALUPD_TIME_TEXT_MAX + 8];
    if (UpdReadText(key, UPDCHECK_VAL_LATEST, text, sizeof(text)) &&
        SalUpdParseVersion(text, -1, FALSE, &state->Latest))
    {
        state->HasLatest = TRUE;
        if (UpdReadText(key, UPDCHECK_VAL_PUBLISHED, text, sizeof(text)) &&
            SalUpdParseUtcTime(text, -1, &qw))
            state->LatestPublished = qw;
    }
    if (UpdReadText(key, UPDCHECK_VAL_SKIPPED, text, sizeof(text)) &&
        SalUpdParseVersion(text, -1, FALSE, &state->Skipped))
        state->HasSkipped = TRUE;
    NOHANDLES(RegCloseKey(key));
}

void UpdateCheck_SetCheckAtStartup(BOOL on)
{
    HKEY key;
    if (UpdOpenKey(TRUE, &key))
    {
        UpdWriteDword(key, UPDCHECK_VAL_ATSTARTUP, on ? 1 : 0);
        NOHANDLES(RegCloseKey(key));
    }
}

void UpdateCheck_SetSkippedVersion(const CSalUpdVersion& version)
{
    char text[SALUPD_VERSION_TEXT_MAX];
    HKEY key;
    if (SalUpdFormatVersion(version, text, sizeof(text)) && UpdOpenKey(TRUE, &key))
    {
        UpdWriteText(key, UPDCHECK_VAL_SKIPPED, text);
        NOHANDLES(RegCloseKey(key));
    }
}

void UpdateCheck_GetInstalledVersion(CSalUpdVersion* version)
{
    version->Major = VERSINFO_SALAMANDER_MAJOR;
    version->Minor = VERSINFO_SALAMANDER_MINORA;
    version->Patch = VERSINFO_SALAMANDER_MINORB;
#ifdef _DEBUG
    // test seam, Debug builds only (specs/123-new-version-check/research.md R11)
    char pretend[SALUPD_VERSION_TEXT_MAX];
    DWORD len = GetEnvironmentVariableA("TC_UPDATECHECK_PRETEND_VERSION", pretend, sizeof(pretend));
    CSalUpdVersion v;
    if (len > 0 && len < sizeof(pretend) && SalUpdParseVersion(pretend, -1, FALSE, &v))
        *version = v;
#endif // _DEBUG
}

CSalUpdKnownState UpdateCheck_GetKnownState(CUpdateState* state)
{
    CUpdateState local;
    if (state == NULL)
        state = &local;
    UpdateCheck_LoadState(state);
    CSalUpdVersion installed;
    UpdateCheck_GetInstalledVersion(&installed);
    return SalUpdKnownState(state->HasLatest, state->Latest, installed);
}

BOOL UpdateCheck_FormatDate(ULONGLONG utcFileTime, WCHAR* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    buf[0] = 0;
    FILETIME ft;
    ft.dwLowDateTime = (DWORD)(utcFileTime & 0xFFFFFFFF); // masked: the Debug build checks casts (/RTCc)
    ft.dwHighDateTime = (DWORD)(utcFileTime >> 32);
    SYSTEMTIME utc, local;
    if (utcFileTime == 0 || !FileTimeToSystemTime(&ft, &utc))
        return FALSE;
    if (!SystemTimeToTzSpecificLocalTime(NULL, &utc, &local))
        local = utc;
    // the user's long date without the day of the week ("14 October 2026")
    WCHAR picture[100];
    if (GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SLONGDATE, picture, _countof(picture)) > 0)
    {
        SalUpdStripWeekday(picture);
        if (picture[0] != 0 &&
            GetDateFormatEx(LOCALE_NAME_USER_DEFAULT, 0, &local, picture, buf, bufSize, NULL) != 0)
            return TRUE;
    }
    if (GetDateFormatEx(LOCALE_NAME_USER_DEFAULT, DATE_LONGDATE, &local, NULL, buf, bufSize, NULL) == 0)
    {
        buf[0] = 0;
        return FALSE;
    }
    return TRUE;
}

//
// ****************************************************************************
// the worker
//
// Cancelling: WinHTTP is used in its asynchronous mode, the only one in which
// a request may be abandoned (Microsoft: never close the handle of a
// synchronous request from another thread). The worker starts each step and
// waits for its completion, for the cancel event or for the deadline of the
// whole request, whichever comes first; then it closes the request handle
// itself. A cancel therefore ends the worker within milliseconds, and it
// announces the result itself, so nobody waits even for that.
//

struct CUpdCheckContext
{
    HWND Notify;        // the main window
    HANDLE CancelEvent; // manual-reset; signalled by a cancel, closed by the worker
    BOOL Manual;        // guarded by UpdCS: an automatic check can be promoted while it runs
    BOOL Cancelled;     // guarded by UpdCS: set by a cancel, which also detaches the context from UpdRunning
};

// what the WinHTTP callback (any thread) hands to the worker
struct CUpdAsync
{
    HANDLE Event;  // auto-reset: the step in progress completed
    HANDLE Closed; // manual-reset: the request handle is gone, no callback will come any more
    DWORD Status;  // WINHTTP_CALLBACK_STATUS_* of the completion
    DWORD Number;  // DATA_AVAILABLE: bytes waiting; READ_COMPLETE: bytes read
    DWORD Error;   // REQUEST_ERROR: the Windows error
};

static CRITICAL_SECTION UpdCS; // never deleted: a worker may outlive an exit in progress
static LONG UpdCSInitialized = 0;
// The check in progress (guarded by UpdCS). The main thread reaches a context only through this
// pointer and only under the lock; the worker clears it (under the lock) before it frees its
// context, and a cancel clears it at once - so it never points at freed memory.
static CUpdCheckContext* UpdRunning = NULL;
static BOOL UpdHasDone = FALSE;  // a result waits for UpdateCheck_TakeResult (guarded by UpdCS)
static CUpdateCheckDone UpdDone; // guarded by UpdCS
static BOOL UpdShutDown = FALSE; // guarded by UpdCS: no announcements any more

static void UpdEnsureCS()
{
    // main thread only, before any worker exists
    if (InterlockedCompareExchange(&UpdCSInitialized, 1, 0) == 0)
        NOHANDLES(InitializeCriticalSection(&UpdCS));
}

static BOOL UpdIsCancelled(CUpdCheckContext* ctx)
{
    NOHANDLES(EnterCriticalSection(&UpdCS));
    BOOL cancelled = ctx->Cancelled;
    NOHANDLES(LeaveCriticalSection(&UpdCS));
    return cancelled;
}

// Reads the state, decides whether an automatic check is due and, if so,
// writes "Last Attempt" - all under a named mutex, so that instances started
// together make one request (contracts/stored-state.md, rule 3).
// 'force' (a manual check): the attempt is recorded without asking the rule.
static BOOL UpdClaim(BOOL force)
{
    HANDLE mutex = NOHANDLES(CreateMutexW(NULL, FALSE, UPDCHECK_MUTEX));
    BOOL locked = FALSE;
    if (mutex != NULL)
    {
        DWORD wait = WaitForSingleObject(mutex, 2000);
        locked = wait == WAIT_OBJECT_0 || wait == WAIT_ABANDONED;
    }
    BOOL due = force;
    if (!force)
    {
        CUpdateState state;
        UpdateCheck_LoadState(&state);
        due = SalUpdAutoCheckDue(state.CheckAtStartup, state.HasLastAttempt, state.LastAttempt,
                                 state.LastAttemptAnswered, UpdNow());
    }
    if (due)
    {
        HKEY key;
        if (UpdOpenKey(TRUE, &key))
        {
            UpdWriteQword(key, UPDCHECK_VAL_LASTATTEMPT, UpdNow());
            UpdWriteDword(key, UPDCHECK_VAL_ANSWERED, 0);
            NOHANDLES(RegCloseKey(key));
        }
    }
    if (mutex != NULL)
    {
        if (locked)
            ReleaseMutex(mutex);
        NOHANDLES(CloseHandle(mutex));
    }
    return due;
}

// 'answered': the server sent an HTTP status in this attempt (the attempt then counts as the
// day's contact, whatever became of the body)
static void UpdStoreResult(CSalUpdResult result, const CSalUpdRelease& release, BOOL answered)
{
    if (result == surCancelled)
        return;
    HKEY key;
    if (!UpdOpenKey(TRUE, &key))
        return;
    UpdWriteDword(key, UPDCHECK_VAL_ANSWERED, (answered || SalUpdResultWasAnswered(result)) ? 1 : 0);
    if (SalUpdResultIsKnowledge(result)) // a failure keeps what the program knew
    {
        char text[SALUPD_VERSION_TEXT_MAX];
        if (SalUpdFormatVersion(release.Version, text, sizeof(text)))
        {
            UpdWriteQword(key, UPDCHECK_VAL_LASTSUCCESS, UpdNow());
            UpdWriteText(key, UPDCHECK_VAL_LATEST, text);
            UpdWriteText(key, UPDCHECK_VAL_PUBLISHED, release.PublishedText);
        }
    }
    NOHANDLES(RegCloseKey(key));
}

static void CALLBACK UpdStatusCallback(HINTERNET handle, DWORD_PTR context, DWORD status,
                                       LPVOID info, DWORD infoLength)
{
    CUpdAsync* async = (CUpdAsync*)context;
    if (async == NULL)
        return;
    switch (status)
    {
    case WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE:
    case WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE:
        async->Number = 0;
        break;

    case WINHTTP_CALLBACK_STATUS_DATA_AVAILABLE:
        async->Number = (info != NULL && infoLength >= sizeof(DWORD)) ? *(DWORD*)info : 0;
        break;

    case WINHTTP_CALLBACK_STATUS_READ_COMPLETE:
        async->Number = infoLength;
        break;

    case WINHTTP_CALLBACK_STATUS_REQUEST_ERROR:
        async->Error = info != NULL ? ((WINHTTP_ASYNC_RESULT*)info)->dwError : 0;
        break;

    case WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING:
        SetEvent(async->Closed); // the last callback of the request
        return;

    default:
        return;
    }
    async->Status = status;
    SetEvent(async->Event);
}

// Waits for the completion of the step just started. Returns its status, or
// 0 when the check was cancelled or the deadline of the whole request passed
// ('*timedOut' TRUE) - the step is then still pending and the caller must
// close the request handle before it frees anything the step uses.
static DWORD UpdAwait(CUpdCheckContext* ctx, CUpdAsync* async, DWORD startTick, BOOL* timedOut)
{
    DWORD elapsed = GetTickCount() - startTick;
    DWORD left = elapsed >= UPDCHECK_DEADLINE_MS ? 0 : UPDCHECK_DEADLINE_MS - elapsed;
    HANDLE handles[2] = {async->Event, ctx->CancelEvent};
    DWORD wait = WaitForMultipleObjects(2, handles, FALSE, left);
    if (wait == WAIT_OBJECT_0)
        return async->Status;
    if (wait == WAIT_TIMEOUT)
        *timedOut = TRUE;
    return 0;
}

// One GET per contracts/update-source.md. Returns the result class; 'release'
// is filled for surNewer / surUpToDate; '*answered' is TRUE when an HTTP
// status arrived. Every WinHTTP handle is opened and closed by this thread.
static CSalUpdResult UpdRequest(CUpdCheckContext* ctx, CSalUpdRelease* release, BOOL* answered)
{
    memset(release, 0, sizeof(*release));
    *answered = FALSE;

    const WCHAR* host = SALUPD_HOST_W;
    const WCHAR* path = SALUPD_PATH_W;
    INTERNET_PORT port = INTERNET_DEFAULT_HTTPS_PORT;
    BOOL secure = TRUE;
#ifdef _DEBUG
    // test seam, Debug builds only: a fixture server on the loopback interface, plain HTTP
    // (specs/123-new-version-check/research.md R11). It cannot change what the program opens -
    // those addresses are constructed from the validated version.
    WCHAR seamUrl[300];
    WCHAR seamPath[300];
    int seamPort = 0;
    DWORD seamLen = GetEnvironmentVariableW(L"TC_UPDATECHECK_URL", seamUrl, _countof(seamUrl));
    if (seamLen > 0 && seamLen < _countof(seamUrl) &&
        SalUpdParseLoopbackUrl(seamUrl, &seamPort, seamPath, _countof(seamPath)))
    {
        host = L"127.0.0.1";
        path = seamPath;
        port = (INTERNET_PORT)seamPort;
        secure = FALSE;
    }
#endif // _DEBUG

    DWORD startTick = GetTickCount();
    CSalUpdResult result = surUnreachable;

    // the callback's data and the answer live on the heap: if the request handle ever failed to
    // close, they are left allocated rather than freed under a late callback
    CUpdAsync* async = (CUpdAsync*)malloc(sizeof(CUpdAsync));
    char* body = (char*)malloc(SALUPD_MAX_ANSWER + 1);
    if (async != NULL)
    {
        memset(async, 0, sizeof(*async));
        async->Event = NOHANDLES(CreateEventW(NULL, FALSE, FALSE, NULL));
        async->Closed = NOHANDLES(CreateEventW(NULL, TRUE, FALSE, NULL));
    }
    if (async == NULL || body == NULL || async->Event == NULL || async->Closed == NULL)
    {
        if (async != NULL)
        {
            if (async->Event != NULL)
                NOHANDLES(CloseHandle(async->Event));
            if (async->Closed != NULL)
                NOHANDLES(CloseHandle(async->Closed));
            free(async);
        }
        if (body != NULL)
            free(body);
        return surUnreachable;
    }

    HINTERNET session = WinHttpOpen(SALUPD_USER_AGENT_W,
                                    secure ? WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY : WINHTTP_ACCESS_TYPE_NO_PROXY,
                                    WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC);
    if (session == NULL && secure) // WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY needs Windows 8.1
        session = WinHttpOpen(SALUPD_USER_AGENT_W, WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                              WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC);
    HINTERNET connect = NULL;
    HINTERNET request = NULL;
    BOOL protocolsSet = TRUE;
    if (session != NULL)
    {
        // inner bounds of the single phases; the whole request is bounded by UpdAwait
        WinHttpSetTimeouts(session, UPDCHECK_RESOLVE_MS, UPDCHECK_CONNECT_MS, UPDCHECK_SEND_MS, UPDCHECK_RECEIVE_MS);
        if (secure)
        {
            // TLS 1.2 or newer; a system that does not know the TLS 1.3 flag gets 1.2 alone; a
            // session that cannot be limited so is not used
            DWORD protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 | 0x00002000 /* WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_3 */;
            if (!WinHttpSetOption(session, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols)))
            {
                protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
                if (!WinHttpSetOption(session, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols)))
                    protocolsSet = FALSE;
            }
        }
        if (protocolsSet)
            connect = WinHttpConnect(session, host, port, 0);
    }
    if (connect != NULL)
    {
        request = WinHttpOpenRequest(connect, L"GET", path, NULL, WINHTTP_NO_REFERER,
                                     WINHTTP_DEFAULT_ACCEPT_TYPES, secure ? WINHTTP_FLAG_SECURE : 0);
    }
    BOOL callbackSet = FALSE;
    if (request != NULL)
    {
        // No cookie jar, no logon with the user's Windows credentials on a 401/407 challenge, no
        // redirect followed (the rule of feature 085); completions and the closing of the handle
        // are reported to UpdStatusCallback. A request that cannot be set up so is not sent.
        DWORD disable = WINHTTP_DISABLE_COOKIES | WINHTTP_DISABLE_AUTHENTICATION | WINHTTP_DISABLE_REDIRECTS;
        DWORD_PTR context = (DWORD_PTR)async;
        if (WinHttpSetOption(request, WINHTTP_OPTION_DISABLE_FEATURE, &disable, sizeof(disable)) &&
            WinHttpSetOption(request, WINHTTP_OPTION_CONTEXT_VALUE, &context, sizeof(context)) &&
            WinHttpSetStatusCallback(request, UpdStatusCallback,
                                     WINHTTP_CALLBACK_FLAG_ALL_COMPLETIONS | WINHTTP_CALLBACK_FLAG_HANDLES,
                                     0) != WINHTTP_INVALID_STATUS_CALLBACK)
            callbackSet = TRUE;
    }

    DWORD bodyLen = 0;
    BOOL bodyComplete = FALSE;
    BOOL timedOut = FALSE;
    if (callbackSet && !UpdIsCancelled(ctx))
    {
        DWORD status = 0;
        DWORD statusSize = sizeof(status);
        if (WinHttpSendRequest(request, SALUPD_HEADERS_W, (DWORD)-1L, WINHTTP_NO_REQUEST_DATA, 0, 0,
                               (DWORD_PTR)async) &&
            UpdAwait(ctx, async, startTick, &timedOut) == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE &&
            WinHttpReceiveResponse(request, NULL) &&
            UpdAwait(ctx, async, startTick, &timedOut) == WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE &&
            WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                                WINHTTP_HEADER_NAME_BY_INDEX, &status, &statusSize, WINHTTP_NO_HEADER_INDEX))
        {
            *answered = TRUE;
            if (!SalUpdStatusWantsBody(status, &result))
            {
                TRACE_I("UpdateCheck: HTTP status " << status); // the body of such an answer is not read
            }
            else
            {
                result = surUnexpected;
                for (;;)
                {
                    // only what has arrived is read, so that a server sending a byte now and then
                    // cannot hold a read open
                    if (!WinHttpQueryDataAvailable(request, NULL) ||
                        UpdAwait(ctx, async, startTick, &timedOut) != WINHTTP_CALLBACK_STATUS_DATA_AVAILABLE)
                    {
                        result = surUnreachable; // the connection broke, or the answer did not arrive in time
                        break;
                    }
                    DWORD avail = async->Number;
                    if (avail == 0)
                    {
                        bodyComplete = TRUE;
                        break;
                    }
                    // one byte more than the limit can be taken, so that an oversized answer is seen
                    DWORD room = SALUPD_MAX_ANSWER + 1 - bodyLen;
                    if (!WinHttpReadData(request, body + bodyLen, min(avail, room), NULL) ||
                        UpdAwait(ctx, async, startTick, &timedOut) != WINHTTP_CALLBACK_STATUS_READ_COMPLETE)
                    {
                        result = surUnreachable;
                        break;
                    }
                    DWORD read = async->Number;
                    if (read == 0)
                    {
                        bodyComplete = TRUE;
                        break;
                    }
                    bodyLen += read;
                    if (bodyLen > SALUPD_MAX_ANSWER)
                        break; // oversized: unexpected
                }
                // an answer that announced its length and ended before it is damaged, however
                // complete the part that arrived may look
                // (an answer without the header - a chunked one - has no announced length; a header
                // that cannot be read as a 32-bit number announces more than any answer we accept)
                DWORD announced = 0;
                DWORD announcedSize = sizeof(announced);
                if (bodyComplete)
                {
                    BOOL known = WinHttpQueryHeaders(request, WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER,
                                                     WINHTTP_HEADER_NAME_BY_INDEX, &announced, &announcedSize,
                                                     WINHTTP_NO_HEADER_INDEX);
                    if (known ? announced != bodyLen : GetLastError() != ERROR_WINHTTP_HEADER_NOT_FOUND)
                    {
                        TRACE_I("UpdateCheck: the answer ended after " << bodyLen << " bytes, not at its announced length");
                        bodyComplete = FALSE; // stays surUnexpected
                    }
                }
            }
        }
        if (timedOut)
            TRACE_I("UpdateCheck: the request did not finish within its deadline");
    }

    // Closing the request handle abandons whatever step is pending. Its data ('async', 'body')
    // may be touched by a callback until WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING arrives.
    BOOL quiet = TRUE;
    if (request != NULL)
    {
        WinHttpCloseHandle(request);
        if (callbackSet)
            quiet = WaitForSingleObject(async->Closed, 5000) == WAIT_OBJECT_0;
    }
    if (connect != NULL)
        WinHttpCloseHandle(connect);
    if (session != NULL)
        WinHttpCloseHandle(session);

    if (bodyComplete && bodyLen <= SALUPD_MAX_ANSWER)
    {
        CSalUpdParseError error;
        if (SalUpdParseLatestRelease(body, bodyLen, release, &error))
        {
            CSalUpdVersion installed;
            UpdateCheck_GetInstalledVersion(&installed);
            result = SalUpdClassify(*release, installed);
        }
        else
        {
            TRACE_I("UpdateCheck: the answer was not accepted, reason " << (int)error);
            result = surUnexpected;
        }
    }
    if (quiet)
    {
        NOHANDLES(CloseHandle(async->Event));
        NOHANDLES(CloseHandle(async->Closed));
        free(async);
        free(body);
    }
    else
        TRACE_E("UpdateCheck: the request handle did not close; its buffers are left allocated");
    return result;
}

static unsigned UpdThreadBody(void* param)
{
    CALL_STACK_MESSAGE1("UpdThreadBody()");
    SetThreadNameInVCAndTrace("UpdateCheck");
    CUpdCheckContext* ctx = (CUpdCheckContext*)param;

    NOHANDLES(EnterCriticalSection(&UpdCS));
    BOOL manual = ctx->Manual;
    NOHANDLES(LeaveCriticalSection(&UpdCS));

    BOOL go = TRUE;
    if (manual)
        UpdClaim(TRUE); // a check on demand counts as today's contact too
    else if (!UpdClaim(FALSE))
    {
        // not due (another instance claimed it meanwhile) - unless the user asked in between
        NOHANDLES(EnterCriticalSection(&UpdCS));
        if (!ctx->Manual || ctx->Cancelled)
        {
            go = FALSE;
            if (UpdRunning == ctx)
                UpdRunning = NULL;
        }
        NOHANDLES(LeaveCriticalSection(&UpdCS));
        if (!go)
            TRACE_I("UpdateCheck: not due, nothing sent");
        else
            UpdClaim(TRUE);
    }

    if (go)
    {
        CSalUpdRelease release;
        BOOL answered;
        CSalUpdResult result = UpdRequest(ctx, &release, &answered);

        if (UpdIsCancelled(ctx))
            TRACE_I("UpdateCheck: cancelled, the result is dropped"); // the cancel announced its own
        else
        {
            TRACE_I("UpdateCheck: result " << SalUpdResultName(result));
            UpdStoreResult(result, release, answered);

            NOHANDLES(EnterCriticalSection(&UpdCS));
            HWND notify = NULL;
            if (UpdRunning == ctx) // not cancelled in the last moment
            {
                UpdRunning = NULL;
                if (!UpdShutDown)
                {
                    UpdDone.Result = result;
                    UpdDone.Release = release;
                    UpdDone.Manual = ctx->Manual;
                    UpdHasDone = TRUE;
                    notify = ctx->Notify;
                }
            }
            NOHANDLES(LeaveCriticalSection(&UpdCS));
            if (notify != NULL)
                PostMessage(notify, WM_USER_UPDATECHECK_DONE, 0, 0);
        }
    }
    // nobody else can reach the context any more: UpdRunning was cleared by us or by a cancel
    // (which signals the event under the lock, before it lets go of the context)
    NOHANDLES(CloseHandle(ctx->CancelEvent));
    free(ctx);
    return 0;
}

static unsigned UpdThreadEH(void* param)
{
#ifndef CALLSTK_DISABLE
    __try
    {
#endif // CALLSTK_DISABLE
        return UpdThreadBody(param);
#ifndef CALLSTK_DISABLE
    }
    __except (CCallStack::HandleException(GetExceptionInformation()))
    {
        TRACE_I("Thread UpdateCheck: calling ExitProcess(1).");
        TerminateProcess(GetCurrentProcess(), 1);
        return 1;
    }
#endif // CALLSTK_DISABLE
}

static DWORD WINAPI UpdThreadF(void* param)
{
#ifndef CALLSTK_DISABLE
    CCallStack stack;
#endif // CALLSTK_DISABLE
    return UpdThreadEH(param);
}

// Worker threads that may still run (main thread only). A cancelled worker ends within
// milliseconds, so more than one or two at a time would be unusual; the exit waits for them
// briefly, so that none is killed in the middle of its work.
#define UPDCHECK_MAX_THREADS 8
static HANDLE UpdThreads[UPDCHECK_MAX_THREADS];
static int UpdThreadCount = 0;

static void UpdForgetFinishedThreads()
{
    int kept = 0;
    for (int i = 0; i < UpdThreadCount; i++)
    {
        if (WaitForSingleObject(UpdThreads[i], 0) == WAIT_OBJECT_0)
            HANDLES(CloseHandle(UpdThreads[i]));
        else
            UpdThreads[kept++] = UpdThreads[i];
    }
    UpdThreadCount = kept;
}

// starts the worker; the caller holds UpdCS and has checked that none runs
static BOOL UpdStartWorker(HWND mainWindow, BOOL manual)
{
    CUpdCheckContext* ctx = (CUpdCheckContext*)malloc(sizeof(CUpdCheckContext));
    if (ctx == NULL)
        return FALSE;
    memset(ctx, 0, sizeof(*ctx));
    ctx->Notify = mainWindow;
    ctx->Manual = manual;
    ctx->CancelEvent = NOHANDLES(CreateEventW(NULL, TRUE, FALSE, NULL));
    if (ctx->CancelEvent == NULL)
    {
        free(ctx);
        return FALSE;
    }
    UpdRunning = ctx;
    UpdHasDone = FALSE;

    DWORD threadID;
    HANDLE thread = HANDLES(CreateThread(NULL, 0, UpdThreadF, ctx, 0, &threadID));
    if (thread == NULL)
    {
        TRACE_E("UpdateCheck: unable to start the worker thread.");
        UpdRunning = NULL;
        NOHANDLES(CloseHandle(ctx->CancelEvent));
        free(ctx);
        return FALSE;
    }
    // the worker frees its context and closes the event; we keep the thread's handle
    UpdForgetFinishedThreads();
    if (UpdThreadCount < UPDCHECK_MAX_THREADS)
        UpdThreads[UpdThreadCount++] = thread;
    else
        AddAuxThread(thread); // closed with the other auxiliary threads
    return TRUE;
}

void UpdateCheck_OnStartupComplete(HWND mainWindow)
{
    CALL_STACK_MESSAGE1("UpdateCheck_OnStartupComplete()");
    if (SALAMANDER_ROOT_REG == NULL)
        return; // the program is leaving without a configuration (see salamdr1.cpp)
    UpdEnsureCS();

    // registry only: is the option on and may a check be due? The worker decides again under
    // the cross-instance mutex before it sends anything.
    CUpdateState state;
    UpdateCheck_LoadState(&state);
    if (!SalUpdAutoCheckDue(state.CheckAtStartup, state.HasLastAttempt, state.LastAttempt,
                            state.LastAttemptAnswered, UpdNow()))
        return;

    NOHANDLES(EnterCriticalSection(&UpdCS));
    if (UpdRunning == NULL && !UpdShutDown)
        UpdStartWorker(mainWindow, FALSE);
    NOHANDLES(LeaveCriticalSection(&UpdCS));
}

BOOL UpdateCheck_StartManual(HWND mainWindow)
{
    CALL_STACK_MESSAGE1("UpdateCheck_StartManual()");
    UpdEnsureCS();
    BOOL ok = TRUE;
    NOHANDLES(EnterCriticalSection(&UpdCS));
    if (UpdShutDown)
        ok = FALSE;
    else if (UpdRunning != NULL)
        UpdRunning->Manual = TRUE; // join the running check: its result will be answered
    else
        ok = UpdStartWorker(mainWindow, TRUE);
    NOHANDLES(LeaveCriticalSection(&UpdCS));
    return ok;
}

BOOL UpdateCheck_IsRunning()
{
    if (UpdCSInitialized == 0)
        return FALSE;
    NOHANDLES(EnterCriticalSection(&UpdCS));
    BOOL running = UpdRunning != NULL;
    NOHANDLES(LeaveCriticalSection(&UpdCS));
    return running;
}

void UpdateCheck_Cancel(BOOL timedOut)
{
    if (UpdCSInitialized == 0)
        return;
    HWND notify = NULL;
    NOHANDLES(EnterCriticalSection(&UpdCS));
    if (UpdRunning != NULL)
    {
        // the worker is let go: it abandons its request at once and drops whatever it learned
        // (see the top of this section)
        CUpdCheckContext* ctx = UpdRunning;
        ctx->Cancelled = TRUE;
        SetEvent(ctx->CancelEvent);
        UpdRunning = NULL;
        if (!UpdShutDown)
        {
            memset(&UpdDone, 0, sizeof(UpdDone));
            UpdDone.Result = timedOut ? surUnreachable : surCancelled;
            UpdDone.Manual = ctx->Manual;
            UpdHasDone = TRUE;
            notify = ctx->Notify;
        }
    }
    NOHANDLES(LeaveCriticalSection(&UpdCS));
    if (notify != NULL)
        PostMessage(notify, WM_USER_UPDATECHECK_DONE, 0, 0);
}

BOOL UpdateCheck_TakeResult(CUpdateCheckDone* done)
{
    if (UpdCSInitialized == 0)
        return FALSE;
    NOHANDLES(EnterCriticalSection(&UpdCS));
    BOOL has = UpdHasDone;
    if (has)
    {
        *done = UpdDone;
        UpdHasDone = FALSE;
    }
    NOHANDLES(LeaveCriticalSection(&UpdCS));
    return has;
}

void UpdateCheck_Shutdown()
{
    if (UpdCSInitialized == 0)
        return;
    NOHANDLES(EnterCriticalSection(&UpdCS));
    UpdShutDown = TRUE;
    UpdHasDone = FALSE;
    NOHANDLES(LeaveCriticalSection(&UpdCS));
    UpdateCheck_Cancel(FALSE);
    // A cancelled worker abandons its request and ends within milliseconds; the short wait lets
    // it finish in order instead of being ended with the auxiliary threads. The exit never
    // depends on the network.
    UpdForgetFinishedThreads();
    if (UpdThreadCount > 0)
        WaitForMultipleObjects(UpdThreadCount, UpdThreads, TRUE, 1500);
    UpdForgetFinishedThreads();
    for (int i = 0; i < UpdThreadCount; i++)
        AddAuxThread(UpdThreads[i]); // still running: ended with the other auxiliary threads
    UpdThreadCount = 0;
}
