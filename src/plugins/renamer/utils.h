// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#ifndef QWORD
typedef unsigned __int64 QWORD;
typedef QWORD* LPQWORD;
#define LODWORD(qw) ((DWORD)qw)
#define HIDWORD(qw) ((DWORD)(qw >> 32))
#define MAKEQWORD(lo, hi) (((QWORD)hi << 32) + lo)
#endif

void LoadHistory(HKEY regKey, const char* keyPattern, char** history,
                 char* buffer, int bufferSize,
                 CSalamanderRegistryAbstract* registry);
void SaveHistory(HKEY regKey, const char* keyPattern, char** history,
                 CSalamanderRegistryAbstract* registry);

BOOL FileError(HWND parent, const char* fileName, int error,
               BOOL retry, BOOL* skip, BOOL* skipAll, int title);

// ****************************************************************************
//
// File APIs for the UTF-8 paths coming from the Salamander interface (version 104);
// they call the W variants of the Win32 functions (Unicode names + long paths).
//

HANDLE CreateFileU8(const char* fileName, DWORD desiredAccess, DWORD shareMode,
                    DWORD creationDisposition, DWORD flagsAndAttributes);
BOOL DeleteFileU8(const char* fileName);
BOOL SetFileAttributesU8(const char* fileName, DWORD attr);
BOOL CreateDirectoryU8(const char* pathName);
BOOL RemoveDirectoryU8(const char* pathName);

// feature 104: text of the dialog's edit controls as UTF-8. The controls are Unicode
// windows (comctl32 6) and stay so (CWindow::AttachToWindowKeepKind); the former code-page
// calls (WM_SETTEXT A of UTF-8 bytes, GetDlgItemText A, EM_GETLINE A) showed the names as
// mojibake and read typed text through the code page ('?', best-fit look-alikes).
// SetWindowTextU8: UTF-8 (WTF-8) text set wide, text that is not UTF-8 as code-page text.
void SetWindowTextU8(HWND hWnd, const char* text);
// the window's whole text as UTF-8 (WTF-8); free() the result; NULL on lack of memory
char* GetWindowTextU8Alloc(HWND hWnd);
// line 'line' of a multi-line edit as UTF-8 into 'buf' (no terminator counted); returns the
// byte length, -1 when it does not fit 'bufSize' (incl. the terminator), -2 when the line
// does not exist - 'buf' is then empty
int GetEditLineU8(HWND edit, int line, char* buf, int bufSize);
// replaces the selection of an edit with 'bytes' (an external program's output or a file
// edited outside): a leading UTF-8 byte-order mark is dropped; UTF-8 (WTF-8) is taken as
// such, anything else as code-page text
void ReplaceEditSelBytes(HWND edit, const char* bytes, BOOL canUndo);

BOOL FileOverwrite(HWND parent, const char* fileName1, const char* fileData1,
                   const char* fileName2, const char* fileData2, DWORD attr,
                   int shquestion, int shtitle, BOOL* skip, DWORD* silent);

// ****************************************************************************

class CBuffer
{
public:
    CBuffer(BOOL persistent = FALSE)
    {
        Buffer = NULL;
        Allocated = 0;
        Persistent = persistent;
    }
    ~CBuffer() { Release(); }
    BOOL Reserve(size_t size);
    void Release()
    {
        if (Buffer)
            free(Buffer);
        Buffer = NULL;
        Allocated = 0;
    }
    size_t GetSize() { return Allocated; }

protected:
    void* Buffer;
    size_t Allocated;
    BOOL Persistent;
};

template <class DATA_TYPE>
class TBuffer : public CBuffer
{
public:
    TBuffer(BOOL persistent = FALSE) : CBuffer(persistent) { ; }
    BOOL Reserve(size_t size) { return CBuffer::Reserve(size * sizeof(DATA_TYPE)); }
    DATA_TYPE* Get() { return (DATA_TYPE*)Buffer; }
    size_t GetSize() { return Allocated / sizeof(DATA_TYPE); }
};

// ****************************************************************************

struct CVarStrHelpMenuItem
{
    int MenuItemStringID;
    const char* VariableName;
    BOOL(*FParameterGetValue)
    (HWND parent, char* buffer);
    CVarStrHelpMenuItem* SubMenu;
};

BOOL SelectVarStrVariable(HWND parent, int x, int y,
                          CVarStrHelpMenuItem* helpMenu, char* buffer, BOOL varStr);

// ****************************************************************************

const char* StrQChr(const char* start, const char* end, char q, char c);
BOOL IsValidInt(const char* begin, const char* end, BOOL isSigned);
BOOL IsValidFloat(const char* begin, const char* end);
int GetRegExpErrorID(CRegExpErrors err);
char* StripRoot(char* path, int rootLen);
enum CRenameSpec;
BOOL ValidateFileName(const char* name, int len, CRenameSpec spec,
                      BOOL* skip, BOOL* skipAll);
int CutTrailingDots(char* name, int len, CRenameSpec spec);
inline const char* GetNextPathComponent(const char* name)
{
    while (*name != '\\' && *name != 0)
        name++;
    return name;
}
BOOL GetOpenFileName(HWND parent, const char* title, const char* filter,
                     char* buffer, BOOL save = FALSE);
