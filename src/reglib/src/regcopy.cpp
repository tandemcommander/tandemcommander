// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <tchar.h>

#include "regparse.h"

#include <string>

// feature 174: the names of keys and values in one buffer of the largest size a value name can
// have (16,383 characters; 3 bytes each in UTF-8) - with MAX_PATH a longer name ended the
// enumeration as if there were no more, and the export left the rest out silently. The buffer is
// shared by the whole recursion: a name is not used after the call that goes one level down.
static const DWORD REG_COPY_NAME_SIZE = 3 * 16384 + 1;

static eRPE_ERROR CopyKey(CSalamanderRegistryExAbstract* pInReg, HKEY hInKey, CSalamanderRegistryExAbstract* pOutReg, HKEY hOutKey, LPTSTR name,
                          REG_VALUE_TRANSFORM transform, void* transformCtx, std::string& keyPath)
{
    eRPE_ERROR ret = RPE_OK;

    DWORD indKey;
    for (indKey = 0;; indKey++)
    {
        HKEY hSubInKey, hSubOutKey;
        if (!pInReg->EnumKey(hInKey, indKey, name, REG_COPY_NAME_SIZE))
        {
            break;
        }
        if (!pInReg->OpenKey(hInKey, name, hSubInKey))
        {
            return RPE_KEY_OPEN;
        }
        if (!pOutReg->CreateKey(hOutKey, name, hSubOutKey))
        {
            pInReg->CloseKey(hSubInKey);
            return RPE_KEY_CREATE;
        }
        size_t keyPathLen = keyPath.size(); // feature 428: the transform sees where a value lives
        keyPath += "\\";
        keyPath += name;
        ret = CopyKey(pInReg, hSubInKey, pOutReg, hSubOutKey, name, transform, transformCtx, keyPath);
        keyPath.resize(keyPathLen);
        pInReg->CloseKey(hSubInKey);
        pOutReg->CloseKey(hSubOutKey);
        if (RPE_OK != ret)
        {
            return ret;
        }
    }

    DWORD indVal;
    for (indVal = 0;; indVal++)
    {
        DWORD valType, dataSize;
        BYTE data[256];
        LPBYTE dataPtr = data;

        if (!pInReg->EnumValue(hInKey, indVal, name, REG_COPY_NAME_SIZE, &valType, NULL, NULL))
        {
            break;
        }
        if (!pInReg->GetSize(hInKey, name, valType, dataSize))
        {
            ret = RPE_VALUE_GET_SIZE;
            break;
        }
        if (dataSize > sizeof(data))
        {
            dataPtr = (LPBYTE)malloc(dataSize);
            if (!dataPtr)
            {
                ret = RPE_OUT_OF_MEMORY;
                break;
            }
        }
        if (!pInReg->GetValue(hInKey, name, valType, dataPtr, dataSize))
        {
            if (dataPtr != data)
                free(dataPtr);
            ret = RPE_VALUE_GET;
            break;
        }
        // feature 428: the caller may rewrite a value on its way (the portable store's $(SalDir));
        // 'newData' is malloc'ed by the transform, NULL = the value goes as it is
        LPBYTE newData = NULL;
        DWORD newSize = 0;
        if (transform != NULL && !transform(keyPath.c_str(), valType, dataPtr, dataSize, &newData, &newSize, transformCtx))
        {
            if (dataPtr != data)
                free(dataPtr);
            ret = RPE_OUT_OF_MEMORY;
            break;
        }
        BOOL setOk = newData != NULL ? pOutReg->SetValue(hOutKey, name, valType, newData, newSize)
                                     : pOutReg->SetValue(hOutKey, name, valType, dataPtr, dataSize);
        free(newData);
        if (!setOk)
        {
            if (dataPtr != data)
                free(dataPtr);
            ret = RPE_VALUE_SET;
            break;
        }
        if (dataPtr != data)
            free(dataPtr);
    }
    return ret;
}

