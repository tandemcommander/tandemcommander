// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"
#include "dbg.h"

#include "isoimage.h"
#include "audio.h"
#include "../../common/salnrgcdtext.h" // feature 331: the NRG chunks' bounds

#include "uniso.h"
#include "uniso.rh"
#include "uniso.rh2"
#include "lang\lang.rh"

// Nero Header
// for reading information about sessions/tracks in .NRG
struct NRGHeader
{
    char ID[4];
    DWORD Size;
};

struct DAOX
{
    DWORD Size;
    BYTE Data[0x10];
    BYTE FirstTrack;
    BYTE LastTrack;
};

// swaping macros

#define SWAPWORD(d) \
    (((d) & 0x00FF) << 8) | \
        (((d) & 0xFF00) >> 8)

#define SWAPDWORD(d) \
    (((d) & 0x000000FF) << 24) | \
        (((d) & 0x0000FF00) << 8) | \
        (((d) & 0x00FF0000) >> 8) | \
        (((d) & 0xFF000000) >> 24)

#define SWAPLONGLONG(l) \
    (((l) & 0x00000000000000FF) << 56) | \
        (((l) & 0x000000000000FF00) << 40) | \
        (((l) & 0x0000000000FF0000) << 24) | \
        (((l) & 0x00000000FF000000) << 8) | \
        (((l) & 0x000000FF00000000) >> 8) | \
        (((l) & 0x0000FF0000000000) >> 24) | \
        (((l) & 0x00FF000000000000) >> 40) | \
        (((l) & 0xFF00000000000000) >> 56)

static WORD
getWord(void* var)
{
    WORD w;
    memcpy(&w, var, 2);
    return SWAPWORD(w);
}

static DWORD
getDWord(void* var)
{
    DWORD d;
    memcpy(&d, var, 4);
    return SWAPDWORD(d);
}

static LONGLONG
getLongLong(void* var)
{
    LONGLONG l;
    memcpy(&l, var, 8);
    return SWAPLONGLONG(l);
}

static void SetTrackTypeMode(CISOImage::Track* track, int type)
{
    CALL_STACK_MESSAGE2("SetTrackTypeMode(, %d)", type);

    if (type == 0x07)
    {
        track->FSType = CISOImage::fsAudio;
        track->Mode = CISOImage::mNone;
    }
    else if (type == 0x00 || type == 0x05)
    {
        track->FSType = CISOImage::fsISO9660;
        track->Mode = CISOImage::mMode1;
    }
    else if (type & 0x02)
    {
        track->FSType = CISOImage::fsISO9660;
        track->Mode = CISOImage::mMode2;
    }
    else
    {
        track->FSType = CISOImage::fsUnknown;
        track->Mode = CISOImage::mNone;
    }
}

static BOOL
ReadHeader(CFile& file, NRGHeader* header)
{
    CALL_STACK_MESSAGE2("ReadHeader(, %p)", header);

    DWORD read;

    BYTE hdr[8];
    if (!file.Read(hdr, sizeof(hdr), &read, NULL, NULL))
        return FALSE;

    if (read != sizeof(hdr))
        return FALSE;

    memcpy(header->ID, hdr, 4);
    header->Size = getDWord(hdr + 4);

    return TRUE;
}

static BOOL
readCUEX(CFile& file, NRGHeader* header, CISOImage* iso)
{
    CALL_STACK_MESSAGE3("readCUEX(, %p, %p)", header, iso);

    // feature 350: the chunk's size comes from the image - (Size - 16) / 16 underflowed for a chunk
    // under 16 bytes (268 million entries) and the reader built a track from every 16 bytes up to the
    // end of the file. Now the chunk is read only when it lies within the image (else skipped like an
    // unknown chunk, as readCDTX), it gives only the whole entries it holds, no track comes from a
    // short read, a chunk of more entries than a CD has tracks is skipped (review 1), and the next
    // chunk header is read right after the chunk
    DWORD fileSizeHi;
    DWORD fileSizeLo = file.GetFileSize(&fileSizeHi);
    __int64 pos = file.Seek(0, FILE_CURRENT);
    if (fileSizeLo == INVALID_FILE_SIZE || pos < 0 || // (as ReadSessionNRG)
        !SalNrgChunkFits((unsigned long long)pos, header->Size, ((unsigned long long)fileSizeHi << 32) | fileSizeLo))
    {
        file.Seek(header->Size, FILE_CURRENT);
        return FALSE;
    }

    DWORD read;
    unsigned long long entries = SalNrgCuexEntryCount(header->Size);
    if (!SalNrgCuexEntriesPlausible(entries))
    {
        // (review 1) more tracks than a CD holds - a damaged chunk lying within the image would still
        // build one track per 16 bytes of it: skipped like a chunk that does not fit, no track
        file.Seek(pos + header->Size, FILE_BEGIN);
        return FALSE;
    }
    if (header->Size >= SAL_NRG_CUEX_HEADER)
    {
        BYTE cuex_hdr[SAL_NRG_CUEX_HEADER];
        if (!file.Read(&cuex_hdr, sizeof(cuex_hdr), &read, NULL, NULL) || read != sizeof(cuex_hdr))
            return FALSE;
    }

    unsigned long long i;
    for (i = 0; i < entries; i++)
    {
        BYTE data[SAL_NRG_CUEX_ENTRY];
        if (!file.Read(&data, sizeof(data), &read, NULL, NULL) || read != sizeof(data))
            return FALSE;

        CISOImage::Track* track = new CAudioTrack;
        track->ExtentOffset = getDWord(data + 0x04);
        iso->AddTrack(track);
    } // for

    // the bytes after the last whole entry (a chunk under 16 bytes: all of it) are not entries
    if (file.Seek(pos + header->Size, FILE_BEGIN) == -1)
        return FALSE;

    return TRUE;
}

