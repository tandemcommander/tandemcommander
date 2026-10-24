# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Every script in bin/ answers --help: what it is for and how to run it.

Run from the repository root:  python -m unittest tools/test_bin_help.py -v
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

BIN = Path(__file__).resolve().parents[1] / "bin"


def git_bash():
    """Git's bash (on Windows `bash` on PATH may be WSL's)."""
    if os.name != "nt":
        return shutil.which("bash")
    exe = shutil.which("git")
    if exe:
        for up in Path(exe).resolve().parents[:3]:
            cand = up / "bin" / "bash.exe"
            if cand.is_file():
                return str(cand)
    return None


def runner(script: Path):
    """The command line that runs the script, or None when no runner is known for its kind."""
    suffix = script.suffix.lower()
    if suffix == ".sh":
        bash = git_bash()
        return [bash, str(script)] if bash else None
    if suffix == ".py":
        return ["python", str(script)]
    if suffix in (".cmd", ".bat"):
        return ["cmd", "/c", str(script)]
    if suffix == ".ps1":
        return ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script)]
    return None


class BinHelpTests(unittest.TestCase):
    def test_every_script_answers_help(self):
        scripts = sorted(p for p in BIN.iterdir() if p.is_file())
        self.assertTrue(scripts, "bin/ holds no script")
        for script in scripts:
            with self.subTest(script.name):
                cmd = runner(script)
                self.assertIsNotNone(cmd, f"bin/{script.name}: no runner for this kind of script (or no Git Bash)")
                r = subprocess.run([*cmd, "--help"], capture_output=True, text=True, encoding="utf-8",
                                   cwd=BIN.parent, timeout=60)
                self.assertEqual(r.returncode, 0, f"bin/{script.name} --help: exit {r.returncode}\n{r.stderr}")
                self.assertIn("usage", r.stdout.lower(), f"bin/{script.name} --help prints no usage")
                self.assertGreaterEqual(len(r.stdout.strip().splitlines()), 3,
                                        f"bin/{script.name} --help says too little")


if __name__ == "__main__":
    unittest.main()
