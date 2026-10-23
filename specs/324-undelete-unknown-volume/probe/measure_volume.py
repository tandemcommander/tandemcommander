# Measurement for backlog item undelete-skips-its-same-partition-warning-when-the-target.
# Reproduces the Win32 facts PathsAreOnTheSameVolume (src/salamdr1.cpp) depends on:
#   - its reparse walk (GetReparsePointDestination) classifies a junction whose substitute name starts
#     "\??\Volume" as a MOUNT POINT and then may not cut the path (cutResPathIsPossible = FALSE);
#   - it asks GetVolumeNameForVolumeMountPoint - the A function (the core is built without UNICODE)
#     with the UTF-8 path - for that folder; when that fails, the volume of the path "cannot be told"
#     and the core answers "different volumes" when the other path's volume was read.
# Usage: python measure_volume.py <fixture folder under %TEMP%>
import ctypes, ctypes.wintypes as wt, os, struct, sys

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.CreateFileW.restype = wt.HANDLE
k32.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, ctypes.c_void_p, wt.DWORD, wt.DWORD, wt.HANDLE]
k32.DeviceIoControl.argtypes = [wt.HANDLE, wt.DWORD, ctypes.c_void_p, wt.DWORD, ctypes.c_void_p, wt.DWORD,
                                ctypes.POINTER(wt.DWORD), ctypes.c_void_p]
k32.GetVolumeNameForVolumeMountPointW.argtypes = [wt.LPCWSTR, wt.LPWSTR, wt.DWORD]
k32.GetVolumeNameForVolumeMountPointA.argtypes = [ctypes.c_char_p, ctypes.c_char_p, wt.DWORD]
k32.CloseHandle.argtypes = [wt.HANDLE]
INVALID = wt.HANDLE(-1).value
FSCTL_SET_REPARSE_POINT = 0x000900A4
IO_REPARSE_TAG_MOUNT_POINT = 0xA0000003


def make_junction(link, subst, printname):
    os.mkdir(link)
    h = k32.CreateFileW(link, 0x40000000, 0, None, 3, 0x02000000 | 0x00200000, None)
    if h == INVALID:
        raise OSError(ctypes.get_last_error(), "open " + link)
    s = subst.encode("utf-16-le")
    p = printname.encode("utf-16-le")
    pathbuf = s + b"\0\0" + p + b"\0\0"
    data = struct.pack("<HHHH", 0, len(s), len(s) + 2, len(p)) + pathbuf
    buf = struct.pack("<IHH", IO_REPARSE_TAG_MOUNT_POINT, len(data), 0) + data
    ret = wt.DWORD(0)
    ok = k32.DeviceIoControl(h, FSCTL_SET_REPARSE_POINT, buf, len(buf), None, 0, ctypes.byref(ret), None)
    err = ctypes.get_last_error()
    k32.CloseHandle(h)
    if not ok:
        raise OSError(err, "FSCTL_SET_REPARSE_POINT " + link)


def vol_w(path):
    b = ctypes.create_unicode_buffer(100)
    ok = k32.GetVolumeNameForVolumeMountPointW(path, b, 100)
    return b.value if ok else "FAIL(%d)" % ctypes.get_last_error()


def vol_a_utf8(path):
    b = ctypes.create_string_buffer(100)
    ok = k32.GetVolumeNameForVolumeMountPointA(path.encode("utf-8"), b, 100)
    return b.value.decode("ascii", "replace") if ok else "FAIL(%d)" % ctypes.get_last_error()


def main():
    root = os.path.abspath(sys.argv[1])
    if not root.lower().startswith(os.environ["TEMP"].lower()):
        sys.exit("fixture must be under %TEMP%")
    os.makedirs(root, exist_ok=False)
    tgt = os.path.join(root, "tgt")
    os.mkdir(tgt)
    drive = root[:3]
    cguid = vol_w(drive)
    print("volume of", drive, "=", cguid)
    rest = tgt[3:]
    # J1: a junction to a folder written as a volume GUID path (ASCII name; no admin needed)
    j1 = os.path.join(root, "jsub")
    make_junction(j1, "\\??\\" + cguid[4:] + rest, "")
    # J2: a junction to the volume root (what a mount folder is) under a non-ASCII name
    j2 = os.path.join(root, "Zálohy")
    try:
        make_junction(j2, "\\??\\" + cguid[4:], "")
        j2ok = True
    except OSError as e:
        print("J2 not created:", e)
        j2ok = False
    rows = [("ROOT", drive), ("J1 jsub\\", j1 + "\\")]
    if j2ok:
        rows.append(("J2 Zálohy\\", j2 + "\\"))
    for name, p in rows:
        print("%-12s W=%s  A(UTF-8)=%s" % (name, vol_w(p), vol_a_utf8(p)))
    # the target folders really are on the drive's volume (written through the link, read directly)
    with open(os.path.join(j1, "probe.txt"), "w") as f:
        f.write("x")
    print("J1 write lands in", tgt, ":", os.path.exists(os.path.join(tgt, "probe.txt")))


main()
