// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "7za/CPP/Common/MyCom.h"
#include "7za/CPP/Common/MyString.h"
#include "7za/CPP/Common/MyVector.h"

#include "7za/CPP/7zip/IPassword.h"
#include "7za/CPP/7zip/Archive/IArchive.h"

// The engine's memory request for an archive (RAR5/RAR7 dictionaries): allowed
// up to min(4 GiB, half of physical memory), refused beyond - the operation
// then fails with an error instead of allocating unbounded memory (feature 087,
// contracts/plugin-engine.md P5). Shared by the open and extract callbacks.
HRESULT AnswerArchiveMemoryRequest(UInt64 requiredSize, UInt64* allowedSize, UInt32* answerFlags);

// feature 087: 7-Zip 26.03 interface macros (Z7_*, every method throw()); the
// volume callback is exposed (RAR multi-part archives), and the memory request
// callback (contracts/plugin-engine.md P3, P5)
class CArchiveOpenCallbackImp Z7_final : public IArchiveOpenCallback,
                                         public IArchiveOpenVolumeCallback,
                                         public ICryptoGetTextPassword,
                                         public IArchiveRequestMemoryUseCallback,
                                         public CMyUnknownImp
{
    Z7_COM_UNKNOWN_IMP_3(IArchiveOpenVolumeCallback, ICryptoGetTextPassword, IArchiveRequestMemoryUseCallback)
    Z7_IFACE_COM7_IMP(IArchiveOpenCallback)
    Z7_IFACE_COM7_IMP(IArchiveOpenVolumeCallback)
    Z7_IFACE_COM7_IMP(ICryptoGetTextPassword)
    Z7_IFACE_COM7_IMP(IArchiveRequestMemoryUseCallback)

private:
    UString& Password;
    AString FolderU8;                // the opened archive's folder (UTF-8, interface 104), no trailing '\'
    UString FileNameW;               // the opened archive's file name
    CObjectVector<AString>* Volumes; // out: full UTF-8 paths of the other volumes opened (may be NULL)

public:
    // If entered, the password gets propagated towards password; 'archivePathU8'
    // is the opened file (UTF-8) - its siblings are the other volumes; 'volumes'
    // receives the other parts the handler opened (for "unpack and delete")
    CArchiveOpenCallbackImp(UString& password, const char* archivePathU8, CObjectVector<AString>* volumes);
    ~CArchiveOpenCallbackImp();
};
