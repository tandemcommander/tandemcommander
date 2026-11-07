<#
.SYNOPSIS
    Feature 408 probe: the Markdown Viewer's code block copy control - hover shows it, a click
    copies the block's source (read through the Debug seam TC_MDVIEW_PROBE_COPY_LOG, never the
    real clipboard: the hidden desktop shares it), a native "Copied" notice (a tooltip window
    of the viewer, outside the page) appears with the copied first line and goes away, the page
    does not scroll, forged copy links do nothing, other links keep working.

.DESCRIPTION
    Fixture %TEMP%\tc408\files\a_doc.md: a fenced block (block 0, Czech + emoji), a magenta box
    holding a Markdown link to a forged copy address, a blue raw-HTML block link to a forged
    copy address, a green block link to foo.txt, a yellow block link to tc-copy-notes.md (an
    existing sibling file), an indented block (1), a list with a fenced block (2), 80 short
    filler lines. Code blocks are found in a PrintWindow capture as the tall runs of
    non-background pixels in the article's centre column.
    Rows (first start, seam = %TEMP%\tc408\seam\copy.txt, notice text in copy.txt.notice):
      OPEN      the viewer opens and three code blocks are found
      SHOWN     WM_MOUSEMOVE over block 0: pixels change in its top-right corner (the control);
                NOT DRIVEN when an ordinary link does not hover either (posted moves give no hover)
      COPY-0    click on block 0's control: the seam file holds exactly its CR LF text, the page
                did not move
      NOTICE    a visible tooltip window of the process at the viewer's bottom right; the notice
                text is "Copied" + the first copied line
      GONE      ... and it is hidden again 4 s later
      AGAIN     click on block 2's control: the seam file holds block 2; the notice shows again
      NOSCROLL  after a wheel scroll (when the engine takes it), a copy of block 1 leaves every
                block top where it was (NOT DRIVEN for the scrolled case when the wheel did not
                scroll; the unscrolled check is part of COPY-0)
      FORGED-MD click on the Markdown link to a forged copy address: no seam file, no window
      FORGED-HTML the same for the raw-HTML link
      LINK      click on foo.txt: the viewer's local-target box opens (links unchanged)
      LINK-TCCOPY click on tc-copy-notes.md: a viewer window opens (review 1, M2)
      KEY       after the foo.txt click, Tab moves to the next control in document order -
                block 1's - and shows it; Enter: the seam file holds block 1 (NOT DRIVEN when
                posted keys reach nothing)
      KEY-AGAIN Enter once more: the focus stayed on the control, block 1 is copied again
                (review 1, S1)
      SOURCE    View Source (101), click where block 0's control was: no seam file
    Second start (seam = the seam FOLDER, so the write fails):
      FAILCOPY  click on block 0's control: no notice appears (FR-005)
    Third start, the review 1 M1 fixture (the document's CSS stretches the genuine control over
    the page, makes it invisible, hides the block):
      HIJACK    a click on the page copies the hidden block - but never silently: the native
                notice is visible and its text names the hidden first line
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Cp408' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Cp408
{
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }

    // the client area of 'wnd' as a bitmap (PrintWindow PW_RENDERFULLCONTENT)
    public static Bitmap Client(IntPtr wnd, string saveAs)
    {
        RECT wr; GetWindowRect(wnd, out wr);
        RECT cr; GetClientRect(wnd, out cr);
        POINT o = new POINT(); ClientToScreen(wnd, ref o);
        int w = wr.Right - wr.Left, h = wr.Bottom - wr.Top;
        using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(wnd, dc, 2); g.ReleaseHdc(dc); }
            var c = bmp.Clone(new Rectangle(o.X - wr.Left, o.Y - wr.Top, cr.Right, cr.Bottom), PixelFormat.Format32bppArgb);
            if (saveAs != null) { try { c.Save(saveAs, ImageFormat.Png); } catch { } }
            return c;
        }
    }
    static int Diff(Color a, Color b) { return Math.Abs(a.R - b.R) + Math.Abs(a.G - b.G) + Math.Abs(a.B - b.B); }
    static bool Saturated(Color c) { int mx = Math.Max(c.R, Math.Max(c.G, c.B)), mn = Math.Min(c.R, Math.Min(c.G, c.B)); return mx - mn > 90; }
    public static Color Bg(Bitmap b) { return b.GetPixel(6, b.Height / 2); }
    // code blocks: runs (top,bottom) >= 40 px of unsaturated non-background pixels in column x
    public static string Blocks(Bitmap b, int x)
    {
        Color bg = Bg(b);
        var res = new List<string>();
        int start = -1, gap = 0, last = -1;
        for (int y = 0; y < b.Height; y++)
        {
            Color c = b.GetPixel(x, y);
            bool on = Diff(c, bg) > 20 && !Saturated(c);
            if (on) { if (start < 0) start = y; last = y; gap = 0; }
            else if (start >= 0 && ++gap > 2) { if (last - start >= 40) res.Add(start + "," + last); start = -1; gap = 0; }
        }
        if (start >= 0 && last - start >= 40) res.Add(start + "," + last);
        return string.Join(";", res.ToArray());
    }
    // the right edge of the non-background area in row y (skipping the right 'skip' px: the scroll bar)
    public static int RightEdge(Bitmap b, int y, int skip)
    {
        Color bg = Bg(b);
        for (int x = b.Width - 1 - skip; x > 0; x--) if (Diff(b.GetPixel(x, y), bg) > 20) return x;
        return -1;
    }
    // pixels differing from the background inside a rectangle
    public static int Ink(Bitmap b, int x0, int y0, int x1, int y1)
    {
        Color bg = Bg(b); int n = 0;
        for (int y = Math.Max(0, y0); y < Math.Min(b.Height, y1); y++)
            for (int x = Math.Max(0, x0); x < Math.Min(b.Width, x1); x++) if (Diff(b.GetPixel(x, y), bg) > 40) n++;
        return n;
    }
    // pixels that differ between two captures inside a rectangle
    public static int Changed(Bitmap a, Bitmap b, int x0, int y0, int x1, int y1)
    {
        int n = 0;
        for (int y = Math.Max(0, y0); y < Math.Min(Math.Min(a.Height, b.Height), y1); y++)
            for (int x = Math.Max(0, x0); x < Math.Min(Math.Min(a.Width, b.Width), x1); x++) if (Diff(a.GetPixel(x, y), b.GetPixel(x, y)) > 40) n++;
        return n;
    }
    // first row holding a pixel of the given kind: 0 magenta, 1 blue, 2 green
    public static string ColorBox(Bitmap b, int kind)
    {
        for (int y = 0; y < b.Height; y++)
            for (int x = 0; x < b.Width; x += 2)
            {
                Color c = b.GetPixel(x, y);
                bool m = kind == 0 ? (c.R > 200 && c.G < 110 && c.B > 200) : kind == 1 ? (c.B > 220 && c.R < 70 && c.G < 70) :
                         kind == 2 ? (c.G > 200 && c.R < 170 && c.B < 110) : (c.R > 220 && c.G > 200 && c.B < 90);
                if (m) return x + "," + y;
            }
        return "";
    }
    public static void Move(IntPtr h, int x, int y) { PostMessageW(h, 0x0200, IntPtr.Zero, (IntPtr)((y << 16) | (x & 0xFFFF))); }
    public static void Wheel(IntPtr h, int sx, int sy, int delta) { PostMessageW(h, 0x020A, (IntPtr)((delta & 0xFFFF) << 16), (IntPtr)((sy << 16) | (sx & 0xFFFF))); }
    public static void KeyPress(IntPtr h, int vk, int ch)
    {
        PostMessageW(h, 0x0100, (IntPtr)vk, (IntPtr)1);
        if (ch != 0) PostMessageW(h, 0x0102, (IntPtr)ch, (IntPtr)1);
        PostMessageW(h, 0x0101, (IntPtr)vk, (IntPtr)unchecked((int)0xC0000001));
    }
}
'@
}

