<#
.SYNOPSIS
    Feature 305 probe: a shortcut (.lnk) whose target has 260 or more characters on a volume
    without 8.3 names is followed to the WHOLE target - Enter on it and Go to Shortcut Target.

.DESCRIPTION
    The shell answers such a target cut at 259 units ("\\?\E:\...", success); the core followed
    the cut path. The links are written by mklnk305.exe (an item list built folder by folder -
    IShellLinkW::SetPath and WScript.Shell refuse such targets). The fixture lives in the build
    folder (<build>\tc305), not in %TEMP%: the defect exists only on a volume without 8.3 names
    and %TEMP% (C:) has them. Every path the probe types starts with the fixture root.
      ENTER-250   a 250-unit target, Enter                                   (control)
      ENTER-300   a 300-unit target, the cut falls in the middle of the last name, Enter
      ENTER-SEP   a 300-unit target whose 259-unit parent is exactly the cut answer after Resolve, Enter
      FOCUS-300   the 300-unit target, Go to Shortcut Target (838)
      FOCUS-SEP   the same, Go to Shortcut Target (838)
    The panel must end in the target folder itself (compared whole, letter case ignored).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$MkLnk,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$MkLnk = (Resolve-Path -LiteralPath $MkLnk).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$BuildDir = Split-Path (Split-Path (Split-Path $Exe -Parent) -Parent) -Parent   # <build>\tandemcommander\Debug_x64\x.exe
$Root = $BuildDir.TrimEnd('\') + '\tc305'
$StartDir = $Root + '\start'
$LinkDir = $Root + '\links'

Add-Type -Namespace P305 -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
public static extern uint GetShortPathNameW(string longPath, System.Text.StringBuilder shortPath, uint size);
'@

# a target folder of exactly $Len units whose parent has exactly $ParentLen units
function Make-Target([string]$Name, [int]$ParentLen, [int]$Len) {
    $cur = $Root + '\' + $Name
    NewDir $cur
    $parts = @($Name)
    $ch = [char]([int][char]'a' + ($Name.Length % 20))
    while (($ParentLen - $cur.Length - 1) -gt 60) {
        $p = ([string]$ch) * 49; $parts += $p; $cur += '\' + $p; NewDir $cur
    }
    $p = 'p' * ($ParentLen - $cur.Length - 1); $parts += $p; $cur += '\' + $p; NewDir $cur
    $leaf = 'z' * ($Len - $ParentLen - 1); $parts += $leaf; $cur += '\' + $leaf; NewDir $cur
    if ($cur.Length -ne $Len) { throw ("target of {0} units, wanted {1}" -f $cur.Length, $Len) }
    return [pscustomobject]@{ Path = $cur; Parts = $parts; Parent = $cur.Substring(0, $ParentLen) }
}
function Make-Lnk([string]$Lnk, $T) {
    $a = @(('"{0}"' -f $Lnk), ('"{0}"' -f $Root)) + @($T.Parts | ForEach-Object { '"' + $_ + '"' })
    $p = Start-Process -FilePath $MkLnk -ArgumentList $a -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -ne 0) { throw ("mklnk305 exit {0}" -f $p.ExitCode) }
}
function Run-Case([string]$Case, [int]$ParentLen, [int]$Len, [int]$How = 0) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        $t = Make-Target ($Case.ToLower()) $ParentLen $Len
        $lnk = $LinkDir + '\' + $Case.ToLower() + '.lnk'
        Make-Lnk $lnk $t
        $id = Start-Tc $StartDir
        [void](Do-ChangeDir $id $lnk)   # the panel in the links folder, the focus on the shortcut
        [void](Serve $id 5 @(2))
        $loc1 = Get-Loc $id
        if ($How -eq 838) { Post-Cmd (Get-Main $id) 838 } else { Key $id 0x0D }   # Go to Shortcut Target / Enter
        $r = Serve $id 15 @(1)
        $loc = Get-Loc $id
        End-Row $Case $id $null $before; $id = 0
        $ok = $loc.TrimEnd('\') -ieq $t.Path
        $where = $(if ($ok) { 'the target' } elseif ($loc.TrimEnd('\') -ieq $t.Parent) { 'the PARENT of the target (cut on a backslash)' } elseif ($loc.TrimEnd('\') -ieq $LinkDir) { 'still the links folder' } else { 'another folder' })
        Row $Case 'TARGET' (V $ok) ("target {0} units; panel before '{1}', after {2} units '{3}' = {4}; windows: {5}" -f $t.Path.Length, (Tail $loc1 30), $loc.Length, (Tail $loc 40), $where, (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc305_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    NewDir $LinkDir
    Set-Config
    $sb = New-Object Text.StringBuilder 1024
    [void][P305.Native]::GetShortPathNameW($StartDir, $sb, 1024)
    $no83 = $sb.ToString() -ieq $StartDir
    Out ("lnk305_probe (feature 305), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Fixture : {0}; volume without 8.3 names: {1}" -f $Root, $no83)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash)
    Out ''
    if (-not $no83) {
        Row 'ALL' 'VOLUME' 'NOT DRIVEN' 'the fixture volume generates 8.3 names - the shell answers the short form, the cut cannot happen here'
    }
    else {
        Run-Case 'ENTER-250' 200 250
        Run-Case 'ENTER-300' 230 300
        Run-Case 'ENTER-SEP' 259 300
        Run-Case 'FOCUS-300' 230 300 838
        Run-Case 'FOCUS-SEP' 259 300 838
    }
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
