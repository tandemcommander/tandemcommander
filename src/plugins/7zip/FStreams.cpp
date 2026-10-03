// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "FStreams.h"
#include "7Zip.h"
#include "7zclient.h"
#include "7zthreads.h"
#include "7zip.rh"
#include "7zip.rh2"
#include "lang\lang.rh"

// 7za never reads/writes more than 4 MB in one call (see CInFile::ReadPart
// and COutFile::WritePart); keep the same granularity
static const UInt32 kChunkSizeMax = (1 << 22);

static HRESULT LastErrorToHRESULT()
{
    DWORD err = ::GetLastError();
    if (err == 0)
        return E_FAIL;
    return HRESULT_FROM_WIN32(err);
}

BOOL ShowRetryAbortBox(HWND hParentWnd, int resID, DWORD err, ...)
{
    TCHAR msg[1024];
    va_list arglist;
    va_start(arglist, err);

    msg[0] = 0;
    _vsnprintf_s(msg, _countof(msg), _TRUNCATE, LoadStr(resID), arglist); // feature 098: bounded
    va_end(arglist);

    if (!_tcsncmp(msg, _T("{!}"), 3))
    {
        TCHAR fmt[1024];
        SalamanderGeneral->ExpandPluralString(fmt, sizeof(fmt), msg, 1, &CQuadWord().SetUI64(((int*)&err)[1]));
        strcpy(msg, fmt);
    }
    TCHAR buf[2048 + 4];
    _snprintf_s(buf, _countof(buf), _TRUNCATE, _T("%s\n\n%s"), msg, SalamanderGeneral->GetErrorText(err)); // feature 098: bounded

    TCHAR btnBuffer[128];
    /* used by the export_mnu.py script, which generates salmenu.mnu for the Translator
   let the message box buttons handle hotkey collisions by simulating a menu
MENU_TEMPLATE_ITEM MsgBoxButtons[] =
{
  {MNTT_PB, 0
  {MNTT_IT, IDS_BTN_RETRY
  {MNTT_IT, IDS_BTN_ABORT
  {MNTT_PE, 0
};
*/
    _stprintf(btnBuffer, _T("%d\t%s\t%d\t%s"),
              DIALOG_RETRY, LoadStr(IDS_BTN_RETRY),
              DIALOG_CANCEL, LoadStr(IDS_BTN_ABORT));

    MSGBOXEX_PARAMS mbep;
    ZeroMemory(&mbep, sizeof(mbep));
    mbep.HParent = hParentWnd;
    mbep.Caption = LoadStr(IDS_PLUGINNAME);
    mbep.Text = buf;
    mbep.Flags = MSGBOXEX_RETRYCANCEL | MSGBOXEX_ICONEXCLAMATION;
    mbep.AliasBtnNames = btnBuffer;
    if (hParentWnd)
    {
        return SendMessage(hParentWnd, WM_7ZIP, WM_7ZIP_SHOWMBOXEX, (LPARAM)&mbep) == DIALOG_RETRY;
    }
    else
    {
        // This can only happen when reading an archive file
        mbep.HParent = SalamanderGeneral->GetMsgBoxParent();
        return SalamanderGeneral->SalMessageBoxEx(&mbep) == DIALOG_RETRY;
    }
}

// ****************************************************************************
//
// CRetryableOutFileStream
//

CRetryableOutFileStream::CRetryableOutFileStream(HWND _hParentWnd)
    : Handle(INVALID_HANDLE_VALUE), hParentWnd(_hParentWnd)
{
}

CRetryableOutFileStream::~CRetryableOutFileStream()
{
    Close();
}

bool CRetryableOutFileStream::Open(const char* u8FileName, DWORD creationDisposition)
{
    Close();
    Handle = CreateFileU8(u8FileName, GENERIC_WRITE, FILE_SHARE_READ, creationDisposition);
    return Handle != INVALID_HANDLE_VALUE;
}

bool CRetryableOutFileStream::Close()
{
    if (Handle == INVALID_HANDLE_VALUE)
        return true;
    if (!::CloseHandle(Handle))
        return false;
    Handle = INVALID_HANDLE_VALUE;
    return true;
}

bool CRetryableOutFileStream::SetMTime(const FILETIME* mTime)
{
    if (Handle == INVALID_HANDLE_VALUE)
        return false;
    return ::SetFileTime(Handle, NULL, NULL, mTime) != FALSE;
}

