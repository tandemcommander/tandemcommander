// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <tchar.h>

#include "regparse.h"

BOOL StrEndsWith(LPCTSTR txt, LPCTSTR pattern, size_t patternLen);

namespace RegLib
{

    class CSystemRegistry : public CSalamanderRegistryExAbstract
    {
    public:
        virtual BOOL WINAPI ClearKey(HKEY key);
        virtual BOOL WINAPI CreateKey(HKEY key, LPCTSTR name, HKEY& createdKey);
        virtual BOOL WINAPI OpenKey(HKEY key, LPCTSTR name, HKEY& openedKey);
        virtual void WINAPI CloseKey(HKEY key);
        virtual BOOL WINAPI DeleteKey(HKEY key, LPCTSTR name);
        virtual BOOL WINAPI GetValue(HKEY key, LPCTSTR name, DWORD type, LPVOID data, DWORD dataSize);
        virtual BOOL WINAPI SetValue(HKEY key, LPCTSTR name, DWORD type, LPCVOID data, DWORD dataSize);
        virtual BOOL WINAPI DeleteValue(HKEY key, LPCTSTR name);
        virtual BOOL WINAPI GetSize(HKEY key, LPCTSTR name, DWORD type, DWORD& bufferSize);

        virtual BOOL WINAPI EnumKey(HKEY key, DWORD subKeyIndex, LPTSTR name, DWORD bufferSize);
        virtual BOOL WINAPI EnumValue(HKEY key, DWORD valIndex, LPTSTR name, DWORD nameSize, LPDWORD valType, LPBYTE data, LPDWORD dataSize);

        virtual void WINAPI RemoveHiddenKeysAndValues() {}
        virtual BOOL WINAPI ClearKeyEx(HKEY key, BOOL doNotDeleteHiddenKeysAndValues, BOOL* keyIsNotEmpty);

        virtual void WINAPI Release();
        virtual BOOL WINAPI Dump(LPCTSTR /*fileName*/, LPCTSTR /*clearKeyName*/) { return TRUE; }
        virtual BOOL WINAPI DumpToBuffer(LPCTSTR /*clearKeyName*/, LPBYTE* data, DWORD* dataSize)
        {
            *data = NULL;
            *dataSize = 0;
            return FALSE;
        }

    private:
        BOOL ClearKeyAux(HKEY key, BOOL doNotDeleteHiddenKeysAndValues, BOOL* keyIsNotEmpty);
    };

    void CSystemRegistry::Release()
    {
        delete this;
    }

#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)

    // feature 174: the core keeps its configuration in the registry as UTF-16
    // (SalRegSetValueExW8); key names, value names and string data cross this class as UTF-8.
    // The A functions it used turned every letter outside the code page into '?' in the export
    // and wrote the import's UTF-8 as code-page text. A name from a REGEDIT4 file of an older
    // version (code page) is taken as code page; string data likewise (SalRegSetValueExW8).

    // the name as UTF-16 (UTF-8, or code page when it is not UTF-8); NULL stays NULL; free()
    static WCHAR* RegNameW(LPCTSTR name, BOOL* failed)
    {
        *failed = FALSE;
        if (name == NULL)
            return NULL;
        char* u8 = SalLegacyToU8Alloc(name);
        WCHAR* w = u8 != NULL ? SalU8ToWAlloc(u8) : NULL;
        free(u8);
        if (w == NULL)
            *failed = TRUE;
        return w;
    }

    // the name as valid UTF-8 for SalRegQueryValueExW8 / SalRegSetValueExW8; NULL stays NULL; free()
    static char* RegNameU8(LPCTSTR name, BOOL* failed)
    {
        *failed = FALSE;
        if (name == NULL)
            return NULL;
        char* u8 = SalLegacyToU8Alloc(name);
        if (u8 == NULL)
            *failed = TRUE;
        return u8;
    }

