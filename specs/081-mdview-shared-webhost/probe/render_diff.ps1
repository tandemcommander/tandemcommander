<#
.SYNOPSIS
    Renders the same document in the pre-migration (reference) build and in the
    migrated build and compares the two viewer client areas pixel by pixel.

.DESCRIPTION
    This is the check that no on-screen detail of the Markdown Viewer moved
    when it was put on the shared WebView2 host (feature 081, spec User Story
    1). Both trees share the WebView2 runtime and the registry - schemes, zoom
    and window placement come out of the same keys - so a differing image can
    only come from the served document or from the surface settings.

    For each executable: start it with both panels on the fixture folder, view
    the document, move the viewer window to a fixed rectangle, wait for the
    render to settle, capture the CLIENT area, close everything.

    A small tolerance is applied per channel (anti-aliasing and subpixel text
    rendering are not bit-stable between two runs of the same build either),
    and the verdict is the share of differing pixels.

.NOTES
    Windows PowerShell 5.1 compatible. Needs a visible desktop session: the
    capture is a screen grab, so the viewer window must actually be on screen
    (do not run this over a disconnected RDP session).

    Debug builds pop the pre-existing "Detected memory leaks!" dialog on exit
    (fix-log T002b); it is dismissed and ignored.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Ref,
    [Parameter(Mandatory = $true)][string]$New,
    [string]$File = "$env:TEMP\md081\10-legit-control.md",
    # empty means "beside this script": $PSScriptRoot is NOT yet populated when
    # a parameter default is evaluated under -File, which silently dropped the
    # captures into the current drive's root.
    [string]$OutDir = '',
    [int]$X = 100, [int]$Y = 100, [int]$W = 1000, [int]$H = 800,
    [int]$Tolerance = 8,
    [double]$MaxDiffPercent = 0.1
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Rdf
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);

    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(1024); GetWindowTextW(h, s, 1024); return s.ToString(); }

    // The comparison runs here, not in PowerShell: 800 000 GetPixel calls
    // through the PS interop take minutes, a LockBits walk takes milliseconds.
    // Returns the number of differing pixels and paints 'diff' red where they
    // are (and the reference pixel elsewhere).
    public static long Compare(System.Drawing.Bitmap a, System.Drawing.Bitmap b,
                               System.Drawing.Bitmap diff, int tolerance)
    {
        var rect = new System.Drawing.Rectangle(0, 0, a.Width, a.Height);
        var fmt = System.Drawing.Imaging.PixelFormat.Format32bppArgb;
        var la = a.LockBits(rect, System.Drawing.Imaging.ImageLockMode.ReadOnly, fmt);
        var lb = b.LockBits(rect, System.Drawing.Imaging.ImageLockMode.ReadOnly, fmt);
        var ld = diff.LockBits(rect, System.Drawing.Imaging.ImageLockMode.WriteOnly, fmt);
        long differing = 0;
        try
        {
            int bytes = Math.Abs(la.Stride) * a.Height;
            byte[] ba = new byte[bytes], bb = new byte[bytes], bd = new byte[bytes];
            Marshal.Copy(la.Scan0, ba, 0, bytes);
            Marshal.Copy(lb.Scan0, bb, 0, bytes);
            for (int i = 0; i < bytes; i += 4)
            {
                bool d = Math.Abs(ba[i] - bb[i]) > tolerance
                      || Math.Abs(ba[i + 1] - bb[i + 1]) > tolerance
                      || Math.Abs(ba[i + 2] - bb[i + 2]) > tolerance;
                if (d)
                {
                    differing++;
                    bd[i] = 0; bd[i + 1] = 0; bd[i + 2] = 255; bd[i + 3] = 255; // red
                }
                else
                {
                    bd[i] = ba[i]; bd[i + 1] = ba[i + 1]; bd[i + 2] = ba[i + 2]; bd[i + 3] = 255;
                }
            }
            Marshal.Copy(bd, 0, ld.Scan0, bytes);
        }
        finally { a.UnlockBits(la); b.UnlockBits(lb); diff.UnlockBits(ld); }
        return differing;
    }
    public static List<IntPtr> Top(uint pid)
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static List<IntPtr> Kids(IntPtr parent)
    {
        var l = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr p) { l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
}
'@

$MainClass = 'TandemCommanderMainWindowVer01'
$CM_VIEW = 742