static BOOL
readDAOX(CFile& file, NRGHeader* header, CISOImage* iso)
{
    CALL_STACK_MESSAGE3("readDAOX(, %p, %p)", header, iso);

    DWORD read;

    BYTE daox_hdr[0x16];
    if (!file.Read(&daox_hdr, sizeof(daox_hdr), &read, NULL, NULL) || read != sizeof(daox_hdr))
        return FALSE;

    BYTE firstTrack = daox_hdr[0x14];
    BYTE lastTrack = daox_hdr[0x15];

    int i;
    for (i = firstTrack; i <= lastTrack; i++)
    {
        BYTE data[0x2A];
        if (!file.Read(&data, sizeof(data), &read, NULL, NULL) || read != sizeof(data))
            return FALSE;

        // feature 331: the track number comes from the image - an entry applies only to a track the
        // CUEX chunk added (0 gave GetTrack(-1) = NULL, count + 1 a pointer past the track table)
        if (!SalNrgDaoTrackInRange(i, iso->GetTrackCount()))
            continue;
        CISOImage::Track* track = iso->GetTrack(i - 1);
        if (track == NULL)
            continue;
        track->SectorSize = getWord(data + 0x0C);
        SetTrackTypeMode(track, data[0x0E]);
        track->Start = getLongLong(data + 0x1A);
        track->End = getLongLong(data + 0x22);
        track->SectorHeaderSize = CISOImage::GetHeaderSizeFromMode(track->Mode, track->SectorSize);
    } // for

    return TRUE;
}

static BOOL
readETNF(CFile& file, NRGHeader* header, CISOImage* iso)
{
    CALL_STACK_MESSAGE3("readETNF(, %p, %p)", header, iso);

    DWORD read;
    BYTE* data = new BYTE[header->Size];
    ZeroMemory(data, header->Size);

    if (!file.Read(data, header->Size, &read, NULL, NULL))
    {
        delete[] data;
        return FALSE;
    }

    int offset = 0;
    unsigned int i;
    for (i = 0; i < header->Size / 0x14; i++)
    {
        CISOImage::Track* track = new CISOImage::Track;

        // sector size
        if (data[offset + 0x0B] & 1)
            track->SectorSize = 0x920;
        else
            track->SectorSize = 0x800;

        track->Start = (LONGLONG)getDWord(data + offset + 0x00);
        track->End = track->Start + (LONGLONG)getDWord(data + offset + 0x04);
        SetTrackTypeMode(track, data[offset + 0x0B]);
        track->SectorHeaderSize = CISOImage::GetHeaderSizeFromMode(track->Mode, track->SectorSize);
        track->ExtentOffset = getDWord(data + offset + 0x0C);
        iso->AddTrack(track);

        offset += 0x14;
    }

    delete[] data;
    return TRUE;
}

static BOOL
readETN2(CFile& file, NRGHeader* header, CISOImage* iso)
{
    CALL_STACK_MESSAGE3("readETN2(, %p, %p)", header, iso);

    DWORD read;
    BYTE* data = new BYTE[header->Size];
    ZeroMemory(data, header->Size);

    if (!file.Read(data, header->Size, &read, NULL, NULL))
    {
        delete[] data;
        return FALSE;
    }

    CISOImage::Track* track = new CISOImage::Track;
    track->SectorSize = 2048;
    track->FSType = CISOImage::fsISO9660;
    track->Mode = CISOImage::mMode1;
    track->SectorHeaderSize = CISOImage::GetHeaderSizeFromMode(CISOImage::mMode1, track->SectorSize);
    track->Start = getLongLong(data + 0x00);
    track->End = getLongLong(data + 0x08);
    track->ExtentOffset = 0;
    iso->AddTrack(track);

    delete[] data;
    return TRUE;
}

