// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

//*****************************************************************************
//
// wicengine.cpp
//
// In-process image engine backed by the Windows Imaging Component (WIC).
// See wicengine.h and specs/006-fix-pictview-plugin/contracts/ for the
// contract. Struct layouts come from lib/PVW32DLL.h (4-byte packing).
//

#include "precomp.h"

// precomp.h defines INT32/UINT32 as macros for legacy compilers; intsafe.h
// (pulled in by wincodec.h) typedefs the same names - drop the macros here
#ifdef INT32
#undef INT32
#undef UINT32
#endif

#include <initguid.h>
#include <wincodec.h>

#include "lib/pvw32dll.h"
#include "pictview.h"
#include "wicengine.h"
#include "../../common/salpvsource.h" // feature 111: source colors, the JPEG comment's NUL

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib") // VariantInit (feature 105: encoder options)

//*****************************************************************************
//
// COM / WIC factory plumbing (research D9)
//

static IWICImagingFactory* WicFactory = NULL;
static CRITICAL_SECTION WicFactoryCS;
static BOOL WicFactoryCSInited = FALSE;

// COM must be initialized on every thread that decodes (viewer window
// threads, thumbnail loader). We never CoUninitialize - the threads run
// message loops for their whole lifetime and the OS cleans up on exit.
static void EnsureComOnThisThread()
{
    static thread_local bool inited = false;
    if (!inited)
    {
        HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
        // S_OK/S_FALSE = ok; RPC_E_CHANGED_MODE = already MTA, also usable
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE)
            TRACE_E("WIC engine: CoInitializeEx failed, hr=0x" << std::hex << hr);
        inited = true;
    }
}

static IWICImagingFactory* GetWicFactory()
{
    EnsureComOnThisThread();
    if (WicFactory != NULL)
        return WicFactory; // pointer write is atomic; factory is thread-safe
    if (!WicFactoryCSInited)
        return NULL; // InitWicEngine not called yet
    EnterCriticalSection(&WicFactoryCS);
    if (WicFactory == NULL)
    {
        IWICImagingFactory* f = NULL;
        HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory, NULL, CLSCTX_INPROC_SERVER,
                                      __uuidof(IWICImagingFactory), (void**)&f);
        if (SUCCEEDED(hr))
            WicFactory = f;
        else
            TRACE_E("WIC engine: cannot create IWICImagingFactory, hr=0x" << std::hex << hr);
    }
    LeaveCriticalSection(&WicFactoryCS);
    return WicFactory;
}

//*****************************************************************************
//
// Per-image context (data-model.md #3)
//

struct CWicImage
{
    IWICBitmapDecoder* Decoder; // NULL for attached-HBITMAP images
    IStream* Stream;            // optional backing stream (callback input)

    UINT FrameCount;
    UINT InfoFrame;   // frame whose dimensions are currently reported
    int DecodedFrame; // frame currently held in the DIB; -1 = none

    HBITMAP HDib; // 32bpp top-down DIB section, opaque (composited over BkColor)
    BYTE* DibBits;
    int Width, Height; // dimensions of the decoded/reported image (after rotation)
    BYTE** Lines;      // per-row pointers for PVGetHandles2 (pipette/histogram)
    PVImageHandles Handles;

    DWORD Format; // PVF_*
    DWORD FileSize;
    DWORD DpiX, DpiY;

    int StretchW, StretchH; // signed target size; negative = mirror; 0 = natural
    DWORD StretchMode;      // StretchBlt mode (COLORONCOLOR, ...)
    COLORREF BkColor;       // background for alpha compositing

    // feature 111
    BOOL FromFile;           // the decoder was opened on a file (OpenFromFileU8)
    BOOL Detached;           // WicDetachSource released that decoder (WicReattachSource takes it back)
    UINT DetachedFrameCount; // the frame count, decoded frame and info frame at the detach
    int DetachedFrame;
    UINT DetachedInfoFrame;
    CWicSourceFormat Src; // the source format of frame SrcFrame (-1 = not read yet)
    int SrcFrame;
    BOOL AlphaUsed; // a pixel of the decoded frame AlphaFrame (-1 = none) is not opaque
    int AlphaFrame;

    // feature 120: clockwise quarter turns (0..3) WicChangeImage applied to the decoded frame - a
    // frame decoded again (another background color) is turned again
    int Turns;
};

static void FreeDib(CWicImage* img)
{
    if (img->HDib != NULL)
    {
        DeleteObject(img->HDib);
        img->HDib = NULL;
    }
    img->DibBits = NULL;
    if (img->Lines != NULL)
    {
        free(img->Lines);
        img->Lines = NULL;
    }
    img->DecodedFrame = -1;
}

static void DestroyWicImage(CWicImage* img)
{
    FreeDib(img);
    if (img->Decoder != NULL)
        img->Decoder->Release();
    if (img->Stream != NULL)
        img->Stream->Release();
    free(img);
}

// allocate the 32bpp top-down DIB for w x h; returns FALSE on failure
static BOOL AllocDib(CWicImage* img, int w, int h)
{
    FreeDib(img);
    BITMAPINFO bi;
    memset(&bi, 0, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h; // top-down
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    void* bits = NULL;
    img->HDib = CreateDIBSection(NULL, &bi, DIB_RGB_COLORS, &bits, NULL, 0);
    if (img->HDib == NULL || bits == NULL)
    {
        img->HDib = NULL;
        return FALSE;
    }
    img->DibBits = (BYTE*)bits;
    img->Width = w;
    img->Height = h;
    return TRUE;
}

static BOOL BuildLines(CWicImage* img)
{
    if (img->Lines != NULL)
        free(img->Lines);
    img->Lines = (BYTE**)malloc(img->Height * sizeof(BYTE*));
    if (img->Lines == NULL)
        return FALSE;
    int y;
    for (y = 0; y < img->Height; y++)
        img->Lines[y] = img->DibBits + (size_t)y * img->Width * 4;
    return TRUE;
}

// composite premultiplied BGRA pixels in the DIB over the background colour,
// producing an opaque image (the viewer draws with plain StretchBlt); TRUE when a pixel
// was not opaque (feature 111: the alpha channel is really used)
static BOOL CompositeOverBackground(CWicImage* img)
{
    BOOL alphaUsed = FALSE;
    BYTE bgR = GetRValue(img->BkColor);
    BYTE bgG = GetGValue(img->BkColor);
    BYTE bgB = GetBValue(img->BkColor);
    size_t count = (size_t)img->Width * img->Height;
    BYTE* px = img->DibBits;
    size_t i;
    for (i = 0; i < count; i++, px += 4)
    {
        BYTE a = px[3];
        if (a != 255)
        {
            // source is premultiplied: out = src + bg * (255 - a) / 255
            px[0] = (BYTE)(px[0] + ((bgB * (255 - a) + 127) / 255));
            px[1] = (BYTE)(px[1] + ((bgG * (255 - a) + 127) / 255));
            px[2] = (BYTE)(px[2] + ((bgR * (255 - a) + 127) / 255));
            px[3] = 255;
            alphaUsed = TRUE;
        }
    }
    return alphaUsed;
}

// feature 111: what the source pixel format 'pf' of a frame holds (the engine always decodes to
// 32-bit rows; this is what the FILE holds). 'fr' gives the palette of an indexed format.
static void SourceFormatOf(REFGUID pf, IWICBitmapFrameDecode* fr, CWicSourceFormat* s)
{
    s->Colors = PV_COLOR_TC24;
    s->ColorModel = PVCM_RGB;
    s->BitsPerPixel = 0;
    s->HasAlpha = FALSE;
    IWICImagingFactory* factory = GetWicFactory();
    BOOL transparency = FALSE;
    if (factory != NULL)
    {
        IWICComponentInfo* ci = NULL;
        if (SUCCEEDED(factory->CreateComponentInfo(pf, &ci)))
        {
            IWICPixelFormatInfo2* pi = NULL;
            if (SUCCEEDED(ci->QueryInterface(IID_PPV_ARGS(&pi))))
            {
                UINT bpp = 0;
                if (SUCCEEDED(pi->GetBitsPerPixel(&bpp)))
                    s->BitsPerPixel = bpp;
                pi->SupportsTransparency(&transparency); // FALSE for indexed formats (measured)
                pi->Release();
            }
            ci->Release();
        }
    }
    if (IsEqualGUID(pf, GUID_WICPixelFormatBlackWhite))
        s->Colors = 2;
    else if (IsEqualGUID(pf, GUID_WICPixelFormat1bppIndexed) || IsEqualGUID(pf, GUID_WICPixelFormat2bppIndexed) ||
             IsEqualGUID(pf, GUID_WICPixelFormat4bppIndexed) || IsEqualGUID(pf, GUID_WICPixelFormat8bppIndexed))
    {
        // the palette's size, not the format's: a GIF of two colors is 8bppIndexed (measured)
        UINT n = 0;
        BOOL gray = FALSE;
        IWICPalette* pal = NULL;
        if (factory != NULL && fr != NULL && SUCCEEDED(factory->CreatePalette(&pal)))
        {
            UINT count = 0;
            if (SUCCEEDED(fr->CopyPalette(pal)) && SUCCEEDED(pal->GetColorCount(&count)) && count > 0)
            {
                n = count;
                pal->IsGrayscale(&gray);
            }
            pal->Release();
        }
        s->Colors = SalPaletteColorsForSave(n, s->BitsPerPixel);
        if (gray && s->Colors == 256)
            s->ColorModel = PVCM_GRAYS;
    }
    else if (IsEqualGUID(pf, GUID_WICPixelFormat2bppGray) || IsEqualGUID(pf, GUID_WICPixelFormat4bppGray) ||
             IsEqualGUID(pf, GUID_WICPixelFormat8bppGray) || IsEqualGUID(pf, GUID_WICPixelFormat16bppGray) ||
             IsEqualGUID(pf, GUID_WICPixelFormat16bppGrayFixedPoint) || IsEqualGUID(pf, GUID_WICPixelFormat16bppGrayHalf) ||
             IsEqualGUID(pf, GUID_WICPixelFormat32bppGrayFloat) || IsEqualGUID(pf, GUID_WICPixelFormat32bppGrayFixedPoint))
    {
        s->Colors = 256; // the dialog's gray choice is 256 gray levels
        s->ColorModel = PVCM_GRAYS;
    }
    else if (IsEqualGUID(pf, GUID_WICPixelFormat16bppBGR555))
        s->Colors = PV_COLOR_HC15;
    else if (IsEqualGUID(pf, GUID_WICPixelFormat16bppBGR565))
        s->Colors = PV_COLOR_HC16;
    else if (IsEqualGUID(pf, GUID_WICPixelFormat16bppBGRA5551))
    {
        s->Colors = PV_COLOR_HC15;
        s->HasAlpha = TRUE;
    }
    else
    {
        if (IsEqualGUID(pf, GUID_WICPixelFormat32bppCMYK) || IsEqualGUID(pf, GUID_WICPixelFormat64bppCMYK) ||
            IsEqualGUID(pf, GUID_WICPixelFormat40bppCMYKAlpha) || IsEqualGUID(pf, GUID_WICPixelFormat80bppCMYKAlpha))
            s->ColorModel = PVCM_CMYK;
        s->HasAlpha = transparency; // 32bppBGRA, 64bppRGBA, ... - not 32bppBGR (measured)
        s->Colors = transparency ? PV_COLOR_TC32 : PV_COLOR_TC24;
    }
}

// feature 111: the source format of 'frame' into img->Src (read once per frame, kept after a detach)
static void EnsureSourceFormat(CWicImage* img, int frame)
{
    if (frame < 0)
        frame = 0;
    if (img->SrcFrame == frame || img->Decoder == NULL)
        return;
    IWICBitmapFrameDecode* fr = NULL;
    if (FAILED(img->Decoder->GetFrame((UINT)frame, &fr)))
        return;
    WICPixelFormatGUID pf;
    if (SUCCEEDED(fr->GetPixelFormat(&pf)))
    {
        SourceFormatOf(pf, fr, &img->Src);
        img->SrcFrame = frame;
    }
    fr->Release();
}

//*****************************************************************************
//
// Format mapping and error codes
//

static DWORD MapContainerToPVF(REFGUID g, const char** shortName)
{
    if (IsEqualGUID(g, GUID_ContainerFormatJpeg))
    {
        *shortName = "JPEG";
        return PVF_JPG;
    }
    if (IsEqualGUID(g, GUID_ContainerFormatPng))
    {
        *shortName = "PNG";
        return PVF_PNG;
    }
    if (IsEqualGUID(g, GUID_ContainerFormatBmp))
    {
        *shortName = "BMP";
        return PVF_BMP;
    }
    if (IsEqualGUID(g, GUID_ContainerFormatGif))
    {
        *shortName = "GIF";
        return PVF_GIF;
    }
    if (IsEqualGUID(g, GUID_ContainerFormatTiff))
    {
        *shortName = "TIFF";
        return PVF_TIFF;
    }
    if (IsEqualGUID(g, GUID_ContainerFormatIco))
    {
        *shortName = "ICO";
        return PVF_ICO;
    }
    *shortName = "WIC";
    return 0; // no special-case handling in the viewer
}

static PVCODE MapOpenHResult(HRESULT hr)
{
    if (hr == E_OUTOFMEMORY)
        return PVC_OOM;
    if (hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) ||
        hr == HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND) ||
        hr == HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED) ||
        hr == HRESULT_FROM_WIN32(ERROR_SHARING_VIOLATION))
        return PVC_CANNOT_OPEN_FILE;
    if (hr == WINCODEC_ERR_COMPONENTNOTFOUND)
        return PVC_UNSUP_FILE_TYPE; // no codec for this data
    return PVC_UNKNOWN_FILE_STRUCT;
}

