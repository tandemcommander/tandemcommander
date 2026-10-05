// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// wicengine.h
//
// In-process image engine backed by the Windows Imaging Component (WIC).
// Replaces the proprietary PVW32Cnv.dll, which was removed from the
// repository for GPL reasons (feature 006-fix-pictview-plugin). The engine
// fills the existing CPVW32DLL function-pointer table with functions of
// identical signatures, so all viewer call sites stay unchanged.
//
// VIEW-CRITICAL functions are implemented fully (open / info / decode /
// draw / stretch / background / close / error text). Out-of-scope
// operations (crop, clipboard, image sequences, file output of PVSaveImage)
// are non-crashing stubs returning a clean PVCODE. PVChangeImage (lossless
// 90deg rotation) IS implemented so EXIF auto-rotate keeps working. Save As
// writes through the Windows encoders since feature 105 (WicEncodeImageToFile
// below); PVIsOutCombSupported reports what those encoders write.
//
// FileName passed to PVOpenImageEx is UTF-8 (plugin interface 104); the
// engine converts it to UTF-16 with the \\?\ long-path prefix internally.
//

struct CPVW32DLL;

// fills all PV* members of the table with the WIC engine implementations
// (the four plugin-internal helpers GetRGBAtCursor/CalculateHistogram/
// CreateThumbnail/SimplifyImageSequence are assigned by the caller)
void InitWicEngine(CPVW32DLL* table);

//*****************************************************************************
//
// Thumbnail fast path (feature 064, contract C4)
//
// WicPrepareThumbnailSource decodes the cheapest pixel source that can fill a
// thumbnail bounded by maxW x maxH into the image's DIB, so the following
// PVSaveImage streams a small image instead of the full frame:
//   fast mode:  embedded decoder thumbnail (EXIF preview) first,
//               then reduced-resolution decode (JPEG DCT-domain scaling),
//   slow mode:  reduced-resolution decode only (final quality).
// On PVC_OK (DWORD; PVCODE value) *effWidth/*effHeight carry the decoded
// dimensions the caller must hand to the thumbnail maker, and *onlyPreview is
// nonzero when the pixels came from a preview smaller than the requested box
// (the caller then flags SSTHUMB_ONLY_PREVIEW so the core schedules a quality
// round). Any failure leaves the image undecoded - the caller just keeps the
// classic full-decode path. Set the background (PVSetBkHandle) BEFORE calling:
// alpha sources are composited here.
//
// hPVImage is the LPPVHandle from PVOpenImageEx (typed void* to keep this
// header independent of pvw32dll.h).
DWORD WicPrepareThumbnailSource(void* hPVImage, int maxW, int maxH, int fastMode,
                                DWORD* effWidth, DWORD* effHeight, int* onlyPreview);

// EXIF orientation of frame 0 (1..8 per the TIFF/EXIF spec); 0 = absent or
// unknown. Cheap: metadata only, no pixel decode (feature 064, contract C5).
int WicGetExifOrientation(void* hPVImage);

//*****************************************************************************
//
// Save As through the Windows encoders (feature 105)
//
// The built-in Windows Imaging Component writes BMP, PNG, JPEG, GIF and TIFF.
// The image written is the frame the viewer shows, as the viewer holds it
// (rotations done in the viewer included, alpha flattened over the background
// as for the display), transformed by 'Flags' and reduced to 'Colors'.
// PVIsOutCombSupported tells the Save As dialog which compressions and color
// depths each format offers; the same table drives the encoder here.

