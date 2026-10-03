// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#define MessageCenterName "RemoteComparator"
#define StartedEventName "RemoteComparatorStarted"

// feature 102: the message fcremote.exe sends to the plug-in, channel version 2.
//
// Version 1 (up to 0.1.8; CMessageCenter::Version "1", 808 bytes):
//   CMessage, char CurrentDirectory[260], char Path1[260], char Path2[260],
//   char ReleaseEvent[20] - the names in fcremote's code page (best-fit mapped by the
//   command line conversion), which the plug-in read as UTF-8: every non-ASCII name failed,
//   a best-fit twin ("voila.txt" for a-grave) or bytes that happened to be valid UTF-8
//   opened a different file; relative names were resolved by the plug-in.
// Version 2 (CMessageCenter::Version "2"): one message of variable length below; the names
//   are full paths (fcremote resolves them with GetFullPathNameW) in UTF-16, exact for every
//   name, any length up to the Windows limit (the channel's buffer holds two names of 32,767
//   units).  The version names the shared buffer, so a version-1 and a version-2 side never
//   exchange a message: the sender's OpenFileMapping fails and it reports an error.
#define RCMESSAGE_MAGIC 0x32524346 // "FCR2"

#include "fcproto.h" // the argument split, the name tail, the message check (header-only)

#pragma pack(push, 4)
struct CRCMessage
{
    CMessage Header;       // Header.Size = RCMESSAGE_HEADER_SIZE + (Path1Len + 1 + Path2Len + 1) * sizeof(WCHAR)
    DWORD Magic;           // RCMESSAGE_MAGIC
    char ReleaseEvent[20]; // name of fcremote's event for -w (ASCII, "FCREMOTE<pid>"), "" = no wait
    DWORD Path1Len;        // UTF-16 units of the first name, without the terminator
    DWORD Path2Len;        // UTF-16 units of the second name, without the terminator
    WCHAR Names[1];        // the first name, L'\0', the second name, L'\0'
};
#pragma pack(pop)

#define RCMESSAGE_HEADER_SIZE ((int)FIELD_OFFSET(CRCMessage, Names))
