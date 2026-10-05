// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "..\undelete.rh2"

#include "miscstr.h"
#include "os.h"
#include "volume.h"
#include "snapshot.h"
#include "volenum.h"

#include "../dialogs.h"
#include "../undelete.h"

#include "../../../common/salnameorder.h" // feature 115: name identity by the file system's rule

// ****************************************************************************
//
// LoadStr() - helper function for reading strings from resources
//

class C__StrCriticalSection
{
public:
    CRITICAL_SECTION cs;
    C__StrCriticalSection() { NOHANDLES(InitializeCriticalSection(&cs)); }
    ~C__StrCriticalSection() { NOHANDLES(DeleteCriticalSection(&cs)); }
};

// ensure critical section is initialized in the beginning
#pragma warning(disable : 4073)
#pragma init_seg(lib)
C__StrCriticalSection __StrCriticalSection;

const unsigned short String<char>::STRBUFSIZE = 10240;
char* String<char>::StringBuffer = NULL;
char* String<char>::StrAct = String<char>::StringBuffer;

const unsigned short String<wchar_t>::STRBUFSIZE = 10240;
wchar_t* String<wchar_t>::StringBuffer = NULL;
wchar_t* String<wchar_t>::StrAct = String<wchar_t>::StringBuffer;

extern HINSTANCE DLLInstance;

template <>
char* String<char>::LoadStr(int resID)
{
    HANDLES(EnterCriticalSection(&__StrCriticalSection.cs));

    char* ret;
    static char errorBuff[] = "ERROR LOADING STRING - INSUFFICIENT MEMORY";
    if (!StringBuffer)
        ret = errorBuff;
    else
    {
        if (STRBUFSIZE - (StrAct - StringBuffer) < 200)
            StrAct = StringBuffer;

        HINSTANCE hInstance = HLanguage;

#ifdef _DEBUG
        // ensure it is not called before handle is initialized
        if (hInstance == NULL)
            TRACE_E("LoadStr: hInstance == NULL");
#endif // _DEBUG

    RELOAD:
        int size = LoadStringA(hInstance, resID, StrAct, STRBUFSIZE - (int)(StrAct - StringBuffer));
        // size contains number of copied characters without terminator
        //    DWORD error = GetLastError();
        if (size != 0 /* || error == NO_ERROR*/) // error is NO_ERROR even if string doesn't exist, we cannot use it
        {
            if (STRBUFSIZE - (StrAct - StringBuffer) == size + 1 && StrAct > StringBuffer)
            {
                // if string was placed exactly on the buffer end, it could be incomplete
                // we will read it again to the beginning of buffer
                StrAct = StringBuffer;
                goto RELOAD;
            }
            else
            {
                ret = StrAct;
                StrAct += size + 1;
            }
        }
        else
        {
            TRACE_E("Error in LoadStr(" << resID << ")." /*"): " << GetErrorText(error)*/);
            static char errorBuff2[] = "ERROR LOADING STRING";
            ret = errorBuff2;
        }
    }

    HANDLES(LeaveCriticalSection(&__StrCriticalSection.cs));

    return ret;
}

