// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "7zip.h"
#include "open.h"
#include "7zip.rh"
#include "7zip.rh2"
#include "lang\lang.rh"
#include "dialogs.h"
#include "FStreams.h"

#include "Common/StringConvert.h"
#include "Windows/PropVariant.h"
#include "structs.h" // U8ToUString, UStringToU8

HRESULT AnswerArchiveMemoryRequest(UInt64 requiredSize, UInt64* allowedSize, UInt32* answerFlags)
{
    UInt64 allowed = (UInt64)1 << 32; // 4 GiB: the engine's own default for RAR7
    MEMORYSTATUSEX ms;
    ms.dwLength = sizeof(ms);
    if (GlobalMemoryStatusEx(&ms) && ms.ullTotalPhys / 2 < allowed)
        allowed = ms.ullTotalPhys / 2;
    if (requiredSize <= allowed)
    {
        if (allowedSize != NULL)
            *allowedSize = allowed;
        *answerFlags = NRequestMemoryAnswerFlags::k_Allow;
    }
    else
    {
        TRACE_I("7zip: archive needs " << requiredSize << " bytes of memory, allowed " << allowed << " - refused");
        *answerFlags = NRequestMemoryAnswerFlags::k_Limit_Exceeded;
    }
    return S_OK;
}

CArchiveOpenCallbackImp::CArchiveOpenCallbackImp(UString& password, const char* archivePathU8,
                                                 CObjectVector<AString>* volumes)
    : Password(password), Volumes(volumes)
{
    const char* slash = archivePathU8 != NULL ? strrchr(archivePathU8, '\\') : NULL;
    if (slash != NULL)
    {
        FolderU8.SetFrom(archivePathU8, (unsigned)(slash - archivePathU8));
        FileNameW = U8ToUString(slash + 1);
    }
    else if (archivePathU8 != NULL)
        FileNameW = U8ToUString(archivePathU8);
}

CArchiveOpenCallbackImp::~CArchiveOpenCallbackImp()
{
}

Z7_COM7F_IMF(CArchiveOpenCallbackImp::SetTotal(const UInt64* /*files*/, const UInt64* /*bytes*/))
{
    return S_OK;
}

Z7_COM7F_IMF(CArchiveOpenCallbackImp::SetCompleted(const UInt64* /*files*/, const UInt64* /*bytes*/))
{
    return S_OK;
}

Z7_COM7F_IMF(CArchiveOpenCallbackImp::CryptoGetTextPassword(BSTR* password))
{
    if (Password.IsEmpty())
    {
        CEnterPasswordDialog dlg(SalamanderGeneral->GetMsgBoxParent());
        int res = (int)dlg.Execute();

        if (res != IDOK)
            return E_ABORT;

        // the password comes from our own ANSI dialog, so it is in the ACP, not
        // UTF-8; the engine gets it as UTF-16 (feature 087: characters outside
        // the code page cannot be typed into the ANSI dialog yet - cluster B-1)
        Password = GetUnicodeString(dlg.GetPassword());
    }
    return StringToBstr(Password, password); // E_OUTOFMEMORY when the BSTR cannot be allocated
}

// feature 087 (P3): the other parts of a multi-part archive (RAR "x.partN.rar",
// "x.rar" + "x.rNN"). The handler composes the names itself; the plugin only
// opens siblings of the first part - a name with a separator or a drive is
// never followed.
Z7_COM7F_IMF(CArchiveOpenCallbackImp::GetStream(const wchar_t* name, IInStream** inStream))
{
    *inStream = NULL;
    if (name == NULL || *name == 0 || wcschr(name, L'\\') != NULL || wcschr(name, L'/') != NULL ||
        wcschr(name, L':') != NULL)
        return S_FALSE;
    try // the method is throw(): an allocation failure must not leave it
    {
        AString path = FolderU8;
        path += '\\';
        path += UStringToU8(name);

        // a missing part is no error dialog here: S_FALSE lets the handler report it
        if (GetFileAttributesU8(path) == INVALID_FILE_ATTRIBUTES)
            return S_FALSE;
        CRetryableInFileStream* fileSpec = new CRetryableInFileStream(NULL);
        CMyComPtr<IInStream> file = fileSpec;
        if (!fileSpec->Open(path))
            return S_FALSE;
        if (Volumes != NULL)
            Volumes->Add(path);
        *inStream = file.Detach();
        return S_OK;
    }
    catch (...)
    {
        return E_OUTOFMEMORY;
    }
}

Z7_COM7F_IMF(CArchiveOpenCallbackImp::GetProperty(PROPID propID, PROPVARIANT* value))
{
    try // the method is throw(): an allocation failure must not leave it
    {
        NWindows::NCOM::CPropVariant prop;
        if (propID == kpidName)
            prop = FileNameW; // the first part: the handler derives the others from it
        prop.Detach(value);
        return S_OK;
    }
    catch (...)
    {
        return E_OUTOFMEMORY;
    }
}

Z7_COM7F_IMF(CArchiveOpenCallbackImp::RequestMemoryUse(UInt32 /*flags*/, UInt32 /*indexType*/, UInt32 /*index*/,
                                                       const wchar_t* /*path*/, UInt64 requiredSize,
                                                       UInt64* allowedSize, UInt32* answerFlags))
{
    return AnswerArchiveMemoryRequest(requiredSize, allowedSize, answerFlags);
}
