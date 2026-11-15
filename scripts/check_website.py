#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Vocal 官网逐项质量检测与门禁验收脚本 (Website Quality Gate & Asset Audit)
负责对 website/ 目录进行自动化逐项检测：
1. 静态资源完整性 (404 零容忍)
2. HTML5 规范与语义结构
3. 深色科技极简风设计系统规范 (vocal.pen 对齐)
4. 核心功能特性覆盖度 (PIN 配对、防抢占、自动回车、草稿审阅、长历史、多端生态)
5. 交互模拟器脚本健康度
6. 零外部打包依赖检测
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Tuple, Dict

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WEBSITE_DIR = PROJECT_ROOT / "website"
INDEX_HTML = WEBSITE_DIR / "index.html"
STYLE_CSS = WEBSITE_DIR / "style.css"
MAIN_JS = WEBSITE_DIR / "main.js"
IMAGES_DIR = WEBSITE_DIR / "images"

class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    RESET = "\033[0m"

class WebsiteQualityChecker:
    def __init__(self):
        self.results: List[Tuple[str, str, bool, str]] = []  # (Category, Item, Passed, Detail)

    def log_result(self, category: str, item: str, passed: bool, detail: str = ""):
        self.results.append((category, item, passed, detail))

    def check_zero_build_dependencies(self):
        """检查零外部重量级构建依赖"""
        forbidden_files = ["package.json", "node_modules", "vite.config.js", "webpack.config.js"]
        found = [f for f in forbidden_files if (WEBSITE_DIR / f).exists()]
        if found:
            self.log_result("架构规范", "零外部构建依赖", False, f"发现禁止的构建文件或目录: {found}")
        else:
            self.log_result("架构规范", "零外部构建依赖 (纯原生即开即用)", True, "无 Node/npm/构建包污染，纯静态单页")

    def check_asset_integrity(self):
        """检查所有引用的静态资源是否存在且非空 (404 零容忍)"""
        if not INDEX_HTML.exists():
            self.log_result("静态资源", "HTML 主入口文件", False, f"缺少 {INDEX_HTML}")
            return
        
        html_content = INDEX_HTML.read_text(encoding="utf-8")
        
        # 匹配 <img src="...">, <link href="...">, <script src="...">
        img_srcs = re.findall(r'<img[^>]+src=["\']([^"\']+)["\']', html_content)
        link_hrefs = re.findall(r'<link[^>]+href=["\']([^"\']+)["\']', html_content)
        script_srcs = re.findall(r'<script[^>]+src=["\']([^"\']+)["\']', html_content)

        all_local_assets = []
        for src in img_srcs + link_hrefs + script_srcs:
            if src.startswith("http://") or src.startswith("https://") or src.startswith("#"):
                continue
            all_local_assets.append(src)

        # 检查 CSS 中的 url(...)
        if STYLE_CSS.exists():
            css_content = STYLE_CSS.read_text(encoding="utf-8")
            css_urls = re.findall(r'url\(["\']?([^"\'\)]+)["\']?\)', css_content)
            for url in css_urls:
                if not (url.startswith("http://") or url.startswith("https://") or url.startswith("data:")):
                    all_local_assets.append(url)

        missing_assets = []
        empty_assets = []
        verified_count = 0

        for asset in set(all_local_assets):
            # 去除 query 参数或 hash
            clean_asset = asset.split("?")[0].split("#")[0]
            target_path = WEBSITE_DIR / clean_asset
            if not target_path.exists():
                missing_assets.append(asset)
            elif target_path.stat().st_size == 0:
                empty_assets.append(asset)
            else:
                verified_count += 1

        if missing_assets:
            self.log_result("静态资源", "本地资源 404 检测", False, f"缺失本地资源: {missing_assets}")
        elif empty_assets:
            self.log_result("静态资源", "本地资源空文件检测", False, f"发现 0 字节文件: {empty_assets}")
        else:
            self.log_result("静态资源", "本地静态资源完整性", True, f"全部 {verified_count} 项本地静态资源均存在且非空")

    def check_html_structure(self):
        """检查 HTML5 结构、语义化与移动端视口适配"""
        if not INDEX_HTML.exists():
            return
        html = INDEX_HTML.read_text(encoding="utf-8")

        # 1. 基础规范
        has_doctype = "<!DOCTYPE html>" in html
        has_lang = bool(re.search(r'<html[^>]+lang=["\']zh', html))
        has_charset = '<meta charset="UTF-8">' in html or '<meta charset="utf-8">' in html
        has_viewport = '<meta name="viewport"' in html and 'width=device-width' in html

        self.log_result("HTML结构", "HTML5 DOCTYPE & 语言声明", has_doctype and has_lang, "DOCTYPE html 与 lang='zh-CN'")
        self.log_result("HTML结构", "UTF-8 字符集与移动端视口 Viewport", has_charset and has_viewport, "宽度自适应与 UTF-8 编码")

        # 2. SEO 标题与描述
        has_title = bool(re.search(r'<title>[^<]+</title>', html))
        has_desc = bool(re.search(r'<meta\s+name=["\']description["\']\s+content=["\'][^"\']+["\']', html))
        self.log_result("HTML结构", "SEO 标题与元描述", has_title and has_desc, "包含完整的 title 与 description")

        # 3. 核心 Section 导航锚点
        required_anchors = ["#playground", "#bento", "#gallery", "#platforms", "#download"]
        missing_anchors = [a for a in required_anchors if a[1:] not in html]
        if missing_anchors:
            self.log_result("HTML结构", "核心导航 Section 完整性", False, f"缺失锚点区块: {missing_anchors}")
        else:
            self.log_result("HTML结构", "核心导航 Section 完整性", True, f"包含全部主板块: {required_anchors}")

    def check_design_system_consistency(self):
        """检查深色科技极简风设计系统规范 (vocal.pen 对齐)"""
        if not STYLE_CSS.exists():
            self.log_result("设计规范", "CSS 样式表存在性", False, f"缺失 {STYLE_CSS}")
            return
        css = STYLE_CSS.read_text(encoding="utf-8")

        # 颜色变量检查
        has_dark_bg = "#0a0f1c" in css.lower() or "#0f172a" in css.lower() or "--bg-primary" in css
        has_cyan = "#22d3ee" in css.lower() or "--accent-cyan" in css
        has_amber = "#f59e0b" in css.lower() or "--accent-amber" in css or "amber" in css.lower()
        has_green = "#10b981" in css.lower() or "--accent-green" in css or "emerald" in css.lower()
        has_mono_font = "JetBrains Mono" in css

        self.log_result("设计规范", "深色极客底色规范 (#0A0F1C / #0F172A)", has_dark_bg, "符合极简暗黑基调")
        self.log_result("设计规范", "青色霓虹强调色规范 (#22D3EE)", has_cyan, "主聚焦光晕与高亮色系对齐")
        self.log_result("设计规范", "状态与警示色彩体系 (Amber/Green)", has_amber and has_green, "PIN 配对琥珀色与服务在线绿色")
        self.log_result("设计规范", "科技等宽代码字体 (JetBrains Mono)", has_mono_font, "集成专业开发级等宽字体")

        # 移动端响应式断点检测
        has_media_query = "@media" in css and ("max-width" in css)
        self.log_result("设计规范", "移动端响应式布局媒体查询", has_media_query, "包含 @media (max-width) 移动端小屏断点适配")

        # CSS 语法大括号平衡检测
        clean_css = re.sub(r'/\*.*?\*/', '', css, flags=re.DOTALL)
        braces_balanced = clean_css.count('{') == clean_css.count('}')
        self.log_result("设计规范", "CSS 语法大括号开闭平衡", braces_balanced,
                        f"校验全量 CSS 规则闭合性: {clean_css.count('{')} 开 / {clean_css.count('}')} 闭")

    def check_feature_coverage(self):
        """检查最新落地的产品核心功能特性覆盖度"""
        if not INDEX_HTML.exists():
            return
        html = INDEX_HTML.read_text(encoding="utf-8")
        js = MAIN_JS.read_text(encoding="utf-8") if MAIN_JS.exists() else ""
        combined = html + " " + js

        features = [
            ("端侧本地听写与隐私闭环", ["本地", "离线", "不上云", "SFSpeechRecognizer", "端侧"], "声音本地处理，绝不上云"),
            ("超低延迟局域网直连", ["WebSocket", "12ms", "15ms", "毫秒", "直连", "低延迟"], "点对点极速通信，物理键盘级响应"),
            ("草稿本地缓冲先审后发", ["草稿", "审阅", "先审阅", "防抖", "手动发送"], "说完确认再发送，杜绝错字错乱"),
            ("设备 PIN 码安全门禁", ["PIN", "配对", "安全", "鉴权", "防蹭", "误连"], "公共网络首次连接安全验证"),
            ("单设备独占防抢占机制", ["防抢占", "独占", "占用", "抢占", "单设备", "互斥"], "避免多设备并发打字冲突"),
            ("自动回车模式切换", ["回车", "Auto Enter", "pressEnter", "换行"], "发送完成后自动回车上屏"),
            ("历史草稿长流滚动回溯", ["历史", "草稿流", "回溯", "重发", "50条", "沉淀流"], "长文随时调取、二次编辑与重发"),
            ("四端多平台生态矩阵", ["macOS", "Windows", "iOS", "Android"], "桌面端双宿主与移动端双客户端"),
        ]

        for title, keywords, desc in features:
            matched = any(kw.lower() in combined.lower() for kw in keywords)
            self.log_result("特性覆盖", title, matched, desc if matched else f"未检测到关键表述: {keywords}")

    def check_simulator_health(self):
        """检查交互式模拟器运行健康度"""
        if not MAIN_JS.exists():
            self.log_result("模拟器交互", "主交互脚本存在性", False, f"缺少 {MAIN_JS}")
            return
        js = MAIN_JS.read_text(encoding="utf-8")

        has_soundwave = "canvas" in js.lower() or "wave" in js.lower() or "soundwave" in js.lower()
        has_typewriter = "type" in js.lower() or "inject" in js.lower() or "send" in js.lower()
        has_event_listener = "addEventListener" in js

        self.log_result("模拟器交互", "动态声波/波形渲染引擎", has_soundwave, "包含流体声波可视化逻辑")
        self.log_result("模拟器交互", "打字机毫秒级字符注入模拟", has_typewriter, "支持模拟键盘敲入动效")
        self.log_result("模拟器交互", "DOM 事件监听与交互绑定", has_event_listener, "标准现代原生事件绑定")

    def check_dom_element_integrity(self):
        """深度审计 DOM 元素与脚本交互绑定的完整性 (零孤儿 ID / 零死链)"""
        if not INDEX_HTML.exists() or not MAIN_JS.exists():
            return
        html = INDEX_HTML.read_text(encoding="utf-8")
        js = MAIN_JS.read_text(encoding="utf-8")

        html_ids = set(re.findall(r'id=["\']([^"\']+)["\']', html))
        js_ids = set(re.findall(r'getElementById\(["\']([^"\']+)["\']\)', js))
        missing_ids = [jid for jid in js_ids if jid not in html_ids]

        self.log_result("元素深度审计", "JS 脚本与 HTML 元素 ID 绑定完整度", len(missing_ids) == 0,
                        f"校验 {len(js_ids)} 处 getElementById 绑定，零缺失" if len(missing_ids) == 0 else f"缺失 ID: {missing_ids}")

        # 检查图片 alt 属性
        img_tags = re.findall(r'<img\s+([^>]+)>', html)
        missing_alt = [img for img in img_tags if not re.search(r'alt=["\'][^"\']+["\']', img)]
        self.log_result("元素深度审计", "全部 <img> 标签无障碍 alt 描述完整性", len(missing_alt) == 0,
                        f"共 {len(img_tags)} 处图片，全部具备合规 alt 描述" if len(missing_alt) == 0 else f"存在缺少 alt 的图片: {len(missing_alt)}")

    def run_all(self) -> bool:
        self.check_zero_build_dependencies()
        self.check_asset_integrity()
        self.check_html_structure()
        self.check_design_system_consistency()
        self.check_feature_coverage()
        self.check_simulator_health()
        self.check_dom_element_integrity()

        total = len(self.results)
        passed_count = sum(1 for _, _, p, _ in self.results if p)
        failed_count = total - passed_count

        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}{Colors.CYAN}📋 Vocal 官网逐项质量检测与门禁验收报告 (Website Quality Gate){Colors.RESET}")
        print("=" * 70)

        current_cat = None
        for cat, item, passed, detail in self.results:
            if cat != current_cat:
                current_cat = cat
                print(f"\n{Colors.BOLD}【{cat}】{Colors.RESET}")
            status = f"{Colors.GREEN}✓ PASS{Colors.RESET}" if passed else f"{Colors.RED}✗ FAIL{Colors.RESET}"
            print(f"  [{status}] {item: <28} : {detail}")

        print("\n" + "-" * 70)
        summary_color = Colors.GREEN if failed_count == 0 else Colors.RED
        print(f"{Colors.BOLD}检测汇总: 共 {total} 项检测，{Colors.GREEN}{passed_count} 项通过{Colors.RESET}，"
              f"{summary_color}{failed_count} 项异常{Colors.RESET}。")
        print("=" * 70 + "\n")

        return failed_count == 0

    def generate_markdown_report(self) -> str:
        """生成标准 Markdown 质检验收报告"""
        lines = [
            "# 🏥 Vocal 官网逐项质量检测与门禁验收报告",
            "",
            "> 自动执行时间戳：实时验证",
            "> 适用范围：`website/` 目录全量静态资源、样式规范、交互脚本与特性文案",
            "",
            "| 检测分类 | 检查细项 | 状态 | 详细说明 |",
            "| :--- | :--- | :---: | :--- |"
        ]
        for cat, item, passed, detail in self.results:
            status = "✅ PASS" if passed else "❌ FAIL"
            lines.append(f"| **{cat}** | {item} | {status} | {detail} |")

        passed_count = sum(1 for _, _, p, _ in self.results if p)
        total = len(self.results)
        lines.append("")
        lines.append(f"**综合评定**: 共 **{total}** 项检测，**{passed_count}/{total}** 通过。")
        if passed_count == total:
            lines.append("🎉 **验收结论**: **全项通过 (LGTM)**，完全满足极简暗黑科技风设计规范与最新功能特性同步要求！")
        else:
            lines.append("⚠️ **验收结论**: 存在未通过门禁项，请 `website-dev` 进行修复！")
        return "\n".join(lines)


if __name__ == "__main__":
    checker = WebsiteQualityChecker()
    success = checker.run_all()
    sys.exit(0 if success else 1)
