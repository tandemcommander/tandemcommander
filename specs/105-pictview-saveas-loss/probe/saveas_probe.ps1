<#
.SYNOPSIS
    Feature 105 probe: PictView Save As never destroys an existing file, and it saves.
    On the build of this feature and on the build before it (Debug_x64_pre105, the control:
    every save fails, "replace?" Yes deletes the existing file first).

.DESCRIPTION
    Fixtures under %TEMP%\tc105 (removed at the end, explicit names only). The source image is
    a 40 x 30 24-bit BMP whose pixel (x, y) is R = 6x, G = 8y, B = 3(x + y) (mod 256), so a saved
    file can be checked pixel by pixel. Every saved file is decoded by GDI+ (System.Drawing, not
    the program's WIC code) and its header is read by hand (BMP bit count, PNG IHDR, GIF color
    table, JPEG SOF, TIFF tags 258/259/262).

    Rows (names for -Only):
      offer      the dialog's "Save as type" list: exactly BMP, GIF, JPEG, PNG, TIFF (before: 14
                 types incl. CEL, IFF, PNM, SGI, RAS, TGA, RLE, SKA, PCX); per type the
                 compressions and color depths offered
      new-*      a new name per format (default options): the file is a valid image of that
                 format, 40 x 30; BMP/PNG/TIFF 24-bit pixel-exact, JPEG/GIF close
      over-*     the same onto an existing file (text "EXISTING"), "replace?" Yes: replaced by a
                 valid image; before: the file was DELETED, then "Unable to save"
      bmp-*, png-*, gif-*, jpg-*, tif-*   color depths and compressions: the header says what
                 was chosen (bits per pixel, palette, gray, TIFF compression tag)
      jpg-q      quality 10 and 95: the file of quality 10 is smaller
      jpg-sub    subsampling 1:1:1 / 2:1:1: the luma sampling factor in SOF is 0x11 / 0x21
      cmt-*      a comment with Czech and CJK characters is in the file as UTF-8
      rot90, fliph   the dialog's rotation (90 deg CW) / flip (horizontal): pixel-exact
      name-*     names in Cyrillic, CJK and an emoji; a CJK name over an existing file
      ro         a read-only existing file: Windows' Save dialog itself refuses it (measured on both
                 builds; PictView's own read-only question is unreachable through the dialog) -
                 the file byte-identical and still read-only
      locked     the existing file held open by another program (share read): "Unable to save"
                 with the system's reason, the file byte-identical, no temporary file left
      acl        the target's folder denies creating files, the existing file inside:
                 "Unable to save", the file byte-identical (before: deleted - deleting needs no
                 right to create)
      cancel     a 6000 x 4000 image saved over an existing file as 256-color PNG, Esc during
                 the save: "canceled", the file byte-identical, no temporary file left
      shown      the shown image saved over itself with rotation 90: replaced (30 x 40), and a
                 following Save As of the viewer gives 30 x 40 too (the viewer reloaded it);
                 before: "in use" error, nothing saved
    Every row also checks that no pv*.tmp file is left in the folder.
    NOT DRIVEN (recorded): a full disk (needs a small volume - admin), a file system without
    ReplaceFile (the fallback), the target vanishing between the question and the replace (both
    covered by saltests TestSafeReplace105).

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another tandemcommander.exe
    runs. HKCU\Software\Tandem Commander exported before, restored and SHA-256-verified after.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [int[]]$NotifyCodes = @(9, 1) # CBN_SELENDOK, CBN_SELCHANGE: what a real selection sends
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) -or (@($Only | Where-Object { $n -like $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
Add-Type -AssemblyName System.Drawing
if (-not ('Drv105' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
public static class Drv105
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    public static string LbText(IntPtr combo, int index)
    {
        long len = SendR(combo, 0x0149 /*CB_GETLBTEXTLEN*/, index, 0);
        if (len < 0) return null;
        var buf = new char[len + 2]; IntPtr r;
        SendGetBuf(combo, 0x0148 /*CB_GETLBTEXT*/, (IntPtr)index, buf, 0, 5000, out r);
        long n = r.ToInt64(); if (n < 0) return null; if (n > len) n = len;
        return new string(buf, 0, (int)n);
    }

    // ---- the source image and the checks ----
    public static int R(int x, int y) { return (x * 6) % 256; }
    public static int G(int x, int y) { return (y * 8) % 256; }
    public static int B(int x, int y) { return ((x + y) * 3) % 256; }
    // a 24-bit BMP: the gradient above, or noise (slow to quantize - the cancel row)
    public static byte[] MakeBmp(int w, int h, bool noise)
    {
        using (var bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb))
        {
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
            var row = new byte[data.Stride]; uint seed = 12345;
            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < w; x++)
                {
                    if (noise) { seed = seed * 1103515245 + 12345; row[x * 3] = (byte)(seed >> 8); row[x * 3 + 1] = (byte)(seed >> 16); row[x * 3 + 2] = (byte)(seed >> 24); }
                    else { row[x * 3] = (byte)B(x, y); row[x * 3 + 1] = (byte)G(x, y); row[x * 3 + 2] = (byte)R(x, y); }
                }
                Marshal.Copy(row, 0, data.Scan0 + y * data.Stride, data.Stride);
            }
            bmp.UnlockBits(data);
            using (var ms = new MemoryStream()) { bmp.Save(ms, ImageFormat.Bmp); return ms.ToArray(); }
        }
    }
    // decodes with GDI+; mode: "dims", "exact", "rot90", "fliph", "approx:<tol>", "gray"
    // returns "OK ..." or "BAD ..."
    public static string Check(byte[] d, int w, int h, string mode)
    {
        try
        {
            using (var ms = new MemoryStream(d))
            using (var img = new Bitmap(ms))
            {
                string head = "GDI+ " + img.Width + "x" + img.Height + " " + img.PixelFormat;
                if (img.Width != w || img.Height != h) return "BAD dims " + head;
                if (mode == "dims") return "OK " + head;
                double sum = 0; int worst = 0; bool gray = true; long n = 0;
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                    {
                        Color c = img.GetPixel(x, y);
                        int sx = x, sy = y;
                        if (mode == "rot90") { sx = y; sy = w - 1 - x; } // output (x,y) of a CW turn of a w' x h' source: source (y, h'-1-x), h' = w
                        if (mode == "fliph") { sx = w - 1 - x; }
                        int dr = Math.Abs(c.R - R(sx, sy)), dg = Math.Abs(c.G - G(sx, sy)), db = Math.Abs(c.B - B(sx, sy));
                        if (c.R != c.G || c.G != c.B) gray = false;
                        sum += dr + dg + db; n += 3; worst = Math.Max(worst, Math.Max(dr, Math.Max(dg, db)));
                    }
                double mean = sum / n;
                string stat = string.Format(" mean diff {0:F1}, worst {1}", mean, worst);
                if (mode == "exact" || mode == "rot90" || mode == "fliph") return (worst == 0 ? "OK " : "BAD ") + head + stat;
                if (mode == "gray") return (gray ? "OK " : "BAD not gray ") + head + stat;
                if (mode.StartsWith("approx:")) { double tol = double.Parse(mode.Substring(7)); return (mean <= tol ? "OK " : "BAD ") + head + stat; }
                return "BAD mode";
            }
        }
        catch (Exception e) { return "BAD GDI+ cannot decode: " + e.Message; }
    }
    static int U16(byte[] d, int i) { return d[i] | (d[i + 1] << 8); }
    static int U32(byte[] d, int i) { return d[i] | (d[i + 1] << 8) | (d[i + 2] << 16) | (d[i + 3] << 24); }
    static int B16(byte[] d, int i) { return (d[i] << 8) | d[i + 1]; }
    // the format and the facts of its header, as "KIND key=value ..."
    public static string Header(byte[] d)
    {
        try
        {
            if (d.Length > 54 && d[0] == 'B' && d[1] == 'M')
            {
                int bpp = U16(d, 28), comp = U32(d, 30), hdr = U32(d, 14);
                string s = "BMP bpp=" + bpp + " comp=" + comp;
                if (bpp == 8)
                {
                    bool g = true; int pal = 14 + hdr;
                    for (int i = 0; i < 256 && pal + i * 4 + 2 < d.Length; i++) if (d[pal + i * 4] != d[pal + i * 4 + 1] || d[pal + i * 4] != d[pal + i * 4 + 2]) g = false;
                    s += " graypal=" + g;
                }
                return s;
            }
            if (d.Length > 26 && d[0] == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G') return "PNG depth=" + d[24] + " type=" + d[25];
            if (d.Length > 13 && d[0] == 'G' && d[1] == 'I' && d[2] == 'F')
            {
                // the color table of the first image: the global one, else the image's local one
                // (the Windows encoder writes a local table)
                int packed = d[10]; int gct = (packed & 0x80) != 0 ? 1 << ((packed & 7) + 1) : 0;
                int i = 13 + 3 * gct, lct = 0;
                while (i < d.Length)
                {
                    if (d[i] == 0x21) { i += 2; while (i < d.Length && d[i] != 0) i += d[i] + 1; i++; continue; }
                    if (d[i] == 0x2C && i + 9 < d.Length) { int p2 = d[i + 9]; lct = (p2 & 0x80) != 0 ? 1 << ((p2 & 7) + 1) : 0; }
                    break;
                }
                return "GIF ver=" + Encoding.ASCII.GetString(d, 3, 3) + " colors=" + (gct != 0 ? gct : lct);
            }
            if (d.Length > 4 && d[0] == 0xFF && d[1] == 0xD8)
            {
                int i = 2;
                while (i + 9 < d.Length)
                {
                    if (d[i] != 0xFF) { i++; continue; }
                    int m = d[i + 1];
                    if (m == 0xC0 || m == 0xC1 || m == 0xC2) return "JPEG comps=" + d[i + 9] + " sampling0=0x" + (d.Length > i + 11 ? d[i + 11].ToString("X2") : "?") + " sof=" + m.ToString("X2");
                    if (m == 0xD8 || (m >= 0xD0 && m <= 0xD7) || m == 0x01) { i += 2; continue; }
                    i += 2 + B16(d, i + 2);
                }
                return "JPEG no SOF";
            }
            if (d.Length > 8 && d[0] == 'I' && d[1] == 'I' && d[2] == 42)
            {
                int ifd = U32(d, 4), cnt = U16(d, ifd); string comp = "?", bps = "?", photo = "?";
                for (int k = 0; k < cnt; k++)
                {
                    int e = ifd + 2 + k * 12, tag = U16(d, e), type = U16(d, e + 2), count = U32(d, e + 4);
                    int val = type == 3 ? U16(d, e + 8) : U32(d, e + 8);
                    if (tag == 259) comp = "" + val;
                    if (tag == 262) photo = "" + val;
                    if (tag == 258) { if (count == 1) bps = "" + val; else { int o = U32(d, e + 8); var sb = new StringBuilder(); for (int j = 0; j < count && j < 4; j++) sb.Append((j > 0 ? "," : "") + U16(d, o + j * 2)); bps = sb.ToString(); } }
                }
                return "TIFF comp=" + comp + " bps=" + bps + " photo=" + photo;
            }
            return "UNKNOWN (" + d.Length + " bytes)";
        }
        catch (Exception e) { return "BAD header: " + e.Message; }
    }
    public static bool Contains(byte[] d, byte[] n)
    {
        for (int i = 0; i + n.Length <= d.Length; i++) { int j = 0; while (j < n.Length && d[i + j] == n[j]) j++; if (j == n.Length) return true; }
        return false;
    }
}
'@
}

$Root = $TempRoot + '\tc105'
$StartDir = $Root + '\start'
$Src = $Root + '\src'
$Out = $Root + '\out'
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
$Cyr = S 0x0416, 0x0430, 0x0431, 0x0430          # Zhaba
$Cjk = S 0x65E5, 0x672C, 0x8A9E                  # nihongo
$Emo = S 0x1F4C1
$Comment = 'Koment' + [char]0x00E1 + [char]0x0159 + ' ' + (S 0x65E5, 0x672C)
$ImgW = 40; $ImgH = 30 # (not $W/$H: PowerShell names are case-insensitive, $w is a window)

function PutText([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }
function PutBytes([string]$p, [byte[]]$b) { [IO.File]::WriteAllBytes($LP + $p, $b) }
function Bytes([string]$p) { if ([IO.File]::Exists($LP + $p)) { return ,[IO.File]::ReadAllBytes($LP + $p) } else { return $null } }
function Hash([string]$p) { $b = Bytes $p; if ($null -eq $b) { return '<missing>' }; $s = [Security.Cryptography.SHA256]::Create(); return ([BitConverter]::ToString($s.ComputeHash($b)) -replace '-', '').Substring(0, 16) }
function Temps([string]$dir) { if (-not [IO.Directory]::Exists($LP + $dir)) { return @() }; return @([IO.Directory]::GetFiles($LP + $dir, 'pv*.tmp') | ForEach-Object { [IO.Path]::GetFileName($_) }) }
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T105', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
# answers every box of the instance: the ids in $WantIds (first present), else close; records the
# texts; stops when no box is shown for 2 s (windows in $Ignore are not boxes)
function Answer([int]$Id, [double]$Seconds = 25, [int[]]$WantIds = @(6, 2, 1), $Ignore = @()) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Test-Alive $Id)) { break }
        $boxes = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $Ignore -notcontains $_ -and [Drv098f]::IsWindowEnabled($_) })
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
function Combo-Items([IntPtr]$C) {
    if (-not $C) { return @() }
    $n = [Drv105]::SendR($C, 0x0146, 0, 0); $l = @()
    for ($i = 0; $i -lt $n; $i++) { $l += [Drv105]::LbText($C, $i) }
    return $l
}
# selects the first item matching $Rx and tells the dialog (CBN_SELCHANGE); $true when found
function Pick([IntPtr]$C, [string]$Rx, [switch]$Notify) {
    if (-not $C) { return $false }
    $items = @(Combo-Items $C)
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($items[$i] -match $Rx) {
            [void][Drv105]::SendR($C, 0x014E, $i, 0)
            if ($Notify)
            {
                # what a real selection sends: CBN_SELENDOK (9), then CBN_SELCHANGE (1)
                $cid = [Drv098f]::GetDlgCtrlID($C); $par = [Drv098f]::GetParent($C)
                foreach ($code in $NotifyCodes) { [void][Drv105]::SendR($par, 0x0111, (($code -shl 16) -bor $cid), $C.ToInt64()) }
            }
            Start-Sleep -Milliseconds 300
            return $true
        }
    }
    return $false
}
# Ctrl+S in viewer $Wv, the dialog set up from $O (Type, Depth, Comp, Rot, Flip, Quality, Sub,
# Comment), the name field = $Full, Save. Returns the dialog's lists and what was set.
function Save-As([int]$Id, [IntPtr]$Wv, [string]$Full, $O) {
    $r = [pscustomobject]@{ Ok = $false; Note = ''; Types = @(); Comps = @(); Depths = @(); Pre = @() }
    $known = Get-Tops $Id
    Post-Cmd $Wv 124   # CMD_SAVEAS
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($c) {
            Start-Sleep -Milliseconds 1200
            if ((Kid $c 1136 'ComboBox')) { $od = $c; break }
            $r.Pre += (WinDesc $c)   # a question before the dialog (alpha channel): Yes
            $y = Buttons $c | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($y) { Click $y } else { Close-Win $c }
            $known = @($known) + @($c); Start-Sleep -Milliseconds 800; continue
        }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { $r.Note = 'no save dialog; before it: ' + ($r.Pre -join ' || '); return $r }
    $types = Kid $od 1136 'ComboBox'
    $r.Types = @(Combo-Items $types)
    if ($O.Type -and -not (Pick $types $O.Type -Notify)) { $r.Note = "type '$($O.Type)' not offered"; Post-Cmd $od 2; return $r }
    Start-Sleep -Milliseconds 300
    $comp = Kid $od 2301 'ComboBox'; $depth = Kid $od 2303 'ComboBox'
    # the compression first: choosing one makes the dialog refill the depths from the source's own
    # depth; choosing a depth keeps the compression when it is still offered
    if ($O.Comp -and -not (Pick $comp $O.Comp -Notify)) { $r.Note = "compression '$($O.Comp)' not offered: " + ((Combo-Items $comp) -join '/'); Post-Cmd $od 2; return $r }
    if ($O.Depth -and -not (Pick $depth $O.Depth -Notify)) { $r.Note = "depth '$($O.Depth)' not offered: " + ((Combo-Items $depth) -join '/'); Post-Cmd $od 2; return $r }
    $r.Comps = @(Combo-Items $comp); $r.Depths = @(Combo-Items $depth)
    if ($O.Rot) { [void](Pick (Kid $od 2304 'ComboBox') $O.Rot) }
    if ($O.Flip) { [void](Pick (Kid $od 2305 'ComboBox') $O.Flip) }
    if ($O.Sub) { [void](Pick (Kid $od 2318 'ComboBox') $O.Sub) }
    if ($O.Quality) { [void][Drv098f]::SetText((Kid $od 2315 'Edit'), $O.Quality, 5000) }
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
# a reopened save dialog (the old build after an error with OK, a "No"): Cancel
function Cancel-Dialogs([int]$Id) { foreach ($x in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 1136 'ComboBox') })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 600 } }
function Esc8([string]$s) { return (Esc $s) }
# one save and its check. $Expect: Mode for Drv105.Check, W/H, Header regex, extra scriptblock
function Run-Save([int]$Id, [IntPtr]$Wv, [string]$Case, [string]$Full, $O, [string]$Mode, [int]$EW, [int]$EH, [string]$HeadRx, [scriptblock]$Extra) {
    $dir = [IO.Path]::GetDirectoryName($Full)
    $hBefore = Hash $Full
    $s = Save-As $Id $Wv $Full $O
    $ans = Answer $Id 25 @(6, 2, 1) @($Wv)
    Cancel-Dialogs $Id
    $b = Bytes $Full
    $tmp = @(Temps $dir)
    if (-not $s.Ok) { Row $Case 'SAVE' 'FAIL' ("dialog: {0}; boxes: {1}" -f $s.Note, (Msgs2 $ans)); return $null }
    if ($null -eq $b) {
        $lost = ($hBefore -ne '<missing>')
        Row $Case 'SAVE' 'FAIL' ("{0}: no file{1}; boxes: {2}; temp left: {3}" -f (Esc ([IO.Path]::GetFileName($Full))), $(if ($lost) { ' - the EXISTING FILE WAS DELETED (LOSS)' } else { '' }), (Msgs2 $ans), $tmp.Count)
        if ($lost) { $script:Losses++ }
        return $null
    }
    $head = [Drv105]::Header($b)
    $chk = [Drv105]::Check($b, $EW, $EH, $Mode)
    $okHead = $head -match $HeadRx
    $more = ''; $okMore = $true
    if ($Extra) { $x = & $Extra $b; $okMore = $x.Ok; $more = '; ' + $x.Text }
    $saved = (Msgs2 $ans) -match 'saved successfully'
    $v = V ($okHead -and $chk.StartsWith('OK') -and $okMore -and $tmp.Count -eq 0 -and $saved)
    Row $Case 'SAVE' $v ("{0}: {1} (want /{2}/); {3}{4}; temp left {5}; boxes: {6}" -f (Esc ([IO.Path]::GetFileName($Full))), $head, $HeadRx, $chk, $more, $tmp.Count, (Msgs2 $ans))
    return ,$b
}

