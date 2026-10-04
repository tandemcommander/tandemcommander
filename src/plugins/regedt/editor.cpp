// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

char Command[MAX_PATH];
char Arguments[MAX_PATH];
char InitDir[MAX_PATH];

const char* EXP_FULLNAME = "FullName";
const char* EXP_DRIVE = "Drive";
const char* EXP_PATH = "Path";
const char* EXP_NAME = "Name";
const char* EXP_NAMEPART = "NamePart";
const char* EXP_EXTPART = "ExtPart";
const char* EXP_FULLPATH = "FullPath";
const char* EXP_WINDIR = "WinDir";
const char* EXP_SYSDIR = "SysDir";
const char* EXP_SALDIR = "SalDir";
const char* EXP_DOSFULLNAME = "DOSFullName";
const char* EXP_DOSDRIVE = "DOSDrive";
const char* EXP_DOSPATH = "DOSPath";
const char* EXP_DOSNAME = "DOSName";
const char* EXP_DOSNAMEPART = "DOSNamePart";
const char* EXP_DOSEXTPART = "DOSExtPart";
const char* EXP_DOSFULLPATH = "DOSFullPath";
const char* EXP_DOSWINDIR = "DOSWinDir";
const char* EXP_DOSSYSDIR = "DOSSysDir";

struct CExpData
{
    char Buffer[3 * MAX_PATH]; // UTF-8 path (up to 3 bytes per character)
    const char* LongName;
    const char* DosName;
};

const char* WINAPI
ExecuteFullName(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteFullName(, )");
    CExpData* data = (CExpData*)param;
    return strcpy(data->Buffer, data->LongName);
}

const char* WINAPI
ExecuteDOSFullName(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSFullName(, )");
    CExpData* data = (CExpData*)param;
    return strcpy(data->Buffer, data->DosName);
}

const char* WINAPI
ExecuteDrive(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDrive(, )");
    CExpData* data = (CExpData*)param;
    SG->GetRootPath(data->Buffer, data->LongName);
    SG->SalPathRemoveBackslash(data->Buffer);
    return data->Buffer;
}

const char* WINAPI
ExecuteDOSDrive(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSDrive(, )");
    CExpData* data = (CExpData*)param;
    SG->GetRootPath(data->Buffer, data->DosName);
    SG->SalPathRemoveBackslash(data->Buffer);
    return data->Buffer;
}

const char* WINAPI
ExecutePath(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecutePath(, )");
    CExpData* data = (CExpData*)param;
    SG->GetRootPath(data->Buffer, data->LongName);
    SG->SalPathRemoveBackslash(data->Buffer);
    strcpy(data->Buffer, data->LongName + strlen(data->Buffer));
    char* str = strrchr(data->Buffer, '\\');
    if (str)
        str[1] = 0;
    return data->Buffer;
}

const char* WINAPI
ExecuteDOSPath(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSPath(, )");
    CExpData* data = (CExpData*)param;
    SG->GetRootPath(data->Buffer, data->DosName);
    SG->SalPathRemoveBackslash(data->Buffer);
    strcpy(data->Buffer, data->DosName + strlen(data->Buffer));
    char* str = strrchr(data->Buffer, '\\');
    if (str)
        str[1] = 0;
    return data->Buffer;
}

const char* WINAPI
ExecuteName(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteName(, )");
    CExpData* data = (CExpData*)param;
    return strcpy(data->Buffer, SG->SalPathFindFileName(data->LongName));
}

const char* WINAPI
ExecuteDOSName(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSName(, )");
    CExpData* data = (CExpData*)param;
    return strcpy(data->Buffer, SG->SalPathFindFileName(data->DosName));
}

const char* WINAPI
ExecuteNamePart(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteNamePart(, )");
    CExpData* data = (CExpData*)param;
    strcpy(data->Buffer, SG->SalPathFindFileName(data->LongName));
    SG->SalPathRemoveExtension(data->Buffer);
    return data->Buffer;
}

const char* WINAPI
ExecuteDOSNamePart(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSNamePart(, )");
    CExpData* data = (CExpData*)param;
    strcpy(data->Buffer, SG->SalPathFindFileName(data->DosName));
    SG->SalPathRemoveExtension(data->Buffer);
    return data->Buffer;
}

const char* WINAPI
ExecuteExtPart(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteExtPart(, )");
    CExpData* data = (CExpData*)param;
    const char* name = SG->SalPathFindFileName(data->LongName);
    const char* ext = strrchr(name, '.');
    if (ext != NULL)
        strcpy(data->Buffer, ++ext); // ".cvspass" is treated as an extension in Windows
    else
        *data->Buffer = 0;
    return data->Buffer;
}

