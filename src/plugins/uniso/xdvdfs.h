// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "fs.h"

// Some elementera info on Xbox DVD format can be found here: http://home.comcast.net/~admiral_powerslave/dvddrives.html

#define XBOX_DESCRIPTOR "MICROSOFT*XBOX*MEDIA"

// ****************************************************************************
//
// CXDVDFS
//

/* types */
#define Uint8 BYTE
#define Uint16 WORD
#define Uint32 DWORD
#define Uint64 unsigned __int64

class CXDVDFS : public CUnISOFSAbstract
{
protected:
    struct CVolumeDescriptor
    {
        Uint32 RootSector;
        Uint32 RootDirectorySize;
        FILETIME CreationTime;
    };

    struct CDirectoryEntry
    {
        Uint32 StartSector;
        Uint32 FileSize;
        BYTE Attr;
    };

    CVolumeDescriptor VD;

    DWORD ExtentOffset;

public:
    CXDVDFS(CISOImage* image, DWORD extent);
    virtual ~CXDVDFS();
    // methods

    virtual BOOL Open(BOOL quiet);
    virtual BOOL DumpInfo(FILE* outStream);
    virtual BOOL ListDirectory(char* path, int session,
                               CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData);
    virtual int UnpackFile(CSalamanderForOperationsAbstract* salamander, const char* srcPath, const char* path,
                           const char* nameInArc, const CFileData* fileData, DWORD& silent, BOOL& toSkip);

protected:
    BOOL ReadBlockPhys(Uint32 lbNum, size_t blocks, unsigned char* data);

    // feature 329: AddFileDir results - as CISO9660's (328): listed, left out (refused by the listing:
    // noted on the image, the walk goes on), failed (the directory ends)
    enum
    {
        ADD_FAILED = 0,
        ADD_LISTED = 1,
        ADD_LEFT_OUT = 2
    };
    int AddFileDir(const char* path, char* fileName, CDirectoryEntry* de,
                   CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData);

    int ScanDir(DWORD sector, DWORD size, char* path, CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData);
};
