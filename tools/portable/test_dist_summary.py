# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Tests of tools/portable/dist_summary.py and make_portable_zip.py (feature 428).

Run from the repository root:  python -m unittest tools/portable/test_dist_summary.py -v

dist_summary runs on a temporary setup\\output and build folder: a published installer of the same
name that this run did not write is never removed, a file this run wrote is, and "DIST OK" needs
both files written by this run.
"""

import contextlib
import io
import os
import sys
import tempfile
import time
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dist_summary as D  # noqa: E402
import make_portable_zip as M  # noqa: E402


class DistSummary(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = os.path.join(self.tmp.name, "output")
        os.makedirs(self.out)
        self.old_output, self.old_env = D.OUTPUT, os.environ.get("OPENSAL_BUILD_DIR")
        D.OUTPUT = self.out
        self.old_released = D.released
        D.released = lambda ver: False  # the repository's own tag of the tree's version must not matter here
        self.old_cert = D.certificate_present
        D.certificate_present = lambda: True
        self.old_dir = D.build_dir_is_default
        D.build_dir_is_default = lambda: True  # the test's own folders
        os.environ["OPENSAL_BUILD_DIR"] = os.path.join(self.tmp.name, "build") + os.sep
        self.ver, _ = D.read_version()
        self.files = D.release_files(self.ver)

    def tearDown(self):
        D.OUTPUT = self.old_output
        D.released = self.old_released
        D.certificate_present = self.old_cert
        D.build_dir_is_default = self.old_dir
        if self.old_env is None:
            os.environ.pop("OPENSAL_BUILD_DIR", None)
        else:
            os.environ["OPENSAL_BUILD_DIR"] = self.old_env
        self.tmp.cleanup()

    def run_main(self, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = D.main(["dist_summary.py"] + list(args))
        return code, buf.getvalue()

    def write(self, key, age=0):
        with open(self.files[key], "wb") as f:
            f.write(b"x" * 10)
        if age:
            t = time.time() - age
            os.utime(self.files[key], (t, t))

    def test_earlier_build_is_set_aside_never_deleted(self):
        self.write("setup", age=3600)  # an earlier dist of the same (unreleased) version
        self.write("portable", age=3600)
        self.run_main("--start")
        self.run_main("--remove-partial", "setup")
        kept = [n for n in os.listdir(self.out) if ".before-dist-" in n]
        self.assertEqual(len(kept), 2, kept)  # both kept under another name
        self.assertFalse(os.path.exists(self.files["setup"]))  # nothing finished-looking stays
        code, text = self.run_main()
        self.assertEqual(code, 1)

    def test_start_refuses_when_git_cannot_tell(self):
        D.released = lambda ver: None
        code, text = self.run_main("--start")
        self.assertEqual(code, 1)
        self.assertIn("cannot tell", text)

    def test_start_refuses_without_the_certificate(self):
        D.certificate_present = lambda: False
        code, text = self.run_main("--start")
        self.assertEqual(code, 1)
        self.assertIn("certificate", text)

    def test_start_refuses_another_build_folder(self):
        D.build_dir_is_default = self.old_dir  # the real rule: the test's folder is not the repository's
        code, text = self.run_main("--start")
        self.assertEqual(code, 1)
        self.assertIn("default build folder", text)

    def test_file_of_this_run_is_removed(self):
        self.run_main("--start")
        self.write("portable")
        with open(self.files["portable"] + ".part", "wb") as f:
            f.write(b"p")
        code, text = self.run_main("--remove-partial", "portable")
        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(self.files["portable"]))
        self.assertFalse(os.path.exists(self.files["portable"] + ".part"))
        self.assertIn("removed", text)

    def test_ok_only_with_both_files_of_this_run(self):
        self.run_main("--start")
        self.write("setup")
        code, text = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("missing", text)
        self.write("portable")
        code, text = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("DIST OK", text)
        self.assertIn("SHA-256", text)

    def test_stale_file_is_not_ok(self):
        self.run_main("--start")
        self.write("setup", age=3600)  # a file of another time (copied in by hand during the run)
        self.write("portable")
        code, text = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("not written by this run", text)

    def test_start_refuses_a_released_version(self):
        D.released = lambda ver: True
        code, text = self.run_main("--start")
        self.assertEqual(code, 1)
        self.assertIn("already released", text)
        self.assertFalse(os.path.exists(D.start_file()))

    def test_built_before_failure_lists_only_this_run(self):
        self.write("portable", age=3600)
        self.run_main("--start")
        self.write("setup")
        code, text = self.run_main("--built-before-failure")
        self.assertIn("setup.exe", text)
        self.assertNotIn("portable.zip", text)


class PortableZipRules(unittest.TestCase):
    def test_excluded(self):
        for rel in ("tandemcommander.pdb", "plugins/zip/zip.lib", "Intermediate/x.obj", "settings/tandemcommander.reg",
                    "utils/salextx64.dll", "plugins/a/obj/b.txt", "x.iobj", "x.ipdb", "x.ilk", "x.exp"):
            self.assertTrue(M.excluded(rel), rel)
        for rel in ("tandemcommander.exe", "plugins/zip/zip.spl", "lang/czech.slg", "utils/sqlite.dll",
                    "convert/cp1250.tab", "toolbars/a.bmp", "settingsfoo/x.txt"):
            self.assertFalse(M.excluded(rel), rel)

    def test_refuses_a_tree_without_the_portable_exe(self):
        with tempfile.TemporaryDirectory() as t:
            tree = os.path.join(t, "tree")
            os.makedirs(tree)
            out = os.path.join(t, "p.zip")
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                self.assertEqual(M.main(["m", tree, out]), 1)  # no exe
            with open(os.path.join(tree, "tandemcommander.exe"), "wb") as f:
                f.write(b"MZ not a real program")
            with contextlib.redirect_stdout(buf):
                self.assertEqual(M.main(["m", tree, out]), 1)  # not the portable edition
            self.assertFalse(os.path.exists(out))
            self.assertFalse(os.path.exists(out + ".part"))
            self.assertIn("not the portable edition", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