# ---- the format rows (one viewer on src.bmp) --------------------------------------------------
$Fmt = @{
    bmp = @{ Type = 'Windows Bitmap'; Ext = 'bmp'; Mode = 'exact'; Head = '^BMP bpp=24 comp=0' }
    png = @{ Type = 'Portable Network'; Ext = 'png'; Mode = 'exact'; Head = '^PNG depth=8 type=2' }
    tif = @{ Type = '^TIFF'; Ext = 'tif'; Mode = 'exact'; Head = '^TIFF comp=5 bps=8,8,8 photo=2'; Comp = '^Default' } # the dialog keeps the previous compression when the new type has it
    jpg = @{ Type = '^JPEG'; Ext = 'jpg'; Mode = 'approx:8'; Head = '^JPEG comps=3' }
    gif = @{ Type = 'GIF'; Ext = 'gif'; Mode = 'approx:16'; Head = '^GIF ver=89a colors=256' }
}
function Run-Formats {
    $id = 0; $before = Reports
    try {
        $id = Start-P $Src
        Focus-File $id ($Src + '\src.bmp')
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'formats' 'OPEN' 'FAIL' 'F3 on src.bmp opened no viewer'; return }
        if (Want 'offer') {
            $lists = @(); $types = @()
            # per type: the lists the dialog offers
            foreach ($k in @('bmp', 'png', 'jpg', 'gif', 'tif')) {
                $known = Get-Tops $id
                Post-Cmd $w 124
                Start-Sleep -Milliseconds 2500
                $od = @(Get-Tops $id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 1136 'ComboBox') }) | Select-Object -First 1
                if ($od) {
                    if (-not $types.Count) { $types = @(Combo-Items (Kid $od 1136 'ComboBox')) }
                    if (Pick (Kid $od 1136 'ComboBox') $Fmt[$k].Type -Notify) { $lists += ("{0}: comp [{1}] depth [{2}]" -f $k, ((Combo-Items (Kid $od 2301 'ComboBox')) -join '/'), ((Combo-Items (Kid $od 2303 'ComboBox')) -join '/')) }
                    else { $lists += "${k}: not offered" }
                    Post-Cmd $od 2; Start-Sleep -Milliseconds 800
                }
            }
            $exts = @($types | ForEach-Object { if ($_ -match '\(\*\.(\w+)') { $Matches[1].ToLower() } }) | Sort-Object
            $okList = (($exts -join ',') -eq 'bmp,gif,jpg,png,tif')
            Row 'offer' 'TYPES' (V $okList) ("{0} types: {1}; {2}" -f $types.Count, ($types -join ' | '), ($lists -join '; '))
        }
        foreach ($k in @('bmp', 'png', 'tif', 'jpg', 'gif')) {
            $f = $Fmt[$k]
            $o = @{ Type = $f.Type }; if ($f.Comp) { $o.Comp = $f.Comp }
            if (Want "new-$k") { [void](Run-Save $id $w "new-$k" ($Out + "\new.$($f.Ext)") $o $f.Mode $ImgW $ImgH $f.Head $null) }
            if (Want "over-$k") {
                PutText ($Out + "\exist.$($f.Ext)") 'EXISTING'
                [void](Run-Save $id $w "over-$k" ($Out + "\exist.$($f.Ext)") $o $f.Mode $ImgW $ImgH $f.Head $null)
            }
        }
        $depthRows = @(
            @('bmp-d16', 'Windows Bitmap', '^16 colors', $null, 'approx:40', '^BMP bpp=4 '),
            @('bmp-d256', 'Windows Bitmap', '^256 colors', $null, 'approx:16', '^BMP bpp=8 comp=0 graypal=False'),
            @('bmp-gray', 'Windows Bitmap', '256 gray', $null, 'gray', '^BMP bpp=8 comp=0 graypal=True'),
            @('bmp-hc15', 'Windows Bitmap', '15bit', $null, 'approx:8', '^BMP bpp=16 comp=0'),
            @('bmp-hc16', 'Windows Bitmap', '16bit', $null, 'approx:8', '^BMP bpp=16 comp=3'),
            @('png-d16', 'Portable Network', '^16 colors', $null, 'approx:40', '^PNG depth=4 type=3'),
            @('png-d256', 'Portable Network', '^256 colors', $null, 'approx:16', '^PNG depth=8 type=3'),
            @('png-gray', 'Portable Network', '256 gray', $null, 'gray', '^PNG depth=8 type=0'),
            @('gif-d16', 'GIF', '^16 colors', $null, 'approx:40', '^GIF ver=89a colors=16$'),
            @('gif-gray', 'GIF', '256 gray', $null, 'gray', '^GIF ver=89a colors=256$'),
            @('jpg-gray', '^JPEG', '256 gray', $null, 'gray', '^JPEG comps=1'),
            @('tif-none', '^TIFF', $null, 'Uncompressed', 'exact', '^TIFF comp=1 '),
            @('tif-lzw', '^TIFF', $null, 'LZW', 'exact', '^TIFF comp=5 '),
            @('tif-zip', '^TIFF', $null, 'Deflat', 'exact', '^TIFF comp=8 '),
            @('tif-pack', '^TIFF', $null, 'PackBits', 'exact', '^TIFF comp=32773 '),
            @('tif-d16', '^TIFF', '^16 colors', '^Default', 'approx:40', '^TIFF comp=5 bps=4 photo=3'),
            @('tif-gray', '^TIFF', '256 gray', '^Default', 'gray', '^TIFF comp=5 bps=8 photo=1')
        )
        foreach ($d in $depthRows) {
            if (-not (Want $d[0])) { continue }
            $o = @{ Type = $d[1] }; if ($d[2]) { $o.Depth = $d[2] }; if ($d[3]) { $o.Comp = $d[3] }
            $ext = 'bmp'; if ($d[1] -match 'Network') { $ext = 'png' } elseif ($d[1] -eq 'GIF') { $ext = 'gif' } elseif ($d[1] -match 'JPEG') { $ext = 'jpg' } elseif ($d[1] -match 'TIFF') { $ext = 'tif' }
            [void](Run-Save $id $w $d[0] ($Out + '\' + $d[0] + '.' + $ext) $o $d[4] $ImgW $ImgH $d[5] $null)
        }
        if (Want 'jpg-q') {
            $b10 = Run-Save $id $w 'jpg-q' ($Out + '\q10.jpg') @{ Type = '^JPEG'; Quality = '10' } 'approx:30' $ImgW $ImgH '^JPEG comps=3' $null
            $b95 = Run-Save $id $w 'jpg-q' ($Out + '\q95.jpg') @{ Type = '^JPEG'; Quality = '95' } 'approx:8' $ImgW $ImgH '^JPEG comps=3' $null
            if ($b10 -and $b95) { Row 'jpg-q' 'SIZE' (V ($b10.Length -lt $b95.Length)) ("quality 10: {0} bytes, quality 95: {1} bytes" -f $b10.Length, $b95.Length) }
            else { Row 'jpg-q' 'SIZE' 'FAIL' 'a file is missing' }
            # leave the stored quality at the default for the following rows
            [void](Run-Save $id $w 'jpg-q' ($Out + '\q75.jpg') @{ Type = '^JPEG'; Quality = '75' } 'approx:8' $ImgW $ImgH '^JPEG comps=3' $null)
        }
        if (Want 'jpg-sub') {
            [void](Run-Save $id $w 'jpg-sub' ($Out + '\s111.jpg') @{ Type = '^JPEG'; Sub = '1:1:1' } 'approx:8' $ImgW $ImgH '^JPEG comps=3 sampling0=0x11' $null)
            [void](Run-Save $id $w 'jpg-sub' ($Out + '\s211.jpg') @{ Type = '^JPEG'; Sub = '2:1:1' } 'approx:8' $ImgW $ImgH '^JPEG comps=3 sampling0=0x21' $null)
        }
        $cu = (New-Object Text.UTF8Encoding($false)).GetBytes($Comment)
        $hasComment = { param($b) $c = [Drv105]::Contains($b, $cu); return [pscustomobject]@{ Ok = $c; Text = 'comment as UTF-8 in the file ' + $c } }
        foreach ($k in @('jpg', 'png', 'gif', 'tif')) {
            $o = @{ Type = $Fmt[$k].Type; Comment = $Comment }; if ($Fmt[$k].Comp) { $o.Comp = $Fmt[$k].Comp }
            if (Want "cmt-$k") { [void](Run-Save $id $w "cmt-$k" ($Out + "\cmt.$($Fmt[$k].Ext)") $o $Fmt[$k].Mode $ImgW $ImgH $Fmt[$k].Head $hasComment) }
        }
        if (Want 'rot90') { [void](Run-Save $id $w 'rot90' ($Out + '\rot90.bmp') @{ Type = 'Windows Bitmap'; Rot = '^90' } 'rot90' $ImgH $ImgW '^BMP bpp=24' $null) }
        if (Want 'fliph') { [void](Run-Save $id $w 'fliph' ($Out + '\fliph.png') @{ Type = 'Portable Network'; Flip = 'Horizontal' } 'fliph' $ImgW $ImgH '^PNG depth=8 type=2' $null) }
        if (Want 'name-*') {
            if (Want 'name-cyr') { [void](Run-Save $id $w 'name-cyr' ($Out + '\' + $Cyr + '.png') @{ Type = 'Portable Network' } 'exact' $ImgW $ImgH '^PNG' $null) }
            if (Want 'name-cjk') { [void](Run-Save $id $w 'name-cjk' ($Out + '\' + $Cjk + '.jpg') @{ Type = '^JPEG' } 'approx:8' $ImgW $ImgH '^JPEG' $null) }
            if (Want 'name-emo') { [void](Run-Save $id $w 'name-emo' ($Out + '\' + $Emo + '.bmp') @{ Type = 'Windows Bitmap' } 'exact' $ImgW $ImgH '^BMP bpp=24' $null) }
            if (Want 'name-over') {
                PutText ($Out + '\' + $Cjk + '-x.gif') 'EXISTING'
                [void](Run-Save $id $w 'name-over' ($Out + '\' + $Cjk + '-x.gif') @{ Type = 'GIF' } 'approx:16' $ImgW $ImgH '^GIF' $null)
            }
        }
        Close-Viewer $id $w
    }
    catch { Row 'formats' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'formats' $id $before } }
}

# ---- failures: nothing may be lost -------------------------------------------------------------
# a save that must leave $Full byte-identical; $Pre/$Post prepare and undo the obstacle
function Run-Keep([string]$Case, [string]$Dir, [string]$Name, [int[]]$WantIds, [string]$BoxRx, [scriptblock]$Pre, [scriptblock]$Post) {
    $full = $Dir + '\' + $Name
    $id = 0; $before = Reports
    try {
        $id = Start-P $Src
        Focus-File $id ($Src + '\src.bmp')
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        $h0 = Hash $full; $a0 = [IO.File]::GetAttributes($LP + $full)
        $ctx = & $Pre
        try {
            $s = Save-As $id $w $full @{ Type = 'Windows Bitmap' }
            $ans = Answer $id 25 $WantIds @($w)
            Cancel-Dialogs $id
        }
        finally { & $Post $ctx }
        $h1 = Hash $full; $a1 = '<missing>'; if ([IO.File]::Exists($LP + $full)) { $a1 = [IO.File]::GetAttributes($LP + $full) }
        $tmp = @(Temps $Dir)
        $box = (Msgs2 $ans) -match $BoxRx
        if ($h1 -eq '<missing>') { $script:Losses++ }
        Row $Case 'KEEP' (V ($s.Ok -and $h1 -eq $h0 -and "$a1" -eq "$a0" -and $tmp.Count -eq 0 -and $box)) ("{0}: content before {1} after {2}{3}; attributes {4} -> {5}; temp left {6}; expected box /{7}/ {8}; boxes: {9}" -f (Esc $Name), $h0, $h1, $(if ($h1 -eq '<missing>') { ' - DELETED (LOSS)' } else { '' }), $a0, $a1, $tmp.Count, $BoxRx, $box, (Msgs2 $ans))
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}
function Run-ReadOnly {
    # measured: Windows' own Save dialog refuses a read-only file ("This file is set to read-only.
    # Try again with a different file name." - OK only) before PictView sees the name, so
    # PictView's read-only question cannot be reached through the dialog (both builds)
    $d = $Root + '\ro'; NewDir $d
    PutText ($d + '\exist-ro.bmp') 'EXISTING'; [IO.File]::SetAttributes($LP + $d + '\exist-ro.bmp', 'ReadOnly')
    Run-Keep 'ro' $d 'exist-ro.bmp' @(6, 2, 1) '.' { } { }
    if ([IO.File]::Exists($LP + $d + '\exist-ro.bmp')) { [IO.File]::SetAttributes($LP + $d + '\exist-ro.bmp', 'Normal') }
}
function Run-Locked {
    $d = $Root + '\locked'; NewDir $d
    PutText ($d + '\exist-locked.bmp') 'EXISTING'
    $full = $d + '\exist-locked.bmp'
    # the scriptblocks run inside Run-Keep, which this function calls: they see $full (dynamic scope)
    Run-Keep 'locked' $d 'exist-locked.bmp' @(6, 2, 1) 'Unable to save|cannot access' {
        return [IO.File]::Open($LP + $full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    } { param($fs) if ($fs) { $fs.Dispose() } }
}
function Run-Acl {
    $d = $Root + '\acl'; NewDir $d
    PutText ($d + '\exist-acl.bmp') 'EXISTING'
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $icacls = Join-Path $env:SystemRoot 'System32\icacls.exe'
    $dirPath = $d
    Run-Keep 'acl' $d 'exist-acl.bmp' @(6, 2, 1) 'Unable to save|denied' {
        $o = & $icacls $dirPath /deny ('*' + $sid + ':(WD)') 2>&1
        Out ('acl: icacls /deny (WD): ' + (($o | ForEach-Object { "$_" }) -join ' '))
        return $null
    } {
        param($x)
        $o = & $icacls $dirPath /remove:d ('*' + $sid) 2>&1
        Out ('acl: icacls /remove:d: ' + (($o | ForEach-Object { "$_" }) -join ' '))
    }
}
function Run-Cancel {
    $d = $Root + '\cancel'; NewDir $d
    PutBytes ($Src + '\big.bmp') ([Drv105]::MakeBmp(6000, 4000, $true))
    PutText ($d + '\exist-big.png') 'EXISTING'
    $full = $d + '\exist-big.png'
    $id = 0; $before = Reports
    try {
        $id = Start-P $Src
        Focus-File $id ($Src + '\big.bmp')
        $w = Open-Viewer $id 60
        if ($w -eq [IntPtr]::Zero) { Row 'cancel' 'OPEN' 'FAIL' 'no viewer'; return }
        Start-Sleep -Milliseconds 3000
        $h0 = Hash $full
        $s = Save-As $id $w $full @{ Type = 'Portable Network'; Depth = '^256 colors' }
        # the "replace?" question: Yes, then Esc (WM_KEYUP, what the save's progress hook reads)
        $msgs = @(); $escOn = $false; $done = $false; $sw = [Diagnostics.Stopwatch]::StartNew(); $escStart = $null
        while ($sw.Elapsed.TotalSeconds -lt 60 -and -not $done) {
            $boxes = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $w -and [Drv098f]::IsWindowEnabled($_) -and -not (Kid $_ 1136 'ComboBox') })
            foreach ($b in $boxes) {
                Start-Sleep -Milliseconds 500
                $dsc = WinDesc $b; $msgs += $dsc
                $yes = Buttons $b | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
                if ($yes -and -not $escOn) { Click $yes; $escOn = $true; $escStart = $sw.Elapsed.TotalSeconds; Start-Sleep -Milliseconds 300 }
                else { $ok = Buttons $b | Where-Object { @(1, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($ok) { Click $ok } else { Close-Win $b }; $done = $true }
            }
            if ($escOn -and -not $done) { [void][Drv105]::PostMessageW($w, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0010001L) }
            Start-Sleep -Milliseconds 120
        }
        Cancel-Dialogs $id
        [void](Answer $id 5 @(1, 2) @($w))
        $h1 = Hash $full; $tmp = @(Temps $d)
        $canceled = ($msgs -join ' ') -match 'canceled'
        if ($h1 -eq '<missing>') { $script:Losses++ }
        Row 'cancel' 'KEEP' (V ($s.Ok -and $canceled -and $h1 -eq $h0 -and $tmp.Count -eq 0)) ("6000x4000 noise as 256-color PNG over exist-big.png, Esc after 'replace?' Yes: canceled {0}; content before {1} after {2}{3}; temp left {4}; boxes: {5}" -f $canceled, $h0, $h1, $(if ($h1 -eq '<missing>') { ' - DELETED (LOSS)' } else { '' }), $tmp.Count, ($msgs -join ' || '))
        Close-Viewer $id $w
    }
    catch { Row 'cancel' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'cancel' $id $before }; if ([IO.File]::Exists($LP + $Src + '\big.bmp')) { [IO.File]::Delete($LP + $Src + '\big.bmp') } }
}
function Run-Shown {
    $d = $Root + '\shown'; NewDir $d
    PutBytes ($d + '\shown.bmp') ([Drv105]::MakeBmp($ImgW, $ImgH, $false))
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id ($d + '\shown.bmp')
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'shown' 'OPEN' 'FAIL' 'no viewer'; return }
        $h0 = Hash ($d + '\shown.bmp')
        $b = Run-Save $id $w 'shown' ($d + '\shown.bmp') @{ Type = 'Windows Bitmap'; Rot = '^90' } 'rot90' $ImgH $ImgW '^BMP bpp=24' $null
        $h1 = Hash ($d + '\shown.bmp')
        if (-not $b) { Row 'shown' 'FILE' 'INFO' ("the shown file: content before {0} after {1}" -f $h0, $h1) }
        Start-Sleep -Milliseconds 1500
        # the viewer shows the saved file now: its next Save As (no rotation) is 30 x 40
        [void](Run-Save $id $w 'shown' ($d + '\after-reload.bmp') @{ Type = 'Windows Bitmap'; Rot = 'None' } 'rot90' $ImgH $ImgW '^BMP bpp=24' $null)
        Close-Viewer $id $w
    }
    catch { Row 'shown' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'shown' $id $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc105_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0; $script:Losses = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Src; NewDir $Out
    PutBytes ($Src + '\src.bmp') ([Drv105]::MakeBmp($ImgW, $ImgH, $false))
    Set-Config
    Out ("saveas_probe (feature 105)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; backup SHA-256 {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '-' }))
    Out ''
    if ((Want 'offer') -or (Want 'new-*') -or (Want 'over-*') -or (Want 'bmp-*') -or (Want 'png-*') -or (Want 'gif-*') -or (Want 'jpg-*') -or (Want 'tif-*') -or (Want 'cmt-*') -or (Want 'rot90') -or (Want 'fliph') -or (Want 'name-*')) { Run-Formats }
    if (Want 'ro') { Run-ReadOnly }
    if (Want 'locked') { Run-Locked }
    if (Want 'acl') { Run-Acl }
    if (Want 'cancel') { Run-Cancel }
    if (Want 'shown') { Run-Shown }
    if (-not $Only) {
        foreach ($nd in @('a full disk during the save (needs a small volume: VHD/RAM disk - admin); the stream keeps the first failing WriteFile error and the temporary file is deleted (code review + saltests)',
                          'a file system without ReplaceFile (the MoveFileEx fallback) and a target that vanishes between the question and the replace: saltests TestSafeReplace105 (pure rule + case 9)',
                          '2 colors and the CCITT G3/G4 TIFF compressions: the dialog offers them only for a bilevel source (since Open Salamander) and the WIC engine reports every image as 32-bit (feature 006) - they cannot be chosen; the encoder paths (1-bit BMP/PNG/TIFF, 2-color GIF, CCITT) were measured directly (research.md, m105b)',
                          'the Regenerate thumbnail and PictView Rename overwrite routes now replace in one step: unreachable on both builds (no scaled JPEG encoder; the viewed file is held open - Rename fails with 32 first)')) { Row 'nd' 'ROUTE' 'NOT DRIVEN' $nd }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    # explicit fixture removal: only the probe's own root (an ACL left by a failed run first)
    try {
        if ([IO.Directory]::Exists($LP + $Root + '\acl')) { & (Join-Path $env:SystemRoot 'System32\icacls.exe') ($Root + '\acl') /remove:d ('*' + [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) | Out-Null }
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
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}; existing files LOST: {3}. Left running: {4}; fixture removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $script:Losses, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
