// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "dbg.h"

#include "uniso.h"
#include "isoimage.h"

#include "uniso.rh"
#include "uniso.rh2"
#include "lang\lang.rh"

#include "audio.h"
#include "iso9660.h"
#include "udf.h"
#include "udfiso.h"
#include "xdvdfs.h"
#include "rawfs.h"
#include "mdf.h"
#include "dmg.h"
#include "isz.h"
#include "apfs.h"

// ****************************************************************************
//
// Helpers
//

// RIFF header
// for the CIF format created by Easy CD Creator
struct RIFFHeader
{
    char RIFF[4];
    DWORD Size;
    char ID[4];
};

// Converts binary date/time format to FILETIME
void ISODateTimeToFileTime(BYTE isodt[], FILETIME* ft)
{
    SYSTEMTIME st;
    __int64 newtime;

    CALL_STACK_MESSAGE1("ISODateTimeToSystemTime(, )");

    st.wYear = 1900 + isodt[0];
    st.wMonth = isodt[1];
    st.wDayOfWeek = 0;
    st.wDay = isodt[2];
    st.wHour = isodt[3];
    st.wMinute = isodt[4];
    st.wSecond = isodt[5];
    st.wMilliseconds = 0;

    SystemTimeToFileTime(&st, ft);
    // idodt[6] Offset from Greenwich Mean Time in number of 15 minute intervals from -48(West) to +52(East)
    newtime = ft->dwLowDateTime + (((__int64)ft->dwHighDateTime) << 32);
    newtime -= ((__int64)(signed char)isodt[6]) * 15 * 60 * 1000 * 1000 * 10; // from 15min units to 100ns units
    ft->dwLowDateTime = (DWORD)(newtime & 0xffffffff);
    ft->dwHighDateTime = (DWORD)(newtime >> 32);
}

