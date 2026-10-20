<#
.SYNOPSIS
    Feature 267: what WIC reports for real camera files - the queries the engine uses
    (/app1/ifd present; /app1/ifd/{ushort=274}; /app1/ifd/exif/{ushort=40962} / {ushort=40963}),
    through WPF's BitmapMetadata (the same WIC metadata query language). Windows PowerShell 5.1.

    powershell -NoProfile -File real267_wic.ps1 -Root <folder>
    One line per file: "<relative path>|wicexif=<0/1>|orient=<n or ->|dims=<WxH or ->". ASCII.
#>
param([Parameter(Mandatory = $true)][string]$Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
function Q($md, [string]$q) { try { return $md.GetQuery($q) } catch { return $null } }
foreach ($f in Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -match '^\.jpe?g$' } | Sort-Object FullName) {
    $rel = $f.FullName.Substring($Root.Length + 1).Replace('\', '/')
    $line = $rel + '|'
    $s = $null
    try {
        $s = [IO.File]::OpenRead($f.FullName)
        $dec = [Windows.Media.Imaging.BitmapDecoder]::Create($s, [Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [Windows.Media.Imaging.BitmapCacheOption]::None)
        $md = $dec.Frames[0].Metadata
        $has = if ($null -ne $md -and $null -ne (Q $md '/app1/ifd')) { 1 } else { 0 }
        $o = if ($md) { Q $md '/app1/ifd/{ushort=274}' } else { $null }
        $w = if ($md) { Q $md '/app1/ifd/exif/{ushort=40962}' } else { $null }
        $h = if ($md) { Q $md '/app1/ifd/exif/{ushort=40963}' } else { $null }
        $line += ('wicexif={0}|orient={1}|dims={2}' -f $has, $(if ($null -ne $o) { $o } else { '-' }), $(if ($null -ne $w -and $null -ne $h) { '{0}x{1}' -f $w, $h } else { '-' }))
    }
    catch { $line += 'ERROR=' + ($_.Exception.Message -replace '[^\x20-\x7e]', '?') }
    finally { if ($s) { $s.Dispose() } }
    Write-Output $line
}