struct CWicEncodeParams
{
    DWORD Format;          // PVF_BMP, PVF_PNG, PVF_JPG, PVF_GIF or PVF_TIFF
    DWORD Compression;     // PVCS_DEFAULT or a PVCS_* the format offers
    DWORD Colors;          // 2, 16, 256, PV_COLOR_HC15, PV_COLOR_HC16 or PV_COLOR_TC24
    DWORD ColorModel;      // PVCM_RGB; PVCM_GRAYS with 256 colors = 256 gray levels
    DWORD Flags;           // PVSF_FLIP_HOR | PVSF_FLIP_VERT | PVSF_ROTATE90 | PVSF_INVERT:
                           // the flips first, then the rotation by 90 degrees clockwise
    DWORD HorDPI, VerDPI;  // of the written image (already swapped for a rotation)
    DWORD JPEGQuality;     // 1..100
    DWORD JPEGSubsampling; // the dialog's choice: 0 = 1:1:1 (4:4:4), otherwise 2:1:1 (4:2:2)
    const char* CommentU8; // NULL or "" = none; JPEG, PNG, GIF, TIFF store it as UTF-8 text
};

// TRUE for the formats the Windows encoders write (PVF_*)
BOOL WicCanEncodeFormat(DWORD format);

// Encodes the image into 'hFile' (open for reading and writing, positioned at 0, empty).
// Returns a PVCODE: PVC_OK; PVC_CANCELED when 'progress' returned TRUE; PVC_UNSUP_OUT_PARAMS
// for a combination the table does not offer; PVC_WRITING_ERROR with '*win32Err' set when the
// file could not be written (disk full, ...), else 0; PVC_OOM. The file content is undefined
// after a failure - the caller writes into a temporary file and discards it.
int WicEncodeImageToFile(void* hPVImage, int imageIndex, HANDLE hFile, const CWicEncodeParams* p,
                         BOOL(WINAPI* progress)(int done, void* appSpecific), void* appSpecific,
                         DWORD* win32Err);

// Releases the decoder of an image opened from a file - and so the file itself, which the
// decoder keeps open without FILE_SHARE_DELETE (it cannot be replaced, renamed or deleted
// meanwhile). The decoded frame stays in memory and is still drawn; other frames and
// re-decoding are gone until WicReattachSource (same content: a rename, a failed replace, a
// declined delete) or until the caller opens the file again (new content). PVC_OK also for an
// image without a file (clipboard, capture).
int WicDetachSource(void* hPVImage);

// Feature 111: takes the file back after WicDetachSource - a new decoder on 'u8Path' (UTF-8; the
// file's name now, e.g. after a rename), the frame count and the frame held in memory as they
// were, the image in memory untouched (no reload: zoom, mirror and rotation stay). Only for the
// SAME content: the caller knows the file was not rewritten. PVC_OK also when nothing was
// detached; on failure (the file is gone, or is no longer an image of the same format) the image
// stays detached and is still drawn from memory.
int WicReattachSource(void* hPVImage, const char* u8Path);

// Feature 111: TRUE while the image is detached from its file by WicDetachSource (and not re-attached).
// A newly opened image never is - so a window can tell whether it still shows the image it let go.
BOOL WicIsDetached(void* hPVImage);

// Feature 111: the shown frame's source as the decoder reports it. The engine always hands the
// viewer 32-bit rows (PVImageInfo::Colors stays PV_COLOR_TC32 - the pipette and the histogram
// read those rows); this tells what the FILE holds, for the Save As dialog (offered and default
// depth, the alpha question), the title and Image Information.
struct CWicSourceFormat
{
    DWORD Colors;       // 2, 16, 256, PV_COLOR_HC15, PV_COLOR_HC16, PV_COLOR_TC24, PV_COLOR_TC32
    DWORD ColorModel;   // PVCM_RGB, PVCM_GRAYS (256 gray levels or gray of more bits), PVCM_CMYK
    DWORD BitsPerPixel; // of the source pixel format (0 = unknown)
    BOOL HasAlpha;      // the source pixel format carries an alpha channel
    BOOL AlphaUsed;     // ... and a pixel of the decoded frame is not opaque (TRUE while not known)
};

// FALSE when the handle is invalid. An opaque image with an alpha channel reports PV_COLOR_TC24
// in 'Colors' (HasAlpha TRUE, AlphaUsed FALSE); PV_COLOR_TC32 means the alpha is really used.
BOOL WicGetSourceFormat(void* hPVImage, CWicSourceFormat* out);
