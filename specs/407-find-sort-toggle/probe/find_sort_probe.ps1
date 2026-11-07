<#
.SYNOPSIS
    Backlog item nefunkcni-prepinani-razeni-vysledku-hledani (GitHub #23) probe: Find's result
    list - a second sort by the same column reverses the order, another column starts ascending,
    folders stay grouped before files in both directions, the header shows the sort arrow, a new
    search forgets the sort.

.DESCRIPTION
    Fixture %TEMP%\tcfsort\find: folders dB / dA (last write 2008 / 2014, empty) and files
    fC.txt (4 bytes, 2006), fA.txt (1 byte, 2010), fD.txt (3 bytes, 2012), fB.txt (2 bytes, 2016):
    the orders by name, date and size all differ. Find (741) in it, Named '*'. The order is the Name cells of the result list
    (LVM_GETITEMTEXTW, 127's library), the arrow the HDF_SORTUP (0x0400) / HDF_SORTDOWN (0x0200)
    bits of the header item format (HDM_GETITEMW in the program's memory).
    Rows:
      menu-time   View > Date (CM_FIND_TIME 2239, the Ctrl+F5 route) once, twice, three times:
                  PASS = ascending by date (folders first), then descending (folders still first,
                  each group reversed), then ascending again; the Date header arrow up / down / up
      click-date  a posted click on the Date header (LVN_COLUMNCLICK) once and twice: as menu-time
      click-other the Date header twice (descending), then the Name header: PASS = ascending by
                  name, the arrow moved to Name (up), none on Date
      click-size  the Size header twice: PASS = ascending, then descending by size inside each group
      new-search  sorted descending by date, then Find again: PASS = no arrow on any column, and
                  the next View > Date sorts ascending
      attr        a click on the Attributes header: PASS = the order and every arrow unchanged
      click-path  the Path header twice, then View > Path (one path for all items): by name,
                  then folders first with the names reversed, then ascending again (review 1)
      dup         Find duplicates (CM_FIND_DUPLICATES 2292, its options dialog answered OK: same
                  name and size) in %TEMP%\tcfsort\dup (pairs x / y / z in s1, s2, s3, one unique
                  file): Name up, Name down with each group together; Path and View > Date
                  refused (order and arrow unchanged); Size up, down, up; Find duplicates again:
                  no arrow. The order is name@folder (review 1: the reviewer's dup probe)
      refused     sorted by Date descending, then Intersect, Subtract and Append (2289-2291) with an
                  invalid regular expression "(" - each refused by its error box: PASS = the six
                  items, their order and the arrow kept (review 2: Intersect / Subtract emptied the
                  list before), then View > Date ascending
      pix-light   what the header paints (PrintWindow, a hash of the pixels): before a sort, after
                  View > Date, after it again - PASS = three different pictures (review 2)
      pix-dark    the same in the program's dark theme ("Theme Mode" = 1): the arrow is painted by
                  the program there (features 044 / 049) - before review 2's fix the three
                  pictures were identical. -PixDir <folder> saves the PNGs
    No real mouse or keyboard: clicks are posted WM_LBUTTONDOWN / UP to the header control,
    commands are WM_COMMAND. Driver of 311's probe (098's library). MUST run through
    tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Repo,
    [string]$PixDir
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Repo) { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $Repo 'specs\127-mixed-template-texts\probe\lvtext_lib.ps1')
if (-not ('HdrFmtSort' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HdrFmtSort
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, UIntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool VirtualFreeEx(IntPtr p, IntPtr a, UIntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] b, int n, out IntPtr w);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, int n, out IntPtr r);
    // the fmt of header item 'index' (HDITEMW, x64: mask at 0, fmt at 28), -1 when it cannot be read
    public static int Fmt(IntPtr hdr, int index)
    {
        uint pid; GetWindowThreadProcessId(hdr, out pid);
        IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020 | 0x0400, false, pid);
        if (hp == IntPtr.Zero) return -1;
        try
        {
            const int size = 128;
            IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, (UIntPtr)(uint)size, 0x3000, 0x04);
            if (mem == IntPtr.Zero) return -1;
            try
            {
                var hdi = new byte[size];
                BitConverter.GetBytes(0x0004).CopyTo(hdi, 0); // HDI_FORMAT
                IntPtr w;
                if (!WriteProcessMemory(hp, mem, hdi, size, out w)) return -1;
                IntPtr r;
                if (SendMessageTimeoutW(hdr, 0x120B, (IntPtr)index, mem, 0, 5000, out r) == IntPtr.Zero) return -1; // HDM_GETITEMW
                if (r == IntPtr.Zero) return -1;
                var buf = new byte[size];
                IntPtr rd;
                if (!ReadProcessMemory(hp, mem, buf, size, out rd)) return -1;
                return BitConverter.ToInt32(buf, 28);
            }
            finally { VirtualFreeEx(hp, mem, UIntPtr.Zero, 0x8000); }
        }
        finally { CloseHandle(hp); }
    }
}
'@
}

