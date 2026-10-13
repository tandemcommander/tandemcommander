// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include <windows.h>
#include <windowsx.h>
#include <stdio.h>
#include <crtdbg.h>

#include "exif.h"
#include <libexif/exif-data.h>
#include <libexif/exif-loader.h>
#include <libexif/exif-utils.h>
#include <libjpeg/jpeg-data.h>
#include "../../../common/salexifthumb.h" // Tandem Commander 135

#pragma warning(push)
#pragma warning(disable : 4267) // FIXME_X64 - warning temporarily suppressed, fix it
#pragma warning(disable : 4133) // FIXME_X64 - warning temporarily suppressed, fix it

//
// Global variables
//

HINSTANCE HInstance = NULL; // Handle to this DLL itself.

struct CEnumData
{
    EXIFENUMPROC EnumFunc;
    LPARAM LParam;
};

BOOL WINAPI
DllMain(HINSTANCE hInstance, DWORD dwReason, LPVOID lpReserved)
{

    if (dwReason == DLL_PROCESS_ATTACH)
    {
        HInstance = hInstance;
    }
    else if (dwReason == DLL_PROCESS_DETACH)
    {
        FreeTranslations();
    }
    return TRUE;
}

static void
show_entry(ExifEntry* entry, void* data)
{
    struct CEnumData* enumData = (struct CEnumData*)data;
    char value[256];
    ExifIfd ifd = exif_entry_get_ifd(entry);

    enumData->EnumFunc(entry->tag,
                       exif_tag_get_title_in_ifd(entry->tag, ifd),
                       exif_tag_get_description_in_ifd(entry->tag, ifd),
                       exif_entry_get_value(entry, value, sizeof(value)),
                       enumData->LParam);
}

static void
show_ifd(ExifContent* content, void* data)
{
    exif_content_foreach_entry(content, show_entry, data);
}

DWORD WINAPI
EXIFGetVersion()
{
    return EXIF_DLL_VERSION;
}

