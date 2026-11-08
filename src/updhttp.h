// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// updhttp.h
//
// The asynchronous WinHTTP helpers shared by the check for a new version
// (feature 123, updcheck.cpp) and the download of its installer (feature 420,
// updinstall.cpp). WinHTTP is used in its asynchronous mode, the only one in
// which a request may be abandoned from another thread's point of view: the
// worker starts each step and waits for its completion, for a cancel event or
// for a deadline, whichever comes first; then it closes the request handle
// itself. Include after <winhttp.h>.
//
//*****************************************************************************

// what the WinHTTP callback (any thread) hands to the worker
struct CUpdAsync
{
    HANDLE Event;  // auto-reset: the step in progress completed
    HANDLE Closed; // manual-reset: the request handle is gone, no callback will come any more
    DWORD Status;  // WINHTTP_CALLBACK_STATUS_* of the completion
    DWORD Number;  // DATA_AVAILABLE: bytes waiting; READ_COMPLETE: bytes read
    DWORD Error;   // REQUEST_ERROR: the Windows error
};

static void CALLBACK UpdHttpStatusCallback(HINTERNET handle, DWORD_PTR context, DWORD status,
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

// Waits for the completion of the step just started. Returns its status, or 0 when 'cancel'
// was signalled or 'deadlineMs' since 'startTick' passed ('*timedOut' TRUE) - the step is then
// still pending and the caller must close the request handle before it frees anything the step
// uses.
static DWORD UpdHttpAwait(HANDLE cancel, CUpdAsync* async, DWORD startTick, DWORD deadlineMs, BOOL* timedOut)
{
    DWORD elapsed = GetTickCount() - startTick;
    DWORD left = elapsed >= deadlineMs ? 0 : deadlineMs - elapsed;
    HANDLE handles[2] = {async->Event, cancel};
    DWORD wait = WaitForMultipleObjects(2, handles, FALSE, left);
    if (wait == WAIT_OBJECT_0)
        return async->Status;
    if (wait == WAIT_TIMEOUT)
        *timedOut = TRUE;
    return 0;
}
