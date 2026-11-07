<#
.SYNOPSIS
    Feature 416 probe: the Fluent 2 icon set by default, Classic in Configuration > Appearance, the real
    fall-back of an unusable dark override.

.DESCRIPTION
    Each run starts the program with a prepared configuration value ("Toolbar Icon Set" absent / 0 / 1 / 2 /
    REG_SZ, "Theme Mode" 0 / 1) in the folder <fixture>\start (its ".." row is the symbol under test) and
    captures (PrintWindow, client only) the top rebar (menu bar, top toolbar, drive bar), the left
    panel's file list and its directory line. Rows:
      CLASSIC-EQ-<theme>   -Before (the build of main) vs this build with value 1: rebar, file list and
                           directory line pixel-identical (Classic = 0.2.0)
      DEFAULT-<theme>      no value = value 0 (identical), and differs from Classic; value 2 and a REG_SZ value
                           also give Fluent 2, with no error box; the file list's ".." carries the
                           navigation blue (#0F6CBD light / #62ABF5 dark) in Fluent 2 only
      SWITCHBACK           Classic -> Fluent 2 + OK in Dark: the rebar equals a Fluent 2 dark start, stored 0
      SWITCH               Configuration (686) > Appearance: Fluent 2 checked; both previews drawn and
                           different; Classic clicked + OK -> the rebar equals the Classic capture without a
                           restart; after closing the value is 1; the next start shows Classic
      PAGE-<theme>         the Appearance page captured (previews drawn) in both themes
      FIT                  the Appearance labels of the 8 shipped languages and English fit their controls
                           (text extent in the page font "MS Shell Dlg 2" 8 pt vs the control width in DLU of
                           the .slt; the DLU conversion checked against the live English dialog)
      OVR-FLUENT           a copy of this build, Dark, Fluent 2: every dark variant replaced by an empty SVG
                           (and one by a non-SVG text) = the dark folder removed (the standard files, adapted)
      OVR-CLASSIC          the same with empty overrides in toolbars\dark\ for Classic (this build: equals no
                           override); with -Before also the build of main (the defect: blank cells)
    NOT DRIVEN here: a menu opened by a real keyboard / mouse; hot / pressed states (a real mouse); 125 / 150 /
    200 % (the hidden desktop's system DPI is fixed - saltests TestIconSet416 rasterizes every file at
    20 / 24 / 32 px).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Before,
    [string]$Label = 'after',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Before) { $Before = (Resolve-Path -LiteralPath $Before).Path }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot 'capture416_lib.ps1')
$Root = $TempRoot + '\tc416p'
$StartDir = $Root + '\start'
$CapDir = Join-Path $PSScriptRoot ('captures_' + $Label)
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$CfgKey = "$RegKey\Settings\Configuration"
$Caps = @{}

