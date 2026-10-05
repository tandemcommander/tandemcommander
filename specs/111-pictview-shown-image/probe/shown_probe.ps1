<#
.SYNOPSIS
    Feature 111 probe: PictView works on the image it shows. On the build of this feature and on
    the build before it (Debug_x64_pre111, the control).

.DESCRIPTION
    Fixtures under %TEMP%\tc111\p (removed at the end, explicit root only). Images are made by
    Pillow (probe\pilcheck.py decodes every saved file independently of the program and reads
    the TIFF tags / JPEG COM bytes by hand).

    Rows (names for -Only):
      ren-*      Rename (CMD_IMG_RENAME) of the shown image: to an ASCII, Cyrillic and CJK name;
                 the shown file held by another program (fails, nothing changes); onto an existing
                 file held by another program (overwrite Yes - fails, both intact); onto an existing
                 read-only file (overwrite Yes - replaced). After each: the viewer holds the file
                 again under the name it now has (an open for DELETE fails with 32), its zoom is
                 unchanged and a Save As of what it shows is pixel-exact. Before 111: error 32.
      del-*      Delete (CMD_IMG_DELETE) of the shown image through \\localhost\C$ (no recycle bin:
                 the shell asks "permanently delete?"): Yes - gone, title <Deleted>, the image
                 still saveable; No - the file stays and is held again. Before 111: "File in use".
      two-*      two viewer windows on one file: Save As over it (rotated 90) from the first - the
                 second shows the saved image (30 x 40 in its title); Rename - the second shows the
                 new name; Delete - the second shows <Deleted>. Before 111: "in use" / error 32.
      alpha-*    the "alpha channel will be lost" question before the Save As dialog: not for an
                 opaque 32-bit PNG / TIFF / ICO, still for one with real transparency
      depth-*    the dialog's default depth and offers: bilevel PNG and CCITT G4 TIFF sources offer
                 "2 colors" (default) and CCITT G3/G4; saved as CCITT G4 TIFF / 1-bit PNG, decoded
                 pixel-equal; gray -> "256 gray levels"; 16-color palette -> "16 colors"; the title
                 says the source's colors
      cmt-*      comments: TIFF ASCII -> tag 270 ASCII only; TIFF non-ASCII -> tag 270 UTF-8 and
                 XMP dc:description (x-default) with the same text; JPEG COM without a NUL byte
      view-*     zoom and mirror after a Save As over the shown image: kept when the replace fails
                 (file held elsewhere), zoom kept after a successful one (the mirror is in the file)
      wp-*       wallpaper commands, ONLY with the dry-run seam (TC_PICTVIEW_WALLPAPER_DRYRUN = a log
                 file): the BMP written to %LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp is
                 decoded; the log names the registry values and the SPI_SETDESKWALLPAPER path that
                 WOULD be used. -NoWallpaper (the pre-111 build, which has no seam) skips them: its
                 commands call SystemParametersInfo with NULL even after a failed save.
      r-nav-del  review B1: windows A and B show x.png; A deletes it and, while the shell asks
                 "permanently delete?", B goes to the next file y.png; Yes: B shows y.png (not
                 <Deleted>) and holds it
      r-nav-ren  the same for a Rename onto an existing z.png (B moves on during the overwrite
                 question): B keeps y.png's name and holds y.png; z.png holds x.png's content
      r-cross    re-review B1: \\localhost; A and B show x.png, C shows y.png; A deletes x.png (question
                 open), B goes to y.png, C renames y.png onto z.png and B lets y go for C's operation
                 (overwrite question open); A's delete confirmed, then C declines: B shows and holds
                 y.png (not <Deleted>), y.png and z.png unchanged
      r-multi    review S3: a two-page TIFF (24-bit, then bilevel): the title names each page's colors
      r-busy     review S1: B saves a large image (slow 256-color PNG) while A saves over the file B
                 shows: no crash; B's file valid; the shown file either replaced or unchanged
      r-print    review S1, deterministic: B's Print dialog is open while A saves over the file: B
                 keeps the file (A: "Unable to save ... in use"), nothing lost, B's image intact
      hl-del     a hard link: A shows a.png, B shows its hard link b.png; A deletes a.png: B keeps
                 b.png (not <Deleted>) and holds it
      info-cmyk  Image Information of a CMYK JPEG says CMYK
      wp-real    always: HKCU\Control Panel\Desktop (Wallpaper, WallpaperStyle, TileWallpaper,
                 PrevWallpaper*) and SPI_GETDESKWALLPAPER unchanged by the whole run

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another tandemcommander.exe
    runs. HKCU\Software\Tandem Commander exported before, restored and SHA-256-verified after.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [switch]$NoWallpaper,
    [int[]]$NotifyCodes = @(9, 1)
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) -or (@($Only | Where-Object { $n -like $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv111' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Drv111
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr CreateFileW(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool SystemParametersInfoW(uint action, uint uiParam, StringBuilder pv, uint flags);
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
    // (32 = another handle - the viewer's decoder - does not share delete)
    public static int OpenDeleteErr(string path)
    {
        IntPtr h = CreateFileW(path, 0x00010000 /*DELETE*/, 7, IntPtr.Zero, 3 /*OPEN_EXISTING*/, 0, IntPtr.Zero);
        if (h == new IntPtr(-1)) return Marshal.GetLastWin32Error();
        CloseHandle(h); return 0;
    }
    // read-only query (SPI_GETDESKWALLPAPER = 0x0073)
    public static string GetWallpaper()
    {
        var sb = new StringBuilder(1024);
        if (!SystemParametersInfoW(0x0073, (uint)sb.Capacity, sb, 0)) return "<error " + Marshal.GetLastWin32Error() + ">";
        return sb.ToString();
    }
}
'@
}

$Root = $TempRoot + '\tc111\p'
$StartDir = $Root + '\start'
$Fix = $Root + '\fix'
$Out = $Root + '\out'
$Unc = '\\localhost\' + $Root.Substring(0, 1) + '$' + $Root.Substring(2)
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
$Cyr = S 0x0416, 0x0430, 0x0431, 0x0430
$Cjk = S 0x65E5, 0x672C, 0x8A9E
$Cjk2 = S 0x5199, 0x771F
$CommentU = 'Koment' + [char]0x00E1 + [char]0x0159 + ' ' + (S 0x65E5, 0x672C)
$CommentA = 'Plain comment'
$Py = 'python'
$PilCheck = Join-Path $PSScriptRoot 'pilcheck.py'
$WpDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$WpFile = Join-Path $WpDir 'PictView_Wallpaper.bmp'
$WpLog = $Root + '\wallpaper_dryrun.log'
$DavPort = 18111
$DavBack = $Root + '\dav'
$DavLog = $Root + '\davnorm.log'
$DavA = '\\localhost@' + $DavPort + '\dav'
$DavPy = Join-Path $PSScriptRoot '..\..\103-same-file-delete-guard\probe\davnorm.py'
$Nfd = 'cafe' + [char]0x0301 + '.png'     # how a macOS server stores the name
$Nfc = 'Caf' + [char]0xE9 + '.png'        # what the user types: the same name on that server
$script:Dav = $null

function PutBytes([string]$p, [byte[]]$b) { [IO.File]::WriteAllBytes($LP + $p, $b) }
function PutText([string]$p, [string]$t) { [IO.File]::WriteAllText($LP + $p, $t, (New-Object Text.ASCIIEncoding)) }
function Bytes([string]$p) { if ([IO.File]::Exists($LP + $p)) { return , [IO.File]::ReadAllBytes($LP + $p) } else { return $null } }
function Hash([string]$p) { $b = Bytes $p; if ($null -eq $b) { return '<missing>' }; $s = [Security.Cryptography.SHA256]::Create(); return ([BitConverter]::ToString($s.ComputeHash($b)) -replace '-', '').Substring(0, 16) }
function Exists([string]$p) { return [IO.File]::Exists($LP + $p) }
function Held([string]$p) { return [Drv111]::OpenDeleteErr($LP + $p) }
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
    $a = @('-t', 'T111', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
# the shell's DirectUI "file in use" window: closed); records the texts; stops after 2 s idle
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
function Zoom([string]$t) { if ($t -match ' - (\d+)%\) - ') { return [int]$Matches[1] }; return -1 }
function Dims([string]$t) { if ($t -match '\((\d+) x (\d+) x ') { return ('{0}x{1}' -f $Matches[1], $Matches[2]) }; return '?' }
function Combo-Items([IntPtr]$C) {
    if (-not $C) { return @() }
    $n = [Drv111]::SendR($C, 0x0146, 0, 0); $l = @()
    for ($i = 0; $i -lt $n; $i++) { $l += [Drv111]::LbText($C, $i) }
    return $l
}
function Combo-Sel([IntPtr]$C) { if (-not $C) { return '' }; $i = [Drv111]::SendR($C, 0x0147, 0, 0); if ($i -lt 0) { return '<none>' }; return [Drv111]::LbText($C, [int]$i) }
function Pick([IntPtr]$C, [string]$Rx, [switch]$Notify) {
    if (-not $C) { return $false }
    $items = @(Combo-Items $C)
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($items[$i] -match $Rx) {
            [void][Drv111]::SendR($C, 0x014E, $i, 0)
            if ($Notify) {
                $cid = [Drv098f]::GetDlgCtrlID($C); $par = [Drv098f]::GetParent($C)
                foreach ($code in $NotifyCodes) { [void][Drv111]::SendR($par, 0x0111, (($code -shl 16) -bor $cid), $C.ToInt64()) }
            }
            Start-Sleep -Milliseconds 300
            return $true
        }
    }
    return $false
}
# Ctrl+S in viewer $Wv; the questions before the dialog are answered Yes and recorded (Pre);
# $O: Type, Depth, Comp, Rot, Comment; $Full = the name; -Inspect: only read the lists, Cancel
function Save-As([int]$Id, [IntPtr]$Wv, [string]$Full, $O, [switch]$Inspect) {
    $r = [pscustomobject]@{ Ok = $false; Note = ''; Pre = @(); Depths = @(); DepthSel = ''; Comps = @() }
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
    $r.Depths = @(Combo-Items $depth); $r.DepthSel = Combo-Sel $depth; $r.Comps = @(Combo-Items $comp)
    if ($Inspect) { Post-Cmd $od 2; Start-Sleep -Milliseconds 800; $r.Ok = $true; return $r }
    if ($O.Comp -and -not (Pick $comp $O.Comp -Notify)) { $r.Note = "compression '$($O.Comp)' not offered: " + ((Combo-Items $comp) -join '/'); Post-Cmd $od 2; return $r }
    if ($O.Depth -and -not (Pick $depth $O.Depth -Notify)) { $r.Note = "depth '$($O.Depth)' not offered: " + ((Combo-Items $depth) -join '/'); Post-Cmd $od 2; return $r }
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
# a save whose result is checked by the caller; returns the boxes text
function Save-Simple([int]$Id, [IntPtr]$Wv, [string]$Full, $O, $Ignore = @()) {
    $s = Save-As $Id $Wv $Full $O
    $ans = Answer $Id 25 @(6, 2, 1) (@($Ignore) + @($Wv))
    Cancel-Dialogs $Id
    return [pscustomobject]@{ Save = $s; Boxes = (Msgs2 $ans) }
}
# CMD_IMG_RENAME in viewer $Wv: the field 2172 set to $NewName, OK; the boxes after it answered
# with $WantIds (overwrite: 6 = Yes)
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
    # a rename dialog shown again (the old build after an error): Cancel
    foreach ($x in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 2172 'Edit') })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 500 }
    return (Msgs2 $ans)
}
function Delete-Shown([int]$Id, [IntPtr]$Wv, [int[]]$WantIds, $Ignore = @()) {
    Post-Cmd $Wv 186
    Start-Sleep -Milliseconds 1500
    $ans = Answer $Id 20 $WantIds (@($Ignore) + @($Wv))
    return (Msgs2 $ans)
}
# a Save As of what the viewer shows into a new file: pixel hash (Pillow) - proves the image is
# still there and what it looks like
function Shown-Pixels([int]$Id, [IntPtr]$Wv, [string]$Full, $Ignore = @()) {
    $x = Save-Simple $Id $Wv $Full @{ Type = 'Portable Network'; Rot = 'None' } $Ignore
    if (-not (Exists $Full)) { return ('<no file; ' + $x.Save.Note + '; ' + $x.Boxes + '>') }
    $f = PilOne $Full
    return ('{0} {1}' -f $f.size, $f.pixels)
}
function Make-Fixtures {
    NewDir $Fix
    $o = & $Py (Join-Path $PSScriptRoot 'mkfix111.py') $Fix 2>&1
    if ("$o" -notmatch 'ok') { throw ('fixtures: ' + "$o") }
}
function Fx([string]$name, [string]$dir, [string]$as) { if (-not $as) { $as = $name }; NewDir $dir; [IO.File]::Copy($LP + $Fix + '\' + $name, $LP + $dir + '\' + $as, $true); return ($dir + '\' + $as) }

# ---- rename -------------------------------------------------------------------------------------
# $Setup returns a context; $Cleanup undoes it; $Expect: 'renamed', 'kept', 'replaced'
function Run-Ren([string]$Case, [string]$SrcName, [string]$NewName, [string]$Expect, [scriptblock]$Setup, [scriptblock]$Cleanup) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = Fx 'rgb.png' $d $SrcName
    $tgt = $d + '\' + $NewName
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        Post-Cmd $w 102; Start-Sleep -Milliseconds 800   # zoom in once: the view must survive
        $t0 = Title $w; $z0 = Zoom $t0
        $h0 = Hash $src
        $ctx = $null; if ($Setup) { $ctx = & $Setup }
        $ht0 = Hash $tgt
        try { $boxes = Rename-Shown $id $w $NewName }
        finally { if ($Cleanup) { & $Cleanup $ctx } }
        Start-Sleep -Milliseconds 500
        $t1 = Title $w; $z1 = Zoom $t1
        $srcNow = Hash $src; $tgtNow = Hash $tgt
        switch ($Expect) {
            'renamed' { $fileOk = ($srcNow -eq '<missing>' -and $tgtNow -eq $h0); $heldAt = $tgt; $titleOk = $t1.Contains($NewName) }
            'replaced' { $fileOk = ($srcNow -eq '<missing>' -and $tgtNow -eq $h0); $heldAt = $tgt; $titleOk = $t1.Contains($NewName) }
            default { $fileOk = ($srcNow -eq $h0 -and $tgtNow -eq $ht0); $heldAt = $src; $titleOk = ($t1 -ceq $t0) }
        }
        $held = Held $heldAt
        $px = Shown-Pixels $id $w ($Out + '\' + $Case + '-after.png')
        $pxOk = $px -match ('^40x30 ' + $script:RgbPixels + '$')
        $v = V ($fileOk -and $held -eq 32 -and $titleOk -and $z1 -eq $z0 -and $pxOk)
        Row $Case 'RENAME' $v ("{0} -> {1}: source {2} -> {3}, target {4} -> {5} (expect {6}); viewer holds {7}: err {8} (32 = held); title '{9}' -> '{10}' ok {11}; zoom {12} -> {13}; Save As of the shown image: {14} ok {15}; boxes: {16}" -f (Esc $SrcName), (Esc $NewName), $h0, $srcNow, $ht0, $tgtNow, $Expect, (Esc ([IO.Path]::GetFileName($heldAt))), $held, (Tail $t0 60), (Tail $t1 60), $titleOk, $z0, $z1, $px, $pxOk, $boxes)
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- rename on WebDAV (103's davnorm.py: a server that folds names like macOS) -----------------
# 'dav-fold': the shown image stored as NFD "cafe<U+0301>.png", renamed to NFC "Caf<U+00E9>.png" - on that
# server the same entry, so the redirector answers "already exists" and 103's guard in PictView's
# RenameFileInternal goes through a temporary name (never reached before 111: error 32 first);
# 'dav-plain': an ordinary rename on WebDAV
function Start-Dav {
    $script:DavOk = $false; $script:DavWhy = 'WebDAV not started'
    if (@(Get-Service WebClient -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }).Count -eq 0) { $script:DavWhy = 'the WebClient service is not running'; return }
    NewDir $DavBack
    try {
        $script:Dav = Start-Process -FilePath $Py -ArgumentList @(('"{0}"' -f $DavPy), ('"{0}"' -f $DavBack), $DavPort, ('"{0}"' -f $DavLog)) -PassThru -WindowStyle Hidden
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 20 -and -not $script:DavOk) { Start-Sleep -Milliseconds 500; $script:DavOk = Test-Path -LiteralPath $DavA }
        if (-not $script:DavOk) { $script:DavWhy = "the WebDAV path $DavA did not answer" }
    }
    catch { $script:DavWhy = 'python could not be started: ' + $_.Exception.Message }
}
function Run-RenDav([string]$Case, [string]$SrcName, [string]$NewName) {
    if (-not (Want $Case)) { return }
    if ($null -eq $script:Dav -and -not $script:DavTried) { $script:DavTried = $true; Start-Dav }
    if (-not $script:DavOk) { Row $Case 'RENAME' 'NOT DRIVEN' $script:DavWhy; return }
    $back = $DavBack + '\' + $Case
    [void](Fx 'rgb.png' $back $SrcName)
    $h0 = Hash ($back + '\' + $SrcName)
    $ud = $DavA + '\' + $Case
    $id = 0; $before = Reports
    try {
        $id = Start-P $ud
        Focus-File $id ($ud + '\' + $SrcName)
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        $boxes = Rename-Shown $id $w $NewName
        Start-Sleep -Milliseconds 800
        $t1 = Title $w
        $names = @([IO.Directory]::GetFiles($LP + $back) | ForEach-Object { [IO.Path]::GetFileName($_) })
        $holders = @($names | Where-Object { (Hash ($back + '\' + $_)) -eq $h0 })
        $px = Shown-Pixels $id $w ($Out + '\' + $Case + '-after.png')
        $pxOk = $px -match ('^40x30 ' + $script:RgbPixels + '$')
        $ok = ($holders.Count -eq 1) -and ($holders[0] -ceq $NewName) -and ($names.Count -eq 1) -and $t1.Contains($NewName) -and $pxOk -and ($boxes -eq 'no box')
        Row $Case 'RENAME' (V $ok) ("on WebDAV {0} -> {1}: the server's folder holds [{2}], the image's content under [{3}] (want exactly the new name, nothing lost); title '{4}'; Save As of the shown image: {5} ok {6}; boxes: {7}" -f (Esc $SrcName), (Esc $NewName), (($names | ForEach-Object { Esc $_ }) -join ', '), (($holders | ForEach-Object { Esc $_ }) -join ', '), (Tail $t1 50), $px, $pxOk, $boxes)
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- review rows (B1, S1, S3, hard link, CMYK) ---------------------------------------------------
# waits for a new top window of class '#32770' (not one of $Known) and returns it
function Wait-Box([int]$Id, $Known, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $b = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($b) { Start-Sleep -Milliseconds 700; return $b }
        Start-Sleep -Milliseconds 150
    }
    return [IntPtr]::Zero
}
function Wait-Title([IntPtr]$Wv, [string]$Part, [double]$Seconds = 10) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ((Title $Wv).Contains($Part)) { return $true }; Start-Sleep -Milliseconds 200 }
    return $false
}
function Run-Nav([string]$Case) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    [void](Fx 'rgb.png' $d 'x.png'); [void](Fx 'gray.png' $d 'y.png')
    if ($Case -eq 'r-nav-ren') { [void](Fx 'rgb_fliph.png' $d 'z.png') }
    $left = $d; if ($Case -eq 'r-nav-del') { $left = $Unc + '\' + $Case }
    $hx = Hash ($d + '\x.png'); $hy = Hash ($d + '\y.png')
    $id = 0; $before = Reports
    try {
        $id = Start-P $left
        Focus-File $id ($left + '\x.png'); $a = Open-Viewer $id
        Focus-File $id ($left + '\x.png'); $b = Open-Viewer $id
        if ($a -eq [IntPtr]::Zero -or $b -eq [IntPtr]::Zero -or $a -eq $b) { Row $Case 'OPEN' 'FAIL' 'two viewers wanted'; return }
        $known = Get-Tops $id
        if ($Case -eq 'r-nav-del') { Post-Cmd $a 186 }
        else {
            Post-Cmd $a 185
            $dlg = Wait-Box $id $known
            if ($dlg -eq [IntPtr]::Zero) { Row $Case 'RUN' 'FAIL' 'no rename dialog'; return }
            [void][Drv098f]::SetText((Kid $dlg 2172 'Edit'), 'z.png', 5000); Click-Ok $dlg
            $known = @($known) + @($dlg)
        }
        $q = Wait-Box $id $known   # "permanently delete?" / "Confirm File Overwrite" (the pre-111 build: the rename's error)
        $qText = if ($q -ne [IntPtr]::Zero) { WinDesc $q } else { 'no question' }
        Post-Cmd $b 147            # CMD_FILE_NEXT: B goes on to y.png while A's question is open
        $moved = Wait-Title $b 'y.png'
        if ($q -ne [IntPtr]::Zero) { $yes = Buttons $q | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($yes) { Click $yes } else { Close-Win $q } }
        $ans = Answer $id 15 @(6, 2, 1) @($a, $b)
        foreach ($x in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 2172 'Edit') })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 500 }
        Start-Sleep -Milliseconds 1000
        $ta = Title $a; $tb = Title $b
        $heldY = Held ($d + '\y.png')
        if ($Case -eq 'r-nav-del') {
            $done = -not (Exists ($d + '\x.png'))
            $ok = $done -and $moved -and $tb.Contains('y.png') -and -not $tb.StartsWith('<Deleted>') -and $heldY -eq 32 -and (Hash ($d + '\y.png')) -eq $hy -and $ta.StartsWith('<Deleted>')
            Row $Case 'NAV' (V $ok) ("A deletes x.png, B moved to y.png during the question ({0}): x.png deleted {1}; B title '{2}'; B holds y.png: err {3}; A title '{4}'; question: {5}; boxes: {6}" -f $moved, $done, (Tail $tb 60), $heldY, (Tail $ta 40), (Tail $qText 90), (Msgs2 $ans))
        }
        else {
            $done = (-not (Exists ($d + '\x.png'))) -and (Hash ($d + '\z.png')) -eq $hx
            $ok = $done -and $moved -and $tb.Contains('y.png') -and -not $tb.Contains('z.png') -and $heldY -eq 32 -and (Hash ($d + '\y.png')) -eq $hy -and $ta.Contains('z.png')
            Row $Case 'NAV' (V $ok) ("A renames x.png onto z.png, B moved to y.png during the overwrite question ({0}): renamed {1}; B title '{2}'; B holds y.png: err {3}; A title '{4}'; question: {5}; boxes: {6}" -f $moved, $done, (Tail $tb 60), $heldY, (Tail $ta 40), (Tail $qText 90), (Msgs2 $ans))
        }
        Close-Viewer $id $b; Close-Viewer $id $a
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}
function Run-Cross {
    if (-not (Want 'r-cross')) { return }
    $d = $Root + '\r-cross'
    [void](Fx 'rgb.png' $d 'x.png'); [void](Fx 'gray.png' $d 'y.png'); [void](Fx 'rgb_fliph.png' $d 'z.png')
    $hy = Hash ($d + '\y.png'); $hz = Hash ($d + '\z.png')
    $u = $Unc + '\r-cross'
    $id = 0; $before = Reports
    try {
        $id = Start-P $u
        Focus-File $id ($u + '\x.png'); $a = Open-Viewer $id
        Focus-File $id ($u + '\x.png'); $b = Open-Viewer $id
        Focus-File $id ($u + '\y.png'); $c = Open-Viewer $id
        if (@($a, $b, $c | Where-Object { $_ -eq [IntPtr]::Zero }).Count -or $a -eq $b -or $b -eq $c -or $a -eq $c) { Row 'r-cross' 'OPEN' 'FAIL' 'three viewers wanted'; return }
        $known = Get-Tops $id
        Post-Cmd $a 186                                   # A: Delete x.png - "permanently delete?" stays open
        $qa = Wait-Box $id $known
        $known = @($known) + @($qa)
        Post-Cmd $b 147                                   # B goes on to y.png
        $moved = Wait-Title $b 'y.png'
        Post-Cmd $c 185                                   # C: Rename y.png onto z.png
        $dlg = Wait-Box $id $known
        if ($dlg -eq [IntPtr]::Zero) { Row 'r-cross' 'RUN' 'FAIL' 'no rename dialog in C'; return }
        [void][Drv098f]::SetText((Kid $dlg 2172 'Edit'), 'z.png', 5000); Click-Ok $dlg
        $known = @($known) + @($dlg)
        $qc = Wait-Box $id $known                         # "Confirm File Overwrite" (the build before: error 32)
        $qcText = if ($qc -ne [IntPtr]::Zero) { WinDesc $qc } else { 'no question' }
        if ($qa -ne [IntPtr]::Zero) { $y = Buttons $qa | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1; if ($y) { Click $y } }
        Start-Sleep -Milliseconds 2500                    # A's delete runs and A's take-back is sent
        if ($qc -ne [IntPtr]::Zero) { $n = Buttons $qc | Where-Object { @(7, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($n) { Click $n } else { Close-Win $qc } }
        $ans = Answer $id 15 @(2, 1) @($a, $b, $c)
        foreach ($x in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 2172 'Edit') })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 500 }
        Start-Sleep -Milliseconds 1500
        $ta = Title $a; $tb = Title $b; $tc = Title $c
        $xGone = -not (Exists ($d + '\x.png')); $heldY = Held ($d + '\y.png')
        $ok = $moved -and $xGone -and (Hash ($d + '\y.png')) -eq $hy -and (Hash ($d + '\z.png')) -eq $hz -and
              $tb.Contains('y.png') -and -not $tb.StartsWith('<Deleted>') -and $tc.Contains('y.png') -and $ta.StartsWith('<Deleted>') -and $heldY -eq 32
        $bPx = Shown-Pixels $id $b ($Out + '\r-cross-b.png') @($a, $c)
        $bOk = $bPx -match ('^40x30 ' + (PilOne ($d + '\y.png')).pixels + '$')
        Row 'r-cross' 'NAV' (V ($ok -and $bOk)) ("B moved to y.png {0}; x.png deleted {1}; y.png/z.png unchanged {2}/{3}; titles A '{4}', B '{5}', C '{6}'; y.png held again: err {7}; B shows y.png {8}; C's question: {9}; boxes: {10}" -f $moved, $xGone, ((Hash ($d + '\y.png')) -eq $hy), ((Hash ($d + '\z.png')) -eq $hz), (Tail $ta 25), (Tail $tb 50), (Tail $tc 50), $heldY, $bOk, (Tail $qcText 80), (Msgs2 $ans))
        Close-Viewer $id $c; Close-Viewer $id $b; Close-Viewer $id $a
    }
    catch { Row 'r-cross' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'r-cross' $id $before } }
}
function Run-Multi {
    if (-not (Want 'r-multi')) { return }
    $d = $Root + '\r-multi'
    $src = Fx 'multi.tif' $d
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'r-multi' 'OPEN' 'FAIL' 'no viewer'; return }
        $t1 = Title $w
        Post-Cmd $w 130   # CMD_NEXTPAGE
        Start-Sleep -Milliseconds 2500
        $t2 = Title $w
        $ok = $t1 -match ' x 16777216 colors \[1 of 2\]' -and $t2 -match ' x 2 colors \[2 of 2\]'
        Row 'r-multi' 'TITLE' (V $ok) ("page 1 (24-bit) '{0}'; page 2 (bilevel) '{1}'" -f (Tail $t1 55), (Tail $t2 55))
        Close-Viewer $id $w
    }
    catch { Row 'r-multi' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'r-multi' $id $before } }
}
function Run-Busy {
    if (-not (Want 'r-busy')) { return }
    $d = $Root + '\r-busy'
    $src = Fx 'big.bmp' $d
    $h0 = Hash $src
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src; $a = Open-Viewer $id 60
        Focus-File $id $src; $b = Open-Viewer $id 60
        if ($a -eq [IntPtr]::Zero -or $b -eq [IntPtr]::Zero -or $a -eq $b) { Row 'r-busy' 'OPEN' 'FAIL' 'two viewers wanted'; return }
        Start-Sleep -Milliseconds 3000
        # A first: its dialog, then its "replace?" question stays open; B starts its slow encode; then A's
        # Yes - A's fast BMP encode ends while B is still encoding, and A asks B to let the file go
        $known = Get-Tops $id
        $sa = Save-As $id $a $src @{ Type = 'Windows Bitmap'; Depth = '^24bit' }
        $qa = Wait-Box $id $known
        $sb = Save-As $id $b ($Out + '\busy-b.png') @{ Type = 'Portable Network'; Depth = '^256 colors' }   # B encodes now (slow)
        Start-Sleep -Milliseconds 300
        if ($qa -ne [IntPtr]::Zero) { $y = Buttons $qa | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1; if ($y) { Click $y } }
        $ans = Answer $id 120 @(6, 2, 1) @($a, $b)
        Cancel-Dialogs $id
        $fb = if (Exists ($Out + '\busy-b.png')) { PilOne ($Out + '\busy-b.png') } else { @{ size = '<none>' } }
        $h1 = Hash $src; $fs = PilOne $src
        $alive = Test-Alive $id
        $ok = $alive -and -not $ans.Fatal -and $fb.size -eq '6000x4000' -and $fs.size -eq '6000x4000' -and -not ($h1 -eq '<missing>')
        $how = if ($h1 -eq $h0) { 'unchanged - B was still encoding and kept the file (the refusal path)' } else { 'replaced - B had finished first (the refusal path not exercised)' }
        Row 'r-busy' 'BUSY' (V $ok) ("B saving (slow) while A saves over the shown file: alive {0}; B's file {1}; the shown file {2} ({3}); boxes: {4}" -f $alive, $fb.size, $how, $fs.size, (Msgs2 $ans))
        Close-Viewer $id $b; Close-Viewer $id $a
    }
    catch { Row 'r-busy' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'r-busy' $id $before } }
}
# review S1, deterministic: B's Print dialog holds B's image across a message loop; A saves over the
# file B shows: B must refuse to let it go (A: "in use", nothing lost) - before the busy flag B let it
# go and reopened the file under the open dialog (its image freed)
function Run-Print {
    if (-not (Want 'r-print')) { return }
    $d = $Root + '\r-print'
    $src = Fx 'rgb.png' $d 'shown.png'
    $h0 = Hash $src
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src; $a = Open-Viewer $id
        Focus-File $id $src; $b = Open-Viewer $id
        if ($a -eq [IntPtr]::Zero -or $b -eq [IntPtr]::Zero -or $a -eq $b) { Row 'r-print' 'OPEN' 'FAIL' 'two viewers wanted'; return }
        $known = Get-Tops $id
        Post-Cmd $b 154   # CMD_PRINT
        $pd = Wait-Box $id $known 20
        if ($pd -eq [IntPtr]::Zero) { Row 'r-print' 'PRINT' 'NOT DRIVEN' 'B opened no Print dialog (no default printer?)'; return }
        $x = Save-Simple $id $a $src @{ Type = 'Portable Network' } @($b, $pd)
        $h1 = Hash $src
        Post-Cmd $pd 2; Start-Sleep -Milliseconds 1000
        [void](Answer $id 5 @(2, 1) @($a, $b))
        $alive = Test-Alive $id
        $px = Shown-Pixels $id $b ($Out + '\r-print-b.png') @($a)
        $ok = $alive -and $h1 -eq $h0 -and $x.Boxes -match 'Unable to save' -and $px -match ('^40x30 ' + $script:RgbPixels + '$')
        Row 'r-print' 'PRINT' (V $ok) ("B's Print dialog open, A saves over the file: file {0} -> {1} (want unchanged); B afterwards shows {2}; alive {3}; boxes: {4}" -f $h0, $h1, $px, $alive, $x.Boxes)
        Close-Viewer $id $b; Close-Viewer $id $a
    }
    catch { Row 'r-print' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'r-print' $id $before } }
}
function Run-HardLink {
    if (-not (Want 'hl-del')) { return }
    $d = $Root + '\hl-del'
    [void](Fx 'rgb.png' $d 'a.png')
    $o = & cmd.exe /c ('mklink /H "{0}" "{1}"' -f ($d + '\b.png'), ($d + '\a.png')) 2>&1
    if (-not (Exists ($d + '\b.png'))) { Row 'hl-del' 'RUN' 'NOT DRIVEN' ('mklink /H failed: ' + "$o"); return }
    $u = $Unc + '\hl-del'
    $id = 0; $before = Reports
    try {
        $id = Start-P $u
        Focus-File $id ($u + '\a.png'); $a = Open-Viewer $id
        Focus-File $id ($u + '\b.png'); $b = Open-Viewer $id
        if ($a -eq [IntPtr]::Zero -or $b -eq [IntPtr]::Zero -or $a -eq $b) { Row 'hl-del' 'OPEN' 'FAIL' 'two viewers wanted'; return }
        $boxes = Delete-Shown $id $a @(6, 2, 1) @($b)
        Start-Sleep -Milliseconds 1000
        $tb = Title $b; $ta = Title $a
        $gone = -not (Exists ($d + '\a.png')); $heldB = Held ($d + '\b.png')
        $ok = $gone -and (Exists ($d + '\b.png')) -and $tb.Contains('b.png') -and -not $tb.StartsWith('<Deleted>') -and $heldB -eq 32 -and $ta.StartsWith('<Deleted>')
        Row 'hl-del' 'DELETE' (V $ok) ("A deletes a.png, B shows its hard link b.png: a gone {0}, b exists {1}; B title '{2}'; B holds b.png: err {3}; A title '{4}'; boxes: {5}" -f $gone, (Exists ($d + '\b.png')), (Tail $tb 50), $heldB, (Tail $ta 40), $boxes)
        Close-Viewer $id $b; Close-Viewer $id $a
    }
    catch { Row 'hl-del' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'hl-del' $id $before } }
}
function Run-InfoCmyk {
    if (-not (Want 'info-cmyk')) { return }
    $d = $Root + '\info-cmyk'
    $src = Fx 'cmyk.jpg' $d
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'info-cmyk' 'OPEN' 'FAIL' 'no viewer'; return }
        $known = Get-Tops $id
        Post-Cmd $w 114   # CMD_IMG_PROP
        $dlg = Wait-Box $id $known
        $txt = '<no dialog>'
        if ($dlg -ne [IntPtr]::Zero) { $c = Kid $dlg 2106; if ($c) { $txt = [Drv098f]::GetText($c, 5000) } else { $txt = '<no colors field>' }; Close-Win $dlg }
        $ok = $txt -eq 'CMYK' -and (Title $w) -match 'CMYK'
        Row 'info-cmyk' 'INFO' (V $ok) ("title '{0}'; Image Information, Colors: '{1}'" -f (Tail (Title $w) 50), (Esc $txt))
        Close-Viewer $id $w
    }
    catch { Row 'info-cmyk' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'info-cmyk' $id $before } }
}

