// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

BOOL CRenamerDialog::ExportToTempFile()
{
    CALL_STACK_MESSAGE1("CRenamerDialog::ExportToTempFile()");

    // create the name of the tmp file
    if (!SG->SalGetTempFileName(NULL, "SAL", TempFile, FALSE, NULL) ||
        !SG->SalPathAppend(TempFile, "list.txt", _countof(TempFile)))
        return Error(IDS_CREATETEMP);

    // create/open the tmp file (the temp path is UTF-8 -> W API)
    HANDLE file = CreateFileU8(TempFile, GENERIC_WRITE, FILE_SHARE_READ,
                               CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL);
    if (file == INVALID_HANDLE_VALUE)
    {
        SG->CutDirectory(TempFile);
        SG->RemoveTemporaryDir(TempFile);
        return Error(IDS_CREATETEMP);
    }

    // nacteme text z controlu
    // feature 104: as UTF-8 - the names' own bytes, which is what the file held before too
    // (the edit showed the UTF-8 bytes as code-page characters and GetWindowText A gave them
    // back); now the edit shows the names and the file still gets their UTF-8 form
    char* text = GetWindowTextU8Alloc(ManualEdit->HWindow);
    if (text == NULL)
    {
        CloseHandle(file);
        SG->CutDirectory(TempFile);
        SG->RemoveTemporaryDir(TempFile);
        return Error(IDS_LOWMEM);
    }
    DWORD len = (DWORD)strlen(text);

    DWORD written;
    BOOL b = WriteFile(file, text, len, &written, NULL) || written != len;
    free(text);

    CloseHandle(file);

    if (!b)
    {
        SG->CutDirectory(TempFile);
        SG->RemoveTemporaryDir(TempFile);
        Error(IDS_WRITETEMP);
    }

    return b;
}

BOOL CRenamerDialog::ImportFromTempFile()
{
    CALL_STACK_MESSAGE1("CRawEditValDialog::ImportFromTempFile()");
    // open the tmp file (the temp path is UTF-8 -> W API)
    HANDLE file = CreateFileU8(TempFile, GENERIC_READ, FILE_SHARE_READ,
                               OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL);
    if (file == INVALID_HANDLE_VALUE)
        return Error(IDS_OPENTEMP);

    CQuadWord size;
    DWORD err;
    if (!SG->SalGetFileSize(file, size, err))
    {
        CloseHandle(file);
        return ErrorL(err, IDS_SIZEOFTEMP);
    }

    if (size.HiDWord > 0)
    {
        CloseHandle(file);
        return Error(IDS_LONGDATA);
    }

    TBuffer<char> buffer;
    if (!buffer.Reserve(size.LoDWord + 1))
    {
        CloseHandle(file);
        return Error(IDS_LOWMEM);
    }

    DWORD read;
    BOOL b = ReadFile(file, buffer.Get(), size.LoDWord, &read, NULL) || read != size.LoDWord;

    CloseHandle(file);

    if (b)
    {
        buffer.Get()[size.LoDWord] = 0;
        SendMessage(ManualEdit->HWindow, EM_SETSEL, 0, -1);
        ReplaceEditSelBytes(ManualEdit->HWindow, buffer.Get(), FALSE); // feature 104: UTF-8, else the code page
        // SendMessage(ManualEdit->HWindow, WM_SETTEXT, 0, LPARAM(buffer.Get()));
    }
    else
        Error(IDS_READTEMP);

    return b;
}

BOOL EscapeQuotes(const char* string, char* escaped)
{
    CALL_STACK_MESSAGE2("EscapeQuotes(%s, )", string);
    int c = 0;
    while (*string)
    {
        if (c >= 4095)
            return FALSE;
        if (*string == '"')
        {
            *escaped++ = '\\';
            c++;
        }
        *escaped++ = *string++;
        c++;
    }
    if (c == 4096)
        return FALSE;
    *escaped++ = 0;
    return TRUE;
}