function Set-Look([int]$Theme, $Set) {
    & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $Theme /f | Out-Null
    if ($null -eq $Set) { & cmd.exe /c "reg delete `"$CfgKey`" /v `"Toolbar Icon Set`" /f >nul 2>&1" }
    elseif ($Set -is [string]) { & reg.exe add $CfgKey /v 'Toolbar Icon Set' /t REG_SZ /d $Set /f | Out-Null }
    else { & reg.exe add $CfgKey /v 'Toolbar Icon Set' /t REG_DWORD /d $Set /f | Out-Null }
}
function Read-Set {
    $v = & cmd.exe /c "reg query `"$CfgKey`" /v `"Toolbar Icon Set`" 2>nul"
    $m = [regex]::Match(($v -join ' '), 'REG_\w+\s+(\S+)')
    if ($m.Success) { return $m.Groups[1].Value } else { return '<none>' }
}
function Start-At([string]$ExePath) {
    $a = @('-t', 'T416', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $ExePath -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2500
    return $p.Id
}
# the parts under test of the running instance
function Grab([int]$Id, [string]$Tag) {
    $main = Get-Main $Id
    [void][Drv098f]::Send($main, 0, 0, 0, 20000)
    $full = [Cap416]::Capture($main, $false)
    $rebar = @(Get-Desc $main 'ReBarWindow32')[0]
    $items = @(Get-Desc $main 'SalamanderItemsBox')[0]
    $dirs = @([Cap416]::Kids($main) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::GetDlgCtrlID($_) -eq 952 })
    $dirs = @($dirs | Sort-Object { $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($_, [ref]$r); $r.left })
    $o = [pscustomobject]@{
        Rebar = [Cap416]::Crop($full, $main, $rebar)
        Items = [Cap416]::Crop($full, $main, $items)
        Dir   = [Cap416]::Crop($full, $main, $dirs[0])
    }
    # the directory line's drive icon only: its right end shows the free space, which changes while the probe runs
    $o.Dir = $o.Dir.Clone((New-Object Drawing.Rectangle(0, 0, [Math]::Min(36, $o.Dir.Width), $o.Dir.Height)), $o.Dir.PixelFormat)
    Save-Png $o.Rebar (Join-Path $CapDir ($Tag + '_rebar.png'))
    Save-Png $o.Items (Join-Path $CapDir ($Tag + '_files.png'))
    Save-Png $o.Dir (Join-Path $CapDir ($Tag + '_dirline.png'))
    $full.Dispose()
    return $o
}
# a whole run: configure, start, wait, grab, close (the program saves its configuration on exit)
function Run-Look([string]$ExePath, [int]$Theme, $Set, [string]$Tag) {
    Set-Look $Theme $Set
    $id = Start-At $ExePath
    $r = Serve $id 8
    Key $id 0x28 # Down: the caret leaves "..", whose icon is then drawn without the focus tincture
    Start-Sleep -Milliseconds 400
    # the file icons of the panel come from a background reader (cold shell cache at the first start):
    # grab until two captures a second apart are identical (at most 10 s)
    $g = Grab $id $Tag
    for ($k = 0; $k -lt 10; $k++) {
        Start-Sleep -Milliseconds 1000
        $g2 = Grab $id $Tag
        $same = Zero (Same $g $g2)
        $g = $g2
        if ($same) { break }
    }
    $g | Add-Member -NotePropertyName Messages -NotePropertyValue (Msgs $r)
    Stop-Tc $id
    $script:Caps[$Tag] = $g
    return $g
}
function Same($a, $b) { return [pscustomobject]@{ Rebar = [Cap416]::Diff($a.Rebar, $b.Rebar); Items = [Cap416]::Diff($a.Items, $b.Items); Dir = [Cap416]::Diff($a.Dir, $b.Dir) } }
function DiffText($d) { return ("rebar {0}, files {1}, dirline {2} px differ" -f $d.Rebar, $d.Items, $d.Dir) }
function Zero($d) { return ($d.Rebar -eq 0) -and ($d.Items -eq 0) -and ($d.Dir -eq 0) }

# ---- Configuration > Appearance -------------------------------------------------------------
function Open-Appearance([int]$Id) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 686
    $dlg = Wait-NewWin $Id $known 15
    if ($null -eq $dlg -or $dlg -eq [IntPtr]::Zero) { throw 'the Configuration dialog did not open' }
    $tree = @([Cap416]::Kids($dlg) | Where-Object { [Cap416]::Cls($_) -eq 'SysTreeView32' })[0]
    if ($null -eq $tree) { throw 'no tree view in the Configuration dialog' }
    $items = New-Object System.Collections.ArrayList
    $stack = New-Object System.Collections.Stack
    $root = [Cap416]::Send($tree, 0x110A, [IntPtr]0, [IntPtr]::Zero) # TVM_GETNEXTITEM TVGN_ROOT
    $h = $root
    $guard = 0
    while ($h -ne [IntPtr]::Zero -and $guard -lt 200) {
        $guard++
        [void]$items.Add($h)
        [void][Cap416]::Send($tree, 0x1102, [IntPtr]2, $h)            # TVM_EXPAND TVE_EXPAND
        $child = [Cap416]::Send($tree, 0x110A, [IntPtr]4, $h)         # TVGN_CHILD
        $next = [Cap416]::Send($tree, 0x110A, [IntPtr]1, $h)          # TVGN_NEXT
        if ($child -ne [IntPtr]::Zero) { if ($next -ne [IntPtr]::Zero) { $stack.Push($next) }; $h = $child }
        elseif ($next -ne [IntPtr]::Zero) { $h = $next }
        elseif ($stack.Count) { $h = $stack.Pop() }
        else { $h = [IntPtr]::Zero }
    }
    foreach ($it in $items) {
        [void][Cap416]::Send($tree, 0x110B, [IntPtr]9, $it)            # TVM_SELECTITEM TVGN_CARET
        Start-Sleep -Milliseconds 300
        $radio = @([Cap416]::Kids($dlg) | Where-Object { [Cap416]::GetDlgCtrlID($_) -eq 6292 -and [Cap416]::IsWindowVisible($_) })
        if ($radio.Count) { return [pscustomobject]@{ Dlg = $dlg; Page = [Cap416]::GetParent($radio[0]); Items = $items.Count } }
    }
    throw ("the Appearance page was not found among {0} tree items" -f $items.Count)
}
function Ctl([IntPtr]$Page, [int]$CtlId) { return @([Cap416]::Kids($Page) | Where-Object { [Cap416]::GetDlgCtrlID($_) -eq $CtlId })[0] }
function Checked([IntPtr]$H) { return [int][Cap416]::Send($H, 0x00F0, [IntPtr]::Zero, [IntPtr]::Zero) }
function Grab-Page($A, [string]$Tag) {
    [void][Drv098f]::Send($A.Page, 0, 0, 0, 10000)
    $pg = [Cap416]::Capture($A.Page, $false)
    Save-Png $pg (Join-Path $CapDir ($Tag + '_appearance.png'))
    $pf = [Cap416]::Crop($pg, $A.Page, (Ctl $A.Page 6294)); $pc = [Cap416]::Crop($pg, $A.Page, (Ctl $A.Page 6295))
    Save-Png $pf (Join-Path $CapDir ($Tag + '_preview_fluent.png')); Save-Png $pc (Join-Path $CapDir ($Tag + '_preview_classic.png'))
    return [pscustomobject]@{ Fluent = $pf; Classic = $pc; FluentStats = [Cap416]::Stats($pf); ClassicStats = [Cap416]::Stats($pc); Differ = [Cap416]::Diff($pf, $pc) }
}
function Colours([Drawing.Bitmap]$B) { return [int](([Cap416]::Stats($B) -split ' ')[2]) }

