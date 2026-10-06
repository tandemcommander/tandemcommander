// Review 2 probe for feature 123 (stand-alone; no product code is linked, no registry is touched).
// The request sequence below is a copy of UpdRequest() from src/updcheck.cpp (working tree of the
// review), instrumented: timing of every call, the thread each callback ran on, callback counts.
//
//   r2_http <host> <port> <path> [secure 0|1] [cancelAfterMs]
//   r2_http tlsopt       - only the TLS option calls on a session (nothing is sent)
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>
#include <stdlib.h>
#include "../../../../src/common/salupdcheck.h"
#pragma comment(lib, "winhttp.lib")

#define UPDCHECK_RESOLVE_MS 4000
#define UPDCHECK_CONNECT_MS 4000
#define UPDCHECK_SEND_MS 2000
#define UPDCHECK_RECEIVE_MS 8000
#define UPDCHECK_DEADLINE_MS 12000

struct CUpdCheckContext
{
    HANDLE CancelEvent;
};

struct CUpdAsync
{
    HANDLE Event;
    HANDLE Closed;
    DWORD Status;
    DWORD Number;
    DWORD Error;
};

static DWORD WorkerTid;
static LONG CbCount = 0, CbInline = 0, CbAfterClose = 0, CbErrors = 0;
static LONG CloseCalled = 0;
static DWORD LastError = 0;
static DWORD T0;

static const char* StName(DWORD s)
{
    switch (s)
    {
    case WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE: return "SENDREQUEST_COMPLETE";
    case WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE: return "HEADERS_AVAILABLE";
    case WINHTTP_CALLBACK_STATUS_DATA_AVAILABLE: return "DATA_AVAILABLE";
    case WINHTTP_CALLBACK_STATUS_READ_COMPLETE: return "READ_COMPLETE";
    case WINHTTP_CALLBACK_STATUS_WRITE_COMPLETE: return "WRITE_COMPLETE";
    case WINHTTP_CALLBACK_STATUS_REQUEST_ERROR: return "REQUEST_ERROR";
    case WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING: return "HANDLE_CLOSING";
    case WINHTTP_CALLBACK_STATUS_HANDLE_CREATED: return "HANDLE_CREATED";
    }
    return "other";
}

static BOOL Verbose = TRUE;

static void CALLBACK UpdStatusCallback(HINTERNET handle, DWORD_PTR context, DWORD status,
                                       LPVOID info, DWORD infoLength)
{
    CUpdAsync* async = (CUpdAsync*)context;
    InterlockedIncrement(&CbCount);
    BOOL inl = GetCurrentThreadId() == WorkerTid;
    if (inl)
        InterlockedIncrement(&CbInline);
    if (CloseCalled && status != WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING)
        InterlockedIncrement(&CbAfterClose);
    if (Verbose && (status == WINHTTP_CALLBACK_STATUS_REQUEST_ERROR || status == WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING ||
                    status == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE || status == WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE))
        printf("    [%5lu ms] cb %-22s ctx=%s %s%s\n", GetTickCount() - T0, StName(status), context ? "set" : "NULL",
               inl ? "INLINE(worker thread)" : "winhttp thread", CloseCalled ? " after-close" : "");
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
        LastError = async->Error;
        InterlockedIncrement(&CbErrors);
        if (Verbose)
            printf("    REQUEST_ERROR api=%lu error=%lu\n", (DWORD)((WINHTTP_ASYNC_RESULT*)info)->dwResult, async->Error);
        break;
    case WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING:
        SetEvent(async->Closed);
        return;
    default:
        return;
    }
    async->Status = status;
    SetEvent(async->Event);
}

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

static DWORD MaxCallMs = 0;
static const char* MaxCallName = "";
#define TIMED(name, expr) TimedCall(name, GetTickCount(), (expr))
static BOOL TimedCall(const char* name, DWORD before, BOOL r)
{
    // 'before' is evaluated before 'expr' only by luck of argument order on MSVC x64 (right to left
    // is NOT guaranteed) - so the callers below take the tick themselves
    return r;
}

