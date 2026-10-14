# Plan: 162

Measure first: drive typed paths around the core's boundary and the plug-in's 300 bytes against
134's FTP server, with the first connect and with a connection open; read every route that hands
the plug-in a user part. Fix only a reachable cut (`plugins/ftp/fs2.cpp` `ChangePath`, a refusal
with `IDS_TOOLONGPATH` - patch prepared). Constitution: PASS (no string, interface, registry or
installer change).

Result: no route reaches the cut - no code change (fix-log.md).
