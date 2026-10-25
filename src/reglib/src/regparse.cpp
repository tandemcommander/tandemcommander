// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <tchar.h>

#include "regparse.h"
#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)
#include "../../common/salregroot.h" // feature 263
#endif

#define SkipWS(s) \
    while ((*s == ' ') || (*s == 9)) \
    s++

BOOL StrEndsWith(LPCTSTR txt, LPCTSTR pattern, size_t patternLen);

// 'mbcs': the text is in a DBCS-capable code page (a REGEDIT4 file); FALSE for UTF-8 (feature 174)
static LPTSTR SeparateStr(LPTSTR s, BOOL mbcs)
{
    while (*s)
    {
#ifndef _UNICODE
        if (mbcs && IsDBCSLeadByte(*s))
        {
            s++;
            if (!*s)
            {
                return NULL; // Invalid MBCS sequence
            }
            s++;
            continue;
        }
#endif
        if (*s == '\\')
        {
            switch (s[1])
            {
            case '\"':
                break;
            case '\\':
                break;
            case 't':
                s[1] = '\t';
                break;
            case 'r':
                s[1] = '\r';
                break;
            case 'n':
                s[1] = '\n';
                break;
            default:
                return NULL;
            }
            memmove(s, s + 1, _tcslen(s) * sizeof(s[0]));
        }
        else if (*s == '\"')
        {
            break;
        }
        s++;
    }
    if (!*s)
    {
        return NULL;
    }
    *s++ = 0;
    return s;
}

