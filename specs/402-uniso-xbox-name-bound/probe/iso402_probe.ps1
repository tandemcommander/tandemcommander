<#
.SYNOPSIS
    Feature 402: an Xbox (XDVDFS) directory entry whose name does not lie whole in its directory's data
    is a damaged record - the walk of that directory ends there (one error box, the listing marked
    incomplete), never reading the name past the directory's buffer.

.DESCRIPTION
    Images by img402.py (no WSL needed). Unpack rows as feature 400's: the left panel shows <row>\src,
    Home, End focuses the image, Alt+F9 (851), the target field (210) set to <row>\tgt, "Delete archive
    after unpacking" (6210) checked, OK.
      XD-NAME   root of 60 bytes: top.txt, zlast/z.txt, then an entry whose 200-byte name has 2 bytes in
                the root - PASS = exactly one box "Error reading directory structure", top.txt and
                zlast/z.txt extracted (nothing else), the image KEPT; before: the name read past the
                buffer (a file with bytes of the heap in its name), no box, the image deleted
      XD-OVER1  the same, the name 3 bytes long, one byte past the root - the same PASS (off by one)
      XD-MAX    the same, the name 255 bytes long - the same PASS
      XD-SUB    folder a of 40 bytes: side.txt, then a 255-byte name with 2 bytes in a; root goes on with
                top.txt, zlast/z.txt - PASS = one box, a/side.txt, top.txt, zlast/z.txt, the image kept
      XD-EDGE   (control) the last name 'zz' ends exactly at the end of the root's 60 bytes - PASS = no
                window, top.txt, zlast/z.txt, zz (BAD), the image deleted (before and after)
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does
    not answer within 10 s (End-Row). MUST run through tools\run_on_hidden_desktop.ps1. Registry
    exported, restored and verified. Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\400-uniso-walk-after-unreadable\probe\iso400_probe.ps1.
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
$Root = $TempRoot + '\tc402'
$StartDir = $Root + '\start'
$ReadErr = 'Error reading directory structure'

function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { try { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) } catch { return '<none>' } }
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}

# exactly the files of $Want (relative path -> content) in tgt; @(ok, facts)
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $missing = @($Want.Keys | Where-Object { $files -notcontains $_ })
    $bad = @($Want.Keys | Where-Object { $files -contains $_ } | Where-Object { (Content $Tgt $_) -cne $Want[$_] })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Damaged = exactly
# one box $ReadErr and the image kept, else a control (no window, the image deleted)
function Unpack-Row([string]$Case, [string]$Iso, $Want, [switch]$Damaged) {
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
        $c = Check-Files $tgt $Want
        $kept = [IO.File]::Exists($LP + $img)
        $nBox = ([regex]::Matches($msgs, $ReadErr)).Count
        if ($Damaged) { $winOk = ($nBox -eq 1) } else { $winOk = ($msgs -eq 'no window') }
        $ok = $c[0] -and (-not $fatal) -and $winOk
        if ($Damaged) { $ok = $ok -and $kept } else { $ok = $ok -and (-not $kept) }
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows as expected ({4}): {5} (boxes seen {6}); fatal: {7}; windows: {8}' -f $c[1], $c[0], $kept, $Damaged.IsPresent, $(if ($Damaged) { 'one box "' + $ReadErr + '"' } else { 'none' }), $winOk, $nBox, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc402_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso402_probe (feature 402) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img402.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $made = @()
    foreach ($k in @('name', 'over1', 'max', 'sub', 'edge')) { $made += & python -I $py $k "$s\xd_$k.iso" 2>&1 }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img402: ' + "$m") }
    Out ''

    $topZ = [ordered]@{ 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' }
    Unpack-Row 'XD-NAME' "$s\xd_name.iso" $topZ -Damaged
    Unpack-Row 'XD-OVER1' "$s\xd_over1.iso" $topZ -Damaged
    Unpack-Row 'XD-MAX' "$s\xd_max.iso" $topZ -Damaged
    Unpack-Row 'XD-SUB' "$s\xd_sub.iso" ([ordered]@{ 'a/side.txt' = 'SIDE'; 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' }) -Damaged
    Unpack-Row 'XD-EDGE' "$s\xd_edge.iso" ([ordered]@{ 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z'; 'zz' = 'BAD' })
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