Z7_COM7F_IMF(CRetryableOutFileStream::Write(const void* data, UInt32 size, UInt32* processedSize))
{
    if (processedSize != NULL)
        *processedSize = 0;

    while (size > 0)
    {
        DWORD toWrite = (size > kChunkSizeMax) ? kChunkSizeMax : size;
        DWORD written = 0;
        BOOL res = ::WriteFile(Handle, data, toWrite, &written, NULL);
        DWORD err = ::GetLastError();

        data = (const unsigned char*)data + written;
        size -= written;
        if (processedSize != NULL)
            *processedSize += written;

        if (!res)
        {
            if (!ShowRetryAbortBox(hParentWnd, IDS_CANT_WRITE, err, size))
                return E_ABORT;
        }
        else if (written == 0)
            return E_FAIL; // no progress although WriteFile succeeded, avoid an endless loop
    }

    return S_OK;
}

Z7_COM7F_IMF(CRetryableOutFileStream::Seek(Int64 offset, UInt32 seekOrigin, UInt64* newPosition))
{
    if (seekOrigin >= 3)
        return STG_E_INVALIDFUNCTION;

    // STREAM_SEEK_SET/CUR/END have the same values as FILE_BEGIN/CURRENT/END
    LARGE_INTEGER distance;
    LARGE_INTEGER newPos;
    distance.QuadPart = offset;
    if (!::SetFilePointerEx(Handle, distance, &newPos, seekOrigin))
        return LastErrorToHRESULT();
    if (newPosition != NULL)
        *newPosition = (UInt64)newPos.QuadPart;

    return S_OK;
}

Z7_COM7F_IMF(CRetryableOutFileStream::SetSize(UInt64 newSize))
{
    LARGE_INTEGER zero;
    LARGE_INTEGER currentPos;
    zero.QuadPart = 0;
    if (!::SetFilePointerEx(Handle, zero, &currentPos, FILE_CURRENT))
        return E_FAIL;

    LARGE_INTEGER size;
    size.QuadPart = (LONGLONG)newSize;
    if (!::SetFilePointerEx(Handle, size, NULL, FILE_BEGIN) || !::SetEndOfFile(Handle))
        return E_FAIL;

    // restore the original position
    if (!::SetFilePointerEx(Handle, currentPos, NULL, FILE_BEGIN))
        return E_FAIL;

    return S_OK;
}

// ****************************************************************************
//
// CRetryableInFileStream
//

CRetryableInFileStream::CRetryableInFileStream(HWND _hParentWnd)
    : Handle(INVALID_HANDLE_VALUE), hParentWnd(_hParentWnd)
{
}

CRetryableInFileStream::~CRetryableInFileStream()
{
    Close();
}

bool CRetryableInFileStream::Open(const char* u8FileName)
{
    Close();
    Handle = CreateFileU8(u8FileName, GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING);
    return Handle != INVALID_HANDLE_VALUE;
}

bool CRetryableInFileStream::Close()
{
    if (Handle == INVALID_HANDLE_VALUE)
        return true;
    if (!::CloseHandle(Handle))
        return false;
    Handle = INVALID_HANDLE_VALUE;
    return true;
}

Z7_COM7F_IMF(CRetryableInFileStream::Read(void* data, UInt32 size, UInt32* processedSize))
{
    if (processedSize != NULL)
        *processedSize = 0;
    if (size > kChunkSizeMax)
        size = kChunkSizeMax; // a partial read is allowed by ISequentialInStream

    for (;;)
    {
        DWORD read = 0;
        if (::ReadFile(Handle, data, size, &read, NULL))
        {
            if (processedSize != NULL)
                *processedSize = read; // read == 0 means end of file
            return S_OK;
        }

        DWORD err = ::GetLastError();
        // the archive itself is read without a progress dialog (hParentWnd == NULL)
        if (!ShowRetryAbortBox(hParentWnd, hParentWnd != NULL ? IDS_CANT_READ : IDS_CANT_READ_ARCHIVE, err, size))
            return E_ABORT;
    }
}

Z7_COM7F_IMF(CRetryableInFileStream::Seek(Int64 offset, UInt32 seekOrigin, UInt64* newPosition))
{
    if (seekOrigin >= 3)
        return STG_E_INVALIDFUNCTION;

    // STREAM_SEEK_SET/CUR/END have the same values as FILE_BEGIN/CURRENT/END
    LARGE_INTEGER distance;
    LARGE_INTEGER newPos;
    distance.QuadPart = offset;
    if (!::SetFilePointerEx(Handle, distance, &newPos, seekOrigin))
        return LastErrorToHRESULT();
    if (newPosition != NULL)
        *newPosition = (UInt64)newPos.QuadPart;

    return S_OK;
}

Z7_COM7F_IMF(CRetryableInFileStream::GetSize(UInt64* size))
{
    LARGE_INTEGER fileSize;
    if (!::GetFileSizeEx(Handle, &fileSize))
        return LastErrorToHRESULT();
    if (size != NULL)
        *size = (UInt64)fileSize.QuadPart;

    return S_OK;
}
