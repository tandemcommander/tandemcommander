<#
.SYNOPSIS
    Feature 350: an NRG (Nero) image whose CUEX chunk is shorter than 16 bytes, longer than the image
    or not a whole number of entries no longer makes the ISO plug-in build a track from every 16 bytes
    up to the end of the file - the CUEX reader takes only the entries its chunk holds.

.DESCRIPTION
    Images built by img350.py (two audio tracks of 10 raw sectors, CUEX / DAOX / SINF / END!):
      ok.nrg     the control - opens, two audio tracks
      short.nrg  a CUEX chunk of 8 bytes and a 96 MiB padding chunk before the good chunks
      past.nrg   a CUEX chunk claiming 0xFFFFFFF0 bytes and the 96 MiB padding before the good chunks
      odd.nrg    the good chunks, the CUEX chunk 4 bytes longer than its two entries
    Each row: the program starts with the image in the left panel (-l); the probe waits until the
    main window answers (at most 180 s), takes the time to that point and the process's peak working
    set, the boxes shown at the open and the panel's location; when the image opened, Select All
    (842) + Copy (727) must ask "Copy 2 files" and answer "Audio tracks cannot be extracted" (the two
    tracks are listed). A bound row also needs the window answering within 5 s of the start.
      N-OK     PASS = opened, two tracks listed
      N-SHORT  PASS = opened, two tracks listed, peak working set at most N-OK's + 150 MB
               (before 350: not opened; ~6 million tracks built from the padding - the peak grows by
               hundreds of MB)
      N-PAST   PASS = no crash, peak working set at most N-OK's + 150 MB (the image does not open as
               NRG: its chunk list ends at the end of the file); before 350: the same growth as N-SHORT
      N-ODD    PASS = opened, two tracks listed (before 350: the next chunk header read 4 bytes early -
               not opened)
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does
    not answer (End-Row).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\329-uniso-other-readers-refused\probe\iso329_probe.ps1.
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
$Root = $TempRoot + '\tc350'
$StartDir = $Root + '\start'
$script:OkPeak = -1

# opens $Nrg in the left panel; $Open = the image must open (else: must not crash); $Bound = the peak
# working set must stay within N-OK's + 150 MB
function Nrg-Row([string]$Case, [string]$Nrg, [bool]$Open, [bool]$Bound) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Nrg)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Nrg); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir $tgt
    $img = $d + '\' + [IO.Path]::GetFileName($Nrg); [IO.File]::Copy($Nrg, $LP + $img)
    $id = 0; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T350', '-l', ('"{0}"' -f $img), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        while ($sw.Elapsed.TotalSeconds -lt 180 -and (Test-Alive $id) -and -not [Drv098f]::Send((Get-Main $id), 0, 0, 0, 1000)) { }
        $secs = $sw.Elapsed.TotalSeconds
        Start-Sleep -Milliseconds 2000
        $openMsgs = Msgs (Serve $id 10)
        $p.Refresh(); $peak = [math]::Round($p.PeakWorkingSet64 / 1MB)
        $loc = Get-Loc $id
        $opened = $loc.StartsWith($img, [StringComparison]::OrdinalIgnoreCase)
        $msgs = '<not copied>'
        if ($opened) {
            Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
            Post-Cmd (Get-Main $id) 727
            $msgs = Msgs (Serve $id 30 @(1, 6))
        }
        End-Row $Case $id $null $before; $id = 0
        $listed = ($msgs -match 'Copy 2 files') -and ($msgs -match 'Audio tracks cannot be extracted')
        if ($Case -eq 'N-OK') { $script:OkPeak = $peak }
        $within = $true
        if ($Bound) { $within = ($script:OkPeak -ge 0) -and ($peak -le $script:OkPeak + 150) -and ($secs -le 5) }
        if ($Open) { $ok = $opened -and $listed -and $within } else { $ok = $within }
        Row $Case 'RUN' (V $ok) ('opened: {0} (want {1}; panel {2}); two tracks listed: {3}; peak working set {4} MB (N-OK {5} MB, bound {6}: {7}); answering after {8:N1} s; at the open: {9}; copy: {10}' -f $opened, $Open, (Tail $loc 60), $listed, $peak, $script:OkPeak, $Bound, $within, $secs, (Tail $openMsgs 300), (Tail $msgs 200))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc350_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("nrg350_probe (feature 350) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $made = @()
    foreach ($k in @('ok', 'short', 'past', 'odd')) { $made += (& python -I (Join-Path $Here 'img350.py') $k "$s\$k.nrg" 2>&1 | ForEach-Object { "$_" }) }
    $ErrorActionPreference = $old
    Out ('img350: ' + ($made -join '; '))
    Nrg-Row 'N-OK' "$s\ok.nrg" $true $false
    Nrg-Row 'N-SHORT' "$s\short.nrg" $true $true
    Nrg-Row 'N-PAST' "$s\past.nrg" $false $true
    Nrg-Row 'N-ODD' "$s\odd.nrg" $true $false
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