$Root = $TempRoot + '\tc408'
$Files = $Root + '\files'
$Files2 = $Root + '\files2'
$SeamDir = $Root + '\seam'
$Seam = $SeamDir + '\copy.txt'
$Forged = 'https://mdcopy.invalid/00000000000000000000000000000000-1/0'

function Put-Text([string]$Path, [string]$Text) {
    if (-not $Path.StartsWith($Root + '\')) { throw "outside the fixture: $Path" }
    [IO.File]::WriteAllBytes($LP + $Path, $Utf8.GetBytes($Text))
}
function Seam-Clear { if ([IO.File]::Exists($Seam)) { [IO.File]::Delete($Seam) } }
function Seam-Read { if ([IO.File]::Exists($Seam)) { return [IO.File]::ReadAllText($Seam, $Utf8) } else { return $null } }
function Show([string]$s) { if ($null -eq $s) { return '<none>' }; return (Esc ($s -replace "`r", '\r' -replace "`n", '\n')) }
function Shot([IntPtr]$W, [string]$Tag) {
    $png = $null; if ($OutFile) { $png = [IO.Path]::Combine([IO.Path]::GetDirectoryName($OutFile), ('shot_{0}_{1}.png' -f $Label, $Tag)) }
    return [Cp408]::Client($W, $png)
}
function Render-Kid([IntPtr]$W) {
    foreach ($k in [Drv098f]::Kids($W)) { if ([Drv098f]::Cls($k) -eq 'Chrome_RenderWidgetHostHWND') { return $k } }
    return [IntPtr]::Zero
}
function Parse-Blocks([string]$s) { if (-not $s) { return @() }; return @($s.Split(';') | ForEach-Object { , @([int]$_.Split(',')[0], [int]$_.Split(',')[1]) }) }
function Open-Viewer([int]$Id) {
    Key $Id 0x24; Key $Id 0x28
    Start-Sleep -Milliseconds 400
    $w = Open-ByCmd $Id 742 20
    if ($w -eq [IntPtr]::Zero -or [Drv098f]::Txt($w) -notlike '*Markdown Viewer*') { return [IntPtr]::Zero }
    [void][Cp408]::SetWindowPos($w, [IntPtr]::Zero, 0, 0, 1200, 900, 0x0014)
    Start-Sleep -Milliseconds 5000
    return $w
}
# the control of a block: right edge of the block minus 30, top plus 17 (CSS px * scale)
function Ctl-Point($Bmp, $Blk, [double]$Scale) {
    $r = [Cp408]::RightEdge($Bmp, $Blk[0] + [int](4 * $Scale), 20)
    return @(($r - [int](30 * $Scale)), ($Blk[0] + [int](17 * $Scale)), $r)
}
# the native notice: a visible tooltip window of the process inside the viewer's bottom-right
# quarter; returns its rectangle as text, or '' when none is visible
function Notice([int]$Id, [IntPtr]$W) {
    $vr = New-Object Cp408+RECT; [void][Cp408]::GetWindowRect($W, [ref]$vr)
    foreach ($h in [Drv098f]::Top([uint32]$Id)) {
        if ([Drv098f]::Cls($h) -ne 'tooltips_class32' -or -not [Drv098f]::IsWindowVisible($h)) { continue }
        $r = New-Object Cp408+RECT; [void][Cp408]::GetWindowRect($h, [ref]$r)
        if ($r.Left -ge ($vr.Left + $vr.Right) / 2 -and $r.Top -ge ($vr.Top + $vr.Bottom) / 2 -and $r.Right -le $vr.Right -and $r.Bottom -le $vr.Bottom) { return ('{0},{1}-{2},{3}' -f $r.Left, $r.Top, $r.Right, $r.Bottom) }
    }
    return ''
}
# every tooltip window of the process (diagnostics)
function Tips([int]$Id) {
    $o = @()
    foreach ($h in [Drv098f]::Top([uint32]$Id)) {
        if ([Drv098f]::Cls($h) -ne 'tooltips_class32') { continue }
        $r = New-Object Cp408+RECT; [void][Cp408]::GetWindowRect($h, [ref]$r)
        $o += ('{0}:{1}:{2},{3}-{4},{5}' -f $h, $(if ([Drv098f]::IsWindowVisible($h)) { 'vis' } else { 'hid' }), $r.Left, $r.Top, $r.Right, $r.Bottom)
    }
    return ($o -join ' ')
}
function Notice-Text { $f = $Seam + '.notice'; if ([IO.File]::Exists($f)) { return [IO.File]::ReadAllText($f, $Utf8) } else { return $null } }
function Notice-Clear { $f = $Seam + '.notice'; if ([IO.File]::Exists($f)) { [IO.File]::Delete($f) } }

$cz = 'beta ' + [char]0x010D + 'e' + [char]0x0161 + 'tina ' + [char]0xD83D + [char]0xDE00
$Expect0 = "alpha line 1`r`n" + $cz
$Expect1 = "indented one`r`n  indented two"
$Expect2 = "in list"
$filler = (1..80 | ForEach-Object { "Filler $_." }) -join "`n`n"
$doc = "``````text`nalpha line 1`n" + $cz + "`n```````n`nShort.`n`n" +
"<div style=`"background:#ff00ff;width:300px;padding:20px`">`n`n[FORGED MARKDOWN LINK XXXXXXXXX](" + $Forged + ")`n`n</div>`n`n" +
"<a href=`"" + $Forged + "`" style=`"display:block;width:300px;height:60px;background:#0000ff`"></a>`n`n" +
"<a href=`"foo.txt`" style=`"display:block;width:300px;height:60px;background:#00ff00`"></a>`n`n" +
"<a href=`"tc-copy-notes.md`" style=`"display:block;width:300px;height:60px;background:#ffff00`"></a>`n`n" +
"Short.`n`n    indented one`n      indented two`n`nShort.`n`n- item`n`n  ```````n  in list`n  ```````n`n" + $filler + "`n"

$backup = Join-Path $env:TEMP 'tc408_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $Files; NewDir $Files2; NewDir $SeamDir
    Set-Config
    Put-Text "$Files\a_doc.md" $doc
    Put-Text "$Files\tc-copy-notes.md" "# Notes`n`nA sibling file.`n"
    Out ("copy408_probe (feature 408) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; desktop {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [DeskLib098]::Name())
    Out ''

    # ---------------- first start: the seam writes a file ----------------
    $env:TC_MDVIEW_PROBE_COPY_LOG = $Seam
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'OPEN' 'RUN' 'FAIL' 'no Markdown Viewer window' }
        else {
            $scale = [Cp408]::GetDpiForWindow($w) / 96.0
            $rk = Render-Kid $w
            $b0 = Shot $w 'start'
            $cx = [int]($b0.Width / 2)
            $blocks = Parse-Blocks ([Cp408]::Blocks($b0, $cx))
            Row 'OPEN' 'RUN' (V (($rk -ne [IntPtr]::Zero) -and $blocks.Count -ge 3)) ("render widget {0}; blocks at column {1}: {2}; scale {3}" -f $rk, $cx, (($blocks | ForEach-Object { $_ -join '-' }) -join ' '), $scale)
            if ($rk -ne [IntPtr]::Zero -and $blocks.Count -ge 3) {
                # SHOWN: hover over block 0
                $p0 = Ctl-Point $b0 $blocks[0] $scale
                # a real pointer enters the page first and then moves over the block
                [Cp408]::Move($rk, 5, $b0.Height - 5)
                Start-Sleep -Milliseconds 300
                [Cp408]::Move($rk, $cx, $blocks[0][0] + 30)
                Start-Sleep -Milliseconds 300
                [Cp408]::Move($rk, $cx + 6, $blocks[0][0] + 32)
                Start-Sleep -Milliseconds 700
                $b1 = Shot $w 'hover'
                $ch = [Cp408]::Changed($b0, $b1, $p0[2] - [int](70 * $scale), $blocks[0][0], $p0[2] + 2, $blocks[0][0] + [int](34 * $scale))
                if ($ch -gt 40) { Row 'SHOWN' 'RUN' 'PASS' ("pixels changed in block 0's top-right corner: {0}; control point {1},{2}" -f $ch, $p0[0], $p0[1]) }
                else {
                    # control: does a posted move hover anything here? An ordinary document link
                    # (the magenta box's) underlines on hover since feature 021.
                    $mg = [Cp408]::ColorBox($b0, 0); $lch = -1
                    if ($mg) {
                        $mx = [int]$mg.Split(',')[0]; $my = [int]$mg.Split(',')[1]
                        [Cp408]::Move($rk, $mx + [int](40 * $scale), $my + [int](43 * $scale))
                        Start-Sleep -Milliseconds 300
                        [Cp408]::Move($rk, $mx + [int](46 * $scale), $my + [int](44 * $scale))
                        Start-Sleep -Milliseconds 700
                        $bl = Shot $w 'hoverlink'
                        $lch = [Cp408]::Changed($b1, $bl, $mx, $my, $mx + [int](300 * $scale), $my + [int](110 * $scale))
                    }
                    if ($lch -eq 0) { Row 'SHOWN' 'RUN' 'NOT DRIVEN' ("posted moves hover nothing here: block corner {0} px, an ordinary link {1} px changed (the look on hover is a person's check)" -f $ch, $lch) }
                    else { Row 'SHOWN' 'RUN' 'FAIL' ("block corner {0} px changed, while an ordinary link changed {1} px on hover" -f $ch, $lch) }
                    [Cp408]::Move($rk, $cx, $blocks[0][0] + 30)
                    Start-Sleep -Milliseconds 300
                }

                # COPY-0 + NOTICE + GONE
                Seam-Clear; Notice-Clear
                $n0 = Notice $id $w
                Post-Click $rk $p0[0] $p0[1]
                Start-Sleep -Milliseconds 1000
                $n1 = Notice $id $w
                $b2 = Shot $w 'copied0'
                $got = Seam-Read
                $blocksAfter = Parse-Blocks ([Cp408]::Blocks($b2, $cx))
                $same = ($blocksAfter.Count -eq $blocks.Count) -and ($blocksAfter[0][0] -eq $blocks[0][0])
                Row 'COPY-0' 'RUN' (V (($got -ceq $Expect0) -and $same)) ("seam '{0}' (want '{1}'); block 0 top {2} -> {3}" -f (Show $got), (Show $Expect0), $blocks[0][0], $(if ($blocksAfter.Count) { $blocksAfter[0][0] } else { '-' }))
                $nt = Notice-Text
                $vr = New-Object Cp408+RECT; [void][Cp408]::GetWindowRect($w, [ref]$vr)
                Row 'NOTICE' 'RUN' (V (($n0 -eq '') -and ($n1 -ne '') -and ($nt -ceq "Copied`nalpha line 1"))) ("tooltip before '{0}', 1 s after the copy '{1}' (viewer {3},{4}-{5},{6}, bottom-right quarter); text '{2}'; all tooltips: {7}" -f $n0, $n1, (Show $nt), $vr.Left, $vr.Top, $vr.Right, $vr.Bottom, (Tips $id))
                Start-Sleep -Milliseconds 3000
                $n2 = Notice $id $w
                Row 'GONE' 'RUN' (V ($n2 -eq '')) ("tooltip 4 s after the copy: '{0}'" -f $n2)

                # AGAIN: block 2
                Seam-Clear; Notice-Clear
                $p2 = Ctl-Point $b2 $blocks[2] $scale
                [Cp408]::Move($rk, $cx, $blocks[2][0] + 20)
                Start-Sleep -Milliseconds 300
                Post-Click $rk $p2[0] $p2[1]
                Start-Sleep -Milliseconds 1000
                $n3 = Notice $id $w
                $got = Seam-Read
                $nt = Notice-Text
                Row 'AGAIN' 'RUN' (V (($got -ceq $Expect2) -and ($n3 -ne '') -and ($nt -ceq "Copied`nin list"))) ("seam '{0}' (want '{1}'); tooltip '{2}'; text '{3}'" -f (Show $got), (Show $Expect2), $n3, (Show $nt))
                Start-Sleep -Milliseconds 3000

                # NOSCROLL: scroll by the wheel, then copy block 1
                $o = New-Object Cp408+POINT; [void][Cp408]::ClientToScreen($rk, [ref]$o)
                [Cp408]::Wheel($rk, $o.X + $cx, $o.Y + 300, -120)
                Start-Sleep -Milliseconds 900
                $b5 = Shot $w 'scrolled'
                $bs = Parse-Blocks ([Cp408]::Blocks($b5, $cx))
                $scrolled = ($bs.Count -ge 1) -and ($bs[0][0] -ne $blocks[0][0])
                # block 1 in the scrolled page: the block whose height matches block 1's
                $h1 = $blocks[1][1] - $blocks[1][0]
                $k1 = @($bs | Where-Object { [Math]::Abs(($_[1] - $_[0]) - $h1) -le 2 -and $_[0] -gt 0 })
                if (-not $scrolled -or $k1.Count -eq 0) { Row 'NOSCROLL' 'RUN' 'NOT DRIVEN' ("the wheel did not scroll the page (block tops {0}); the unscrolled case is in COPY-0" -f (($bs | ForEach-Object { $_ -join '-' }) -join ' ')) }
                else {
                    Seam-Clear
                    $q = Ctl-Point $b5 $k1[0] $scale
                    [Cp408]::Move($rk, $cx, $k1[0][0] + 20)
                    Start-Sleep -Milliseconds 300
                    Post-Click $rk $q[0] $q[1]
                    Start-Sleep -Milliseconds 1200
                    $b6 = Shot $w 'scrolledcopy'
                    $bs2 = Parse-Blocks ([Cp408]::Blocks($b6, $cx))
                    $got = Seam-Read
                    $tops1 = ($bs | ForEach-Object { $_[0] }) -join ','; $tops2 = ($bs2 | ForEach-Object { $_[0] }) -join ','
                    Row 'NOSCROLL' 'RUN' (V (($got -ceq $Expect1) -and ($tops1 -eq $tops2))) ("scrolled block tops {0} -> after the copy {1}; seam '{2}' (want '{3}')" -f $tops1, $tops2, (Show $got), (Show $Expect1))
                    Start-Sleep -Milliseconds 4000
                }
                # back to the top for the link rows: Ctrl+Home is a browser key; reopen instead
                [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
                Start-Sleep -Milliseconds 2000
                $w = Open-Viewer $id
                $rk = Render-Kid $w
                $b7 = Shot $w 'links'
                foreach ($case in @(@('FORGED-MD', 0, 40), @('FORGED-HTML', 1, 30))) {
                    $pt = [Cp408]::ColorBox($b7, $case[1])
                    if (-not $pt) { Row $case[0] 'RUN' 'NOT DRIVEN' 'the coloured box was not found'; continue }
                    $x = [int]$pt.Split(',')[0] + [int](($case[2] + 10) * $scale); $y = [int]$pt.Split(',')[1] + [int]($case[2] * $scale)
                    Seam-Clear
                    $known = Get-Tops $id
                    Post-Click $rk $x $y
                    $nw = Wait-NewWin $id $known 3
                    $got = Seam-Read
                    $desc = if ($nw -ne [IntPtr]::Zero) { WinDesc $nw } else { 'none' }
                    if ($nw -ne [IntPtr]::Zero) { Click-Ok $nw }
                    Row $case[0] 'RUN' (V (($null -eq $got) -and ($nw -eq [IntPtr]::Zero))) ("click at {0},{1}: seam {2}; new window {3}" -f $x, $y, (Show $got), $desc)
                }
                $pt = [Cp408]::ColorBox($b7, 2)
                if (-not $pt) { Row 'LINK' 'RUN' 'NOT DRIVEN' 'the green box was not found' }
                else {
                    $known = Get-Tops $id
                    Post-Click $rk ([int]$pt.Split(',')[0] + [int](40 * $scale)) ([int]$pt.Split(',')[1] + [int](30 * $scale))
                    $nw = Wait-NewWin $id $known 6
                    if ($nw -ne [IntPtr]::Zero) { Row 'LINK' 'RUN' (V ((FullText $nw) -like '*foo.txt*')) ('box: ' + (WinDesc $nw)); Click-Ok $nw }
                    else { Row 'LINK' 'RUN' 'FAIL' 'no window after the click on foo.txt' }
                }
                # LINK-TCCOPY (review 1, M2): a sibling file whose name starts "tc-copy-" opens
                $py = [Cp408]::ColorBox($b7, 3)
                if (-not $py) { Row 'LINK-TCCOPY' 'RUN' 'NOT DRIVEN' 'the yellow box was not found' }
                else {
                    $known = Get-Tops $id
                    Post-Click $rk ([int]$py.Split(',')[0] + [int](40 * $scale)) ([int]$py.Split(',')[1] + [int](30 * $scale))
                    $nw = Wait-NewWin $id $known 12
                    if ($nw -ne [IntPtr]::Zero) {
                        Start-Sleep -Milliseconds 1500
                        Row 'LINK-TCCOPY' 'RUN' (V ([Drv098f]::Txt($nw) -like '*tc-copy-notes.md*')) ('new window: ' + (WinDesc $nw))
                        [void][Drv098f]::PostMessageW($nw, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
                        Start-Sleep -Milliseconds 1500
                    }
                    else { Row 'LINK-TCCOPY' 'RUN' 'FAIL' 'no window after the click on tc-copy-notes.md' }
                }
                # KEY: the last click was the foo.txt link, so Tab moves to the next focusable
                # element in document order - block 1's control; Enter copies block 1
                Seam-Clear
                [Cp408]::Move($rk, 5, $b7.Height - 5)
                Start-Sleep -Milliseconds 300
                $bk0 = Shot $w 'key0'
                [Cp408]::KeyPress($rk, 0x09, 0)
                Start-Sleep -Milliseconds 600
                $bk1 = Shot $w 'keyfocus'
                $pk = Ctl-Point $bk0 $blocks[1] $scale
                $focusCh = [Cp408]::Changed($bk0, $bk1, $pk[2] - [int](70 * $scale), $blocks[1][0], $pk[2] + 2, $blocks[1][0] + [int](34 * $scale))
                [Cp408]::KeyPress($rk, 0x0D, 13)
                Start-Sleep -Milliseconds 1200
                $got = Seam-Read
                if ($null -eq $got -and $focusCh -lt 20) { Row 'KEY' 'RUN' 'NOT DRIVEN' ("posted Tab/Enter changed nothing (corner pixels {0}, no seam file)" -f $focusCh) }
                else { Row 'KEY' 'RUN' (V (($got -ceq $Expect1) -and ($focusCh -gt 40))) ("focus shows block 1's control: {0} px changed; seam '{1}' (want '{2}')" -f $focusCh, (Show $got), (Show $Expect1)) }
                # KEY-AGAIN (review 1, S1): the focus stays on the control after a copy
                Seam-Clear
                [Cp408]::KeyPress($rk, 0x0D, 13)
                Start-Sleep -Milliseconds 1200
                $got = Seam-Read
                $bk2 = Shot $w 'keyagain'
                $still = [Cp408]::Changed($bk0, $bk2, $pk[2] - [int](70 * $scale), $blocks[1][0], $pk[2] + 2, $blocks[1][0] + [int](34 * $scale))
                Row 'KEY-AGAIN' 'RUN' (V (($got -ceq $Expect1) -and ($still -gt 40))) ("second Enter: seam '{0}'; control still shown {1} px" -f (Show $got), $still)
                Start-Sleep -Milliseconds 3000
                # SOURCE: View Source, click where block 0's control was
                Post-Cmd $w 101
                Start-Sleep -Milliseconds 3000
                $bsrc = Shot $w 'source'
                Seam-Clear
                [Cp408]::Move($rk, $cx, $blocks[0][0] + 20)
                Start-Sleep -Milliseconds 300
                Post-Click $rk $p0[0] $p0[1]
                Start-Sleep -Milliseconds 1200
                $got = Seam-Read
                $title = [Drv098f]::Txt($w)
                Row 'SOURCE' 'RUN' (V (($null -eq $got) -and ($title -like '*[Source]*'))) ("title '{0}'; seam {1}" -f (Esc $title), (Show $got))
            }
            [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 1500
        }
    }
    catch { Row 'FIRST' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'FIRST' $id $null $before } }

    # ---------------- second start: the seam cannot write (a folder) ----------------
    $env:TC_MDVIEW_PROBE_COPY_LOG = $SeamDir
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'FAILCOPY' 'RUN' 'FAIL' 'no Markdown Viewer window' }
        else {
            $scale = [Cp408]::GetDpiForWindow($w) / 96.0
            $rk = Render-Kid $w
            $b0 = Shot $w 'fail0'
            $cx = [int]($b0.Width / 2)
            $blocks = Parse-Blocks ([Cp408]::Blocks($b0, $cx))
            if ($rk -eq [IntPtr]::Zero -or $blocks.Count -lt 1) { Row 'FAILCOPY' 'RUN' 'NOT DRIVEN' 'no block found' }
            else {
                $p0 = Ctl-Point $b0 $blocks[0] $scale
                [Cp408]::Move($rk, $cx, $blocks[0][0] + 30)
                Start-Sleep -Milliseconds 500
                Post-Click $rk $p0[0] $p0[1]
                Start-Sleep -Milliseconds 1000
                $nn = Notice $id $w
                Row 'FAILCOPY' 'RUN' (V ($nn -eq '')) ("seam = a folder (write fails): tooltip '{0}'" -f $nn)
            }
            [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 1500
        }
    }
    catch { Row 'SECOND' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'SECOND' $id $null $before } }

    # ---------------- third start: review 1 M1, a document restyles the genuine control ----------------
    $env:TC_MDVIEW_PROBE_COPY_LOG = $Seam
    $hdoc = "<style>.tc-copy{position:fixed!important;left:0!important;top:0!important;width:100vw!important;height:100vh!important;opacity:0!important;pointer-events:auto!important;z-index:99!important}.tc-code pre{display:none!important}</style>`n`n" +
    "# Harmless page`n`n<a href=`"other-notes.md`" style=`"display:block;width:300px;height:60px;background:#0000ff`"></a>`n`n``````text`nHIDDEN PAYLOAD`n```````n"
    Put-Text "$Files2\h_doc.md" $hdoc
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files2
        [void](Serve $id 10)
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'HIJACK' 'RUN' 'FAIL' 'no Markdown Viewer window' }
        else {
            $scale = [Cp408]::GetDpiForWindow($w) / 96.0
            $rk = Render-Kid $w
            $b0 = Shot $w 'hijack0'
            $pt = [Cp408]::ColorBox($b0, 1)
            if ($rk -eq [IntPtr]::Zero -or -not $pt) { Row 'HIJACK' 'RUN' 'NOT DRIVEN' 'the blue box was not found' }
            else {
                Seam-Clear; Notice-Clear
                Post-Click $rk ([int]$pt.Split(',')[0] + [int](40 * $scale)) ([int]$pt.Split(',')[1] + [int](30 * $scale))
                Start-Sleep -Milliseconds 1000
                $nn = Notice $id $w
                $got = Seam-Read
                $nt = Notice-Text
                [void](Shot $w 'hijack1')
                # the copy itself is the document's own (hidden) block; what must hold is that it
                # is never silent and the notice names what was copied
                Row 'HIJACK' 'RUN' (V (($got -ceq 'HIDDEN PAYLOAD') -and ($nn -ne '') -and ($nt -ceq "Copied`nHIDDEN PAYLOAD"))) ("seam '{0}'; tooltip '{1}'; text '{2}'" -f (Show $got), $nn, (Show $nt))
            }
            [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 1500
        }
    }
    catch { Row 'THIRD' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'THIRD' $id $null $before } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    Remove-Item Env:\TC_MDVIEW_PROBE_COPY_LOG -ErrorAction SilentlyContinue
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