function Get-Main([int]$procId) {
    foreach ($h in [Rdf]::Top([uint32]$procId)) { if ([Rdf]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}
function Get-Viewer([int]$procId) {
    foreach ($h in [Rdf]::Top([uint32]$procId)) {
        if ([Rdf]::IsWindowVisible($h) -and [Rdf]::Txt($h) -like '*Markdown Viewer*') { return $h }
    }
    return [IntPtr]::Zero
}
function Dismiss([int]$procId) {
    foreach ($h in [Rdf]::Top([uint32]$procId)) {
        if ([Rdf]::IsWindowVisible($h) -and [Rdf]::Cls($h) -eq '#32770') {
            $b = [Rdf]::GetDlgItem($h, 2)
            if ($b -ne [IntPtr]::Zero) { [void][Rdf]::PostMessageW($b, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
        }
    }
}

function Capture([string]$exe, [string]$tag) {
    $folder = Split-Path -Parent $File
    $name = Split-Path -Leaf $File
    $args = @('-t', "RD$tag", '-l', ('"{0}"' -f $folder), '-r', ('"{0}"' -f $folder))
    $p = Start-Process -FilePath $exe -ArgumentList $args -PassThru
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 150 }
    Start-Sleep -Seconds 3

    # put the cursor on the file: Home, then one Down per preceding entry
    $m = Get-Main $p.Id
    $lists = @([Rdf]::Kids($m) | Where-Object { [Rdf]::Cls($_) -eq 'SalamanderItemsBox' -and [Rdf]::IsWindowVisible($_) })
    $names = @(Get-ChildItem -LiteralPath $folder -Directory | Sort-Object Name | ForEach-Object { $_.Name }) +
             @(Get-ChildItem -LiteralPath $folder -File | Sort-Object Name | ForEach-Object { $_.Name })
    $idx = [array]::IndexOf($names, $name)
    if ($idx -lt 0) { throw "file '$name' not found in $folder" }
    foreach ($l in $lists) {
        [void][Rdf]::PostMessageW($l, 0x0100, [IntPtr]0x24, [IntPtr]1)
        [void][Rdf]::PostMessageW($l, 0x0101, [IntPtr]0x24, [IntPtr]0xC0000001)
    }
    Start-Sleep -Milliseconds 300
    for ($i = 0; $i -le $idx; $i++) {
        foreach ($l in $lists) {
            [void][Rdf]::PostMessageW($l, 0x0100, [IntPtr]0x28, [IntPtr]1)
            [void][Rdf]::PostMessageW($l, 0x0101, [IntPtr]0x28, [IntPtr]0xC0000001)
        }
        Start-Sleep -Milliseconds 25
    }
    Start-Sleep -Milliseconds 400

    [void][Rdf]::PostMessageW((Get-Main $p.Id), 0x0111, [IntPtr]$CM_VIEW, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $v = [IntPtr]::Zero
    while ($sw.Elapsed.TotalSeconds -lt 30 -and $v -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 150; $v = Get-Viewer $p.Id }
    if ($v -eq [IntPtr]::Zero) { throw "$tag : the viewer window never appeared" }

    # SWP_NOZORDER=4 | SWP_NOACTIVATE=0x10 are NOT passed: the window must be on
    # top and active, because this is a screen capture.
    [void][Rdf]::SetWindowPos($v, [IntPtr]::Zero, $X, $Y, $W, $H, 0)
    [void][Rdf]::SetForegroundWindow($v)
    Start-Sleep -Seconds 3      # let the engine finish painting

    $rc = New-Object Rdf+RECT
    [void][Rdf]::GetClientRect($v, [ref]$rc)
    $pt = New-Object Rdf+POINT
    $pt.X = 0; $pt.Y = 0
    [void][Rdf]::ClientToScreen($v, [ref]$pt)

    $bmp = New-Object System.Drawing.Bitmap($rc.Right, $rc.Bottom)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($pt.X, $pt.Y, 0, 0, (New-Object System.Drawing.Size($rc.Right, $rc.Bottom)))
    $g.Dispose()

    $png = Join-Path $OutDir "render-$tag.png"
    $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)

    [void][Rdf]::PostMessageW($v, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Seconds 1
    [void][Rdf]::PostMessageW((Get-Main $p.Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 400
        if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) { break }
        Dismiss $p.Id
    }
    if (Get-Process -Id $p.Id -ErrorAction SilentlyContinue) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }

    Write-Host ("  captured {0}: {1}x{2} -> {3}" -f $tag, $rc.Right, $rc.Bottom, $png)
    return @{ Bitmap = $bmp; Path = $png }
}

if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $PSScriptRoot 'out' }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
if (-not (Test-Path $Ref)) { throw "reference executable not found: $Ref" }
if (-not (Test-Path $New)) { throw "migrated executable not found: $New" }
if (-not (Test-Path $File)) { throw "document not found: $File" }

Write-Host "render diff (feature 081)"
Write-Host "  reference : $Ref"
Write-Host "  migrated  : $New"
Write-Host "  document  : $File"

$a = Capture $Ref 'reference'
$b = Capture $New 'migrated'

if ($a.Bitmap.Width -ne $b.Bitmap.Width -or $a.Bitmap.Height -ne $b.Bitmap.Height) {
    Write-Host ("FAIL: different client sizes: {0}x{1} vs {2}x{3}" -f `
        $a.Bitmap.Width, $a.Bitmap.Height, $b.Bitmap.Width, $b.Bitmap.Height)
    exit 1
}

$w = $a.Bitmap.Width; $h = $a.Bitmap.Height
$diff = New-Object System.Drawing.Bitmap($w, $h)
$differing = [Rdf]::Compare($a.Bitmap, $b.Bitmap, $diff, $Tolerance)
$total = $w * $h
$pct = [Math]::Round(100.0 * $differing / $total, 4)
$diffPath = Join-Path $OutDir 'render-diff.png'
$diff.Save($diffPath, [System.Drawing.Imaging.ImageFormat]::Png)

Write-Host ""
Write-Host ("  client area   : {0}x{1} = {2} pixels" -f $w, $h, $total)
Write-Host ("  differing     : {0} ({1} %) with a per-channel tolerance of {2}" -f $differing, $pct, $Tolerance)
Write-Host ("  diff image    : {0}" -f $diffPath)
Write-Host ""
if ($pct -le $MaxDiffPercent) {
    Write-Host ("RESULT: PASS ({0} % <= {1} %)" -f $pct, $MaxDiffPercent)
    exit 0
}
Write-Host ("RESULT: FAIL ({0} % > {1} %) - open {2} and look at the red pixels" -f $pct, $MaxDiffPercent, $diffPath)
exit 1