eRPE_ERROR Parse(LPTSTR buf, CSalamanderRegistryExAbstract* pRegistry, BOOL doNotDeleteHiddenKeysAndValues,
                 LPCTSTR onlyUnderHKCU, LPCTSTR legacyRoot)
{
#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)
    char mappedName[2 * MAX_PATH]; // feature 343: a key name of the 0.1.x root mapped to the current root
#else
    (void)legacyRoot; // the mapping is char-only (see below)
#endif
    LPTSTR line;
    HKEY hKey = NULL;
    eRPE_ERROR ret = RPE_OK;
    BOOL bReg5File;
    BOOL inParentOfRoot = FALSE; // feature 263: the last key line named a key above 'onlyUnderHKCU'

    line = _tcstok(buf, _T("\r\n"));
    if (!line)
    {
        return RPE_INVALID_FORMAT;
    }
    if (*line != 0 && !_tcscmp(line + 1 /*skip BOM*/, _T("Windows Registry Editor Version 5.00")))
    {
        bReg5File = TRUE;
    }
#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)
    else if ((BYTE)line[0] == 0xEF && (BYTE)line[1] == 0xBB && (BYTE)line[2] == 0xBF &&
             !strcmp(line + 3, "Windows Registry Editor Version 5.00"))
    {
        bReg5File = TRUE; // ConvertIfNeeded made UTF-8 of it, its BOM included (feature 174)
    }
#endif
    else if (!_tcscmp(line, _T("REGEDIT4")))
    {
        bReg5File = FALSE;
    }
    else
    {
        return RPE_NOT_REG_FILE;
    }
#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)
    const BOOL mbcs = !bReg5File; // a v5 file was made UTF-8; a REGEDIT4 one is code page
#else
    const BOOL mbcs = TRUE;
#endif
    while (NULL != (line = _tcstok(NULL, _T("\r\n"))))
    {
        if (!*line)
            continue; // empty line
        if (*line == '[')
        { // First char on the line -> MBCS-safe
            LPTSTR keyName;
            HKEY hParentKey;
            BOOL bDelete = FALSE;

            if (hKey)
            {
                pRegistry->CloseKey(hKey);
                hKey = NULL;
            }
            line++;
            if (line[0] == '-')
            {
                bDelete = TRUE;
                line++;
            }
            if (!_tcsnicmp(line, _T("HKEY_CURRENT_USER"), SizeOf(_T("HKEY_CURRENT_USER")) - 1))
            {
                keyName = line + SizeOf(_T("HKEY_CURRENT_USER")) - 1;
                hParentKey = HKEY_CURRENT_USER;
            }
            else if (!_tcsnicmp(line, _T("HKEY_CLASSES_ROOT"), SizeOf(_T("HKEY_CLASSES_ROOT")) - 1))
            {
                keyName = line + SizeOf(_T("HKEY_CLASSES_ROOT")) - 1;
                hParentKey = HKEY_CLASSES_ROOT;
            }
            else if (!_tcsnicmp(line, _T("HKEY_LOCAL_MACHINE"), SizeOf(_T("HKEY_LOCAL_MACHINE")) - 1))
            {
                keyName = line + SizeOf(_T("HKEY_LOCAL_MACHINE")) - 1;
                hParentKey = HKEY_LOCAL_MACHINE;
            }
            else if (!_tcsnicmp(line, _T("HKEY_USERS"), SizeOf(_T("HKEY_USERS")) - 1))
            {
                keyName = line + SizeOf(_T("HKEY_USERS")) - 1;
                hParentKey = HKEY_USERS;
            }
            else if (!_tcsnicmp(line, _T("HKEY_CURRENT_CONFIG"), SizeOf(_T("HKEY_CURRENT_CONFIG")) - 1))
            {
                keyName = line + SizeOf(_T("HKEY_CURRENT_CONFIG")) - 1;
                hParentKey = HKEY_CURRENT_CONFIG;
            }
            else if (!_tcsnicmp(line, _T("HKEY_DYN_DATA"), SizeOf(_T("HKEY_DYN_DATA")) - 1))
            {
                keyName = line + SizeOf(_T("HKEY_DYN_DATA")) - 1;
                hParentKey = HKEY_DYN_DATA;
            }
            else if (!_tcsnicmp(line, _T("HKEY_PERFORMANCE_DATA"), SizeOf(_T("HKEY_PERFORMANCE_DATA")) - 1))
            {
                keyName = line + SizeOf(_T("HKEY_PERFORMANCE_DATA")) - 1;
                hParentKey = HKEY_PERFORMANCE_DATA;
            }
            else
            {
                return RPE_ROOT_INVALID_KEY;
            }

            if (*keyName != ']')
            {
                if (*keyName == '\\')
                {
                    keyName++;
                }
                else
                {
                    return RPE_ROOT_INVALID_KEY;
                }
            }
            LPTSTR s = keyName;
            int nBrackets = 1;

            while (*s && nBrackets)
            {
#ifndef _UNICODE
                if (mbcs && IsDBCSLeadByte(*s))
                {
                    s++;
                    if (!*s)
                    {
                        return RPE_INVALID_MBCS;
                    }
                    s++;
                    continue;
                }
#endif
                if (*s == '[')
                    nBrackets++;
                else if (*s == ']')
                    nBrackets--;
                s++;
            }
            if (nBrackets)
            {
                return RPE_INVALID_KEY;
            }
            s[-1] = 0;
            inParentOfRoot = FALSE;
            if (onlyUnderHKCU != NULL)
            { // feature 263: never create, open or delete a key outside the allowed root
#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)
                if (hParentKey == HKEY_CURRENT_USER && !bDelete && SalRegKeyIsParentOfRoot(keyName, onlyUnderHKCU))
                { // our own export writes the keys above the root too, without values: nothing to create
                    inParentOfRoot = TRUE;
                    continue;
                }
                if (hParentKey == HKEY_CURRENT_USER && legacyRoot != NULL && !SalRegKeyIsInsideRoot(keyName, onlyUnderHKCU))
                { // feature 343: a key of the 0.1.x root is imported under the version-free root
                    if (SalRegMapLegacyRoot(keyName, onlyUnderHKCU, legacyRoot, mappedName, (int)sizeof(mappedName)))
                        keyName = mappedName;
                }
                if (hParentKey != HKEY_CURRENT_USER || !SalRegKeyIsInsideRoot(keyName, onlyUnderHKCU))
                {
                    TRACE_E("Parse(): key outside the allowed root: " << (bDelete ? "[-" : "[") << line << "]");
                    return RPE_KEY_OUTSIDE_ROOT;
                }
#else
                return RPE_KEY_OUTSIDE_ROOT; // the rule is char-only; no such caller outside the core
#endif
            }
            if (keyName[0] != 0) // root key cannot be created nor deleted this way (e.g. line with [HKEY_CURRENT_USER] or [-HKEY_CURRENT_USER])
            {
                if (!bDelete)
                {
                    if (!pRegistry->CreateKey(hParentKey, keyName, hKey))
                    {
                        return RPE_KEY_CREATE;
                    }
                }
                else
                {
                    if (!doNotDeleteHiddenKeysAndValues ||
                        !StrEndsWith(keyName, _T(".hidden"), SizeOf(_T(".hidden")) - 1))
                    {
                        // Delete entire subtree
                        if (pRegistry->OpenKey(hParentKey, keyName, hKey))
                        {
                            BOOL keyIsNotEmpty = FALSE;
                            pRegistry->ClearKeyEx(hKey, doNotDeleteHiddenKeysAndValues, &keyIsNotEmpty); // Delete the subtree
                            pRegistry->CloseKey(hKey);
                            if (!keyIsNotEmpty)
                                pRegistry->DeleteKey(hParentKey, keyName); // Delete the key itself
                        }
                        hKey = NULL;
                    }
                }
            }
            continue;
        }
        if ((*line == '\"') || (*line == '@'))
        { // First char on the line -> MBCS-safe
            LPTSTR s;

            if (inParentOfRoot) // feature 263: a value (or its deletion) in a key above the allowed root
            {
#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)
                TRACE_E("Parse(): value in a key above the allowed root: " << line);
#endif
                return RPE_KEY_OUTSIDE_ROOT;
            }

            if (*line != '@')
            {
                s = SeparateStr(++line, mbcs);

                if (!*s)
                {
                    ret = RPE_VALUE_MISSING_QUOTE;
                    break;
                }
            }
            else
            {
                s = line + 1;
                *line = 0;
            }
            SkipWS(s);
            if (*s++ != '=')
            { // MBCS-safe
                ret = RPE_VALUE_MISSING_ASSIG;
                break;
            }
            SkipWS(s);
            if (!_tcsnicmp(s, _T("dword:"), SizeOf(_T("dword:")) - 1))
            {
                DWORD val;
                s += SizeOf(_T("dword:")) - 1;
                if (1 == _stscanf(s, _T("%x"), &val))
                {
                    if (pRegistry->SetValue(hKey, line, REG_DWORD, &val, sizeof(val)))
                    {
                        continue;
                    }
                    ret = RPE_VALUE_SET;
                    break;
                }
                ret = RPE_VALUE_DWORD;
                break;
            }
            else if (!_tcsnicmp(s, _T("hex"), SizeOf(_T("hex")) - 1))
            {
                LPBYTE val, val2;
                int valType;

                s += SizeOf(_T("hex")) - 1;
                if (*s == ':')
                {
                    *s++;
                    valType = REG_BINARY;
                }
                else
                {
                    // hex(b):01,02,03,04,05,06,07,08   <-- QWORD value
                    if (*s != '(')
                    {
                        ret = RPE_VALUE_INVALID_TYPE;
                        break;
                    }
                    LPTSTR s2 = ++s;
                    while (((*s2 >= '0') && (*s2 <= '9')) || ((*s2 >= 'a') && (*s2 <= 'f')) || ((*s2 >= 'A') && (*s2 <= 'F')))
                        s2++;
                    if ((*s2 != ')') || (s2[1] != ':'))
                    {
                        ret = RPE_VALUE_INVALID_TYPE;
                        break;
                    }
                    *s2 = 0;
                    _stscanf(s, _T("%x"), &valType);
                    s = s2 + 2;
                }
                val = val2 = (LPBYTE)s;
                while (*s)
                {
                    if (*s == '\\')
                    { // MBCS-safe
                        s = _tcstok(NULL, _T("\r\n"));
                        if (!s)
                        {
                            ret = RPE_VALUE_HEX;
                            break;
                        }
                        SkipWS(s);
                    }
                    if ((*s >= '0') && (*s <= '9'))
                    {
                        *val2 = (BYTE)((*s++ - '0') << 4);
                    }
                    else if ((*s >= 'a') && (*s <= 'f'))
                    {
                        *val2 = (BYTE)((*s++ - 'a' + 10) << 4);
                    }
                    else if ((*s >= 'A') && (*s <= 'F'))
                    {
                        *val2 = (BYTE)((*s++ - 'A' + 10) << 4);
                    }
                    else
                    {
                        ret = RPE_VALUE_HEX;
                        break;
                    }
                    if ((*s >= '0') && (*s <= '9'))
                    {
                        *val2 |= (*s++ - '0');
                    }
                    else if ((*s >= 'a') && (*s <= 'f'))
                    {
                        *val2 |= (*s++ - 'a' + 10);
                    }
                    else if ((*s >= 'A') && (*s <= 'F'))
                    {
                        *val2 |= (*s++ - 'A' + 10);
                    }
                    else
                    {
                        ret = RPE_VALUE_HEX;
                        break;
                    }
                    val2++;
                    if (*s == ',')
                        s++; // MBCS-safe
                }
                if (*s)
                {
                    break; // ret is non-OK
                }
                LPBYTE valTmp = NULL;
#ifdef _UNICODE
                if (!bReg5File && ((valType == REG_MULTI_SZ) || (valType == REG_EXPAND_SZ)))
                {
                    size_t srcLen = val2 - val;
                    LPBYTE srcVal = val;
                    size_t len = srcLen * sizeof(WCHAR);

                    if (len > (size_t)((LPBYTE)line - (LPBYTE)buf))
                    {
                        valTmp = (LPBYTE)malloc(len);
                        if (!valTmp)
                        {
                            ret = RPE_OUT_OF_MEMORY;
                            break;
                        }
                        val = valTmp;
                    }
                    else
                    {
                        val = (LPBYTE)buf;
                    }
                    // Cope with W2K/XP/Vista/W7 bug: regedit exports just low bytes of such items i.s.o. conversion to CP_ACP
                    // We insert here zeros as high bytes
                    // But imports (at least on XP64) via CP_ACP :-(
                    size_t i;
                    for (i = 0; i < srcLen; i++)
                    {
                        val[2 * i] = srcVal[i];
                        val[2 * i + 1] = 0;
                    }
                    val2 = val + len;
                }
#else
                if (bReg5File && ((valType == REG_MULTI_SZ) || (valType == REG_EXPAND_SZ)))
                {
                    size_t srcLen = (val2 - val) / sizeof(WCHAR);
                    LPWSTR srcVal = (LPWSTR)val;
#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)
                    // feature 174: UTF-8 for the core (its string data are UTF-8 - SalRegSetValueExW8);
                    // the code page made '?' of the letters outside it
                    int len = srcLen > 0 ? SalWToU8(srcVal, (int)srcLen, NULL, 0) - 1 : 0; // without SalWToU8's own terminator
#else
                    int len = WideCharToMultiByte(CP_ACP, 0, srcVal, (int)srcLen, NULL, 0, NULL, NULL);
#endif

                    if (len > 0)
                    {
                        if (len > line - buf)
                        {
                            valTmp = (LPBYTE)malloc(len);
                            if (!valTmp)
                            {
                                ret = RPE_OUT_OF_MEMORY;
                                break;
                            }
                            val = valTmp;
                        }
                        else
                        {
                            val = (LPBYTE)buf;
                        }
#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)
                        char* u8 = SalWToU8Alloc(srcVal, (int)srcLen);
                        if (u8 == NULL)
                        {
                            if (valTmp)
                                free(valTmp);
                            ret = RPE_OUT_OF_MEMORY;
                            break;
                        }
                        memcpy(val, u8, len);
                        free(u8);
#else
                        WideCharToMultiByte(CP_ACP, 0, srcVal, (int)srcLen, (LPSTR)val, len, NULL, NULL);
#endif
                    }
                    val2 = val + max(len, 0);
                }
#endif
                if (pRegistry->SetValue(hKey, line, valType, val, (DWORD)(val2 - val)))
                {
                    if (valTmp)
                        free(valTmp);
                    continue;
                }
                if (valTmp)
                    free(valTmp);
                ret = RPE_VALUE_SET;
                break;
            }
            else if (*s == '\"')
            { // MBCS-safe
                LPTSTR val = ++s;
                s = SeparateStr(s, mbcs);
                if (s)
                {
                    if (pRegistry->SetValue(hKey, line, REG_SZ, val, sizeof(TCHAR) * (DWORD)(_tcslen(val) + 1)))
                    {
                        continue;
                    }
                    ret = RPE_VALUE_SET;
                    break;
                }
                ret = RPE_VALUE_STRING;
                break;
            }
            else if (*s == '-')
            {
                if (!doNotDeleteHiddenKeysAndValues ||
                    !StrEndsWith(line, _T(".hidden"), SizeOf(_T(".hidden")) - 1))
                {
                    // DeleteValue returns FALSE when the value did not exist
                    pRegistry->DeleteValue(hKey, line);
                }
            }
            else
            {
                ret = RPE_VALUE_INVALID_TYPE;
                break;
            }
        }
    }
    if (hKey)
        pRegistry->CloseKey(hKey);
    return ret;
}