//*****************************************************************************
//
// Open paths
//

static PVCODE OpenFromFileU8(CWicImage* img, const char* u8Path)
{
    IWICImagingFactory* factory = GetWicFactory();
    if (factory == NULL)
        return PVC_EXCEPTION;
    // UTF-8 -> UTF-16 with \\?\ prefix so long paths work (feature 004)
    WCHAR* w = SplU8ToWExtAlloc(u8Path);
    if (w == NULL)
        return PVC_CANNOT_OPEN_FILE;

    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (GetFileAttributesExW(w, GetFileExInfoStandard, &fad))
        img->FileSize = fad.nFileSizeLow; // informational only

    IWICBitmapDecoder* dec = NULL;
    HRESULT hr = factory->CreateDecoderFromFilename(w, NULL, GENERIC_READ,
                                                    WICDecodeMetadataCacheOnDemand, &dec);
    free(w);
    if (FAILED(hr))
        return MapOpenHResult(hr);
    img->Decoder = dec;
    img->FromFile = TRUE; // feature 111
    return PVC_OK;
}

static PVCODE OpenFromCallbacks(CWicImage* img, TPVReadFunc readFunc, TPVSeekFunc seekFunc,
                                void* appSpecific, DWORD dataSize)
{
    IWICImagingFactory* factory = GetWicFactory();
    if (factory == NULL)
        return PVC_EXCEPTION;
    if (readFunc == NULL)
        return PVC_INCORRECT_PARAMETER;
    if (seekFunc != NULL)
        seekFunc(appSpecific, 0, FILE_BEGIN);

    // read everything into memory (thumbnail/embedded inputs are small)
    DWORD cap = dataSize > 0 ? dataSize : 64 * 1024;
    BYTE* buf = (BYTE*)malloc(cap);
    if (buf == NULL)
        return PVC_OOM;
    DWORD total = 0;
    for (;;)
    {
        if (total == cap)
        {
            DWORD newCap = cap * 2;
            BYTE* nb = (BYTE*)realloc(buf, newCap);
            if (nb == NULL)
            {
                free(buf);
                return PVC_OOM;
            }
            buf = nb;
            cap = newCap;
        }
        DWORD got = readFunc(appSpecific, buf + total, cap - total);
        if (got == 0 || got == (DWORD)-1)
            break;
        total += got;
        if (dataSize > 0 && total >= dataSize)
            break;
    }
    if (total == 0)
    {
        free(buf);
        return PVC_READING_ERROR;
    }

    HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, total);
    if (hMem == NULL)
    {
        free(buf);
        return PVC_OOM;
    }
    void* p = GlobalLock(hMem);
    memcpy(p, buf, total);
    GlobalUnlock(hMem);
    free(buf);

    IStream* stream = NULL;
    if (FAILED(CreateStreamOnHGlobal(hMem, TRUE /*free on release*/, &stream)))
    {
        GlobalFree(hMem);
        return PVC_OOM;
    }
    IWICBitmapDecoder* dec = NULL;
    HRESULT hr = factory->CreateDecoderFromStream(stream, NULL, WICDecodeMetadataCacheOnDemand, &dec);
    if (FAILED(hr))
    {
        stream->Release();
        return MapOpenHResult(hr);
    }
    img->Stream = stream;
    img->Decoder = dec;
    img->FileSize = total;
    return PVC_OK;
}

