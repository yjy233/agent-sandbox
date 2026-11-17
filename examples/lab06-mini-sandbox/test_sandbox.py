"""lab06 测试：做一点测一点。
python3 -m unittest test_sandbox -v
平台不符的用例自动 skip。
"""
import os
import platform
import shutil
import tempfile
import unittest

import sandbox

IS_MAC = platform.system() == "Darwin" and shutil.which("sandbox-exec")
IS_LINUX = platform.system() == "Linux" and shutil.which("bwrap")
PY = "/usr/bin/python3" if platform.system() == "Darwin" else "python3"
NET_CMD = [PY, "-c",
           'import socket; socket.create_connection(("1.1.1.1", 443), timeout=3); print("CONNECTED")']


class TestProfileGeneration(unittest.TestCase):
    """step1: policy -> profile 生成（跨平台纯逻辑）"""

    def setUp(self):
        self.ws = os.path.realpath(tempfile.mkdtemp())
        self.policy = {"workspace": self.ws}

    def test_deny_default(self):
        self.assertIn("(deny default)", sandbox.build_profile(self.policy))

    def test_workspace_in_reads_and_writes(self):
        p = sandbox.build_profile(self.policy)
        self.assertIn(f'(subpath "{self.ws}")', p)
        self.assertIn('(param "WORKSPACE")', p)

    def test_network_denied(self):
        self.assertIn("(deny network*)", sandbox.build_profile(self.policy))

    def test_extra_read_paths(self):
        self.policy["extra_read_paths"] = ["/opt/tools"]
        self.assertIn('(subpath "/opt/tools")', sandbox.build_profile(self.policy))


@unittest.skipUnless(IS_MAC, "需要 macOS + sandbox-exec")
class TestMacOSBackend(unittest.TestCase):
    """step2-4: macOS 后端集成测试"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.ws = os.path.join(self.tmp.name, "workspace")
        os.makedirs(self.ws)
        self.secret = os.path.join(self.tmp.name, "secret.txt")
        with open(self.secret, "w") as f:
            f.write("FAKE-SECRET-DO-NOT-LEAK")
        self.policy = {"workspace": self.ws}

    def tearDown(self):
        self.tmp.cleanup()

    def test_step2_echo_runs(self):
        r = sandbox.run(["/bin/echo", "agent-ok"], self.policy)
        self.assertEqual(r.returncode, 0)
        self.assertIn("agent-ok", r.stdout)

    def test_step3_write_inside_ok(self):
        r = sandbox.run(["/usr/bin/touch", os.path.join(self.ws, "ok.txt")], self.policy)
        self.assertEqual(r.returncode, 0)

    def test_step3_write_outside_denied(self):
        r = sandbox.run(["/usr/bin/touch", "/tmp/lab06-should-fail.txt"], self.policy)
        self.assertNotEqual(r.returncode, 0)

    def test_step4_secret_unreadable(self):
        r = sandbox.run(["/bin/cat", self.secret], self.policy)
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn("FAKE-SECRET", r.stdout + r.stderr)

    def test_step4_network_denied(self):
        r = sandbox.run(NET_CMD, self.policy)
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn("CONNECTED", r.stdout)


@unittest.skipUnless(IS_LINUX, "需要 Linux + bwrap")
class TestLinuxBackend(unittest.TestCase):
    """Linux 后端集成测试（bwrap 内路径为 /workspace）"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.ws = os.path.join(self.tmp.name, "workspace")
        os.makedirs(self.ws)
        self.policy = {"workspace": self.ws}

    def tearDown(self):
        self.tmp.cleanup()

    def test_echo_runs(self):
        r = sandbox.run(["/bin/sh", "-c", "echo agent-ok"], self.policy)
        self.assertEqual(r.returncode, 0)
        self.assertIn("agent-ok", r.stdout)

    def test_write_inside_ok(self):
        r = sandbox.run(["/bin/sh", "-c", "touch /workspace/ok.txt"], self.policy)
        self.assertEqual(r.returncode, 0)

    def test_host_not_visible(self):
        r = sandbox.run(["/bin/sh", "-c", "test -e /home"], self.policy)
        self.assertNotEqual(r.returncode, 0)

    def test_network_denied(self):
        r = sandbox.run(["/bin/bash", "-c", "exec 3<>/dev/tcp/1.1.1.1/443"], self.policy)
        self.assertNotEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)