    static BOOL RegNameEndsWithHidden(const WCHAR* name)
    {
        size_t len = wcslen(name);
        size_t plen = wcslen(L".hidden");
        return len >= plen && _wcsicmp(name + len - plen, L".hidden") == 0;
    }

    // the longest value name the registry allows, in UTF-16 units with the terminator
    static const DWORD REG_VALUE_NAME_MAX_W = 16384;

    BOOL CSystemRegistry::ClearKey(HKEY key)
    {
        return ClearKeyAux(key, FALSE, NULL);
    }

    BOOL CSystemRegistry::ClearKeyEx(HKEY key, BOOL doNotDeleteHiddenKeysAndValues, BOOL* keyIsNotEmpty)
    {
        return ClearKeyAux(key, doNotDeleteHiddenKeysAndValues, keyIsNotEmpty);
    }

    BOOL CSystemRegistry::CreateKey(HKEY key, LPCTSTR name, HKEY& createdKey)
    {
        BOOL failed;
        WCHAR* w = RegNameW(name, &failed);
        BOOL ret = !failed && ERROR_SUCCESS == RegCreateKeyExW(key, w, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &createdKey, NULL);
        free(w);
        return ret;
    }

    BOOL CSystemRegistry::OpenKey(HKEY key, LPCTSTR name, HKEY& openedKey)
    {
        BOOL failed;
        WCHAR* w = RegNameW(name, &failed);
        BOOL ret = !failed && ERROR_SUCCESS == RegOpenKeyExW(key, w, 0, KEY_ALL_ACCESS, &openedKey);
        free(w);
        return ret;
    }

    void CSystemRegistry::CloseKey(HKEY key)
    {
        RegCloseKey(key);
    }

    BOOL CSystemRegistry::DeleteKey(HKEY key, LPCTSTR name)
    {
        BOOL failed;
        WCHAR* w = RegNameW(name, &failed);
        BOOL ret = !failed && w != NULL && ERROR_SUCCESS == RegDeleteKeyW(key, w);
        free(w);
        return ret;
    }

    BOOL CSystemRegistry::GetValue(HKEY key, LPCTSTR name, DWORD type, LPVOID data, DWORD dataSize)
    {
        BOOL failed;
        char* n = RegNameU8(name, &failed);
        DWORD realType = REG_NONE;
        BOOL ret = !failed && ERROR_SUCCESS == SalRegQueryValueExW8(key, n, &realType, (BYTE*)data, &dataSize) && realType == type;
        free(n);
        return ret;
    }

    BOOL CSystemRegistry::SetValue(HKEY key, LPCTSTR name, DWORD type, LPCVOID data, DWORD dataSize)
    {
        BOOL failed;
        char* n = RegNameU8(name, &failed);
        BOOL ret = !failed && ERROR_SUCCESS == SalRegSetValueExW8(key, n, type, (CONST BYTE*)data, dataSize);
        free(n);
        return ret;
    }

    BOOL CSystemRegistry::DeleteValue(HKEY key, LPCTSTR name)
    {
        BOOL failed;
        WCHAR* w = RegNameW(name, &failed);
        BOOL ret = !failed && ERROR_SUCCESS == RegDeleteValueW(key, w);
        free(w);
        return ret;
    }

    BOOL CSystemRegistry::GetSize(HKEY key, LPCTSTR name, DWORD type, DWORD& dataSize)
    {
        BOOL failed;
        char* n = RegNameU8(name, &failed);
        DWORD realType = REG_NONE;
        BOOL ret = !failed && ERROR_SUCCESS == SalRegQueryValueExW8(key, n, &realType, NULL, &dataSize) && realType == type;
        free(n);
        return ret;
    }

    BOOL CSystemRegistry::EnumKey(HKEY key, DWORD subKeyIndex, LPTSTR name, DWORD bufferSize)
    {
        WCHAR nameW[256]; // a key name has at most 255 characters
        DWORD len = _countof(nameW);
        return ERROR_SUCCESS == RegEnumKeyExW(key, subKeyIndex, nameW, &len, NULL, NULL, NULL, NULL) &&
               SalWToU8(nameW, -1, name, (int)bufferSize) != 0;
    }

