<#
.SYNOPSIS
    Feature 238 probe: a folder whose name holds %...% is opened as it is - a path on the command line
    or typed into Change Directory expanded the environment variable in it and opened another folder.

.DESCRIPTION
    Fixture: <root>\p%OS%q (the folder) and <root>\pWindows_NTq (the decoy: %OS% expanded); <root>\viaenv,
    named by the environment variable TC238V (set for the program).
      CMDLINE     -l "<root>\p%OS%q": PASS = the panel at p%OS%q
      CMDVAR      -l "%TC238V%": PASS = the panel at viaenv (a variable still expands)
      TYPED       Change Directory "<root>\p%OS%q": PASS = the panel at p%OS%q
      TYPEDVAR    Change Directory "%TC238V%": PASS = the panel at viaenv
      DEEP        Change Directory "<root>\p%OS%q\sub" (both folders hold sub): PASS = p%OS%q's sub
      REL         the panel at <root>, typed "p%OS%q" (relative): PASS = the panel at p%OS%q
      STRAY       the panel at <root>\stray, which holds a folder literally named "%TC238V%" (as some
                  programs create "%APPDATA%"); typed "%TC238V%": PASS = viaenv (the variable wins)
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
$Root = $TempRoot + '\tc238'
$StartDir = $Root + '\start'
$Lit = $Root + '\p%OS%q'
$Decoy = $Root + '\pWindows_NTq'
$ViaEnv = $Root + '\viaenv'
$env:TC238V = $ViaEnv

function Run-Case([string]$Case, [string]$StartArg, [string]$Typed, [string]$Want) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $(if ($StartArg) { $StartArg } else { $StartDir })
        [void](Serve $id 10)
        if ($Typed) { [void](Do-ChangeDir $id $Typed); [void](Serve $id 10) }
        $loc = Get-Loc $id
        $ok = ($loc -ceq $Want)
        Row $Case 'RUN' (V $ok) ("panel at '{0}' (want '{1}')" -f (Esc $loc), (Esc $Want))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc238_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Lit; NewDir $Decoy; NewDir $ViaEnv
    Set-Config
    Out ("pct238_probe (feature 238) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Case 'CMDLINE' $Lit $null $Lit
    Run-Case 'CMDVAR' '%TC238V%' $null $ViaEnv
    Run-Case 'TYPED' $null $Lit $Lit
    Run-Case 'TYPEDVAR' $null '%TC238V%' $ViaEnv
    NewDir ($Lit + '\sub'); NewDir ($Decoy + '\sub')
    Run-Case 'DEEP' $null ($Lit + '\sub') ($Lit + '\sub')
    Run-Case 'REL' $Root 'p%OS%q' $Lit
    NewDir ($Root + '\stray'); NewDir ($Root + '\stray\%TC238V%')
    Run-Case 'STRAY' ($Root + '\stray') '%TC238V%' $ViaEnv
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