$Root = $TempRoot + '\tcfsort'
$StartDir = $Root + '\start'
$FindDir = $Root + '\find'
$Items = @(
    @{ Name = 'dB'; Dir = $true; Year = 2008; Size = 0 },
    @{ Name = 'dA'; Dir = $true; Year = 2014; Size = 0 },
    @{ Name = 'fC.txt'; Dir = $false; Year = 2006; Size = 4 },
    @{ Name = 'fA.txt'; Dir = $false; Year = 2010; Size = 1 },
    @{ Name = 'fD.txt'; Dir = $false; Year = 2012; Size = 3 },
    @{ Name = 'fB.txt'; Dir = $false; Year = 2016; Size = 2 }
)
# the expected Name orders (name, date and size orders all differ)
$DateUp = 'dB,dA,fC.txt,fA.txt,fD.txt,fB.txt'
$DateDown = 'dA,dB,fB.txt,fD.txt,fA.txt,fC.txt'
$NameUp = 'dA,dB,fA.txt,fB.txt,fC.txt,fD.txt'
$SizeUp = 'dA,dB,fA.txt,fB.txt,fD.txt,fC.txt'       # folders: size 0 both, then by name
$SizeDown = 'dB,dA,fC.txt,fD.txt,fB.txt,fA.txt'     # every key reversed
$PathUp = 'dA,dB,fA.txt,fB.txt,fC.txt,fD.txt'       # one path for all: by name
$PathDown = 'dB,dA,fD.txt,fC.txt,fB.txt,fA.txt'     # folders still first, names reversed
# the duplicates fixture (review 1, the reviewer's dup probe): three pairs of files with the same
# name and size in s1 / s2 / s3, one unique file; the order is name@folder
$DupDir = $Root + '\dup'
$DupItems = @(
    @{ Name = 's1\x.txt'; Text = 'aa' }, @{ Name = 's2\x.txt'; Text = 'aa' },
    @{ Name = 's1\y.txt'; Text = 'b' }, @{ Name = 's3\y.txt'; Text = 'b' },
    @{ Name = 's2\z.txt'; Text = 'ccc' }, @{ Name = 's3\z.txt'; Text = 'ccc' }
)
$DupNameUp = 'x@s1,x@s2,y@s1,y@s3,z@s2,z@s3'
$DupNameDown = 'z@s3,z@s2,y@s3,y@s1,x@s2,x@s1'   # each group together, the groups and members reversed
$DupSizeUp = 'y@s1,y@s3,x@s1,x@s2,z@s2,z@s3'
$DupSizeDown = 'z@s3,z@s2,x@s2,x@s1,y@s3,y@s1'
$script:Mode = 'normal'

