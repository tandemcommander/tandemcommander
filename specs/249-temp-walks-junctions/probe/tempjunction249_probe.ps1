<#
.SYNOPSIS
    Feature 249 probe: removing a temporary folder and the external unpacker's walk never go
    through a junction - the junction's TARGET keeps its files.

.DESCRIPTION
    Fixture under %TEMP%\tc249: victim folders holding keep.txt, each reached only through a junction
    planted by the probe (or by the fake unpacker).
      SWEEP    the start-up sweep of SAL*.tmp folders (ClearTEMPIfNeeded, feature 212): the program is
               started with TMP / TEMP = <fixture>\tmp holding SAL249A.tmp\{plain.txt, lnk -> victimS};
               the question "delete ... temporary directories" answered Yes (button 3).
               PASS = SAL249A.tmp removed (the sweep ran - the control) and victimS\keep.txt kept.
      UNPACK   the external unpacker's walk (PackUniversalUncompress, pack1.cpp): the 7-Zip executable
               of the archiver configuration points to a fake 7z.exe built here. "l" runs the real
               7z.exe (the listing of t.arj, a 7z archive holding top\a.txt); "x" plays an unpacker
               that restores a junction: it creates <-o folder>\top -> victimU. The left panel shows
               t.arj\top, select all, F5 to <fixture>\out, OK.
               PASS = victimU\keep.txt kept, out holds no keep.txt and no PACK*.tmp folder is left.
               (Before the fix the walk entered "top" and moved victimU's files into out.)
      DEEP     as UNPACK one level deeper: the archive holds a\top\a.txt, the panel shows t.arj\a\top, the
               fake "x" creates a real folder a and the junction a\top -> victimU.
               PASS of UNPACK and DEEP also needs the error "System error: <...top>: ..." (the refusal).
      PLAIN    the control of UNPACK: the fake "x" creates a real folder top\a.txt - unpacked as before
               (and no "System error" message)
               (out\a.txt, no PACK*.tmp left).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe',
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
if (-not $Lib) { $Lib = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. $Lib
$Root = $TempRoot + '\tc249'
$StartDir = $Root + '\start'
$Fake = $Root + '\fake\7z.exe'
$FakeCfg = $Root + '\fake\fake7z.cfg'
$RegPredef = 'HKCU:\Software\Tandem Commander\Settings\Packers & Unpackers\Predefined Packers'
$RegAssoc = 'HKCU:\Software\Tandem Commander\Settings\Packers & Unpackers\Archive Association'

$FakeSource = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
public static class Fake7z
{
    // fake7z.cfg: line 1 the real 7z.exe, line 2 the mode ("junction" or "plain"), line 3 the junction's target
    public static int Main(string[] args)
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string[] cfg = File.ReadAllLines(Path.Combine(dir, "fake7z.cfg"));
        File.AppendAllText(Path.Combine(dir, "fake7z.log"), string.Join(" | ", args) + Environment.NewLine);
        if (args.Length > 0 && args[0] == "x")
        {
            string outDir = null;
            foreach (string a in args) if (a.StartsWith("-o")) outDir = a.Substring(2).Trim('"');
            if (outDir == null) return 2;
            // line 4: the folders above "top" in the archive ("" or "a")
            string parent = cfg.Length > 3 && cfg[3].Length > 0 ? Path.Combine(outDir, cfg[3]) : outDir;
            Directory.CreateDirectory(parent);
            string top = Path.Combine(parent, "top");
            if (cfg[1] == "junction")
            {
                var p = Process.Start(new ProcessStartInfo("cmd.exe", "/c mklink /J \"" + top + "\" \"" + cfg[2] + "\"") { UseShellExecute = false, CreateNoWindow = true });
                p.WaitForExit();
                return p.ExitCode == 0 ? 0 : 2;
            }
            Directory.CreateDirectory(top);
            File.WriteAllText(Path.Combine(top, "a.txt"), "A");
            return 0;
        }
        // the listing: the real 7z.exe with the same arguments, its output passed through
        string cmd = Environment.CommandLine;
        int i = 0;
        if (cmd.Length > 0 && cmd[0] == '"') { i = cmd.IndexOf('"', 1) + 1; } else { while (i < cmd.Length && cmd[i] != ' ') i++; }
        var psi = new ProcessStartInfo(cfg[0], cmd.Substring(i).TrimStart()) { UseShellExecute = false, RedirectStandardOutput = true, CreateNoWindow = true };
        var q = Process.Start(psi);
        Stream o = Console.OpenStandardOutput();
        q.StandardOutput.BaseStream.CopyTo(o);
        o.Flush();
        q.WaitForExit();
        return q.ExitCode;
    }
}
'@

# Predefined Packers\<n> of the 7-Zip archiver (Packer UID 13): its "Packer Executable"
function Set-7zExe([string]$Path) {
    foreach ($k in (Get-ChildItem -LiteralPath $RegPredef -ErrorAction SilentlyContinue)) {
        if ((Get-ItemProperty -LiteralPath $k.PSPath -Name 'Packer UID' -ErrorAction SilentlyContinue).'Packer UID' -eq 13) {
            Set-ItemProperty -LiteralPath $k.PSPath -Name 'Packer Executable' -Value $Path
            return $true
        }
    }
    return $false
}
# the "arj" association unpacks with the 7-Zip archiver (index 0)
function Get-ArjUnpacker {
    foreach ($k in (Get-ChildItem -LiteralPath $RegAssoc -ErrorAction SilentlyContinue)) {
        $p = Get-ItemProperty -LiteralPath $k.PSPath
        if ($p.'Extension List' -eq 'arj') { return [int]$p.'Unpacker Index' }
    }
    return $null
}

function Start-Mine([string[]]$A) {
    $p = Start-Process -FilePath $Exe -ArgumentList $A -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    return $p.Id
}

function Junction([string]$Link, [string]$Target) {
    if (-not $Link.StartsWith($Root + '\') -or -not $Target.StartsWith($Root + '\')) { throw "junction outside the fixture: $Link -> $Target" }
    & cmd.exe /c "mklink /J `"$Link`" `"$Target`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "mklink /J failed: $Link" }
}

function Run-Sweep {
    if (-not (Want 'SWEEP')) { return }
    $d = $Root + '\SWEEP'; $tmp = $d + '\tmp'; $sal = $tmp + '\SAL249A.tmp'; $victim = $d + '\victimS'
    NewDir $sal; NewDir $victim
    WriteFile ($victim + '\keep.txt') 'KEEP'
    WriteFile ($sal + '\plain.txt') 'P'
    Junction ($sal + '\lnk') $victim
    $id = 0; $before = Reports
    $oldTmp = $env:TMP; $oldTemp = $env:TEMP
    try {
        # "Reload Environment Variables" (on by default) rebuilds the environment from the registry at
        # start - TMP would be the user's again and the sweep would look into the real %TEMP%
        & reg.exe add "$RegKey\Settings\Configuration" /v 'Reload Environment Variables' /t REG_DWORD /d 0 /f | Out-Null
        $env:TMP = $tmp; $env:TEMP = $tmp
        try { $id = Start-Mine @('-t', 'T249', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1') }
        finally { $env:TMP = $oldTmp; $env:TEMP = $oldTemp }
        # the question comes late in the start-up (after the plug-ins and the configuration)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $q = @()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id) -and $q.Count -eq 0) { Start-Sleep -Milliseconds 200; $q = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' }) }
        $asked = $false; $first = 'no question'
        if ($q.Count) {
            Start-Sleep -Milliseconds 600
            $first = WinDesc $q[0]
            # Yes (3) only for exactly the one fixture folder - never the user's own SAL*.tmp folders
            $asked = $first -match 'delete 1 temporary directory'
            $b = Buttons $q[0] | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $(if ($asked) { 3 } else { 4 }) } | Select-Object -First 1
            if ($b) { Click $b } else { Close-Win $q[0] }
        }
        $r = Serve $id 20 @(1)
        $msgs = $first + ' || ' + (Msgs $r)
        End-Row 'SWEEP' $id $r.Fatal $before; $id = 0
        $swept = -not [IO.Directory]::Exists($LP + $sal)
        $kept = [IO.File]::Exists($LP + $victim + '\keep.txt')
        Row 'SWEEP' 'RUN' (V ($asked -and $swept -and $kept)) ("asked {0}; SAL249A.tmp removed {1}; victim keep.txt kept {2}; windows: {3}" -f $asked, $swept, $kept, $msgs)
    }
    catch { Row 'SWEEP' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'SWEEP' $id $null $before } }
}

function Run-Unpack([string]$Case, [string]$Mode, [string]$Above = '') {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case; $victim = $d + '\victimU'; $out = $d + '\out'; $arcSrc = $d + '\arcsrc'
    $first = 'top'; $inner = 'top'; if ($Above) { $first = $Above; $inner = $Above + '\top' }   # the folder the panel shows inside the archive
    NewDir $victim; NewDir $out; NewDir ($arcSrc + '\' + $inner)
    WriteFile ($victim + '\keep.txt') 'KEEP'
    WriteFile ($arcSrc + '\' + $inner + '\a.txt') 'A'
    $arc = $d + '\t.arj'
    Push-Location -LiteralPath $arcSrc
    try { & $SevenZip a -t7z ($d + '\t.7z') $first | Out-Null } finally { Pop-Location }
    Move-Item -LiteralPath ($d + '\t.7z') -Destination $arc
    [IO.File]::WriteAllLines($FakeCfg, [string[]]@($SevenZip, $Mode, $victim, $Above))
    $id = 0; $before = Reports
    try {
        $id = Start-Mine @('-t', 'T249', '-l', ('"{0}"' -f ($arc + '\' + $inner)), '-r', ('"{0}"' -f $out), '-p', '1')
        Start-Sleep -Milliseconds 2500
        [void](Serve $id 10)
        Post-Cmd (Get-Main $id) 842   # CM_ACTIVESELECTALL
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 727   # CM_COPYFILES (F5)
        $r = Serve $id 40 @(1, 6)
        $msgs = Msgs $r
        End-Row $Case $id $r.Fatal $before; $id = 0
        $kept = [IO.File]::Exists($LP + $victim + '\keep.txt')
        $moved = [IO.File]::Exists($LP + $out + '\keep.txt')
        $left = @([IO.Directory]::GetDirectories($LP + $out, 'PACK*.tmp')).Count
        $outNames = (@([IO.Directory]::GetFileSystemEntries($LP + $out) | ForEach-Object { [IO.Path]::GetFileName($_) }) -join ',')
        $log = ''; if (Test-Path -LiteralPath ($Root + '\fake\fake7z.log')) { $log = ((Get-Content -LiteralPath ($Root + '\fake\fake7z.log') | ForEach-Object { ($_ -split ' \| ')[0] }) -join ',') }
        $refused = $msgs -match 'System error: [^|]*top'
        if ($Mode -eq 'junction') { $ok = $kept -and -not $moved -and $left -eq 0 -and $refused }
        else { $ok = [IO.File]::Exists($LP + $out + '\a.txt') -and $left -eq 0 -and $kept -and -not ($msgs -match 'System error') }
        Row $Case 'RUN' (V $ok) ("victim keep.txt kept {0}; moved into out {1}; out [{2}]; PACK*.tmp left {3}; refused with a message {4}; fake 7z calls [{5}]; windows: {6}" -f $kept, $moved, $outNames, $left, $refused, $log, $msgs)
        Remove-Item -LiteralPath ($Root + '\fake\fake7z.log') -ErrorAction SilentlyContinue
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

# removes the fixture without walking a junction (a junction is removed as a link first)
function Remove-Fixture {
    if (-not [IO.Directory]::Exists($LP + $Root)) { return }
    foreach ($j in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue)) { [IO.Directory]::Delete($LP + $j.FullName, $false) }
    [IO.Directory]::Delete($LP + $Root, $true)
}

$backup = Join-Path $env:TEMP 'tc249_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    Remove-Fixture
    NewDir $StartDir; NewDir ($Root + '\fake')
    Add-Type -TypeDefinition $FakeSource -OutputAssembly $Fake -OutputType ConsoleApplication
    Set-Config
    Out ("tempjunction249_probe (feature 249) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; 7-Zip {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $SevenZip)
    $set = Set-7zExe $Fake
    $arj = Get-ArjUnpacker
    Out ("Config  : 7-Zip executable set to the fake {0}; arj unpacker index {1} (0 = the 7-Zip archiver)" -f $set, $arj)
    Out ''
    Run-Sweep
    if ($set -and $arj -eq 0) { Run-Unpack 'PLAIN' 'plain'; Run-Unpack 'UNPACK' 'junction'; Run-Unpack 'DEEP' 'junction' 'a' }
    else { Row 'UNPACK' 'SETUP' 'NOT DRIVEN' 'the archiver configuration has no 7-Zip archiver for arj' }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { Remove-Fixture } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