static PVCODE AttachBitmap(CWicImage* img, HBITMAP hBmp)
{
    BITMAP bm;
    if (hBmp == NULL || GetObject(hBmp, sizeof(bm), &bm) == 0 || bm.bmWidth <= 0 || bm.bmHeight <= 0)
        return PVC_INCORRECT_PARAMETER;
    if (!AllocDib(img, bm.bmWidth, bm.bmHeight))
        return PVC_OOM;

    BITMAPINFO bi;
    memset(&bi, 0, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = bm.bmWidth;
    bi.bmiHeader.biHeight = -bm.bmHeight; // top-down
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    HDC dc = GetDC(NULL);
    int ok = GetDIBits(dc, hBmp, 0, bm.bmHeight, img->DibBits, &bi, DIB_RGB_COLORS);
    ReleaseDC(NULL, dc);
    if (ok == 0)
    {
        FreeDib(img);
        return PVC_GDI_ERROR;
    }
    // DDB has no alpha - force opaque
    size_t count = (size_t)img->Width * img->Height;
    BYTE* px = img->DibBits;
    size_t i;
    for (i = 0; i < count; i++, px += 4)
        px[3] = 255;

    if (!BuildLines(img))
    {
        FreeDib(img);
        return PVC_OOM;
    }
    img->FrameCount = 1;
    img->InfoFrame = 0;
    img->DecodedFrame = 0;
    img->Format = PVF_BMP;
    // feature 111: a device-dependent bitmap (clipboard, capture, scan) is 24-bit color, opaque
    img->Src.Colors = PV_COLOR_TC24;
    img->Src.ColorModel = PVCM_RGB;
    img->Src.BitsPerPixel = 24;
    img->Src.HasAlpha = FALSE;
    img->SrcFrame = 0;
    return PVC_OK;
}

//*****************************************************************************
//
// Frame info + decode
//

// fill frame dimensions/DPI for 'frame' without a full decode
static PVCODE QueryFrameInfo(CWicImage* img, UINT frame, UINT* w, UINT* h)
{
    if (img->Decoder == NULL) // attached bitmap
    {
        *w = img->Width;
        *h = img->Height;
        return PVC_OK;
    }
    if (frame >= img->FrameCount)
        return PVC_NO_MORE_IMAGES;
    IWICBitmapFrameDecode* fr = NULL;
    if (FAILED(img->Decoder->GetFrame(frame, &fr)))
        return PVC_READING_ERROR;
    UINT fw = 0, fh = 0;
    fr->GetSize(&fw, &fh);
    double dx = 0, dy = 0;
    fr->GetResolution(&dx, &dy);
    fr->Release();
    if (fw == 0 || fh == 0)
        return PVC_INVALID_DIMENSIONS;
    img->DpiX = dx > 1 ? (DWORD)(dx + 0.5) : 96;
    img->DpiY = dy > 1 ? (DWORD)(dy + 0.5) : 96;
    *w = fw;
    *h = fh;
    return PVC_OK;
}

// decode 'frame' into the context DIB (PBGRA composited over BkColor)
static PVCODE DecodeFrame(CWicImage* img, int frame, TProgressProc progress, void* appSpecific)
{
    if (img->Decoder == NULL) // attached bitmap is always "decoded"
        return img->DecodedFrame >= 0 ? PVC_OK : PVC_INVALID_HANDLE;
    if (frame < 0)
        frame = 0;
    if ((UINT)frame >= img->FrameCount)
        return PVC_NO_MORE_IMAGES;
    if (img->DecodedFrame == frame)
        return PVC_OK;

    IWICImagingFactory* factory = GetWicFactory();
    if (factory == NULL)
        return PVC_EXCEPTION;

    // PictView's TProgressProc returns TRUE to CANCEL (e.g. the user pressed a
    // page/file-navigation key) and FALSE to continue - the opposite of the
    // header's "return FALSE to cancel" comment. Honor a real cancel before we
    // start decoding; the inverted check here was skipping the very first draw,
    // leaving the window blank until a resize/zoom forced a repaint.
    if (progress != NULL && progress(0, appSpecific))
        return PVC_CANCELED;

    IWICBitmapFrameDecode* fr = NULL;
    if (FAILED(img->Decoder->GetFrame(frame, &fr)))
        return PVC_READING_ERROR;

    IWICFormatConverter* conv = NULL;
    HRESULT hr = factory->CreateFormatConverter(&conv);
    if (SUCCEEDED(hr))
        hr = conv->Initialize(fr, GUID_WICPixelFormat32bppPBGRA, WICBitmapDitherTypeNone,
                              NULL, 0.0, WICBitmapPaletteTypeCustom);
    UINT w = 0, h = 0;
    if (SUCCEEDED(hr))
        hr = fr->GetSize(&w, &h);
    double dx = 0, dy = 0;
    if (SUCCEEDED(hr))
        fr->GetResolution(&dx, &dy);

    PVCODE code = PVC_OK;
    if (FAILED(hr) || w == 0 || h == 0)
        code = (hr == E_OUTOFMEMORY) ? PVC_OOM : PVC_READING_ERROR;
    else if (!AllocDib(img, (int)w, (int)h))
        code = PVC_OOM;
    else
    {
        hr = conv->CopyPixels(NULL, w * 4, w * 4 * h, img->DibBits);
        if (FAILED(hr))
        {
            FreeDib(img);
            code = (hr == E_OUTOFMEMORY) ? PVC_OOM : PVC_READING_ERROR;
        }
    }
    if (conv != NULL)
        conv->Release();
    fr->Release();
    if (code != PVC_OK)
        return code;

    img->AlphaUsed = CompositeOverBackground(img); // feature 111: the alpha channel really used?
    img->AlphaFrame = frame;
    if (!BuildLines(img))
    {
        FreeDib(img);
        return PVC_OOM;
    }
    img->DpiX = dx > 1 ? (DWORD)(dx + 0.5) : 96;
    img->DpiY = dy > 1 ? (DWORD)(dy + 0.5) : 96;
    img->DecodedFrame = frame;
    img->InfoFrame = (UINT)frame;
    img->Turns = 0; // feature 120: as decoded

    // decode is complete; report 100% but never abort a finished frame (a late
    // cancel must not suppress drawing the image we already have in the DIB)
    if (progress != NULL)
        progress(100, appSpecific);
    return PVC_OK;
}

//*****************************************************************************
//
// Thumbnail fast path (feature 064, contract C4)
//

// convert an arbitrary WIC source into the context DIB (PBGRA composited over
// BkColor); shared by the embedded-thumbnail and reduced-decode paths
static PVCODE DecodeSourceToDib(CWicImage* img, IWICBitmapSource* src)
{
    IWICImagingFactory* factory = GetWicFactory();
    if (factory == NULL)
        return PVC_EXCEPTION;
    UINT w = 0, h = 0;
    if (FAILED(src->GetSize(&w, &h)) || w == 0 || h == 0)
        return PVC_READING_ERROR;
    IWICFormatConverter* conv = NULL;
    HRESULT hr = factory->CreateFormatConverter(&conv);
    if (SUCCEEDED(hr))
        hr = conv->Initialize(src, GUID_WICPixelFormat32bppPBGRA, WICBitmapDitherTypeNone,
                              NULL, 0.0, WICBitmapPaletteTypeCustom);
    PVCODE code = PVC_OK;
    if (FAILED(hr))
        code = (hr == E_OUTOFMEMORY) ? PVC_OOM : PVC_READING_ERROR;
    else if (!AllocDib(img, (int)w, (int)h))
        code = PVC_OOM;
    else
    {
        hr = conv->CopyPixels(NULL, w * 4, w * 4 * h, img->DibBits);
        if (FAILED(hr))
        {
            FreeDib(img);
            code = (hr == E_OUTOFMEMORY) ? PVC_OOM : PVC_READING_ERROR;
        }
    }
    if (conv != NULL)
        conv->Release();
    if (code == PVC_OK)
        CompositeOverBackground(img);
    return code;
}

// embedded decoder thumbnail (typically the EXIF preview, ~160x120): orders of
// magnitude cheaper than any decode; may be smaller than the requested box
static PVCODE TryEmbeddedThumbnail(CWicImage* img, IWICBitmapFrameDecode* fr,
                                   int maxW, int maxH, int* onlyPreview)
{
    IWICBitmapSource* th = NULL;
    if (FAILED(fr->GetThumbnail(&th)) || th == NULL)
        return PVC_UNSUP_FILE_TYPE;
    UINT w = 0, h = 0;
    th->GetSize(&w, &h);
    PVCODE code = (w == 0 || h == 0) ? PVC_READING_ERROR : DecodeSourceToDib(img, th);
    th->Release();
    if (code == PVC_OK)
        *onlyPreview = (w < (UINT)maxW && h < (UINT)maxH); // same rule the driver uses
    return code;
}

// reduced-resolution decode through IWICBitmapSourceTransform (JPEG decodes in
// the DCT domain at 1/2..1/8): full final quality at a fraction of the cost
static PVCODE TryReducedDecode(CWicImage* img, IWICBitmapFrameDecode* fr,
                               int maxW, int maxH, UINT fullW, UINT fullH)
{
    IWICImagingFactory* factory = GetWicFactory();
    if (factory == NULL)
        return PVC_EXCEPTION;

    IWICBitmapSourceTransform* st = NULL;
    if (FAILED(fr->QueryInterface(IID_PPV_ARGS(&st))) || st == NULL)
        return PVC_UNSUP_FILE_TYPE;

    PVCODE code = PVC_UNSUP_FILE_TYPE;
    // largest power-of-two reduction whose result still covers the box
    UINT n = 1;
    while (n < 8 && fullW / (n * 2) >= (UINT)maxW && fullH / (n * 2) >= (UINT)maxH)
        n *= 2;
    UINT w = fullW / n;
    UINT h = fullH / n;
    if (n > 1 && SUCCEEDED(st->GetClosestSize(&w, &h)) &&
        w != 0 && h != 0 && (w < fullW || h < fullH))
    {
        WICPixelFormatGUID fmt = GUID_WICPixelFormat32bppPBGRA;
        UINT bpp = 0;
        if (SUCCEEDED(st->GetClosestPixelFormat(&fmt)))
        {
            IWICComponentInfo* ci = NULL;
            if (SUCCEEDED(factory->CreateComponentInfo(fmt, &ci)) && ci != NULL)
            {
                IWICPixelFormatInfo* pfi = NULL;
                if (SUCCEEDED(ci->QueryInterface(IID_PPV_ARGS(&pfi))) && pfi != NULL)
                {
                    pfi->GetBitsPerPixel(&bpp);
                    pfi->Release();
                }
                ci->Release();
            }
        }
        if (bpp >= 8)
        {
            UINT stride = (w * bpp + 7) / 8;
            stride = (stride + 3) & ~3u; // DWORD-aligned rows for CreateBitmapFromMemory
            UINT size = stride * h;
            BYTE* buf = (BYTE*)malloc(size);
            if (buf != NULL)
            {
                HRESULT hr = st->CopyPixels(NULL, w, h, &fmt, WICBitmapTransformRotate0,
                                            stride, size, buf);
                if (SUCCEEDED(hr))
                {
                    IWICBitmap* bmp = NULL;
                    hr = factory->CreateBitmapFromMemory(w, h, fmt, stride, size, buf, &bmp);
                    if (SUCCEEDED(hr) && bmp != NULL)
                    {
                        code = DecodeSourceToDib(img, bmp);
                        bmp->Release();
                    }
                }
                free(buf);
            }
            else
                code = PVC_OOM;
        }
    }
    st->Release();
    return code;
}

DWORD WicPrepareThumbnailSource(void* hPVImage, int maxW, int maxH, int fastMode,
                                DWORD* effWidth, DWORD* effHeight, int* onlyPreview)
{
    CWicImage* img = (CWicImage*)hPVImage;
    *onlyPreview = FALSE;
    if (img == NULL || maxW <= 0 || maxH <= 0)
        return PVC_INVALID_HANDLE;
    if (img->Decoder == NULL || img->DecodedFrame >= 0)
    {
        // attached bitmap or already decoded: report what is there
        if (img->DibBits == NULL)
            return PVC_INVALID_HANDLE;
        *effWidth = img->Width;
        *effHeight = img->Height;
        return PVC_OK;
    }

    IWICBitmapFrameDecode* fr = NULL;
    if (FAILED(img->Decoder->GetFrame(0, &fr)) || fr == NULL)
        return PVC_READING_ERROR;
    UINT fullW = 0, fullH = 0;
    fr->GetSize(&fullW, &fullH);

    PVCODE code = PVC_UNSUP_FILE_TYPE;
    if (fastMode)
        code = TryEmbeddedThumbnail(img, fr, maxW, maxH, onlyPreview);
    if (code != PVC_OK)
    {
        *onlyPreview = FALSE;
        code = TryReducedDecode(img, fr, maxW, maxH, fullW, fullH);
    }
    fr->Release();
    if (code != PVC_OK && code != PVC_OOM)
        return code; // caller silently keeps the classic full-decode path
    if (code != PVC_OK)
        return code;

    if (!BuildLines(img)) // keep the handle fully usable (pipette path expects Lines)
    {
        FreeDib(img);
        return PVC_OOM;
    }
    img->DecodedFrame = 0; // PVSaveImage's DecodeFrame becomes a no-op
    img->Turns = 0;        // feature 120: the reduced image as decoded
    img->InfoFrame = 0;
    *effWidth = (DWORD)img->Width;
    *effHeight = (DWORD)img->Height;
    return PVC_OK;
}

int WicGetExifOrientation(void* hPVImage)
{
    CWicImage* img = (CWicImage*)hPVImage;
    if (img == NULL || img->Decoder == NULL)
        return 0;
    IWICBitmapFrameDecode* fr = NULL;
    if (FAILED(img->Decoder->GetFrame(0, &fr)) || fr == NULL)
        return 0;
    int orient = 0;
    IWICMetadataQueryReader* q = NULL;
    if (SUCCEEDED(fr->GetMetadataQueryReader(&q)) && q != NULL)
    {
        PROPVARIANT v;
        PropVariantInit(&v);
        // JPEG stores the IFD under APP1; TIFF-family containers at the root
        if (SUCCEEDED(q->GetMetadataByName(L"/app1/ifd/{ushort=274}", &v)) ||
            SUCCEEDED(q->GetMetadataByName(L"/ifd/{ushort=274}", &v)))
        {
            if (v.vt == VT_UI2)
                orient = v.uiVal;
            else if (v.vt == VT_UI4)
                orient = (int)v.ulVal;
        }
        PropVariantClear(&v);
        q->Release();
    }
    fr->Release();
    return (orient >= 1 && orient <= 8) ? orient : 0;
}

// blit the decoded (already composited) DIB to 'dc' with the image origin at
// (X, Y), honoring the stretch/mirror state, clipped to 'clip' when given
static PVCODE BlitTo(CWicImage* img, HDC dc, int X, int Y, const RECT* clip)
{
    if (img->HDib == NULL)
        return PVC_INVALID_HANDLE;
    int dw = img->StretchW != 0 ? abs(img->StretchW) : img->Width;
    int dh = img->StretchH != 0 ? abs(img->StretchH) : img->Height;
    BOOL mirH = img->StretchW < 0;
    BOOL mirV = img->StretchH < 0;

    int saved = SaveDC(dc);
    if (clip != NULL)
        IntersectClipRect(dc, clip->left, clip->top, clip->right, clip->bottom);
    SetStretchBltMode(dc, img->StretchMode != 0 ? img->StretchMode : COLORONCOLOR);

    HDC mem = CreateCompatibleDC(dc);
    PVCODE code = PVC_GDI_ERROR;
    if (mem != NULL)
    {
        HGDIOBJ old = SelectObject(mem, img->HDib);
        if (StretchBlt(dc, X, Y, dw, dh, mem,
                       mirH ? img->Width - 1 : 0, mirV ? img->Height - 1 : 0,
                       mirH ? -img->Width : img->Width, mirV ? -img->Height : img->Height,
                       SRCCOPY))
            code = PVC_OK;
        SelectObject(mem, old);
        DeleteDC(mem);
    }
    RestoreDC(dc, saved);
    return code;
}

//*****************************************************************************
//
// PVImageInfo filling
//

static const char* FormatShortName(DWORD pvf)
{
    switch (pvf)
    {
    case PVF_JPG:
        return "JPEG";
    case PVF_PNG:
        return "PNG";
    case PVF_BMP:
        return "BMP";
    case PVF_GIF:
        return "GIF";
    case PVF_TIFF:
        return "TIFF";
    case PVF_ICO:
        return "ICO";
    }
    return "WIC";
}

static void FillInfo(CWicImage* img, UINT frame, UINT w, UINT h, LPPVImageInfo out, int cbSize)
{
    PVImageInfo pv;
    memset(&pv, 0, sizeof(pv));
    pv.cbSize = sizeof(pv);
    pv.Width = w;
    pv.Height = h;
    pv.BytesPerLine = w * 4;
    pv.FileSize = img->FileSize;
    pv.Colors = PV_COLOR_TC32;
    pv.Format = img->Format;
    pv.Flags = 0; // no PVFF_IMAGESEQUENCE in v1 (animation shows frame 0)
    pv.ColorModel = PVCM_RGB;
    pv.NumOfImages = img->FrameCount != 0 ? img->FrameCount : 1;
    pv.CurrentImage = frame;
    lstrcpynA(pv.Info1, FormatShortName(img->Format), PV_MAX_INFO_LEN);
    pv.StretchedWidth = img->StretchW != 0 ? abs(img->StretchW) : w;
    pv.StretchedHeight = img->StretchH != 0 ? abs(img->StretchH) : h;
    pv.StretchMode = img->StretchMode;
    pv.HorDPI = img->DpiX != 0 ? img->DpiX : 96;
    pv.VerDPI = img->DpiY != 0 ? img->DpiY : 96;
    pv.FSI = NULL;
    pv.Compression = PVCS_DEFAULT;
    pv.CommentSize = 0;
    pv.Comment = NULL;
    pv.TotalBitDepth = 24;

    if (out != NULL && cbSize > 0)
        memcpy(out, &pv, min((size_t)cbSize, sizeof(pv)));
}

//*****************************************************************************
//
// Engine entry points (table implementations)
//

static PVCODE WINAPI WicOpenImageEx(LPPVHandle* Img, LPPVOpenImageExInfo oi, LPPVImageInfo pInfo, int cbSize)
{
    if (Img == NULL || oi == NULL)
        return PVC_INCORRECT_PARAMETER;
    *Img = NULL;

    CWicImage* img = (CWicImage*)calloc(1, sizeof(CWicImage));
    if (img == NULL)
        return PVC_OOM;
    img->DecodedFrame = -1;
    img->SrcFrame = -1;   // feature 111
    img->AlphaFrame = -1; // feature 111
    img->FrameCount = 1;
    img->BkColor = RGB(255, 255, 255);
    img->StretchMode = COLORONCOLOR;
    img->DpiX = img->DpiY = 96;

    PVCODE code;
    if (oi->Flags & PVOF_ATTACH_TO_HANDLE)
        code = AttachBitmap(img, (HBITMAP)oi->Handle);
    else if (oi->Flags & PVOF_USERDEFINED_INPUT)
        code = OpenFromCallbacks(img, oi->ReadFunc, oi->SeekFunc, (void*)oi->Handle, oi->DataSize);
    else if (oi->FileName != NULL)
        code = OpenFromFileU8(img, oi->FileName); // FileName carries UTF-8 (feature 006)
    else
        code = PVC_INCORRECT_PARAMETER;

    UINT w = 0, h = 0;
    if (code == PVC_OK && img->Decoder != NULL)
    {
        UINT frames = 0;
        if (FAILED(img->Decoder->GetFrameCount(&frames)) || frames == 0)
            code = PVC_UNKNOWN_FILE_STRUCT;
        else
        {
            img->FrameCount = frames;
            GUID container;
            const char* shortName;
            if (SUCCEEDED(img->Decoder->GetContainerFormat(&container)))
                img->Format = MapContainerToPVF(container, &shortName);
            code = QueryFrameInfo(img, 0, &w, &h);
        }
    }
    else if (code == PVC_OK) // attached bitmap
    {
        w = img->Width;
        h = img->Height;
    }

    if (code != PVC_OK)
    {
        DestroyWicImage(img);
        return code;
    }
    img->InfoFrame = 0;
    FillInfo(img, 0, w, h, pInfo, cbSize);
    *Img = (LPPVHandle)img;
    return PVC_OK;
}

static PVCODE WINAPI WicGetImageInfo(LPPVHandle Img, LPPVImageInfo pInfo, int cbSize, int ImageIndex)
{
    CWicImage* img = (CWicImage*)Img;
    if (img == NULL || pInfo == NULL)
        return PVC_INVALID_HANDLE;
    if (ImageIndex < 0)
        ImageIndex = 0;
    UINT w, h;
    if (img->DecodedFrame == ImageIndex)
    {
        // report the decoded (possibly rotated) dimensions
        w = img->Width;
        h = img->Height;
    }
    else
    {
        PVCODE code = QueryFrameInfo(img, (UINT)ImageIndex, &w, &h);
        if (code != PVC_OK)
            return code;
    }
    img->InfoFrame = (UINT)ImageIndex;
    FillInfo(img, (UINT)ImageIndex, w, h, pInfo, cbSize);
    return PVC_OK;
}

static PVCODE WINAPI WicReadImage2(LPPVHandle Img, HDC PaintDC, RECT* pDRect,
                                   TProgressProc Progress, void* AppSpecific, int ImageIndex)
{
    CWicImage* img = (CWicImage*)Img;
    if (img == NULL)
        return PVC_INVALID_HANDLE;
    PVCODE code = DecodeFrame(img, ImageIndex, Progress, AppSpecific);
    if (code != PVC_OK)
        return code;
    if (PaintDC != NULL)
    {
        // the viewer passes the image's on-screen rectangle; its top-left is
        // the image origin (render1.cpp OnPaint first-load path)
        int x = pDRect != NULL ? pDRect->left : 0;
        int y = pDRect != NULL ? pDRect->top : 0;
        code = BlitTo(img, PaintDC, x, y, pDRect);
    }
    return code;
}

static PVCODE WINAPI WicDrawImage(LPPVHandle Img, HDC PaintDC, int X, int Y, LPRECT rect)
{
    CWicImage* img = (CWicImage*)Img;
    if (img == NULL || PaintDC == NULL)
        return PVC_INVALID_HANDLE;
    if (img->HDib == NULL)
    {
        // background colour changed after decode (or draw before read):
        // re-decode the current info frame without progress UI
        PVCODE code = DecodeFrame(img, (int)img->InfoFrame, NULL, NULL);
        if (code != PVC_OK)
            return code;
    }
    return BlitTo(img, PaintDC, X, Y, rect);
}

static PVCODE WINAPI WicSetStretchParameters(LPPVHandle Img, DWORD Width, DWORD Height, DWORD Mode)
{
    CWicImage* img = (CWicImage*)Img;
    if (img == NULL)
        return PVC_INVALID_HANDLE;
    img->StretchW = (int)Width;  // negative encodes horizontal mirror
    img->StretchH = (int)Height; // negative encodes vertical mirror
    img->StretchMode = Mode;
    return PVC_OK;
}

static void RedecodeTurned(CWicImage* img); // feature 120

static PVCODE WINAPI WicSetBkHandle(LPPVHandle Img, COLORREF BkColor)
{
    CWicImage* img = (CWicImage*)Img;
    if (img == NULL)
        return PVC_INVALID_HANDLE;
    if (img->BkColor != BkColor)
    {
        img->BkColor = BkColor;
        // alpha was flattened against the old colour - re-decode lazily; a turned frame now, turned
        // again (feature 120)
        if (img->Decoder != NULL && img->DecodedFrame >= 0)
        {
            if (img->Turns == 0 || img->HDib == NULL)
                FreeDib(img);
            else
                RedecodeTurned(img);
        }
    }
    return PVC_OK;
}

static PVCODE WINAPI WicCloseImage(LPPVHandle Img)
{
    if (Img != NULL)
        DestroyWicImage((CWicImage*)Img);
    return PVC_OK;
}

static const char* WINAPI WicGetErrorText(DWORD ErrorCode)
{
    switch ((PVCODE)ErrorCode)
    {
    case PVC_OK:
        return "No error.";
    case PVC_OOM:
    case PVC_OUT_OF_MEMORY:
        return "Not enough memory to process the image.";
    case PVC_CANCELED:
        return "Operation was canceled.";
    case PVC_INVALID_HANDLE:
        return "Invalid image handle.";
    case PVC_GDI_ERROR:
        return "A graphics (GDI) operation failed.";
    case PVC_NO_MORE_IMAGES:
        return "No more images in the file.";
    case PVC_CANNOT_OPEN_FILE:
        return "The file cannot be opened.";
    case PVC_UNSUP_FILE_TYPE:
        return "This image is in a format that is not supported by the built-in Windows imaging component.";
    case PVC_UNKNOWN_FILE_STRUCT:
        return "The image file is damaged or has an unknown structure.";
    case PVC_READING_ERROR:
        return "An error occurred while reading or decoding the image.";
    case PVC_INVALID_DIMENSIONS:
        return "The image has invalid dimensions.";
    case PVC_INCORRECT_PARAMETER:
        return "Incorrect parameter.";
    case PVC_UNSUP_OUT_PARAMS:
        return "This operation is not supported by the built-in image engine.";
    case PVC_WRITING_ERROR:
        return "The image could not be written.";
    }
    return "Unknown image engine error.";
}

static DWORD WINAPI WicGetDLLVersion(void)
{
    return (1 << 16) | 0; // built-in WIC engine 1.00
}

static PVCODE WINAPI WicSetParam(LPPVHandle Img)
{
    // the proprietary engine registered a text callback here; no-op for WIC
    UNREFERENCED_PARAMETER(Img);
    return PVC_OK;
}

//*****************************************************************************
//
// Lossless rotation (kept real so EXIF auto-rotate works)
//

// turns the image in the DIB by 90 degrees (PVCF_ROTATE90CW or PVCF_ROTATE90CCW)
static PVCODE RotateDib(CWicImage* img, DWORD Flags)
{
    int w = img->Width;
    int h = img->Height;
    BITMAPINFO bi;
    memset(&bi, 0, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = h; // swapped
    bi.bmiHeader.biHeight = -w;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    void* newBits = NULL;
    HBITMAP newDib = CreateDIBSection(NULL, &bi, DIB_RGB_COLORS, &newBits, NULL, 0);
    if (newDib == NULL || newBits == NULL)
        return PVC_OOM;

    const DWORD* src = (const DWORD*)img->DibBits;
    DWORD* dst = (DWORD*)newBits;
    int y;
    for (y = 0; y < h; y++)
    {
        const DWORD* srcRow = src + (size_t)y * w;
        if (Flags == PVCF_ROTATE90CW)
        {
            // (x, y) -> (h-1-y, x): column h-1-y of the new image
            DWORD* dstCol = dst + (h - 1 - y);
            int x;
            for (x = 0; x < w; x++)
                dstCol[(size_t)x * h] = srcRow[x];
        }
        else
        {
            // (x, y) -> (y, w-1-x)
            DWORD* dstCol = dst + (size_t)(w - 1) * h + y;
            int x;
            for (x = 0; x < w; x++)
                dstCol[-(LONG_PTR)x * h] = srcRow[x];
        }
    }

    DeleteObject(img->HDib);
    img->HDib = newDib;
    img->DibBits = (BYTE*)newBits;
    img->Width = h;
    img->Height = w;
    DWORD dpi = img->DpiX;
    img->DpiX = img->DpiY;
    img->DpiY = dpi;
    if (!BuildLines(img))
    {
        FreeDib(img);
        return PVC_OOM;
    }
    return PVC_OK;
}

static PVCODE WINAPI WicChangeImage(LPPVHandle Img, DWORD Flags)
{
    CWicImage* img = (CWicImage*)Img;
    if (img == NULL)
        return PVC_INVALID_HANDLE;
    if (Flags != PVCF_ROTATE90CW && Flags != PVCF_ROTATE90CCW)
        return PVC_UNSUP_OUT_PARAMS;
    if (img->HDib == NULL)
    {
        PVCODE code = DecodeFrame(img, (int)img->InfoFrame, NULL, NULL);
        if (code != PVC_OK)
            return code;
    }
    PVCODE code = RotateDib(img, Flags);
    if (code == PVC_OK)
        img->Turns = (img->Turns + (Flags == PVCF_ROTATE90CW ? 1 : 3)) & 3; // feature 120
    return code;
}

// Feature 120 (recorded by 105): another background color needs the frame decoded again - its alpha
// was flattened over the old color. It used to be decoded lazily from the file, and the viewer's
// rotations went with the old image: the viewer kept the turned size, so the image was drawn
// squeezed and saved unturned (also the pipette's rows were then of another size). A turned frame is
// decoded again now and turned again; when that fails, the old image stays (over the old color).
static void RedecodeTurned(CWicImage* img)
{
    HBITMAP oldDib = img->HDib;
    BYTE* oldBits = img->DibBits;
    BYTE** oldLines = img->Lines;
    int oldW = img->Width, oldH = img->Height;
    DWORD oldDpiX = img->DpiX, oldDpiY = img->DpiY;
    int frame = img->DecodedFrame;
    UINT info = img->InfoFrame;
    int turns = img->Turns;
    BOOL alphaUsed = img->AlphaUsed;
    int alphaFrame = img->AlphaFrame;
    img->HDib = NULL; // AllocDib must not free the old image
    img->DibBits = NULL;
    img->Lines = NULL;
    img->DecodedFrame = -1;
    PVCODE code = DecodeFrame(img, frame, NULL, NULL);
    int t;
    for (t = 0; code == PVC_OK && t < (turns == 3 ? 1 : turns); t++)
        code = RotateDib(img, turns == 3 ? PVCF_ROTATE90CCW : PVCF_ROTATE90CW);
    if (code == PVC_OK)
    {
        DeleteObject(oldDib);
        free(oldLines);
        img->InfoFrame = info;
        img->Turns = turns;
        return;
    }
    FreeDib(img); // what was decoded or turned of the new image
    img->HDib = oldDib;
    img->DibBits = oldBits;
    img->Lines = oldLines;
    img->Width = oldW;
    img->Height = oldH;
    img->DpiX = oldDpiX;
    img->DpiY = oldDpiY;
    img->DecodedFrame = frame;
    img->InfoFrame = info;
    img->Turns = turns;
    img->AlphaUsed = alphaUsed;
    img->AlphaFrame = alphaFrame;
}

//*****************************************************************************
//
// Pixel access for the pipette / histogram tools
//

static PVCODE WINAPI WicGetHandles2(LPPVHandle Img, LPPVImageHandles* pHandles)
{
    CWicImage* img = (CWicImage*)Img;
    if (img == NULL || pHandles == NULL)
        return PVC_INVALID_HANDLE;
    if (img->HDib == NULL)
    {
        PVCODE code = DecodeFrame(img, (int)img->InfoFrame, NULL, NULL);
        if (code != PVC_OK)
            return code;
    }
    memset(&img->Handles, 0, sizeof(img->Handles));
    img->Handles.pLines = img->Lines;
    img->Handles.Palette = NULL;
    *pHandles = &img->Handles;
    return PVC_OK;
}

//*****************************************************************************
//
// Raw pixel export - backs the panel-thumbnail path (feature 048)
//

// The panel thumbnail loader (thumbs.cpp CreateThumbnail) asks PVSaveImage
// for the decoded image as raw 32bpp rows pushed through pSii->WriteFunc at
// natural size; the core's CSalamanderThumbnailMaker does the shrinking.
// Exactly that subset is implemented here. File output, encoder formats,
// scaling and cropping stay unsupported, so print preview, the wallpaper
// commands and the batch JPEG thumbnail operation keep their pre-048 behavior
// (PVC_UNSUP_OUT_PARAMS). Save As does not come here since feature 105: it
// encodes through WicEncodeImageToFile into a temporary file.
static PVCODE WINAPI WicSaveImage(LPPVHandle Img, const char* OutFName, LPPVSaveImageInfo pSii,
                                  TProgressProc Progress, void* AppSpecific, int ImageIndex)
{
    UNREFERENCED_PARAMETER(OutFName); // user-defined output only

    CWicImage* img = (CWicImage*)Img;
    if (img == NULL)
        return PVC_INVALID_HANDLE;
    if (pSii == NULL)
        return PVC_INCORRECT_PARAMETER;

    // Salamander-proprietary decode-speed hint set by thumbs.cpp for heavily
    // oversized images (PVSF_SUPERFAST there); accepted and ignored
    const DWORD PVSF_SUPERFAST_HINT = 0x8000000;

    if ((pSii->Flags & PVSF_USERDEFINED_OUTPUT) == 0 || pSii->WriteFunc == NULL ||
        pSii->Format != PVF_RAW || pSii->Colors != PV_COLOR_TC32 ||
        pSii->Width != 0 || pSii->Height != 0 ||         // no scaling in this subset
        pSii->CropWidth != 0 || pSii->CropHeight != 0 || // no cropping either
        (pSii->Flags & ~(PVSF_USERDEFINED_OUTPUT | PVSF_FLIP_VERT | PVSF_SUPERFAST_HINT)) != 0)
        return PVC_UNSUP_OUT_PARAMS;

    // decoded rows are opaque BGRX composited over BkColor - the exact
    // PV_COLOR_TC32 row layout the consumer expects (see print.cpp usage)
    PVCODE code = DecodeFrame(img, ImageIndex, Progress, AppSpecific);
    if (code != PVC_OK)
        return code;
    if (img->DibBits == NULL || img->Width <= 0 || img->Height <= 0)
        return PVC_INVALID_DIMENSIONS;

    DWORD stride = (DWORD)img->Width * 4;
    // whole rows per WriteFunc call; bounded batches keep the consumer's
    // cancellation (short write) responsive on large images
    int rowsPerBatch = (int)(256 * 1024 / stride);
    if (rowsPerBatch < 1)
        rowsPerBatch = 1;
    BOOL flip = (pSii->Flags & PVSF_FLIP_VERT) != 0;
    if (flip)
        rowsPerBatch = 1; // rows leave in reverse order -> one row per call

    int y = 0;
    while (y < img->Height)
    {
        // between batches only: the consumer's progress hook probes its own
        // completion state and would report a false error after the last row
        if (y > 0 && Progress != NULL && Progress(MulDiv(y, 100, img->Height), AppSpecific))
            return PVC_OK; // consumer cancel; it judges completeness itself

        int rows = min(rowsPerBatch, img->Height - y);
        BYTE* p = img->DibBits + (size_t)(flip ? img->Height - y - 1 : y) * stride;
        DWORD bytes = (DWORD)rows * stride;
        if (pSii->WriteFunc(AppSpecific, p, bytes) != bytes)
        {
            // short write is the normal end: the thumbnail maker returns FALSE
            // (-> 0 bytes) both on cancellation and after consuming the final
            // rows, and ThumbnailReady() arbitrates which one it was
            return PVC_OK;
        }
        y += rows;
    }
    return PVC_OK;
}

//*****************************************************************************
//
// Save As through the Windows encoders (feature 105)
//
// Feature 006 left Save As without an encoder: PVSaveImage refused every file output,
// so Save As always ended with "Unable to save the image" - after it had deleted an
// existing target (fixed on the caller's side, saveas.cpp). The Windows Imaging
// Component writes BMP, PNG, JPEG, GIF and TIFF; the table below is what the Save As
// dialog offers for them (measured: specs/105-pictview-saveas-loss/research.md).

enum CWicOutPalette
{
    wopNone,    // no palette (gray, HiColor, TrueColor)
    wopOptimal, // the image's own colors (IWICPalette::InitializeFromBitmap)
    wopBW,      // black and white
    wopGray,    // 256 gray levels in an indexed format
};

struct CWicOutPlan
{
    GUID Container;
    WICPixelFormatGUID PixelFormat;
    CWicOutPalette Palette;
    UINT PaletteColors;  // wopOptimal
    int TiffCompression; // WICTiffCompressionOption, -1 = not TIFF
};

static void SetOutPlan(CWicOutPlan* plan, REFGUID pf, CWicOutPalette pal, UINT colors)
{
    plan->PixelFormat = pf;
    plan->Palette = pal;
    plan->PaletteColors = colors;
}

// what (format, compression, colors, color model) becomes; FALSE = not offered
static BOOL WicPlanOutput(DWORD format, DWORD compr, DWORD colors, DWORD colorModel, CWicOutPlan* plan)
{
    BOOL gray = colorModel == PVCM_GRAYS;
    enum
    {
        cdNone,
        cdBW,
        cd16,
        cd256,
        cdGray,
        cdHC15,
        cdHC16,
        cdTC24
    } cd = cdNone;
    switch (colors)
    {
    case 2:
        cd = cdBW;
        break;
    case 16:
        cd = gray ? cdNone : cd16;
        break;
    case 256:
        cd = gray ? cdGray : cd256;
        break;
    case PV_COLOR_HC15:
        cd = gray ? cdNone : cdHC15;
        break;
    case PV_COLOR_HC16:
        cd = gray ? cdNone : cdHC16;
        break;
    case PV_COLOR_TC24:
        cd = gray ? cdNone : cdTC24;
        break;
    }
    if (cd == cdNone)
        return FALSE;
    memset(plan, 0, sizeof(*plan));
    plan->TiffCompression = -1;
    switch (format)
    {
    case PVF_BMP: // no RLE in the Windows BMP encoder
        if (compr != PVCS_DEFAULT && compr != PVCS_NO_COMPRESSION)
            return FALSE;
        plan->Container = GUID_ContainerFormatBmp;
        switch (cd)
        {
        case cdBW:
            SetOutPlan(plan, GUID_WICPixelFormat1bppIndexed, wopBW, 2);
            return TRUE;
        case cd16:
            SetOutPlan(plan, GUID_WICPixelFormat4bppIndexed, wopOptimal, 16);
            return TRUE;
        case cd256:
            SetOutPlan(plan, GUID_WICPixelFormat8bppIndexed, wopOptimal, 256);
            return TRUE;
        case cdGray: // the BMP encoder has no 8bppGray (measured: it answers 8bppIndexed)
            SetOutPlan(plan, GUID_WICPixelFormat8bppIndexed, wopGray, 256);
            return TRUE;
        case cdHC15:
            SetOutPlan(plan, GUID_WICPixelFormat16bppBGR555, wopNone, 0);
            return TRUE;
        case cdHC16:
            SetOutPlan(plan, GUID_WICPixelFormat16bppBGR565, wopNone, 0);
            return TRUE;
        case cdTC24:
            SetOutPlan(plan, GUID_WICPixelFormat24bppBGR, wopNone, 0);
            return TRUE;
        }
        return FALSE;

    case PVF_PNG:
        if (compr != PVCS_DEFAULT && compr != PVCS_DEFLATE)
            return FALSE;
        plan->Container = GUID_ContainerFormatPng;
        switch (cd)
        {
        case cdBW:
            SetOutPlan(plan, GUID_WICPixelFormatBlackWhite, wopBW, 2);
            return TRUE;
        case cd16:
            SetOutPlan(plan, GUID_WICPixelFormat4bppIndexed, wopOptimal, 16);
            return TRUE;
        case cd256:
            SetOutPlan(plan, GUID_WICPixelFormat8bppIndexed, wopOptimal, 256);
            return TRUE;
        case cdGray:
            SetOutPlan(plan, GUID_WICPixelFormat8bppGray, wopNone, 0);
            return TRUE;
        case cdTC24:
            SetOutPlan(plan, GUID_WICPixelFormat24bppBGR, wopNone, 0);
            return TRUE;
        }
        return FALSE; // no 15/16-bit PNG

    case PVF_JPG:
        if (compr != PVCS_DEFAULT && compr != PVCS_JPEG_HUFFMAN)
            return FALSE;
        plan->Container = GUID_ContainerFormatJpeg;
        if (cd == cdGray)
        {
            SetOutPlan(plan, GUID_WICPixelFormat8bppGray, wopNone, 0);
            return TRUE;
        }
        if (cd == cdTC24)
        {
            SetOutPlan(plan, GUID_WICPixelFormat24bppBGR, wopNone, 0);
            return TRUE;
        }
        return FALSE;

    case PVF_GIF: // the GIF encoder takes 8bppIndexed only; the smaller palettes go into it
        if (compr != PVCS_DEFAULT && compr != PVCS_LZW)
            return FALSE;
        plan->Container = GUID_ContainerFormatGif;
        switch (cd)
        {
        case cdBW:
            SetOutPlan(plan, GUID_WICPixelFormat8bppIndexed, wopBW, 2);
            return TRUE;
        case cd16:
            SetOutPlan(plan, GUID_WICPixelFormat8bppIndexed, wopOptimal, 16);
            return TRUE;
        case cd256:
            SetOutPlan(plan, GUID_WICPixelFormat8bppIndexed, wopOptimal, 256);
            return TRUE;
        case cdGray:
            SetOutPlan(plan, GUID_WICPixelFormat8bppIndexed, wopGray, 256);
            return TRUE;
        }
        return FALSE;

    case PVF_TIFF:
    {
        // WICTiffCompressionOption: 0 don't care (= LZW), 1 none, 2 CCITT G3, 3 CCITT G4, 4 LZW,
        // 5 RLE (= PackBits, tag 259 = 32773, measured), 6 ZIP (= Deflate, tag 259 = 8)
        int opt;
        switch (compr)
        {
        case PVCS_DEFAULT:
            opt = 0;
            break;
        case PVCS_NO_COMPRESSION:
            opt = 1;
            break;
        case PVCS_CCITT_3:
            opt = 2;
            break;
        case PVCS_CCITT_4:
            opt = 3;
            break;
        case PVCS_LZW:
            opt = 4;
            break;
        case PVCS_PACKBITS:
            opt = 5;
            break;
        case PVCS_DEFLATE:
            opt = 6;
            break;
        default:
            return FALSE; // no JPEG in TIFF, no Huffman
        }
        if ((opt == 2 || opt == 3) && cd != cdBW)
            return FALSE; // CCITT is bilevel only (the encoder would turn anything into black and white)
        plan->Container = GUID_ContainerFormatTiff;
        plan->TiffCompression = opt;
        switch (cd)
        {
        case cdBW:
            SetOutPlan(plan, GUID_WICPixelFormatBlackWhite, wopBW, 2);
            return TRUE;
        case cd16:
            SetOutPlan(plan, GUID_WICPixelFormat4bppIndexed, wopOptimal, 16);
            return TRUE;
        case cd256:
            SetOutPlan(plan, GUID_WICPixelFormat8bppIndexed, wopOptimal, 256);
            return TRUE;
        case cdGray:
            SetOutPlan(plan, GUID_WICPixelFormat8bppGray, wopNone, 0);
            return TRUE;
        case cdTC24:
            SetOutPlan(plan, GUID_WICPixelFormat24bppBGR, wopNone, 0);
            return TRUE;
        }
        return FALSE; // no 15/16-bit TIFF
    }
    }
    return FALSE;
}

BOOL WicCanEncodeFormat(DWORD format)
{
    CWicOutPlan plan;
    return WicPlanOutput(format, PVCS_DEFAULT, PV_COLOR_TC24, PVCM_RGB, &plan) ||
           WicPlanOutput(format, PVCS_DEFAULT, 256, PVCM_GRAYS, &plan);
}

// The decoded frame (32bpp BGRX, top-down, opaque) as a WIC source, transformed on the fly:
// the flips first, then the rotation by 90 degrees clockwise (PVSF_ROTATE90 - the same turn as
// PVChangeImage's PVCF_ROTATE90CW), colors inverted on request. No copy of the image is made.
// Reports progress (and takes a cancel) every 16 rows it delivers; 'rowsTotal' is the number
// of rows all readers together ask for (the palette builder reads the image once more).
class CWicDibSource : public IWICBitmapSource
{
public:
    CWicDibSource(const CWicImage* img, DWORD flags, double dpiX, double dpiY,
                  BOOL(WINAPI* progress)(int, void*), void* appSpecific, ULONGLONG rowsTotal)
    {
        Refs = 1;
        Img = img;
        Rot90 = (flags & PVSF_ROTATE90) != 0;
        FlipH = (flags & PVSF_FLIP_HOR) != 0;
        FlipV = (flags & PVSF_FLIP_VERT) != 0;
        Invert = (flags & PVSF_INVERT) != 0;
        DpiX = dpiX;
        DpiY = dpiY;
        Progress = progress;
        AppSpecific = appSpecific;
        RowsTotal = rowsTotal;
        RowsDone = 0;
        Canceled = FALSE;
    }

    BOOL Canceled;

    UINT OutWidth() const { return (UINT)(Rot90 ? Img->Height : Img->Width); }
    UINT OutHeight() const { return (UINT)(Rot90 ? Img->Width : Img->Height); }

    STDMETHODIMP QueryInterface(REFIID riid, void** ppv)
    {
        if (ppv == NULL)
            return E_POINTER;
        if (IsEqualIID(riid, __uuidof(IUnknown)) || IsEqualIID(riid, __uuidof(IWICBitmapSource)))
        {
            *ppv = (IWICBitmapSource*)this;
            AddRef();
            return S_OK;
        }
        *ppv = NULL;
        return E_NOINTERFACE;
    }
    STDMETHODIMP_(ULONG)
    AddRef() { return (ULONG)InterlockedIncrement(&Refs); }
    STDMETHODIMP_(ULONG)
    Release()
    {
        LONG r = InterlockedDecrement(&Refs);
        if (r == 0)
            delete this;
        return (ULONG)r;
    }
    STDMETHODIMP GetSize(UINT* w, UINT* h)
    {
        if (w == NULL || h == NULL)
            return E_INVALIDARG;
        *w = OutWidth();
        *h = OutHeight();
        return S_OK;
    }
    STDMETHODIMP GetPixelFormat(WICPixelFormatGUID* pf)
    {
        if (pf == NULL)
            return E_INVALIDARG;
        *pf = GUID_WICPixelFormat32bppBGR;
        return S_OK;
    }
    STDMETHODIMP GetResolution(double* x, double* y)
    {
        if (x == NULL || y == NULL)
            return E_INVALIDARG;
        *x = DpiX;
        *y = DpiY;
        return S_OK;
    }
    STDMETHODIMP CopyPalette(IWICPalette* palette)
    {
        UNREFERENCED_PARAMETER(palette);
        return WINCODEC_ERR_PALETTEUNAVAILABLE;
    }
    STDMETHODIMP CopyPixels(const WICRect* prc, UINT stride, UINT bufSize, BYTE* buf)
    {
        UINT ow = OutWidth(), oh = OutHeight();
        WICRect r = {0, 0, (INT)ow, (INT)oh};
        if (prc != NULL)
            r = *prc;
        if (buf == NULL || r.X < 0 || r.Y < 0 || r.Width < 0 || r.Height < 0 ||
            (UINT)r.X + (UINT)r.Width > ow || (UINT)r.Y + (UINT)r.Height > oh)
            return E_INVALIDARG;
        if (r.Width == 0 || r.Height == 0)
            return S_OK;
        if ((ULONGLONG)stride < (ULONGLONG)r.Width * 4 ||
            (ULONGLONG)bufSize < (ULONGLONG)(r.Height - 1) * stride + (ULONGLONG)r.Width * 4)
            return WINCODEC_ERR_INSUFFICIENTBUFFER;
        const int w = Img->Width, h = Img->Height;
        const DWORD* src = (const DWORD*)Img->DibBits;
        const DWORD invert = Invert ? 0x00FFFFFF : 0;
        for (int oy = r.Y; oy < r.Y + r.Height; oy++)
        {
            DWORD* dst = (DWORD*)(buf + (size_t)(oy - r.Y) * stride);
            for (int ox = r.X; ox < r.X + r.Width; ox++)
            {
                int fx = ox, fy = oy; // a point of the flipped image
                if (Rot90)            // output (ox, oy) of a clockwise turn = flipped (oy, h-1-ox)
                {
                    fx = oy;
                    fy = h - 1 - ox;
                }
                int sx = FlipH ? w - 1 - fx : fx;
                int sy = FlipV ? h - 1 - fy : fy;
                *dst++ = (src[(size_t)sy * w + sx] ^ invert) | 0xFF000000;
            }
            RowsDone++;
            if (Progress != NULL && (RowsDone & 15) == 0)
            {
                int done = RowsTotal != 0 ? (int)min(99, RowsDone * 100 / RowsTotal) : 0;
                if (Progress(done, AppSpecific)) // TRUE = cancel (PictView's convention, see DecodeFrame)
                {
                    Canceled = TRUE;
                    return HRESULT_FROM_WIN32(ERROR_CANCELLED);
                }
            }
        }
        return S_OK;
    }

private:
    LONG Refs;
    const CWicImage* Img;
    BOOL Rot90, FlipH, FlipV, Invert;
    double DpiX, DpiY;
    BOOL(WINAPI* Progress)
    (int, void*);
    void* AppSpecific;
    ULONGLONG RowsTotal, RowsDone;
};

// IStream over an open file handle: the encoders write into the caller's (temporary) file;
// the first failing system call is kept so the user is told why (disk full, ...).
class CWicHandleStream : public IStream
{
public:
    CWicHandleStream(HANDLE file)
    {
        Refs = 1;
        File = file;
        LastError = 0;
    }

    DWORD LastError;

    STDMETHODIMP QueryInterface(REFIID riid, void** ppv)
    {
        if (ppv == NULL)
            return E_POINTER;
        if (IsEqualIID(riid, __uuidof(IUnknown)) || IsEqualIID(riid, __uuidof(ISequentialStream)) ||
            IsEqualIID(riid, __uuidof(IStream)))
        {
            *ppv = (IStream*)this;
            AddRef();
            return S_OK;
        }
        *ppv = NULL;
        return E_NOINTERFACE;
    }
    STDMETHODIMP_(ULONG)
    AddRef() { return (ULONG)InterlockedIncrement(&Refs); }
    STDMETHODIMP_(ULONG)
    Release()
    {
        LONG r = InterlockedDecrement(&Refs);
        if (r == 0)
            delete this;
        return (ULONG)r;
    }
    STDMETHODIMP Read(void* pv, ULONG cb, ULONG* pcbRead)
    {
        DWORD got = 0;
        if (!ReadFile(File, pv, cb, &got, NULL))
            return Fail();
        if (pcbRead != NULL)
            *pcbRead = got;
        return got < cb ? S_FALSE : S_OK;
    }
    STDMETHODIMP Write(const void* pv, ULONG cb, ULONG* pcbWritten)
    {
        DWORD written = 0;
        if (!WriteFile(File, pv, cb, &written, NULL))
            return Fail();
        if (pcbWritten != NULL)
            *pcbWritten = written;
        if (written != cb)
        {
            if (LastError == 0)
                LastError = ERROR_WRITE_FAULT;
            return STG_E_WRITEFAULT;
        }
        return S_OK;
    }
    STDMETHODIMP Seek(LARGE_INTEGER move, DWORD origin, ULARGE_INTEGER* newPos)
    {
        // STREAM_SEEK_SET/CUR/END have the values of FILE_BEGIN/CURRENT/END
        LARGE_INTEGER np;
        if (origin > STREAM_SEEK_END)
            return STG_E_INVALIDFUNCTION;
        if (!SetFilePointerEx(File, move, &np, origin))
            return Fail();
        if (newPos != NULL)
            newPos->QuadPart = (ULONGLONG)np.QuadPart;
        return S_OK;
    }
    STDMETHODIMP SetSize(ULARGE_INTEGER size)
    {
        LARGE_INTEGER zero, pos, to;
        zero.QuadPart = 0;
        to.QuadPart = (LONGLONG)size.QuadPart;
        if (!SetFilePointerEx(File, zero, &pos, FILE_CURRENT) || !SetFilePointerEx(File, to, NULL, FILE_BEGIN) ||
            !SetEndOfFile(File) || !SetFilePointerEx(File, pos, NULL, FILE_BEGIN))
            return Fail();
        return S_OK;
    }
    STDMETHODIMP CopyTo(IStream*, ULARGE_INTEGER, ULARGE_INTEGER*, ULARGE_INTEGER*) { return E_NOTIMPL; }
    STDMETHODIMP Commit(DWORD) { return S_OK; }
    STDMETHODIMP Revert() { return E_NOTIMPL; }
    STDMETHODIMP LockRegion(ULARGE_INTEGER, ULARGE_INTEGER, DWORD) { return STG_E_INVALIDFUNCTION; }
    STDMETHODIMP UnlockRegion(ULARGE_INTEGER, ULARGE_INTEGER, DWORD) { return STG_E_INVALIDFUNCTION; }
    STDMETHODIMP Stat(STATSTG* st, DWORD flags)
    {
        UNREFERENCED_PARAMETER(flags);
        if (st == NULL)
            return E_INVALIDARG;
        memset(st, 0, sizeof(*st));
        st->type = STGTY_STREAM;
        st->grfMode = STGM_READWRITE;
        LARGE_INTEGER size;
        if (!GetFileSizeEx(File, &size))
            return Fail();
        st->cbSize.QuadPart = (ULONGLONG)size.QuadPart;
        return S_OK;
    }
    STDMETHODIMP Clone(IStream** ppstm)
    {
        if (ppstm != NULL)
            *ppstm = NULL;
        return E_NOTIMPL;
    }

private:
    LONG Refs;
    HANDLE File;

    HRESULT Fail()
    {
        DWORD e = GetLastError();
        if (e == 0)
            e = ERROR_WRITE_FAULT;
        if (LastError == 0)
            LastError = e;
        return HRESULT_FROM_WIN32(e);
    }
};

// feature 111: the Windows JPEG encoder writes the comment segment (COM) with a NUL byte after the
// text (measured: "FF FE <len> <text> 00"); COM holds bytes, not a C string, and readers show the
// NUL. Takes it out of the complete file: the segment's length one less, the rest of the file one
// byte to the front. Touches nothing unless the first COM before the image data is exactly the
// comment of 'textLen' bytes plus that NUL (SalJpegCommentNul). Returns 0 or the system error.
static DWORD JpegDropCommentNul(HANDLE file, size_t textLen)
{
    auto lastError = []() -> DWORD
    {
        DWORD e = GetLastError();
        return e != 0 ? e : ERROR_WRITE_FAULT;
    };
    LARGE_INTEGER size;
    if (!GetFileSizeEx(file, &size))
        return lastError();
    BYTE head[4096];
    DWORD headLen = (DWORD)min((LONGLONG)sizeof(head), size.QuadPart);
    LARGE_INTEGER pos;
    pos.QuadPart = 0;
    DWORD got = 0;
    if (!SetFilePointerEx(file, pos, NULL, FILE_BEGIN) || !ReadFile(file, head, headLen, &got, NULL))
        return lastError();
    size_t lengthAt, nulAt;
    if (!SalJpegCommentNul(head, got, textLen, &lengthAt, &nulAt))
        return 0;
    // the shorter length, then everything after the NUL one byte to the front
    DWORD len = ((DWORD)head[lengthAt] << 8) | head[lengthAt + 1];
    BYTE newLen[2] = {(BYTE)((len - 1) >> 8), (BYTE)((len - 1) & 0xFF)};
    DWORD done = 0;
    pos.QuadPart = (LONGLONG)lengthAt;
    if (!SetFilePointerEx(file, pos, NULL, FILE_BEGIN) || !WriteFile(file, newLen, 2, &done, NULL) || done != 2)
        return lastError();
    BYTE buf[16384];
    LONGLONG from = (LONGLONG)nulAt + 1;
    while (from < size.QuadPart)
    {
        DWORD chunk = (DWORD)min((LONGLONG)sizeof(buf), size.QuadPart - from);
        pos.QuadPart = from;
        if (!SetFilePointerEx(file, pos, NULL, FILE_BEGIN) || !ReadFile(file, buf, chunk, &got, NULL) || got != chunk)
            return lastError();
        pos.QuadPart = from - 1;
        if (!SetFilePointerEx(file, pos, NULL, FILE_BEGIN) || !WriteFile(file, buf, chunk, &done, NULL) || done != chunk)
            return lastError();
        from += chunk;
    }
    pos.QuadPart = size.QuadPart - 1;
    if (!SetFilePointerEx(file, pos, NULL, FILE_BEGIN) || !SetEndOfFile(file))
        return lastError();
    return 0;
}

static HRESULT WriteEncoderOption(IPropertyBag2* bag, LPCOLESTR name, VARIANT* value)
{
    PROPBAG2 opt;
    memset(&opt, 0, sizeof(opt));
    opt.pstrName = (LPOLESTR)name;
    return bag->Write(1, &opt, value);
}

int WicEncodeImageToFile(void* hPVImage, int imageIndex, HANDLE hFile, const CWicEncodeParams* p,
                         BOOL(WINAPI* progress)(int done, void* appSpecific), void* appSpecific,
                         DWORD* win32Err)
{
    *win32Err = 0;
    CWicImage* img = (CWicImage*)hPVImage;
    if (img == NULL || p == NULL || hFile == INVALID_HANDLE_VALUE)
        return PVC_INVALID_HANDLE;
    CWicOutPlan plan;
    if (!WicPlanOutput(p->Format, p->Compression, p->Colors, p->ColorModel, &plan))
        return PVC_UNSUP_OUT_PARAMS;
    IWICImagingFactory* factory = GetWicFactory();
    if (factory == NULL)
        return PVC_EXCEPTION;
    // the frame as the viewer holds it: a rotation done in the viewer is in the DIB already
    PVCODE code = DecodeFrame(img, imageIndex < 0 ? 0 : imageIndex, NULL, NULL);
    if (code != PVC_OK)
        return code;
    if (img->DibBits == NULL || img->Width <= 0 || img->Height <= 0)
        return PVC_INVALID_DIMENSIONS;

    double dpiX = p->HorDPI != 0 ? p->HorDPI : 96;
    double dpiY = p->VerDPI != 0 ? p->VerDPI : 96;
    BOOL rot = (p->Flags & PVSF_ROTATE90) != 0;
    ULONGLONG outRows = (ULONGLONG)(rot ? img->Width : img->Height);
    CWicDibSource* src = new CWicDibSource(img, p->Flags, dpiX, dpiY, progress, appSpecific,
                                           outRows * (plan.Palette == wopOptimal ? 2 : 1));
    CWicHandleStream* stream = new CWicHandleStream(hFile);
    if (src == NULL || stream == NULL)
    {
        if (src != NULL)
            src->Release();
        if (stream != NULL)
            stream->Release();
        return PVC_OOM;
    }

    IWICPalette* pal = NULL;
    IWICFormatConverter* conv = NULL;
    IWICBitmapEncoder* enc = NULL;
    IWICBitmapFrameEncode* frame = NULL;
    IPropertyBag2* bag = NULL;
    BOOL unsupported = FALSE;
    HRESULT hr = S_OK;
    if (plan.Palette != wopNone)
    {
        hr = factory->CreatePalette(&pal);
        if (SUCCEEDED(hr))
        {
            if (plan.Palette == wopOptimal)
                hr = pal->InitializeFromBitmap(src, plan.PaletteColors, FALSE);
            else
                hr = pal->InitializePredefined(plan.Palette == wopBW ? WICBitmapPaletteTypeFixedBW
                                                                     : WICBitmapPaletteTypeFixedGray256,
                                               FALSE);
        }
    }
    if (SUCCEEDED(hr))
        hr = factory->CreateFormatConverter(&conv);
    if (SUCCEEDED(hr))
    {
        // fewer colors: error diffusion; gray levels and HiColor/TrueColor: plain conversion
        BOOL dither = plan.Palette == wopOptimal || plan.Palette == wopBW;
        hr = conv->Initialize(src, plan.PixelFormat, dither ? WICBitmapDitherTypeErrorDiffusion : WICBitmapDitherTypeNone,
                              pal, 0.0, pal != NULL ? WICBitmapPaletteTypeCustom : WICBitmapPaletteTypeMedianCut);
    }
    if (SUCCEEDED(hr))
        hr = factory->CreateEncoder(plan.Container, NULL, &enc);
    if (SUCCEEDED(hr))
        hr = enc->Initialize(stream, WICBitmapEncoderNoCache);
    if (SUCCEEDED(hr))
        hr = enc->CreateNewFrame(&frame, &bag);
    if (SUCCEEDED(hr) && p->Format == PVF_JPG)
    {
        VARIANT v;
        VariantInit(&v);
        v.vt = VT_R4;
        v.fltVal = (float)max(1, min(100, (int)p->JPEGQuality)) / 100.0f;
        hr = WriteEncoderOption(bag, L"ImageQuality", &v);
        if (SUCCEEDED(hr))
        {
            VariantInit(&v);
            v.vt = VT_UI1;
            // WICJpegYCrCbSubsamplingOption: 2 = 4:2:2 (the dialog's 2:1:1), 3 = 4:4:4 (1:1:1)
            v.bVal = (BYTE)(p->JPEGSubsampling == 0 ? 3 : 2);
            hr = WriteEncoderOption(bag, L"JpegYCrCbSubsampling", &v);
        }
    }
    if (SUCCEEDED(hr) && plan.TiffCompression >= 0)
    {
        VARIANT v;
        VariantInit(&v);
        v.vt = VT_UI1;
        v.bVal = (BYTE)plan.TiffCompression;
        hr = WriteEncoderOption(bag, L"TiffCompressionMethod", &v);
    }
    if (SUCCEEDED(hr))
        hr = frame->Initialize(bag);
    if (SUCCEEDED(hr))
        hr = frame->SetSize(src->OutWidth(), src->OutHeight());
    if (SUCCEEDED(hr))
        hr = frame->SetResolution(dpiX, dpiY);
    if (SUCCEEDED(hr))
    {
        WICPixelFormatGUID pf = plan.PixelFormat;
        hr = frame->SetPixelFormat(&pf);
        if (SUCCEEDED(hr) && !IsEqualGUID(pf, plan.PixelFormat))
        {
            unsupported = TRUE; // the encoder wants another format: never write anything but what was offered
            hr = WINCODEC_ERR_UNSUPPORTEDPIXELFORMAT;
        }
    }
    if (SUCCEEDED(hr) && pal != NULL)
        hr = frame->SetPalette(pal);
    if (SUCCEEDED(hr) && p->CommentU8 != NULL && p->CommentU8[0] != 0)
    {
        // The comment is UTF-8 text. VT_LPSTR is written as the bytes given; VT_LPWSTR is converted
        // to the system code page by the tEXt and TIFF writers ('?' for the rest - measured), so:
        // JPEG COM, the GIF comment extension and TIFF ImageDescription get the UTF-8 bytes; PNG
        // gets a tEXt chunk (Latin-1 by the PNG rules) when the text is ASCII, else an iTXt chunk
        // (UTF-8 by the PNG rules; keyword "Comment"). BMP has no comment (the dialog offers none).
        // Feature 111: TIFF ImageDescription is an ASCII-typed tag. An ASCII comment stays exactly
        // that; any other gets the UTF-8 bytes there - what Windows itself writes into that tag
        // (its System.Title policy) and reads back as UTF-8 (measured), the Metadata Working
        // Group's recommendation - and, so that no reader has to guess, the same text in XMP
        // dc:description (x-default), which is Unicode by definition. The JPEG COM writer appends
        // a NUL byte; it is taken out after the commit (JpegDropCommentNul).
        // Feature 120, decided: the GIF comment extension is 7-bit ASCII by GIF89a and GIF has no
        // Unicode alternative - the Windows GIF encoder refuses XMP (/xmp/... answers
        // WINCODEC_ERR_PROPERTYNOTSUPPORTED, measured). An ASCII comment is what the standard
        // defines; any other keeps its UTF-8 bytes, as JPEG and TIFF do, rather than losing the
        // user's text (a reader that decodes the bytes as Latin-1 shows them garbled, nothing is
        // lost). Measured: the bytes as given in sub-blocks of at most 255, no NUL.
        IWICMetadataQueryWriter* mw = NULL;
        BOOL unicode = !SplIsASCII(p->CommentU8);
        BOOL pngUnicode = p->Format == PVF_PNG && unicode;
        LPCWSTR query = NULL;
        switch (p->Format)
        {
        case PVF_JPG:
            query = L"/com/TextEntry";
            break;
        case PVF_GIF:
            query = L"/commentext/TextEntry";
            break;
        case PVF_PNG:
            query = pngUnicode ? L"/iTXt/TextEntry" : L"/tEXt/{str=Comment}";
            break;
        case PVF_TIFF:
            query = L"/ifd/{ushort=270}";
            break;
        }
        if (query != NULL)
            hr = frame->GetMetadataQueryWriter(&mw);
        if (query != NULL && SUCCEEDED(hr))
        {
            PROPVARIANT v; // borrowed strings: never PropVariantClear'ed
            PropVariantInit(&v);
            WCHAR* commentW = NULL;
            if (pngUnicode)
            {
                v.vt = VT_LPSTR;
                v.pszVal = (LPSTR) "Comment";
                hr = mw->SetMetadataByName(L"/iTXt/Keyword", &v);
                commentW = SplU8ToWAlloc(p->CommentU8);
                if (SUCCEEDED(hr) && commentW == NULL)
                    hr = E_INVALIDARG;
                PropVariantInit(&v);
                v.vt = VT_LPWSTR;
                v.pwszVal = commentW;
            }
            else
            {
                v.vt = VT_LPSTR;
                v.pszVal = (LPSTR)p->CommentU8;
            }
            if (SUCCEEDED(hr))
                hr = mw->SetMetadataByName(query, &v);
            if (SUCCEEDED(hr) && p->Format == PVF_TIFF && unicode) // feature 111: XMP dc:description
            {
                commentW = SplU8ToWAlloc(p->CommentU8);
                if (commentW == NULL)
                    hr = E_INVALIDARG;
                else
                {
                    PropVariantInit(&v);
                    v.vt = VT_LPWSTR;
                    v.pwszVal = commentW;
                    hr = mw->SetMetadataByName(L"/ifd/xmp/<xmpalt>dc:description/x-default", &v);
                }
            }
            free(commentW);
        }
        if (mw != NULL)
            mw->Release();
    }
    if (SUCCEEDED(hr))
        hr = frame->WriteSource(conv, NULL);
    if (SUCCEEDED(hr))
        hr = frame->Commit();
    if (SUCCEEDED(hr))
        hr = enc->Commit();
    if (SUCCEEDED(hr) && p->Format == PVF_JPG && p->CommentU8 != NULL && p->CommentU8[0] != 0)
    {
        DWORD err = JpegDropCommentNul(hFile, strlen(p->CommentU8)); // feature 111
        if (err != 0)
        {
            stream->LastError = err;
            hr = HRESULT_FROM_WIN32(err);
        }
    }

    BOOL canceled = src->Canceled;
    DWORD streamErr = stream->LastError;
    if (bag != NULL)
        bag->Release();
    if (frame != NULL)
        frame->Release();
    if (enc != NULL)
        enc->Release();
    if (conv != NULL)
        conv->Release();
    if (pal != NULL)
        pal->Release();
    src->Release();
    stream->Release();

    if (SUCCEEDED(hr))
        return PVC_OK;
    if (canceled)
        return PVC_CANCELED;
    TRACE_E("WIC engine: encoding failed, hr=0x" << std::hex << hr);
    if (streamErr != 0)
    {
        *win32Err = streamErr;
        return PVC_WRITING_ERROR;
    }
    if (hr == E_OUTOFMEMORY)
        return PVC_OOM;
    if (unsupported || hr == WINCODEC_ERR_UNSUPPORTEDPIXELFORMAT || hr == WINCODEC_ERR_COMPONENTNOTFOUND ||
        hr == WINCODEC_ERR_UNSUPPORTEDOPERATION)
        return PVC_UNSUP_OUT_PARAMS;
    if (HRESULT_FACILITY(hr) == FACILITY_WIN32)
        *win32Err = HRESULT_CODE(hr);
    return PVC_WRITING_ERROR;
}

int WicDetachSource(void* hPVImage)
{
    CWicImage* img = (CWicImage*)hPVImage;
    if (img == NULL)
        return PVC_INVALID_HANDLE;
    if (img->Decoder == NULL)
        return PVC_OK; // no file behind the image
    if (img->HDib == NULL)
    {
        PVCODE code = DecodeFrame(img, (int)img->InfoFrame, NULL, NULL);
        if (code != PVC_OK)
            return code;
    }
    EnsureSourceFormat(img, img->DecodedFrame); // feature 111: still known while detached
    // feature 111: what WicReattachSource restores
    img->Detached = img->FromFile;
    img->DetachedFrameCount = img->FrameCount;
    img->DetachedFrame = img->DecodedFrame;
    img->DetachedInfoFrame = img->InfoFrame;
    img->Decoder->Release(); // closes the file
    img->Decoder = NULL;
    if (img->Stream != NULL)
    {
        img->Stream->Release();
        img->Stream = NULL;
    }
    // from now on the image behaves like an attached bitmap: one frame, always decoded
    img->FrameCount = 1;
    img->InfoFrame = 0;
    img->DecodedFrame = 0;
    if (img->SrcFrame >= 0)
        img->SrcFrame = 0; // the source format of the frame in memory
    if (img->AlphaFrame >= 0)
        img->AlphaFrame = 0;
    return PVC_OK;
}

int WicReattachSource(void* hPVImage, const char* u8Path)
{
    CWicImage* img = (CWicImage*)hPVImage;
    if (img == NULL || u8Path == NULL)
        return PVC_INVALID_HANDLE;
    if (!img->Detached || img->Decoder != NULL)
        return PVC_OK; // nothing was let go
    CWicImage probe;   // the new decoder is checked before it replaces anything
    memset(&probe, 0, sizeof(probe));
    PVCODE code = OpenFromFileU8(&probe, u8Path);
    if (code != PVC_OK)
        return code;
    UINT frames = 0;
    GUID container;
    const char* shortName;
    if (FAILED(probe.Decoder->GetFrameCount(&frames)) || frames != img->DetachedFrameCount ||
        FAILED(probe.Decoder->GetContainerFormat(&container)) || MapContainerToPVF(container, &shortName) != img->Format)
    {
        probe.Decoder->Release(); // not the file that was let go: stay detached
        return PVC_UNKNOWN_FILE_STRUCT;
    }
    img->Decoder = probe.Decoder;
    img->FrameCount = img->DetachedFrameCount;
    img->InfoFrame = img->DetachedInfoFrame;
    img->DecodedFrame = img->DetachedFrame; // the image in memory IS that frame (rotations included)
    if (img->SrcFrame >= 0)
        img->SrcFrame = img->DetachedFrame;
    if (img->AlphaFrame >= 0)
        img->AlphaFrame = img->DetachedFrame;
    img->Detached = FALSE;
    return PVC_OK;
}

BOOL WicIsDetached(void* hPVImage)
{
    CWicImage* img = (CWicImage*)hPVImage;
    return img != NULL && img->Detached && img->Decoder == NULL;
}

BOOL WicGetRowsSize(void* hPVImage, int* width, int* height)
{
    CWicImage* img = (CWicImage*)hPVImage;
    if (img == NULL || img->Lines == NULL || img->DibBits == NULL)
        return FALSE;
    *width = img->Width;
    *height = img->Height;
    return TRUE;
}

BOOL WicGetSourceFormat(void* hPVImage, CWicSourceFormat* out)
{
    CWicImage* img = (CWicImage*)hPVImage;
    if (img == NULL || out == NULL)
        return FALSE;
    // the frame whose information is reported: after a page change the title is set before the new
    // page is decoded (review S3: DecodedFrame still named the previous page then)
    EnsureSourceFormat(img, (int)img->InfoFrame);
    if (img->SrcFrame < 0) // cannot be read: what the rows are
    {
        out->Colors = PV_COLOR_TC24;
        out->ColorModel = PVCM_RGB;
        out->BitsPerPixel = 0;
        out->HasAlpha = FALSE;
        out->AlphaUsed = FALSE;
        return TRUE;
    }
    *out = img->Src;
    out->AlphaUsed = img->Src.HasAlpha && (img->AlphaFrame == img->SrcFrame ? img->AlphaUsed : TRUE);
    if (out->Colors == PV_COLOR_TC32 && !out->AlphaUsed)
        out->Colors = PV_COLOR_TC24; // an opaque image with an alpha channel holds 24-bit color
    return TRUE;
}

//*****************************************************************************
//
// Graceful stubs - operations with no engine backing (feature 006 scope)
//

static PVCODE WINAPI WicLoadFromClipboard(LPPVHandle* Img, LPPVImageInfo pInfo, int cbSize)
{
    UNREFERENCED_PARAMETER(pInfo);
    UNREFERENCED_PARAMETER(cbSize);
    if (Img != NULL)
        *Img = NULL;
    return PVC_UNSUP_FILE_TYPE;
}

// the Save As dialog's question: may (format, compression, colors, color model) be offered?
// -1 = no. PVCS_DEFAULT asks for the format's default compression. Feature 006 returned 0 -
// "supported" - for everything, so the dialog offered every format and depth and then failed.
static DWORD WINAPI WicIsOutCombSupported(int Fmt, int Compr, int Colors, int ColorModel)
{
    CWicOutPlan plan;
    return WicPlanOutput((DWORD)Fmt, (DWORD)Compr, (DWORD)Colors, ColorModel == PVCM_GRAYS ? PVCM_GRAYS : PVCM_RGB, &plan)
               ? 0
               : (DWORD)-1;
}

static PVCODE WINAPI WicReadImageSequence(LPPVHandle Img, LPPVImageSequence* ppSeq)
{
    // never called in v1: the engine does not set PVFF_IMAGESEQUENCE
    if (ppSeq != NULL)
        *ppSeq = NULL;
    UNREFERENCED_PARAMETER(Img);
    return PVC_UNSUP_FILE_TYPE;
}

static PVCODE WINAPI WicCropImage(LPPVHandle Img, int Left, int Top, int Width, int Height)
{
    UNREFERENCED_PARAMETER(Img);
    UNREFERENCED_PARAMETER(Left);
    UNREFERENCED_PARAMETER(Top);
    UNREFERENCED_PARAMETER(Width);
    UNREFERENCED_PARAMETER(Height);
    return PVC_UNSUP_OUT_PARAMS;
}

//*****************************************************************************
//
// InitWicEngine
//

void InitWicEngine(CPVW32DLL* table)
{
    if (!WicFactoryCSInited)
    {
        InitializeCriticalSection(&WicFactoryCS);
        WicFactoryCSInited = TRUE;
    }
    table->PVReadImage2 = WicReadImage2;
    table->PVCloseImage = WicCloseImage;
    table->PVDrawImage = WicDrawImage;
    table->PVGetErrorText = WicGetErrorText;
    table->PVOpenImageEx = WicOpenImageEx;
    table->PVSetBkHandle = WicSetBkHandle;
    table->PVGetDLLVersion = WicGetDLLVersion;
    table->PVSetStretchParameters = WicSetStretchParameters;
    table->PVLoadFromClipboard = WicLoadFromClipboard;
    table->PVGetImageInfo = WicGetImageInfo;
    table->PVSetParam = WicSetParam;
    table->PVGetHandles2 = WicGetHandles2;
    table->PVSaveImage = WicSaveImage;
    table->PVChangeImage = WicChangeImage;
    table->PVIsOutCombSupported = WicIsOutCombSupported;
    table->PVReadImageSequence = WicReadImageSequence;
    table->PVCropImage = WicCropImage;
    table->Handle = NULL; // no external DLL
}
