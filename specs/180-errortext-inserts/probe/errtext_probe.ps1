<#
.SYNOPSIS
    Feature 180 probe: an error whose Windows text has inserts (193 "%1 is not a valid Win32
    application.") is shown with its text, not "System error 193, text description is not
    available."

.DESCRIPTION
    PLUGIN: Plugins > Plugins Manager (815), Add (2602), the open dialog given fake.spl (a text file,
    not a DLL - LoadLibrary fails with 193), Open. The error box's text is read. PASS = it holds
    "(193)", no fallback text and no '%'. The dialogs are cancelled; the registry is restored.
    (An Enter on a fake .exe in the panel goes to the shell, which shows its own window - not this
    text.)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc180'
$StartDir = $Root + '\start'
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function NameBox([IntPtr]$Dlg) {
    if (-not (Kid $Dlg 1121 $null)) { return $null }
    return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::Cls([Drv098f]::GetParent($_)) -match 'ComboBox' -and ([Drv098f]::GetDlgCtrlID($_) -eq 1001 -or [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148) }) | Select-Object -First 1
}

$backup = Join-Path $env:TEMP 'tc180_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("errtext_probe (feature 180), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    $d = $Root + '\plug'; NewDir $d
    WriteFile ($d + '\fake.spl') 'this is not a DLL'
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        $pm = Open-ByCmd $id 815 10
        if ($pm -eq [IntPtr]::Zero) { Row 'PLUGIN' 'TEXT' 'NOT DRIVEN' 'no Plugins Manager'; throw 'no dialog' }
        $known = Get-Tops $id
        Post-Cmd $pm 2602
        $od = [IntPtr]::Zero
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $od -eq [IntPtr]::Zero) {
            $c = @(Get-Tops $id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
            if ($c -and (NameBox $c)) { $od = $c }
            Start-Sleep -Milliseconds 300
        }
        if ($od -eq [IntPtr]::Zero) { Row 'PLUGIN' 'TEXT' 'NOT DRIVEN' 'no open dialog'; throw 'no open dialog' }
        Start-Sleep -Milliseconds 600
        [void][Drv098f]::SetText((NameBox $od), ($d + '\fake.spl'), 5000)
        $ok1 = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
        if ($ok1) { Click $ok1 } else { Post-Cmd $od 1 }
        # the error box(es): OK; the Plugins Manager stays - not answered by Serve (no OK/Yes wanted)
        $msgs = New-Object System.Collections.ArrayList
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15) {
            $b = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $pm -and [Drv098f]::IsWindowVisible($_) -and -not (NameBox $_) }) | Select-Object -First 1
            if ($b) {
                Start-Sleep -Milliseconds 600
                [void]$msgs.Add((WinDesc $b))
                $okb = Buttons $b | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
                if ($okb) { Click $okb } else { Close-Win $b }
                Start-Sleep -Milliseconds 800
                continue
            }
            if ($msgs.Count) { break }
            Start-Sleep -Milliseconds 200
        }
        Post-Cmd $pm 2; Start-Sleep -Milliseconds 800
        End-Row 'PLUGIN' $id $null $before; $id = 0
        $m = ($msgs -join ' || ')
        $ok = ($m -match '\(193\)') -and ($m -notmatch 'text description is not available') -and ($m -notmatch '%')
        Row 'PLUGIN' 'TEXT' (V $ok) ("windows: {0}" -f $(if ($m) { $m } else { 'none' }))
    }
    catch { if ($_.Exception.Message -notmatch '^no ') { Row 'PLUGIN' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
    finally { if ($id) { End-Row 'PLUGIN' $id $null $before } }
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
if ($Expect -eq 'before') { exit 0 }
exit $nf