# ---- delete (through \\localhost\C$: no recycle bin, the shell asks "permanently delete?") ------
function Run-Del([string]$Case, [int]$Answer) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = Fx 'rgb.png' $d 'shown.png'
    $ud = $Unc + '\' + $Case
    $id = 0; $before = Reports
    try {
        if (-not (Test-Path -LiteralPath "$ud\shown.png")) { Row $Case 'DELETE' 'NOT DRIVEN' ('the administrative share is not reachable: ' + $ud); return }
        $id = Start-P $ud
        Focus-File $id ($ud + '\shown.png')
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        $boxes = Delete-Shown $id $w @($Answer, 2, 1)
        Start-Sleep -Milliseconds 800
        $t1 = Title $w; $gone = -not (Exists $src)
        $px = Shown-Pixels $id $w ($Out + '\' + $Case + '-after.png')
        $pxOk = $px -match ('^40x30 ' + $script:RgbPixels + '$')
        $inUse = $boxes -match 'shell operation window'
        if ($Answer -eq 6) {
            $v = V ($gone -and $t1.StartsWith('<Deleted>') -and $pxOk -and -not $inUse)
            Row $Case 'DELETE' $v ("Delete, 'permanently delete?' Yes: file gone {0}; title '{1}'; the image still saveable: {2} ok {3}; boxes: {4}" -f $gone, (Tail $t1 60), $px, $pxOk, $boxes)
        }
        else {
            $held = Held $src
            $v = V ((-not $gone) -and $held -eq 32 -and $pxOk -and -not $inUse)
            Row $Case 'DELETE' $v ("Delete, 'permanently delete?' No: file kept {0}; held again: err {1}; title '{2}'; saveable: {3} ok {4}; boxes: {5}" -f (-not $gone), $held, (Tail $t1 60), $px, $pxOk, $boxes)
        }
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- two windows on one file -------------------------------------------------------------------
function Run-Two([string]$Case) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = Fx 'rgb.png' $d 'shown.png'
    $left = $d; $file = $src
    if ($Case -eq 'two-del') { $left = $Unc + '\' + $Case; $file = $left + '\shown.png' }
    $id = 0; $before = Reports
    try {
        $id = Start-P $left
        Focus-File $id $file
        $a = Open-Viewer $id
        Focus-File $id $file
        $b = Open-Viewer $id
        if ($a -eq [IntPtr]::Zero -or $b -eq [IntPtr]::Zero -or $a -eq $b) { Row $Case 'OPEN' 'FAIL' ("two viewers wanted: {0} / {1}" -f $a, $b); return }
        $tb0 = Title $b
        switch ($Case) {
            'two-save' {
                Post-Cmd $b 120; Start-Sleep -Milliseconds 600   # window B mirrored: its own view must stay
                $x = Save-Simple $id $a $src @{ Type = 'Portable Network'; Rot = '^90' } @($b)
                Start-Sleep -Milliseconds 1500
                $f = PilOne $src; $ta = Title $a; $tb = Title $b
                $pa = Shown-Pixels $id $a ($Out + '\two-save-a.png') @($b)
                $pb = Shown-Pixels $id $b ($Out + '\two-save-b.png') @($a)
                $okA = $pa -match ('^30x40 ' + (PilOne $src).pixels + '$')
                $okB = $pb -match ('^30x40 ' + $script:RotFlipPixels + '$')
                $v = V ($f.size -eq '30x40' -and (Dims $ta) -eq '30x40' -and (Dims $tb) -eq '30x40' -and $x.Boxes -match 'saved successfully' -and $okA -and $okB)
                Row $Case 'SAVE' $v ("window A saves over the file both show, rotated 90: file {0}; A title {1}; B title {2} -> {3}; A shows the file {4}; B (mirrored before) shows it mirrored {5} ({6}); boxes: {7}" -f $f.size, (Dims $ta), (Dims $tb0), (Dims $tb), $okA, $okB, $pb, $x.Boxes)
            }
            'two-ren' {
                $boxes = Rename-Shown $id $a 'renamed.png' @(6, 2, 1) @($b)
                Start-Sleep -Milliseconds 800
                $tb = Title $b; $ta = Title $a
                $ok = (-not (Exists $src)) -and (Exists ($d + '\renamed.png')) -and $ta.Contains('renamed.png') -and $tb.Contains('renamed.png') -and (Held ($d + '\renamed.png')) -eq 32
                Row $Case 'RENAME' (V $ok) ("window A renames the file both show: renamed {0}; A title '{1}'; B title '{2}' -> '{3}'; held {4}; boxes: {5}" -f (Exists ($d + '\renamed.png')), (Tail $ta 50), (Tail $tb0 50), (Tail $tb 50), (Held ($d + '\renamed.png')), $boxes)
            }
            'two-del' {
                $boxes = Delete-Shown $id $a @(6, 2, 1) @($b)
                Start-Sleep -Milliseconds 800
                $tb = Title $b; $ta = Title $a; $gone = -not (Exists $src)
                $ok = $gone -and $ta.StartsWith('<Deleted>') -and $tb.StartsWith('<Deleted>') -and -not ($boxes -match 'shell operation window')
                Row $Case 'DELETE' (V $ok) ("window A deletes the file both show: gone {0}; A title '{1}'; B title '{2}'; boxes: {3}" -f $gone, (Tail $ta 50), (Tail $tb 50), $boxes)
            }
        }
        Close-Viewer $id $b; Close-Viewer $id $a
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- the source's real format: alpha question, depths, title ------------------------------------
function Run-Format([string]$Case, [string]$Fixture, [string]$Kind, $A) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = Fx $Fixture $d
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        switch ($Kind) {
            'alpha' {
                $s = Save-As $id $w ($d + '\x.bmp') @{ Type = 'Windows Bitmap' } -Inspect
                $asked = ($s.Pre -join ' ') -match 'alpha channel'
                $res = [pscustomobject]@{ Step = 'ALPHA'; Ok = ($s.Ok -and $asked -eq $A.Asked); Text = ("alpha question asked {0} (want {1}); dialog opened {2}; {3}" -f $asked, $A.Asked, $s.Ok, $s.Note) }
            }
            'default' {
                $s = Save-As $id $w ($d + '\x.out') @{ Type = $A.Type } -Inspect
                $t = Title $w
                $ok = $s.Ok -and ($s.DepthSel -match $A.Sel) -and ($t -match $A.TitleRx)
                $res = [pscustomobject]@{ Step = 'DEPTH'; Ok = $ok; Text = ("type /{0}/: default depth '{1}' (want /{2}/), offered [{3}]; title wants /{4}/; questions before the dialog: {5}" -f $A.Type, $s.DepthSel, $A.Sel, ($s.Depths -join '/'), $A.TitleRx, $s.Pre.Count) }
            }
            'bilevel' {
                $ins = Save-As $id $w ($d + '\x.tif') @{ Type = '^TIFF' } -Inspect
                $offer = ('TIFF: depths [{0}] default {1}; compressions [{2}]' -f ($ins.Depths -join '/'), $ins.DepthSel, ($ins.Comps -join '/'))
                $full = $d + '\' + $A.Out
                $x = Save-Simple $id $w $full $A.O
                if (-not (Exists $full)) { $res = [pscustomobject]@{ Step = 'BILEVEL'; Ok = $false; Text = ("{0}; save: no file ({1}; {2})" -f $offer, $x.Save.Note, $x.Boxes) } }
                else {
                    $f = PilOne $full; $s0 = PilOne $src
                    $ok = ($ins.DepthSel -match '^2 colors') -and (($ins.Comps -join '/') -match 'CCITT G4') -and ($f.bits -eq $A.Bits) -and ((-not $A.Comp) -or $f.comp -eq $A.Comp) -and ($f.pixels -eq $s0.pixels)
                    $res = [pscustomobject]@{ Step = 'BILEVEL'; Ok = $ok; Text = ("{0}; saved {1}: mode {2} bits {3} comp {4} (want bits {5} comp {6}); pixels {7} = source {8}; boxes: {9}" -f $offer, $A.Out, $f.mode, $f.bits, $f.comp, $A.Bits, $A.Comp, $f.pixels, $s0.pixels, $x.Boxes) }
                }
            }
        }
        Row $Case $res.Step (V $res.Ok) ("{0}: title '{1}'; {2}" -f $Fixture, (Tail (Title $w) 60), $res.Text)
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- comments ------------------------------------------------------------------------------------
function Run-Cmt([string]$Case, [string]$TypeRx, [string]$Ext, [string]$Comment, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = Fx 'rgb.png' $d 'src.png'
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        $full = $d + '\cmt.' + $Ext
        $o = @{ Type = $TypeRx; Comment = $Comment }; if ($Ext -eq 'tif') { $o.Comp = '^Default' }
        $x = Save-Simple $id $w $full $o
        if (-not (Exists $full)) { Row $Case 'COMMENT' 'FAIL' ("no file: {0}; {1}" -f $x.Save.Note, $x.Boxes) }
        else { $f = PilOne $full; $j = & $Judge $f; Row $Case 'COMMENT' (V $j.Ok) $j.Text }
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- view kept after a Save As over the shown image ----------------------------------------------
function Run-View([string]$Case, [bool]$Fail) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = Fx 'rgb.png' $d 'shown.png'
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        Post-Cmd $w 102; Start-Sleep -Milliseconds 600   # zoom in
        Post-Cmd $w 120; Start-Sleep -Milliseconds 600   # mirror horizontally
        $z0 = Zoom (Title $w); $h0 = Hash $src
        $lock = $null
        if ($Fail) { $lock = [IO.File]::Open($LP + $src, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read) }
        try { $x = Save-Simple $id $w $src @{ Type = 'Portable Network' } }
        finally { if ($lock) { $lock.Dispose() } }
        Start-Sleep -Milliseconds 1500
        $z1 = Zoom (Title $w); $h1 = Hash $src
        $px = Shown-Pixels $id $w ($Out + '\' + $Case + '-after.png')
        if ($Fail) {
            # the replace failed: file unchanged; the viewer still mirrored and zoomed
            $ok = ($h1 -eq $h0) -and ($z1 -eq $z0) -and ($px -match ('^40x30 ' + $script:FlipPixels + '$')) -and ($x.Boxes -match 'Unable to save')
            Row $Case 'VIEW' (V $ok) ("Save As over the shown image while another program holds it: file {0} -> {1}; zoom {2} -> {3}; a following Save As: {4} (mirrored = {5}); boxes: {6}" -f $h0, $h1, $z0, $z1, $px, $script:FlipPixels, $x.Boxes)
        }
        else {
            # saved: the file holds the mirrored image; the window shows the file (not mirrored twice) at the same zoom
            $f = PilOne $src
            $ok = ($f.pixels -eq $script:FlipPixels) -and ($z1 -eq $z0) -and ($px -match ('^40x30 ' + $script:FlipPixels + '$')) -and ($x.Boxes -match 'saved successfully')
            Row $Case 'VIEW' (V $ok) ("Save As over the shown image (mirrored, zoomed): file pixels {0} (mirrored = {1}); zoom {2} -> {3}; a following Save As: {4}; boxes: {5}" -f $f.pixels, $script:FlipPixels, $z0, $z1, $px, $x.Boxes)
        }
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- wallpaper (dry run only) --------------------------------------------------------------------
function Desk-State {
    $k = 'HKCU:\Control Panel\Desktop'
    $p = Get-ItemProperty -LiteralPath $k
    $vals = foreach ($n in 'Wallpaper', 'WallpaperStyle', 'TileWallpaper', 'PrevWallpaper', 'PrevWallpaperStyle', 'PrevTileWallpaper') { '{0}={1}' -f $n, $(if ($p.PSObject.Properties[$n]) { $p.$n } else { '<none>' }) }
    return (($vals -join ';') + ';SPI=' + [Drv111]::GetWallpaper())
}
function Run-Wallpaper {
    $cases = @(@('wp-center', 175), @('wp-tile', 176), @('wp-stretch', 177), @('wp-restore', 178), @('wp-none', 179))
    $todo = @($cases | Where-Object { Want $_[0] })
    if (-not $todo.Count) { return }
    if ($NoWallpaper) { foreach ($c in $todo) { Row $c[0] 'WALL' 'NOT DRIVEN' 'the build has no dry-run seam: its wallpaper commands write HKCU\Control Panel\Desktop and call SystemParametersInfo(SPI_SETDESKWALLPAPER, NULL) - never on this session' }; return }
    # the seam must be in the binary before any command is sent
    $spl = Join-Path (Split-Path $Exe) 'plugins\pictview\pictview.spl'
    $bin = [IO.File]::ReadAllBytes($spl)
    $needle = [Text.Encoding]::ASCII.GetBytes('TC_PICTVIEW_WALLPAPER_DRYRUN')
    $nw = [Text.Encoding]::Unicode.GetBytes('TC_PICTVIEW_WALLPAPER_DRYRUN')
    $found = $false
    foreach ($nd in @($needle, $nw)) { for ($i = 0; $i -le $bin.Length - $nd.Length -and -not $found; $i++) { if ($bin[$i] -eq $nd[0]) { $j = 1; while ($j -lt $nd.Length -and $bin[$i + $j] -eq $nd[$j]) { $j++ }; if ($j -eq $nd.Length) { $found = $true } } } }
    if (-not $found) { foreach ($c in $todo) { Row $c[0] 'WALL' 'NOT DRIVEN' 'the dry-run seam name is not in pictview.spl - refused to send a wallpaper command' }; return }
    $hadFile = [IO.File]::Exists($WpFile); $saved = $null
    if ($hadFile) { $saved = [IO.File]::ReadAllBytes($WpFile) }
    $d = $Root + '\wp'
    $src = Fx 'rgb.png' $d 'wall.png'
    $env:TC_PICTVIEW_WALLPAPER_DRYRUN = $WpLog
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'wp' 'OPEN' 'FAIL' 'no viewer'; return }
        $real = Desk-State
        foreach ($c in $todo) {
            if ([IO.File]::Exists($WpLog)) { [IO.File]::Delete($WpLog) }
            $t0 = $null; if ([IO.File]::Exists($WpFile)) { $t0 = [IO.File]::GetLastWriteTimeUtc($WpFile) }
            Post-Cmd $w $c[1]
            Start-Sleep -Milliseconds 2500
            $ans = Answer $id 6 @(1, 6) @($w)
            $log = @(); if ([IO.File]::Exists($WpLog)) { $log = @([IO.File]::ReadAllLines($WpLog, (New-Object Text.UTF8Encoding($false)))) }
            $logTxt = ($log -join ' ; ')
            $cur = (Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop')
            switch ($c[0]) {
                { $_ -in 'wp-center', 'wp-tile', 'wp-stretch' } {
                    $style = @{ 'wp-center' = '0'; 'wp-tile' = '0'; 'wp-stretch' = '2' }[$c[0]]
                    $tile = @{ 'wp-center' = '0'; 'wp-tile' = '1'; 'wp-stretch' = '0' }[$c[0]]
                    $f = $null; if ([IO.File]::Exists($WpFile)) { $f = PilOne $WpFile }
                    $fresh = $t0 -eq $null -or ([IO.File]::GetLastWriteTimeUtc($WpFile) -gt $t0)
                    $want = @("SET WallpaperStyle=$style", "SET TileWallpaper=$tile", ('SPI_SETDESKWALLPAPER ' + $WpFile))
                    $okLog = @($want | Where-Object { $log -notcontains $_ }).Count -eq 0
                    $prevOk = $true
                    if ($cur.Wallpaper -and ([IO.Path]::GetFileName($cur.Wallpaper) -ine 'PictView_Wallpaper.bmp')) {
                        # the backup only after the SPI call took effect (review S2)
                        $iSpi = [array]::IndexOf($log, ('SPI_SETDESKWALLPAPER ' + $WpFile)); $iPrev = [array]::IndexOf($log, ('SET PrevWallpaper=' + $cur.Wallpaper))
                        $prevOk = $iPrev -gt $iSpi -and $iSpi -ge 0
                    }
                    $ok = $f -and $f.fmt -eq 'BMP' -and $f.bits -eq '24' -and $f.size -eq '40x30' -and $f.pixels -eq $script:RgbPixels -and $fresh -and $okLog -and $prevOk -and -not ($logTxt -match 'SPI_SETDESKWALLPAPER <NULL>')
                    $fdesc = if ($f) { '{0} {1}-bit {2} pixels ok {3}' -f $f.fmt, $f.bits, $f.size, ($f.pixels -eq $script:RgbPixels) } else { '<no file>' }
                    Row $c[0] 'WALL' (V $ok) ("command {0}: file {1}, rewritten {2}; log has {3}: {4}; previous wallpaper saved as Prev* {5}; log lines {6}; boxes: {7}" -f $c[1], $fdesc, $fresh, ($want -join ' + ').Replace($WpFile, '<wallpaper file>'), $okLog, $prevOk, $log.Count, (Msgs2 $ans))
                }
                'wp-restore' {
                    $prev = [string]$cur.PrevWallpaper
                    if ($prev -eq '') {
                        # nothing backed up (review S2): nothing may happen - it removed the wallpaper before
                        $ok = $log.Count -eq 0
                        Row $c[0] 'WALL' (V $ok) ("command 178 with NO backup (PrevWallpaper empty): log lines {0} (want 0: no registry write, no SPI call) {1}; boxes: {2}" -f $log.Count, (Esc $logTxt.Replace([string]$cur.Wallpaper, '<current>')), (Msgs2 $ans))
                    }
                    else {
                        $ok = ($log -contains ('SPI_SETDESKWALLPAPER ' + $prev)) -and ($log -contains ('SET PrevWallpaper=' + $cur.Wallpaper)) -and -not ($logTxt -match '<NULL>')
                        Row $c[0] 'WALL' (V $ok) ("command 178 with a backup: SPI path = the backup {0}; the current one saved as the backup {1}; log lines {2}; boxes: {3}" -f ($log -contains ('SPI_SETDESKWALLPAPER ' + $prev)), ($log -contains ('SET PrevWallpaper=' + $cur.Wallpaper)), $log.Count, (Msgs2 $ans))
                    }
                }
                'wp-none' {
                    $curW = [string]$cur.Wallpaper
                    $worth = $curW -ne '' -and ([IO.Path]::GetFileName($curW) -ine 'PictView_Wallpaper.bmp')
                    $spi = ($log.Count -gt 0) -and ($log[0] -eq 'SPI_SETDESKWALLPAPER ')   # the call first, the backup after it
                    $bk = $log -contains ('SET PrevWallpaper=' + $curW)
                    $ok = $spi -and ($bk -eq $worth) -and -not ($logTxt -match '<NULL>')
                    Row $c[0] 'WALL' (V $ok) ("command 179: first SPI with an empty path {0}; the current wallpaper backed up {1} (want {2}: not empty and not ours); log lines {3}; boxes: {4}" -f $spi, $bk, $worth, $log.Count, (Msgs2 $ans))
                }
            }
            if ((Desk-State) -ne $real) { Row $c[0] 'REAL' 'FAIL' 'THE REAL WALLPAPER SETTINGS CHANGED' }
        }
        Close-Viewer $id $w
    }
    catch { Row 'wp' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-P 'wp' $id $before }
        Remove-Item Env:\TC_PICTVIEW_WALLPAPER_DRYRUN -ErrorAction SilentlyContinue
        if ($hadFile) { [IO.File]::WriteAllBytes($WpFile, $saved) } elseif ([IO.File]::Exists($WpFile)) { [IO.File]::Delete($WpFile) }
        foreach ($t in @([IO.Directory]::GetFiles($WpDir, 'pv*.tmp'))) { Out ('wallpaper: a temporary file was left: ' + $t) }
    }
}

# ---- main ------------------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc111_backup.reg'
$existed = Backup-Reg $backup
$desk0 = Desk-State
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Out
    Make-Fixtures
    $script:RgbPixels = (PilOne ($Fix + '\rgb.png')).pixels
    $script:FlipPixels = (PilOne ($Fix + '\rgb_fliph.png')).pixels
    $script:RotFlipPixels = (PilOne ($Fix + '\rgb_rot90_fliph.png')).pixels
    Set-Config
    Out ("shown_probe (feature 111)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; backup SHA-256 {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '-' }))
    Out ''
    Run-Ren 'ren-ascii' 'shown.png' 'renamed.png' 'renamed' $null $null
    Run-Ren 'ren-cyr' 'shown.png' ($Cyr + '.png') 'renamed' $null $null
    Run-Ren 'ren-cjk' ($Cjk + '.png') ($Cjk2 + '.png') 'renamed' $null $null
    Run-Ren 'ren-locked' 'shown.png' 'renamed.png' 'kept' { return [IO.File]::Open($LP + $Root + '\ren-locked\shown.png', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read) } { param($fs) if ($fs) { $fs.Dispose() } }
    Run-Ren 'ren-tgtlocked' 'shown.png' 'exist.png' 'kept' { PutText ($Root + '\ren-tgtlocked\exist.png') 'EXISTING'; $script:TgtHash = Hash ($Root + '\ren-tgtlocked\exist.png'); return [IO.File]::Open($LP + $Root + '\ren-tgtlocked\exist.png', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read) } { param($fs) if ($fs) { $fs.Dispose() } }
    Run-Ren 'ren-tgtro' 'shown.png' 'exist.png' 'replaced' { PutText ($Root + '\ren-tgtro\exist.png') 'EXISTING'; [IO.File]::SetAttributes($LP + $Root + '\ren-tgtro\exist.png', 'ReadOnly'); return $null } $null
    Run-RenDav 'dav-fold' $Nfd $Nfc
    Run-RenDav 'dav-plain' 'shown.png' 'renamed.png'
    Run-Nav 'r-nav-del'
    Run-Nav 'r-nav-ren'
    Run-Cross
    Run-Multi
    Run-Busy
    Run-Print
    Run-HardLink
    Run-InfoCmyk
    Run-Del 'del-yes' 6
    Run-Del 'del-no' 2
    Run-Two 'two-save'
    Run-Two 'two-ren'
    Run-Two 'two-del'
    Run-Format 'alpha-opq-png' 'rgba_opaque.png' 'alpha' @{ Asked = $false }
    Run-Format 'alpha-opq-tif' 'rgba_opaque.tif' 'alpha' @{ Asked = $false }
    Run-Format 'alpha-opq-ico' 'icon_opaque.ico' 'alpha' @{ Asked = $false }
    Run-Format 'alpha-real-png' 'rgba_alpha.png' 'alpha' @{ Asked = $true }
    Run-Format 'alpha-real-tif' 'rgba_alpha.tif' 'alpha' @{ Asked = $true }
    Run-Format 'depth-bl-png' 'bilevel.png' 'bilevel' @{ Out = 'bl.tif'; O = @{ Type = '^TIFF'; Comp = 'CCITT G4'; Depth = '^2 colors' }; Comp = '4'; Bits = '1' }
    Run-Format 'depth-bl-tif' 'bilevel_g4.tif' 'bilevel' @{ Out = 'bl.png'; O = @{ Type = 'Portable Network'; Depth = '^2 colors' }; Comp = ''; Bits = '1' }
    Run-Format 'depth-gray' 'gray.png' 'default' @{ Type = 'Windows Bitmap'; Sel = '^256 gray'; TitleRx = ' x 256 colors - ' }
    Run-Format 'depth-pal16' 'pal16.png' 'default' @{ Type = 'Windows Bitmap'; Sel = '^16 colors'; TitleRx = ' x 16 colors - ' }
    Run-Format 'depth-rgb' 'rgb.png' 'default' @{ Type = 'Windows Bitmap'; Sel = '^24bit'; TitleRx = ' x 16777216 colors - ' }
    Run-Format 'depth-bl-title' 'bilevel.png' 'default' @{ Type = 'Windows Bitmap'; Sel = '^2 colors'; TitleRx = ' x 2 colors - ' }
    $hu = U8Hex $CommentU; $ha = U8Hex $CommentA
    Run-Cmt 'cmt-tif-u8' '^TIFF' 'tif' $CommentU { param($f) [pscustomobject]@{ Ok = ($f.t270 -eq ($hu + '00') -and $f.xmpdesc -eq $hu); Text = ("tag 270 {0} (want UTF-8 + NUL {1}00); XMP dc:description {2} (want {1}); Pillow reads tag 270 as '{3}'" -f $f.t270, $hu, $f.xmpdesc, $f.pil270) } }
    Run-Cmt 'cmt-tif-ascii' '^TIFF' 'tif' $CommentA { param($f) [pscustomobject]@{ Ok = ($f.t270 -eq ($ha + '00') -and $f.xmpdesc -eq '-'); Text = ("tag 270 {0} (want ASCII + NUL); XMP dc:description {1} (want none); Pillow: '{2}'" -f $f.t270, $f.xmpdesc, $f.pil270) } }
    Run-Cmt 'cmt-jpg-u8' '^JPEG' 'jpg' $CommentU { param($f) [pscustomobject]@{ Ok = ($f.com -eq $hu); Text = ("JPEG COM {0} (want exactly the UTF-8 bytes {1}, no NUL)" -f $f.com, $hu) } }
    Run-Cmt 'cmt-jpg-ascii' '^JPEG' 'jpg' $CommentA { param($f) [pscustomobject]@{ Ok = ($f.com -eq $ha); Text = ("JPEG COM {0} (want {1}, no NUL)" -f $f.com, $ha) } }
    Run-Cmt 'cmt-gif' 'GIF' 'gif' $CommentU { param($f) [pscustomobject]@{ Ok = ($f.com -eq $hu); Text = ("GIF comment {0} (want {1}; unchanged by 111)" -f $f.com, $hu) } }
    Run-View 'view-fail' $true
    Run-View 'view-ok' $false
    Run-Wallpaper
    if (-not $Only) {
        foreach ($nd in @('Delete into the Recycle Bin (a local file, no Shift): the same code path as the \\localhost rows (only FOF_ALLOWUNDO differs) - not driven, it would put probe files into the user''s Recycle Bin',
                          'the real SystemParametersInfo(SPI_SETDESKWALLPAPER) and the HKCU\Control Panel\Desktop writes: never driven (the hidden desktop shares the user''s wallpaper); code review + the dry-run log')) { Row 'nd' 'ROUTE' 'NOT DRIVEN' $nd }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    if ($script:Dav -and -not $script:Dav.HasExited) { Stop-Process -Id $script:Dav.Id -Force; Start-Sleep -Milliseconds 500 }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    $desk1 = Desk-State
    Row 'wp-real' 'REAL' (V ($desk1 -eq $desk0)) ("HKCU\Control Panel\Desktop wallpaper values and SPI_GETDESKWALLPAPER unchanged by the run: {0}" -f ($desk1 -eq $desk0))
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