// Tandem Commander 142: a path of the old (char) exports as the wide path fopen() made of it
// (the code page of the system); free() the result, NULL = cannot be converted or low memory
static wchar_t* AnsiPathToWideAlloc(const char* path)
{
    wchar_t* w;
    int len;

    if (path == NULL)
        return NULL;
    // MB_ERR_INVALID_CHARS: bytes that are no character of the code page fail the call, as
    // they did in the CRT's fopen() - they do not become a default character (another name)
    len = MultiByteToWideChar(CP_ACP, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    if (len <= 0)
        return NULL;
    w = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (w != NULL && MultiByteToWideChar(CP_ACP, MB_ERR_INVALID_CHARS, path, -1, w, len) <= 0)
    {
        free(w);
        w = NULL;
    }
    return w;
}

// Tandem Commander 142: exif_data_new_from_file for a wide path
static ExifData* ExifDataNewFromFileW(const wchar_t* fileName)
{
    ExifData* ed;
    ExifLoader* loader = exif_loader_new();

    if (loader == NULL)
        return NULL;
    exif_loader_write_file_w(loader, fileName);
    ed = exif_loader_get_data(loader);
    exif_loader_unref(loader);
    return ed;
}

// calls 'enumFunc' for the tags of 'ed' and releases 'ed' (the common part of EXIFGetInfo
// and EXIFGetInfoW)
static BOOL EnumExifData(ExifData* ed, EXIFENUMPROC enumFunc, LPARAM lParam)
{
    ExifMnoteData* md;

    struct CEnumData data;
    data.EnumFunc = enumFunc;
    data.LParam = lParam;

    if (ed == NULL)
        return FALSE;
    md = exif_data_get_mnote_data(ed);

    exif_data_foreach_content(ed, show_ifd, &data);

    if (md)
    {
        int c, i;
        unsigned prevId = -1, cnt = 0x1000;

        c = exif_mnote_data_count(md);
        for (i = 0; i < c; i++)
        {

            char val[256];
            const char* title;

            exif_mnote_data_get_value(md, i, val, sizeof(val));
            title = exif_mnote_data_get_title(md, i);
            // ignore unknown parts of Canon makernote
            if (title)
            {
                // We need the tag number to let the user highlight tags
                // he/she is interested in.
                // 0x5678 is a proprierary shift that helps us to distinguish mnote from ordinary tags
                unsigned int id = exif_mnote_data_get_id(md, i) + 0x5678;
                // There are multiple 'Settings (first part)' & 'Settings (second part)' values coming from Canon
                // We attempt here to give a unique ID to each of them.
                if (id == prevId)
                {
                    id += cnt++;
                }
                else
                {
                    prevId = id;
                }

                enumFunc(id, title, exif_mnote_data_get_description(md, i), val, lParam);
            }
        }
    }
    exif_data_unref(ed);

    return TRUE;
}

// Tandem Commander 142: the file 'fileName' is a wide path - a name in any script, with "\\?\"
// in front for a long one (EXIFGetInfo reaches only what the code page and MAX_PATH allow)
BOOL WINAPI
EXIFGetInfoW(const wchar_t* fileName, EXIFENUMPROC enumFunc, LPARAM lParam)
{
    if (fileName == NULL || enumFunc == NULL)
        return FALSE;
    return EnumExifData(ExifDataNewFromFileW(fileName), enumFunc, lParam);
}

BOOL WINAPI
EXIFGetInfo(const char* fileName, int dataLen, EXIFENUMPROC enumFunc, LPARAM lParam)
{
    wchar_t* fileNameW;
    BOOL ret;

    if (dataLen)
        return EnumExifData(exif_data_new_from_data(fileName, dataLen), enumFunc, lParam);

    // Tandem Commander 142: a file goes through the wide entry point
    fileNameW = AnsiPathToWideAlloc(fileName);
    if (fileNameW == NULL)
        return FALSE;
    ret = EnumExifData(ExifDataNewFromFileW(fileNameW), enumFunc, lParam);
    free(fileNameW);
    return ret;
}

// Loads exif data without forced fixup of entries
ExifData* get_exif_data_no_fixups(const char* fileName)
{
    ExifLoader* el;
    ExifData* ed;
    const unsigned char* buf;
    size_t buf_size;

    el = exif_loader_new();
    if (!el)
        return NULL;
    exif_loader_write_file(el, fileName);

    exif_loader_get_buf(el, &buf, &buf_size);
    if (!buf_size)
    {
        exif_loader_unref(el);
        return NULL;
    }
    ed = exif_data_new();
    if (!ed)
    {
        exif_loader_unref(el);
        return NULL;
    }
    exif_data_unset_option(ed, ~0);
    exif_data_set_data_type(ed, EXIF_DATA_TYPE_UNKNOWN);
    exif_data_load_data(ed, buf, buf_size);
    exif_loader_unref(el);
    return ed;
}

// The work of EXIFReplaceThumbnailW and EXIFReplaceThumbnail. Tandem Commander 142: the paths are
// wide; '*err' gets the reason of a failure - the Windows error of the file call that failed,
// ERROR_INVALID_DATA for a file that is refused (not understood, or the result does not fit).
static BOOL ReplaceThumbnailW(const wchar_t* fileName, const wchar_t* newFile, unsigned char* pData, int size, DWORD* err)
{
    JPEGData* pJpeg;
    BOOL ret = FALSE;
    unsigned long fileErr = 0;

    *err = ERROR_INVALID_DATA;
    if (pData == NULL || size <= 0) // Tandem Commander 135: no picture - nothing to write (an empty JFXX block was)
        return FALSE;

    pJpeg = jpeg_data_new_from_file_w(fileName, &fileErr);
    if (fileErr != 0)
    {
        // not read whole or not understood: nothing could be saved from such data (they are
        // marked incomplete) - leave here, with the reason
        *err = fileErr;
        if (pJpeg)
            jpeg_data_unref(pJpeg);
        return FALSE;
    }
    if (pJpeg)
    {
        // Tandem Commander 135: the Exif block is NOT handed to libexif any more. It used to be
        // parsed into tags and serialised again - measured on real camera files, 30 of 82 came
        // back with a changed or shortened maker's block (MakerNote), lost tags, or the block
        // moved (which breaks makers whose block holds offsets from the start of the Exif
        // data). SalExifReplaceThumbnail swaps the thumbnail picture and leaves every other
        // byte of the block where it is; a block it does not understand, or a result that
        // does not fit a segment, is refused - nothing is written.
        // The block is the first Exif APP1 before the picture data (132), not what the
        // streaming loader finds: that one gives up at a block it does not know (APP12
        // "Ducky", APP14 "Adobe" before the Exif block) and a JFXX thumbnail was then added
        // to a file that has Exif.
        const unsigned char* exifBytes = NULL;
        unsigned int exifSize = 0;
        if (jpeg_data_get_exif_bytes(pJpeg, &exifBytes, &exifSize))
        {
            unsigned char* newTiff = NULL;
            size_t newTiffSize = 0;
            if (pData != NULL && size > 0 && exifSize > 6 &&
                SalExifReplaceThumbnail(exifBytes + 6, exifSize - 6, pData, (size_t)size, &newTiff, &newTiffSize))
            {
                unsigned char* payload = malloc(newTiffSize + 6);
                if (payload != NULL)
                {
                    memcpy(payload, "Exif\0\0", 6);
                    memcpy(payload + 6, newTiff, newTiffSize);
                    if (jpeg_data_set_exif_bytes(pJpeg, payload, (unsigned int)(newTiffSize + 6)))
                    {
                        ret = jpeg_data_save_file_w(pJpeg, newFile, &fileErr);
                        if (!ret)
                            *err = fileErr;
                    }
                    free(payload);
                }
                free(newTiff);
            }
        }
        else
        {
            // No APP1 EXIF marker -> make APP0 JFXX
            unsigned int i = 0;
            JPEGSection* pSect = pJpeg->sections;

            while (i < pJpeg->count)
            {
                switch (pSect->marker)
                {
                case JPEG_MARKER_APP0:
                    if ((pSect->content.generic.size < 4) || (*(DWORD*)pSect->content.generic.data == 'XXFJ'))
                    {
                        // invalid or existing JFXX marker -> remove it
                        free(pSect->content.generic.data);
                        memmove(pSect, &pSect[1], (--pJpeg->count - i) * sizeof(JPEGSection));
                        break;
                    }
                    // fall through
                case JPEG_MARKER_SOI:
                    pSect++;
                    i++;
                    break;
                default:
                    // any non-APP0 marker -> insert JFXX before it
                    jpeg_data_append_section(pJpeg);
                    pSect = &pJpeg->sections[i];
                    memmove(&pSect[1], pSect, (pJpeg->count - i - 1) * sizeof(JPEGSection));
                    pSect->marker = JPEG_MARKER_APP0;
                    pSect->content.generic.size = (6 + size);
                    pSect->content.generic.data = malloc(6 + size);
                    *(DWORD*)pSect->content.generic.data = 'XXFJ';
                    // NULL temrination of JFXX, version number
                    ((WORD*)pSect->content.generic.data)[2] = 0x1000;
                    memcpy((char*)pSect->content.generic.data + 6, pData, size);
                    ret = jpeg_data_save_file_w(pJpeg, newFile, &fileErr);
                    if (!ret)
                        *err = fileErr;
                    i = pJpeg->count;
                }
            }
        }
        jpeg_data_unref(pJpeg);
    }
    return ret;
}

// Tandem Commander 142: 'fileName' and 'newFile' are wide paths - names in any script, with
// "\\?\" in front for long ones. After FALSE GetLastError() gives the reason: the Windows error
// of the file call that failed, or ERROR_INVALID_DATA for a file that is refused.
BOOL WINAPI EXIFReplaceThumbnailW(const wchar_t* fileName, const wchar_t* newFile, unsigned char* pData, int size)
{
    DWORD err = ERROR_INVALID_PARAMETER;
    BOOL ret = fileName != NULL && newFile != NULL && ReplaceThumbnailW(fileName, newFile, pData, size, &err);

    if (!ret)
        SetLastError(err);
    return ret;
}

// the old entry point: paths in the code page of the system (Tandem Commander 142: converted
// and handed to the wide one)
BOOL WINAPI EXIFReplaceThumbnail(char* fileName, char* newFile, unsigned char* pData, int size)
{
    wchar_t* fileNameW = AnsiPathToWideAlloc(fileName);
    wchar_t* newFileW = AnsiPathToWideAlloc(newFile);
    DWORD err = ERROR_INVALID_NAME;
    BOOL ret = fileNameW != NULL && newFileW != NULL && ReplaceThumbnailW(fileNameW, newFileW, pData, size, &err);

    free(fileNameW);
    free(newFileW);
    if (!ret)
        SetLastError(err);
    return ret;
}

static void orient_enum_entry(ExifEntry* entry, void* data)
{
    ExifIfd ifd = exif_entry_get_ifd(entry);
    char value[256];

    if (entry->tag == 274 /* orientation */)
    {
        static const char* TR = NULL;
        static const char* BR = NULL;
        static const char* BL = NULL;
        static const char* LT = NULL;
        static const char* RT = NULL;
        static const char* RB = NULL;
        static const char* LB = NULL;
        static int bInited = FALSE;
        PThumbExifInfo pInfo = (PThumbExifInfo)data;

        if (!bInited)
        {
            bInited = TRUE;
            TR = TranslateText("Top-right");
            BR = TranslateText("Bottom-right");
            BL = TranslateText("Bottom-left");
            LT = TranslateText("Left-top");
            RT = TranslateText("Right-top");
            RB = TranslateText("Right-bottom");
            LB = TranslateText("Left-bottom");
        }
        exif_entry_get_value(entry, value, sizeof(value));

        //     if (!stricmp(value, "top - left")) pInfo->Orient = 1; /* default */
        if (!_stricmp(value, TR))
            pInfo->Orient = 2;
        if (!_stricmp(value, BR))
            pInfo->Orient = 3;
        if (!_stricmp(value, BL))
            pInfo->Orient = 4;
        if (!_stricmp(value, LT))
            pInfo->Orient = 5;
        if (!_stricmp(value, RT))
            pInfo->Orient = 6;
        if (!_stricmp(value, RB))
            pInfo->Orient = 7;
        if (!_stricmp(value, LB))
            pInfo->Orient = 8;
        pInfo->flags |= TEI_ORIENT;
    }
    if (entry->tag == 0xa002)
    {
        PThumbExifInfo pInfo = (PThumbExifInfo)data;

        exif_entry_get_value(entry, value, sizeof(value));
        pInfo->Width = atoi(value);
        pInfo->flags |= TEI_WIDTH;
    }
    if (entry->tag == 0xa003)
    {
        PThumbExifInfo pInfo = (PThumbExifInfo)data;

        exif_entry_get_value(entry, value, sizeof(value));
        pInfo->Height = atoi(value);
        pInfo->flags |= TEI_HEIGHT;
    }
} /* orient_enum_entry */

static void orient_enum_ifd(ExifContent* content, void* data)
{
    exif_content_foreach_entry(content, orient_enum_entry, data);
}

BOOL WINAPI EXIFGetOrientationInfo(const char* fileName, PThumbExifInfo pInfo)
{
    ExifData* ed;

    pInfo->Orient = pInfo->flags = 0;

    ed = exif_data_new_from_file(fileName);

    if (ed == NULL)
        return FALSE;

    exif_data_foreach_content(ed, orient_enum_ifd, pInfo);

    exif_data_unref(ed);

    return TRUE;
}

#pragma warning(pop) // FIXME_X64 - warning temporarily suppressed, fix it
