#!/usr/bin/env python3
"""lab06: 统一沙箱封装 —— policy 描述意图，后端负责实现。

用法（库）:
    from sandbox import run
    r = run(["/bin/echo", "hi"], {"workspace": "/abs/ws"})

用法（CLI）:
    python3 sandbox.py --policy policy.json -- /bin/echo hi

后端:
    macOS  -> sandbox-exec (Seatbelt)，profile 由 policy 生成
    Linux  -> bubblewrap（需安装 bwrap）

教学版限制: 网络一律 deny；生产版应支持代理白名单（见 docs/06）。
"""
import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile

SYSTEM_READ_PATHS = [
    "/usr/lib", "/usr/share", "/usr/bin", "/bin", "/sbin",
    "/System", "/Library/Frameworks", "/Library/Developer",
    "/Library/Preferences", "/private/var/db/timezone",
    "/private/etc", "/dev",
]

SBPL_TEMPLATE = """(version 1)
(deny default)
(allow process-exec process-fork)
(allow signal (target self))
(allow sysctl-read)
(allow file-read-metadata)
(allow file-read* (literal "/"))
(allow file-read* {read_paths})
(allow file-write*
  (subpath (param "WORKSPACE"))
  (literal "/dev/null")
  (literal "/dev/dtracehelper"))
(allow file-ioctl (literal "/dev/dtracehelper"))
(deny network*)
(allow mach-lookup
  (global-name "com.apple.system.logger")
  (global-name "com.apple.system.notification_center"))
"""


def build_profile(policy: dict) -> str:
    # Seatbelt 按规范路径匹配，/var -> /private/var 这类符号链接必须先解析
    ws = os.path.realpath(policy["workspace"])
    reads = SYSTEM_READ_PATHS + list(policy.get("extra_read_paths", [])) + [ws]
    read_paths = " ".join(f'(subpath "{p}")' for p in reads)
    return SBPL_TEMPLATE.format(read_paths=read_paths)


def build_command(cmd: list, policy: dict) -> list:
    ws = os.path.realpath(policy["workspace"])
    os.makedirs(ws, exist_ok=True)
    system = platform.system()

    if system == "Darwin":
        if not shutil.which("sandbox-exec"):
            raise RuntimeError("sandbox-exec not found")
        f = tempfile.NamedTemporaryFile("w", suffix=".sb", delete=False)
        f.write(build_profile(policy))
        f.close()
        return ["sandbox-exec", "-D", f"WORKSPACE={ws}", "-f", f.name, *cmd]

    if system == "Linux":
        if not shutil.which("bwrap"):
            raise RuntimeError("bwrap not found (apt install bubblewrap)")
        return [
            "bwrap",
            "--ro-bind", "/usr", "/usr",
            "--ro-bind", "/bin", "/bin",
            "--ro-bind", "/sbin", "/sbin",
            "--ro-bind", "/lib", "/lib",
            "--symlink", "usr/lib", "/lib64",
            "--ro-bind", "/etc", "/etc",
            "--bind", ws, "/workspace",
            "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
            "--chdir", "/workspace",
            "--unshare-all", "--die-with-parent", "--new-session",
            *cmd,
        ]

    raise RuntimeError(f"unsupported platform: {system}")


def run(cmd: list, policy: dict, timeout: int = 30) -> subprocess.CompletedProcess:
    return subprocess.run(build_command(cmd, policy),
                          capture_output=True, text=True, timeout=timeout)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--policy", required=True, help="policy JSON 文件路径")
    ap.add_argument("cmd", nargs="+", help="-- 之后是要执行的命令")
    args = ap.parse_args()
    with open(args.policy) as f:
        policy = json.load(f)
    r = run(args.cmd, policy)
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr)
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())