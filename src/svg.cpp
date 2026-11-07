// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"

#include "svg.h"
#include "themes_palette.h"

#define NANOSVG_IMPLEMENTATION
#include "nanosvg\nanosvg.h"
#define NANOSVGRAST_IMPLEMENTATION
#include "nanosvg\nanosvgrast.h"

CSVGSprite SVGArrowRight;
CSVGSprite SVGArrowRightSmall;
CSVGSprite SVGArrowMore;
CSVGSprite SVGArrowLess;
CSVGSprite SVGArrowDropDown;

// Alternative: http://stackoverflow.com/questions/11376288/fast-computing-of-log2-for-64-bit-integers
// (we could probably find one for shorter versions as well)
//
// The following solution has the advantage that constants are computed within the precompiler
// LOG2_k(n) returns floor(log2(n)) and is valid for values 0 <= n < 1 << k
#define LOG2_2(n) ((n) & 0x2 ? 1 : 0)
#define LOG2_4(n) ((n) & 0xC ? 2 + LOG2_2((n) >> 2) : LOG2_2(n))
#define LOG2_8(n) ((n) & 0xF0 ? 4 + LOG2_4((n) >> 4) : LOG2_4(n))
#define LOG2_16(n) ((n) & 0xFF00 ? 8 + LOG2_8((n) >> 8) : LOG2_8(n))
#define LOG2_32(n) ((n) & 0xFFFF0000 ? 16 + LOG2_16((n) >> 16) : LOG2_16(n))
#define LOG2_64(n) ((n) & 0xFFFFFFFF00000000 ? 32 + LOG2_32((n) >> 32) : LOG2_32(n))

//__popcnt16, __popcnt, __popcnt64
//https://msdn.microsoft.com/en-us/library/bb385231(v=vs.100).aspx

DWORD GetSVGSysColor(int index)
{
    // feature 028: SVG sprites rasterize against the theme palette so toolbar
    // and menu glyphs stay legible in the Dark theme
    DWORD color = ThemeSysColor(index);
    DWORD ret = 0xFF000000;
    ret |= GetBValue(color) << 16;
    ret |= GetGValue(color) << 8;
    ret |= GetRValue(color);
    return ret;
}

//*****************************************************************************
//
// RenderSVGImage
//

