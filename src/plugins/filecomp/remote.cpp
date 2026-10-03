// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

// ****************************************************************************
//
// CRemoteComparator
//

BOOL CRemoteComparator::Created = FALSE;
HANDLE CRemoteComparator::RemoteComparatorThread = NULL;
HANDLE CRemoteComparator::TerminateEvent = NULL;

CRemoteComparator::CRemoteComparator()
    : CThread("Remote Comparator"),
      MessageCenter(MessageCenterName, FALSE){
          CALL_STACK_MESSAGE_NONE}

      CRemoteComparator::~CRemoteComparator()
{
    CALL_STACK_MESSAGE_NONE
}

void CRemoteComparator::CreateRemoteComparator()
{
    CALL_STACK_MESSAGE1("CRemoteComparator::CreateRemoteComparator()");
    if (Created)
        return;

    TerminateEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
    if (TerminateEvent == NULL)
        return;

    CRemoteComparator* rc = new CRemoteComparator;
    if (!rc)
    {
        Error((HWND)-1, IDS_LOWMEM);
        CloseHandle(TerminateEvent);
        TerminateEvent = NULL;
        return;
    }
    // TODO set a smaller stack size
    RemoteComparatorThread = rc->Create(ThreadQueue);
    if (!RemoteComparatorThread)
    {
        delete rc;
        CloseHandle(TerminateEvent);
        TerminateEvent = NULL;
        return;
    }
    Created = TRUE;
}

BOOL CRemoteComparator::Terminate(BOOL force)
{
    CALL_STACK_MESSAGE2("CRemoteComparator::Terminate(%d)", force);
    if (!Created)
        return TRUE;

    SetEvent(TerminateEvent);
    if (!ThreadQueue.WaitForExit(RemoteComparatorThread, force ? 200 : 1000))
    {
        if (!force)
        {
            ResetEvent(TerminateEvent);
            TRACE_E("Remote comparator thread has not finished, we will refuse to unload plugin.");
            return FALSE;
        }
        TRACE_E("Remote comparator thread has not finished, we will terminate it.");
        ThreadQueue.KillThread(RemoteComparatorThread, 666);
    }
    RemoteComparatorThread = NULL;
    CloseHandle(TerminateEvent);
    TerminateEvent = NULL;
    Created = FALSE;
    return TRUE;
}

unsigned
CRemoteComparator::Body()
{
    CALL_STACK_MESSAGE1("CRemoteComparator::Body()");
    if (!MessageCenter.IsGood())
        return -1;
    BOOL ret;
    HANDLE started = CreateEvent(NULL, TRUE, FALSE, StartedEventName);
    SetEvent(started);
    while (1)
    {
        BOOL success;
        BOOL canceled;
        ret = MessageCenter.WaitForMessage(success, INFINITE, TerminateEvent, canceled);
        if (!ret)
            break;
        if (canceled)
            break;
        if (success)
            MessageCenter.RecieveMessages(this);
    }
    ResetEvent(started);
    CloseHandle(started);
    return ret ? 0 : -1;
}

// feature 102: a full name from fcremote (UTF-16) as the plug-in's UTF-8 (WTF-8: a lone
// surrogate survives); an "\\?\" name, which fcremote passes through unchanged, in its display
// form (FcDisplayFormU8, fcproto.h); NULL on failure
static char* RemoteNameToU8(const WCHAR* name)
{
    char* u8 = SplWToU8Alloc(name);
    if (u8 != NULL)
        FcDisplayFormU8(u8);
    return u8;
}

// allow fcremote.exe -w to continue
static void SignalReleaseEvent(const char* releaseEvent)
{
    if (*releaseEvent)
    {
        HANDLE event = OpenEvent(EVENT_MODIFY_STATE, FALSE, releaseEvent);
        if (event != NULL)
        {
            SetEvent(event);
            CloseHandle(event);
        }
    }
}

void CRemoteComparator::RecieveMessage(const CMessage* message, int size)
{
    CALL_STACK_MESSAGE1("CRemoteComparator::RecieveMessage()");
    // feature 102: channel version 2 (remotmsg.h): a variable-length message with UTF-16 names.
    // 'size' was checked against the shared buffer by CMessageCenter::RecieveMessages; the
    // message is copied out of the shared memory once and only the copy is checked and used
    // (review: another process could change the shared bytes between a check and a use)
    if (size < RCMESSAGE_HEADER_SIZE + 2 * (int)sizeof(WCHAR))
        return; // not even the fixed part: nothing to answer
    CRCMessage* msg = (CRCMessage*)malloc(size);
    if (msg == NULL)
        return;
    memcpy(msg, message, size);
    if (msg->Magic != RCMESSAGE_MAGIC)
    {
        free(msg);
        return;
    }

    char releaseEvent[sizeof(msg->ReleaseEvent)];
    if (memchr(msg->ReleaseEvent, 0, sizeof(msg->ReleaseEvent)) == NULL)
    {
        free(msg);
        return; // a damaged event name: it cannot be answered either
    }
    strcpy(releaseEvent, msg->ReleaseEvent);

    // the names must fill the message exactly and be terminated where the lengths say
    if (!FcCheckNames(size, RCMESSAGE_HEADER_SIZE, msg->Path1Len, msg->Path2Len, msg->Names))
    {
        TRACE_E("CRemoteComparator::RecieveMessage(): malformed message.");
        free(msg);
        SignalReleaseEvent(releaseEvent); // "-w" must not wait for a comparison that never starts
        return;
    }

    char* path1 = RemoteNameToU8(msg->Names);
    char* path2 = RemoteNameToU8(msg->Names + msg->Path1Len + 1);
    free(msg);

    BOOL ok = FALSE;
    if (path1 == NULL || path2 == NULL)
        Error((HWND)NULL, IDS_LOWMEM);
    else
    {
        // names longer than the comparator's buffers cannot be Windows paths; the comparator
        // then asks for the files with an empty field instead of comparing a cut name
        if (strlen(path1) >= FC_NAME_SIZE)
            *path1 = 0;
        if (strlen(path2) >= FC_NAME_SIZE)
            *path2 = 0;
        CFilecompThread* d = new CFilecompThread(path1, path2, TRUE, releaseEvent);
        if (!d)
        {
            Error((HWND)NULL, IDS_LOWMEM);
        }
        else
        {
            ok = d->Create(ThreadQueue) != NULL;
            if (!ok)
                delete d;
        }
    }
    free(path1);
    free(path2);

    if (!ok)
        SignalReleaseEvent(releaseEvent);
}
