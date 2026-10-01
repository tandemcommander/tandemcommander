// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "7za/CPP/Common/MyCom.h"
#include "7za/CPP/7zip/IStream.h"

// Streams that feed 7za with data from disk.
//
// They implement the 7za stream interfaces directly instead of deriving from
// CInFileStream/COutFileStream: the bundled 7za is built with FString ==
// AString (USE_UNICODE_FSTRING is off), so its file layer converts char paths
// with the ANSI code page and is limited to MAX_PATH. Neither works for the
// UTF-8, potentially long paths of plugin interface 104.
//
// Every path handed to these classes is UTF-8 (as received from Salamander);
// it is opened through the W file API with the \\?\ prefix (splunicode.h).
// On a read/write error the user is offered Retry/Abort.

// feature 087: 7-Zip 26.03 interface macros (Z7_*, every method throw())
class CRetryableOutFileStream Z7_final : public IOutStream,
                                         public CMyUnknownImp
{
    Z7_COM_UNKNOWN_IMP_1(IOutStream)
    Z7_IFACE_COM7_IMP(ISequentialOutStream)
    Z7_IFACE_COM7_IMP(IOutStream)

public:
    CRetryableOutFileStream(HWND hParentWnd);

    virtual ~CRetryableOutFileStream();

    // 'u8FileName' is a UTF-8 path coming from the Salamander interface
    bool Open(const char* u8FileName, DWORD creationDisposition);
    bool Close();

    bool SetMTime(const FILETIME* mTime);

private:
    HANDLE Handle;
    HWND hParentWnd;
};

class CRetryableInFileStream Z7_final : public IInStream,
                                        public IStreamGetSize,
                                        public CMyUnknownImp
{
    Z7_COM_UNKNOWN_IMP_2(IInStream, IStreamGetSize)
    Z7_IFACE_COM7_IMP(ISequentialInStream)
    Z7_IFACE_COM7_IMP(IInStream)
    Z7_IFACE_COM7_IMP(IStreamGetSize)

public:
    CRetryableInFileStream(HWND hParentWnd);

    virtual ~CRetryableInFileStream();

    // 'u8FileName' is a UTF-8 path coming from the Salamander interface
    bool Open(const char* u8FileName);
    bool Close();

private:
    HANDLE Handle;
    HWND hParentWnd;
};
