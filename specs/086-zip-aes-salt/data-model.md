# Data model: 086 — what the random bytes become

No new data and no format change. The bytes this feature changes the source of:

| Item | Where | Size | Produced by | Read back by |
|---|---|---|---|---|
| AES salt (WinZip AE) | in front of each AES-encrypted file's data, after the local header (extra field `0x9901` names the strength) | 8 B (AES-128), 16 B (AES-256) | `add.cpp:1632` → `FillBufferWithRandomData` | `extract.cpp` (from the archive) |
| AES password verifier | right after the salt | 2 B | `AESInit` (derived, not random) | unchanged |
| ZIP 2.0 encryption header | in front of each ZipCrypto-encrypted file's data | 12 B: 11 random bytes drawn, 1–2 check bytes written over the end (10–11 random remain), all encrypted | `crypt.cpp` `CryptHeader` → `FillBufferWithRandomData` | `extract.cpp` (decrypts, checks) |
| Password-manager salts (core) | registry blobs / Master Password verifier | 16 B | `pwdmngr.cpp` (feature 085) | unchanged |

Rules: every item is generated once per file (or per stored password), stored
next to what it protects, and never derived from time or process id.