const char* WINAPI
ExecuteDOSExtPart(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSExtPart(, )");
    CExpData* data = (CExpData*)param;
    const char* name = SG->SalPathFindFileName(data->DosName);
    const char* ext = strrchr(name, '.');
    if (ext != NULL)
        strcpy(data->Buffer, ++ext); // ".cvspass" is treated as an extension in Windows
    else
        *data->Buffer = 0;
    return data->Buffer;
}

const char* WINAPI
ExecuteFullPath(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteFullPath(, )");
    CExpData* data = (CExpData*)param;
    strcpy(data->Buffer, data->LongName);
    char* str = strrchr(data->Buffer, '\\');
    if (str)
        str[1] = 0;
    return data->Buffer;
}

const char* WINAPI
ExecuteDOSFullPath(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSFullPath(, )");
    CExpData* data = (CExpData*)param;
    strcpy(data->Buffer, data->DosName);
    char* str = strrchr(data->Buffer, '\\');
    if (str)
        str[1] = 0;
    return data->Buffer;
}

// feature 104: the folders as UTF-8 - the variables are expanded into UTF-8 text (the names
// and the temp file are UTF-8) and the command line is converted from UTF-8. The A calls gave
// code-page bytes: a path outside ASCII garbled the whole command line, a character outside the
// code page became '?' (an installation folder under such a user name, $(SalDir)).
// 'which': 0 = Windows folder, 1 = system folder; 'dos': the short (8.3) form
static const char* GetSystemFolderU8(CExpData* data, int which, BOOL dos)
{
    *data->Buffer = 0;
    WCHAR w[MAX_PATH];
    UINT l = which == 0 ? GetWindowsDirectoryW(w, MAX_PATH) : GetSystemDirectoryW(w, MAX_PATH);
    if (l == 0 || l >= MAX_PATH)
        return data->Buffer;
    if (dos)
    {
        WCHAR s[MAX_PATH];
        DWORD sl = GetShortPathNameW(w, s, MAX_PATH);
        if (sl == 0 || sl >= MAX_PATH)
            return data->Buffer;
        lstrcpynW(w, s, MAX_PATH);
    }
    if (SplWToU8(w, data->Buffer, sizeof(data->Buffer)) == 0)
        *data->Buffer = 0;
    return data->Buffer;
}

const char* WINAPI
ExecuteWinDir(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteWinDir(, )");
    CExpData* data = (CExpData*)param;
    if (*GetSystemFolderU8(data, 0, FALSE) != 0)
        SG->SalPathAddBackslash(data->Buffer, sizeof(data->Buffer));
    return data->Buffer;
}

const char* WINAPI
ExecuteDOSWinDir(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSWinDir(, )");
    CExpData* data = (CExpData*)param;
    if (*GetSystemFolderU8(data, 0, TRUE) != 0)
        SG->SalPathAddBackslash(data->Buffer, sizeof(data->Buffer));
    return data->Buffer;
}

const char* WINAPI
ExecuteSysDir(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteSysDir(, )");
    CExpData* data = (CExpData*)param;
    if (*GetSystemFolderU8(data, 1, FALSE) != 0)
        SG->SalPathAddBackslash(data->Buffer, sizeof(data->Buffer));
    return data->Buffer;
}

const char* WINAPI
ExecuteDOSSysDir(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteDOSSysDir(, )");
    CExpData* data = (CExpData*)param;
    if (*GetSystemFolderU8(data, 1, TRUE) != 0)
        SG->SalPathAddBackslash(data->Buffer, sizeof(data->Buffer));
    return data->Buffer;
}

const char* WINAPI
ExecuteSalDir(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteSalDir(, )");
    CExpData* data = (CExpData*)param;
    *data->Buffer = 0;
    const DWORD size = 32768;
    WCHAR* w = (WCHAR*)malloc(size * sizeof(WCHAR));
    if (w != NULL)
    {
        DWORD l = GetModuleFileNameW(NULL, w, size); // hInstance==NULL: we want the path to the EXE, not the DLL
        WCHAR* slash = l > 0 && l < size ? wcsrchr(w, L'\\') : NULL;
        if (slash != NULL)
        {
            slash[1] = 0;
            if (SplWToU8(w, data->Buffer, sizeof(data->Buffer)) == 0)
                *data->Buffer = 0;
        }
        free(w);
    }
    return data->Buffer;
}

const char* WINAPI
ExecutePath2(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecutePath2(, )");
    CExpData* data = (CExpData*)param;
    SG->GetRootPath(data->Buffer, data->LongName);
    SG->SalPathRemoveBackslash(data->Buffer);
    strcpy(data->Buffer, data->LongName + strlen(data->Buffer));
    int l = (int)strlen(data->Buffer);
    if (data->Buffer[l - 1] == '\\' && l > 1)
        data->Buffer[l - 1] = 0;
    return data->Buffer;
}

