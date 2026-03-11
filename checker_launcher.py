#!/usr/bin/env python3
"""
上海房市追踪 - 校验启动器
"""
import subprocess
import os
import datetime

WORK_DIR = "/Users/caocao/Documents/上海房市追踪系统"
SCRIPT = os.path.join(WORK_DIR, "checker.sh")
LOG = os.path.join(WORK_DIR, "update.log")

now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

subprocess.run(["xattr", "-c", SCRIPT], capture_output=True)

with open(SCRIPT, "r") as f:
    script_content = f.read()

with open(LOG, "a") as log:
    log.write(f"[{now}] Checker launcher 启动\n")

result = subprocess.run(
    ["/bin/bash"],
    input=script_content,
    capture_output=True,
    text=True,
    cwd=WORK_DIR,
    env={
        **os.environ,
        "PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "DATA_DIR": os.path.join(WORK_DIR, "data"),
    }
)

with open(LOG, "a") as log:
    if result.returncode == 0:
        log.write(f"[{now}] Checker launcher 完成 ✅\n")
    else:
        log.write(f"[{now}] Checker launcher 失败 (code={result.returncode})\n")
        if result.stderr:
            log.write(f"[{now}] stderr: {result.stderr[:500]}\n")
