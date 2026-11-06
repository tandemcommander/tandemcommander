// Tab strip mock renderer: paints the panel tab strip with the same GDI calls as
// src/tabwnd.cpp (variant 0 = the current code, ported line by line) and the
// proposed variants 1-4. Text always goes through GDI DrawTextW with the
// program's EnvFont (SPI_GETICONTITLELOGFONT), so ClearType output matches.
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

public class TabPal
{
    public int Face, Shadow, Hilite, Text, ActBk, ActFg, InBk, InFg, HotPanel, HotAct, HotIn, Accent, Light3D, DkShadow;
    public bool Dark;

    [DllImport("user32.dll")] static extern int GetSysColor(int i);
    [DllImport("shlwapi.dll")] static extern void ColorRGBToHLS(int clr, out ushort h, out ushort l, out ushort s);
    [DllImport("shlwapi.dll")] static extern int ColorHLSToRGB(ushort h, ushort l, ushort s);

    public static int RGB(int r, int g, int b) { return r | (g << 8) | (b << 16); }
    public static int R(int c) { return c & 0xFF; }
    public static int G(int c) { return (c >> 8) & 0xFF; }
    public static int B(int c) { return (c >> 16) & 0xFF; }
    static int Gray(int c)
    {
        int v = (55 * R(c) + 183 * G(c) + 19 * B(c)) / 255;
        return v > 255 ? 255 : v;
    }

    // port of GetHilightColor (salamdr1.cpp)
    static int Hilight(int clr1, int clr2)
    {
        ushort h1, l1, s1;
        ColorRGBToHLS(clr1, out h1, out l1, out s1);
        int gray1 = Gray(clr1), gray2 = Gray(clr2);
        int res = 0;
        if (gray2 < 170 && gray1 <= 220)
        {
            int wanted = gray1 + 20 + (220 - gray1) / 2;
            if (wanted < gray2 + 100) wanted = gray2 + 100;
            if (wanted > 255) wanted = 255;
            bool first = true;
            while (first || l1 != 240)
            {
                first = false;
                l1 += 5;
                if (l1 > 240) l1 = 240;
                res = ColorHLSToRGB(h1, l1, s1);
                if (Gray(res) >= wanted) break;
            }
        }
        else
        {
            if (Math.Abs(gray1 - gray2) > 85 || gray2 < 85 || gray1 < 75)
            {
                if (gray1 > gray2)
                    res = RGB((4 * R(clr1) + 3 * R(clr2)) / 7, (4 * G(clr1) + 3 * G(clr2)) / 7, (4 * B(clr1) + 3 * B(clr2)) / 7);
                else
                    res = RGB((R(clr1) + R(clr2)) / 2, (G(clr1) + G(clr2)) / 2, (B(clr1) + B(clr2)) / 2);
            }
            else res = 0;
        }
        return res;
    }

    // Default theme, Salamander/Explorer scheme with SCF_DEFAULT caption colors
    // resolved like UpdateDefaultColors does
    public static TabPal Light()
    {
        TabPal p = new TabPal();
        p.Face = GetSysColor(15); p.Shadow = GetSysColor(16); p.Hilite = GetSysColor(20); p.Text = GetSysColor(18);
        p.Light3D = GetSysColor(22); p.DkShadow = GetSysColor(21);
        p.ActBk = GetSysColor(2); p.ActFg = GetSysColor(9); p.InBk = GetSysColor(3);
        int fgAc = GetSysColor(9), fgIn = GetSysColor(19);
        p.InFg = Math.Abs(Gray(fgAc) - Gray(p.InBk)) >= Math.Abs(Gray(fgIn) - Gray(p.InBk)) ? fgAc : fgIn;
        p.HotPanel = GetSysColor(26);
        p.HotAct = Hilight(p.ActFg, p.ActBk);
        p.HotIn = Hilight(p.InFg, p.InBk);
        p.Accent = GetSysColor(26); // COLOR_HOTLIGHT
        return p;
    }

