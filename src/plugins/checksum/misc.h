// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

BOOL Error(HWND hParent, int lastErr, int title, int error, ...);
// feature 147: 'terminate' (a worker's flag, may be NULL): once it is set no error box is shown - the
// call fails as cancelled (the window that owns the box is closing and waits for the worker)
BOOL SafeReadFile(HANDLE hFile, LPVOID lpBuffer, DWORD nBytesToRead, DWORD* pnBytesRead, char* fileName, HWND parent, BOOL* skippedReadError = NULL, BOOL* skipAllReadErrors = NULL, const BOOL* terminate = NULL);
BOOL SafeWriteFile(HANDLE hFile, LPVOID lpBuffer, DWORD nBytesToWrite, DWORD* pnBytesWritten, char* fileName, HWND parent);
BOOL SafeOpenCreateFile(LPCTSTR fileName, DWORD desiredAccess, DWORD shareMode, DWORD creationDisposition,
                        DWORD flagsAndAttributes, HANDLE* hFile, BOOL* skip, int* silent, HWND parent,
                        const BOOL* terminate = NULL); // feature 147, see SafeReadFile

void GetFirstWord(char* str, int& pos, int& len, char delimitChar = 0);
void GetLastWord(char* str, int& pos, int& len, char delimitChar = 0);
BYTE hex(char c);
BOOL IsHex(const char* str, int len);