// converts the string date format to SYSTEMTIME
void ISODateTimeStrToSystemTime(BYTE isodt[], SYSTEMTIME* st)
{
    CALL_STACK_MESSAGE1("ISODateTimeStrToSystemTime(, )");

#define CpyN(Var, Ofs, N) \
    ZeroMemory(strdate, 16); \
    memcpy(strdate, isodt + Ofs, N); \
    strdate[N] = '\0'; \
    sscanf(strdate, "%hu", &(st->##Var));

    char strdate[16];

    ZeroMemory(st, sizeof(*st));
    CpyN(wYear, 0, 4);
    CpyN(wMonth, 4, 2);
    CpyN(wDay, 6, 2);
    CpyN(wHour, 8, 2);
    CpyN(wMinute, 10, 2);
    CpyN(wSecond, 12, 2);
#undef CpyN
}

void GetInfo(char* buffer, FILETIME* lastWrite, CQuadWord size)
{
    CALL_STACK_MESSAGE2("GetInfo(, , 0x%I64X)", size.Value);

    SYSTEMTIME st;
    FILETIME ft;
    FileTimeToLocalFileTime(lastWrite, &ft);
    FileTimeToSystemTime(&ft, &st);

    char date[50], time[50], number[50];
    if (GetTimeFormat(LOCALE_USER_DEFAULT, 0, &st, NULL, time, 50) == 0)
        sprintf(time, "%u:%02u:%02u", st.wHour, st.wMinute, st.wSecond);
    if (GetDateFormat(LOCALE_USER_DEFAULT, DATE_SHORTDATE, &st, NULL, date, 50) == 0)
        sprintf(date, "%u.%u.%u", st.wDay, st.wMonth, st.wYear);
    sprintf(buffer, "%s, %s, %s", SalamanderGeneral->NumberToStr(number, size), date, time);
}

void SetFileAttrs(const char* name, DWORD attrs, BOOL quiet)
{
    if (Options.ClearReadOnly)
        attrs &= ~FILE_ATTRIBUTE_READONLY;
    if (!SetFileAttributesU8(name, attrs)) // 'name' is UTF-8 (interface 104) -> W API
    { // set attributes - always clear Archive attribute, clearing of Read-Only attribute depends on settings
        DWORD err = GetLastError();
        Error(LoadStrU8(IDS_CANT_SET_ATTRS), err, quiet);
    }
}

//
BOOL IsValidCDHeader(char hdr[])
{
    if (hdr[0] == 0x01 && strncmp((hdr + 1), "CD001", 5) == 0)
        return TRUE;
    else
        return FALSE;
}

BOOL IsValidUDFHeader(char hdr[])
{
    if (hdr[0] == 0x00 && strncmp((hdr + 1), "BEA01", 5) == 0)
        return TRUE;
    else
        return FALSE;
}

// ****************************************************************************
//
// CISOImage
//

CISOImage::Track::Track()
{
    // feature 351: every field has a value before a reader describes the track - a track the track
    // table does not describe (a CUEX track no DAOX entry names) stays unknown with zero bounds: never
    // detected nor listed, it marks the listing (334); before, these were the heap's (Release: a
    // CloneCD data track was often "unknown" and the image did not open)
    SectorSize = 0;
    SectorHeaderSize = 0;
    Mode = mNone;
    Start = 0;
    End = 0;
    ExtentOffset = 0;
    FSType = fsUnknown;
    FileSystem = NULL;
    Bootable = FALSE;
    RawLost = FALSE;
    Form2Stream = FALSE;
}

CISOImage::Track::~Track()
{
    delete FileSystem;
}

const char* CISOImage::Track::GetLabel()
{
    return "";
}

void CISOImage::Track::SetLabel(const char*)
{
}

CISOImage::CISOImage() : Session(10, 5),
                         Tracks(30, 10, dtDelete)
{
    FileName = NULL;
    File = NULL;

    DataOffset = 0;

    OpenedTrack = -1;

    // GUI
    DisplayMissingCCDWarning = TRUE;
    CcdMissing = FALSE;

    // default
    SectorHeaderSize = 0;
    SectorRawSize = 2048;
    SectorUserSize = 2048;

    Label = NULL;

    ImageDataEnd = -1;
}

CISOImage::~CISOImage()
{
    delete[] FileName;
    delete[] Label;
    delete File;
}

void CISOImage::AddTrack(Track* track)
{
    Tracks.Add(track);
}

void CISOImage::AddSessionTracks(int tracks)
{
    Session.Add(tracks);
}

void CISOImage::SetLabel(const char* label)
{
    delete[] Label;
    Label = new char[strlen(label) + 1];
    if (Label)
        strcpy(Label, label);
}

const char*
CISOImage::GetLabel()
{
    return Label ? Label : "";
}

DWORD
CISOImage::ReadDataByPos(LONGLONG position, DWORD size, void* data)
{
    if (File->Seek(position, FILE_BEGIN) == -1)
        return 0;

    DWORD read;

    if (File->Read(data, size, &read, FileName, SalamanderGeneral->GetMainWindowHWND()))
        return read;
    else
        return 0;
}

BOOL CISOImage::SetSectorFormat(ESectorType format)
{
    CALL_STACK_MESSAGE1("CISOImage::SetSectorFormat()");

    SectorType = format;

    switch (format)
    {
    case stMode1:
        SectorHeaderSize = 16;
        SectorRawSize = 0x930;
        break;

    case stMode2Form1:
        SectorHeaderSize = 24;
        SectorRawSize = 0x930;
        break;

    case stMode2Form2:
        SectorHeaderSize = 24;
        SectorUserSize = 2324;
        SectorRawSize = 0x930;
        break;

    case stMode2Form12336:
        SectorHeaderSize = 8;
        SectorRawSize = 0x920;
        break;

    case stCIF:
        SectorHeaderSize = 8;
        SectorRawSize = 0x808;
        break;

    case stISO:
    default:
        SectorHeaderSize = 0;
        SectorRawSize = 0x800;
        break;
    }

    return TRUE;
}

void CISOImage::DetectSectorType()
{
    CALL_STACK_MESSAGE1("CISOImage::DetectSectorType()");

    if (File->Seek(0, FILE_BEGIN) == -1)
        return;

    char buffer[2352];
    DWORD read;
    ESectorType type;

    if (!File->Read(buffer, 2352, &read, FileName, SalamanderGeneral->GetMainWindowHWND()))
        return;

    if (File->Seek(0, FILE_BEGIN) == -1)
        return;

    if (!memcmp(buffer, "\0\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\0", 12))
    {
        if (buffer[15] == 1)
            type = stMode1;
        else if (buffer[15] == 2)
        {
            if (buffer[18] & 0x20)
                type = stMode2Form2;
            else
                type = stMode2Form1;
        }
        else
            type = stISO;
    }
    else
        type = stISO;

    SectorType = type;
}

LONGLONG
CISOImage::GetSectorOffset(int nSector)
{
    return Int32x32To64(nSector, SectorRawSize) + SectorHeaderSize + DataOffset;
}

//
// A set of functions to detect whether the image is valid. One function per format.
// It's a bit silly because we have to add a new function for every new format.
// Other plugins look for the CD001 signature and determine the format based on it. We could do that too,
// but you cannot fully rely on it.
// With this approach we can also set the image format and other important information right away.
// And we can be sure that we are indeed working with a CD image
//

BOOL CISOImage::CheckForISO(BOOL quiet /* = FALSE*/)
{
    char hdr[6];
    LONGLONG offset = GetSectorOffset(16);
    if (ReadDataByPos(offset, sizeof(hdr), hdr) != sizeof(hdr))
        return FALSE;

    if (IsValidCDHeader(hdr) || IsValidUDFHeader(hdr))
        return TRUE; // ok, it's ISO

    return FALSE;
}

BOOL CISOImage::CheckForNRG(BOOL quiet /* = FALSE*/)
{
    char hdr[6];
    LONGLONG offset = GetSectorOffset(16);

    // check for NRG
    if (ReadDataByPos(offset + 0x4B000, sizeof(hdr), hdr) != sizeof(hdr))
        return FALSE;

    if (IsValidCDHeader(hdr) || IsValidUDFHeader(hdr))
    {
        // ok, it's NRG
        DataOffset = 0x4B000;
        return TRUE;
    }

    return FALSE;
}

BOOL CISOImage::CheckFor2336(BOOL quiet /* = FALSE*/)
{
    char hdr[6];

    if (ReadDataByPos(0x9208, sizeof(hdr), hdr) == sizeof(hdr))
    {
        if (IsValidCDHeader(hdr))
        {
            SetSectorFormat(stMode2Form12336);
            return TRUE;
        }
        else
        {
            if (ReadDataByPos(0x5EAC8, sizeof(hdr), hdr) == sizeof(hdr))
            {
                if (IsValidCDHeader(hdr))
                {
                    DataOffset = 0x558C0;
                    SetSectorFormat(stMode2Form12336);
                    SectorRawSize = 0x920;
                    return TRUE;
                }
            }
        }
    } // if - 2336 file format

    return FALSE;
}

BOOL CISOImage::CheckForNCD(BOOL quiet /* = FALSE*/)
{
    char hdr[6];

    // check for NCD
    if (ReadDataByPos(0x1EE4E, sizeof(hdr), hdr) != sizeof(hdr))
        return FALSE;

    if (IsValidCDHeader(hdr))
    {
        // ok, it's NCD
        DataOffset = 0x16E4E;
        return TRUE;
    }

    return FALSE;
}

BOOL CISOImage::CheckForPDI(BOOL quiet /* = FALSE*/)
{
    char hdr[6];

    // check for PDI
    if (ReadDataByPos(0x8130, sizeof(hdr), hdr) != sizeof(hdr))
        return FALSE;

    if (IsValidCDHeader(hdr))
    {
        // ok, it's PDI
        DataOffset = 0x130;
        return TRUE;
    }

    return FALSE;
}

BOOL CISOImage::CheckForECDC(BOOL quiet /* = FALSE*/)
{
    char hdr[6];

    // check for ISO from Easy CD Creator
    // Easy CD Creator inserts headers separating sectors into the ISO file, but "incorrectly" (they are all zeros),
    // so the CheckSectorType function cannot detect anything
    if (ReadDataByPos(0x9318, sizeof(hdr), hdr) != sizeof(hdr))
        return FALSE;

    if (IsValidCDHeader(hdr))
    {
        // ok, it's Easy CD Creator
        DataOffset = 0x0;
        SetSectorFormat(stMode2Form1);
        return TRUE;
    }

    return FALSE;
}

BOOL CISOImage::CheckForC2D(BOOL quiet /* = FALSE*/)
{
    char hdr[6];

    // check for ISO from WinOnCD
    if (ReadDataByPos(0x28000, sizeof(hdr), hdr) != sizeof(hdr))
        return FALSE;

    if (IsValidCDHeader(hdr))
    {
        // ok, it's WinOnCD
        DataOffset = 0x20000;
        return TRUE;
    }
    else
    {
        if (ReadDataByPos(0x7F538, sizeof(hdr), hdr) != sizeof(hdr))
            return FALSE;
        else
        {
            if (IsValidCDHeader(hdr))
            {
                DataOffset = 0x76220;
                SetSectorFormat(stMode2Form1);
                return TRUE;
            }
        }
    }

    // check for Roxio Image Format 3.0
    if (ReadDataByPos(0x008120, sizeof(hdr), hdr) != sizeof(hdr))
        return FALSE;

    if (IsValidCDHeader(hdr))
    {
        // ok, it's WinOnCD
        DataOffset = 0x000120;
        return TRUE;
    }

    return FALSE;
}

// ****************************************************************************
// Support functions for CIF format

inline BOOL isRIFFHeader(RIFFHeader* hdr)
{
    if (strncmp(hdr->RIFF, "RIFF", 4) == 0)
        return TRUE;
    else
        return FALSE;
}

inline BOOL checkChunk(RIFFHeader* hdr, const char* id)
{
    if (strncmp(hdr->ID, id, 4) == 0)
        return TRUE;
    else
        return FALSE;
}

// Chunks are aligned to even positions
inline void alignOffset(LONGLONG* offset)
{
    if (*offset % 2 == 1)
        (*offset)++;
}

BOOL CISOImage::CheckForCIF(BOOL quiet /* = FALSE*/)
{
    char hdr[6];

    // RIFF header
    RIFFHeader riffHead;
    LONGLONG offset = 0x0000;

    // imag chunk
    if (ReadDataByPos(offset, sizeof(riffHead), &riffHead) != sizeof(riffHead))
        return FALSE;
    if (!isRIFFHeader(&riffHead) || !checkChunk(&riffHead, "imag"))
        return FALSE;
    offset += riffHead.Size + 8; // skip this block, sizeof(RIFF signature + chunk size) == 8
    alignOffset(&offset);

    // disc chunk
    if (ReadDataByPos(offset, sizeof(riffHead), &riffHead) != sizeof(riffHead))
        return FALSE;
    if (!isRIFFHeader(&riffHead) || !checkChunk(&riffHead, "disc"))
        return FALSE;
    offset += riffHead.Size + 8; // skip this block, sizeof(RIFF signature + chunk size) == 8
    alignOffset(&offset);

    // info chunk
    if (ReadDataByPos(offset, sizeof(riffHead), &riffHead) != sizeof(riffHead))
        return FALSE;
    if (!isRIFFHeader(&riffHead) || !checkChunk(&riffHead, "info"))
        return FALSE;
    offset += sizeof(riffHead) + 8; // sizeof(SectorHeader) == 8

    // it is highly probable that this is a CIF
    SetSectorFormat(stCIF);

    if (ReadDataByPos(offset + GetSectorOffset(16), sizeof(hdr), hdr) != sizeof(hdr))
        return FALSE;

    if (IsValidCDHeader(hdr))
    {
        // ok, it's CIF
        DataOffset = offset;
        return TRUE;
    }

    return FALSE;
}

BOOL CISOImage::CheckForCIF2332(BOOL quiet /* = FALSE*/)
{
    char hdr[6];

    if (ReadDataByPos(0x91C8, sizeof(hdr), hdr) == sizeof(hdr))
    {
        if (IsValidCDHeader(hdr))
        {
            // some obscure format from CloneCD 5.0
            DataOffset = 0;
            SetSectorFormat(stCIF);
            SectorRawSize = 0x91C; // special format - override settings from SetSectorFormat
            return TRUE;
        }
    } // if - 2332 file format

    return FALSE;
}

BOOL CISOImage::CheckForXbox(BOOL quiet /* = FALSE*/)
{
    char hdr1[0x14];
    char hdr2[0x14];

    if (ReadDataByPos(0x10000, sizeof(hdr1), hdr1) == sizeof(hdr1) &&
        ReadDataByPos(0x107ec, sizeof(hdr2), hdr2) == sizeof(hdr2))
    {
        if (strncmp(hdr1, XBOX_DESCRIPTOR, 0x14) == 0 && strncmp(hdr2, XBOX_DESCRIPTOR, 0x14) == 0)
        {
            DataOffset = 0;
            SetSectorFormat(stISO);
            return TRUE;
        }
    }

    return FALSE;
}

BOOL CISOImage::CheckForMDF(BOOL quiet /* = FALSE*/)
{
    // check sync header
    char sync_hdr[12];
    if (ReadDataByPos(0x0, sizeof(sync_hdr), sync_hdr) == sizeof(sync_hdr) &&
        memcmp(sync_hdr, SYNC_HEADER, 12) == 0)
    {
        if (ReadDataByPos(2352, sizeof(sync_hdr), sync_hdr) == sizeof(sync_hdr))
        {
            if (memcmp(sync_hdr, SYNC_HEADER_MDF, 12) == 0)
            {
                DataOffset = 0;
                SectorRawSize = 0x990;
                // SetSectorFormat() already called no change needed
                return TRUE;
            }
            else if (memcmp(sync_hdr, SYNC_HEADER_MDF_AUDIO, 12) == 0)
            {
                DataOffset = 0;
                // set sector format
                SectorHeaderSize = 0;
                SectorRawSize = 0x990;
                SectorUserSize = 0x930;
                return TRUE;
            }
        }
    }

    return FALSE;
}

BOOL CISOImage::CheckForHFS(BOOL quiet /* = FALSE*/)
{
    // First check for Device Manager header
    CHFS::Block0 block0;

    if ((ReadDataByPos(GetSectorOffset(0), sizeof(block0), &block0) == sizeof(block0)) &&
        (block0.sbSig == HFS_DEVICE_SIGNATURE))
    {
        SetSectorFormat(stISO);
        SectorHeaderSize = 0;
        SectorUserSize = SectorRawSize = FromM16(block0.sbBlkSize);
        return TRUE;
    }

    // Check if dealing directly with a partition
    CHFS::HFSPlusVolumeHeader volHeader;

    if ((ReadDataByPos(GetSectorOffset(0) + 1024, sizeof(volHeader), &volHeader) == sizeof(volHeader)) &&
        ((volHeader.signature == kHFSPlusSigWord) || (volHeader.signature == HFS_PARTITION_HFS_SIGNATURE)))
    {
        SetSectorFormat(stISO);
        SectorHeaderSize = 0;
        SectorUserSize = SectorRawSize = 512;
        return TRUE;
    }

    return FALSE;
}

BOOL CISOImage::CheckForAPFS(BOOL quiet /* = FALSE*/)
{
    CAPFS::ContainerSuperblock superblock;

    if ((ReadDataByPos(GetSectorOffset(0) + 32, sizeof(superblock), &superblock) == sizeof(superblock)) &&
        (superblock.magic == APFS_CONTAINER_SUPERBLOCK_SIGNATURE))
    {
        SetSectorFormat(stISO);
        SectorHeaderSize = 0;
        SectorUserSize = SectorRawSize = FromM16(superblock.blocksize);
        return TRUE;
    }

    return FALSE;
}

//BOOL
//CISOImage::ReadSessionInfo(BOOL quiet/* = FALSE*/)
//{
//  if (!FileName)
//    return FALSE;
//
//  BOOL ret = FALSE;
//
//  int len = strlen(FileName);
//  char *fn = new char [len + 1];
//BUGBUG: test for fn == NULL
//  ZeroMemory(fn, len);
//  strcpy(fn, FileName);
//
//  // determine the extension
//  char *ext = strrchr(fn, '.');
//  if (ext != NULL) {   // ".cvspass" is extension in Windows
//
//BUGBUG: what if the extension "nrgXX" shows up? You would classify it as "nrg"
//    char extlwr[3];
//    strncpy(extlwr, ext + 1, 3);
//BUGBUG: strncpy() does not terminate the string, so _strlwr then overwrote the stack
//    _strlwr(extlwr);
//
//    if (strncmp(extlwr, "nrg", 3) == 0)
//      ret = ReadSessionNRG(quiet);
//    else if (strncmp(extlwr, "img", 3) == 0)
//    {
//      fn[strlen(fn) - 3] = '\0';
//      strcat(fn, "ccd");
//      ret = ReadSessionCCD(fn, quiet);
//    }
//    else if (strncmp(extlwr, "ccd", 3) == 0)
//      ret = ReadSessionCCD(fn, quiet);
//  }
//  else
//    ret = FALSE;
//
//  delete [] fn;
//
//  return ret;
//}

BOOL CISOImage::ReadSessionInfo(BOOL quiet /* = FALSE*/)
{
    CALL_STACK_MESSAGE2("CISOImage::ReadSessionInfo(%d)", quiet);

    if (!FileName)
        return FALSE;

    BOOL ret = FALSE;
    CcdMissing = FALSE; // feature 353: set by ReadSessionCCD

    char* fn = SalamanderGeneral->DupStr(FileName);
    if (fn != NULL)
    {
        char* ext = strrchr(fn, '.');
        if (ext != NULL) // ".cvspass" is extension in Windows
        {
            ext++;
            if (SalamanderGeneral->StrICmp(ext, "nrg") == 0)
                ret = ReadSessionNRG(quiet);
            else if (SalamanderGeneral->StrICmp(ext, "img") == 0)
            {
                strcpy(ext, "ccd");
                ret = ReadSessionCCD(fn, quiet);
            }
            //      else if (SalamanderGeneral->StrICmp(ext, "ccd") == 0)
            //        ret = ReadSessionCCD(fn, quiet);
        }
        SalamanderGeneral->Free(fn);
    }
    return ret;
}

BYTE CISOImage::GetHeaderSizeFromMode(ETrackMode mode, DWORD sectorRawSize)
{
    BYTE headerSize = 0;
    switch (mode)
    {
    case mMode1:
        if (sectorRawSize == 0x930)
            headerSize = 16;
        else if (sectorRawSize == 0x808)
            headerSize = 8;
        else if (sectorRawSize == 0x91C)
            headerSize = 8;
        else
            headerSize = 0;
        break;

    case mMode2:
        if (sectorRawSize == 0x920)
            headerSize = 8;
        else if (sectorRawSize == 0x930)
            headerSize = 24;
        else if (sectorRawSize == 0x990)
            headerSize = 16;
        else
            headerSize = 0;

        break;
    } // switch

    return headerSize;
}

LONGLONG CISOImage::GetCurrentTrackEnd(int trackno)
{
    DWORD loSize, hiSize;
    LONGLONG size, start;

    loSize = File->GetFileSize(&hiSize);
    if (INVALID_FILE_SIZE == loSize)
    {
        return 0xFFFFFFFFFFFFFFFF;
    }
    size = ((LONGLONG)hiSize << 32) | loSize;
    start = Tracks[trackno]->Start;
    int i;
    for (i = 0; i < Tracks.Count; i++)
    {
        if (i == trackno)
            continue;
        LONGLONG tmp = Tracks[i]->Start - Tracks[0]->Start;

        if ((tmp > start) && (tmp < size))
        {
            size = tmp;
        }
    }

    return size - start;
}

void CISOImage::SetTrackParams(int trackno)
{
    CALL_STACK_MESSAGE2("CISOImage::SetTrackParams(%d)", trackno);

    Track* track = Tracks[trackno];
    if (track == NULL)
        return;

    ExtentOffset = track->ExtentOffset;
    DataOffset = track->Start;
    DataEnd = track->End;
    SectorRawSize = track->SectorSize;
    SectorHeaderSize = track->SectorHeaderSize;
}

BOOL CISOImage::Open(const char* fileName, BOOL quiet /* = FALSE*/)
{
    CALL_STACK_MESSAGE3("CISOImage::Open(%s, %d)", fileName, quiet);

    if (!fileName)
        return FALSE;

    // remember the name of the file being opened
    if ((FileName = new char[strlen(fileName) + 1]) == NULL)
        return Error(IDS_INSUFFICIENT_MEMORY, quiet);

    strcpy(FileName, fileName);

    // 'fileName' is the image path from the interface: UTF-8 since interface 104 -> W API
    HANDLE hFile = CreateFileU8(fileName, GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING, 0);
    if (hFile == INVALID_HANDLE_VALUE)
    {
        char errStr[MAX_PATH];

        DWORD openErr = GetLastError(); // before LoadStr can change it
        // feature 097: bounded - 'fileName' may be longer than the buffer
        if (_snprintf_s(errStr, _TRUNCATE, LoadStrU8(IDS_CANT_OPEN_FILE), fileName) < 0)
        { // cut: drop a UTF-8 sequence the cut has torn - a complete last character stays
            // (the rule of the core's SalU8TrimIncompleteTail, which a plug-in cannot link)
            int len = (int)strlen(errStr);
            int n = len;
            while (n > 0 && ((unsigned char)errStr[n - 1] & 0xC0) == 0x80)
                n--; // back over the continuation bytes
            if (n > 0)
            {
                unsigned char lead = (unsigned char)errStr[n - 1];
                if (lead >= 0xC0 && len - (n - 1) < (lead >= 0xF0 ? 4 : (lead >= 0xE0 ? 3 : 2)))
                    errStr[n - 1] = 0; // fewer bytes than the lead byte promises
            }
        }
        return Error(errStr, openErr, quiet);
    }
    DWORD l = 0;
    DWORD dwBytesRead;
    LONG posHi = -1; // Upper part of -512

    // NOTE: DMG might be uncompressed disk image not containing some (zero-filled) blocks
    // -> It is wrong to parse files starting with 'ER' as HFS+, we must check for DMG footer!
    SetFilePointer(hFile, -512, &posHi, FILE_END);
    ReadFile(hFile, &l, 4, &dwBytesRead, NULL);
    SetFilePointer(hFile, 0, NULL, FILE_BEGIN);
    if (DMG_FOOTER_MAGIC != l)
    {
        posHi = -1;
        SetFilePointer(hFile, -4, &posHi, FILE_END);
        ReadFile(hFile, &l, 4, &dwBytesRead, NULL);
    }
    if ((DMG_FOOTER_MAGIC == l) || (DMG_FOOTER_ENCR == l))
    {
        CDMGFile* DMGFile = new CDMGFile(hFile, quiet);
        if (DMGFile && !DMGFile->IsOK())
        {
            // Error message already shown
            delete DMGFile;
            return FALSE;
        }
        File = DMGFile;
    }
    else
    {
        SetFilePointer(hFile, 0, NULL, FILE_BEGIN);
        ReadFile(hFile, &l, 4, &dwBytesRead, NULL);
        if (ISZ_HEADER_MAGIC == l)
        {
            CISZFile* ISZFile = new CISZFile(hFile, quiet);
            if (ISZFile && !ISZFile->IsOK())
            {
                // Error message already shown
                delete ISZFile;
                return FALSE;
            }
            File = ISZFile;
        }
        else
        {
            // If an error occured, CBufferedFile will complain soon...
            File = new CBufferedFile(hFile, GENERIC_READ);
        }
    }

    if (!File)
        return Error(IDS_INSUFFICIENT_MEMORY, quiet);

    File->GetFileTime(NULL, NULL, &LastWrite);

    int ret = ERR_OK;
    BOOL validISO = FALSE;
    try
    {
        if (ReadSessionInfo(quiet))
        {
            //
            int trk;
            for (trk = 0; trk < Tracks.Count; trk++)
            {
                if (Tracks[trk]->FSType != fsUnknown && Tracks[trk]->FSType != fsAudio)
                {
                    // if the track cannot be opened it is not a supported format and most likely contains data (e.g. on a video CD)
                    SetTrackParams(trk);
                    ret = DetectTrackFS(trk);
                    if (ret == ERR_CONTINUE)
                    {
                        Tracks[trk]->FSType = fsData;
                        // feature 334: no file system found and the track's sector 16 (where every file
                        // system the plug-in reads is looked for, as DetectTrackFS's bound) is not within the
                        // image - nothing of the track can be read; the listing marks it (salisotrack.h)
                        DWORD sizeHi;
                        DWORD sizeLo = File->GetFileSize(&sizeHi);
                        LONGLONG fileSize = ((LONGLONG)sizeHi << 32) | sizeLo;
                        BOOL outside = SalIsoTrackSectorOutside(GetSectorOffset(0x10), SectorUserSize, fileSize);
                        // feature 335: within the image, the track's content is lost to the listing too
                        // unless its sector 16 is a Mode 2 Form 2 sector (a Video CD's MPEG stream - no file
                        // system is ever there); the stored sector's sync, header and subheader decide - a
                        // read that fails or a track of user data only is not Form 2 (fails closed)
                        BOOL form2 = FALSE;
                        if (!outside)
                        {
                            unsigned char raw[24];
                            DWORD want = 0; // the bytes up to the end of the subheader
                            if (SectorRawSize >= 0x930)
                                want = 24; // a raw sector: sync, header, subheader
                            else if (SectorRawSize == 0x920)
                                want = 8; // a Mode 2 sector of 2336 bytes: subheader
                            if (want > 0)
                            {
                                // reviews 2, 3: every sector from 16 on within the track and the file (up to
                                // SAL_ISO_FORM2_STREAM_SECTORS) must be Form 2; none (sector 16 not in the track)
                                // = not a stream (salisotrack.h)
                                LONGLONG at = GetSectorOffset(0x10) - SectorHeaderSize;
                                int n = SalIsoForm2SectorsToCheck(at, SectorRawSize, DataOffset, DataEnd, fileSize);
                                form2 = n > 0;
                                int i;
                                for (i = 0; form2 && i < n; i++, at += SectorRawSize)
                                {
                                    DWORD got = ReadDataByPos(at, want, raw);
                                    form2 = SalIsoSectorIsForm2(raw, got, SectorRawSize);
                                }
                            }
                        }
                        Tracks[trk]->RawLost = outside || !form2;
                        // feature 336: a stream the listing must find a file for (MarkUncoveredStreams)
                        Tracks[trk]->Form2Stream = !outside && form2;
                        ret = ERR_OK; // we can handle raw data tracks, so we turn the error into OK (what rascals we are :-D)
                    }
                    if (ret == ERR_TERMINATE)
                        throw ERR_TERMINATE;
                }
            }

            // find last 'readable' track
            int lastTrack = Tracks.Count - 1;
            while (lastTrack >= 0)
            {
                Track* track = Tracks[lastTrack];
                if (track->FSType != fsUnknown)
                {
                    if (track->FSType == fsAudio)
                        validISO = TRUE;
                    else
                    {
                        SetTrackParams(lastTrack);
                        if (CheckForISO(quiet))
                        {
                            validISO = TRUE;
                            break;
                        }
                        else if (CheckForHFS(quiet))
                        {
                            validISO = TRUE;
                            break;
                        }
                    }
                }

                lastTrack--;
            }

            LastTrack = lastTrack;

            // Patera 2008.11.15: (LastTrack == -1) replaced with !validISO to support AudioCD
            if (!validISO)
                ret = ERR_CONTINUE;
        }
        else
        {
            // if we don't know the CD info, set it up according to known information
            DataOffset = 0x0;

            DetectSectorType();
            // feature 353: sector 0 carries the CD sync pattern - a raw dump (as CloneCD writes it), before
            // a check below picks another layout
            BOOL rawStart = SectorType != stISO;
            SetSectorFormat(SectorType);
            // feature 354: a cooked image - 2048-byte sectors from offset 0, recognised by its sector 16
            BOOL cookedIso = FALSE;

            if (CheckForISO(quiet))
            {
                validISO = TRUE;
                cookedIso = !rawStart && SectorType == stISO && DataOffset == 0 && SectorRawSize == 0x800 &&
                            SectorHeaderSize == 0;
            }
            else if (CheckForNRG(quiet))
                validISO = TRUE;
            else if (CheckFor2336(quiet))
                validISO = TRUE;
            else if (CheckForNCD(quiet))
                validISO = TRUE;
            else if (CheckForPDI(quiet))
                validISO = TRUE;
            else if (CheckForECDC(quiet))
                validISO = TRUE;
            else if (CheckForCIF(quiet))
                validISO = TRUE;
            else if (CheckForC2D(quiet))
                validISO = TRUE;
            else if (CheckForCIF2332(quiet))
                validISO = TRUE;
            else if (CheckForXbox(quiet))
                validISO = TRUE;
            else if (CheckForMDF(quiet))
                validISO = TRUE;
            else if (CheckForHFS(quiet))
                validISO = TRUE;
            else if (CheckForAPFS(quiet))
                validISO = TRUE;

            if (validISO)
            {
                Track* track = new Track;
                track->Start = DataOffset;
                track->ExtentOffset = 0;

                DWORD hi;
                DWORD lo = File->GetFileSize(&hi);
                track->End = ((LONGLONG)hi << 32) | lo;
                track->SectorSize = (unsigned)SectorRawSize;
                track->SectorHeaderSize = (BYTE)SectorHeaderSize;

                switch (SectorType)
                {
                case stMode1:
                case stCIF:
                case stISO:
                    track->Mode = mMode1;
                    break;

                case stMode2Form1:
                case stMode2Form2:
                case stMode2Form12336:
                    track->Mode = mMode2;
                    break;
                } // switch

                LastTrack = 0;
                Tracks.Add(track);
                Session.Add(1);

                ret = DetectTrackFS(LastTrack);
                if (ret == ERR_CONTINUE)
                    track->FSType = fsData;
                if (ret == ERR_TERMINATE)
                    throw ERR_TERMINATE;

                // feature 353: a CloneCD .img whose .ccd could not be opened lists only the volume at its
                // sector 16 - a multi-session dump's first session; when the raw file holds room for a
                // later volume past that one (or the volume's size cannot be read), the listing is marked
                // incomplete, so a whole unpack fails and "Delete archive after unpacking" keeps the image
                // (the "Missing .CCD file" box already says the image could be incomplete)
                if (CcdMissing && rawStart)
                {
                    unsigned char desc[SAL_ISO_PVD_BYTES];
                    DWORD got = ReadDataByPos(GetSectorOffset(16), (DWORD)sizeof(desc), desc);
                    unsigned long long volumeSectors = 0;
                    BOOL known = SalIsoPvdVolumeSectors(desc, got, volumeSectors);
                    if (SalIsoNoCcdRestMarks(true, known != FALSE, volumeSectors, track->End, DataOffset,
                                             SectorRawSize))
                    {
                        TRACE_I("CISOImage::Open(): .ccd missing, a raw image of " << track->End
                                                                                   << " bytes past a volume of "
                                                                                   << volumeSectors << " sectors");
                        ListingLeftOut.SetIncomplete();
                    }
                }

                // feature 354: a cooked image lists only the volume at its sector 16 - a multi-session
                // image's first session; when the file holds room for a later volume past that one and the
                // rest is not zero bytes only (or cannot be shown to be: too long, not readable, the volume's
                // size unknown or more than the file), the listing is marked incomplete, so a whole unpack
                // fails and "Delete archive after unpacking" keeps the image
                if (cookedIso)
                {
                    unsigned char desc[SAL_ISO_PVD_BYTES];
                    DWORD got = ReadDataByPos(GetSectorOffset(16), (DWORD)sizeof(desc), desc);
                    unsigned long long volumeSectors = 0;
                    bool iso9660 = got >= 6 && IsValidCDHeader((char*)desc);
                    bool known = SalIsoPvdVolumeSectors(desc, got, volumeSectors);
                    long long checkFrom = 0, checkBytes = 0;
                    int decision = SalIsoCookedRestDecision(iso9660, known, volumeSectors, track->End, checkFrom,
                                                            checkBytes);
                    BOOL mark = decision == SAL_ISO_REST_MARK;
                    if (decision == SAL_ISO_REST_CHECK)
                    {
                        const DWORD piece = 0x10000;
                        unsigned char* buf = new unsigned char[piece];
                        mark = buf == NULL; // not checked - fails closed
                        while (!mark && checkBytes > 0)
                        {
                            DWORD want = checkBytes < (long long)piece ? (DWORD)checkBytes : piece;
                            DWORD read = ReadDataByPos(checkFrom, want, buf);
                            if (read != want || !SalIsoBytesAllZero(buf, read))
                                mark = TRUE;
                            checkFrom += want;
                            checkBytes -= want;
                        }
                        delete[] buf;
                    }
                    if (mark)
                    {
                        TRACE_I("CISOImage::Open(): a cooked image of " << track->End << " bytes past a volume of "
                                                                        << volumeSectors << " sectors, decision "
                                                                        << decision);
                        ListingLeftOut.SetIncomplete();
                    }
                }
            }
            else
            {
                ret = ERR_CONTINUE;
            }
        }
    }
    catch (int e)
    {
        ret = e;
    }

    if (!validISO)
    {
        BOOL bBootOrMBR = (ret == ERR_CONTINUE) ? CheckForBootSectorOrMBR() : false;

        File->Close(FileName, SalamanderGeneral->GetMainWindowHWND());
        if (ret == ERR_CONTINUE)
            Error(bBootOrMBR ? IDS_BOOT_OR_MBR : IDS_UNKNOWN_FILE_FORMAT, quiet);
    }

    return (ret == ERR_OK);
}

int CISOImage::DetectTrackFS(int track)
{
    CALL_STACK_MESSAGE2("CISOImage::DetectTrackFS(%d)", track);

    if (track < 0 || track >= Tracks.Count)
        return ERR_CONTINUE;

    ETrackFSType trackFSType = fsUnknown;

    int ret = ERR_OK;
    // starting with block 16
    DWORD block = 0x10;

    char* sector = new char[SectorUserSize]; // (2k)
    if (!sector)
    {
        Error(IDS_INSUFFICIENT_MEMORY, FALSE);
        return ERR_TERMINATE;
    }

    BOOL terminate = FALSE;
    BOOL isoDescriptors = FALSE;
    BOOL udfDescriptors = FALSE;
    BOOL hfsDescriptors = FALSE;
    BOOL apfsDescriptors = FALSE;

    if (ReadBlock(0, SectorUserSize, sector) == SectorUserSize)
    {
        if ((sector[0] == 'E') && (sector[1] == 'R'))
        { // Looks like Apple Device Manager Block0
            hfsDescriptors = TRUE;
        }
    }
    if (!hfsDescriptors & (ReadBlock(2, SectorUserSize, sector) == SectorUserSize))
    {
        if (((sector[0] == 'H') && (sector[1] == '+')) || ((sector[0] == 'B') && (sector[1] == 'D')))
        { // Looks like HFSPlus resp. HFSP partition
            hfsDescriptors = TRUE;
        }
        if (((sector[0] == 'N') && (sector[1] == 'X')) || ((sector[0] == 'S') && (sector[1] == 'B')))
        { // Looks like APFS partition
            apfsDescriptors = TRUE;
        }
    }

    DWORD fileSizeHi;
    LONGLONG fileSize = File->GetFileSize(&fileSizeHi);

    fileSize |= (LONGLONG)fileSizeHi << 32;

    // Try to find VolumeDescriptor
    // But do not read beyond file size. See empty.isz having just 50KB uncompressed
    while (!terminate && (GetSectorOffset(block) + SectorUserSize <= fileSize))
    {
        // Try to read a block
        if (ReadBlock(block, SectorUserSize, sector) != SectorUserSize)
        {
            // Something went wrong, probably EOF?
            break;
        }

        if (strncmp(sector + 1, "CD001", 5) == 0)
        {
            switch (sector[0])
            {
            case 0x00: // boot record
                Tracks[track]->Bootable = TRUE;
                break;

            case 0x01: // primary volume descriptor
                isoDescriptors = TRUE;
                break;

            case 0xff: // terminator
                break;
            } // switch
        } // if

        if (sector[0] == 0x00 && strncmp(sector + 1, "BEA01", 5) == 0)
        {
            udfDescriptors = TRUE;
        }
        else if (sector[0] == 0x00 && strncmp(sector + 1, "NSR02", 5) == 0 ||
                 sector[0] == 0x00 && strncmp(sector + 1, "NSR03", 5) == 0)
        {
            udfDescriptors = TRUE;
        }
        else if (sector[0] == 0x00 && strncmp(sector + 1, "TEA01", 5) == 0)
        {
        }

        block++;

        // Just to make sure we don't read in a too big file, stop after 128 sectors.
        if (block > 128)
            break;
    }

    // detecting XBOX
    BOOL xboxDescriptors = FALSE;

    if (GetSectorOffset(0x20) + SectorUserSize <= fileSize)
    {
        // Try to read a block
        if (ReadBlock(0x20, SectorUserSize, sector) == SectorUserSize)
        {
            if (strncmp(sector, XBOX_DESCRIPTOR, 0x14) == 0 &&
                strncmp(sector + 0x7ec, XBOX_DESCRIPTOR, 0x14) == 0)
            {
                xboxDescriptors = TRUE;
            }
        }
    }

    if (isoDescriptors)
    {
        if (udfDescriptors)
        {
            if (hfsDescriptors)
                trackFSType = fsUDF_ISO9660_HFS;
            else if (apfsDescriptors)
                trackFSType = fsUDF_ISO9660_APFS;
            else
                trackFSType = fsUDF_ISO9660;
        }
        else if (xboxDescriptors)
            trackFSType = fsXbox;
        else if (hfsDescriptors)
            trackFSType = fsISO9660_HFS;
        else if (apfsDescriptors)
            trackFSType = fsISO9660_APFS;
        else
            trackFSType = fsISO9660;
    }
    else
    {
        if (udfDescriptors)
        {
            if (hfsDescriptors)
                trackFSType = fsUDF_HFS;
            else if (apfsDescriptors)
                trackFSType = fsUDF_APFS;
            else
                trackFSType = fsUDF;
        }
        else if (xboxDescriptors)
            trackFSType = fsXbox;
        else if (hfsDescriptors)
            trackFSType = fsHFS;
        else if (apfsDescriptors)
            trackFSType = fsAPFS;
        else
            ret = ERR_CONTINUE;
    }

    Tracks[track]->FSType = trackFSType;

    delete[] sector;

    return ret;
}

BOOL CISOImage::OpenTrack(int track, BOOL quiet)
{
    CALL_STACK_MESSAGE3("CISOImage::OpenTrack(%d, %d)", track, quiet);

    if (track < 0 || track >= Tracks.Count)
        return FALSE;

    // we want to open a track that is already open. We don't have to ;)
    if (OpenedTrack == track)
        return TRUE;

    BOOL ret = FALSE;
    if (Tracks[track]->FileSystem == NULL)
    {
        CUnISOFSAbstract* fileSystem = NULL;

        switch (Tracks[track]->FSType)
        {
        case fsAudio:
            Tracks[track]->FileSystem = new CAudio(this, track);
            break;

        case fsISO9660:
            SetTrackParams(track);
            fileSystem = new CISO9660(this, ExtentOffset);
            break;

        case fsUDF_ISO9660:
        case fsUDF_ISO9660_HFS:
        case fsISO9660_HFS:
        case fsUDF_HFS:
        case fsUDF_ISO9660_APFS:
        case fsISO9660_APFS:
        case fsUDF_APFS:
        {
            ETrackFSType t = Tracks[track]->FSType;
            SetTrackParams(track);
            // feature 330: the parts the descriptors declare - one that does not open marks the listing
            BOOL hasISO = t == fsUDF_ISO9660 || t == fsUDF_ISO9660_HFS || t == fsISO9660_HFS ||
                          t == fsUDF_ISO9660_APFS || t == fsISO9660_APFS;
            BOOL hasUDF = t == fsUDF_ISO9660 || t == fsUDF_ISO9660_HFS || t == fsUDF_HFS ||
                          t == fsUDF_ISO9660_APFS || t == fsUDF_APFS;
            fileSystem = new CUDFISO(this, ExtentOffset, hasISO, hasUDF);
            break;
        }

        case fsAPFS:
            Error(IDS_UNSUPPORTED_APFS, quiet);
            break;

        case fsHFS:
            SetTrackParams(track);
            fileSystem = new CHFS(this);
            break;

        case fsUDF:
            SetTrackParams(track);
            fileSystem = new CUDF(this, ExtentOffset, track);
            break;

        case fsXbox:
            SetTrackParams(track);
            fileSystem = new CXDVDFS(this, ExtentOffset);
            break;

        case fsData:
            SetTrackParams(track);
            fileSystem = new CRawFS(this, ExtentOffset);
            break;
        } // switch

        if (fileSystem != NULL)
        {
            if (fileSystem->Open(quiet))
                Tracks[track]->FileSystem = fileSystem;
            else
                delete fileSystem;
        }
    }
    else
    {
        SetTrackParams(track);
    }

    if (Tracks[track]->FileSystem != NULL)
    {
        OpenedTrack = track;
        ret = TRUE;
    }

    return ret;
}

DWORD
CISOImage::ReadBlock(DWORD block, DWORD size, void* data)
{
    SLOW_CALL_STACK_MESSAGE4("CISOImage::ReadBlock(%u, %u, 0x%p)", block, size, data);

    char sectorStat[0x8000];
    char* sector = SectorUserSize <= sizeof(sectorStat) ? sectorStat : new char[SectorUserSize]; // cannot fail (see allochan.* in Salamander)

    BYTE* end = (BYTE*)data;
    DWORD remain = size;
    while (remain > 0)
    {
        if (ReadDataByPos(GetSectorOffset(block), SectorUserSize, sector) != SectorUserSize)
        {
            if (sector != sectorStat)
                delete[] sector;

            return 0;
        }

        if (remain > SectorUserSize)
        {
            memcpy(end, sector, SectorUserSize);
            end += SectorUserSize;
            remain -= SectorUserSize;
        }
        else
        {
            memcpy(end, sector, remain);
            end += remain;
            remain = 0;
        }
        block++;
    }

    if (sector != sectorStat)
        delete[] sector;

    return size;
}

BYTE CISOImage::GetTrackFromExtent(DWORD extent)
{
    CALL_STACK_MESSAGE2("CISOImage::GetTrackFromExtent(%u)", extent);

    // feature 336: the rule is shared with MarkUncoveredStreams (salisotrack.h)
    return (BYTE)SalIsoTrackOfExtent(Tracks.Count, extent, [this](int t) -> unsigned long
                                     { return Tracks[t]->ExtentOffset; });
}

BOOL CISOImage::ListDirectory(char* path, int session, CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    BOOL ret = FALSE;
    if (OpenedTrack >= 0 && OpenedTrack < Tracks.Count)
        ret = Tracks[OpenedTrack]->FileSystem->ListDirectory(path, session, dir, pluginData);

    return ret;
}

void CISOImage::MarkTrack(int track, int outcome)
{
    if (track < 0 || track >= Tracks.Count)
        return;
    Track* t = Tracks[track];
    int kind = t->FSType == fsUnknown ? SAL_ISO_TRACK_UNKNOWN : t->FSType == fsAudio ? SAL_ISO_TRACK_AUDIO
                                                                                     : SAL_ISO_TRACK_DATA;
    if (SalIsoTrackMarksListing(kind, t->RawLost != FALSE, outcome))
    {
        TRACE_I("CISOImage::MarkTrack(): track " << track << " (outcome " << outcome << ") leaves the listing incomplete");
        ListingLeftOut.SetIncomplete();
    }
}

BOOL CISOImage::ListImage(CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    CALL_STACK_MESSAGE1("CISOImage::ListImage(, )");

    BOOL ret = ListTracks(dir, pluginData);
    // feature 336: a Form 2 stream no listed file starts in is in no listing - in every listing mode
    MarkUncoveredStreams(dir);
    return ret;
}

void CISOImage::NoteListedFileStarts(const CSalamanderDirectoryAbstract* dir, bool* covered,
                                     TDirectArray<SalIsoStreamSpan>& spans, const long long* trackSectors)
{
    // the listed tree, walked without recursion (a deep tree must not exhaust the stack)
    TDirectArray<const CSalamanderDirectoryAbstract*> pending(16, 16);
    pending.Add(dir);
    while (pending.IsGood() && pending.Count > 0)
    {
        const CSalamanderDirectoryAbstract* d = pending[pending.Count - 1];
        pending.Delete(pending.Count - 1);
        if (d == NULL)
            continue;
        int count = d->GetFilesCount();
        int i;
        for (i = 0; i < count; i++)
        {
            const CFileData* file = d->GetFile(i);
            // an audio track's virtual file has no position (NULL); only an ISO 9660 record's extent is
            // the disc address of the file's first sector (review 1: HFS+ gives a catalog record number,
            // UDF a partition-relative block)
            const CFilePos* fp = file != NULL ? (const CFilePos*)file->PluginData : NULL;
            if (fp == NULL)
                continue;
            int t = SalIsoFileStartTrack(Tracks.Count, fp->Extent, file->Size.Value, fp->Type == FS_TYPE_ISO9660,
                                         [this](int k) -> unsigned long
                                         { return Tracks[k]->ExtentOffset; });
            if (t < 0)
                continue;
            covered[t] = true;
            // feature 337: the sectors the unpack reads of the stream (salisotrack.h)
            SalIsoStreamSpan span;
            span.Track = t;
            if (Tracks[t]->Form2Stream &&
                SalIsoFileSectorSpan(fp->Extent, file->Size.Value, Tracks[t]->ExtentOffset, trackSectors[t],
                                     &span.First, &span.End))
                spans.Add(span);
        }
        count = d->GetDirsCount();
        for (i = 0; i < count; i++)
            pending.Add(d->GetSalDir(i));
    }
    if (!pending.IsGood() || !spans.IsGood())
    {
        // out of memory: the walk is incomplete - no stream counts as covered (fails closed)
        int t;
        for (t = 0; t < Tracks.Count; t++)
            covered[t] = false;
    }
}

void CISOImage::MarkUncoveredStreams(const CSalamanderDirectoryAbstract* dir)
{
    BOOL anyStream = FALSE;
    int track;
    for (track = 0; track < Tracks.Count; track++)
        anyStream = anyStream || Tracks[track]->Form2Stream;
    if (!anyStream)
        return;

    bool* covered = new bool[Tracks.Count];
    long long* sectors = new long long[Tracks.Count];
    if (covered == NULL || sectors == NULL)
    {
        ListingLeftOut.SetIncomplete(); // nothing can be checked: fails closed
        delete[] covered;
        delete[] sectors;
        return;
    }
    // feature 337: the stored sectors of each stream track, a last one stored in part included (a wrong
    // track-table end fails closed)
    DWORD sizeHi;
    DWORD sizeLo = File->GetFileSize(&sizeHi);
    LONGLONG fileSize = ((LONGLONG)sizeHi << 32) | sizeLo;
    // review 2: the last track reaches up to the image's sector data end (an NRG image's chunks, else the
    // file's end) - its track-table end may be too small as well
    LONGLONG dataEnd = ImageDataEnd > 0 && ImageDataEnd < fileSize ? ImageDataEnd : fileSize;
    for (track = 0; track < Tracks.Count; track++)
    {
        covered[track] = false;
        Track* t = Tracks[track];
        sectors[track] = t->Form2Stream ? SalIsoStreamTrackSectors(t->Start, t->End, track + 1 < Tracks.Count ? Tracks[track + 1]->Start : dataEnd,
                                                                   fileSize, t->SectorSize)
                                        : 0;
    }
    TDirectArray<SalIsoStreamSpan> spans(16, 16);
    if (dir != NULL)
        NoteListedFileStarts(dir, covered, spans, sectors);
    int merged = spans.IsGood() ? SalIsoMergeStreamSpans(spans.GetData(), spans.Count) : 0;
    for (track = 0; track < Tracks.Count; track++)
    {
        if (!Tracks[track]->Form2Stream)
            continue;
        if (SalIsoStreamTrackMarksListing(true, covered[track]))
        {
            TRACE_I("CISOImage::MarkUncoveredStreams(): no listed file starts in the Form 2 track " << track << " - the listing is incomplete");
            ListingLeftOut.SetIncomplete();
            continue;
        }
        // feature 337: the sectors no listed file reads must be empty gaps (at most SAL_ISO_STREAM_GAP_SECTORS)
        long long uncovered = SalIsoStreamUncovered(spans.GetData(), merged, track, sectors[track]);
        bool empty = uncovered >= 0 && uncovered <= SAL_ISO_STREAM_GAP_SECTORS &&
                     StreamGapsEmpty(track, spans.GetData(), merged, sectors[track]);
        if (SalIsoStreamGapsMark(sectors[track], uncovered, empty))
        {
            TRACE_I("CISOImage::MarkUncoveredStreams(): the listed files leave " << uncovered << " of " << sectors[track]
                                                                                 << " sectors of the Form 2 track " << track << " uncovered and not empty - the listing is incomplete");
            ListingLeftOut.SetIncomplete();
        }
    }
    delete[] covered;
    delete[] sectors;
}

BOOL CISOImage::StreamGapsEmpty(int track, const SalIsoStreamSpan* merged, int n, long long trackSectors)
{
    Track* t = Tracks[track];
    long long payloadAt = SalIsoForm2PayloadOffset(t->SectorSize);
    if (payloadAt < 0)
        return FALSE;
    unsigned char payload[SAL_ISO_FORM2_PAYLOAD];
    long long cursor = 0;
    long long first, end;
    while (SalIsoStreamNextGap(merged, n, track, trackSectors, &cursor, &first, &end))
    {
        long long s;
        for (s = first; s < end; s++)
        {
            DWORD got = ReadDataByPos(t->Start + s * t->SectorSize + payloadAt, sizeof(payload), payload);
            if (!SalIsoPayloadEmpty(payload, got))
            {
                TRACE_I("CISOImage::StreamGapsEmpty(): sector " << s << " of the Form 2 track " << track << " holds data no listed file reads");
                return FALSE;
            }
        }
    }
    return TRUE;
}

BOOL CISOImage::ListTracks(CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData)
{
    CALL_STACK_MESSAGE1("CISOImage::ListTracks(, )");

    // feature 222: a path part of up to MAX_PATH - 5 bytes + '\\' + a name of up to 3 * MAX_PATH
    // bytes (the core takes names of 255 UTF-16 units now) - the file systems append to it in place
    char path[4 * MAX_PATH + 2];
    ZeroMemory(&path, sizeof(path));

    if (Options.SessionAsDirectory && Session.Count > 1)
    {
        BOOL ret = TRUE;

        int firstSessionTrack = 0;
        int session;
        for (session = 0; session < Session.Count; session++)
        {
            sprintf(path, "\\Session %02d", session + 1);

            // feature 340: the session's count comes from the image (an NRG SINF chunk, unsigned): the
            // session gets at most the tracks left in the track table; a count that does not fit marks
            // the listing incomplete (a whole unpack fails, the image is kept)
            bool fits;
            int trackCount = SalIsoSessionTracks(firstSessionTrack, (unsigned int)Session[session], Tracks.Count, fits);
            if (!fits)
            {
                TRACE_I("CISOImage::ListTracks(): session " << session + 1 << " counts " << (unsigned int)Session[session]
                                                            << " tracks, " << trackCount << " left in the track table");
                ListingLeftOut.SetIncomplete();
            }
            int lastSessionTrack = firstSessionTrack + trackCount;

            int track;
            for (track = firstSessionTrack; track < lastSessionTrack; track++)
            {
                // feature 334: a track that does not open or list, lies past the end of the image, an
                // audio track (never extracted) or an unknown one (never listed) marks the listing
                // incomplete (a whole unpack fails, the image is kept) - the box and the listing of the
                // other sessions stay as they were
                switch (Tracks[track]->FSType)
                {
                case fsAudio:
                    if (OpenTrack(track, TRUE))
                        MarkTrack(track, ListDirectory(path, session + 1, dir, pluginData) ? SAL_ISO_TRACK_LISTED : SAL_ISO_TRACK_LIST_FAILED);
                    else
                        MarkTrack(track, SAL_ISO_TRACK_NOT_OPENED);
                    break;

                case fsUnknown:
                    // nothing we can do about it
                    MarkTrack(track, SAL_ISO_TRACK_NOT_TRIED);
                    break;

                default:
                    if (OpenTrack(track, TRUE))
                        MarkTrack(track, ListDirectory(path, session + 1, dir, pluginData) ? SAL_ISO_TRACK_LISTED : SAL_ISO_TRACK_LIST_FAILED);
                    else
                    {
                        MarkTrack(track, SAL_ISO_TRACK_NOT_OPENED);
                        ret = FALSE;
                    }
                    break;
                } // switch
            } // for
            firstSessionTrack += trackCount;
        }
        // feature 334 (review 1): tracks no session count covers are left out of the listing
        int track;
        for (track = firstSessionTrack; track < Tracks.Count; track++)
            MarkTrack(track, SAL_ISO_TRACK_LEFT_OUT);

        if (!ret)
            Error(IDS_ERROR_OPENING_MULTISESSION);

        return TRUE;
    }
    else
    {
        int track;
        if (OpenTrack(LastTrack))
        {
            BOOL ret = ListDirectory(path, -1, dir, pluginData);
            // feature 334: only the last data track is listed (by design: its directory holds the earlier
            // sessions' files); an audio or unknown track (review 1: a data + audio disc lost its audio)
            // or a data track whose content is lost (past the end of the image; 335: a raw data track that
            // is not a Form 2 stream) still marks the listing incomplete
            // (review 2) in an image of one session that directory holds no other track: another data track
            // with a file system is left out; a raw data track in Form 2 sectors (fsData, a Video CD's MPEG
            // track) is not
            for (track = 0; track < Tracks.Count; track++)
            {
                if (track == LastTrack)
                    continue;
                BOOL leftOut = Session.Count <= 1 && Tracks[track]->FSType != fsData;
                MarkTrack(track, leftOut ? SAL_ISO_TRACK_LEFT_OUT : SAL_ISO_TRACK_NOT_TRIED);
            }
            return ret;
        }
        else
        {
            BOOL ret = FALSE;
            // feature 334: the last data track did not open - the tracks listed below are not all of the
            // image, so the listing is marked incomplete (a whole unpack fails, the image is kept); so is
            // each track tried below that does not open or list, and an audio track (LastTrack is -1 for
            // an audio CD: then this is the normal listing, marked for its audio tracks)
            if (LastTrack >= 0 && LastTrack < Tracks.Count)
                MarkTrack(LastTrack, SAL_ISO_TRACK_NOT_OPENED);
            // we also try to insert audio tracks if there are any
            for (track = 0; track < Tracks.Count; track++)
            {
                if (track == LastTrack)
                    continue;
                if (OpenTrack(track, TRUE))
                {
                    if (ListDirectory(path, -1, dir, pluginData))
                    {
                        ret = TRUE;
                        MarkTrack(track, SAL_ISO_TRACK_LISTED);
                    }
                    else
                        MarkTrack(track, SAL_ISO_TRACK_LIST_FAILED);
                }
                else
                    MarkTrack(track, SAL_ISO_TRACK_NOT_OPENED);
            } // for

            return ret;
        }
    }
}

//
int CISOImage::UnpackFile(CSalamanderForOperationsAbstract* salamander, const char* srcPath, const char* path,
                          const CFileData* fileData, DWORD& silent, BOOL& toSkip)
{
    CALL_STACK_MESSAGE6("CISOImage::UnpackFile(, %s, %s, %p, %u, %d)", srcPath, path, fileData, silent, toSkip);

    if (fileData == NULL)
        return UNPACK_ERROR;

    CFilePos* fp = (CFilePos*)fileData->PluginData;
    // is it virtual file ? (audio track)
    if (fp == NULL)
        return UNPACK_AUDIO_UNSUP;

    //  BYTE track = fp->Track;
    //  DWORD e = fp->Extent;
    BYTE track = GetTrackFromExtent(fp->Extent);
    /*
  char u[1024];
  sprintf(u, "CISOImage::UnpackFile(): opening track: %d, Extent: 0x%X", track, fp->Extent);
  TRACE_I(u);
*/
    if (!OpenTrack(track))
    {
        Error(IDS_UNKNOWN_TRACK_TYPE);
        return UNPACK_ERROR;
    }

    // 'FileName' is the image path from the interface (UTF-8, may be long) and 'srcPath'
    // a UTF-8 path inside the image - neither is bounded by MAX_PATH (interface 104)
    int nameInArcSize = (int)strlen(FileName) + 2 + (int)strlen(srcPath) + 2 +
                        (int)strlen(fileData->Name) + 1;
    char* nameInArc = (char*)malloc(nameInArcSize);
    if (nameInArc == NULL)
        return Error(IDS_INSUFFICIENT_MEMORY);
    strcpy(nameInArc, FileName);
    SalamanderGeneral->SalPathAppend(nameInArc, srcPath, nameInArcSize);
    SalamanderGeneral->SalPathAppend(nameInArc, fileData->Name, nameInArcSize);

    CUnISOFSAbstract* fileSystem = Tracks[track]->FileSystem;
    int ret;
    if (fileSystem != NULL)
        ret = fileSystem->UnpackFile(salamander, srcPath, path, nameInArc, fileData, silent, toSkip);
    else
        ret = Error(IDS_INTERNAL_PLUGIN_ERROR);
    free(nameInArc);
    return ret;
}

BOOL CISOImage::UnpackDir(const char* dirName, const CFileData* fileData)
{
    CALL_STACK_MESSAGE3("CISOImage::UnpackDir(%s, %p)", dirName, fileData);

    if (!SalamanderGeneral->CheckAndCreateDirectory(dirName))
        return UNPACK_ERROR;

    DWORD attrs = fileData->Attr;

    // set attrs to dir
    if (Options.ClearReadOnly) // clear ReadOnly Attribute if needed
        attrs &= ~FILE_ATTRIBUTE_READONLY;

    if (!SetFileAttributesU8(dirName, attrs)) // 'dirName' is UTF-8 (interface 104) -> W API
    {
        DWORD err = GetLastError();
        Error(LoadStrU8(IDS_CANT_SET_ATTRS), err);
    }

    return UNPACK_OK;
}

// feature 338: the wide target path of a file of a whole unpack, built as the readers build it (the
// folder + the file's name made safe, AppendSafeName); NULL when it cannot be built (the reader then
// fails on it too)
static WCHAR* WholeUnpackTargetW(const char* path, const char* name)
{
    CU8PathBuf target;
    if (!target.IsOk())
        return NULL;
    lstrcpyn(target, path, U8_MAX_PATH);
    if (!AppendSafeName(target, name, U8_MAX_PATH))
        return NULL;
    return SplU8ToWExtAlloc(target);
}

int CISOImage::ExtractAllItems(CSalamanderForOperationsAbstract* salamander, char* srcPath,
                               CSalamanderDirectoryAbstract const* dir, const char* mask,
                               char* path, int pathBufSize, DWORD& silent, BOOL& toSkip,
                               CSalIsoWholeUnpackTally& tally, CSalIsoWrittenFiles& written)
{
    CALL_STACK_MESSAGE7("CISOImage::ExtractAllItems(, %s, , %s, %s, %d, %u, %d, , )", srcPath, mask, path, pathBufSize, silent, toSkip);

    int count = dir->GetFilesCount();
    int i;
    for (i = 0; i < count; i++)
    {
        CFileData const* file = dir->GetFile(i);
        //    TRACE_I("EnumAllItems(): file: " << path << (path[0] != 0 ? "\\" : "") << file->Name);
        salamander->ProgressDialogAddText(file->Name, TRUE); // delayedPaint==TRUE, so we do not slow things down

        salamander->ProgressSetSize(CQuadWord(0, 0), CQuadWord(-1, -1), TRUE);
        salamander->ProgressSetTotalSize(file->Size + CQuadWord(1, 0), CQuadWord(-1, -1));

        if (SalamanderGeneral->AgreeMask(file->Name, mask, file->Ext[0] != 0))
        {
            // feature 338: does the file land on one this unpack already wrote (two records of one
            // name, names equal for the file system)? The overwrite question stays the core's; a
            // write over such a file fails the unpack - one of the two exists only in the image
            WCHAR* wTarget = WholeUnpackTargetW(path, file->Name);
            BOOL overOwn = FALSE;
            if (wTarget != NULL && GetFileAttributesW(wTarget) != INVALID_FILE_ATTRIBUTES)
            {
                CSalFileIdentity id;
                BOOL read = SalGetFileIdentityW(wTarget, FALSE, &id);
                overOwn = written.WrittenBefore(read, id);
            }

            //      SalamanderGeneral->CheckAndCreateDirectory(path);
            int ret = UnpackFile(salamander, srcPath, path, file, silent, toSkip);
            if (!tally.File(ret) || !salamander->ProgressAddSize(1, TRUE))
            {
                tally.Cancelled = TRUE;
                free(wTarget);
                return UNPACK_CANCEL;
            }
            if (ret == UNPACK_OK)
            {
                if (overOwn)
                    tally.WroteOverOwn = TRUE;
                CSalFileIdentity id;
                BOOL read = wTarget != NULL && SalGetFileIdentityW(wTarget, FALSE, &id);
                if (!read)
                    SalFileIdentityClear(&id);
                written.Note(read, id);
            }
            free(wTarget);
        }
    } // for

    count = dir->GetDirsCount();
    int pathLen = (int)strlen(path);
    int srcPathLen = (int)strlen(srcPath);
    int j;
    for (j = 0; j < count; j++)
    {
        CFileData const* file = dir->GetDir(j);
        //    TRACE_I("EnumAllItems(): directory: " << path << (path[0] != 0 ? "\\" : "") << file->Name);
        if (!SalamanderGeneral->SalPathAppend(path, file->Name, pathBufSize))
        {
            Error(IDS_ERR_TOO_LONG_NAME);
            tally.Cancelled = TRUE;
            return UNPACK_CANCEL;
        }
        int dirRet = UnpackDir(path, file);
        if (dirRet == UNPACK_CANCEL)
        {
            tally.Cancelled = TRUE;
            return UNPACK_CANCEL;
        }
        if (dirRet != UNPACK_OK)
            tally.NotWhole = TRUE; // feature 338: the folder could not be created - its contents cannot be either

        CSalamanderDirectoryAbstract const* subDir = dir->GetSalDir(j);
        SalamanderGeneral->SalPathAppend(srcPath, file->Name, ISO_MAX_PATH_LEN);
        if (ExtractAllItems(salamander, srcPath, subDir, mask, path, pathBufSize, silent, toSkip, tally, written) == UNPACK_CANCEL)
            return UNPACK_CANCEL;

        srcPath[srcPathLen] = '\0';
        path[pathLen] = '\0';
    }

    return UNPACK_OK;
}

CISOImage::Track*
CISOImage::GetTrack(int track)
{
    CALL_STACK_MESSAGE2("CISOImage::GetTrack(%d)", track);

    if (track >= 0 && track < Tracks.Count) // feature 331: was <= (an index equal to the count)
        return Tracks[track];
    else
        return NULL;
}