static CSalUpdResult UpdRequest(CUpdCheckContext* ctx, const WCHAR* host, INTERNET_PORT port, const WCHAR* path,
                                BOOL secure, CSalUpdRelease* release, BOOL* answered)
{
    memset(release, 0, sizeof(*release));
    *answered = FALSE;
    DWORD startTick = GetTickCount();
    T0 = startTick;
    CSalUpdResult result = surUnreachable;

    CUpdAsync* async = (CUpdAsync*)malloc(sizeof(CUpdAsync));
    char* body = (char*)malloc(SALUPD_MAX_ANSWER + 1);
    memset(async, 0, sizeof(*async));
    async->Event = CreateEventW(NULL, FALSE, FALSE, NULL);
    async->Closed = CreateEventW(NULL, TRUE, FALSE, NULL);

    DWORD t = GetTickCount();
    WCHAR proxy[100];
    DWORD proxyLen = GetEnvironmentVariableW(L"R2_PROXY", proxy, 100);
    BOOL useProxy = proxyLen > 0 && proxyLen < 100;
    BOOL noDisable = GetEnvironmentVariableW(L"R2_NODISABLE", NULL, 0) != 0; // negative control: authentication left on
    HINTERNET session = useProxy ? WinHttpOpen(SALUPD_USER_AGENT_W, WINHTTP_ACCESS_TYPE_NAMED_PROXY, proxy,
                                               WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC)
                                 : WinHttpOpen(SALUPD_USER_AGENT_W,
                                    secure ? WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY : WINHTTP_ACCESS_TYPE_NO_PROXY,
                                    WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC);
    printf("  WinHttpOpen: %lu ms, %s\n", GetTickCount() - t, session ? "ok" : "FAILED");
    HINTERNET connect = NULL;
    HINTERNET request = NULL;
    if (session != NULL)
    {
        WinHttpSetTimeouts(session, UPDCHECK_RESOLVE_MS, UPDCHECK_CONNECT_MS, UPDCHECK_SEND_MS, UPDCHECK_RECEIVE_MS);
        if (secure)
        {
            DWORD protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 | 0x00002000;
            if (!WinHttpSetOption(session, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols)))
            {
                printf("  TLS1.2|1.3 option refused (%lu), trying 1.2\n", GetLastError());
                protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
                if (!WinHttpSetOption(session, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols)))
                    printf("  TLS1.2 option refused too (%lu)\n", GetLastError());
            }
        }
        connect = WinHttpConnect(session, host, port, 0);
    }
    if (connect != NULL)
        request = WinHttpOpenRequest(connect, L"GET", path, NULL, WINHTTP_NO_REFERER,
                                     WINHTTP_DEFAULT_ACCEPT_TYPES, secure ? WINHTTP_FLAG_SECURE : 0);
    BOOL callbackSet = FALSE;
    if (request != NULL)
    {
        DWORD disable = WINHTTP_DISABLE_COOKIES | WINHTTP_DISABLE_AUTHENTICATION | WINHTTP_DISABLE_REDIRECTS;
        if (noDisable)
            disable = WINHTTP_DISABLE_COOKIES | WINHTTP_DISABLE_REDIRECTS;
        DWORD_PTR context = (DWORD_PTR)async;
        if (WinHttpSetOption(request, WINHTTP_OPTION_DISABLE_FEATURE, &disable, sizeof(disable)) &&
            WinHttpSetOption(request, WINHTTP_OPTION_CONTEXT_VALUE, &context, sizeof(context)) &&
            WinHttpSetStatusCallback(request, UpdStatusCallback,
                                     WINHTTP_CALLBACK_FLAG_ALL_COMPLETIONS | WINHTTP_CALLBACK_FLAG_HANDLES,
                                     0) != WINHTTP_INVALID_STATUS_CALLBACK)
            callbackSet = TRUE;
    }
    printf("  set-up done at %lu ms, callbackSet=%d\n", GetTickCount() - startTick, callbackSet);

    DWORD bodyLen = 0;
    BOOL bodyComplete = FALSE;
    BOOL timedOut = FALSE;
    DWORD status = 0;
    int reads = 0;
    if (callbackSet)
    {
        DWORD statusSize = sizeof(status);
        t = GetTickCount();
        BOOL sent = WinHttpSendRequest(request, SALUPD_HEADERS_W, (DWORD)-1L, WINHTTP_NO_REQUEST_DATA, 0, 0,
                                       (DWORD_PTR)async);
        DWORD sendErr = GetLastError();
        printf("  WinHttpSendRequest returned %d after %lu ms (error %lu)\n", sent, GetTickCount() - t, sent ? 0 : sendErr);
        DWORD st = 0;
        BOOL ok = sent && (st = UpdAwait(ctx, async, startTick, &timedOut)) == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE;
        printf("  [%5lu ms] after send await: %s\n", GetTickCount() - startTick, ok ? "SENDREQUEST_COMPLETE" : "no");
        if (ok)
        {
            t = GetTickCount();
            ok = WinHttpReceiveResponse(request, NULL);
            DWORD dt = GetTickCount() - t;
            if (dt > MaxCallMs) { MaxCallMs = dt; MaxCallName = "ReceiveResponse"; }
            ok = ok && UpdAwait(ctx, async, startTick, &timedOut) == WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE;
            printf("  [%5lu ms] after receive await: %s\n", GetTickCount() - startTick, ok ? "HEADERS_AVAILABLE" : "no");
        }
        if (ok && WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                                      WINHTTP_HEADER_NAME_BY_INDEX, &status, &statusSize, WINHTTP_NO_HEADER_INDEX))
        {
            *answered = TRUE;
            if (!SalUpdStatusWantsBody(status, &result))
            {
            }
            else
            {
                result = surUnexpected;
                for (;;)
                {
                    t = GetTickCount();
                    BOOL q = WinHttpQueryDataAvailable(request, NULL);
                    DWORD dt = GetTickCount() - t;
                    if (dt > MaxCallMs) { MaxCallMs = dt; MaxCallName = "QueryDataAvailable"; }
                    if (!q || UpdAwait(ctx, async, startTick, &timedOut) != WINHTTP_CALLBACK_STATUS_DATA_AVAILABLE)
                    {
                        result = surUnreachable;
                        break;
                    }
                    DWORD avail = async->Number;
                    if (avail == 0)
                    {
                        bodyComplete = TRUE;
                        break;
                    }
                    DWORD room = SALUPD_MAX_ANSWER + 1 - bodyLen;
                    t = GetTickCount();
                    BOOL r = WinHttpReadData(request, body + bodyLen, min(avail, room), NULL);
                    dt = GetTickCount() - t;
                    if (dt > MaxCallMs) { MaxCallMs = dt; MaxCallName = "ReadData"; }
                    if (!r || UpdAwait(ctx, async, startTick, &timedOut) != WINHTTP_CALLBACK_STATUS_READ_COMPLETE)
                    {
                        result = surUnreachable;
                        break;
                    }
                    DWORD read = async->Number;
                    reads++;
                    if (read == 0)
                    {
                        bodyComplete = TRUE;
                        break;
                    }
                    bodyLen += read;
                    if (bodyLen > SALUPD_MAX_ANSWER)
                        break;
                }
                DWORD announced = 0;
                DWORD announcedSize = sizeof(announced);
                BOOL haveCL = WinHttpQueryHeaders(request, WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER,
                                                  WINHTTP_HEADER_NAME_BY_INDEX, &announced, &announcedSize,
                                                  WINHTTP_NO_HEADER_INDEX);
                DWORD clErr = GetLastError();
                printf("  Content-Length query: %s (announced %lu, error %lu), bodyLen %lu, bodyComplete %d\n",
                       haveCL ? "ok" : "failed", announced, haveCL ? 0 : clErr, bodyLen, bodyComplete);
                if (bodyComplete && haveCL && announced != bodyLen)
                    bodyComplete = FALSE;
            }
        }
    }
    printf("  [%5lu ms] sequence over: status %lu, reads %d, bodyLen %lu, complete %d, timedOut %d, cancelled %d\n",
           GetTickCount() - startTick, status, reads, bodyLen, bodyComplete, timedOut,
           WaitForSingleObject(ctx->CancelEvent, 0) == WAIT_OBJECT_0);

    BOOL quiet = TRUE;
    if (request != NULL)
    {
        t = GetTickCount();
        InterlockedExchange(&CloseCalled, 1);
        WinHttpCloseHandle(request);
        DWORD closeRet = GetTickCount() - t;
        if (callbackSet)
            quiet = WaitForSingleObject(async->Closed, 5000) == WAIT_OBJECT_0;
        printf("  WinHttpCloseHandle(request) returned after %lu ms; HANDLE_CLOSING %s after %lu ms\n", closeRet,
               quiet ? "arrived" : "DID NOT ARRIVE", GetTickCount() - t);
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
            CSalUpdVersion installed = {0, 1, 8};
            result = SalUpdClassify(*release, installed);
        }
        else
        {
            printf("  parse refused, reason %d\n", (int)error);
            result = surUnexpected;
        }
    }
    printf("  TOTAL %lu ms; longest blocking WinHTTP call %lu ms (%s); callbacks %ld (inline %ld, after close %ld, errors %ld, last error %lu)\n",
           GetTickCount() - startTick, MaxCallMs, MaxCallName, CbCount, CbInline, CbAfterClose, CbErrors, LastError);
    if (quiet)
    {
        CloseHandle(async->Event);
        CloseHandle(async->Closed);
        free(async);
        free(body);
    }
    return result;
}

