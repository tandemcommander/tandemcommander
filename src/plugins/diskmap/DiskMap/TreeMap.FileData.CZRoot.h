// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "Utils.Array.h"
#include "System.RWLock.h"
#include "System.WorkerThread.h"
#include "TreeMap.FileData.CZFile.h"
#include "TreeMap.FileData.CZDirectory.h"
#include "System.CLogger.h"
#include "Utils.CZString.h"

#define ARRAY_BLOCKSIZE_CFILELIST 64
#define MAXREPORTEDFILES 256

class CZFile;
class CZDirectory;
class CZRoot;

//enum EPopulateState { psNULL, psPopulating, psPopulated, psAbort, psAborted };

class CZRoot : public CZDirectory
{
protected:
    friend class CZDirectory;

    int _sortorder;

    volatile int _allfilecount;
    volatile int _alldircount;
    volatile INT64 _allsize;

    CRWLock* _lock;
    CLogger* _logger;

    int _clustersize;
    int _minimalfilesize; //determine whether NTFS, because then it equals 512

    CRWLock* GetRWLock() { return this->_lock; }

    static DWORD_PTR WINAPI PopulateThreadProc(CWorkerThread* mythread, LPVOID lpParam)
    {
        CZRoot* self = (CZRoot*)lpParam;
        TCHAR path[6 * MAX_PATH + 3]; //UTF-8 path + UTF-8 file name (up to 3 bytes per character) + some margin
        self->PopulateDir(mythread, path, 0, ARRAYSIZE(path));
        if (mythread->Aborting() && mythread->IsSelfDelete())
        {
            delete self;
            return FALSE;
        }
        return TRUE;
    }
    void Log(int level, const TCHAR* text, CZFile* file /*CString *path*/)
    {
        CLogItemBase* lgi;
        lgi = CLogger::CreateLogItem(level, text, new CZString(file));
        this->_logger->Log(lgi);
    }
    void LogLastError(CZFile* file)
    {
        this->LogError(file, GetLastError());
    }
    void LogError(CZFile* file, DWORD dwError)
    {
        // feature 121 (review NIT 5): a message longer than the buffer made FormatMessage fail and an
        // uninitialised buffer was logged (and shown by the log window) - larger, checked, no inserts
        TCHAR szBuf[512];
        if (FormatMessage(
                FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                NULL,
                dwError,
                MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                szBuf, ARRAYSIZE(szBuf),
                NULL) == 0)
            _stprintf_s(szBuf, TEXT("Error %u"), (unsigned)dwError);

        CZString* ers = new CZString(szBuf);
        CLogItemBase* lgi = CLogger::CreateLogItem(LOG_ERROR, ers, new CZString(file));
        this->_logger->Log(lgi);
    }
    void IncStats(int fileinc, int dirinc, INT64 sizeinc)
    {
        this->_lock->EnterWrite();
        this->_allfilecount += fileinc;
        this->_alldircount += dirinc;
        this->_allsize += sizeinc;
        this->_lock->LeaveWrite();
    }

public:
    CZRoot(TCHAR const* name, CLogger* logger, int sortorder = FILESIZE_DISK) : CZDirectory(NULL, name, NULL, NULL)
    {
        this->_clustersize = 0;
        this->_minimalfilesize = 0; //TODO: pro NTFS = 512

        this->_allfilecount = 0;
        this->_alldircount = 0;
        this->_allsize = 0;

        this->_sortorder = sortorder;

        this->_lock = new CRWLock();

        this->_logger = logger;

        this->_root = this;
    }
    virtual ~CZRoot()
    {
        delete this->_lock;
    }
    int GetSortOrder() { return this->_sortorder; }

    //FIXME: toto je hack :(
    void SetClusterSize(int clustersize)
    {
        this->_clustersize = clustersize;
    }
    INT64 GetDiskSize(INT64 filesize)
    {
        if (filesize <= this->_minimalfilesize)
            return 0;
        if (!this->_clustersize)
        {
            TCHAR path[3 * MAX_PATH + 1]; // UTF-8 path (up to 3 bytes per character)
            size_t pos = this->GetFullName(path, ARRAYSIZE(path) - 2);
            if (path[pos - 1] != TEXT('\\'))
                path[pos++] = TEXT('\\');
            path[pos++] = TEXT('\0');
            DWORD SectorsPerCluster = 0;
            DWORD BytesPerSector = 0;
            DWORD NumberOfFreeClusters = 0;
            DWORD TotalNumberOfClusters = 0;
            WCHAR* wPath = SplU8ToWAlloc(path); // the path is UTF-8 -> W API
            BOOL gotSpace = wPath != NULL ? GetDiskFreeSpaceW(wPath, &SectorsPerCluster, &BytesPerSector, &NumberOfFreeClusters, &TotalNumberOfClusters)
                                          : GetDiskFreeSpaceA(path, &SectorsPerCluster, &BytesPerSector, &NumberOfFreeClusters, &TotalNumberOfClusters);
            free(wPath);
            if (!gotSpace)
            {
                this->_logger->Log(new CBasicLogItem(LOG_ERROR, TEXT("Problem with GetDiskFreeSpace() API."), NULL));
            }
            else
            {
                this->_clustersize = BytesPerSector * SectorsPerCluster;
            }
        }
        if (!this->_clustersize)
        {
            this->_clustersize = 512;
        }
        return ((filesize - 1) / this->_clustersize + 1) * this->_clustersize;
    }

    void GetStats(int& filecount, int& dircount, INT64& size)
    {
        this->_lock->EnterRead();
        filecount = this->_allfilecount;
        dircount = this->_alldircount;
        size = this->_allsize;
        this->_lock->LeaveRead();
    }

    INT64 SyncPopulate()
    {
        TCHAR path[6 * MAX_PATH + 3]; //UTF-8 path + UTF-8 file name (up to 3 bytes per character) + some margin
        return this->PopulateDir(NULL, path, 0, ARRAYSIZE(path));
    }

    CWorkerThread* BeginAsyncPopulate(HWND owner, UINT msg)
    {
        CWorkerThread* mythread = new CWorkerThread(
            NULL,
            CZRoot::PopulateThreadProc,
            this,
            owner,
            msg,
            this,
            FALSE);
        return mythread;
    }
};