# ---- the rows -------------------------------------------------------------------------------
function Row-ClassicEq([int]$Theme) {
    $n = 'CLASSIC-EQ-' + @('LIGHT', 'DARK')[$Theme]
    if (-not (Want $n)) { return }
    if (-not $Before) { Row $n 'RUN' 'NOT DRIVEN' 'no -Before build given'; return }
    try {
        $b = Run-Look $Before $Theme $null ('before_classic_t' + $Theme)
        $a = Run-Look $Exe $Theme 1 ('classic_t' + $Theme)
        $d = Same $a $b
        Row $n 'COMPARE' (V (Zero $d)) ((DiffText $d) + '; rebar ' + [Cap416]::Stats($a.Rebar) + '; windows: ' + $a.Messages)
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
function Row-Default([int]$Theme) {
    $n = 'DEFAULT-' + @('LIGHT', 'DARK')[$Theme]
    if (-not (Want $n)) { return }
    try {
        $none = Run-Look $Exe $Theme $null ('default_t' + $Theme)
        $zero = Run-Look $Exe $Theme 0 ('fluent_t' + $Theme)
        $two = Run-Look $Exe $Theme 2 ('unknown_t' + $Theme)
        $kept = Read-Set # review 1: a later version's number is written back unchanged
        $sz = Run-Look $Exe $Theme '1' ('wrongtype_t' + $Theme)
        if (-not $script:Caps.ContainsKey('classic_t' + $Theme)) { [void](Run-Look $Exe $Theme 1 ('classic_t' + $Theme)) }
        $cl = $script:Caps['classic_t' + $Theme]
        $d0 = Same $none $zero; $d2 = Same $two $zero; $ds = Same $sz $zero; $dc = Same $zero $cl
        Row $n 'NO-VALUE=FLUENT' (V (Zero $d0)) (DiffText $d0)
        Row $n 'VALUE-2=FLUENT' (V ((Zero $d2) -and $kept -eq '0x2')) ((DiffText $d2) + '; stored after closing: ' + $kept)
        Row $n 'REG_SZ=FLUENT' (V ((Zero $ds) -and $sz.Messages -eq 'no window')) ((DiffText $ds) + '; windows: ' + $sz.Messages)
        Row $n 'FLUENT<>CLASSIC' (V ($dc.Rebar -gt 500 -and $dc.Items -gt 0 -and $dc.Dir -gt 0)) (DiffText $dc)
        $blue = @(0x0F6CBD, 0x62ABF5)[$Theme]
        $bf = [Cap416]::CountColor($zero.Items, $blue, 6); $bc = [Cap416]::CountColor($cl.Items, $blue, 6)
        Row $n 'UPDIR-BLUE' (V ($bf -ge 8 -and $bc -eq 0)) ("pixels of #{0:X6} in the file list: Fluent 2 {1}, Classic {2}" -f $blue, $bf, $bc)
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
# review 2: the way back - Classic -> Fluent 2 + OK, in the Dark theme, without a restart
function Row-SwitchBack {
    $n = 'SWITCHBACK'
    if (-not (Want $n)) { return }
    $id = 0
    try {
        if (-not $script:Caps.ContainsKey('fluent_t1')) { [void](Run-Look $Exe 1 0 'fluent_t1') }
        Set-Look 1 1
        $id = Start-At $Exe
        [void](Serve $id 8)
        $a = Open-Appearance $id
        $f = Ctl $a.Page 6292; $c = Ctl $a.Page 6293
        Row $n 'CLASSIC-CHECKED' (V ((Checked $c) -eq 1 -and (Checked $f) -eq 0)) ("Fluent {0}, Classic {1}" -f (Checked $f), (Checked $c))
        [void][Cap416]::Send($f, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 300
        $okBtn = @([Cap416]::Kids($a.Dlg) | Where-Object { [Cap416]::Cls($_) -eq 'Button' -and [Cap416]::GetDlgCtrlID($_) -eq 5 })[0]
        Click $okBtn
        $r = Serve $id 15
        Start-Sleep -Milliseconds 1500
        Key $id 0x28
        Start-Sleep -Milliseconds 400
        $g = Grab $id 'switchback_after_ok'
        $d = Same $g $script:Caps['fluent_t1']
        Row $n 'DARK-APPLIED-NO-RESTART' (V (Zero $d)) ((DiffText $d) + ' (vs Fluent dark); windows: ' + (Msgs $r))
        Stop-Tc $id; $id = 0
        Row $n 'STORED' (V ((Read-Set) -eq '0x0')) ("stored: {0}" -f (Read-Set))
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Stop-Tc $id } }
}
function Row-Switch {
    $n = 'SWITCH'
    if (-not (Want $n)) { return }
    $id = 0
    try {
        if (-not $script:Caps.ContainsKey('classic_t0')) { [void](Run-Look $Exe 0 1 'classic_t0') }
        if (-not $script:Caps.ContainsKey('fluent_t0')) { [void](Run-Look $Exe 0 0 'fluent_t0') }
        Set-Look 0 $null
        $id = Start-At $Exe
        [void](Serve $id 8)
        $a = Open-Appearance $id
        $f = Ctl $a.Page 6292; $c = Ctl $a.Page 6293
        Row $n 'PAGE-FOUND' 'PASS' ("{0} tree items walked" -f $a.Items)
        Row $n 'FLUENT-CHECKED' (V ((Checked $f) -eq 1 -and (Checked $c) -eq 0)) ("Fluent {0}, Classic {1}" -f (Checked $f), (Checked $c))
        $pg = Grab-Page $a 'switch_light'
        Row $n 'PREVIEWS' (V ((Colours $pg.Fluent) -ge 8 -and (Colours $pg.Classic) -ge 8 -and $pg.Differ -gt 50)) ("Fluent {0}; Classic {1}; differ {2} px" -f $pg.FluentStats, $pg.ClassicStats, $pg.Differ)
        [void][Cap416]::Send($c, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) # BM_CLICK
        Start-Sleep -Milliseconds 300
        Row $n 'CLASSIC-CLICKED' (V ((Checked $c) -eq 1 -and (Checked $f) -eq 0)) ("Fluent {0}, Classic {1}" -f (Checked $f), (Checked $c))
        $okBtn = @([Cap416]::Kids($a.Dlg) | Where-Object { [Cap416]::Cls($_) -eq 'Button' -and [Cap416]::GetDlgCtrlID($_) -eq 5 })[0] # _TPD_IDC_OK
        if ($null -eq $okBtn) { throw 'no OK button (id 5) in the Configuration dialog' }
        Click $okBtn
        $r = Serve $id 15
        Start-Sleep -Milliseconds 1500
        Key $id 0x28
        Start-Sleep -Milliseconds 400
        $g = Grab $id 'switch_after_ok'
        $d = Same $g $script:Caps['classic_t0']
        Row $n 'APPLIED-NO-RESTART' (V ($d.Rebar -eq 0 -and $d.Items -eq 0)) ((DiffText $d) + ' (vs Classic); windows: ' + (Msgs $r))
        Stop-Tc $id; $id = 0
        $v = Read-Set
        Row $n 'STORED' (V ($v -eq '0x1')) ("Toolbar Icon Set after closing: {0}" -f $v)
        $id = Start-At $Exe
        [void](Serve $id 8)
        Key $id 0x28
        Start-Sleep -Milliseconds 400
        $g2 = Grab $id 'switch_restart'
        Stop-Tc $id; $id = 0
        $d2 = Same $g2 $script:Caps['classic_t0']
        Row $n 'RESTART-CLASSIC' (V (Zero $d2)) (DiffText $d2)
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Stop-Tc $id } }
}
function Row-Page([int]$Theme) {
    $n = 'PAGE-' + @('LIGHT', 'DARK')[$Theme]
    if (-not (Want $n)) { return }
    $id = 0
    try {
        Set-Look $Theme 0
        $id = Start-At $Exe
        [void](Serve $id 8)
        $a = Open-Appearance $id
        $pg = Grab-Page $a ('page_t' + $Theme)
        Row $n 'PREVIEWS' (V ((Colours $pg.Fluent) -ge 8 -and (Colours $pg.Classic) -ge 8 -and $pg.Differ -gt 50)) ("Fluent {0}; Classic {1}; differ {2} px" -f $pg.FluentStats, $pg.ClassicStats, $pg.Differ)
        if ($Theme -eq 0) {
            # the DLU conversion of Row-Fit, checked on the live English page
            $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect((Ctl $a.Page 6292), [ref]$r)
            $script:LiveRadioPx = $r.right - $r.left
            $r2 = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect((Ctl $a.Page 6291), [ref]$r2)
            $script:LiveGroupPx = $r2.right - $r2.left
        }
        Post-Cmd $a.Dlg 2 # IDCANCEL
        [void](Serve $id 8)
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Stop-Tc $id } }
}
function Row-Fit {
    $n = 'FIT'
    if (-not (Want $n)) { return }
    try {
        $font = New-Object Drawing.Font('MS Shell Dlg 2', 8)
        $bmp = New-Object Drawing.Bitmap(10, 10); $g = [Drawing.Graphics]::FromImage($bmp)
        $flags = [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::NoPadding
        $abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
        $baseX = ([Windows.Forms.TextRenderer]::MeasureText($g, $abc, $font, (New-Object Drawing.Size(2000, 100)), $flags).Width / 26 + 1) / 2
        $dpi = $g.DpiX
        $check = [int](13 * $dpi / 96) + [int](4 * $dpi / 96) # the radio's circle and its gap
        # the control widths from the live English page (its real dialog base unit); the text extents from
        # TextRenderer, which measures a little wider than the dialog's DrawText - the check errs on the safe side
        $measured = $baseX
        if ($script:LiveRadioPx -and $script:LiveGroupPx) {
            $bxRadio = $script:LiveRadioPx * 4.0 / 70; $bxGroup = $script:LiveGroupPx * 4.0 / 295
            $baseX = ($bxRadio + $bxGroup) / 2
            Row $n 'DLU' (V ([Math]::Abs($bxRadio - $bxGroup) -le 0.1)) ("live page: 70 DLU = {0} px, 295 DLU = {1} px -> base unit x {2:0.00} / {3:0.00} (TextRenderer estimate {4:0.00})" -f $script:LiveRadioPx, $script:LiveGroupPx, $bxRadio, $bxGroup, $measured)
        } else { Row $n 'DLU' 'NOT DRIVEN' ("no live page measured (row PAGE-LIGHT); estimate {0:0.00}" -f $measured) }
        $tpl = Join-Path (Split-Path (Split-Path $Exe)) 'translator\templates\salamand.slt'
        $files = @(, @('english', $tpl)) + @('czech', 'slovak', 'german', 'french', 'dutch', 'hungarian', 'romanian', 'spanish' | ForEach-Object { , @($_, (Join-Path $RepoRoot ("translations\{0}\salamand.slt" -f $_))) })
        foreach ($pair in $files) {
            $lang = $pair[0]
            if (-not (Test-Path -LiteralPath $pair[1])) { Row $n $lang 'FAIL' ('missing ' + $pair[1]); continue }
            $lines = [IO.File]::ReadAllLines($pair[1], [Text.Encoding]::UTF8)
            $worst = @()
            $ok = $true
            foreach ($ctl in 6291, 6292, 6293) {
                $line = @($lines | Where-Object { $_ -like ("{0},*" -f $ctl) })[0]
                $m = [regex]::Match($line, '^\d+,(-?\d+),(-?\d+),(\d+),(\d+),\d+,"(.*)"$')
                $text = $m.Groups[5].Value -replace '&&', "`0" -replace '&', '' -replace "`0", '&'
                $w = [int]$m.Groups[3].Value
                $px = [int][Math]::Round($w * $baseX / 4)
                $tw = [Windows.Forms.TextRenderer]::MeasureText($g, $text.Trim(), $font, (New-Object Drawing.Size(4000, 100)), $flags).Width
                $room = if ($ctl -eq 6291) { $px - [int](16 * $dpi / 96) } else { $px - $check }
                if ($tw -gt $room) { $ok = $false }
                $worst += ("{0} '{1}' {2}/{3} px" -f $ctl, $text.Trim(), $tw, $room)
            }
            Row $n $lang (V $ok) ($worst -join '; ')
        }
        $g.Dispose(); $bmp.Dispose()
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
# review 1 (S1): a configuration imported at start-up (-C file.reg) holds another set than the registry
function Row-Import {
    $n = 'IMPORT'
    if (-not (Want $n)) { return }
    $id = 0
    try {
        if (-not $script:Caps.ContainsKey('classic_t0')) { [void](Run-Look $Exe 0 1 'classic_t0') }
        Set-Look 0 1
        $reg = $Root + '\imp\import416.reg' # in a folder made at the start: the fixture root's time (the ".." row) stays
        & cmd.exe /c "reg export `"$RegKey\Settings`" `"$reg`" /y >nul 2>&1"
        if ($LASTEXITCODE -ne 0) { throw 'reg export of the configuration failed' }
        Set-Look 0 $null # the registry says nothing (= Fluent 2) when the program starts; the file says Classic
        $a = @('-t', 'T416', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1', '-C', ('"{0}"' -f $reg))
        $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2500
        $r = Serve $id 10
        Key $id 0x28
        Start-Sleep -Milliseconds 400
        $g = Grab $id 'import_classic'
        Stop-Tc $id; $id = 0
        $d = Same $g $script:Caps['classic_t0']
        Row $n 'CLASSIC-FROM-FILE' (V (Zero $d)) ((DiffText $d) + ' (vs Classic); stored now ' + (Read-Set) + '; windows: ' + (Msgs $r))
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Stop-Tc $id } }
}
# a throw-away copy of a build tree (no .pdb, no Intermediate, no saltests)
function Copy-Tree([string]$From, [string]$To) {
    & robocopy.exe (Split-Path $From) $To /E /XF *.pdb *.ilk /XD Intermediate saltests /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $From -> $To failed ($LASTEXITCODE)" }
    return (Join-Path $To (Split-Path $From -Leaf))
}
$EmptySvg = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"></svg>'
function Row-OvrFluent {
    $n = 'OVR-FLUENT'
    if (-not (Want $n)) { return }
    try {
        $tree = $Root + '\tree_fluent'
        $exe2 = Copy-Tree $Exe $tree
        $darkDir = $tree + '\iconsets\fluent\dark'
        $x = Run-Look $exe2 1 0 'ovr_fluent_verbatim'
        $names = @(Get-ChildItem -LiteralPath $darkDir -Filter '*.svg' | ForEach-Object { $_.Name })
        foreach ($f in $names) { [IO.File]::WriteAllText((Join-Path $darkDir $f), $EmptySvg) }
        [IO.File]::WriteAllText((Join-Path $darkDir 'Copy.svg'), 'this is not an SVG file')
        $y = Run-Look $exe2 1 0 'ovr_fluent_empty'
        [IO.Directory]::Delete($darkDir, $true)
        $z = Run-Look $exe2 1 0 'ovr_fluent_nodark'
        $dyz = Same $y $z; $dxy = Same $x $y
        Row $n 'EMPTY=STANDARD' (V (Zero $dyz)) ("{0} overrides empty (Copy.svg not an SVG) vs no dark folder: {1}; rebar {2}" -f $names.Count, (DiffText $dyz), [Cap416]::Stats($y.Rebar))
        Row $n 'VERBATIM<>ADAPTED' (V ($dxy.Rebar -gt 0)) ("the hand-made dark files vs the adapted standard files: " + (DiffText $dxy))
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
function Row-OvrClassic([string]$Which, [string]$ExePath) {
    $n = 'OVR-CLASSIC-' + $Which
    if (-not (Want $n)) { return }
    try {
        $tree = $Root + '\tree_classic_' + $Which
        $exe2 = Copy-Tree $ExePath $tree
        $darkDir = $tree + '\toolbars\dark'
        $p = Run-Look $exe2 1 1 ('ovr_classic_' + $Which + '_none')
        $names = @(Get-ChildItem -LiteralPath ($tree + '\toolbars') -Filter '*.svg' | ForEach-Object { $_.Name })
        foreach ($f in $names) { [IO.File]::WriteAllText((Join-Path $darkDir $f), $EmptySvg) }
        $q = Run-Look $exe2 1 1 ('ovr_classic_' + $Which + '_empty')
        $d = Same $p $q
        if ($Which -eq 'AFTER') { Row $n 'EMPTY=NONE' (V ($d.Rebar -eq 0)) ("{0} empty overrides in toolbars\dark: {1}" -f $names.Count, (DiffText $d)) }
        else { Row $n 'DEFECT' (V ($d.Rebar -gt 0)) ("the build of main with {0} empty overrides (negative control, the defect): {1}" -f $names.Count, (DiffText $d)) }
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}

$backup = Join-Path $env:TEMP 'tc416_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    Add-Type -AssemblyName System.Windows.Forms
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    NewDir ($Root + '\imp')
    # an unregistered extension: the panel draws its own symbol, no association icon read in the background
    # (with .txt the first starts showed the shell icon or not, by timing)
    foreach ($f in 'a.tc416', 'b.tc416') { $p = $StartDir + '\' + $f; [IO.File]::WriteAllText($p, 'x'); [IO.File]::SetLastWriteTime($p, [datetime]'2026-01-02 03:04:05') }
    [void][IO.Directory]::CreateDirectory($CapDir)
    Set-Config
    Out ("iconset416_probe (feature 416) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Before  : {0}" -f $Before)
    Out ("Date    : {0}; registry key existed {1}; captures in {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $CapDir)
    Out ''
    Row-ClassicEq 0
    Row-ClassicEq 1
    Row-Default 0
    Row-Default 1
    Row-Switch
    Row-SwitchBack
    Row-Page 0
    Row-Page 1
    Row-Fit
    Row-Import
    Row-OvrFluent
    Row-OvrClassic 'AFTER' $Exe
    if ($Before) { Row-OvrClassic 'BEFORE' $Before }
    Row 'MENU' 'OPEN' 'NOT DRIVEN' 'a menu opened by a real keyboard or mouse (the menus draw from the same image lists as the toolbar)'
    Row 'STATES' 'HOT-PRESSED' 'NOT DRIVEN' 'hot / pressed buttons need a real mouse; checked / disabled / highlight are measured offline (saltests TestIconSet416)'
    Row 'DPI' '125-200' 'NOT DRIVEN' 'the hidden desktop runs at the session system DPI; saltests rasterizes every file at 20 / 24 / 32 px'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
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
