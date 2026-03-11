#!/usr/bin/env python3
"""
上海房市追踪 - 启动器
用 python3 调用 bash 脚本，绕过 macOS Gatekeeper 限制
"""
import subprocess
import os
import datetime

WORK_DIR = "/Users/caocao/Documents/上海房市追踪系统"
SCRIPT = os.path.join(WORK_DIR, "daily_update.sh")
LOG = os.path.join(WORK_DIR, "update.log")

now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# 清除安全属性
subprocess.run(["xattr", "-c", SCRIPT], capture_output=True)

# 读取脚本内容并通过 stdin 传给 bash（绕过文件执行限制）
with open(SCRIPT, "r") as f:
    script_content = f.read()

with open(LOG, "a") as log:
    log.write(f"[{now}] Python launcher 启动\n")

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
        log.write(f"[{now}] Python launcher 完成 ✅\n")
    else:
        log.write(f"[{now}] Python launcher 失败 (code={result.returncode})\n")
        if result.stderr:
            log.write(f"[{now}] stderr: {result.stderr[:500]}\n")
