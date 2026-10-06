<#
.SYNOPSIS
    Feature 120 probe: PictView's leftovers of 105/111 - the pipette and the histogram read the
    engine's rows, a Rename onto a file another window shows, the rotation kept across a new
    background color, the GIF comment. On the build of this feature and on the build before it
    (Debug_x64_pre120, the control).

.DESCRIPTION
    Fixtures under %TEMP%\tc120\p (removed at the end, explicit root only), made by Pillow
    (probe\mkfix120.py); saved files decoded by 111's probe\pilcheck.py; references by
    probe\ref120.py. The window-driving helpers are 111's (shown_probe.ps1), copied.

    Rows (names for -Only):
      tgt-shown       A shows x.png, B shows z.png, C shows x.png too; A renames x.png onto z.png,
                      overwrite Yes: z.png holds x's content, x.png gone, no error; A and C titled
                      z.png, B titled z.png showing x's pixels (it shows what its name holds now);
                      z.png held again. Before 120: "Error Renaming File (32)", nothing changed.
      tgt-shown-no    the same, overwrite No: both files unchanged, B still shows z's pixels and
                      holds z.png, A holds x.png (both builds)
      tgt-shown-hl    B shows hz.png, a hard link of z.png; A renames x.png onto z.png, Yes: z.png
                      = x's content, hz.png keeps the old content, B keeps hz.png (title, pixels)
                      and holds it. Before 120: 32.
      tgt-shown-print B's Print dialog is open on z.png (the image is in use): A's replace fails
                      "in use", x.png and z.png unchanged, B intact (both builds)
      hist-*          Histogram (CMD_IMG_HISTOGRAM) of a one-color PNG, the same as an 8-bit GIF,
                      and a half-transparent PNG over white: the histogram control is captured
                      (BitBlt of its DC, else PrintWindow of its window) and its bars read per
                      level; the shown channel is identified by the tone band under the bars. The
                      levels must be exactly those of the image (ref120.py). Before 120: extra
                      levels (misaligned bytes, the unused byte read as 255). NOT DRIVEN when the
                      capture does not show the tone band (no rendering on that desktop).
      bk-rot          rotate right, full screen on and off with another full-screen background
                      color (seeded: FullScreenBGColor = black): Save As of the shown image is the
                      turned image (30x40, pixel-exact) and the title says 30 x 40. Before 120:
                      the rotation was lost (40x30).
      cmt-gif-ascii   a GIF comment of ASCII text: exactly its bytes (GIF89a: 7-bit ASCII)
      cmt-gif-u8      a GIF comment outside ASCII: its UTF-8 bytes (decided, unchanged by 120)
      pip-plain       the pipette (status bar, X/Y and R/G/B panels) at sampled positions of a
      pip-mirror      120x90 image of distinct colors, plain and mirrored horizontally: R/G/B =
                      the pixel shown under the cursor. ONLY on the visible desktop with
                      -VisiblePipette and TC_PROBE_ALLOW_VISIBLE_DESKTOP=1 (SetCursorPos moves the
                      user's mouse; a hidden desktop has no cursor) - NOT DRIVEN otherwise.

    The renderer's background (RendererBGColor) is seeded white and FullScreenBGColor black,
    under HKCU\Software\Tandem Commander (exported before, restored and SHA-256-verified after).
    MUST run through tools\run_on_hidden_desktop.ps1 (the pipette rows excepted, see above).
    Refuses while another tandemcommander.exe runs. Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [switch]$VisiblePipette,
    [int[]]$NotifyCodes = @(9, 1)
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($VisiblePipette) { $Only = @('pip-*') }   # the visible desktop: the pipette rows only
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) -or (@($Only | Where-Object { $n -like $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv120' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
public static class Drv120
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr CreateFileW(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr addr, UIntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool VirtualFreeEx(IntPtr p, IntPtr addr, UIntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool ReadProcessMemory(IntPtr p, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr done);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetWindowLongW(IntPtr h, int index);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr dst, int x, int y, int w, int h, IntPtr src, int sx, int sy, uint rop);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    public static string LbText(IntPtr combo, int index)
    {
        long len = SendR(combo, 0x0149, index, 0);
        if (len < 0) return null;
        var buf = new char[len + 2]; IntPtr r;
        SendGetBuf(combo, 0x0148, (IntPtr)index, buf, 0, 5000, out r);
        long n = r.ToInt64(); if (n < 0) return null; if (n > len) n = len;
        return new string(buf, 0, (int)n);
    }
    // 0 when the file can be opened for DELETE with every sharing mode; else the system error
    // (32 = another handle - a viewer's decoder - does not share delete)
    public static int OpenDeleteErr(string path)
    {
        IntPtr h = CreateFileW(path, 0x00010000, 7, IntPtr.Zero, 3, 0, IntPtr.Zero);
        if (h == new IntPtr(-1)) return Marshal.GetLastWin32Error();
        CloseHandle(h); return 0;
    }
    // the text of part 'part' of a status bar of another process (SB_GETTEXTW into its memory)
    public static string SbText(IntPtr sb, int part)
    {
        uint pid; GetWindowThreadProcessId(sb, out pid);
        IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid);
        if (hp == IntPtr.Zero) return null;
        IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, (UIntPtr)4096, 0x3000, 0x04);
        if (mem == IntPtr.Zero) { CloseHandle(hp); return null; }
        try
        {
            IntPtr r;
            if (SendMessageTimeoutW(sb, 0x040D /*SB_GETTEXTW*/, (IntPtr)part, mem, 0, 5000, out r) == IntPtr.Zero) return null;
            var b = new byte[4096]; UIntPtr n;
            if (!ReadProcessMemory(hp, mem, b, (UIntPtr)4096, out n)) return null;
            var chars = new char[2048]; Buffer.BlockCopy(b, 0, chars, 0, 4096);
            int z = Array.IndexOf(chars, '\0'); if (z < 0) z = chars.Length;
            return new string(chars, 0, z);
        }
        finally { VirtualFreeEx(hp, mem, UIntPtr.Zero, 0x8000); CloseHandle(hp); }
    }
    static bool Near(int c, int r, int g, int b)
    {
        return Math.Abs(((c >> 16) & 255) - r) <= 3 && Math.Abs(((c >> 8) & 255) - g) <= 3 && Math.Abs((c & 255) - b) <= 3;
    }
    // the histogram control (histwnd.cpp CHistogramControl::Paint): level j is the column band
    // [j * mag, j * mag + mag) with mag = width / 256; its bar is 0xB4B4B4 over black; under the bars
    // three separator lines and the tone band of the shown channel (j, j, j) / (j, 0, 0) / ...
    // Returns the levels with a bar ("50,100,200") and the channel ("gray", "red", "green", "blue"),
    // or null when the tone band is not there (the capture shows nothing real)
    public static string ReadBars(int[] px, int w, int h, out string channel, out int mag)
    {
        channel = null; mag = w / 256;
        if (px == null || mag < 1 || h < 20) return null;
        int x255 = 255 * mag + mag / 2, x128 = 128 * mag + mag / 2;
        int c255 = px[(h - 1) * w + x255], c128 = px[(h - 1) * w + x128];
        if (Near(c255, 255, 255, 255) && Near(c128, 128, 128, 128)) channel = "gray";
        else if (Near(c255, 255, 0, 0) && Near(c128, 128, 0, 0)) channel = "red";
        else if (Near(c255, 0, 255, 0) && Near(c128, 0, 128, 0)) channel = "green";
        else if (Near(c255, 0, 0, 255) && Near(c128, 0, 0, 128)) channel = "blue";
        else return null;
        int y = h - 1;
        while (y > 0 && px[(y - 1) * w + x255] == c255) y--;
        int barBottom = y - 3;
        var sb = new StringBuilder();
        for (int j = 0; j < 256; j++)
        {
            bool found = false;
            for (int x = j * mag; x < (j + 1) * mag && !found; x++)
                for (int yy = 0; yy < barBottom && !found; yy++)
                    if (Near(px[yy * w + x], 0xB4, 0xB4, 0xB4)) found = true;
            if (found) { if (sb.Length > 0) sb.Append(','); sb.Append(j); }
        }
        return sb.ToString();
    }
    // the client area of 'h' as 0xRRGGBB values: method 0 = BitBlt from its DC, 1 = PrintWindow of
    // its top-level window 'top' (PW_RENDERFULLCONTENT) cut to the client area
    public static int[] Capture(IntPtr h, IntPtr top, int method, out int w, out int hgt)
    {
        RECT cr; GetClientRect(h, out cr); w = cr.Right; hgt = cr.Bottom;
        if (w <= 0 || hgt <= 0) return null;
        int ox = 0, oy = 0, bw = w, bh = hgt;
        if (method == 1)
        {
            RECT tr; GetWindowRect(top, out tr);
            POINT p = new POINT(); ClientToScreen(h, ref p);
            ox = p.X - tr.Left; oy = p.Y - tr.Top; bw = tr.Right - tr.Left; bh = tr.Bottom - tr.Top;
        }
        using (var bmp = new Bitmap(bw, bh, PixelFormat.Format32bppRgb))
        {
            using (var g = Graphics.FromImage(bmp))
            {
                IntPtr hdc = g.GetHdc();
                if (method == 0) { IntPtr src = GetDC(h); BitBlt(hdc, 0, 0, w, hgt, src, 0, 0, 0x00CC0020); ReleaseDC(h, src); }
                else PrintWindow(top, hdc, 2);
                g.ReleaseHdc(hdc);
            }
            var data = bmp.LockBits(new Rectangle(0, 0, bw, bh), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
            var all = new int[bw * bh];
            Marshal.Copy(data.Scan0, all, 0, all.Length);
            bmp.UnlockBits(data);
            var res = new int[w * hgt];
            for (int y = 0; y < hgt; y++)
                for (int x = 0; x < w; x++)
                {
                    int sx = x + ox, sy = y + oy;
                    res[y * w + x] = (sx < bw && sy < bh) ? (all[sy * bw + sx] & 0xFFFFFF) : 0;
                }
            return res;
        }
    }
}
'@
}

$Root = $TempRoot + '\tc120\p'
$StartDir = $Root + '\start'
$Fix = $Root + '\fix'
$Out = $Root + '\out'
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
$CommentU = 'Koment' + [char]0x00E1 + [char]0x0159 + ' ' + (S 0x65E5, 0x672C)
$CommentA = 'Plain comment'
$Py = 'python'
$PilCheck = Join-Path $PSScriptRoot '..\..\111-pictview-shown-image\probe\pilcheck.py'
$Ref = Join-Path $PSScriptRoot 'ref120.py'
$PvKey = $RegKey + '\0.1\Plugins Configuration\PictView'

function Bytes([string]$p) { if ([IO.File]::Exists($LP + $p)) { return , [IO.File]::ReadAllBytes($LP + $p) } else { return $null } }
function Hash([string]$p) { $b = Bytes $p; if ($null -eq $b) { return '<missing>' }; $s = [Security.Cryptography.SHA256]::Create(); return ([BitConverter]::ToString($s.ComputeHash($b)) -replace '-', '').Substring(0, 16) }
function Exists([string]$p) { return [IO.File]::Exists($LP + $p) }
function Held([string]$p) { return [Drv120]::OpenDeleteErr($LP + $p) }
function Pil([string[]]$files) {
    $r = @{}
    $o = & $Py $PilCheck @($files | ForEach-Object { $LP + $_ }) 2>&1
    foreach ($line in $o) {
        $parts = "$line" -split '\|'
        $f = @{}; foreach ($kv in $parts[1..($parts.Count - 1)]) { $i = $kv.IndexOf('='); if ($i -gt 0) { $f[$kv.Substring(0, $i)] = $kv.Substring($i + 1) } }
        $r[$parts[0]] = $f
    }
    return $r
}
function PilOne([string]$file) { $r = Pil @($file); $n = [IO.Path]::GetFileName($file); if ($r.ContainsKey($n)) { return $r[$n] }; return @{ ERROR = 'no output' } }
function U8Hex([string]$s) { return (-join ((New-Object Text.UTF8Encoding($false)).GetBytes($s) | ForEach-Object { $_.ToString('x2') })) }
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T120', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
# answers every box of the instance (#32770: the first button of $WantIds present, else close;
# the shell's "file in use" window: closed); records the texts; stops after 2 s idle
function Answer([int]$Id, [double]$Seconds = 25, [int[]]$WantIds = @(6, 2, 1), $Ignore = @()) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Test-Alive $Id)) { break }
        $boxes = @(Get-Tops $Id | Where-Object { @('#32770', 'OperationStatusWindow') -contains [Drv098f]::Cls($_) -and $Ignore -notcontains $_ -and [Drv098f]::IsWindowEnabled($_) })
        if (-not $boxes.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 150; continue
        }
        $idleSince = $null
        foreach ($b in $boxes) {
            $key = $b.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - $seen[$key] -lt 0.7) { continue }
            $seen.Remove($key)
            $d = WinDesc $b
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if ([Drv098f]::Cls($b) -eq 'OperationStatusWindow') {
                [void]$r.Messages.Add('[shell operation window] ' + (Esc ([Drv098f]::Txt($b))))
                [void][Drv098f]::PostMessageW($b, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
                Start-Sleep -Milliseconds 800; continue
            }
            [void]$r.Messages.Add($d)
            $btn = $null
            foreach ($w in $WantIds) { $btn = Buttons $b | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($btn) { break } }
            if ($btn) { Click $btn } else { Close-Win $b }
            Start-Sleep -Milliseconds 600
        }
    }
    return $r
}
function Msgs2($r) { if ($r.Messages.Count) { return ($r.Messages -join ' || ') } else { return 'no box' } }
function End-P([string]$Case, [int]$Id, $Before) {
    foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep -Milliseconds 800
    [void](Answer $Id 6 @(6, 1))
    End-Row $Case $Id $null $Before
}
function Focus-File([int]$Id, [string]$Full) { [void](Do-ChangeDir $Id $Full); [void](Serve $Id 8); Sync $Id }
function Open-Viewer([int]$Id, [double]$Seconds = 30) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 742
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne '#32770' }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 1500; return $w }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}
function Close-Viewer([int]$Id, [IntPtr]$Wv) {
    if ($Wv -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($Wv)) { return }
    [void][Drv098f]::PostMessageW($Wv, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($Wv)) { Start-Sleep -Milliseconds 100 }
    [void](Answer $Id 3 @(6, 1))
}
function Title([IntPtr]$Wv) { return [Drv098f]::Txt($Wv) }
function Dims([string]$t) { if ($t -match '\((\d+) x (\d+) x ') { return ('{0}x{1}' -f $Matches[1], $Matches[2]) }; return '?' }
function Combo-Items([IntPtr]$C) {
    if (-not $C) { return @() }
    $n = [Drv120]::SendR($C, 0x0146, 0, 0); $l = @()
    for ($i = 0; $i -lt $n; $i++) { $l += [Drv120]::LbText($C, $i) }
    return $l
}
function Pick([IntPtr]$C, [string]$Rx, [switch]$Notify) {
    if (-not $C) { return $false }
    $items = @(Combo-Items $C)
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($items[$i] -match $Rx) {
            [void][Drv120]::SendR($C, 0x014E, $i, 0)
            if ($Notify) {
                $cid = [Drv098f]::GetDlgCtrlID($C); $par = [Drv098f]::GetParent($C)
                foreach ($code in $NotifyCodes) { [void][Drv120]::SendR($par, 0x0111, (($code -shl 16) -bor $cid), $C.ToInt64()) }
            }
            Start-Sleep -Milliseconds 300
            return $true
        }
    }
    return $false
}
# Ctrl+S in viewer $Wv (111's): the questions before the dialog answered Yes; $O: Type, Depth, Comp, Rot, Comment
function Save-As([int]$Id, [IntPtr]$Wv, [string]$Full, $O) {
    $r = [pscustomobject]@{ Ok = $false; Note = ''; Pre = @() }
    $known = Get-Tops $Id
    Post-Cmd $Wv 124
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($c) {
            Start-Sleep -Milliseconds 1200
            if ((Kid $c 1136 'ComboBox')) { $od = $c; break }
            $r.Pre += (WinDesc $c)
            $y = Buttons $c | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($y) { Click $y } else { Close-Win $c }
            $known = @($known) + @($c); Start-Sleep -Milliseconds 800; continue
        }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { $r.Note = 'no save dialog; before it: ' + ($r.Pre -join ' || '); return $r }
    $types = Kid $od 1136 'ComboBox'
    if ($O.Type -and -not (Pick $types $O.Type -Notify)) { $r.Note = "type '$($O.Type)' not offered"; Post-Cmd $od 2; return $r }
    Start-Sleep -Milliseconds 300
    $comp = Kid $od 2301 'ComboBox'; $depth = Kid $od 2303 'ComboBox'
    if ($O.Comp -and -not (Pick $comp $O.Comp -Notify)) { $r.Note = "compression '$($O.Comp)' not offered"; Post-Cmd $od 2; return $r }
    if ($O.Depth -and -not (Pick $depth $O.Depth -Notify)) { $r.Note = "depth '$($O.Depth)' not offered"; Post-Cmd $od 2; return $r }
    if ($O.Rot) { [void](Pick (Kid $od 2304 'ComboBox') $O.Rot) }
    if ($O.Comment) { [void][Drv098f]::SetText((Kid $od 2309 'Edit'), $O.Comment, 5000) }
    $fn = @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 }) | Select-Object -First 1
    if (-not $fn) { $r.Note = 'no file name field'; Post-Cmd $od 2; return $r }
    [void][Drv098f]::SetText($fn, $Full, 5000)
    $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    if ($ok) { Click $ok } else { Post-Cmd $od 1 }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    $r.Ok = $true
    return $r
}
function Cancel-Dialogs([int]$Id) { foreach ($x in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 1136 'ComboBox') })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 600 } }
function Save-Simple([int]$Id, [IntPtr]$Wv, [string]$Full, $O, $Ignore = @()) {
    $s = Save-As $Id $Wv $Full $O
    $ans = Answer $Id 25 @(6, 2, 1) (@($Ignore) + @($Wv))
    Cancel-Dialogs $Id
    return [pscustomobject]@{ Save = $s; Boxes = (Msgs2 $ans) }
}
# a Save As of what the viewer shows into a new PNG: "WxH <pixel hash>" (Pillow)
function Shown-Pixels([int]$Id, [IntPtr]$Wv, [string]$Full, $Ignore = @()) {
    $x = Save-Simple $Id $Wv $Full @{ Type = 'Portable Network'; Rot = 'None' } $Ignore
    if (-not (Exists $Full)) { return ('<no file; ' + $x.Save.Note + '; ' + $x.Boxes + '>') }
    $f = PilOne $Full
    return ('{0} {1}' -f $f.size, $f.pixels)
}
function Wait-Box([int]$Id, $Known, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $b = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($b) { Start-Sleep -Milliseconds 700; return $b }
        Start-Sleep -Milliseconds 150
    }
    return [IntPtr]::Zero
}
# CMD_IMG_RENAME in viewer $Wv: the field 2172 set to $NewName, OK; the boxes after it answered
# with $WantIds (overwrite: 6 = Yes, 7 = No); a rename dialog shown again is canceled
function Rename-Shown([int]$Id, [IntPtr]$Wv, [string]$NewName, [int[]]$WantIds = @(6, 2, 1), $Ignore = @()) {
    $known = Get-Tops $Id
    Post-Cmd $Wv 185
    $dlg = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 10 -and $dlg -eq [IntPtr]::Zero) {
        $dlg = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 2172 'Edit') }) | Select-Object -First 1
        if (-not $dlg) { $dlg = [IntPtr]::Zero; Start-Sleep -Milliseconds 200 }
    }
    if ($dlg -eq [IntPtr]::Zero) { return 'no rename dialog' }
    Start-Sleep -Milliseconds 500
    [void][Drv098f]::SetText((Kid $dlg 2172 'Edit'), $NewName, 5000)
    Click-Ok $dlg
    Start-Sleep -Milliseconds 800
    $ans = Answer $Id 15 $WantIds (@($Ignore) + @($Wv))
    foreach ($x in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 2172 'Edit') })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 500 }
    return (Msgs2 $ans)
}
function Make-Fixtures {
    NewDir $Fix
    $o = & $Py (Join-Path $PSScriptRoot 'mkfix120.py') $Fix 2>&1
    if ("$o" -notmatch 'ok') { throw ('fixtures: ' + "$o") }
}
function Fx([string]$name, [string]$dir, [string]$as) { if (-not $as) { $as = $name }; NewDir $dir; [IO.File]::Copy($LP + $Fix + '\' + $name, $LP + $dir + '\' + $as, $true); return ($dir + '\' + $as) }
function Px([string]$file) { return (PilOne $file).pixels }

# ---- Rename onto a file another window shows -------------------------------------------------
function Run-Tgt([string]$Case) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $x = Fx 'rgb.png' $d 'x.png'; $z = Fx 'gray.png' $d 'z.png'
    $hx = Hash $x; $hz = Hash $z; $pxX = Px $x; $pxZ = Px $z
    $bName = 'z.png'
    if ($Case -eq 'tgt-shown-hl') {
        $o = & cmd.exe /c ('mklink /H "{0}" "{1}"' -f ($d + '\hz.png'), $z) 2>&1
        if (-not (Exists ($d + '\hz.png'))) { Row $Case 'RUN' 'NOT DRIVEN' ('mklink /H failed: ' + "$o"); return }
        $bName = 'hz.png'
    }
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $x; $a = Open-Viewer $id
        Focus-File $id ($d + '\' + $bName); $b = Open-Viewer $id
        $c = [IntPtr]::Zero
        if ($Case -eq 'tgt-shown') { Focus-File $id $x; $c = Open-Viewer $id }
        if ($a -eq [IntPtr]::Zero -or $b -eq [IntPtr]::Zero -or $a -eq $b -or ($Case -eq 'tgt-shown' -and ($c -eq [IntPtr]::Zero -or $c -eq $a -or $c -eq $b))) { Row $Case 'OPEN' 'FAIL' 'the viewer windows wanted did not open'; return }
        $others = @($b); if ($c -ne [IntPtr]::Zero) { $others += $c }
        $pd = [IntPtr]::Zero
        if ($Case -eq 'tgt-shown-print') {
            $known = Get-Tops $id
            Post-Cmd $b 154   # CMD_PRINT: B's image is in use while its dialog is open
            $pd = Wait-Box $id $known 20
            if ($pd -eq [IntPtr]::Zero) { Row $Case 'PRINT' 'NOT DRIVEN' 'B opened no Print dialog (no default printer?)'; return }
            $others += $pd
        }
        $want = @(6, 2, 1); if ($Case -eq 'tgt-shown-no') { $want = @(7, 2) }
        $boxes = Rename-Shown $id $a 'z.png' $want $others
        if ($pd -ne [IntPtr]::Zero) { Post-Cmd $pd 2; Start-Sleep -Milliseconds 1000; [void](Answer $id 5 @(2, 1) @($a, $b)) }
        Start-Sleep -Milliseconds 1200
        $ta = Title $a; $tb = Title $b; $tc = if ($c -ne [IntPtr]::Zero) { Title $c } else { '' }
        $xNow = Hash $x; $zNow = Hash $z
        $err32 = $boxes -match '\(32\)|used by another process|in use'
        switch ($Case) {
            'tgt-shown' {
                $pb = Shown-Pixels $id $b ($Out + '\' + $Case + '-b.png') @($a, $c)
                $pc = Shown-Pixels $id $c ($Out + '\' + $Case + '-c.png') @($a, $b)
                $ok = ($xNow -eq '<missing>') -and ($zNow -eq $hx) -and $ta.Contains('z.png') -and $tb.Contains('z.png') -and $tc.Contains('z.png') -and
                      ($pb -match ('^40x30 ' + $pxX + '$')) -and ($pc -match ('^40x30 ' + $pxX + '$')) -and ((Held $z) -eq 32) -and -not $err32
                Row $Case 'RENAME' (V $ok) ("A renames x.png onto z.png (B shows z.png, C shows x.png), Yes: x {0}, z = x's content {1}; titles A '{2}', B '{3}', C '{4}'; B shows {5} (want x's pixels {6}); C shows {7}; z held: err {8}; boxes: {9}" -f $xNow, ($zNow -eq $hx), (Tail $ta 30), (Tail $tb 30), (Tail $tc 30), $pb, $pxX, $pc, (Held $z), $boxes)
            }
            'tgt-shown-no' {
                $pb = Shown-Pixels $id $b ($Out + '\' + $Case + '-b.png') @($a)
                $ok = ($xNow -eq $hx) -and ($zNow -eq $hz) -and $ta.Contains('x.png') -and $tb.Contains('z.png') -and ($pb -match ('^40x30 ' + $pxZ + '$')) -and ((Held $z) -eq 32) -and ((Held $x) -eq 32)
                Row $Case 'RENAME' (V $ok) ("overwrite No: x unchanged {0}, z unchanged {1}; titles A '{2}', B '{3}'; B shows {4} (want z's pixels {5}); held x {6} z {7}; boxes: {8}" -f ($xNow -eq $hx), ($zNow -eq $hz), (Tail $ta 30), (Tail $tb 30), $pb, $pxZ, (Held $x), (Held $z), $boxes)
            }
            'tgt-shown-hl' {
                $hzNow = Hash ($d + '\hz.png')
                $pb = Shown-Pixels $id $b ($Out + '\' + $Case + '-b.png') @($a)
                $ok = ($xNow -eq '<missing>') -and ($zNow -eq $hx) -and ($hzNow -eq $hz) -and $tb.Contains('hz.png') -and ($pb -match ('^40x30 ' + $pxZ + '$')) -and ((Held ($d + '\hz.png')) -eq 32) -and -not $err32
                Row $Case 'RENAME' (V $ok) ("B shows hz.png (hard link of z.png); A renames x.png onto z.png, Yes: z = x's content {0}, hz keeps the old content {1}; B title '{2}', shows {3} (want {4}); hz held: err {5}; boxes: {6}" -f ($zNow -eq $hx), ($hzNow -eq $hz), (Tail $tb 30), $pb, $pxZ, (Held ($d + '\hz.png')), $boxes)
            }
            'tgt-shown-print' {
                $pb = Shown-Pixels $id $b ($Out + '\' + $Case + '-b.png') @($a)
                $ok = ($xNow -eq $hx) -and ($zNow -eq $hz) -and $err32 -and ($pb -match ('^40x30 ' + $pxZ + '$')) -and (Test-Alive $id)
                Row $Case 'RENAME' (V $ok) ("B prints z.png while A renames x.png onto it, Yes: refused 'in use' {0}; x unchanged {1}, z unchanged {2}; B afterwards shows {3}; boxes: {4}" -f $err32, ($xNow -eq $hx), ($zNow -eq $hz), $pb, $boxes)
            }
        }
        foreach ($w in @($c, $b, $a)) { Close-Viewer $id $w }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- Histogram -------------------------------------------------------------------------------
# the levels with a bar in a capture of the histogram control (Drv120.ReadBars); $null when the
# capture does not show the tone band
function Read-Histogram([int[]]$px, [int]$w, [int]$h) {
    if ($null -eq $px) { return $null }
    $chan = ''; $mag = 0
    $levels = [Drv120]::ReadBars($px, $w, $h, [ref]$chan, [ref]$mag)
    if ($null -eq $levels) { return $null }
    return [pscustomobject]@{ Channel = $chan; Levels = $levels; Mag = $mag }
}
function Run-Hist([string]$Case, [string]$Fixture) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = Fx $Fixture $d
    $refLine = (& $Py $Ref 'hist' ($LP + $src) 'FFFFFF' 2>&1) -join ''
    $ref = @{}; foreach ($kv in $refLine -split '\|') { $i = $kv.IndexOf('='); if ($i -gt 0) { $ref[$kv.Substring(0, $i)] = $kv.Substring($i + 1) } }
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        $known = Get-Tops $id
        Post-Cmd $w 189   # CMD_IMG_HISTOGRAM
        $hw = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $hw -eq [IntPtr]::Zero) {
            $hw = @(Get-Tops $id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne '#32770' }) | Select-Object -First 1
            if (-not $hw) { $hw = [IntPtr]::Zero; Start-Sleep -Milliseconds 200 }
        }
        if ($hw -eq [IntPtr]::Zero) { Row $Case 'HIST' 'FAIL' 'no histogram window'; return }
        [void][Drv120]::SetWindowPos($hw, [IntPtr]::Zero, 0, 0, 900, 420, 0x0016)   # SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE
        Start-Sleep -Milliseconds 1500
        $ctl = @([Drv098f]::Kids($hw) | Where-Object { [Drv098f]::GetParent($_) -eq $hw } | Sort-Object { $r = New-Object Drv120+RECT; [void][Drv120]::GetClientRect($_, [ref]$r); - ($r.Right * $r.Bottom) }) | Select-Object -First 1
        $res = $null; $how = ''
        foreach ($m in 0, 1) {
            $cw = 0; $ch = 0
            $cap = [Drv120]::Capture($ctl, $hw, $m, [ref]$cw, [ref]$ch)
            $res = Read-Histogram $cap $cw $ch
            if ($res) { $how = @('BitBlt', 'PrintWindow')[$m] + (' {0}x{1}, {2} px per level' -f $cw, $ch, $res.Mag); break }
        }
        if (-not $res) { Row $Case 'HIST' 'NOT DRIVEN' 'the capture of the histogram control shows no tone band (nothing rendered on this desktop)' }
        else {
            $want = switch ($res.Channel) { 'red' { @($ref.red) } 'green' { @($ref.green) } 'blue' { @($ref.blue) } default { @($ref.lum, $ref.rgb) } }
            $ok = $want -contains $res.Levels
            Row $Case 'HIST' (V $ok) ("{0}: channel shown {1}; bars at levels [{2}] (want [{3}]); capture {4}" -f $Fixture, $res.Channel, $res.Levels, ($want -join '] or ['), $how)
        }
        [void][Drv098f]::PostMessageW($hw, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 600
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- rotation kept across a new background color ---------------------------------------------
function Run-BkRot {
    if (-not (Want 'bk-rot')) { return }
    $d = $Root + '\bk-rot'
    $src = Fx 'rgb.png' $d 'shown.png'
    $want = Px ($Fix + '\rgb_rot90.png')
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'bk-rot' 'OPEN' 'FAIL' 'no viewer'; return }
        Post-Cmd $w 127; Start-Sleep -Milliseconds 800    # CMD_ROTATE_RIGHT
        $t0 = Title $w
        Post-Cmd $w 129; Start-Sleep -Milliseconds 1500   # CMD_FULLSCREEN: the full-screen background (black)
        Post-Cmd $w 129; Start-Sleep -Milliseconds 1500   # back: the window background (white)
        $t1 = Title $w
        $px = Shown-Pixels $id $w ($Out + '\bk-rot-after.png')
        $ok = ($px -match ('^30x40 ' + $want + '$')) -and (Dims $t1) -eq '30x40'
        Row 'bk-rot' 'ROTATE' (V $ok) ("rotated right, full screen on and off (another background color): title {0} -> {1}; Save As of the shown image {2} (want 30x40 {3})" -f (Dims $t0), (Dims $t1), $px, $want)
        Close-Viewer $id $w
    }
    catch { Row 'bk-rot' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'bk-rot' $id $before } }
}

# ---- GIF comments ----------------------------------------------------------------------------
function Run-CmtGif([string]$Case, [string]$Comment) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = Fx 'rgb.png' $d 'src.png'
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        $full = $d + '\cmt.gif'
        $x = Save-Simple $id $w $full @{ Type = 'GIF'; Comment = $Comment }
        if (-not (Exists $full)) { Row $Case 'COMMENT' 'FAIL' ("no file: {0}; {1}" -f $x.Save.Note, $x.Boxes) }
        else {
            $f = PilOne $full; $hexWant = U8Hex $Comment
            Row $Case 'COMMENT' (V ($f.com -eq $hexWant)) ("GIF comment extension {0} (want exactly {1}{2})" -f $f.com, $hexWant, $(if ($Comment -match '^[\x20-\x7e]*$') { ' - 7-bit ASCII' } else { ' - the UTF-8 bytes, decided in 120' }))
        }
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- the pipette (visible desktop only) ------------------------------------------------------
function Run-Pipette([string]$Case, [bool]$Mirror) {
    if (-not (Want $Case)) { return }
    $desk = [DeskLib098]::Name()
    if (-not $VisiblePipette -or $desk -ine 'Default') { Row $Case 'PIPETTE' 'NOT DRIVEN' ("the pipette follows the real mouse cursor, which a hidden desktop does not have (desktop '{0}'); run -VisiblePipette on the visible desktop with the user's agreement" -f $desk); return }
    $d = $Root + '\' + $Case
    $src = Fx 'pipette.png' $d
    $id = 0; $before = Reports
    $p0 = New-Object Drv120+POINT; [void][Drv120]::GetCursorPos([ref]$p0)
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        if ($Mirror) { Post-Cmd $w 120; Start-Sleep -Milliseconds 800 }   # CMD_MIRROR_HOR
        $sb = @([Drv098f]::Kids($w) | Where-Object { [Drv098f]::Cls($_) -eq 'msctls_statusbar32' }) | Select-Object -First 1
        if (-not $sb) { Row $Case 'PIPETTE' 'FAIL' 'no status bar'; return }
        [void][Drv120]::SetForegroundWindow($w); Start-Sleep -Milliseconds 500
        $wr = New-Object Drv120+RECT; [void][Drv120]::GetWindowRect($w, [ref]$wr)
        $samples = @()
        foreach ($fy in 0.30, 0.45, 0.60) {
            foreach ($fx in 0.25, 0.4, 0.5, 0.6, 0.75) {
                $sx = [int]($wr.Left + ($wr.Right - $wr.Left) * $fx); $sy = [int]($wr.Top + ($wr.Bottom - $wr.Top) * $fy)
                [void][Drv120]::SetCursorPos($sx, $sy); Start-Sleep -Milliseconds 250
                $xy = [Drv120]::SbText($sb, 1); $c = [Drv120]::SbText($sb, 3)
                if ($xy -match 'X:(\d+)\s+Y:(\d+)' ) {
                    $X = [int]$Matches[1]; $Y = [int]$Matches[2]
                    if ($c -match 'R:(\d+)\s+G:(\d+)\s+B:(\d+)') { $samples += [pscustomobject]@{ X = $X; Y = $Y; Got = ('{0},{1},{2}' -f $Matches[1], $Matches[2], $Matches[3]) } }
                }
            }
        }
        [void][Drv120]::SetCursorPos($p0.X, $p0.Y)
        if ($samples.Count -lt 6) { Row $Case 'PIPETTE' 'FAIL' ('only {0} positions over the image read (status bar X/Y + R/G/B)' -f $samples.Count) }
        else {
            # the pixel SHOWN at (X, Y): mirrored, the image's column 119 - X
            $pts = @($samples | ForEach-Object { '{0},{1}' -f $(if ($Mirror) { 119 - $_.X } else { $_.X }), $_.Y })
            $refs = @(& $Py $Ref 'pix' ($LP + $src) @pts 2>&1)
            $bad = @()
            for ($i = 0; $i -lt $samples.Count; $i++) { $want = ("$($refs[$i])" -split '=')[1]; if ($samples[$i].Got -ne $want) { $bad += ('({0},{1}) got {2} want {3}' -f $samples[$i].X, $samples[$i].Y, $samples[$i].Got, $want) } }
            Row $Case 'PIPETTE' (V ($bad.Count -eq 0)) ("{0}: {1} positions read, {2} wrong{3}" -f $(if ($Mirror) { 'mirrored' } else { 'plain' }), $samples.Count, $bad.Count, $(if ($bad.Count) { ': ' + (($bad | Select-Object -First 4) -join '; ') } else { '' }))
        }
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { [void][Drv120]::SetCursorPos($p0.X, $p0.Y); if ($id) { End-P $Case $id $before } }
}

# ---- main ------------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc120_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Out
    Make-Fixtures
    Set-Config
    # the backgrounds the rows rely on (inside the exported key): the window's white, full screen black
    & reg.exe add $PvKey /v 'RendererBGColor' /t REG_DWORD /d 0x00FFFFFF /f | Out-Null
    & reg.exe add $PvKey /v 'FullScreenBGColor' /t REG_DWORD /d 0x00000000 /f | Out-Null
    Out ("pv120_probe (feature 120)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; desktop '{2}'; registry key existed {3}; backup SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), [DeskLib098]::Name(), $existed, $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '-' }))
    Out ''
    Run-Tgt 'tgt-shown'
    Run-Tgt 'tgt-shown-no'
    Run-Tgt 'tgt-shown-hl'
    Run-Tgt 'tgt-shown-print'
    Run-Hist 'hist-png' 'one_color.png'
    Run-Hist 'hist-gif' 'one_color.gif'
    Run-Hist 'hist-alpha' 'one_alpha.png'
    Run-BkRot
    Run-CmtGif 'cmt-gif-ascii' $CommentA
    Run-CmtGif 'cmt-gif-u8' $CommentU
    Run-Pipette 'pip-plain' $false
    Run-Pipette 'pip-mirror' $true
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try {
        if ([IO.Directory]::Exists($LP + $Root)) {
            foreach ($f in @([IO.Directory]::GetFiles($LP + $Root, '*', 'AllDirectories'))) { [IO.File]::SetAttributes($f, 'Normal') }
            [IO.Directory]::Delete($LP + $Root, $true)
        }
    }
    catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
