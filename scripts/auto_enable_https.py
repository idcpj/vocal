#!/usr/bin/env python3
"""
自动轮询 GitHub Pages 证书状态并开启 HTTPS 强制跳转
"""

import time
import subprocess
import json
import sys

REPO = "idcpj/vocal"
MAX_ATTEMPTS = 60  # 最多轮询 60 次 (约 15 分钟)
INTERVAL = 15     # 间隔 15 秒

print(f"[*] 开始监控 GitHub Pages 自定义域名证书状态: {REPO}")

for attempt in range(1, MAX_ATTEMPTS + 1):
    try:
        res = subprocess.run(
            ["gh", "api", f"/repos/{REPO}/pages"],
            capture_output=True,
            text=True,
            check=True
        )
        data = json.loads(res.stdout)
        cert = data.get("https_certificate", {})
        state = cert.get("state")
        desc = cert.get("description")
        enforced = data.get("https_enforced", False)

        print(f"[{attempt}/{MAX_ATTEMPTS}] 当前状态: state={state}, enforced={enforced}, desc={desc}")

        if enforced:
            print("[+] HTTPS 强制跳转已经成功开启！")
            sys.exit(0)

        # 尝试开启 https_enforced
        enable_res = subprocess.run(
            ["gh", "api", "--method", "PUT", f"/repos/{REPO}/pages", "-F", "https_enforced=true"],
            capture_output=True,
            text=True
        )
        if enable_res.returncode == 0:
            print("[+] 成功开启 Enforce HTTPS！")
            # 验证一次
            time.sleep(2)
            verify_res = subprocess.run(
                ["gh", "api", f"/repos/{REPO}/pages"],
                capture_output=True,
                text=True
            )
            print("[+] 最新 Pages 状态:", verify_res.stdout)
            sys.exit(0)
        else:
            # 还在签发中或等待验证
            pass

    except Exception as e:
        print(f"[!] 查询出错: {e}")

    time.sleep(INTERVAL)

print("[-] 超时：证书签发仍在进行中，请稍后手动重试或等待 GitHub 后台完成。")
sys.exit(1)