BOOL CRenamerDialog::ExecuteCommand(const char* command)
{
    CALL_STACK_MESSAGE2("CRenamerDialog::ExecuteCommand(%s)", command);
    // create the command line
    // feature 104: the shell's path as UTF-8, like the command (the command line is built in
    // UTF-8 and converted as such below; it was converted with CP_ACP, which garbled every
    // non-ASCII character of a command typed in the Command dialog)
    char shell[3 * MAX_PATH];
    {
        WCHAR shellW[MAX_PATH];
        DWORD n = GetEnvironmentVariableW(L"SHELL", shellW, MAX_PATH);
        if (n == 0 || n >= MAX_PATH)
            n = GetEnvironmentVariableW(L"COMSPEC", shellW, MAX_PATH);
        if (n == 0 || n >= MAX_PATH || SplWToU8(shellW, shell, sizeof(shell)) == 0)
            return FALSE;
    }

    BOOL sh = strlen(shell) && strstr(SG->SalPathFindFileName(shell), "sh") != NULL;

    char cmdLine[4096];
    if (sh)
    {
        char escaped[4096];

        if (!EscapeQuotes(command, escaped) ||
            !SalPrintf(cmdLine, 4096, "%s -c \"%s\"", shell, escaped))
            return Error(IDS_LONGDATA);
    }
    else
    {
        if (!SalPrintf(cmdLine, 4096, "%s /C %s", shell, command))
            return Error(IDS_LONGDATA);
    }

    char tempDir[3 * MAX_PATH]; // the temp path is UTF-8 (up to 3 bytes per character)
    char outName[3 * MAX_PATH];
    char errName[3 * MAX_PATH];
    HANDLE inPipeWr = INVALID_HANDLE_VALUE;
    HANDLE inPipeWrDup = INVALID_HANDLE_VALUE;
    HANDLE inPipeRd = INVALID_HANDLE_VALUE;
    HANDLE outFile = INVALID_HANDLE_VALUE;
    HANDLE errFile = INVALID_HANDLE_VALUE;
    SECURITY_ATTRIBUTES saAttr;
    TBuffer<char> buffer;
    CQuadWord size;
    BOOL ret = TRUE;
    WCHAR* wCmdLine = NULL; // the command line and the working directory for CreateProcessW
    WCHAR* wRoot = NULL;

    // so the handles can be inherited
    saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
    saAttr.lpSecurityDescriptor = NULL;
    saAttr.bInheritHandle = TRUE;

    // create names for the tmp files
    if (!SG->SalGetTempFileName(NULL, "SAL", tempDir, FALSE, NULL) ||
        !SG->SalPathAppend(strcpy(outName, tempDir), "stdout", _countof(outName)) ||
        !SG->SalPathAppend(strcpy(errName, tempDir), "stderr", _countof(errName)))
        return Error(IDS_CREATETEMP);

    // create the pipe for input
    if (!CreatePipe(&inPipeRd, &inPipeWr, &saAttr, 0))
    {
        inPipeWr = INVALID_HANDLE_VALUE;
        inPipeRd = INVALID_HANDLE_VALUE;
        ret = Error(IDS_CREATEPIPE);
        goto LERROR;
    }
    if (!DuplicateHandle(GetCurrentProcess(), inPipeWr,
                         GetCurrentProcess(), &inPipeWrDup, 0,
                         FALSE,
                         DUPLICATE_SAME_ACCESS))
        return FALSE;
    CloseHandle(inPipeWr);
    inPipeWr = INVALID_HANDLE_VALUE;

    // create/open tmp files for output (the temp paths are UTF-8 -> W API; the handles must be inheritable)
    {
        WCHAR* wOutName = SplU8ToWExtAlloc(outName);
        outFile = wOutName != NULL ? CreateFileW(wOutName, GENERIC_READ | GENERIC_WRITE,
                                                 FILE_SHARE_READ | FILE_SHARE_WRITE, &saAttr, CREATE_ALWAYS,
                                                 FILE_ATTRIBUTE_TEMPORARY, NULL)
                                   : INVALID_HANDLE_VALUE;
        free(wOutName);
        WCHAR* wErrName = SplU8ToWExtAlloc(errName);
        errFile = wErrName != NULL ? CreateFileW(wErrName, GENERIC_READ | GENERIC_WRITE,
                                                 FILE_SHARE_READ | FILE_SHARE_WRITE, &saAttr, CREATE_ALWAYS,
                                                 FILE_ATTRIBUTE_TEMPORARY, NULL)
                                   : INVALID_HANDLE_VALUE;
        free(wErrName);
    }
    if (outFile == INVALID_HANDLE_VALUE ||
        errFile == INVALID_HANDLE_VALUE)
    {
        ret = Error(IDS_CREATETEMP);
        goto LERROR;
    }

    // nacteme text z controlu
    // feature 104: as UTF-8 - the bytes the command received before too (see ExportToTempFile)
    char* text;
    text = GetWindowTextU8Alloc(ManualEdit->HWindow);
    if (text == NULL || !buffer.Reserve((int)strlen(text) + 1))
    {
        free(text);
        SG->CutDirectory(TempFile);
        SG->RemoveTemporaryDir(TempFile);
        ret = Error(IDS_LOWMEM);
        goto LERROR;
    }
    DWORD len;
    len = (DWORD)strlen(text);
    memcpy(buffer.Get(), text, len + 1);
    free(text);

    // launch the shell on the W layer: the working directory (Root) is a UTF-8 panel path
    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    int cmdLineLen;
    // feature 104: cmdLine is UTF-8 (the shell's path + the command from the Command dialog,
    // read with EditLine); text that is not UTF-8 is taken as code-page text
    wCmdLine = SplU8ToWAlloc(cmdLine);
    if (wCmdLine == NULL)
    {
        cmdLineLen = MultiByteToWideChar(CP_ACP, 0, cmdLine, -1, NULL, 0);
        wCmdLine = cmdLineLen > 0 ? (WCHAR*)malloc(cmdLineLen * sizeof(WCHAR)) : NULL;
        if (wCmdLine != NULL && MultiByteToWideChar(CP_ACP, 0, cmdLine, -1, wCmdLine, cmdLineLen) == 0)
        {
            free(wCmdLine);
            wCmdLine = NULL;
        }
    }
    if (wCmdLine == NULL)
    {
        ret = Error(IDS_PROCESS);
        goto LERROR;
    }
    wRoot = *Root ? SplU8ToWAlloc(Root) : NULL;

    memset(&si, 0, sizeof(STARTUPINFOW));
    si.cb = sizeof(STARTUPINFOW);
    si.lpTitle = wCmdLine;
    si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
    si.wShowWindow = SW_SHOWMINIMIZED;
    si.hStdInput = inPipeRd;
    si.hStdOutput = outFile;
    si.hStdError = errFile;

    if (!CreateProcessW(NULL, wCmdLine, NULL, NULL, TRUE,
                        CREATE_DEFAULT_ERROR_MODE | NORMAL_PRIORITY_CLASS,
                        NULL, wRoot, &si, &pi))
    {
        ret = Error(IDS_PROCESS);
        goto LERROR;
    }

    CloseHandle(inPipeRd);
    inPipeRd = INVALID_HANDLE_VALUE;

    DWORD written;
    if (!WriteFile(inPipeWrDup, buffer.Get(), len, &written, NULL) || written != len)
    {
        if (GetLastError() != ERROR_BROKEN_PIPE)
            ret = Error(IDS_WRITEPIPE);
    }

    CloseHandle(inPipeWrDup);
    inPipeWrDup = INVALID_HANDLE_VALUE;

    WaitForSingleObject(pi.hProcess, INFINITE);

    DWORD exitCode;
    GetExitCodeProcess(pi.hProcess, &exitCode);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    // verify that no error occurred
    size.HiDWord = 0;
    size.LoDWord = SetFilePointer(errFile, 0, LPLONG(&size.HiDWord), FILE_END);
    if (exitCode || size.LoDWord)
    {
        if (!buffer.Reserve(size.LoDWord + 1))
        {
            ret = Error(IDS_LOWMEM);
            goto LERROR;
        }

        LONG l;
        l = 0;
        SetFilePointer(errFile, 0, &l, FILE_BEGIN);

        DWORD read;
        if (ReadFile(errFile, buffer.Get(), size.LoDWord, &read, NULL) && read == size.LoDWord)
        {
            buffer.Get()[size.LoDWord] = 0;
            ret = CCommandErrorDialog(HWindow, cmdLine, exitCode, buffer.Get()).Execute() == IDOK;
            if (!ret)
                goto LERROR;
        }
        else
        {
            ret = Error(IDS_READTEMP);
            goto LERROR;
        }
    }

    if (!ret)
        goto LERROR;

    // read the text from the file
    size.HiDWord = 0;
    size.LoDWord = SetFilePointer(outFile, 0, LPLONG(&size.HiDWord), FILE_END);

    if (size.HiDWord > 0)
    {
        ret = Error(IDS_LONGDATA);
        goto LERROR;
    }

    if (!buffer.Reserve(size.LoDWord + 1))
    {
        ret = Error(IDS_LOWMEM);
        goto LERROR;
    }

    LONG l;
    l = 0;
    SetFilePointer(outFile, 0, &l, FILE_BEGIN);

    DWORD read;
    if (ReadFile(outFile, buffer.Get(), size.LoDWord, &read, NULL) && read == size.LoDWord)
    {
        buffer.Get()[size.LoDWord] = 0;
        SendMessage(ManualEdit->HWindow, EM_SETSEL, 0, -1);
        ReplaceEditSelBytes(ManualEdit->HWindow, buffer.Get(), TRUE); // feature 104: UTF-8, else the code page
        //SendMessage(ManualEdit->HWindow, WM_SETTEXT, 0, LPARAM(buffer.Get()));
    }
    else
    {
        ret = Error(IDS_READTEMP);
        goto LERROR;
    }

LERROR:
    free(wCmdLine);
    free(wRoot);
    if (inPipeWr != INVALID_HANDLE_VALUE)
        CloseHandle(inPipeWr);
    if (inPipeRd != INVALID_HANDLE_VALUE)
        CloseHandle(inPipeRd);
    if (inPipeWrDup != INVALID_HANDLE_VALUE)
        CloseHandle(inPipeWrDup);
    if (outFile != INVALID_HANDLE_VALUE)
        CloseHandle(outFile);
    if (errFile != INVALID_HANDLE_VALUE)
        CloseHandle(errFile);
    SG->RemoveTemporaryDir(tempDir);

    return ret;
}