    BOOL CSystemRegistry::EnumValue(HKEY key, DWORD valIndex, LPTSTR name, DWORD nameSize, LPDWORD valType, LPBYTE data, LPDWORD dataSize)
    {
        WCHAR* nameW = (WCHAR*)malloc(REG_VALUE_NAME_MAX_W * sizeof(WCHAR));
        if (nameW == NULL)
            return FALSE;
        DWORD len = REG_VALUE_NAME_MAX_W;
        DWORD type = REG_NONE;
        BOOL ret = ERROR_SUCCESS == RegEnumValueW(key, valIndex, nameW, &len, NULL, &type, NULL, NULL) &&
                   SalWToU8(nameW, -1, name, (int)nameSize) != 0;
        free(nameW);
        if (ret && valType != NULL)
            *valType = type;
        if (ret && dataSize != NULL) // the data as GetValue gives them (strings UTF-8)
            ret = ERROR_SUCCESS == SalRegQueryValueExW8(key, name, NULL, data, dataSize);
        return ret;
    }

    BOOL CSystemRegistry::ClearKeyAux(HKEY key, BOOL doNotDeleteHiddenKeysAndValues, BOOL* keyIsNotEmpty)
    {
        WCHAR* name = (WCHAR*)malloc(REG_VALUE_NAME_MAX_W * sizeof(WCHAR)); // also holds any key name
        if (name == NULL)
            return FALSE;
        HKEY subKey;
        DWORD size = REG_VALUE_NAME_MAX_W;
        DWORD index = 0;
        BOOL ret = TRUE;

        while (RegEnumKeyExW(key, index, name, &size, NULL, NULL, NULL, NULL) == ERROR_SUCCESS)
        {
            if (!doNotDeleteHiddenKeysAndValues || !RegNameEndsWithHidden(name))
            {
                if (RegOpenKeyExW(key, name, 0, KEY_READ | KEY_WRITE, &subKey) == ERROR_SUCCESS)
                {
                    BOOL subkeyIsNotEmpty = FALSE;
                    BOOL subRet = ClearKeyAux(subKey, doNotDeleteHiddenKeysAndValues, &subkeyIsNotEmpty);
                    if (subkeyIsNotEmpty && keyIsNotEmpty != NULL)
                        *keyIsNotEmpty = TRUE;

                    RegCloseKey(subKey);
                    if (!subRet || !subkeyIsNotEmpty && RegDeleteKeyW(key, name) != ERROR_SUCCESS)
                    {
                        ret = FALSE;
                        break;
                    }
                    if (subkeyIsNotEmpty)
                        index++;
                }
                else
                {
                    ret = FALSE;
                    break;
                }
            }
            else
            {
                if (keyIsNotEmpty != NULL)
                    *keyIsNotEmpty = TRUE;
                index++;
            }
            size = REG_VALUE_NAME_MAX_W;
        }

        size = REG_VALUE_NAME_MAX_W;
        index = 0;
        while (ret && RegEnumValueW(key, index, name, &size, NULL, NULL, NULL, NULL) == ERROR_SUCCESS)
        {
            if (!doNotDeleteHiddenKeysAndValues || !RegNameEndsWithHidden(name))
            {
                if (RegDeleteValueW(key, name) != ERROR_SUCCESS)
                { // Unable to delete values in specified key (in registry)
                    break;
                }
            }
            else
            {
                if (keyIsNotEmpty != NULL)
                    *keyIsNotEmpty = TRUE;
                index++;
            }
            size = REG_VALUE_NAME_MAX_W;
        }

        free(name);
        return ret;
    }

#else // INSIDE_SALAMANDER && !_UNICODE

    BOOL CSystemRegistry::ClearKey(HKEY key)
    {
        return ClearKeyAux(key, FALSE, NULL);
    }