eRPE_ERROR CopyBranch(LPCTSTR branch, CSalamanderRegistryExAbstract* pInReg, CSalamanderRegistryExAbstract* pOutReg)
{
    return CopyBranchTransform(branch, pInReg, pOutReg, NULL, NULL);
}

eRPE_ERROR CopyBranchTransform(LPCTSTR branch, CSalamanderRegistryExAbstract* pInReg, CSalamanderRegistryExAbstract* pOutReg,
                               REG_VALUE_TRANSFORM transform, void* transformCtx)
{
    HKEY hParentKey, hInKey, hOutKey;
    eRPE_ERROR ret = RPE_OK;

    if (!_tcsnicmp(branch, _T("HKEY_CURRENT_USER"), SizeOf(_T("HKEY_CURRENT_USER")) - 1)) // portable: reglib name (the system registry maps it to SalCfgBaseKey())
    {
        branch += SizeOf(_T("HKEY_CURRENT_USER")) - 1;
        hParentKey = HKEY_CURRENT_USER; // portable: reglib name (the system registry maps it to SalCfgBaseKey())
    }
    else if (!_tcsnicmp(branch, _T("HKEY_CLASSES_ROOT"), SizeOf(_T("HKEY_CLASSES_ROOT")) - 1))
    {
        branch += SizeOf(_T("HKEY_CLASSES_ROOT")) - 1;
        hParentKey = HKEY_CLASSES_ROOT;
    }
    else if (!_tcsnicmp(branch, _T("HKEY_LOCAL_MACHINE"), SizeOf(_T("HKEY_LOCAL_MACHINE")) - 1))
    {
        branch += SizeOf(_T("HKEY_LOCAL_MACHINE")) - 1;
        hParentKey = HKEY_LOCAL_MACHINE;
    }
    else if (!_tcsnicmp(branch, _T("HKEY_USERS"), SizeOf(_T("HKEY_USERS")) - 1))
    {
        branch += SizeOf(_T("HKEY_USERS")) - 1;
        hParentKey = HKEY_USERS;
    }
    else if (!_tcsnicmp(branch, _T("HKEY_CURRENT_CONFIG"), SizeOf(_T("HKEY_CURRENT_CONFIG")) - 1))
    {
        branch += SizeOf(_T("HKEY_CURRENT_CONFIG")) - 1;
        hParentKey = HKEY_CURRENT_CONFIG;
    }
    else if (!_tcsnicmp(branch, _T("HKEY_DYN_DATA"), SizeOf(_T("HKEY_DYN_DATA")) - 1))
    {
        branch += SizeOf(_T("HKEY_DYN_DATA")) - 1;
        hParentKey = HKEY_DYN_DATA;
    }
    else if (!_tcsnicmp(branch, _T("HKEY_PERFORMANCE_DATA"), SizeOf(_T("HKEY_PERFORMANCE_DATA")) - 1))
    {
        branch += SizeOf(_T("HKEY_PERFORMANCE_DATA")) - 1;
        hParentKey = HKEY_PERFORMANCE_DATA;
    }
    else
    {
        return RPE_ROOT_INVALID_KEY;
    }

    if (*branch != 0)
    {
        if (*branch != '\\')
        {
            return RPE_ROOT_INVALID_KEY;
        }
        else
        {
            branch++;
        }
    }

    if (!pInReg->OpenKey(hParentKey, branch, hInKey))
    {
        return RPE_KEY_OPEN;
    }

    if (pOutReg->CreateKey(hParentKey, branch, hOutKey))
    {
        LPTSTR name = (LPTSTR)malloc(REG_COPY_NAME_SIZE * sizeof(TCHAR));
        std::string keyPath; // relative to the branch: "" for its root, "\\Sub\\Key" below it
        ret = name != NULL ? CopyKey(pInReg, hInKey, pOutReg, hOutKey, name, transform, transformCtx, keyPath) : RPE_OUT_OF_MEMORY;
        free(name);
        pOutReg->CloseKey(hOutKey);
    }
    else
    {
        ret = RPE_KEY_CREATE;
    }

    pInReg->CloseKey(hInKey);

    return ret;
}