const char* WINAPI
ExecuteFullPath2(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteFullPath2(, )");
    CExpData* data = (CExpData*)param;
    return strcpy(data->Buffer, data->LongName);
}

const char* WINAPI
ExecuteWinDir2(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteWinDir2(, )");
    CExpData* data = (CExpData*)param;
    if (*GetSystemFolderU8(data, 0, FALSE) != 0) // feature 104: UTF-8, see GetSystemFolderU8
        SG->SalPathRemoveBackslash(data->Buffer);
    return data->Buffer;
}

const char* WINAPI
ExecuteSysDir2(HWND msgParent, void* param)
{
    CALL_STACK_MESSAGE1("ExecuteSysDir2(, )");
    CExpData* data = (CExpData*)param;
    if (*GetSystemFolderU8(data, 1, FALSE) != 0) // feature 104: UTF-8, see GetSystemFolderU8
        SG->SalPathRemoveBackslash(data->Buffer);
    return data->Buffer;
}

CSalamanderVarStrEntry ExpCommandVariables[] =
    {
        {EXP_WINDIR, ExecuteWinDir},
        {EXP_SYSDIR, ExecuteSysDir},
        {EXP_SALDIR, ExecuteSalDir},
        {NULL, NULL}};

CSalamanderVarStrEntry ExpArgumentsVariables[] =
    {
        {EXP_FULLNAME, ExecuteFullName},
        {EXP_DRIVE, ExecuteDrive},
        {EXP_PATH, ExecutePath},
        {EXP_NAME, ExecuteName},
        {EXP_NAMEPART, ExecuteNamePart},
        {EXP_EXTPART, ExecuteExtPart},
        {EXP_FULLPATH, ExecuteFullPath},
        {EXP_WINDIR, ExecuteWinDir},
        {EXP_SYSDIR, ExecuteSysDir},
        {EXP_DOSFULLNAME, ExecuteDOSFullName},
        {EXP_DOSDRIVE, ExecuteDOSDrive},
        {EXP_DOSPATH, ExecuteDOSPath},
        {EXP_DOSNAME, ExecuteDOSName},
        {EXP_DOSNAMEPART, ExecuteDOSNamePart},
        {EXP_DOSEXTPART, ExecuteDOSExtPart},
        {EXP_DOSFULLPATH, ExecuteDOSFullPath},
        {EXP_DOSWINDIR, ExecuteDOSWinDir},
        {EXP_DOSSYSDIR, ExecuteDOSSysDir},
        {NULL, NULL}};

CSalamanderVarStrEntry ExpInitDirVariables[] =
    {
        {EXP_DRIVE, ExecuteDrive},
        {EXP_PATH, ExecutePath2},
        {EXP_FULLPATH, ExecuteFullPath2},
        {EXP_WINDIR, ExecuteWinDir2},
        {EXP_SYSDIR, ExecuteSysDir2},
        {NULL, NULL}};

BOOL RemoveDoubleBackslahesFromPath(char* text)
{
    if (text == NULL)
    {
        TRACE_E("Unexpected situation in RemoveDoubleBackslahesFromPath().");
        return FALSE;
    }
    int len = (int)strlen(text);
    if (len < 3)
        return TRUE;
    char* s = text + 2; // UNC paths start with "\\"
    char* d = s;
    while (*s != 0)
    {
        if (*s == '\\' && *(s + 1) == '\\')
            s++;
        *d = *s;
        s++;
        d++;
    }
    *d = 0;
    return TRUE;
}

BOOL ExpandCommand(const char* varText, char* buffer, int bufferLen, BOOL ignoreEnvVarNotFoundOrTooLong)
{
    CALL_STACK_MESSAGE2("ExpandCommand(, %s, , ,)", varText);
    CExpData data;
    data.LongName = NULL;
    data.DosName = NULL;
    if (SG->ExpandVarString(GetParent(), varText, buffer, bufferLen, ExpCommandVariables, &data,
                            ignoreEnvVarNotFoundOrTooLong))
    {
        // the EXECUTE_WINDIR, EXECUTE_SYSDIR, and EXECUTE_SALDIR variables end with a backslash
        // the user adds their own backslash, so the resulting path contains two of them
        RemoveDoubleBackslahesFromPath(buffer); // trim double backslashes down to one
        return TRUE;
    }
    else
        return FALSE;
}

BOOL ExpandInitDir(const char* varText, char* directory, int directorySize,
                   const char* longName, const char* dosName)
{
    CALL_STACK_MESSAGE4("ExpandInitDir(%s, , %s, %s)", varText, longName, dosName);
    CExpData data;
    data.LongName = longName;
    data.DosName = dosName;
    return SG->ExpandVarString(GetParent(), varText, directory, directorySize, ExpInitDirVariables, &data);
}