    BOOL CSystemRegistry::ClearKeyEx(HKEY key, BOOL doNotDeleteHiddenKeysAndValues, BOOL* keyIsNotEmpty)
    {
        return ClearKeyAux(key, doNotDeleteHiddenKeysAndValues, keyIsNotEmpty);
    }

    BOOL CSystemRegistry::CreateKey(HKEY key, LPCTSTR name, HKEY& createdKey)
    {
        char buff[] = "";
        return ERROR_SUCCESS == RegCreateKeyEx(key, name, 0, buff, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &createdKey, NULL);
    }

    BOOL CSystemRegistry::OpenKey(HKEY key, LPCTSTR name, HKEY& openedKey)
    {
        return ERROR_SUCCESS == RegOpenKeyEx(key, name, 0, KEY_ALL_ACCESS, &openedKey);
    }

    void CSystemRegistry::CloseKey(HKEY key)
    {
        RegCloseKey(key);
    }

    BOOL CSystemRegistry::DeleteKey(HKEY key, LPCTSTR name)
    {
        return ERROR_SUCCESS == RegDeleteKey(key, name);
    }

#ifndef INSIDE_SALAMANDER

    // our variant of the RegQueryValueEx function; unlike the API version it
    // ensures adding a null terminator for REG_SZ, REG_MULTI_SZ, and
    // REG_EXPAND_SZ
    // WARNING: when determining the required buffer size it returns one or two
    //          characters more (two only for REG_MULTI_SZ) in case the string
    //          needs to be terminated with null character(s)
    LONG SalRegQueryValueEx(HKEY hKey, LPCSTR lpValueName, LPDWORD lpReserved,
                            LPDWORD lpType, LPBYTE lpData, LPDWORD lpcbData)
    {
        DWORD dataBufSize = lpData == NULL ? 0 : *lpcbData;
        DWORD type = REG_NONE;
        LONG ret = RegQueryValueEx(hKey, lpValueName, lpReserved, &type, lpData, lpcbData);
        if (lpType != NULL)
            *lpType = type;
        if (type == REG_SZ || type == REG_MULTI_SZ || type == REG_EXPAND_SZ)
        {
            if (hKey != HKEY_PERFORMANCE_DATA &&
                lpcbData != NULL &&
                (ret == ERROR_MORE_DATA || lpData == NULL && ret == ERROR_SUCCESS))
            {
                (*lpcbData) += type == REG_MULTI_SZ ? 2 : 1; // proactively request extra null terminator(s)
                return ret;
            }
            if (ret == ERROR_SUCCESS && lpData != NULL)
            {
                if (*lpcbData < 1 || ((char*)lpData)[*lpcbData - 1] != 0)
                {
                    if (*lpcbData < dataBufSize)
                    {
                        ((char*)lpData)[*lpcbData] = 0;
                        (*lpcbData)++;
                    }
                    else // not enough space for a null terminator in the buffer
                    {
                        (*lpcbData) += type == REG_MULTI_SZ ? 2 : 1; // request the required null terminator(s)
                        return ERROR_MORE_DATA;
                    }
                }
                if (type == REG_MULTI_SZ && (*lpcbData < 2 || ((char*)lpData)[*lpcbData - 2] != 0))
                {
                    if (*lpcbData < dataBufSize)
                    {
                        ((char*)lpData)[*lpcbData] = 0;
                        (*lpcbData)++;
                    }
                    else // not enough space for the second null terminator in the buffer
                    {
                        (*lpcbData)++; // request the required null terminator
                        return ERROR_MORE_DATA;
                    }
                }
            }
        }
        return ret;
    }

#endif // INSIDE_SALAMANDER

    BOOL CSystemRegistry::GetValue(HKEY key, LPCTSTR name, DWORD type, LPVOID data, DWORD dataSize)
    {
        DWORD realType;

        return (ERROR_SUCCESS == SalRegQueryValueEx(key, name, NULL, &realType, (BYTE*)data, &dataSize)) && (realType == type);
    }