template <>
wchar_t* String<wchar_t>::LoadStr(int resID)
{
    HANDLES(EnterCriticalSection(&__StrCriticalSection.cs));

    wchar_t* ret;
    static wchar_t errorBuff[] = L"ERROR LOADING STRING - INSUFFICIENT MEMORY";
    if (!StringBuffer)
        ret = errorBuff;
    else
    {
        if (STRBUFSIZE - (StrAct - StringBuffer) < 200)
            StrAct = StringBuffer;

        HINSTANCE hInstance = HLanguage;

#ifdef _DEBUG
        // ensure it is not called before handle is initialized
        if (hInstance == NULL)
            TRACE_E("LoadStr: hInstance == NULL");
#endif // _DEBUG

    RELOAD:
        int size = LoadStringW(hInstance, resID, StrAct, STRBUFSIZE - (int)(StrAct - StringBuffer));
        // size contains number of copied characters without terminator
        //    DWORD error = GetLastError();
        if (size != 0 /* || error == NO_ERROR*/) // error is NO_ERROR even if string doesn't exist, we cannot use it
        {
            if ((DWORD)(STRBUFSIZE - (StrAct - StringBuffer)) == (DWORD)(size + 1) && StrAct > StringBuffer)
            {
                // if string was placed exactly on the buffer end, it could be incomplete
                // we will read it again to the beginning of buffer
                StrAct = StringBuffer;
                goto RELOAD;
            }
            else
            {
                ret = StrAct;
                StrAct += size + 1;
            }
        }
        else
        {
            TRACE_E("Error in LoadStr(" << resID << ")." /*"): " << GetErrorText(error)*/);
            static wchar_t errorBuff2[] = L"ERROR LOADING STRING";
            ret = errorBuff2;
        }
    }

    HANDLES(LeaveCriticalSection(&__StrCriticalSection.cs));

    return ret;
}

template <>
void String<char>::VSPrintF(char* buffer, const char* pattern, va_list& marker)
{
    vsprintf(buffer, pattern, marker);
}

template <>
int String<char>::StrCmp(const char* string1, const char* string2)
{
    return strcmp(string1, string2);
}

template <>
int String<char>::StrICmp(const char* string1, const char* string2)
{
    return _stricmp(string1, string2);
}

// feature 115: names are WTF-8 (114); _stricmp folds ASCII only, so "C-caron.txt" and
// "c-caron.txt" - one file for Windows - were two names (not numbered: the second restore asked
// to overwrite the first). A total order: equal names are neighbours after a sort by it.
template <>
int String<char>::NameCmp(const char* string1, const char* string2)
{
    return SalNameOrderCompareCI(string1, -1, string2, -1);
}

template <>
size_t String<char>::StrLen(const char* text)
{
    return strlen(text);
}

template <>
char String<char>::ToUpper(char c)
{
    return toupper(c);
}

template <>
char* String<char>::StrCpy(char* text1, const char* text2)
{
    return strcpy(text1, text2);
}

template <>
char* String<char>::StrCat(char* text1, const char* text2)
{
    return strcat(text1, text2);
}

template <>
errno_t String<char>::StrCat_s(char* strDestination, size_t numberOfElements, const char* strSource)
{
    return strcat_s(strDestination, numberOfElements, strSource);
}

template <>
char* String<char>::AddNumberSuffix(char* filename, int n)
{
    char* ext = strrchr(filename, '.'); // ".cvspass" is extension in Windows
    if (ext != NULL && (ext - filename) != ((int)strlen(filename) - 4))
        ext = NULL;

    // feature 114: sized by the name - a name is up to 255 UTF-16 units, 765 bytes of UTF-8, and
    // the fixed MAX_PATH + 50 bytes overran the stack for two equal long names (a FAT directory
    // with two deleted files of one long CJK name, or a restore of {All Deleted Files})
    size_t len = strlen(filename);
    char* ret = new char[len + 32]; // " (" + up to 11 digits + ")" + terminator
    if (ret == NULL)
        return NULL;
    if (ext == NULL)
    {
        sprintf(ret, "%s (%d)", filename, n);
    }
    else
    {
        memcpy(ret, filename, ext - filename);
        sprintf(ret + (ext - filename), " (%d)%s", n, ext);
    }
    return ret;
}

template <>
char* String<char>::CopyFromASCII(char* dest, const char* src, unsigned long srclen, unsigned long destlen)
{
    if (destlen)
        dest[0] = 0;
    if (srclen)
    {
        if (destlen > srclen)
        {
            strncpy(dest, src, srclen);
            dest[srclen] = 0;
        }
        else
            TRACE_E("CopyFromASCII error: small dest buffer");
    }
    return dest;
}

template <>
char* String<char>::NewFromASCII(const char* src)
{
    return NewStr(src);
}

