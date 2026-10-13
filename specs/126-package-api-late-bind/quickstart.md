# Quickstart: validating feature 126

```powershell
cmd /c "E:\Projects\tandemcommander\build.cmd"            # Debug
cmd /c "E:\Projects\tandemcommander\build.cmd release"    # Release

build\tandemcommander\Debug_x64\saltests\saltests.exe      # all checks pass (TestPackageApi126 among them)

# import tables: nothing in the Release tree needs the two functions at load time
python specs\126-package-api-late-bind\probe\pe_imports.py check build\tandemcommander\Release_x64 GetPackagesByPackageFamily GetPackagePathByFullName
#   -> exit code 0

# the real lookup on Windows 11 still answers what Windows reports
powershell -NoProfile -ExecutionPolicy Bypass -File specs\126-package-api-late-bind\probe\package_live.ps1
```

Owed to a person with Windows 7 SP1 / Server 2008 R2 SP1: start the 0.1.10 build there (the
main window appears; Options > Configuration > Command Shell lists the ordinary shells).
