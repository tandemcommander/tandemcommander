<#
.SYNOPSIS
    Feature 329: an entry of a UDF, Xbox (XDVDFS) or HFS+ volume, or an audio track, that the panel
    listing refuses no longer ends its folder (or the HFS+ volume, or the listing) with "Error" /
    "too long path" - it is left out and named in feature 328's report, and Unpack with "Delete
    archive after unpacking" keeps an image whose listing left something out.

.DESCRIPTION
    Seed images, all of 328's deep tree a<59 x>/b<59 x>/c<59 x>/d<59 x>/e<59 x>/deep.txt,
    a<59 x>/side.txt, top.txt, zlast/z.txt (zlast after the deep folder in every directory):
      udeep.iso  genisoimage -udf (mkimg329.sh, WSL Ubuntu): ISO 9660 level 1 + UDF; the listing's
                 folder "UDF (TC329)" refuses e<59 x> (its folder part is 256 bytes)
      hdeep.iso  xorriso -hfsplus on, no Rock Ridge / Joliet (mkimg329.sh): ISO 9660 + HFS+; the folder
                 "HFS (...)" refuses an entry of the deep chain
      xdeep.iso  XDVDFS built by img329.py: no file-system folder; the listing refuses deep.txt (its
                 folder part is 305 bytes)
      audio.nrg  NRG of two audio tracks built by img329.py, CD-Text labels SHORT and 253 x L: the
                 second track's name (256 bytes) is refused
    Copy rows U-COPY, X-COPY, H-COPY: the left panel opens the image, the right shows <row>\tgt;
    Select All (842), Copy (727), every box answered OK / Yes.
      PASS = no "Error" / "too long path" box at the open; one "(206)" box naming the left-out entry
             (e<59 x> for UDF / HFS+, deep.txt for Xbox); top.txt, zlast\z.txt and a<59 x>\side.txt of
             that file system extracted with their content; no deep.txt anywhere under it (HFS+: a
             left-out folder's contents are not listed elsewhere) - before 329: "Error" / "too long
             path", z.txt lost (later folders not descended, later HFS+ records dropped)
    Unpack rows U-UNP-DEL, X-UNP-DEL, H-UNP-DEL: the left panel shows <row>\src, Home, End focuses the
    image, Alt+F9 (851), the target field (210) set to <row>\tgt, "Delete archive after unpacking"
    (6210) checked, OK.
      PASS = the same three files, a "(206)" box, the image KEPT - before 329: the image deleted
    A-OPEN: the left panel opens audio.nrg. PASS = no "Error" box at the open, a "(206)" box naming the
      second track (02 L...); Select All + Copy answers "Audio tracks cannot be extracted" (the first
      track is listed) - before 329: "Error", the listing cleared (nothing to copy)
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does
    not answer within 30 s (End-Row). Without WSL Ubuntu the U / H rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\328-uniso-refused-entry\probe\iso328_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc329'
$StartDir = $Root + '\start'
$Seg = 'x' * 59
$SegA = 'a' + $Seg; $SegE = 'e' + $Seg # (not $a / $e: PowerShell names ignore case)

function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { try { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) } catch { return '<none>' } }
function Short([string]$s) { return ($s -replace ('x{59}'), '<59x>' -replace ('X{7}'), '<7X>' -replace ('L{253}'), '<253 L>') }
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}

