<#
.SYNOPSIS
    Feature 131 probe: the rows of the defect batch that can be driven on the hidden desktop
    without a server.

.DESCRIPTION
      FTPPCT   Change Directory to "ftp://<host with %s and %d>/": the host does not exist, the
               FTP client reports it. The host name must be shown as typed - on the build before
               its '%' characters were read as printf directives of the error text.
      END      the instance ends with exit code 0, no stray window, no report

    The host name ends in ".invalid" (reserved: never resolves, nothing is contacted beyond the
    name lookup).

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string]$Lang = 'english'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc131'
$StartDir = $Root + '\start'
$HostName = 'tc131-%s-%d-%s.invalid'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T131', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }

function Row-FtpPct {
    $before = Reports; $id = 0
    try {
        $id = Start-P $StartDir
        $known = Get-Tops $id
        [void](Do-ChangeDir $id ('ftp://' + $HostName + '/'))
        # the windows that follow (a wait window, then the error): every text seen is collected
        $seen = New-Object System.Collections.ArrayList
        $sw = [Diagnostics.Stopwatch]::StartNew(); $quiet = $null
        while ($sw.Elapsed.TotalSeconds -lt 60) {
            if (-not (Test-Alive $id)) { break }
            $wins = @(Get-Tops $id | Where-Object { $known -notcontains $_ -and [Drv098f]::IsWindowVisible($_) })
            if (-not $wins.Count) {
                if ($seen.Count) { if ($null -eq $quiet) { $quiet = $sw.Elapsed.TotalSeconds } elseif ($sw.Elapsed.TotalSeconds - $quiet -gt 3) { break } }
                Start-Sleep -Milliseconds 200; continue
            }
            $quiet = $null
            foreach ($h in $wins) {
                $d = WinDesc $h
                if ($d -match $FatalRx) { [void]$seen.Add('FATAL ' + $d); break }
                if ($seen -notcontains $d) { [void]$seen.Add($d) }
                if ([Drv098f]::Cls($h) -eq '#32770' -and [Drv098f]::IsWindowEnabled($h)) {
                    $btn = Buttons $h
                    $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
                    if ($ids.Count -eq 1 -and $ids[0] -eq 2 -and $sw.Elapsed.TotalSeconds -lt 30) { continue }   # a wait window: let it work
                    Start-Sleep -Milliseconds 800
                    $pick = $null; foreach ($w in @(2, 1, 7)) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($pick) { break } }
                    if ($pick) { Click $pick } else { Close-Win $h }
                    Start-Sleep -Milliseconds 600
                }
            }
            Start-Sleep -Milliseconds 200
        }
        $all = ($seen -join ' || ')
        $alive = Test-Alive $id
        $shown = $all.Contains($HostName)
        $fatal = [bool]($all -match '^FATAL|\|\| FATAL')
        Row 'FTPPCT' 'TEXT' (V ($alive -and $shown -and -not $fatal)) ("the program runs: {0}; the host name '{1}' is shown as typed: {2}; windows seen: {3}" -f $alive, $HostName, $shown, $(if ($all.Length -gt 1500) { $all.Substring(0, 1500) + ' ...' } else { $all }))
    }
    catch { Row 'FTPPCT' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $f = Fatal-Win $id; End-Row 'FTPPCT' $id $f $before } }
}

$backup = Join-Path $env:TEMP 'tc131_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    Set-Config
    Set-Lang ($Lang + '.slg')
    Out ("batch131_probe (feature 131), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ''
    Row-FtpPct
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}. Left running: {2}; registry restored+identical: {3}" -f $np, $nf, @($Started | Where-Object { Test-Alive $_ }).Count, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
