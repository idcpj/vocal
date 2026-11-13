#!/usr/bin/env python3
"""
Unified E2E Cross-platform Integration Test Runner for Vocal.
Runs zero-dependency, pure Python 3 async test suites against live MacHostApp.
"""

import asyncio
import os
import sys
import time

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from tests.e2e.host_process import compile_mac_host
from tests.e2e.test_handshake_state import run_handshake_state_tests
from tests.e2e.test_payload_inject import run_payload_inject_tests
from tests.e2e.test_heartbeat_reconnect import run_heartbeat_reconnect_tests


async def main() -> int:
    start_time = time.time()
    print("=" * 65)
    print("🚀 Vocal 跨端自动化集成测试套件 (E2E Integration Test Suite)")
    print("=" * 65)

    # 1. Compile Host
    try:
        binary_path = compile_mac_host()
        print(f"📦 测试宿主二进制就绪: {binary_path}\n")
    except Exception as e:
        print(f"❌ 宿主编译失败: {e}")
        return 1

    results = {}

    # 2. Handshake & State Sync
    results["握手与状态同步 (TC-01, TC-02)"] = await run_handshake_state_tests(base_port=19100)

    # 3. Payload & Injection
    results["消息载荷与回车注入 (TC-04, TC-05, TC-06)"] = await run_payload_inject_tests(base_port=19200)

    # 4. Heartbeat & Reconnect
    results["心跳保活与故障自愈 (TC-03, TC-08)"] = await run_heartbeat_reconnect_tests(base_port=19300)

    # Summary
    duration = time.time() - start_time
    print("=" * 65)
    print("📊 Vocal E2E 自动化测试汇总报告")
    print("=" * 65)

    all_passed = True
    for test_suite, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        if not passed:
            all_passed = False
        print(f"  {status} - {test_suite}")

    print("-" * 65)
    print(f"⏱  总执行耗时: {duration:.2f} 秒")
    if all_passed:
        print("🎉 全部 E2E 跨端自动化集成测试 100% 通过！")
        return 0
    else:
        print("🚨 存在未通过的测试用例，请检查上述错误日志！")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)

