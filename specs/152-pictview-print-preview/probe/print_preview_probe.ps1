<#
.SYNOPSIS
    Feature 152 probe: PictView's print preview shows the picture (it was empty since 006), the
    right way round and only the selection when printing the selection.

.DESCRIPTION
    Fixture quad.png (probe\mkfix152.py, Pillow): 80x60, red top left, green top right, blue bottom
    left, yellow bottom right. The viewer opens it, Print (CMD_PRINT) opens the Print dialog and
    its preview control (IDC_PRINT_PREVIEW 2517) is captured with PrintWindow (WM_PRINTCLIENT,
    which the control answers since 152 - a hidden desktop shows nothing otherwise). Each of the
    four colors is counted and located (centroid) in the capture.

    Rows (names for -Only):
      plain      all four colors, red left of green and above blue, yellow right of blue and below
                 green; the colored area 4:3 within 10 %
      mirror-h   the viewer mirrored horizontally (CMD_MIRROR_HOR) first: green left of red
      mirror-v   mirrored vertically (CMD_MIRROR_VERT): blue above red
      rotate     turned right (CMD_ROTATE_RIGHT) first: blue top left, red top right, 3:4
      sel-all    Select All, then "Print selection" checked: as plain
      sel-part   a selection of the top-left quadrant dragged with the select tool (posted mouse
                 messages - NOT DRIVEN when no selection comes of it), "Print selection": red only
                 (the other colors under 5 % of red)
      reopen     the dialog canceled and opened again on the same window (the cached dialog,
                 UpdateImageParams): the picture again

    The control build before 152 has the WM_PRINTCLIENT answer without the preview fix
    (Debug_x64_pre152): the rows FAIL there with nothing of the picture captured.

    MUST run through tools\run_on_hidden_desktop.ps1. Needs a default printer (any; nothing is
    printed - every dialog is canceled). Registry exported before, restored and verified after.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) -or (@($Only | Where-Object { $n -like $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv152' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Drv152
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
    // the client area of 'h' as 0xRRGGBB. method 0: PrintWindow(h, PW_CLIENTONLY); 1: PrintWindow(h,
    // 0) cut to the client area; 2: PrintWindow of the top-level window 'top' (0) cut to h's client
    // area. 'ok' = what PrintWindow returned; untouched pixels keep 0x010203
    public static int[] Capture(IntPtr h, IntPtr top, int method, out int w, out int hgt, out bool ok)
    {
        ok = false;
        RECT cr; GetClientRect(h, out cr); w = cr.Right; hgt = cr.Bottom;
        if (w <= 0 || hgt <= 0) return null;
        IntPtr src = method == 2 ? top : h;
        int ox = 0, oy = 0, bw = w, bh = hgt;
        if (method != 0)
        {
            RECT wr; GetWindowRect(src, out wr);
            POINT p = new POINT(); ClientToScreen(h, ref p);
            ox = p.X - wr.Left; oy = p.Y - wr.Top; bw = wr.Right - wr.Left; bh = wr.Bottom - wr.Top;
        }
        using (var bmp = new Bitmap(bw, bh, PixelFormat.Format32bppRgb))
        {
            using (var g = Graphics.FromImage(bmp))
            {
                g.Clear(Color.FromArgb(1, 2, 3));
                IntPtr hdc = g.GetHdc();
                ok = PrintWindow(src, hdc, method == 0 ? 1u : 0u);
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
                    res[y * w + x] = (sx >= 0 && sy >= 0 && sx < bw && sy < bh) ? (all[sy * bw + sx] & 0xFFFFFF) : 0x010203;
                }
            return res;
        }
    }
    static bool Near(int c, int r, int g, int b)
    {
        return Math.Abs(((c >> 16) & 255) - r) <= 24 && Math.Abs(((c >> 8) & 255) - g) <= 24 && Math.Abs((c & 255) - b) <= 24;
    }
    // per color (0 red, 1 green, 2 blue, 3 yellow): count, centroid x, centroid y; then the
    // bounding box of all four: left, top, right, bottom (exclusive)
    public static double[] Analyze(int[] px, int w, int h)
    {
        int[,] want = { { 255, 0, 0 }, { 0, 255, 0 }, { 0, 0, 255 }, { 255, 255, 0 } };
        var res = new double[16];
        long[] sx = new long[4], sy = new long[4], n = new long[4];
        int l = int.MaxValue, t = int.MaxValue, r = -1, b = -1;
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int c = px[y * w + x];
                for (int k = 0; k < 4; k++)
                    if (Near(c, want[k, 0], want[k, 1], want[k, 2]))
                    {
                        n[k]++; sx[k] += x; sy[k] += y;
                        if (x < l) l = x; if (y < t) t = y; if (x >= r) r = x + 1; if (y >= b) b = y + 1;
                        break;
                    }
            }
        for (int k = 0; k < 4; k++)
        {
            res[k * 3] = n[k];
            res[k * 3 + 1] = n[k] > 0 ? (double)sx[k] / n[k] : -1;
            res[k * 3 + 2] = n[k] > 0 ? (double)sy[k] / n[k] : -1;
        }
        res[12] = l; res[13] = t; res[14] = r; res[15] = b;
        return res;
    }
}
'@
}