    // Dark theme: src/common/themes_palette.h
    public static TabPal DarkPal()
    {
        TabPal p = new TabPal();
        p.Dark = true;
        p.Face = RGB(45, 45, 45); p.Shadow = RGB(26, 26, 26); p.Hilite = RGB(70, 70, 70); p.Text = RGB(240, 240, 240);
        p.Light3D = RGB(58, 58, 58); p.DkShadow = RGB(16, 16, 16);
        p.ActBk = RGB(38, 79, 120); p.ActFg = RGB(255, 255, 255); p.InBk = RGB(45, 45, 45); p.InFg = RGB(170, 170, 170);
        p.HotPanel = RGB(102, 178, 255); p.HotAct = RGB(180, 210, 255); p.HotIn = RGB(160, 190, 230);
        p.Accent = RGB(102, 178, 255);
        return p;
    }

    public static int Mix(int a, int b, double t)
    {
        return RGB((int)Math.Round(R(a) + (R(b) - R(a)) * t), (int)Math.Round(G(a) + (G(b) - G(a)) * t), (int)Math.Round(B(a) + (B(b) - B(a)) * t));
    }
}

public class TabMock
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int x, y; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct LOGFONTW
    {
        public int lfHeight, lfWidth, lfEscapement, lfOrientation, lfWeight;
        public byte lfItalic, lfUnderline, lfStrikeOut, lfCharSet, lfOutPrecision, lfClipPrecision, lfQuality, lfPitchAndFamily;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string lfFaceName;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct TEXTMETRICW
    {
        public int tmHeight, tmAscent, tmDescent, tmInternalLeading, tmExternalLeading, tmAveCharWidth, tmMaxCharWidth,
            tmWeight, tmOverhang, tmDigitizedAspectX, tmDigitizedAspectY;
        public char tmFirstChar, tmLastChar, tmDefaultChar, tmBreakChar;
        public byte tmItalic, tmUnderlined, tmStruckOut, tmPitchAndFamily, tmCharSet;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct SHFILEINFOW
    {
        public IntPtr hIcon; public int iIcon; public uint dwAttributes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szDisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)] public string szTypeName;
    }

    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateSolidBrush(int c);
    [DllImport("user32.dll")] static extern int FillRect(IntPtr dc, ref RECT r, IntPtr br);
    [DllImport("user32.dll")] static extern bool DrawEdge(IntPtr dc, ref RECT r, uint edge, uint flags);
    [DllImport("gdi32.dll")] static extern int SetBkMode(IntPtr dc, int m);
    [DllImport("gdi32.dll")] static extern int SetTextColor(IntPtr dc, int c);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int DrawTextW(IntPtr dc, string s, int n, ref RECT r, uint f);
    [DllImport("gdi32.dll")] static extern IntPtr CreatePen(int style, int w, int c);
    [DllImport("gdi32.dll")] static extern bool MoveToEx(IntPtr dc, int x, int y, IntPtr old);
    [DllImport("gdi32.dll")] static extern bool LineTo(IntPtr dc, int x, int y);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateFontIndirectW(ref LOGFONTW lf);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool SystemParametersInfoW(uint a, uint b, ref LOGFONTW lf, uint c);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern bool GetTextMetricsW(IntPtr dc, out TEXTMETRICW tm);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SHGetFileInfoW(string p, uint attr, ref SHFILEINFOW fi, uint cb, uint flags);
    [DllImport("user32.dll")] static extern bool DrawIconEx(IntPtr dc, int x, int y, IntPtr ic, int cx, int cy, int step, IntPtr br, int flags);
    [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr ic);

    const int tspNone = 0, tspTab = 1, tspClose = 2, tspPlus = 3;
    const uint DT_LEFT = 0, DT_VCENTER = 4, DT_SINGLELINE = 0x20, DT_END_ELLIPSIS = 0x8000, DT_NOPREFIX = 0x800;

    static IntPtr EnvFont = IntPtr.Zero;
    static int EnvFontCharHeight, AvgCharWidth;

    // inputs
    public int Variant;           // 0 current, 1 flat, 2 rounded, 3 underline, 4 flat + icons
    public int Width;
    public string[] Titles;
    public string[] IconPaths;    // "dir" or a real path (drive)
    public int Active;
    public int HotIndex = -1, HotPart = tspNone;
    public bool ActivePanel;
    public TabPal P;

    // layout state (names as in CTabWindow)
    public int Height;
    int TabsLeft, TabWidth, VisibleCount, FirstVisible;
    RECT PlusRect;
    int pad, glyph;

    static void EnsureFont()
    {
        if (EnvFont != IntPtr.Zero) return;
        LOGFONTW lf = new LOGFONTW();
        SystemParametersInfoW(0x1F, (uint)Marshal.SizeOf(typeof(LOGFONTW)), ref lf, 0); // SPI_GETICONTITLELOGFONT
        EnvFont = CreateFontIndirectW(ref lf);
        IntPtr dc = GetDC(IntPtr.Zero);
        IntPtr old = SelectObject(dc, EnvFont);
        TEXTMETRICW tm;
        GetTextMetricsW(dc, out tm);
        EnvFontCharHeight = tm.tmHeight;
        AvgCharWidth = tm.tmAveCharWidth;
        SelectObject(dc, old);
        ReleaseDC(IntPtr.Zero, dc);
    }

    public static string FontInfo()
    {
        EnsureFont();
        return "charHeight=" + EnvFontCharHeight + " avgChar=" + AvgCharWidth;
    }

    public static int NeededHeight(int variant)
    {
        EnsureFont();
        int h = 2 + EnvFontCharHeight + 2 + 2;
        if (variant == 1 || variant == 3 || variant == 4) h += 2;
        if (variant == 2 || variant == 5) h += 4;
        if (variant == 6) h += 8; // F: E made taller
        return h;
    }

    bool HasIcons { get { return (Variant == 4 || Variant >= 5) && IconPaths != null; } }
    bool Rounded { get { return Variant == 2 || Variant >= 5; } }
    int closePad, iconGap;
    int Count { get { return Titles.Length; } }

    void Layout()
    {
        int count = Count;
        int btnW = Height;
        int extra = HasIcons ? 16 + (Variant >= 5 ? 6 : pad) : 0;
        int minW = 6 * AvgCharWidth + 2 * pad + glyph + extra;
        int maxW = 20 * AvgCharWidth + 2 * pad + glyph + extra;
        TabsLeft = Rounded ? 8 : 1; // the rounded tab's feet need room
        VisibleCount = count;
        TabWidth = 0;
        if (count > 0 && Width > 0)
        {
            int available = Width - TabsLeft - btnW - 2;
            if (available < 0) available = 0;
            TabWidth = available / count;
            if (TabWidth > maxW) TabWidth = maxW;
            if (TabWidth < minW) TabWidth = minW; // the mock never overflows
        }
        FirstVisible = 0;
        PlusRect.left = TabsLeft + VisibleCount * TabWidth + 2;
        PlusRect.right = PlusRect.left + btnW;
        PlusRect.top = 1;
        PlusRect.bottom = Height - 1;
    }

    bool GetTabRect(int index, out RECT r)
    {
        r = new RECT();
        if (index < FirstVisible || index >= FirstVisible + VisibleCount || TabWidth <= 0) return false;
        r.left = TabsLeft + (index - FirstVisible) * TabWidth;
        r.right = r.left + TabWidth - 1;
        r.top = 1;
        r.bottom = Height - 1;
        return true;
    }

    bool ShowsCloseGlyph(int index) { return Count > 1 && (index == Active || index == HotIndex); }

    bool GetCloseRect(int index, out RECT r)
    {
        r = new RECT();
        RECT tab;
        if (!GetTabRect(index, out tab)) return false;
        r.right = tab.right - closePad;
        r.left = r.right - glyph;
        r.top = (Height - glyph) / 2;
        if (Variant != 0) r.top = TextTop() + (Height - TextTop() - glyph) / 2;
        r.bottom = r.top + glyph;
        if (r.left < tab.left + pad) r.left = tab.left + pad;
        return r.left < r.right;
    }

    // ---------------------------------------------------------------- GDI helpers
    static void Fill(IntPtr dc, RECT r, int clr)
    {
        IntPtr br = CreateSolidBrush(clr);
        FillRect(dc, ref r, br);
        DeleteObject(br);
    }
    static RECT Rc(int l, int t, int r, int b) { RECT x; x.left = l; x.top = t; x.right = r; x.bottom = b; return x; }

    void ThemeDrawEdgeRaisedInnerLTR(IntPtr dc, RECT rc)
    {
        if (!P.Dark)
        {
            DrawEdge(dc, ref rc, 0x0004 /*BDR_RAISEDINNER*/, 1 | 2 | 4 /*BF_LEFT|BF_TOP|BF_RIGHT*/);
            return;
        }
        // themes.cpp: flat single-pixel bevel, raised -> 3DLIGHT top/left, 3DDKSHADOW bottom/right
        Fill(dc, Rc(rc.left, rc.top, rc.right, rc.top + 1), P.Light3D);
        Fill(dc, Rc(rc.left, rc.top, rc.left + 1, rc.bottom), P.Light3D);
        Fill(dc, Rc(rc.right - 1, rc.top, rc.right, rc.bottom), P.DkShadow);
    }

    void GdiLines(IntPtr dc, int[] pts, int clr)
    {
        IntPtr pen = CreatePen(0, 1, clr);
        IntPtr old = SelectObject(dc, pen);
        for (int i = 0; i + 3 < pts.Length; i += 4)
        {
            MoveToEx(dc, pts[i], pts[i + 1], IntPtr.Zero);
            LineTo(dc, pts[i + 2], pts[i + 3]);
        }
        SelectObject(dc, old);
        DeleteObject(pen);
    }

    void DrawTitle(IntPtr dc, RECT tr, string title, int clr)
    {
        if (tr.right <= tr.left) return;
        SetBkMode(dc, 1); // TRANSPARENT
        IntPtr oldFont = SelectObject(dc, EnvFont);
        SetTextColor(dc, clr);
        DrawTextW(dc, title, -1, ref tr, DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS | DT_NOPREFIX);
        SelectObject(dc, oldFont);
    }

    static Color C(int c) { return Color.FromArgb(TabPal.R(c), TabPal.G(c), TabPal.B(c)); }

    // ---------------------------------------------------------------- variant 0: tabwnd.cpp
    void PaintTabCurrent(IntPtr dc, int index)
    {
        RECT r;
        if (!GetTabRect(index, out r)) return;
        bool active = index == Active;
        bool hot = HotIndex == index && HotPart == tspTab;
        RECT body = r;
        if (active) body.bottom = Height; else body.top += 2;
        Fill(dc, body, active ? (ActivePanel ? P.ActBk : P.InBk) : P.Face);
        ThemeDrawEdgeRaisedInnerLTR(dc, body);
        int clr;
        if (active) clr = hot ? (ActivePanel ? P.HotAct : P.HotIn) : (ActivePanel ? P.ActFg : P.InFg);
        else clr = hot ? P.HotPanel : P.Text;
        RECT tr = body;
        tr.left += pad; tr.right -= pad;
        bool closeGlyph = ShowsCloseGlyph(index);
        if (closeGlyph) tr.right -= glyph + pad;
        DrawTitle(dc, tr, Titles[index], clr);
        if (closeGlyph)
        {
            RECT cr;
            if (GetCloseRect(index, out cr))
            {
                bool closeHot = HotIndex == index && HotPart == tspClose;
                int gc = closeHot ? (active ? (ActivePanel ? P.HotAct : P.HotIn) : P.HotPanel) : clr;
                if (!active && !closeHot) gc = P.Text;
                GdiLines(dc, new int[] { cr.left, cr.top, cr.right, cr.bottom, cr.left, cr.bottom, cr.right, cr.top }, gc);
            }
        }
    }

    void PaintPlusCurrent(IntPtr dc)
    {
        int cx = (PlusRect.left + PlusRect.right) / 2, cy = (PlusRect.top + PlusRect.bottom) / 2, h = glyph / 2;
        int clr = HotPart == tspPlus ? P.HotPanel : P.Text;
        GdiLines(dc, new int[] { cx - h, cy, cx + h + 1, cy, cx, cy - h, cx, cy + h + 1 }, clr);
    }

    void PaintCurrent(IntPtr dc)
    {
        Fill(dc, Rc(0, 0, Width, Height), P.Face);
        Fill(dc, Rc(0, Height - 1, Width, Height), P.Shadow);
        for (int i = 0; i < Count; i++)
            if (i != Active) PaintTabCurrent(dc, i);
        PaintTabCurrent(dc, Active);
        PaintPlusCurrent(dc);
    }

    // ---------------------------------------------------------------- proposals
    int StripBg { get { return Rounded ? TabPal.Mix(P.Face, P.Shadow, P.Dark ? 0.5 : 0.22) : P.Face; } }
    int Dim { get { return TabPal.Mix(P.Text, StripBg, P.Dark ? 0.30 : 0.38); } }
    int HoverBg { get { return TabPal.Mix(StripBg, P.Text, P.Dark ? 0.10 : 0.07); } }
    int LineClr { get { return P.Dark ? P.Hilite : TabPal.Mix(P.Shadow, P.Face, 0.35); } }
    int SepClr { get { return P.Dark ? P.Hilite : TabPal.Mix(P.Shadow, StripBg, 0.30); } }
    int CapBk { get { return ActivePanel ? P.ActBk : P.InBk; } }
    int CapFg { get { return ActivePanel ? P.ActFg : P.InFg; } }
    int InactiveAccent { get { return P.Dark ? TabPal.RGB(110, 110, 110) : P.Shadow; } }

    int TextTop()
    {
        if (Rounded) return 3;
        if (Variant == 1 || Variant == 4) return 3; // below the 2 px accent
        return 1;
    }

    static GraphicsPath RoundRect(float x, float y, float w, float h, float rad)
    {
        GraphicsPath p = new GraphicsPath();
        float d = rad * 2;
        p.AddArc(x, y, d, d, 180, 90);
        p.AddArc(x + w - d, y, d, d, 270, 90);
        p.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        p.AddArc(x, y + h - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    void WithGraphics(IntPtr dc, Action<Graphics> a)
    {
        using (Graphics g = Graphics.FromHdc(dc))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            a(g);
        }
    }

    void DrawCross(Graphics g, float cx, float cy, float half, int clr, float width)
    {
        using (Pen pen = new Pen(C(clr), width))
        {
            pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
            g.DrawLine(pen, cx - half, cy - half, cx + half, cy + half);
            g.DrawLine(pen, cx - half, cy + half, cx + half, cy - half);
        }
    }
    void DrawPlusGlyph(Graphics g, float cx, float cy, float half, int clr, float width)
    {
        using (Pen pen = new Pen(C(clr), width))
        {
            pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
            g.DrawLine(pen, cx - half, cy, cx + half, cy);
            g.DrawLine(pen, cx, cy - half, cx, cy + half);
        }
    }

    // the tab body behind text: backgrounds, shapes
    void PaintTabBack(IntPtr dc, int index)
    {
        RECT r;
        if (!GetTabRect(index, out r)) return;
        bool active = index == Active;
        bool hot = HotIndex == index && (HotPart == tspTab || HotPart == tspClose);
        int H = Height;
        if (Variant == 1 || Variant == 4)
        {
            if (active)
            {
                Fill(dc, Rc(r.left, 1, r.right + 1, H), CapBk);
                Fill(dc, Rc(r.left, 1, r.left + 1, H), LineClr);
                Fill(dc, Rc(r.right, 1, r.right + 1, H), LineClr);
                Fill(dc, Rc(r.left, 1, r.right + 1, 3), ActivePanel ? P.Accent : InactiveAccent);
            }
            else if (hot)
                Fill(dc, Rc(r.left + 1, 3, r.right, H - 1), HoverBg);
        }
        else if (Rounded)
        {
            float rad = 6;
            if (active)
            {
                float L = r.left, Rr = r.right + 1, T = 3, B = H;
                WithGraphics(dc, g =>
                {
                    using (GraphicsPath p = new GraphicsPath())
                    {
                        p.AddArc(L - 2 * rad, B - 2 * rad, 2 * rad, 2 * rad, 90, -90); // left foot
                        p.AddLine(L, B - rad, L, T + rad);
                        p.AddArc(L, T, 2 * rad, 2 * rad, 180, 90);
                        p.AddLine(L + rad, T, Rr - rad, T);
                        p.AddArc(Rr - 2 * rad, T, 2 * rad, 2 * rad, 270, 90);
                        p.AddLine(Rr, T + rad, Rr, B - rad);
                        p.AddArc(Rr, B - 2 * rad, 2 * rad, 2 * rad, 180, -90); // right foot
                        p.CloseFigure();
                        using (SolidBrush b = new SolidBrush(C(CapBk))) g.FillPath(b, p);
                    }
                });
            }
            else if (hot)
            {
                WithGraphics(dc, g =>
                {
                    using (GraphicsPath p = RoundRect(r.left + 3, 4, r.right - r.left - 5, H - 7, 5))
                    using (SolidBrush b = new SolidBrush(C(HoverBg))) g.FillPath(b, p);
                });
            }
        }
        else if (Variant == 3)
        {
            if (hot && !active)
                WithGraphics(dc, g =>
                {
                    using (GraphicsPath p = RoundRect(r.left + 2, 3, r.right - r.left - 3, H - 7, 4))
                    using (SolidBrush b = new SolidBrush(C(HoverBg))) g.FillPath(b, p);
                });
            if (active)
                WithGraphics(dc, g =>
                {
                    using (GraphicsPath p = RoundRect(r.left + pad, H - 3, r.right - r.left - 2 * pad + 1, 3, 1.5f))
                    using (SolidBrush b = new SolidBrush(C(ActivePanel ? P.Accent : InactiveAccent))) g.FillPath(b, p);
                });
        }
    }

    bool Plain(int i) { return i >= 0 && i < Count && i != Active && i != HotIndex; }

    void PaintSeparators(IntPtr dc)
    {
        if (Variant == 3) return;
        int H = Height;
        int grow = Rounded ? (H - 25) / 2 : 0;
        int top = Rounded ? 8 + grow : 6, bottom = Rounded ? H - 6 - grow : H - 5;
        for (int i = 0; i + 1 < Count; i++)
        {
            if (!Plain(i) || !Plain(i + 1)) continue;
            RECT r;
            GetTabRect(i, out r);
            Fill(dc, Rc(r.right, top, r.right + 1, bottom), SepClr);
        }
    }

    void PaintTabFront(IntPtr dc, int index)
    {
        RECT r;
        if (!GetTabRect(index, out r)) return;
        bool active = index == Active;
        bool hot = HotIndex == index && (HotPart == tspTab || HotPart == tspClose);
        int clr;
        if (Variant == 3) clr = (active || hot) ? P.Text : Dim;
        else clr = active ? CapFg : (hot ? P.Text : Dim);
        RECT tr = Rc(r.left + pad, TextTop(), r.right - pad, Height - (Variant == 3 ? 2 : 0));
        if (Rounded) tr.bottom = Height;
        bool closeGlyph = ShowsCloseGlyph(index);
        if (closeGlyph) tr.right = r.right - closePad - glyph - 6;
        if (HasIcons)
        {
            SHFILEINFOW fi = new SHFILEINFOW();
            string path = IconPaths[index];
            if (path == "dir") SHGetFileInfoW("folder", 0x10, ref fi, (uint)Marshal.SizeOf(fi), 0x100 | 0x1 | 0x10);
            else SHGetFileInfoW(path, 0, ref fi, (uint)Marshal.SizeOf(fi), 0x100 | 0x1);
            if (fi.hIcon != IntPtr.Zero)
            {
                int iy = tr.top + (tr.bottom - tr.top - 16) / 2;
                DrawIconEx(dc, tr.left, iy, fi.hIcon, 16, 16, 0, IntPtr.Zero, 3);
                DestroyIcon(fi.hIcon);
            }
            tr.left += 16 + iconGap;
        }
        DrawTitle(dc, tr, Titles[index], clr);
        if (closeGlyph)
        {
            RECT cr;
            if (GetCloseRect(index, out cr))
            {
                bool closeHot = HotIndex == index && HotPart == tspClose;
                int bg = active && Variant != 3 ? CapBk : (hot ? HoverBg : StripBg);
                int baseClr = active ? (Variant == 3 ? P.Text : CapFg) : P.Text;
                float cx = cr.left + glyph / 2.0f, cy = cr.top + glyph / 2.0f;
                WithGraphics(dc, g =>
                {
                    if (closeHot)
                    {
                        int hb = TabPal.Mix(bg, baseClr, P.Dark ? 0.20 : 0.14);
                        using (SolidBrush b = new SolidBrush(C(hb)))
                        {
                            if (Rounded) g.FillEllipse(b, cx - 8, cy - 8, 16, 16);
                            else using (GraphicsPath p = RoundRect(cx - 8, cy - 8, 16, 16, 3)) g.FillPath(b, p);
                        }
                    }
                    DrawCross(g, cx, cy, 3.5f, closeHot ? baseClr : TabPal.Mix(baseClr, bg, 0.25), 1.2f);
                });
            }
        }
    }

    void PaintPlusNew(IntPtr dc)
    {
        bool hot = HotPart == tspPlus;
        float cx = (PlusRect.left + PlusRect.right) / 2.0f, cy = TextTop() + (Height - TextTop()) / 2.0f;
        if (Variant == 3) cy = (Height - 1) / 2.0f;
        WithGraphics(dc, g =>
        {
            if (hot)
            {
                using (SolidBrush b = new SolidBrush(C(HoverBg)))
                {
                    if (Rounded) g.FillEllipse(b, cx - 9, cy - 9, 18, 18);
                    else using (GraphicsPath p = RoundRect(cx - 9, cy - 9, 18, 18, 3)) g.FillPath(b, p);
                }
            }
            DrawPlusGlyph(g, cx, cy, 4.5f, hot ? P.Text : Dim, 1.2f);
        });
    }

    void PaintNew(IntPtr dc)
    {
        Fill(dc, Rc(0, 0, Width, Height), StripBg);
        if (Variant == 1 || Variant == 3 || Variant == 4)
            Fill(dc, Rc(0, Height - 1, Width, Height), LineClr);
        for (int i = 0; i < Count; i++)
            if (i != Active) PaintTabBack(dc, i);
        PaintTabBack(dc, Active);
        PaintSeparators(dc);
        for (int i = 0; i < Count; i++)
            PaintTabFront(dc, i);
        PaintPlusNew(dc);
    }

    public Bitmap Render()
    {
        EnsureFont();
        Height = NeededHeight(Variant);
        pad = Variant == 0 ? 4 : (Variant >= 5 ? 10 : 6);
        closePad = Variant == 0 ? 4 : (Variant >= 5 ? 8 : 6);
        iconGap = Variant >= 5 ? 6 : 5;
        glyph = 8;
        Layout();
        IntPtr screen = GetDC(IntPtr.Zero);
        IntPtr dc = CreateCompatibleDC(screen);
        IntPtr bmp = CreateCompatibleBitmap(screen, Width, Height);
        IntPtr oldBmp = SelectObject(dc, bmp);
        if (Variant == 0) PaintCurrent(dc); else PaintNew(dc);
        SelectObject(dc, oldBmp);
        Bitmap result = Image.FromHbitmap(bmp);
        DeleteObject(bmp);
        DeleteDC(dc);
        ReleaseDC(IntPtr.Zero, screen);
        return result;
    }

    // tab rectangle for the page's annotations (x of the hot targets)
    public int TabLeft(int i) { return TabsLeft + i * TabWidth; }
    public int TabW { get { return TabWidth; } }
    public int PlusLeft { get { return PlusRect.left; } }
}
