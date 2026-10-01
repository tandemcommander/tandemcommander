// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "7za/CPP/Common/MyCom.h"
#include "7za/CPP/Common/MyString.h"

#include "7za/CPP/7zip/IPassword.h"
#include "7za/CPP/7zip/Archive/IArchive.h"

// feature 087: 7-Zip 26.03 interface macros (Z7_*, every method throw())
class CArchiveOpenCallbackImp Z7_final : public IArchiveOpenCallback,
                                         public IArchiveOpenVolumeCallback,
                                         public ICryptoGetTextPassword,
                                         public CMyUnknownImp
{
    Z7_COM_UNKNOWN_IMP_1(ICryptoGetTextPassword)
    Z7_IFACE_COM7_IMP(IArchiveOpenCallback)
    Z7_IFACE_COM7_IMP(IArchiveOpenVolumeCallback)
    Z7_IFACE_COM7_IMP(ICryptoGetTextPassword)

private:
    UString& Password;

public:
    // If entered, the password gets propagated towards password
    CArchiveOpenCallbackImp(UString& password);
    ~CArchiveOpenCallbackImp();
};
