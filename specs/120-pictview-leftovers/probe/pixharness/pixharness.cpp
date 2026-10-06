// Feature 120 harness: PictView's image engine (wicengine.cpp) and its pipette / histogram reader
// (PixelAccess.cpp) compiled into a console program - the plug-in's own sources, no copy - fed with
// known images. build_and_run.cmd builds it twice: from the working tree and from the sources of a
// git revision (the build before), so the same fixtures show the defect and the fix.
//
// Usage: pixharness <image> [<image> ...]
//   For every image, as the viewer does: PVOpenImageEx (UTF-8 name), PVReadImage2, PVGetImageInfo;
//   then lines (one record per line, fields separated by '|'):
//     FILE|<name>|<w>|<h>|<colors>|<bytesPerLine>
//     PIX|<x>|<y>|<r>|<g>|<b>|<ok>            every pixel, through GetRGBAtCursor (pvii.Colors)
//     HIST|<channel>|<256 counts, comma-separated>   lum, red, green, blue, rgb (CalculateHistogram)
//     TURN|<w>|<h>|<pixels hash>              after PVChangeImage(90 CW) and a new background color
//                                             (PVSetBkHandle black): the size the engine then reports
//                                             and an FNV-1a hash of its rows' B,G,R bytes
//     TURN3|<w>|<h>|<pixels hash>             two more clockwise turns (three in all), then white
// The viewer's background is white (the engine's default) - Pillow composites the same way.

#include "precomp.h"

#ifdef INT32
#undef INT32
#undef UINT32
#endif

#include "lib/pvw32dll.h"
#include "pictview.h"
#include "PixelAccess.h"
#include "wicengine.h"

CPVW32DLL PVW32DLL; // pictview.cpp in the plug-in

// spl_base.h redirects lstrcpynA here; the plug-ins get it from shared/dbg.cpp (same body)
extern "C" LPSTR _sal_lstrcpynA(LPSTR lpString1, LPCSTR lpString2, int iMaxLength)
{
    if (iMaxLength <= 0)
        return lpString1;
    LPSTR ret = lpString1;
    LPSTR end = lpString1 + iMaxLength - 1;
    while (lpString1 < end && *lpString2 != 0)
        *lpString1++ = *lpString2++;
    *lpString1 = 0;
    return ret;
}

static unsigned Fnv(unsigned h, BYTE b) { return (h ^ b) * 16777619u; }

static void Dump(const wchar_t* fileW)
{
    char u8[2048];
    WideCharToMultiByte(CP_UTF8, 0, fileW, -1, u8, sizeof(u8), NULL, NULL);
    PVOpenImageExInfo oi;
    memset(&oi, 0, sizeof(oi));
    oi.cbSize = sizeof(oi);
    oi.FileName = u8;
    PVImageInfo pvii;
    memset(&pvii, 0, sizeof(pvii));
    LPPVHandle h = NULL;
    PVCODE code = PVW32DLL.PVOpenImageEx(&h, &oi, &pvii, sizeof(pvii));
    if (code != PVC_OK)
    {
        printf("FILE|%s|ERROR open %d\n", u8, (int)code);
        return;
    }
    code = PVW32DLL.PVReadImage2(h, NULL, NULL, NULL, NULL, 0);
    if (code == PVC_OK)
        code = PVW32DLL.PVGetImageInfo(h, &pvii, sizeof(pvii), 0);
    if (code != PVC_OK)
    {
        printf("FILE|%s|ERROR read %d\n", u8, (int)code);
        PVW32DLL.PVCloseImage(h);
        return;
    }
    printf("FILE|%s|%lu|%lu|%lu|%lu\n", u8, pvii.Width, pvii.Height, pvii.Colors, pvii.BytesPerLine);
    for (DWORD y = 0; y < pvii.Height; y++)
        for (DWORD x = 0; x < pvii.Width; x++)
        {
            RGBQUAD c = {0, 0, 0, 0};
            int ind = 0;
            bool ok = PVW32DLL.GetRGBAtCursor(h, pvii.Colors, (int)x, (int)y, &c, &ind);
            printf("PIX|%lu|%lu|%d|%d|%d|%d\n", x, y, c.rgbRed, c.rgbGreen, c.rgbBlue, ok ? 1 : 0);
        }
    static DWORD a[5][256];
    code = PVW32DLL.CalculateHistogram(h, &pvii, a[0], a[1], a[2], a[3], a[4]);
    static const char* names[5] = {"lum", "red", "green", "blue", "rgb"};
    for (int c = 0; c < 5; c++)
    {
        printf("HIST|%s|", names[c]);
        for (int i = 0; i < 256; i++)
            printf(i ? ",%lu" : "%lu", code == PVC_OK ? a[c][i] : 0);
        printf("\n");
    }
    // a rotation in the viewer, then another background color (full screen / configuration)
    if (PVW32DLL.PVChangeImage(h, PVCF_ROTATE90CW) == PVC_OK)
    {
        PVW32DLL.PVSetBkHandle(h, RGB(0, 0, 0));
        PVImageInfo after;
        memset(&after, 0, sizeof(after));
        PVW32DLL.PVGetImageInfo(h, &after, sizeof(after), 0);
        LPPVImageHandles hs = NULL;
        unsigned hash = 2166136261u;
        if (PVW32DLL.PVGetHandles2(h, &hs) == PVC_OK && hs != NULL && hs->pLines != NULL)
        {
            // the engine's own rows: their size is what PVGetImageInfo reports once decoded
            PVW32DLL.PVGetImageInfo(h, &after, sizeof(after), 0);
            for (DWORD y = 0; y < after.Height; y++)
                for (DWORD x = 0; x < after.Width; x++)
                    for (int k = 0; k < 3; k++)
                        hash = Fnv(hash, hs->pLines[y][x * 4 + k]);
        }
        printf("TURN|%lu|%lu|%08x\n", after.Width, after.Height, hash);
        // two more clockwise turns (three in all = one counter-clockwise), then white again
        if (PVW32DLL.PVChangeImage(h, PVCF_ROTATE90CW) == PVC_OK && PVW32DLL.PVChangeImage(h, PVCF_ROTATE90CW) == PVC_OK)
        {
            PVW32DLL.PVSetBkHandle(h, RGB(255, 255, 255));
            hash = 2166136261u;
            if (PVW32DLL.PVGetHandles2(h, &hs) == PVC_OK && hs != NULL && hs->pLines != NULL)
            {
                PVW32DLL.PVGetImageInfo(h, &after, sizeof(after), 0);
                for (DWORD y = 0; y < after.Height; y++)
                    for (DWORD x = 0; x < after.Width; x++)
                        for (int k = 0; k < 3; k++)
                            hash = Fnv(hash, hs->pLines[y][x * 4 + k]);
            }
            printf("TURN3|%lu|%lu|%08x\n", after.Width, after.Height, hash);
        }
    }
    PVW32DLL.PVCloseImage(h);
}

int wmain(int argc, wchar_t** argv)
{
    memset(&PVW32DLL, 0, sizeof(PVW32DLL));
    InitWicEngine(&PVW32DLL);
    PVW32DLL.GetRGBAtCursor = GetRGBAtCursor;
    PVW32DLL.CalculateHistogram = CalculateHistogram;
    for (int i = 1; i < argc; i++)
        Dump(argv[i]);
    return 0;
}
