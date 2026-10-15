<#
.SYNOPSIS
    Feature 241 probe: copying (F5) or moving (F6) a folder into a ZIP when a folder inside it has a
    name over 255 bytes (90 CJK letters) - never a silent end, never a "success" that packed nothing.

.DESCRIPTION
    Fixture per row: <row>\src\A holding x.txt and the folder LONG (90 CJK letters, 270 bytes of UTF-8)
    with f.txt; <row>\t.zip (one entry "seed.txt", made by .NET). The left panel shows <row>\src, the
    right panel the archive t.zip. Home, Down focuses A; F5 (727) or F6 (728), the dialogs answered OK.
      COPY   PASS = a message names the problem (a window with "too long" / "name") and t.zip keeps
             seed.txt; or A packed whole (A/x.txt and A/LONG/f.txt in t.zip)
      MOVE   as COPY; PASS also needs src\A untouched unless it was packed whole
      SHORT  the control: A with a short subfolder "s" - packed (A/x.txt, A/s/f.txt)
      TOP    the long folder itself selected (src holds only LONG with f.txt), F5: PASS = "too long" and
             t.zip keeps only seed.txt
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Root = $TempRoot + '\tc241'
$StartDir = $Root + '\start'
$Long = -join (1..90 | ForEach-Object { [char](0x4E00 + $_) })

function Zip-Entries([string]$Zip) {
    $z = [IO.Compression.ZipFile]::OpenRead($Zip)
    try { return @($z.Entries | ForEach-Object { $_.FullName }) } finally { $z.Dispose() }
}

function Run-Case([string]$Case, [int]$Cmd, [string]$Sub) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $a = $d + '\src\A'
    if ($Case -eq 'TOP') { $a = $d + '\src' }   # the long folder directly in the panel
    NewDir $a; NewDir ($a + '\' + $Sub)
    [IO.File]::WriteAllText($LP + $a + '\x.txt', 'X'); [IO.File]::WriteAllText($LP + $a + '\' + $Sub + '\f.txt', 'F')
    $seedDir = $d + '\seed'; NewDir $seedDir; [IO.File]::WriteAllText($LP + $seedDir + '\seed.txt', 'S')
    $zip = $d + '\t.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($seedDir, $zip)
    $id = 0; $before = Reports
    try {
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T241', '-l', ('"{0}"' -f ($d + '\src')), '-r', ('"{0}"' -f $zip), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x28
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) $Cmd
        $r = Serve $id 40 @(1, 6)
        End-Row $Case $id $null $before; $id = 0
        $entries = @(Zip-Entries $zip)
        $srcLeft = [IO.Directory]::Exists($LP + $a + '\' + $Sub + '\') -and [IO.File]::Exists($LP + $a + '\x.txt')
        $packedWhole = ($entries -contains 'A/x.txt') -and ($entries -contains ('A/' + $Sub + '/f.txt'))
        $msgs = Msgs $r
        $told = $msgs -match 'too long'
        if ($Case -eq 'SHORT') { $ok = $packedWhole }
        elseif ($Case -eq 'TOP') { $ok = $told -and ($entries.Count -eq 1) -and ($entries -contains 'seed.txt') }
        else { $ok = $packedWhole -or ($told -and ($entries -contains 'seed.txt') -and $srcLeft) }
        Row $Case 'RUN' (V $ok) ("zip entries: {0}; src A whole {1}; windows: {2}" -f (($entries | ForEach-Object { if ($_.Length -gt 40) { $_.Substring(0, 12) + '...(' + $_.Length + ')' } else { $_ } }) -join ', '), $srcLeft, $msgs)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc241_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("pack241_probe (feature 241) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; the long folder {3} bytes" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), (U8Len $Long))
    Out ''
    Run-Case 'SHORT' 727 's'
    Run-Case 'COPY' 727 $Long
    Run-Case 'MOVE' 728 $Long
    Run-Case 'TOP' 727 $Long
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