    BOOL CSystemRegistry::SetValue(HKEY key, LPCTSTR name, DWORD type, LPCVOID data, DWORD dataSize)
    {
        return ERROR_SUCCESS == RegSetValueEx(key, name, NULL, type, (BYTE*)data, dataSize);
    }

    BOOL CSystemRegistry::DeleteValue(HKEY key, LPCTSTR name)
    {
        return ERROR_SUCCESS == RegDeleteValue(key, name);
    }

    BOOL CSystemRegistry::GetSize(HKEY key, LPCTSTR name, DWORD type, DWORD& dataSize)
    {
        DWORD realType;

        return (ERROR_SUCCESS == SalRegQueryValueEx(key, name, NULL, &realType, NULL, &dataSize)) && (realType == type);
    }

    BOOL CSystemRegistry::EnumKey(HKEY key, DWORD subKeyIndex, LPTSTR name, DWORD bufferSize)
    {
        return ERROR_SUCCESS == RegEnumKeyEx(key, subKeyIndex, name, &bufferSize, NULL, NULL, NULL, NULL);
    }

    BOOL CSystemRegistry::EnumValue(HKEY key, DWORD valIndex, LPTSTR name, DWORD nameSize, LPDWORD valType, LPBYTE data, LPDWORD dataSize)
    {
        return ERROR_SUCCESS == RegEnumValue(key, valIndex, name, &nameSize, NULL, valType, data, dataSize);
    }

    BOOL CSystemRegistry::ClearKeyAux(HKEY key, BOOL doNotDeleteHiddenKeysAndValues, BOOL* keyIsNotEmpty)
    {
        TCHAR name[MAX_PATH];
        HKEY subKey;
        DWORD size = SizeOf(name);
        DWORD index = 0;

        while (RegEnumKeyEx(key, index, name, &size, NULL, NULL, NULL, NULL) == ERROR_SUCCESS)
        {
            if (!doNotDeleteHiddenKeysAndValues ||
                !::StrEndsWith(name, _T(".hidden"), SizeOf(_T(".hidden")) - 1))
            {
                if (RegOpenKeyEx(key, name, 0, KEY_READ | KEY_WRITE, &subKey) == ERROR_SUCCESS)
                {
                    BOOL subkeyIsNotEmpty = FALSE;
                    BOOL ret = ClearKeyAux(subKey, doNotDeleteHiddenKeysAndValues, &subkeyIsNotEmpty);
                    if (subkeyIsNotEmpty && keyIsNotEmpty != NULL)
                        *keyIsNotEmpty = TRUE;

                    RegCloseKey(subKey);
                    if (!ret || !subkeyIsNotEmpty && RegDeleteKey(key, name) != ERROR_SUCCESS)
                        return FALSE;
                    if (subkeyIsNotEmpty)
                        index++;
                }
                else
                {
                    return FALSE;
                }
            }
            else
            {
                if (keyIsNotEmpty != NULL)
                    *keyIsNotEmpty = TRUE;
                index++;
            }
            size = SizeOf(name);
        }

        size = SizeOf(name);
        index = 0;
        while (RegEnumValue(key, index, name, &size, NULL, NULL, NULL, NULL) == ERROR_SUCCESS)
        {
            if (!doNotDeleteHiddenKeysAndValues ||
                !::StrEndsWith(name, _T(".hidden"), SizeOf(_T(".hidden")) - 1))
            {
                if (RegDeleteValue(key, name) != ERROR_SUCCESS)
                { // Unable to delete values in specified key (in registry)
                    break;
                }
            }
            else
            {
                if (keyIsNotEmpty != NULL)
                    *keyIsNotEmpty = TRUE;
                index++;
            }
            size = SizeOf(name);
        }

        return TRUE;
    }

#endif // INSIDE_SALAMANDER && !_UNICODE

} // namespace RegLib

CSalamanderRegistryExAbstract* REG_SysRegistryFactory()
{
    return new RegLib::CSystemRegistry();
}