// feature 114: the conversions below are WTF-8 (the program's name encoding since feature 066,
// the plug-in helpers' since 089): a name with an unpaired UTF-16 surrogate - legal on NTFS and in
// FAT/exFAT long names - keeps it as its 3-byte sequence instead of becoming U+FFFD, so a file is
// restored under its own name and not under another one. Valid Unicode converts byte for byte as
// before (SplUnicodeDetail::WToWtf8 is plain UTF-8 there).

// 'srclen' units of 'src' (not necessarily terminated) as a terminated heap copy; free() it
static WCHAR* TerminatedCopyW(const wchar_t* src, unsigned long srclen)
{
    WCHAR* w = (WCHAR*)malloc((srclen + 1) * sizeof(WCHAR));
    if (w != NULL)
    {
        memcpy(w, src, srclen * sizeof(WCHAR));
        w[srclen] = 0;
    }
    return w;
}

template <>
char* String<char>::NewFromUnicode(const wchar_t* src, unsigned long srclen)
{
    // MFT/directory names are UTF-16; the plugin carries the char names as UTF-8
    // so they reach Salamander as UTF-8 (plugin interface 104). One UTF-16 unit
    // may need up to 3 UTF-8 bytes, so the byte length can exceed 'srclen'.
    WCHAR* w = TerminatedCopyW(src, srclen);
    if (w == NULL)
        return NULL;
    int need = SplUnicodeDetail::WToWtf8(w, NULL, 0); // bytes including the terminator
    char* dest = new char[need];
    if (dest != NULL)
        SplUnicodeDetail::WToWtf8(w, dest, need);
    free(w);
    return dest;
}

template <>
char* String<char>::CopyFromUnicode(char* dest, const wchar_t* src, unsigned long srclen, unsigned long destlen)
{
    if (destlen)
        dest[0] = 0;
    if (srclen && destlen)
    {
        // dest holds UTF-8 (WTF-8). The conversion is all-or-nothing, so an oversized
        // name yields an empty string.
        WCHAR* w = TerminatedCopyW(src, srclen);
        if (w == NULL || SplUnicodeDetail::WToWtf8(w, dest, (int)destlen) <= 0)
        {
            TRACE_E("CopyFromUnicode: the name does not fit " << destlen << " bytes");
            dest[0] = 0;
        }
        free(w);
    }
    return dest;
}

template <>
wchar_t* String<char>::CopyToUnicode(wchar_t* dest, const char* src, unsigned long srclen, unsigned long destlen)
{
    if (destlen)
        dest[0] = 0;
    if (srclen && destlen)
    {
        // src is UTF-8 (WTF-8, plugin interface 104); the number of UTF-16 units never
        // exceeds the byte count, so 'destlen' wchars is always enough here.
        char* t = (char*)malloc(srclen + 1);
        if (t != NULL)
        {
            memcpy(t, src, srclen);
            t[srclen] = 0;
            if (SplU8ToW(t, dest, (int)destlen) <= 0)
            {
                TRACE_E("CopyToUnicode: not UTF-8 or too long");
                dest[0] = 0;
            }
            free(t);
        }
    }
    return dest;
}

// ****************************************************************************
//
//  Error message functions
//

extern HWND HProgressDlg;

// feature 114: the texts of the error boxes are composed in UTF-8. LoadStr is code-page text
// (LoadStringA) and the file names put into it are UTF-8: in a translated UI the composed text was
// neither, the program showed it as code-page text and the name as mojibake. The format comes
// from the UTF-16 resource now, the system message from FormatMessageW, the result is cut at a
// whole character ('buf' always ends with a complete UTF-8 sequence).
static void TrimTornUtf8Tail(char* s)
{
    size_t n = strlen(s);
    if (n == 0)
        return;
    size_t i = n - 1;
    while (i > 0 && ((unsigned char)s[i] & 0xC0) == 0x80 && n - i < 4)
        i--;
    unsigned char b = (unsigned char)s[i];
    size_t seq = b < 0x80 ? 1 : (b >= 0xC2 && b <= 0xDF) ? 2 : (b >= 0xE0 && b <= 0xEF) ? 3 : (b >= 0xF0 && b <= 0xF4) ? 4 : 0;
    if (seq != 0 && n - i < seq)
        s[i] = 0; // the last sequence was cut
}