static BOOL
readCDTX(CFile& file, NRGHeader* header, CISOImage* iso)
{
    CALL_STACK_MESSAGE3("readCDTX(, %p, %p)", header, iso);

    // feature 331: the chunk's size comes from the image - it is used only when the chunk lies within
    // the image (the buffer was Size + 1 + tracks in 32-bit arithmetic, which wraps near 4 GiB), else
    // the chunk is skipped like an unknown one and the tracks keep "Audio Track NN"
    DWORD fileSizeHi;
    DWORD fileSizeLo = file.GetFileSize(&fileSizeHi);
    __int64 pos = file.Seek(0, FILE_CURRENT);
    if (fileSizeLo == INVALID_FILE_SIZE || pos < 0 || // (as ReadSessionNRG)
        !SalNrgChunkFits((unsigned long long)pos, header->Size, ((unsigned long long)fileSizeHi << 32) | fileSizeLo) ||
        header->Size == 0)
    {
        file.Seek(header->Size, FILE_CURRENT);
        return FALSE;
    }

    unsigned char* data = (unsigned char*)malloc(header->Size);
    if (data == NULL)
    {
        file.Seek(header->Size, FILE_CURRENT);
        return FALSE;
    }

    DWORD read;
    if (!file.Read(data, header->Size, &read, NULL, NULL) || read != header->Size)
    {
        free(data);
        return FALSE;
    }

    // the text of the blocks of 12 bytes (after 4 bytes of flags, each followed by 6 other bytes),
    // gathered in place within the chunk; then the volume label and one label per track, each taken
    // by its length (a label without a terminator ends at the text's end)
    size_t textLen = SalNrgCdTextGather(data, header->Size, data);
    size_t next = 0, start, len;
    int j;
    for (j = -1; j < iso->GetTrackCount() && SalNrgCdTextNext(data, textLen, next, start, len); j++)
    {
        char* label = (char*)malloc(len + 1);
        if (label == NULL)
            break;
        memcpy(label, data + start, len);
        label[len] = 0;
        if (j < 0)
            iso->SetLabel(label);
        else
            iso->GetTrack(j)->SetLabel(label);
        free(label);
    }

    free(data);
    return TRUE;
}

static BOOL
readSINF(CFile& file, NRGHeader* header, CISOImage* iso)
{
    CALL_STACK_MESSAGE3("readSINF(, %p, %p)", header, iso);

    DWORD read;
    DWORD count;

    if (!file.Read(&count, sizeof(count), &read, NULL, NULL))
        return FALSE;

    count = SWAPDWORD(count);
    iso->AddSessionTracks(count);

    return TRUE;
}

static BOOL
ReadNRGRoot(CFile& file, CISOImage* iso, LONGLONG* chunks)
{
    CALL_STACK_MESSAGE2("ReadNRGRoot(, %p)", iso);

    BOOL ret = FALSE;

    // check header
    NRGHeader header;
    DWORD read;

    if (!file.Read(&header.ID, sizeof(header.ID), &read, NULL, NULL))
        return FALSE;

    if ((read != 4) || (strncmp(header.ID, "NER5", 4) != 0))
        return FALSE;

    // read offset
    LONGLONG offset;
    if (!file.Read(&offset, sizeof(offset), &read, NULL, NULL))
        return FALSE;
    if (read != 8)
        return FALSE;

    offset = getLongLong(&offset);
    // feature 337 (review 2): the chunks follow the sector data - where the last track's data ends at most
    *chunks = offset;

    // set file pointer to start of session information
    if (file.Seek(offset, FILE_BEGIN) == -1)
        return FALSE;

    do
    {
        if (!ReadHeader(file, &header))
            return FALSE;

        if (strncmp(header.ID, "CUEX", 4) == 0)
            readCUEX(file, &header, iso);
        else if (strncmp(header.ID, "DAOX", 4) == 0)
            readDAOX(file, &header, iso);
        else if (strncmp(header.ID, "SINF", 4) == 0)
            readSINF(file, &header, iso);
        else if (strncmp(header.ID, "ETNF", 4) == 0)
            readETNF(file, &header, iso);
        else if (strncmp(header.ID, "ETN2", 4) == 0)
            readETN2(file, &header, iso);
        else if (strncmp(header.ID, "CDTX", 4) == 0)
            readCDTX(file, &header, iso);
        else if (file.Seek(header.Size, FILE_CURRENT) == -1)
            return FALSE;

    } while (strncmp(header.ID, "NER5", 4) != 0);

    return TRUE;
}

BOOL CISOImage::ReadSessionNRG(BOOL quiet /* = FALSE*/)
{
    CALL_STACK_MESSAGE2("CISOImage::ReadSessionNRG(%d)", quiet);

    DWORD fileSizeHi;
    DWORD fileSizeLo = File->GetFileSize(&fileSizeHi);
    if (INVALID_FILE_SIZE == fileSizeLo)
        return FALSE;

    LARGE_INTEGER pos;
    pos.QuadPart = (((LONGLONG)fileSizeHi) << 32) + fileSizeLo - 12;
    if (File->Seek(pos.QuadPart, FILE_BEGIN) == -1)
        return FALSE;

    LONGLONG chunks = -1;
    BOOL ret = ReadNRGRoot(*File, this, &chunks);
    ImageDataEnd = chunks;

    return ret;
}
