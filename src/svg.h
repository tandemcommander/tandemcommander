// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#pragma once

struct NSVGrasterizer;
struct NSVGimage;
// Renders icon 'svgName' of icon set 'iconSet' (SAL_ICONSET_*, -1 = the configured set) into the
// iconSize x iconSize cell at x, y of hDC over bkColor. Feature 416: returns FALSE and leaves the cell
// untouched when the set has no usable file for the name (missing, unreadable, unparseable, no shapes).
BOOL RenderSVGImage(NSVGrasterizer* rast, HDC hDC, int x, int y, const char* svgName, int iconSize, COLORREF bkColor,
                    BOOL enabled, int iconSet = -1);

// feature 416: icon 'svgName' of icon set 'iconSet' (-1 = configured) as a size x size icon with an
// alpha channel and a matching mask (for image lists without alpha); NULL when the set has no usable
// file for the name - the caller then uses its Classic icon. Registered in HANDLES (DestroyIcon via HANDLES).
HICON CreateSetSVGIcon(const char* svgName, int iconSet, int size);

// feature 417: the active set's icon 'name' (a plug-in id or SAL_ICONSET_NAME_PLUGIN / _PLUGINFS) from its
// plug-in folder (iconsets\fluent\plugins\) as a size x size icon, the 416 dark rules applied; NULL in
// Classic (no plug-in icons) or when the set has no usable file. Registered in HANDLES.
HICON CreateSetPluginSVGIcon(const char* name, int size);

// returns SysColor in the format for the SVG library (BGR instead of Win32 RGB)
DWORD GetSVGSysColor(int index);

//*****************************************************************************
//
// CSVGSprite
//

#define SVGSTATE_ORIGINAL 0x0001 // unchanged original form of the SVG
#define SVGSTATE_ENABLED 0x0002  // SVG recolored to the enabled text color
#define SVGSTATE_DISABLED 0x0004 // SVG recolored to the disabled text color
#define SVGSTATE_COUNT 3

// Object used to render SVGs via a cached bitmap.
// Primarily stores the colored variant of the image rendered with the colors defined in the source SVG.
// It can also hold other color variants of the bitmap (hence Sprite in the name — it internally uses a larger bitmap with multiple images),
// for example "disabled", "active", "selected".
class CSVGSprite
{
public:
    CSVGSprite();
    ~CSVGSprite();

    // discards the bitmap and initializes variables to their default values
    void Clean();

    // 'states' is a combination of bits from the SVGSTATE_* family
    // 'disabledSysIndex' is the system colour of SVGSTATE_DISABLED (feature 416: the Fluent 2 chevron uses
    // COLOR_GRAYTEXT - COLOR_BTNSHADOW was invisible on the dark toolbar)
    BOOL Load(int resID, int width, int height, DWORD states, int disabledSysIndex = COLOR_BTNSHADOW);

    void GetSize(SIZE* s);
    int GetWidth();
    int GetHeight();

    // 'hDC' is the destination DC where the bitmap should be rendered
    // 'x' and 'y' are the destination coordinates in 'hDC'
    // 'width' and 'height' are the destination size; if they are -1, the stored 'Width'/'Height' size is used
    void AlphaBlend(HDC hDC, int x, int y, int width, int height, DWORD state);

protected:
    // loads the resource into memory, allocates a buffer one byte longer, and terminates the resource with zero
    // on success returns a pointer to the allocated memory (it has to be freed), on failure returns NULL
    char* LoadSVGResource(int resID);

    // Input 'sz' specifies the size in points that the SVG should fit into after conversion to a bitmap.
    // If one dimension is -1, it is unspecified and is computed to preserve the aspect ratio.
    // If neither dimension is specified, they are taken from the source data.
    // Returns the output bitmap dimensions in points.
    void GetScaleAndSize(const NSVGimage* image, const SIZE* sz, float* scale, int* width, int* height);

    // creates a DIB of size 'width' and 'height', returns its handle and a pointer to its data
    void CreateDIB(int width, int height, HBITMAP* hMemBmp, void** lpMemBits);

    // tints the SVG 'image' with the color determined by 'state' state
    void ColorizeSVG(NSVGimage* image, DWORD state, int disabledSysIndex);

protected:
    int Width; // dimension of a single image in points
    int Height;
    HBITMAP HBitmaps[SVGSTATE_COUNT];
};

//*****************************************************************************
//
// global variables
//

//extern HBITMAP HArrowRight;         // bitmap created from SVG, used for buttons as the right arrow
//extern SIZE ArrowRightSize;         // dimensions in points
//HBITMAP HArrowRight = NULL;
//SIZE ArrowRightSize = { 0 };

extern CSVGSprite SVGArrowRight;
extern CSVGSprite SVGArrowRightSmall;
extern CSVGSprite SVGArrowMore;
extern CSVGSprite SVGArrowLess;
extern CSVGSprite SVGArrowDropDown;