BOOL ExpandArguments(const char* varText, char* arguments, int argumentsSize,
                     const char* longName, const char* dosName)
{
    CALL_STACK_MESSAGE4("ExpandArguments(%s, , %s, %s)", varText, longName,
                        dosName);
    CExpData data;
    data.LongName = longName;
    data.DosName = dosName;
    return SG->ExpandVarString(GetParent(), varText, arguments, argumentsSize, ExpArgumentsVariables, &data);
}

// UTF-8 path -> short (8.3) UTF-8 path; the paths are UTF-8 since plugin interface 104
static BOOL GetShortPathNameU8(const char* path, char* buffer, int bufferSize)
{
    WCHAR wShort[MAX_PATH];
    WCHAR* w = SplU8ToWAlloc(path);
    BOOL ret = w != NULL && GetShortPathNameW(w, wShort, _countof(wShort)) > 0 &&
               SplWToU8(wShort, buffer, bufferSize) > 0;
    free(w);
    return ret;
}

// text mixing UTF-8 paths and ANSI resource/config strings -> UTF-16 (UTF-8 first, ANSI fallback)
static WCHAR* TextToWAlloc(const char* text)
{
    WCHAR* w = SplU8ToWAlloc(text);
    if (w != NULL)
        return w;
    int len = MultiByteToWideChar(CP_ACP, 0, text, -1, NULL, 0);
    if (len <= 0)
        return NULL;
    w = (WCHAR*)malloc(len * sizeof(WCHAR));
    if (w != NULL)
        MultiByteToWideChar(CP_ACP, 0, text, -1, w, len);
    return w;
}

BOOL ExecuteEditor(const char* tempFile)
{
    CALL_STACK_MESSAGE2("ExecuteEditor(%s)", tempFile);
    char command[MAX_PATH];
    char directory[3 * MAX_PATH]; // UTF-8 path (up to 3 bytes per character)
    char arguments[3 * MAX_PATH];

    char longName[3 * MAX_PATH];
    char dosName[3 * MAX_PATH];

    // expand initdir
    SG->CutDirectory(strcpy(longName, tempFile));
    if (!GetShortPathNameU8(longName, dosName, _countof(dosName)))
        dosName[0] = 0;

    int e1, e2;

    if (!SG->ValidateVarString(GetParent(), Command, e1, e2, ExpCommandVariables) ||
        !ExpandCommand(Command, command, MAX_PATH, FALSE))
        return FALSE;

    if (!SG->ValidateVarString(GetParent(), InitDir, e1, e2, ExpInitDirVariables) ||
        !ExpandInitDir(InitDir, directory, _countof(directory), longName, dosName))
        return FALSE;

    // expand arguments
    if (!GetShortPathNameU8(tempFile, dosName, _countof(dosName)))
        dosName[0] = 0;

    if (!SG->ValidateVarString(GetParent(), Arguments, e1, e2, ExpArgumentsVariables) ||
        !ExpandArguments(Arguments, arguments, _countof(arguments), tempFile, dosName))
        return FALSE;

    // run the command
    if (!*command)
        return Error(IDS_PROCESS);
    TBuffer<char> cmdLine;
    if (!cmdLine.Reserve((int)strlen(command) + 3 + (int)strlen(arguments) + 1)) // regedt's TBuffer takes an int
        return Error(IDS_LOWMEM);
    SalPrintf(cmdLine.Get(), (unsigned int)cmdLine.GetSize(), "\"%s\" %s", command, arguments);

    // feature 104: launch the editor on the W layer (the renamer's code): the command line
    // and the folder are UTF-8 - the temp file is <Temp>\SALxxx\_<value name>; CreateProcess A
    // with GetShortPathName A on UTF-8 bytes garbled every non-ASCII temp path or value name
    WCHAR* wCmdLine = TextToWAlloc(cmdLine.Get());
    WCHAR* wDirectory = directory[0] ? TextToWAlloc(directory) : NULL;
    if (wCmdLine == NULL)
    {
        free(wDirectory);
        return Error(IDS_PROCESS);
    }

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(STARTUPINFOW));
    si.cb = sizeof(STARTUPINFOW);
    si.lpTitle = NULL;
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_SHOWNORMAL;

    BOOL created = CreateProcessW(NULL, wCmdLine, NULL, NULL, FALSE,
                                  CREATE_DEFAULT_ERROR_MODE | NORMAL_PRIORITY_CLASS,
                                  NULL, wDirectory, &si, &pi);
    free(wCmdLine);
    free(wDirectory);
    if (!created)
        return Error(IDS_PROCESS);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return TRUE;
}
