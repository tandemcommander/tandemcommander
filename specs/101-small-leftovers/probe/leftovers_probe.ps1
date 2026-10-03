<#
.SYNOPSIS
    Feature 101 probe: the small leftovers of 097-100, on the build of this feature
    (-Expect fixed) and on the build before it (-Expect before, Debug_x64_pre101).

.DESCRIPTION
    Fixtures under %TEMP%\tc101_lo (removed at the end; junctions and the icacls deny
    are removed first, the SUBST drive in the finally block).

    CLIP  Ctrl+Shift+V path paste (CM_CLIPPASTE 775 with text on the clipboard) - only
          when this session can open the clipboard (098/099 could not: then NOT DRIVEN):
            p600   an existing folder, path of 600 bytes       fixed: lands there    before: "too long"
            p5000  an existing folder, path of 5,000 bytes     fixed: lands there    before: "too long"
            pnx    a 600-byte path that does not exist         fixed: the usual error, not "too long"
            pcjk   a short existing folder with U+4E2D         both: lands there
    UNC   "copy UNC name" on a SUBST drive (subst X: <folder>, no administrator rights):
            unc1 panel (CM_CLIPCOPYUNCNAME 712), X:\<300 bytes>\f.txt, SUBST target of
                 about 240 bytes: target + rest > 520 bytes
                 fixed: "The path specified is too long."   before: "cannot be converted to UNC"
            unc2 panel, X:\<600 bytes>\f.txt (over the 520-byte buffers)
                 fixed: "too long"                          before: no window (silent)
            unc3 the Find window (Alt+F7, Find Now f.txt in X:\<600 bytes>, CM_FIND_SELECTALL,
                 CM_FIND_CLIPCOPYUNCNAME 2286): fixed: "too long", owned by the Find window;
                 before: no window (silent - the old clipboard content stayed)
            unc4 control: panel, X:\short\f.txt: both builds the same (no share here:
                 "cannot be converted to UNC"; never "too long")
            unc5 control: the Find window on X:\short\f.txt (the Find route can be driven)
    MSG   Alt+F5 into a new ZIP with "Delete files from disk after packing" (512):
            unr   selection B, B\U cannot be listed (icacls deny RD for the current user)
                  fixed: "...a directory in the selection cannot be read, so it cannot be
                  checked for links..."             before: the link text ("link to directory")
            deep  selection A, A holds 1,005 nested folders "d"
                  fixed: the scan says "nested too deeply (more than 1000 levels), so it cannot
                  be checked" naming the folder shortened with "..." (review NIT 1), then only the
                  enumeration's real length refusal ("with full path is too long", level ~129):
                  2 message boxes, no 14184 box for the same skipped subtree (review NIT 2)
                  before: the link text + 2 x "with full path is too long": 3 message boxes
            link  control: selection B, B\J a junction -> X: the link text on both builds
            unrcs / deepcs  the same in Czech (Configuration\Language = czech.slg):
                  fixed: the Czech texts of 14182 / 14183 / 14184   before: the Czech link text
          every MSG case: the files are not deleted (B\b.txt, A\a.txt, X\x.txt stay)
    Not driven, by design: the tray tip (the hidden desktop has no notification area, and
    the user's tray is not touched - saltests covers the conversion and the cut), the share
    look-up (no share without administrator rights - saltests covers the matching), the
    directory-line drag image (no drag on a hidden desktop - read only).

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another
    tandemcommander.exe runs. HKCU\Software\Tandem Commander exported before, restored and
    SHA-256-verified after. Pure ASCII. Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
function WantGroup([string]$g) { return (-not $Only) -or (@($Only | Where-Object { $_ -like ($g + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv101' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Drv101
{
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
}
'@
}
$Root = $TempRoot + '\tc101_lo'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$Me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$script:Links = New-Object System.Collections.ArrayList
$script:Denied = New-Object System.Collections.ArrayList
$script:Subst = $null
$Fixed = ($Expect -eq 'fixed')

function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function Remove-Fixtures {
    foreach ($d in @($script:Denied)) { [void](Cmd ("icacls `"{0}`" /remove:d `"{1}`"" -f $d, $Me)) }
    $script:Denied.Clear()
    foreach ($l in @($script:Links)) {
        if ([IO.Directory]::Exists($l)) { [void](Cmd ("rmdir `"{0}`"" -f $l)) }
        if ([IO.Directory]::Exists($l)) { Out ('Link: COULD NOT REMOVE ' + $l) }
    }
    $script:Links.Clear()
}
# the whole text of a window and its children, unescaped and uncut (for matching texts). Line
# breaks are REMOVED, not turned into spaces: when a message holds a long unbreakable path, the
# message box inserts hard breaks at character positions into the whole text (msgbox.cpp
# DuplicateStrAndInsertEOLs - "wil\nl not be deleted"), and removing them restores the text
function RawText([IntPtr]$H) {
    $parts = @([Drv098f]::Txt($H))
    foreach ($c in [Drv098f]::Kids($H)) { $t = [Drv098f]::Txt($c); if ($t -and [Drv098f]::IsWindowVisible($c)) { $parts += $t } }
    return (($parts -join ' | ').Replace("`r", '').Replace("`n", ''))
}
# Serve of the 098 library, recording the raw text and the owner of every window it answers
function Serve101([int]$Id, [double]$Seconds = 30, [int[]]$Want = @(1, 6)) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Raw = New-Object System.Collections.ArrayList; Owners = New-Object System.Collections.ArrayList; Boxes = New-Object System.Collections.ArrayList; Fatal = $null; Died = $false; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { $r.Died = $true; break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $script:Keep -notcontains $_ })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 1.5) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            [void]$r.Messages.Add($d); [void]$r.Raw.Add((RawText $h)); [void]$r.Owners.Add([Drv101]::GetWindow($h, 4))
            # a message box: no edit / combo box child (the Pack and Create New Archive dialogs have them)
            if (-not @([Drv098f]::Kids($h) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) }).Count) { [void]$r.Boxes.Add((RawText $h)) }
            $pick = $btn | Where-Object { $Want -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
$script:Keep = @()
function Short([string]$s, [int]$n = 170) { if ($s.Length -le $n) { return (Esc $s) }; return ((Esc $s.Substring(0, $n)) + '...') }
function MsgList($r) { if ($r.Raw.Count) { return ((@($r.Raw) | ForEach-Object { Short $_ }) -join ' || ') } else { return 'no window' } }
function Has($r, [string]$Text) { return @($r.Raw | Where-Object { $_.Contains($Text) }).Count }
function Settle([int]$Id, [int]$Ms = 500) { $m = Get-Main $Id; [void][Drv098f]::Send($m, 0, 0, 0, 20000); Start-Sleep -Milliseconds $Ms; [void][Drv098f]::Send($m, 0, 0, 0, 20000) }
# a directory of exactly $Bytes UTF-8 bytes below $Base (components of at most 150 'q')
function LongDir([string]$Base, [int]$Bytes, [string]$Ch = 'q') {
    $p = $Base
    while ((U8Len $p) -lt $Bytes) { $n = [Math]::Min(150, $Bytes - (U8Len $p) - 1); if ($n -lt 1) { $p += $Ch; continue }; $p += '\' + ($Ch * $n) }
    return $p
}

# ---- texts -------------------------------------------------------------------
$Cz = @{
    Link = 'proto' + (S 0x17E) + 'e ozna' + (S 0x10D) + 'en' + (S 0xED) + ' obsahuje odkaz na adres' + (S 0xE1, 0x159)   # not 'neobsahuje' of the new texts
    Unr = 'nelze p' + (S 0x159) + 'e' + (S 0x10D, 0xED) + 'st, a proto nelze ov' + (S 0x11B, 0x159) + 'it'
    DeepScan = 'je vno' + (S 0x159) + 'en p' + (S 0x159, 0xED) + 'li' + (S 0x161) + ' hluboko (v' + (S 0xED) + 'ce ne' + (S 0x17E) + ' 1000 ' + (S 0xFA) + 'rovn' + (S 0xED) + '), a proto'
    DeepWalk = 'je vno' + (S 0x159) + 'en p' + (S 0x159, 0xED) + 'li' + (S 0x161) + ' hluboko (v' + (S 0xED) + 'ce ne' + (S 0x17E) + ' 1000 ' + (S 0xFA) + 'rovn' + (S 0xED) + '), ne' + (S 0x17E) + ' aby'
    TooLongName = 's plnou cestou je p' + (S 0x159, 0xED) + 'li' + (S 0x161) + ' dlouh' + (S 0xFD)
}
$En = @{
    Link = 'link to directory'
    Unr = 'a directory in the selection cannot be read, so it cannot be checked for links'
    DeepScan = 'is nested too deeply (more than 1000 levels), so it cannot be checked for links'
    DeepWalk = 'is nested too deeply (more than 1000 levels) to be processed.'
    TooLongName = 'with full path is too long'
}
$TooLongPath = 'The path specified is too long.'
$NoUnc = 'cannot be converted to UNC'

# ---- CLIP ----------------------------------------------------------------------
function Run-Paste([string]$Case, [string]$Target, [string]$Kind) {
    if (-not $script:ClipOk) { Row $Case 'PASTE' 'NOT DRIVEN' 'the clipboard cannot be opened from this session - verified by reading'; return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $StartDir
        $loc0 = Get-Loc $id
        [Windows.Forms.Clipboard]::SetText($Target)
        Post-Cmd (Get-Main $id) 775
        Start-Sleep -Milliseconds 800
        $r = Serve101 $id 30
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $loc1 = Get-Loc $id
        $tl = Has $r 'too long'
        $landed = ($loc1 -ceq $Target)
        if ($Kind -eq 'any') { $ok = $landed -and $r.Raw.Count -eq 0 }
        elseif ($Kind -eq 'long') { if ($Fixed) { $ok = $landed -and $r.Raw.Count -eq 0 } else { $ok = $tl -eq 1 -and ($loc1 -ceq $loc0) } }
        else { if ($Fixed) { $ok = $tl -eq 0 -and $r.Raw.Count -ge 1 } else { $ok = $tl -eq 1 } }
        Row $Case 'PASTE' (V ((-not $fatal) -and $ok)) ("pasted {0} bytes; windows: {1}; location before {2}, after {3}{4}" -f (U8Len $Target), (MsgList $r), (Tail $loc0 30), (Tail $loc1 40), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- UNC -----------------------------------------------------------------------
function Free-Letter {
    $used = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Name.ToUpper() })
    foreach ($l in 'X', 'W', 'V', 'U', 'T', 'R', 'Q', 'P', 'N', 'M', 'L', 'K') {
        if ($used -notcontains $l -and -not [IO.Directory]::Exists($l + ':\')) { return $l }
    }
    throw 'no free drive letter for SUBST'
}
function Run-Unc([string]$Case, [string]$Folder, [string]$Route, [string]$WantFixed, [string]$WantBefore, [string]$LookIn = '') {
    $before = Reports; $id = 0; $fatal = $null; $find = [IntPtr]::Zero
    try {
        $id = Start-Tc $StartDir
        if (-not (Do-ChangeDir $id $Folder)) { throw 'the Change Directory field did not hold the path' }
        [void](Serve101 $id 10)
        $loc = Get-Loc $id
        if ($loc -cne $Folder) { throw ("the panel is not in the folder: '{0}'" -f (Tail $loc 40)) }
        Settle $id 300
        $find = [IntPtr]::Zero; $how = ''
        if ($Route -eq 'panel') {
            Key $id 0x24; Key $id 0x28                   # Home (".."), Down (f.txt)
            Settle $id 500
            Post-Cmd (Get-Main $id) 712                  # CM_CLIPCOPYUNCNAME
            $how = 'panel CM_CLIPCOPYUNCNAME'
            Start-Sleep -Milliseconds 600
            $r = Serve101 $id 30
        }
        else {
            $find = Open-ByCmd $id 741 10
            if ($find -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
            $script:Keep = @($find)
            $named = Find-Ctl $find 2505
            if ($LookIn) {
                # the Find window takes the panel path cut to 259 bytes into Look in: search from a
                # short parent instead, with subdirectories (the found item keeps its whole path)
                [void][Drv098f]::SetText((Find-Ctl $find 2501), $LookIn, 5000)
                $sub = @([Drv098f]::Kids($find) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2503 }) | Select-Object -First 1
                if ($sub) { [void][Drv098f]::Send($sub, 0x00F1, 1, 0, 5000) }   # BM_SETCHECK: search subdirectories
            }
            $look = [Drv098f]::GetText((Find-Ctl $find 2501), 5000)
            $inner = @([Drv098f]::Kids($named) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' }) | Select-Object -First 1
            # as 093's probe: clear the field, then type the mask into the inner edit (WM_CHAR)
            [void][Drv098f]::SetText($named, '', 5000)
            foreach ($u in 'f.txt'.ToCharArray()) { [void][Drv098f]::PostMessageW($inner, 0x0102, [IntPtr][int]$u, [IntPtr]1) }
            Settle $id 500
            $mask = [Drv098f]::GetText($named, 5000)
            $lv = @([Drv098f]::Kids($find) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2510 }) | Select-Object -First 1
            Post-Cmd $find 1                             # Find Now
            $count = -1; $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 15) {
                Start-Sleep -Milliseconds 300
                $res = [IntPtr]::Zero
                if ($lv -and [Drv098f]::SendMessageTimeoutW($lv, 0x1004, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res) -ne [IntPtr]::Zero) { $count = [int]$res.ToInt64() }
                if ($count -ge 1 -and $sw.Elapsed.TotalSeconds -gt 2) { break }
            }
            if ($count -ne 1) { throw ("Find Now found {0} items for '{1}' in '{2}' ({3} bytes)" -f $count, (Esc $mask), (Tail $look 40), (U8Len $look)) }
            Post-Cmd $find 2231                          # CM_FIND_SELECTALL
            Start-Sleep -Milliseconds 500
            Post-Cmd $find 2286                          # CM_FIND_CLIPCOPYUNCNAME
            $how = ("Find window (found {0} in '{1}') CM_FIND_CLIPCOPYUNCNAME" -f $count, (Tail $look 30))
            Start-Sleep -Milliseconds 600
            $r = Serve101 $id 30
        }
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $want = $(if ($Fixed) { $WantFixed } else { $WantBefore })
        $n = $r.Raw.Count; $tl = Has $r $TooLongPath; $nu = Has $r $NoUnc
        switch ($want) {
            'toolong' { $ok = $n -eq 1 -and $tl -eq 1 }
            'nounc' { $ok = $n -eq 1 -and $nu -eq 1 }
            'none' { $ok = $n -eq 0 }
            'notlong' { $ok = $tl -eq 0 }
        }
        $own = ''
        if ($Route -eq 'find' -and $n -ge 1) { $o = $r.Owners[0]; $own = ('; message owner = Find window: {0}' -f ($o -eq $find)); if ($want -eq 'toolong') { $ok = $ok -and ($o -eq $find) } }
        Row $Case 'UNC' (V ((-not $fatal) -and $ok)) ("{0} on {1} ({2} bytes + f.txt); expected {3}; windows: {4}{5}{6}" -f $how, (Tail $Folder 24), (U8Len $Folder), $want, (MsgList $r), $own, $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
        if ($find -ne [IntPtr]::Zero) { $script:Keep = @(); Close-Win $find; Start-Sleep -Milliseconds 500 }
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally {
        $script:Keep = @()
        if ($find -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($find)) { Close-Win $find; Start-Sleep -Milliseconds 500 }
        if ($id) { End-Row $Case $id $fatal $before }
    }
}

# ---- MSG -----------------------------------------------------------------------
function Select-Zip([IntPtr]$Dlg) {
    $packer = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 511 }) | Select-Object -First 1
    $items = @(); $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($packer, 0x0146, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)
    for ($i = 0; $i -lt [int]$res.ToInt64(); $i++) {
        $buf = New-Object char[] 512; $r2 = [IntPtr]::Zero
        [void][Drv098f]::SendGetText($packer, 0x0148, [IntPtr]$i, $buf, 0, 5000, [ref]$r2)
        $items += (New-Object string($buf, 0, [Math]::Max(0, [int]$r2.ToInt64())))
    }
    $ix = -1
    for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i] -match '^ZIP' -and $items[$i] -match '(?i)plug') { $ix = $i; break } }
    if ($ix -lt 0) { for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i] -match '^ZIP') { $ix = $i; break } } }
    if ($ix -lt 0) { throw ('no ZIP packer in ' + ($items -join '; ')) }
    [void][Drv098f]::Send($packer, 0x014E, $ix, 0, 5000)
    [void][Drv098f]::Send($Dlg, 0x0111, ((1 -shl 16) -bor 511), $packer.ToInt64(), 5000)
    return $items[$ix]
}
function Run-Move([string]$Case, [string]$Kind, [bool]$Czech) {
    $base = $Root + '\' + $Case
    $src = $base + '\S'
    $x = $base + '\X'
    NewDir $x; WriteFile ($x + '\x.txt') "outside`r`n"
    $keepFiles = @($x + '\x.txt')
    switch ($Kind) {
        'unr' {
            NewDir ($src + '\B\U'); WriteFile ($src + '\B\b.txt') "b`r`n"; WriteFile ($src + '\B\U\u.txt') "u`r`n"
            $r0 = Cmd ("icacls `"{0}`" /deny `"{1}`":(RD)" -f ($src + '\B\U'), $Me)
            if ($r0.Rc -ne 0) { Row $Case 'MOVE' 'NOT DRIVEN' ('icacls refused: ' + $r0.Text); return }
            [void]$script:Denied.Add($src + '\B\U')
            try { [void][IO.Directory]::GetFileSystemEntries($src + '\B\U'); Row $Case 'MOVE' 'NOT DRIVEN' 'the deny did not make the folder unreadable'; Remove-Fixtures; return } catch { }
            $keepFiles += ($src + '\B\b.txt')
        }
        'deep' {
            $deep = $src + '\A' + ('\d' * 1005)
            NewDir $deep; WriteFile ($deep + '\deep.txt') "deep`r`n"; WriteFile ($src + '\A\a.txt') "a`r`n"
            $keepFiles += ($src + '\A\a.txt'); $keepFiles += ($deep + '\deep.txt')
        }
        'link' {
            NewDir ($src + '\B'); WriteFile ($src + '\B\b.txt') "b`r`n"
            $r0 = Cmd ("mklink /J `"{0}`" `"{1}`"" -f ($src + '\B\J'), $x)
            if ($r0.Rc -ne 0) { Row $Case 'MOVE' 'NOT DRIVEN' ('mklink refused: ' + $r0.Text); return }
            [void]$script:Links.Add($src + '\B\J')
            $keepFiles += ($src + '\B\b.txt')
        }
    }
    $T = $(if ($Czech) { $Cz } else { $En })
    $arc = $OutDir + '\' + $Case + '.zip'
    $before = Reports; $id = 0; $fatal = $null
    try {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $(if ($Czech) { 'czech.slg' } else { 'english.slg' }) /f | Out-Null
        $id = Start-Tc $src
        Post-Cmd (Get-Main $id) 842   # select all (one item)
        Settle $id 500
        $dlg = Open-ByCmd $id 850
        if ($dlg -eq [IntPtr]::Zero) { throw 'Pack (850) opened no window' }
        $pk = Select-Zip $dlg
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), $arc, 5000)
        $mv = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 512 }) | Select-Object -First 1
        [void][Drv098f]::Send($mv, 0x00F1, 1, 0, 5000)   # BM_SETCHECK: delete files after packing
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve101 $id 180
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $boxes = $r.Boxes.Count
        # review NIT 1: the folder named by 14183 is visibly shortened (start ... end) when it is cut
        $short = @($r.Raw | Where-Object { $_.Contains($T.DeepScan) -and $_ -match '\.\.\.\\?d(\\d)+' }).Count
        $link = Has $r $T.Link; $unr = Has $r $T.Unr; $dScan = Has $r $T.DeepScan; $dWalk = Has $r $T.DeepWalk; $tln = Has $r $T.TooLongName
        $lost = @($keepFiles | Where-Object { -not [IO.File]::Exists($LP + $_) })
        $ok = $lost.Count -eq 0
        switch ($Kind) {
            'unr' { if ($Fixed) { $ok = $ok -and $unr -eq 1 -and $link -eq 0 -and $boxes -eq 2 } else { $ok = $ok -and $link -eq 1 -and $unr -eq 0 -and $boxes -eq 2 } }
            # review NIT 2: fixed = 14183 + the enumeration's real length refusal, no 14184 box for the
            # same skipped subtree (2 boxes); before = the link text + 2 x 'too long' (3 boxes)
            'deep' { if ($Fixed) { $ok = $ok -and $dScan -eq 1 -and $short -eq 1 -and $dWalk -eq 0 -and $tln -eq 1 -and $link -eq 0 -and $boxes -eq 2 } else { $ok = $ok -and $link -eq 1 -and $dScan -eq 0 -and $dWalk -eq 0 -and $tln -eq 2 -and $boxes -eq 3 } }
            'link' { $ok = $ok -and $link -eq 1 -and $unr -eq 0 -and $dScan -eq 0 }
        }
        Row $Case 'MOVE' (V ((-not $fatal) -and $ok)) ("Alt+F5 into {0} with delete; language {1}; link text {2}, cannot-read text {3}, too-deep scan text {4}, too-deep walk text {5}, 'too long' name text {6}; message boxes {10}; 14183 name shortened with '...' {11}; files lost: {7}; windows: {8}{9}" -f $pk, $(if ($Czech) { 'Czech' } else { 'English' }), $link, $unr, $dScan, $dWalk, $tln, $(if ($lost.Count) { ($lost | ForEach-Object { Tail $_ 30 }) -join ',' } else { 'none' }), (MsgList $r), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }), $boxes, $short)
        foreach ($t in $r.Raw) { Out ('           text: ' + (Short $t 700)) }
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally {
        if ($id) { End-Row $Case $id $fatal $before }
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        Remove-Fixtures
    }
}

# ---- main --------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc101_lo_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    Set-Config
    Out ("leftovers_probe (feature 101) {0}; expecting the {1} behaviour" -f $Label, $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Save-Clip
    Out ''
    # CLIP
    if (WantGroup 'p') {
        $p600 = LongDir ($Root + '\p600') 600; NewDir $p600
        $p5k = LongDir ($Root + '\p5k') 5000; NewDir $p5k
        $pnx = LongDir ($Root + '\pnx') 600
        $pcjk = $Root + '\paste' + [char]0x4E2D; NewDir $pcjk
        if (Want 'p600') { Run-Paste 'p600' $p600 'long' }
        if (Want 'p5000') { Run-Paste 'p5000' $p5k 'long' }
        if (Want 'pnx') { Run-Paste 'pnx' $pnx 'nx' }
        if (Want 'pcjk') { Run-Paste 'pcjk' $pcjk 'any' }
    }
    # UNC on a SUBST drive
    if (WantGroup 'unc') {
        $letter = Free-Letter
        $target = LongDir ($Root + '\subst') 240 't'
        NewDir $target
        $r0 = Cmd ("subst {0}: `"{1}`"" -f $letter, $target)
        if ($r0.Rc -ne 0) { Row 'unc' 'SUBST' 'NOT DRIVEN' ('subst refused: ' + $r0.Text) }
        else {
            $script:Subst = $letter
            Out ("SUBST {0}: -> {1} ({2} bytes)" -f $letter, (Tail $target 30), (U8Len $target))
            $d1 = LongDir ($target + '\u1') (240 + 300); NewDir $d1; WriteFile ($d1 + '\f.txt') "f`r`n"
            $d2 = LongDir ($target + '\u2') (240 + 600); NewDir $d2; WriteFile ($d2 + '\f.txt') "f`r`n"
            $d4 = $target + '\u4short'; NewDir $d4; WriteFile ($d4 + '\f.txt') "f`r`n"
            $x1 = $letter + ':' + $d1.Substring($target.Length)
            $x2 = $letter + ':' + $d2.Substring($target.Length)
            $x4 = $letter + ':' + $d4.Substring($target.Length)
            if (Want 'unc1') { Run-Unc 'unc1' $x1 'panel' 'toolong' 'nounc' }
            if (Want 'unc2') { Run-Unc 'unc2' $x2 'panel' 'toolong' 'none' }
            if (Want 'unc3') { Run-Unc 'unc3' $x2 'find' 'toolong' 'none' ($letter + ':\u2') }
            if (Want 'unc4') { Run-Unc 'unc4' $x4 'panel' 'notlong' 'notlong' }
            if (Want 'unc5') { Run-Unc 'unc5' $x4 'find' 'notlong' 'notlong' }
        }
    }
    # MSG
    if (Want 'unr') { Run-Move 'unr' 'unr' $false }
    if (Want 'deep') { Run-Move 'deep' 'deep' $false }
    if (Want 'link') { Run-Move 'link' 'link' $false }
    if (Want 'unrcs') { Run-Move 'unrcs' 'unr' $true }
    if (Want 'deepcs') { Run-Move 'deepcs' 'deep' $true }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    Restore-Clip
    if ($script:Subst) { $r1 = Cmd ("subst {0}: /d" -f $script:Subst); Out ("SUBST {0}: removed (rc {1}); still present: {2}" -f $script:Subst, $r1.Rc, [IO.Directory]::Exists($script:Subst + ':\')) }
    try { Remove-Fixtures } catch { Out ('Fixtures: ' + $_.Exception.Message) }
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