static DWORD CancelAfter = 0;
static DWORD WINAPI CancelThread(void* p)
{
    Sleep(CancelAfter);
    SetEvent((HANDLE)p);
    return 0;
}

int wmain(int argc, wchar_t** argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc >= 2 && wcscmp(argv[1], L"tlsopt") == 0)
    {
        HINTERNET s = WinHttpOpen(L"r2", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, NULL, NULL, WINHTTP_FLAG_ASYNC);
        printf("WinHttpOpen(AUTOMATIC_PROXY, ASYNC): %s (%lu)\n", s ? "ok" : "FAILED", s ? 0 : GetLastError());
        DWORD protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 | 0x00002000;
        BOOL r = WinHttpSetOption(s, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols));
        printf("SECURE_PROTOCOLS TLS1.2|TLS1.3 on the session: %d (%lu)\n", r, r ? 0 : GetLastError());
        DWORD got = 0, size = sizeof(got);
        r = WinHttpQueryOption(s, WINHTTP_OPTION_SECURE_PROTOCOLS, &got, &size);
        printf("read back: %d value 0x%lX\n", r, got);
        WinHttpCloseHandle(s);
        return 0;
    }
    if (argc < 4)
    {
        printf("usage\n");
        return 2;
    }
    BOOL secure = argc >= 5 && _wtoi(argv[4]) != 0;
    CUpdCheckContext ctx;
    ctx.CancelEvent = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (argc >= 6)
    {
        CancelAfter = _wtoi(argv[5]);
        CloseHandle(CreateThread(NULL, 0, CancelThread, ctx.CancelEvent, 0, NULL));
    }
    WorkerTid = GetCurrentThreadId();
    CSalUpdRelease release;
    BOOL answered;
    printf("=== %ls:%ls%ls secure=%d cancelAfter=%lu\n", argv[1], argv[2], argv[3], secure, CancelAfter);
    DWORD t = GetTickCount();
    CSalUpdResult r = UpdRequest(&ctx, argv[1], (INTERNET_PORT)_wtoi(argv[2]), argv[3], secure, &release, &answered);
    printf("  RESULT %s answered=%d version %u.%u.%u in %lu ms\n", SalUpdResultName(r), answered, release.Version.Major,
           release.Version.Minor, release.Version.Patch, GetTickCount() - t);
    Sleep(300); // late callbacks would show here
    printf("  callbacks total after 300 ms more: %ld\n", CbCount);
    return 0;
}