# the files of one file system in tgt: $Fs = '' (Xbox: the image root) or the prefix of its folder
# ('UDF', 'HFS'); returns @(ok, facts)
function Check-Fs([string]$Tgt, [string]$Fs) {
    $files = @(Tgt-Files $Tgt)
    $pre = ''
    if ($Fs) {
        $dirs = @($files | ForEach-Object { ($_ -split '/')[0] } | Where-Object { $_.StartsWith($Fs + ' (') -or $_ -ceq $Fs } | Sort-Object -Unique)
        if ($dirs.Count -ne 1) { return @($false, ('no single "{0}" folder; files {1}: {2}' -f $Fs, $files.Count, ((@($files | ForEach-Object { Esc (Short $_) })) -join ', '))) }
        $pre = $dirs[0] + '/'
    }
    $mine = @($files | Where-Object { $_.StartsWith($pre) } | ForEach-Object { $_.Substring($pre.Length) })
    $want = [ordered]@{ ($SegA + '/side.txt') = 'SIDE'; 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' }
    $missing = @($want.Keys | Where-Object { $mine -cnotcontains $_ })
    $bad = @($want.Keys | Where-Object { $mine -ccontains $_ -and (Content $Tgt ($pre + $_)) -cne $want[$_] })
    $deep = @($mine | Where-Object { $_ -like '*deep.txt' })
    $ok = ($missing.Count -eq 0 -and $bad.Count -eq 0 -and $deep.Count -eq 0 -and $mine.Count -eq 3)
    $f = ('{0}files {1}: {2}' -f $(if ($pre) { "in '" + $pre + "' " } else { '' }), $mine.Count, ((@($mine | ForEach-Object { Esc (Short $_) })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ((@($missing | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ((@($bad | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    return @($ok, $f)
}

# opens $Iso in the left panel (the right one shows tgt), Select All, Copy; $LeftName = the entry the
# report must name
function Copy-Row([string]$Case, [string]$Iso, [string]$Fs, [string]$LeftName) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Iso)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Iso); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir $tgt
    $img = $d + '\' + [IO.Path]::GetFileName($Iso); [IO.File]::Copy($Iso, $LP + $img)
    $id = 0; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T329', '-l', ('"{0}"' -f $img), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        $openMsgs = Msgs (Serve $id 10)
        $loc = Get-Loc $id
        if (-not $loc.StartsWith($img, [StringComparison]::OrdinalIgnoreCase)) { throw ('the image did not open; panel at: ' + (Tail $loc 80) + '; at the open: ' + (Tail $openMsgs 200)) }
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 727
        $msgs = Msgs (Serve $id 60 @(1, 6))
        End-Row $Case $id $null $before; $id = 0
        $c = Check-Fs $tgt $Fs
        $has206 = ($openMsgs -match '\(206\)') -and ($openMsgs -match [regex]::Escape($LeftName))
        $errBox = ($openMsgs -cmatch '\] Error( \||$)') -or ($openMsgs -match 'too long path')
        $ok = $c[0] -and $has206 -and -not $errBox
        Row $Case 'RUN' (V $ok) ('{0}; "(206)" naming {1} at the open: {2}; "Error" / "too long path": {3}; at the open: {4}; copy: {5}' -f $c[1], (Short $LeftName), $has206, $errBox, (Short (Tail $openMsgs 500)), (Short (Tail $msgs 500)))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"
function Unpack-Row([string]$Case, [string]$Iso, [string]$Fs, [string]$LeftName) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Iso)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Iso); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Iso); [IO.File]::Copy($Iso, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        Set-Field $dlg 210 $tgt
        $btn = Find-Btn $dlg 6210
        if (-not $btn -or -not [Drv098f]::IsWindowEnabled($btn)) { throw 'the box "Delete archive after unpacking" (6210) is missing or disabled' }
        [void][Drv098f]::Send($btn, 0x00F1, 1, 0, 5000)   # BM_SETCHECK BST_CHECKED
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 90 @(1, 6)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Fs $tgt $Fs
        $kept = [IO.File]::Exists($LP + $img)
        $has206 = ($msgs -match '\(206\)') -and ($msgs -match [regex]::Escape($LeftName))
        $ok = $c[0] -and (-not $fatal) -and $kept -and $has206
        Row $Case 'RUN' (V $ok) ('{0}; image kept: {1} (want True); "(206)" naming {2}: {3}; fatal: {4}; windows: {5}' -f $c[1], $kept, (Short $LeftName), $has206, (Tail ([string]$fatal) 200), (Short (Tail $msgs 500)))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# opens the audio NRG in the left panel; Select All + Copy into tgt
function Audio-Row([string]$Case, [string]$Nrg) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Nrg)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Nrg); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir $tgt
    $img = $d + '\' + [IO.Path]::GetFileName($Nrg); [IO.File]::Copy($Nrg, $LP + $img)
    $id = 0; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T329', '-l', ('"{0}"' -f $img), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        $openMsgs = Msgs (Serve $id 10)
        $loc = Get-Loc $id
        $opened = $loc.StartsWith($img, [StringComparison]::OrdinalIgnoreCase)
        $msgs = '<not copied>'
        if ($opened) {
            Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
            Post-Cmd (Get-Main $id) 727
            $msgs = Msgs (Serve $id 30 @(1, 6))
        }
        End-Row $Case $id $null $before; $id = 0
        # the box wraps the 253 letters - the window text joins its lines with a space
        $has206 = ($openMsgs -match '\(206\)') -and ($openMsgs -match '02 ((?:L|\s)+)') -and (($Matches[1] -replace '\s', '').Length -eq 253)
        $errBox = ($openMsgs -cmatch '\] Error( \||$)')
        $listed = ($msgs -match 'Audio tracks cannot be extracted')
        $ok = $opened -and $has206 -and (-not $errBox) -and $listed
        Row $Case 'RUN' (V $ok) ('opened: {0} (panel {1}); "(206)" naming 02 <253 L>: {2}; "Error": {3}; a track listed (copy answers "Audio tracks cannot be extracted"): {4}; at the open: {5}; copy: {6}' -f $opened, (Tail $loc 60), $has206, $errBox, $listed, (Short (Tail $openMsgs 400)), (Short (Tail $msgs 300)))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc329_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso329_probe (feature 329) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $Here 'mkimg329.sh')) (WslPath $s) 2>&1
    $px = & python -I (Join-Path $Here 'img329.py') xbox "$s\xdeep.iso" 2>&1
    $pn = & python -I (Join-Path $Here 'img329.py') nrg "$s\audio.nrg" 2>&1
    $ErrorActionPreference = $old
    Out ("seeds: {0}; img329: {1} / {2}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','), (($px | ForEach-Object { "$_" }) -join ' '), (($pn | ForEach-Object { "$_" }) -join ' '))
    if (-not [IO.File]::Exists("$s\udeep.iso")) { Out ('mkimg329.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Copy-Row 'U-COPY' "$s\udeep.iso" 'UDF' $SegE
    Copy-Row 'X-COPY' "$s\xdeep.iso" '' 'deep.txt'
    Copy-Row 'H-COPY' "$s\hdeep.iso" 'HFS' $SegE
    Unpack-Row 'U-UNP-DEL' "$s\udeep.iso" 'UDF' $SegE
    Unpack-Row 'X-UNP-DEL' "$s\xdeep.iso" '' 'deep.txt'
    Unpack-Row 'H-UNP-DEL' "$s\hdeep.iso" 'HFS' $SegE
    Audio-Row 'A-OPEN' "$s\audio.nrg"
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
