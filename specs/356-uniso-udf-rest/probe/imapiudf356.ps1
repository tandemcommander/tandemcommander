param(
    [Parameter(Mandatory = $true)][string]$SrcDir,
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$Revision = 0x102,
    [string]$Label = 'UDF356',
    [int]$FileSystems = 4
)
# Writes a UDF-only image of $SrcDir with Windows' IMAPI2FS (FsiFileSystemUDF = 4; -FileSystems 1 = ISO 9660 only)
$ErrorActionPreference = 'Stop'
if (-not ('Imapi356.Stream' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
namespace Imapi356 {
public static class Stream {
    public static void Save(object o, string path) {
        IStream s = (IStream)o;
        byte[] buf = new byte[65536];
        IntPtr pRead = Marshal.AllocHGlobal(4);
        try {
            using (FileStream f = File.Create(path)) {
                while (true) {
                    s.Read(buf, buf.Length, pRead);
                    int n = Marshal.ReadInt32(pRead);
                    if (n <= 0) break;
                    f.Write(buf, 0, n);
                }
            }
        } finally { Marshal.FreeHGlobal(pRead); }
    }
}
}
'@
}
$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = $FileSystems
$fsi.UDFRevision = $Revision
$fsi.VolumeName = $Label
$fsi.FreeMediaBlocks = 0
$fsi.Root.AddTree($SrcDir, $false)
$res = $fsi.CreateResultImage()
[Imapi356.Stream]::Save($res.ImageStream, $Out)
Write-Output ("{0}: {1} bytes, {2} blocks" -f $Out, (Get-Item $Out).Length, $res.TotalBlocks)