$Root = $TempRoot + '\tc152\p'
$StartDir = $Root + '\start'
$Fix = $Root + '\fix'
$Py = 'python'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T152', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
function End-P([string]$Case, [int]$Id, $Before) {
    foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep -Milliseconds 800
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
function Wait-Box([int]$Id, $Known, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $b = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($b) { Start-Sleep -Milliseconds 700; return $b }
        Start-Sleep -Milliseconds 150
    }
    return [IntPtr]::Zero
}
# the viewer's picture window: its largest child
function Renderer([IntPtr]$Wv) {
    return @([Drv098f]::Kids($Wv) | Sort-Object { $r = New-Object Drv152+RECT; [void][Drv152]::GetClientRect($_, [ref]$r); - ($r.Right * $r.Bottom) }) | Select-Object -First 1
}
function Open-Print([int]$Id, [IntPtr]$Wv) {
    $known = Get-Tops $Id
    Post-Cmd $Wv 154   # CMD_PRINT
    return (Wait-Box $Id $known 20)
}
# the preview captured and read: a description and the verdict of $Check (a script block over the
# analysis $a: [count, cx, cy] x 4 colors, then the bounding box)
function Read-Preview([IntPtr]$Dlg) {
    $ctl = Kid $Dlg 2517
    if (-not $ctl) { return $null }
    Start-Sleep -Milliseconds 600
    $tried = @()
    foreach ($m in 0, 1, 2) {
        $w = 0; $h = 0; $okPw = $false
        $px = [Drv152]::Capture($ctl, $Dlg, $m, [ref]$w, [ref]$h, [ref]$okPw)
        if ($null -eq $px) { continue }
        $bg = [int](@($px | Group-Object | Sort-Object Count -Descending | Select-Object -First 1)[0].Name)
        $tried += ('m{0} PrintWindow {1} most {2:X6}' -f $m, $okPw, $bg)
        if ($bg -ne 0x010203) { break }   # something was drawn
    }
    if ($null -eq $px) { return $null }
    $a = [Drv152]::Analyze($px, $w, $h)
    return [pscustomobject]@{ A = $a; W = $w; H = $h; Bg = ($tried -join '; ') }
}
function Desc($p) {
    if ($null -eq $p) { return 'no capture' }
    $a = $p.A; $n = @('red', 'green', 'blue', 'yellow'); $s = @()
    for ($k = 0; $k -lt 4; $k++) { $s += ('{0} {1}@({2:N0},{3:N0})' -f $n[$k], $a[$k * 3], $a[$k * 3 + 1], $a[$k * 3 + 2]) }
    $box = if ($a[14] -ge 0) { '{0}x{1} at {2},{3}' -f ($a[14] - $a[12]), ($a[15] - $a[13]), $a[12], $a[13] } else { 'none' }
    return ('capture {0}x{1} ({2}): {3}; colored box {4}' -f $p.W, $p.H, $p.Bg, ($s -join ', '), $box)
}
# the viewer's picture (its largest child, through PrintWindow of the viewer) as the analysis text
# of its colors; '' when nothing of the picture was captured
function View-Snap([IntPtr]$Wv) {
    $rw = Renderer $Wv
    $w = 0; $h = 0; $okPw = $false
    $px = [Drv152]::Capture($rw, $Wv, 2, [ref]$w, [ref]$h, [ref]$okPw)
    if ($null -eq $px) { return '' }
    $a = [Drv152]::Analyze($px, $w, $h)
    if ($a[0] + $a[3] + $a[6] + $a[9] -eq 0) { return '' }
    return ('red {0} green {1} blue {2} yellow {3}; box {4}x{5} at {6},{7}' -f $a[0], $a[3], $a[6], $a[9], ($a[14] - $a[12]), ($a[15] - $a[13]), $a[12], $a[13])
}
function Num([string]$t) { $v = 0.0; if ([double]::TryParse(($t -replace ',', '.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v)) { return $v }; return 0.0 }
function All4($a) { return ($a[0] -gt 50 -and $a[3] -gt 50 -and $a[6] -gt 50 -and $a[9] -gt 50) }
function Aspect43($a) { $bw = $a[14] - $a[12]; $bh = $a[15] - $a[13]; if ($bh -le 0) { return $false }; $r = $bw / $bh; return ($r -gt 1.2 -and $r -lt 1.47) }
function Upright($a) { return (All4 $a) -and $a[1] -lt $a[4] -and $a[2] -lt $a[8] -and $a[10] -gt $a[7] -and $a[11] -gt $a[5] }
function MirrorH($a) { return (All4 $a) -and $a[4] -lt $a[1] -and $a[10] -lt $a[7] -and $a[2] -lt $a[8] }
# turned 90 degrees clockwise: blue top left, red top right, yellow bottom left, green bottom right; 3:4
function Turned($a) { $bw = $a[14] - $a[12]; $bh = $a[15] - $a[13]; return (All4 $a) -and $bh -gt 0 -and ($bw / $bh) -gt 0.68 -and ($bw / $bh) -lt 0.82 -and $a[7] -lt $a[1] -and $a[8] -lt $a[11] -and $a[10] -lt $a[4] -and $a[2] -lt $a[5] }
function MirrorV($a) { return (All4 $a) -and $a[8] -lt $a[2] -and $a[11] -lt $a[5] -and $a[1] -lt $a[4] }

function Run-Row([string]$Case) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        $id = Start-P $Fix
        Focus-File $id ($Fix + '\quad.png')
        $wv = Open-Viewer $id
        if ($wv -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        if ($Case -eq 'mirror-h') { Post-Cmd $wv 120; Start-Sleep -Milliseconds 800 }
        if ($Case -eq 'mirror-v') { Post-Cmd $wv 121; Start-Sleep -Milliseconds 800 }
        if ($Case -eq 'sel-all') { Post-Cmd $wv 139; Start-Sleep -Milliseconds 800 }
        if ($Case -eq 'rotate') { Post-Cmd $wv 127; Start-Sleep -Milliseconds 1200 }   # CMD_ROTATE_RIGHT
        if ($Case -eq 'sel-part') {
            Post-Cmd $wv 151; Start-Sleep -Milliseconds 500   # CMD_TOOLS_SELECT
            $rw = Renderer $wv
            $r = New-Object Drv152+RECT; [void][Drv152]::GetClientRect($rw, [ref]$r)
            $x0 = [int](($r.Right - 80) / 2); $y0 = [int](($r.Bottom - 60) / 2)   # 100 %, centered
            $lp = { param($x, $y) [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF)) }
            [void][Drv098f]::PostMessageW($rw, 0x0201, [IntPtr]1, (& $lp ($x0 + 1) ($y0 + 1)))
            Start-Sleep -Milliseconds 200
            foreach ($s in 10, 20, 30, 39) { [void][Drv098f]::PostMessageW($rw, 0x0200, [IntPtr]1, (& $lp ($x0 + $s) ($y0 + [int]($s * 0.75)))); Start-Sleep -Milliseconds 120 }
            [void][Drv098f]::PostMessageW($rw, 0x0202, [IntPtr]0, (& $lp ($x0 + 39) ($y0 + 29)))
            Start-Sleep -Milliseconds 800
        }
        $viewBefore = View-Snap $wv
        $dlg = Open-Print $id $wv
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'PRINT' 'NOT DRIVEN' 'no Print dialog (no default printer?)'; return }
        if ($Case -like 'sel-*') {
            $cb = Kid $dlg 2513 'Button'
            if (-not $cb -or -not [Drv098f]::IsWindowEnabled($cb)) {
                $v = if ($Case -eq 'sel-part') { 'NOT DRIVEN' } else { 'FAIL' }
                Row $Case 'SELECT' $v '"Print selection" is not enabled - no selection was made'
                Post-Cmd $dlg 2; return
            }
            Click $cb; Start-Sleep -Milliseconds 800
        }
        if ($Case -eq 'reopen') {
            Post-Cmd $dlg 2; Start-Sleep -Milliseconds 1200
            $dlg = Open-Print $id $wv
            if ($dlg -eq [IntPtr]::Zero) { Row $Case 'PRINT' 'FAIL' 'the second Print dialog did not open'; return }
        }
        # the printed size the dialog shows (Width 2510 / Height 2508 with their units)
        $sw = Num ([Drv098f]::GetText((Kid $dlg 2510 'Edit'), 5000)); $sh = Num ([Drv098f]::GetText((Kid $dlg 2508 'Edit'), 5000))
        $size = '{0} x {1}, fit {2}, keep aspect {3}' -f $sw, $sh,
            [Drv152]::SendR((Kid $dlg 2506 'Button'), 0x00F0, 0, 0), [Drv152]::SendR((Kid $dlg 2507 'Button'), 0x00F0, 0, 0)
        $p = Read-Preview $dlg
        $a = if ($p) { $p.A } else { $null }
        $ok = $false
        if ($a) {
            switch ($Case) {
                'plain' { $ok = (Upright $a) -and (Aspect43 $a) }
                'reopen' { $ok = (Upright $a) -and (Aspect43 $a) }
                'sel-all' { $ok = (Upright $a) -and (Aspect43 $a) }
                'mirror-h' { $ok = (MirrorH $a) -and (Aspect43 $a) }
                'mirror-v' { $ok = (MirrorV $a) -and (Aspect43 $a) }
                'rotate' { $ok = Turned $a }
                'sel-part' {
                    # only red, in the shape of the selection the dialog prints (its width : height)
                    $bw = $a[14] - $a[12]; $bh = $a[15] - $a[13]
                    $shape = $sh -gt 0 -and $bh -gt 0 -and [Math]::Abs(($bw / $bh) / ($sw / $sh) - 1) -lt 0.1
                    $ok = $a[0] -gt 200 -and $a[3] -lt $a[0] * 0.05 -and $a[6] -lt $a[0] * 0.05 -and $a[9] -lt $a[0] * 0.05 -and $shape
                }
            }
        }
        Row $Case 'PREVIEW' (V $ok) ((Desc $p) + '; the dialog: ' + $size)
        Post-Cmd $dlg 2; Start-Sleep -Milliseconds 1500
        # the viewer shows its picture as before (the preview gave the engine's stretch back)
        $viewAfter = View-Snap $wv
        if (-not $viewBefore) { Row $Case 'VIEWER' 'NOT DRIVEN' 'the capture of the viewer shows nothing of the picture' }
        else {
            # the box of the picture (size and place) and each color's count within 5 % - the counts
            # may differ by a few pixels of the animated selection frame
            $boxOf = { param($t) if ($t -match 'box (.*)$') { $Matches[1] } else { '?' } }
            $cnt = { param($t) @([regex]::Matches($t, '(red|green|blue|yellow) (\d+)') | ForEach-Object { [int]$_.Groups[2].Value }) }
            $cb = & $cnt $viewBefore; $ca = & $cnt $viewAfter
            $same = $viewAfter -and (& $boxOf $viewAfter) -eq (& $boxOf $viewBefore) -and $ca.Count -eq 4
            for ($k = 0; $same -and $k -lt 4; $k++) { if ([Math]::Abs($ca[$k] - $cb[$k]) -gt [Math]::Max(3, $cb[$k] * 0.05)) { $same = $false } }
            Row $Case 'VIEWER' (V $same) ("before the dialog: {0}; after: {1}" -f $viewBefore, $viewAfter)
        }
        if (Fatal-Win $id) { Row $Case 'FATAL' 'FAIL' (WinDesc (Fatal-Win $id)) }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- main ------------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc152_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Fix
    $o = & $Py (Join-Path $PSScriptRoot 'mkfix152.py') $Fix 2>&1
    if ("$o" -notmatch 'ok') { throw ('fixture: ' + "$o") }
    Set-Config
    Out ("print_preview_probe (feature 152)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; default printer '{2}'" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), ((Get-CimInstance Win32_Printer | Where-Object Default).Name))
    Out ''
    foreach ($c in 'plain', 'mirror-h', 'mirror-v', 'rotate', 'sel-all', 'sel-part', 'reopen') { Run-Row $c }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } }
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