function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}
function Get-Lv([IntPtr]$Dlg) { return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' }) | Select-Object -First 1) }
function Get-Hdr([IntPtr]$Lv) { return (@([Drv098f]::Kids($Lv) | Where-Object { [Drv098f]::Cls($_) -eq 'SysHeader32' }) | Select-Object -First 1) }
function Order([IntPtr]$Lv) {
    $n = [LvText127]::Count($Lv)
    if ($script:Mode -eq 'dup') {
        return ((@(0..($n - 1) | ForEach-Object { ([IO.Path]::GetFileNameWithoutExtension([LvText127]::Cell($Lv, $_, 0))) + '@' + ([LvText127]::Cell($Lv, $_, 1).TrimEnd('\') -split '\\')[-1] })) -join ',')
    }
    return ((@(0..($n - 1) | ForEach-Object { [LvText127]::Cell($Lv, $_, 0) })) -join ',')
}
# the arrows of the six columns: '-' none, '^' up, 'v' down, '?' unreadable
function Arrows([IntPtr]$Lv) {
    $h = Get-Hdr $Lv
    return (-join (0..5 | ForEach-Object {
        $f = [HdrFmtSort]::Fmt($h, $_)
        if ($f -lt 0) { '?' } elseif ($f -band 0x0400) { '^' } elseif ($f -band 0x0200) { 'v' } else { '-' }
    }))
}
function Click-Col([IntPtr]$Lv, [int]$Col) {
    $h = Get-Hdr $Lv
    $x = 0
    for ($i = 0; $i -lt $Col; $i++) { $r = [IntPtr]::Zero; [void][Drv098f]::SendMessageTimeoutW($Lv, 0x101D, [IntPtr]$i, [IntPtr]::Zero, 0, 5000, [ref]$r); $x += [int]$r.ToInt64() }   # LVM_GETCOLUMNWIDTH
    $r = [IntPtr]::Zero; [void][Drv098f]::SendMessageTimeoutW($Lv, 0x101D, [IntPtr]$Col, [IntPtr]::Zero, 0, 5000, [ref]$r)
    $x += [int]([int]$r.ToInt64() / 2)
    Post-Click $h $x 6
    Start-Sleep -Milliseconds 700
    [void][Drv098f]::Send($Lv, 0, 0, 0, 10000)
}
function Menu-Cmd([IntPtr]$Dlg, [int]$Cmd) { Post-Cmd $Dlg $Cmd; Start-Sleep -Milliseconds 700; [void][Drv098f]::Send($Dlg, 0, 0, 0, 10000) }
function Want-Count { if ($script:Mode -eq 'dup') { return $DupItems.Count } else { return $Items.Count } }
function Do-Find([IntPtr]$Dlg) {
    if ($script:Mode -eq 'dup') {
        # Find duplicates (CM_FIND_DUPLICATES 2292): its options dialog, OK with the defaults (same name and size)
        $known = Get-Tops $script:RowId
        Post-Cmd $Dlg 2292
        $w = Wait-NewWin $script:RowId $known 10
        if ($w -eq [IntPtr]::Zero) { throw 'Find duplicates opened no options dialog' }
        Click-Ok $w
    }
    else { Click (Find-Btn $Dlg 1) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $lv = Get-Lv $Dlg
    while ($sw.Elapsed.TotalSeconds -lt 20 -and [LvText127]::Count($lv) -lt (Want-Count)) { Start-Sleep -Milliseconds 200 }
    Start-Sleep -Milliseconds 1500
}
function Open-Find([int]$Id) {
    $dlg = Open-ByCmd $Id 741 15
    if ($dlg -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
    Start-Sleep -Milliseconds 600
    Set-Field $dlg 2501 $(if ($script:Mode -eq 'dup') { $DupDir } else { $FindDir })
    Set-Field $dlg 2505 '*'
    Do-Find $dlg
    $lv = Get-Lv $dlg
    $n = [LvText127]::Count($lv)
    if ($n -ne (Want-Count)) { throw ("Find found {0} items, not {1}: {2}" -f $n, (Want-Count), (Order $lv)) }
    return $dlg
}
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch {
        Row $Case 'ERROR' 'FAIL' $_.Exception.Message
        if ($script:RowId -and (Test-Alive $script:RowId)) { foreach ($h in @(Get-Tops $script:RowId | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}
# runs $Steps (a list of @{ Do = scriptblock taking dlg, lv; Order = expected or $null; Arrows = expected or $null })
function Seq-Row([string]$Case, $Steps, [string]$Mode = 'normal') {
    $script:Mode = $Mode
    Run-Row $Case {
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-Find $id
        $lv = Get-Lv $dlg
        $facts = @(("found: {0} [{1}]" -f (Order $lv), (Arrows $lv)))
        $ok = $true
        $n = 0
        foreach ($s in $Steps) {
            $n++
            & $s.Do $dlg $lv
            $o = Order $lv; $a = Arrows $lv
            $okO = ($null -eq $s.Order) -or (@($s.Order) -contains $o)
            $okA = ($null -eq $s.Arrows) -or ($a -ceq $s.Arrows)
            $ok = $ok -and $okO -and $okA
            $box = ''
            if ($script:BoxText) { $box = ' (box: ' + (Tail ($script:BoxText -replace '\[Button id=\d+\] [^|]*(\||$)', '') 120) + ')'; $script:BoxText = $null }   # review 3: the box answered
            $facts += ("{0} {1}{2}: {3} [{4}]{5}" -f $n, $s.What, $box, $o, $a, $(if ($okO -and $okA) { '' } else { ' <- expected ' + (@($s.Order) -join ' | ') + ' [' + $s.Arrows + ']' }))
        }
        $script:RowFatal = Fatal-Win $id
        Row $Case 'RUN' (V ($ok -and -not $script:RowFatal)) ($facts -join '; ')
        Close-Win $dlg; Start-Sleep -Milliseconds 500
        [void](Serve $id 10)
    }
}

# ---- review 2: what the header really paints (the format bits alone did not show the dark theme's
# missing arrow) - PrintWindow of the header, an FNV hash of its pixels (the reviewer's pix row)
if (-not ('HdrPix407' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class HdrPix407
{
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    public static string Shot(IntPtr h, string file)
    {
        RECT r; GetWindowRect(h, out r);
        int w = r.R - r.L, ht = r.B - r.T;
        if (w <= 0 || ht <= 0) return "empty";
        using (var bmp = new Bitmap(w, ht, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(bmp))
            {
                IntPtr hdc = g.GetHdc();
                PrintWindow(h, hdc, 0);
                g.ReleaseHdc(hdc);
            }
            ulong hash = 1469598103934665603UL;
            for (int y = 0; y < ht; y++)
                for (int x = 0; x < w; x++)
                {
                    hash ^= (ulong)bmp.GetPixel(x, y).ToArgb();
                    hash *= 1099511628211UL;
                }
            if (!string.IsNullOrEmpty(file)) bmp.Save(file, ImageFormat.Png); // PowerShell passes $null as ""
            return hash.ToString("X16");
        }
    }
}
'@
}
# the header painted before any sort, after View > Date (up) and again (down): PASS = three different
# pictures; -Dark: the program's dark theme (Configuration "Theme Mode" = 1 in the probe's registry)
function Pix-Row([string]$Case, [bool]$Dark) {
    $script:Mode = 'normal'
    Run-Row $Case {
        if ($Dark) { & reg.exe add "$RegKey\Settings\Configuration" /v 'Theme Mode' /t REG_DWORD /d 1 /f | Out-Null }
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-Find $id
        $lv = Get-Lv $dlg
        $h = Get-Hdr $lv
        $tag = $(if ($Dark) { 'dark' } else { 'light' })
        $file = { param($n) if ($PixDir) { Join-Path $PixDir ('pix_' + $tag + '_' + $n + '.png') } else { $null } }
        $h0 = [HdrPix407]::Shot($h, (& $file '0none')); $a0 = Arrows $lv
        Menu-Cmd $dlg 2239; Start-Sleep -Milliseconds 400
        $h1 = [HdrPix407]::Shot($h, (& $file '1up')); $a1 = Arrows $lv
        Menu-Cmd $dlg 2239; Start-Sleep -Milliseconds 400
        $h2 = [HdrPix407]::Shot($h, (& $file '2down')); $a2 = Arrows $lv
        $script:RowFatal = Fatal-Win $id
        $ok = ($h0 -ne $h1) -and ($h1 -ne $h2) -and ($h0 -ne $h2) -and ($a1 -ceq '---^--') -and ($a2 -ceq '---v--')
        Row $Case 'RUN' (V $ok) ("{0}: none {1} [{2}]; up {3} [{4}]; down {5} [{6}]" -f $tag, $h0, $a0, $h1, $a1, $h2, $a2)
        Close-Win $dlg; Start-Sleep -Milliseconds 500
        [void](Serve $id 10)
    }
}

# review 2 (NOTE 2): a refine or Append refused by an invalid regular expression - "Search file
# content" (2508) and "Regular expression" (2513) on, Containing (2504) "(", the command posted, the
# error box answered OK; the list must keep its items, their order and the arrow
function Set-Check([IntPtr]$Dlg, [int]$CtlId, [bool]$On) {
    $b = Find-Btn $Dlg $CtlId
    if (-not $b) { throw "check box $CtlId not found" }
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($b, 0x00F0, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # BM_GETCHECK
    if (($res.ToInt64() -eq 1) -ne $On) { Click $b; Start-Sleep -Milliseconds 400 }
}
function Refused-Cmd([IntPtr]$Dlg, [int]$Cmd) {
    Set-Check $Dlg 2508 $true
    Set-Check $Dlg 2513 $true
    Set-Field $Dlg 2504 '('
    $known = Get-Tops $script:RowId
    Post-Cmd $Dlg $Cmd
    $w = Wait-NewWin $script:RowId $known 10
    if ($w -eq [IntPtr]::Zero) { $script:BoxText = '<no box>'; return }   # (an emptied list offers no refine)
    $script:BoxText = WinDesc $w
    Click-Ok $w
    Start-Sleep -Milliseconds 800
    [void][Drv098f]::Send($Dlg, 0, 0, 0, 10000)
}

$TimeCmd = { param($d, $l) Menu-Cmd $d 2239 }
$ClickDate = { param($d, $l) Click-Col $l 3 }
$ClickName = { param($d, $l) Click-Col $l 0 }
$ClickSize = { param($d, $l) Click-Col $l 2 }
$ClickAttr = { param($d, $l) Click-Col $l 5 }
$ClickPath = { param($d, $l) Click-Col $l 1 }
$FindAgain = { param($d, $l) Do-Find $d }
$Cases = [ordered]@{}
$Cases['menu-time'] = { Seq-Row 'menu-time' @(
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateUp; Arrows = '---^--' },
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateDown; Arrows = '---v--' },
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateUp; Arrows = '---^--' }) }
$Cases['click-date'] = { Seq-Row 'click-date' @(
        @{ What = 'click Date'; Do = $ClickDate; Order = $DateUp; Arrows = '---^--' },
        @{ What = 'click Date'; Do = $ClickDate; Order = $DateDown; Arrows = '---v--' }) }
$Cases['click-other'] = { Seq-Row 'click-other' @(
        @{ What = 'click Date'; Do = $ClickDate; Order = $DateUp; Arrows = '---^--' },
        @{ What = 'click Date'; Do = $ClickDate; Order = $DateDown; Arrows = '---v--' },
        @{ What = 'click Name'; Do = $ClickName; Order = $NameUp; Arrows = '^-----' }) }
$Cases['click-size'] = { Seq-Row 'click-size' @(
        @{ What = 'click Size'; Do = $ClickSize; Order = $SizeUp; Arrows = '--^---' },
        @{ What = 'click Size'; Do = $ClickSize; Order = $SizeDown; Arrows = '--v---' }) }
$Cases['new-search'] = { Seq-Row 'new-search' @(
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateUp; Arrows = '---^--' },
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateDown; Arrows = '---v--' },
        @{ What = 'Find again'; Do = $FindAgain; Order = $null; Arrows = '------' },
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateUp; Arrows = '---^--' }) }
$Cases['attr'] = { Seq-Row 'attr' @(
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateUp; Arrows = '---^--' },
        @{ What = 'click Attr'; Do = $ClickAttr; Order = $DateUp; Arrows = '---^--' }) }
$Cases['click-path'] = { Seq-Row 'click-path' @(
        @{ What = 'click Path'; Do = $ClickPath; Order = $PathUp; Arrows = '-^----' },
        @{ What = 'click Path'; Do = $ClickPath; Order = $PathDown; Arrows = '-v----' },
        @{ What = 'View>Path'; Do = { param($d, $l) Menu-Cmd $d 2241 }; Order = $PathUp; Arrows = '-^----' }) }
$Cases['dup'] = { Seq-Row 'dup' @(
        @{ What = 'click Name'; Do = $ClickName; Order = $DupNameUp; Arrows = '^-----' },
        @{ What = 'click Name'; Do = $ClickName; Order = $DupNameDown; Arrows = 'v-----' },
        @{ What = 'click Path'; Do = $ClickPath; Order = $DupNameDown; Arrows = 'v-----' },
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DupNameDown; Arrows = 'v-----' },
        @{ What = 'click Size'; Do = $ClickSize; Order = $DupSizeUp; Arrows = '--^---' },
        @{ What = 'click Size'; Do = $ClickSize; Order = $DupSizeDown; Arrows = '--v---' },
        @{ What = 'click Size'; Do = $ClickSize; Order = $DupSizeUp; Arrows = '--^---' },
        @{ What = 'dup again'; Do = $FindAgain; Order = $null; Arrows = '------' }) 'dup' }
$Cases['refused'] = { Seq-Row 'refused' @(
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateUp; Arrows = '---^--' },
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateDown; Arrows = '---v--' },
        @{ What = 'Intersect refused'; Do = { param($d, $l) Refused-Cmd $d 2289 }; Order = $DateDown; Arrows = '---v--' },
        @{ What = 'Subtract refused'; Do = { param($d, $l) Refused-Cmd $d 2290 }; Order = $DateDown; Arrows = '---v--' },
        @{ What = 'Append refused'; Do = { param($d, $l) Refused-Cmd $d 2291 }; Order = $DateDown; Arrows = '---v--' },
        @{ What = 'View>Date'; Do = $TimeCmd; Order = $DateUp; Arrows = '---^--' }) }
$Cases['pix-light'] = { Pix-Row 'pix-light' $false }
$Cases['pix-dark'] = { Pix-Row 'pix-dark' $true }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tcfsort_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $FindDir
    WriteFile "$StartDir\a.txt" 'A'
    foreach ($it in $Items) {
        $p = $FindDir + '\' + $it.Name
        $t = New-Object DateTime ($it.Year, 6, 15, 12, 0, 0)
        if ($it.Dir) { NewDir $p; [IO.Directory]::SetLastWriteTime($LP + $p, $t) }
        else { WriteFile $p ('x' * $it.Size); [IO.File]::SetLastWriteTime($LP + $p, $t) }
    }
    foreach ($it in $DupItems) {
        $p = $DupDir + '\' + $it.Name
        NewDir ([IO.Path]::GetDirectoryName($p))
        WriteFile $p $it.Text
    }
    WriteFile ($DupDir + '\s1\u.txt') 'unique'
    Set-Config
    Out ("find_sort_probe (backlog item nefunkcni-prepinani-razeni-vysledku-hledani) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out 'Fixture: dB 2008, dA 2014 (folders), fC.txt 4 B 2006, fA.txt 1 B 2010, fD.txt 3 B 2012, fB.txt 2 B 2016; arrows per column Name,Path,Size,Date,Time,Attr: ^ up, v down, - none'
    Out ''
    foreach ($k in @($Cases.Keys)) {
        if (Want $k) {
            & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
            if ($existed) { & cmd.exe /c "reg import `"$backup`" >nul 2>&1" }
            Set-Config
            & $Cases[$k]
        }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