DWORD ConvertIfNeeded(LPTSTR* pBuf, DWORD size)
{
    LPTSTR buf = *pBuf;

#ifndef _UNICODE
    if (size >= sizeof(WCHAR) &&
        !wcsncmp(((LPWSTR)buf) + 1, L"Windows Registry Editor Version 5.00",
                 SizeOf(L"Windows Registry Editor Version 5.00") - 1))
    {
#if defined(INSIDE_SALAMANDER)
        // feature 174: UTF-8 (WTF-8) for the core, its byte order mark included (Parse knows it) -
        // the code page made '?' of every letter outside it
        char* bufA = SalWToU8Alloc((LPWSTR)buf, (int)(size / sizeof(WCHAR)));
        if (!bufA)
        {
            return 0;
        }
        free(buf);
        buf = bufA;
        size = (DWORD)strlen(bufA);
#else
        char* bufA;
        int sizeA = WideCharToMultiByte(CP_ACP, 0, (LPWSTR)buf, size / sizeof(WCHAR), NULL, 0, NULL, NULL);

        bufA = (char*)malloc(sizeA + 1);
        if (!bufA)
        {
            return 0;
        }
        WideCharToMultiByte(CP_ACP, 0, (LPWSTR)buf, size / sizeof(WCHAR), bufA, sizeA, NULL, NULL);
        free(buf);
        buf = bufA;
        size = sizeA;
#endif
    }
#else
    if (!strncmp((char*)buf, "REGEDIT4", sizeof("REGEDIT4") - 1))
    {
        LPWSTR bufW;
        int sizeW = MultiByteToWideChar(CP_ACP, 0, (char*)buf, size, NULL, 0);

        sizeW *= sizeof(WCHAR);
        bufW = (LPWSTR)malloc(sizeW + sizeof(WCHAR));
        if (!bufW)
        {
            return 0;
        }
        MultiByteToWideChar(CP_ACP, 0, (char*)buf, size, bufW, sizeW / sizeof(WCHAR));
        free(buf);
        buf = bufW;
        size = sizeW;
    }
#endif

    buf[size / sizeof(TCHAR)] = 0; // force NUL termination
    *pBuf = buf;
    return size;
}