static void FormatResU8(char* buf, int bufSize, int resID, va_list arglist)
{
    char fmt[1024];
    if (SplWToU8(String<wchar_t>::LoadStr(resID), fmt, sizeof(fmt)) <= 0)
        lstrcpyn(fmt, String<char>::LoadStr(resID), sizeof(fmt));
    buf[0] = 0;
    _vsnprintf_s(buf, bufSize, _TRUNCATE, fmt, arglist);
    TrimTornUtf8Tail(buf);
}

HWND GetParentHWND()
{
    HWND hParent = SalamanderGeneral->GetMsgBoxParent();
    if (HProgressDlg != NULL)
        hParent = HProgressDlg;
    return hParent;
}

template <>
BOOL String<char>::SysError(int title, int error, ...)
{
    int lastErr = GetLastError();
    CALL_STACK_MESSAGE3("SysError(%d, %d, ...)", title, error);
    char buf[1024];
    *buf = 0;
    va_list arglist;
    va_start(arglist, error);
    FormatResU8(buf, sizeof(buf), error, arglist); // feature 114: UTF-8, bounded
    va_end(arglist);
    if (lastErr != ERROR_SUCCESS)
    {
        WCHAR sysW[512];
        if (FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, lastErr,
                           MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), sysW, _countof(sysW), NULL) != 0)
        {
            char sys[3 * 512];
            if (SplWToU8(sysW, sys, sizeof(sys)) > 0)
            {
                strncat_s(buf, sizeof(buf), " ", _TRUNCATE);
                strncat_s(buf, sizeof(buf), sys, _TRUNCATE);
                TrimTornUtf8Tail(buf);
            }
        }
    }
    HWND hParent = GetParentHWND();
    SalamanderGeneral->SalMessageBox(hParent, buf, LoadStr(title), MB_OK | MB_ICONERROR);
    return FALSE;
}

template <>
BOOL String<char>::Error(int title, int error, ...)
{
    int lastErr = GetLastError();
    CALL_STACK_MESSAGE3("Error(%d, %d, ...)", title, error);
    char buf[1024];
    va_list arglist;
    va_start(arglist, error);
    FormatResU8(buf, sizeof(buf), error, arglist); // feature 114: UTF-8, bounded
    va_end(arglist);
    HWND hParent = GetParentHWND();
    SalamanderGeneral->SalMessageBox(hParent, buf, LoadStr(title), MB_OK | MB_ICONERROR);
    return FALSE;
}

template <>
int String<char>::PartialRestore(int checkBoxText, BOOL* checkBoxValue, int title, int text, ...)
{
    CALL_STACK_MESSAGE3("PartialRestore(%d, %d, ...)", title, text);
    char buf[1024];
    va_list arglist;
    va_start(arglist, text);
    FormatResU8(buf, sizeof(buf), text, arglist); // feature 114: UTF-8, bounded
    va_end(arglist);
    HWND hParent = GetParentHWND();

    MSGBOXEX_PARAMS mbep;
    memset(&mbep, 0, sizeof(mbep));
    mbep.HParent = hParent;
    mbep.Text = buf;
    mbep.Caption = String<char>::LoadStr(title);
    mbep.Flags = MB_YESNOCANCEL | MSGBOXEX_ICONQUESTION;
    if (checkBoxText != -1)
    {
        mbep.CheckBoxText = String<char>::LoadStr(checkBoxText);
        mbep.CheckBoxValue = checkBoxValue;
    }

    return SalamanderGeneral->SalMessageBoxEx(&mbep);
}
