#!/usr/bin/env bash
set -e

# ==============================================================================
# Vocal 全链路自动化集成测试回归脚本 (Master Test Runner)
# 一键运行：
# 1. 移动端 Flutter 单元测试与 Layer 1 Mock 宿主集成测试
# 2. macOS 宿主端 Swift 单文件语法与独立编译自检
# 3. Layer 3 跨端真实端到端 (E2E) 自动化集成测试套件
# ==============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=================================================================="
echo "🧪 Vocal 自动化集成测试流水线启动 (Full Regression Pipeline)"
echo "=================================================================="

# 1. Flutter 移动端测试
echo ""
echo "📱 [阶段 1/3] 运行 Flutter 移动端测试 (单元测试 + Layer 1 Mock 宿主集成测试)..."
cd mobile
fvm flutter test
cd "$PROJECT_ROOT"
echo "✅ [阶段 1/3] 移动端全部测试通过！"

# 2. macOS 宿主独立编译自检
echo ""
echo "🖥️  [阶段 2/3] 校验 macOS 宿主端零外部依赖编译 (swiftc)..."
swiftc -o /dev/null -parse-as-library mac/VocalHostApp.swift
echo "✅ [阶段 2/3] macOS 宿主编译自检通过！"

# 3. 跨端真实 E2E 自动化测试
echo ""
echo "🌐 [阶段 3/3] 执行真实跨端 E2E 自动化测试套件 (Python 3 Asyncio)..."
python3 tests/e2e/run_e2e.py
echo "✅ [阶段 3/3] 跨端 E2E 自动化测试套件全部通过！"

echo ""
echo "=================================================================="
echo "🎉 [ALL PASSED] Vocal 全链路自动化回归测试 100% 验证通过！"
echo "=================================================================="