char* ReadSVGFile(const char* fileName)
{
    char* buff = NULL;
    // feature 171: fileName is UTF-8 (the program's folder), opened wide - quietly (a missing dark variant is normal)
    HANDLE hFile = SalCreateFile(fileName, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                                 FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (hFile != INVALID_HANDLE_VALUE)
    {
        DWORD size = GetFileSize(hFile, NULL);
        if (size != INVALID_FILE_SIZE)
        {
            buff = (char*)malloc(size + 1);
            DWORD read;
            if (ReadFile(hFile, buff, size, &read, NULL) && read == size)
            {
                buff[size] = 0;
            }
            else
            {
                TRACE_E("ReadSVGFile(): ReadFile() failed on " << fileName);
                free(buff);
                buff = NULL;
            }
        }
        else
        {
            TRACE_E("ReadSVGFile(): GetFileSize() failed on " << fileName);
        }
        HANDLES(CloseHandle(hFile));
    }
    else
    {
        TRACE_I("ReadSVGFile(): cannot open SVG file " << fileName);
    }
    return buff;
}

// feature 029: adapt a nanosvg color (0xAABBGGRR) for dark surfaces; the
// per-color rules are shared with the legacy bitmap transform
// (ThemeDarkAdaptColor in themes_palette.h)
static DWORD ThemeDarkAdaptSVGColor(DWORD abgr)
{
    int r = (int)(abgr & 0xFF);
    int g = (int)((abgr >> 8) & 0xFF);
    int b = (int)((abgr >> 16) & 0xFF);
    ThemeDarkAdaptColor(&r, &g, &b);
    return (abgr & 0xFF000000) | ((DWORD)b << 16) | ((DWORD)g << 8) | (DWORD)r;
}

// feature 416: the set in use - an explicit set, or the configured one (-1)
static int ResolveIconSet(int iconSet)
{
    return SalIconSetNormalize(iconSet < 0 ? GetActiveIconSet() : iconSet);
}

// feature 416: 'svg' (freed here) parsed into an image with at least one shape, else NULL -
// an override that does not parse or draws nothing must not blank the button (029 contract, rule 3)
static NSVGimage* ParseUsableSVG(char* svg, float dpi)
{
    if (svg == NULL)
        return NULL;
    NSVGimage* image = nsvgParse(svg, "px", dpi);
    free(svg);
    if (image != NULL && image->shapes == NULL)
    {
        TRACE_I("ParseUsableSVG(): the file draws no shape, not used");
        nsvgDelete(image);
        image = NULL;
    }
    return image;
}

// feature 416: the image of icon 'svgName' of icon set 'iconSet' (SAL_ICONSET_*): in the Dark theme
// the set's hand-tuned variant when it is usable (*darkOverride = TRUE, drawn verbatim), else the
// set's standard file; NULL when neither is usable. Paths are UTF-8, read wide (feature 171); a
// path that does not fit is refused (SalIconSetBuildPath), never cut.
static NSVGimage* LoadSetSVGImage(const char* svgName, int iconSet, float dpi, BOOL* darkOverride)
{
    *darkOverride = FALSE;
    char dir[SAL_MODULE_PATH_U8];
    if (!SalGetModuleDirU8(NULL, dir, 3 * MAX_PATH))
        return NULL;
    char svgFile[SAL_MODULE_PATH_U8];
    BOOL dark = IsDarkThemeActive();
    NSVGimage* darkImage = NULL;
    // feature 029: while the Dark theme is active a hand-tuned variant in <set>\dark\ takes
    // precedence over the automatic adaptation (contract: specs/416-fluent-icon-set/contracts/icon-set-files.md)
    if (dark && SalIconSetBuildPath(svgFile, _countof(svgFile), dir, iconSet, true, svgName))
        darkImage = ParseUsableSVG(ReadSVGFile(svgFile), dpi);
    NSVGimage* standardImage = NULL;
    if (darkImage == NULL && SalIconSetBuildPath(svgFile, _countof(svgFile), dir, iconSet, false, svgName))
        standardImage = ParseUsableSVG(ReadSVGFile(svgFile), dpi);
    switch (SalIconSetChooseSource(dark != FALSE, darkImage != NULL, standardImage != NULL))
    {
    case SAL_ICONSRC_DARK:
        *darkOverride = TRUE;
        return darkImage;
    case SAL_ICONSRC_STANDARD:
        return standardImage;
    }
    return NULL;
}

// feature 029: the standard glyphs are drawn for light surfaces - lighten their dark/neutral
// strokes and fills so they stay legible on the dark toolbar; colored accents keep their hue
static void ThemeDarkAdaptSVGImage(NSVGimage* image)
{
    NSVGshape* shape = image->shapes;
    while (shape != NULL)
    {
        if (shape->fill.type == NSVG_PAINT_COLOR)
            shape->fill.color = ThemeDarkAdaptSVGColor(shape->fill.color);
        if (shape->stroke.type == NSVG_PAINT_COLOR)
            shape->stroke.color = ThemeDarkAdaptSVGColor(shape->stroke.color);
        shape = shape->next;
    }
}

// Renders icons for which we have an SVG representation
BOOL RenderSVGImage(NSVGrasterizer* rast, HDC hDC, int x, int y, const char* svgName, int iconSize, COLORREF bkColor,
                    BOOL enabled, int iconSet)
{
    // feature 171: the program's folder as UTF-8 and the file read wide - under an install folder
    // outside the code page GetModuleFileName A gave '?' and every icon fell back to the old bitmaps
    float sysDPIScale = (float)GetScaleForSystemDPI();
    BOOL darkOverride = FALSE; // hand-tuned dark variant loaded (used verbatim)
    // feature 416: parsed before the cell is touched - without a usable image the cell keeps what
    // lies below it (the Classic raster glyph, or the caller's fallback)
    NSVGimage* image = LoadSetSVGImage(svgName, ResolveIconSet(iconSet), sysDPIScale, &darkOverride);
    if (image == NULL)
        return FALSE;

    HDC hMemDC = HANDLES(CreateCompatibleDC(NULL));
    BITMAPINFOHEADER bmhdr;
    memset(&bmhdr, 0, sizeof(bmhdr));
    bmhdr.biSize = sizeof(bmhdr);
    bmhdr.biWidth = iconSize;
    bmhdr.biHeight = -iconSize;
    if (bmhdr.biHeight == 0)
        bmhdr.biHeight = -1;
    bmhdr.biPlanes = 1;
    bmhdr.biBitCount = 32;
    bmhdr.biCompression = BI_RGB;
    void* lpMemBits = NULL;
    HBITMAP hMemBmp = HANDLES(CreateDIBSection(hMemDC, (CONST BITMAPINFO*)&bmhdr, DIB_RGB_COLORS, &lpMemBits, NULL, 0));
    SelectObject(hMemDC, hMemBmp);

    RECT r;
    r.left = x;
    r.top = y;
    r.right = x + iconSize;
    r.bottom = y + iconSize;
    SetBkColor(hDC, bkColor);
    ExtTextOut(hDC, 0, 0, ETO_OPAQUE, &r, "", 0, NULL);

    if (!enabled)
    {
        DWORD disabledColor = GetSVGSysColor(COLOR_BTNSHADOW); // JRYFIXME - initial draft: where will we take the disabled color from?
        NSVGshape* shape = image->shapes;
        while (shape != NULL)
        {
            if ((shape->fill.color & 0x00FFFFFF) != 0x00FFFFFF)
                shape->fill.color = disabledColor;
            shape = shape->next;
        }
    }

    // feature 029: hand-tuned dark variants are rasterized verbatim
    if (enabled && !darkOverride && IsDarkThemeActive())
        ThemeDarkAdaptSVGImage(image);

    float scale = sysDPIScale / 100;
    nsvgRasterize(rast, image, 0, 0, scale, (BYTE*)lpMemBits, iconSize, iconSize, iconSize * 4);
    nsvgDelete(image);

    BLENDFUNCTION bf;
    bf.BlendOp = AC_SRC_OVER;
    bf.BlendFlags = 0;
    bf.SourceConstantAlpha = 0xff; // want to use per-pixel alpha values
    bf.AlphaFormat = AC_SRC_ALPHA;
    AlphaBlend(hDC, x, y, iconSize, iconSize, hMemDC, 0, 0, iconSize, iconSize, bf);

    HANDLES(DeleteObject(hMemBmp));
    HANDLES(DeleteDC(hMemDC));
    return TRUE;
}

HICON CreateSetSVGIcon(const char* svgName, int iconSet, int size)
{
    if (svgName == NULL || size <= 0 || size > 256)
        return NULL;
    BOOL darkOverride = FALSE;
    NSVGimage* image = LoadSetSVGImage(svgName, ResolveIconSet(iconSet), (float)GetScaleForSystemDPI(), &darkOverride);
    if (image == NULL)
        return NULL;
    if (image->width <= 0)
    {
        nsvgDelete(image);
        return NULL;
    }
    if (!darkOverride && IsDarkThemeActive())
        ThemeDarkAdaptSVGImage(image);

    BITMAPINFOHEADER bmhdr;
    memset(&bmhdr, 0, sizeof(bmhdr));
    bmhdr.biSize = sizeof(bmhdr);
    bmhdr.biWidth = size;
    bmhdr.biHeight = -size; // top-down
    bmhdr.biPlanes = 1;
    bmhdr.biBitCount = 32;
    bmhdr.biCompression = BI_RGB;
    void* bits = NULL;
    HBITMAP hColor = HANDLES(CreateDIBSection(NULL, (CONST BITMAPINFO*)&bmhdr, DIB_RGB_COLORS, &bits, NULL, 0));
    if (hColor == NULL || bits == NULL)
    {
        if (hColor != NULL)
            HANDLES(DeleteObject(hColor));
        nsvgDelete(image);
        return NULL;
    }
    memset(bits, 0, (size_t)size * size * 4);
    NSVGrasterizer* rast = nsvgCreateRasterizer();
    if (rast != NULL)
    {
        // the set's icons are drawn on a 16 x 16 canvas: scale to the requested size
        nsvgRasterize(rast, image, 0, 0, (float)size / image->width, (BYTE*)bits, size, size, size * 4);
        nsvgDeleteRasterizer(rast);
    }
    nsvgDelete(image);

    // the rasterizer gives premultiplied alpha (what AlphaBlend wants); an icon wants straight
    // alpha, and a 1-bit mask (1 = transparent) for image lists and DCs that ignore the alpha
    int maskStride = ((size + 15) / 16) * 2;
    BYTE* maskBits = (BYTE*)calloc((size_t)maskStride * size, 1);
    BYTE* p = (BYTE*)bits;
    for (int yy = 0; yy < size; yy++)
    {
        for (int xx = 0; xx < size; xx++, p += 4)
        {
            int a = p[3];
            if (a > 0 && a < 255)
            {
                for (int c = 0; c < 3; c++)
                    p[c] = (BYTE)min(255, (p[c] * 255 + a / 2) / a);
            }
            if (a < 128 && maskBits != NULL)
                maskBits[yy * maskStride + xx / 8] |= (BYTE)(0x80 >> (xx % 8));
        }
    }
    HBITMAP hMask = maskBits != NULL ? HANDLES(CreateBitmap(size, size, 1, 1, maskBits)) : NULL;
    if (maskBits != NULL)
        free(maskBits);
    HICON hIcon = NULL;
    if (hMask != NULL)
    {
        ICONINFO ii;
        ii.fIcon = TRUE;
        ii.xHotspot = 0;
        ii.yHotspot = 0;
        ii.hbmMask = hMask;
        ii.hbmColor = hColor;
        hIcon = HANDLES(CreateIconIndirect(&ii));
        HANDLES(DeleteObject(hMask));
    }
    HANDLES(DeleteObject(hColor));
    return hIcon;
}

//*****************************************************************************
//
// CSVGSprite
//

CSVGSprite::CSVGSprite()
{
    for (int i = 0; i < SVGSTATE_COUNT; i++)
        HBitmaps[i] = NULL;
    Clean();
}

CSVGSprite::~CSVGSprite()
{
    Clean();
}

void CSVGSprite::Clean()
{
    for (int i = 0; i < SVGSTATE_COUNT; i++)
    {
        if (HBitmaps[i] != NULL)
        {
            HANDLES(DeleteObject(HBitmaps[i]));
            HBitmaps[i] = NULL;
        }
    }
    Width = -1;
    Height = -1;
}

char* CSVGSprite::LoadSVGResource(int resID)
{
    char* ret = NULL;
    HRSRC hRsrc = FindResource(HInstance, MAKEINTRESOURCE(resID), RT_RCDATA);
    if (hRsrc != NULL)
    {
        char* rawSVG = (char*)LoadResource(HInstance, hRsrc);
        if (rawSVG != NULL)
        {
            DWORD size = SizeofResource(HInstance, hRsrc);
            if (size > 0)
            {
                NSVGimage* image = NULL;
                NSVGrasterizer* rast = NULL;

                char* terminatedSVG = (char*)malloc(size + 1);
                memcpy(terminatedSVG, rawSVG, size);
                terminatedSVG[size] = 0;
                ret = terminatedSVG;
            }
            else
            {
                TRACE_E("LoadSVGResource() Invalid resource data! resID=" << resID);
            }
        }
        else
        {
            TRACE_E("LoadSVGResource() Cannot load resource! resID=" << resID);
        }
    }
    else
    {
        TRACE_E("LoadSVGResource() Resource not found! resID=" << resID);
    }
    return ret;
}

void CSVGSprite::GetScaleAndSize(const NSVGimage* image, const SIZE* sz, float* scale, int* width, int* height)
{
    if (sz->cx != -1 || sz->cy != -1)
    {
        float scaleX, scaleY;
        if (sz->cx != -1)
            scaleX = sz->cx / image->width;
        if (sz->cy != -1)
            scaleY = sz->cy / image->height;
        if (sz->cx == -1)
        {
            *scale = scaleY;
            *height = sz->cy;
            *width = (int)(image->width * *scale);
        }
        else
        {
            if (sz->cy == -1)
            {
                *scale = scaleX;
                *width = sz->cx;
                *height = (int)(image->height * *scale);
            }
            else
            {
                *scale = min(scaleX, scaleY);
                *width = (int)(image->width * *scale);
                *height = (int)(image->height * *scale);
            }
        }
    }
    else
    {
        *scale = (float)GetScaleForSystemDPI() / 100;
        *width = (int)(image->width * *scale);
        *height = (int)(image->height * *scale);
    }
}
/*
HBITMAP
CSVGSprite::LoadSVGToBitmap(int resID, SIZE *sz)
{
  if (sz == NULL)
    TRACE_C("LoadSVGToBitmap(): invalid parameters!");

  HBITMAP hMemBmp = NULL;

  char *terminatedSVG = LoadSVGResource(resID);
  if (terminatedSVG != NULL)
  {
    NSVGimage *image = NULL;
    image = nsvgParse(terminatedSVG, "px", (float)GetSystemDPI());
    free(terminatedSVG);

    float scale;
    int w, h;
    GetScaleAndSize(image, sz, &scale, &w, &h);

    NSVGrasterizer *rast = NULL;
    rast = nsvgCreateRasterizer();

    HDC hMemDC = HANDLES(CreateCompatibleDC(NULL));
    BITMAPINFOHEADER bmhdr;
    memset(&bmhdr, 0, sizeof(bmhdr));
    bmhdr.biSize = sizeof(bmhdr);
    bmhdr.biWidth = w;
    bmhdr.biHeight = -h;
    if (bmhdr.biHeight == 0) bmhdr.biHeight = -1;
    bmhdr.biPlanes = 1;
    bmhdr.biBitCount = 32;
    bmhdr.biCompression = BI_RGB;
    void *lpMemBits = NULL;
    hMemBmp = HANDLES(CreateDIBSection(hMemDC, (CONST BITMAPINFO *)&bmhdr, DIB_RGB_COLORS, &lpMemBits, NULL, 0));
    HANDLES(DeleteDC(hMemDC));

    nsvgRasterize(rast, image, 0, 0, scale, (BYTE*)lpMemBits, w, h, w * 4);

    sz->cx = w;
    sz->cy = h;

    nsvgDeleteRasterizer(rast);
    nsvgDelete(image);
  }
  return hMemBmp;
}
*/
void CSVGSprite::CreateDIB(int width, int height, HBITMAP* hMemBmp, void** lpMemBits)
{
    HDC hMemDC = HANDLES(CreateCompatibleDC(NULL));
    BITMAPINFOHEADER bmhdr;
    memset(&bmhdr, 0, sizeof(bmhdr));
    bmhdr.biSize = sizeof(bmhdr);
    bmhdr.biWidth = width;
    bmhdr.biHeight = -height;
    if (bmhdr.biHeight == 0)
        bmhdr.biHeight = -1;
    bmhdr.biPlanes = 1;
    bmhdr.biBitCount = 32;
    bmhdr.biCompression = BI_RGB;
    *hMemBmp = HANDLES(CreateDIBSection(hMemDC, (CONST BITMAPINFO*)&bmhdr, DIB_RGB_COLORS, lpMemBits, NULL, 0));
    HANDLES(DeleteDC(hMemDC));
}

void CSVGSprite::ColorizeSVG(NSVGimage* image, DWORD state, int disabledSysIndex)
{
    if (state == SVGSTATE_ORIGINAL)
        return;

    int sysIndex;
    switch (state)
    {
    case SVGSTATE_ENABLED:
        sysIndex = COLOR_BTNTEXT;
        break;

    case SVGSTATE_DISABLED:
        sysIndex = disabledSysIndex; // COLOR_BTNSHADOW, feature 416: COLOR_GRAYTEXT for the Fluent 2 chevron
        break;

    default:
        sysIndex = COLOR_BTNTEXT;
        TRACE_E("CSVGSprite::ColorizeSVG() unknown state=" << state);
    }
    DWORD color = GetSVGSysColor(sysIndex);
    NSVGshape* shape = image->shapes;
    while (shape != NULL)
    {
        shape->fill.color = color;
        // feature 416: the Fluent 2 chevron is a stroke (the Classic sprites have no stroke)
        if (shape->stroke.type == NSVG_PAINT_COLOR)
            shape->stroke.color = color;
        shape = shape->next;
    }
}

BOOL CSVGSprite::Load(int resID, int width, int height, DWORD states, int disabledSysIndex)
{
    if (states == 0 || states >= (1 << SVGSTATE_COUNT))
    {
        TRACE_E("CSVGSprite::Load() wrong states combination: " << states);
        states |= SVGSTATE_ORIGINAL;
    }
    Clean();

    char* terminatedSVG = LoadSVGResource(resID);
    if (terminatedSVG != NULL)
    {
        NSVGimage* image = NULL;
        image = nsvgParse(terminatedSVG, "px", (float)GetSystemDPI());
        free(terminatedSVG);

        float scale;
        SIZE sz = {width, height};
        GetScaleAndSize(image, &sz, &scale, &Width, &Height);

        NSVGrasterizer* rast = NULL;
        rast = nsvgCreateRasterizer();

        for (int i = 0; i < SVGSTATE_COUNT; i++)
        {
            DWORD state = 1 << i;
            if (states & state)
            {
                void* lpMemBits;
                CreateDIB(Width, Height, &HBitmaps[i], &lpMemBits);
                ColorizeSVG(image, state, disabledSysIndex);
                nsvgRasterize(rast, image, 0, 0, scale, (BYTE*)lpMemBits, Width, Height, Width * 4);
            }
        }

        nsvgDeleteRasterizer(rast);
        nsvgDelete(image);
    }
    return TRUE;
}

void CSVGSprite::GetSize(SIZE* s)
{
    s->cx = Width;
    s->cy = Height;
}

int CSVGSprite::GetWidth()
{
    return Width;
}

int CSVGSprite::GetHeight()
{
    return Height;
}

void CSVGSprite::AlphaBlend(HDC hDC, int x, int y, int width, int height, DWORD state)
{
    HDC hMemTmpDC = HANDLES(CreateCompatibleDC(hDC));
    int index = LOG2_32(state);
    HBITMAP hOldBitmap = (HBITMAP)SelectObject(hMemTmpDC, HBitmaps[index]);

    if (width == -1)
        width = Width;
    if (height == -1)
        height = Height;

    BLENDFUNCTION bf;
    bf.BlendOp = AC_SRC_OVER;
    bf.BlendFlags = 0;
    bf.SourceConstantAlpha = 0xff; // want to use per-pixel alpha values
    bf.AlphaFormat = AC_SRC_ALPHA;
    ::AlphaBlend(hDC, x, y, width, height, hMemTmpDC, 0, 0, Width, Height, bf);

    SelectObject(hMemTmpDC, hOldBitmap);
    HANDLES(DeleteDC(hMemTmpDC));
}
