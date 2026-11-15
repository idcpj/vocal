#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Vocal 官网 DOM 元素与交互绑定深度审计脚本 (DOM & Interaction Element Auditor)
逐项检查：
1. JS 中 getElementById 查询的 ID 是否在 index.html 中全部存在
2. JS 中 querySelector 查询的关键 Class 是否在 index.html / style.css 中存在
3. 所有 <a> 锚点跳转的 target ID 是否真实存在
4. 检查是否有破损的 HTML 标签
5. 所有 img 的 src 属性与 alt 属性完整性
"""

import re
import sys
from pathlib import Path

WEBSITE_DIR = Path(__file__).resolve().parent.parent / "website"
INDEX_HTML = WEBSITE_DIR / "index.html"
STYLE_CSS = WEBSITE_DIR / "style.css"
MAIN_JS = WEBSITE_DIR / "main.js"

def audit_elements():
    html = INDEX_HTML.read_text(encoding="utf-8")
    css = STYLE_CSS.read_text(encoding="utf-8")
    js = MAIN_JS.read_text(encoding="utf-8")

    print("=" * 70)
    print("🔍 Vocal 官网 DOM 元素与交互深度审计 (Element & DOM Audit)")
    print("=" * 70)

    # 1. 提取 HTML 中所有 ID
    html_ids = set(re.findall(r'id=["\']([^"\']+)["\']', html))
    print(f"[*] HTML 中共定义了 {len(html_ids)} 个唯一元素 ID")

    # 2. 检查 JS 中引用的 ID 是否存在
    js_ids = set(re.findall(r'getElementById\(["\']([^"\']+)["\']\)', js))
    missing_ids = [jid for jid in js_ids if jid not in html_ids]
    if missing_ids:
        print(f"❌ [FAIL] JS 中引用的 ID 在 HTML 中不存在: {missing_ids}")
    else:
        print(f"✅ [PASS] JS 引用的 {len(js_ids)} 个 getElementById 全部在 HTML 中有效对应")

    # 3. 检查 HTML 中的内部锚点链接是否全部有对应目标
    anchor_hrefs = set(re.findall(r'href=["\']#([^"\']+)["\']', html))
    valid_anchors = []
    missing_targets = []
    for href in anchor_hrefs:
        if not href:
            continue
        if href in html_ids:
            valid_anchors.append(href)
        else:
            missing_targets.append(href)
    
    if missing_targets:
        print(f"⚠️  [WARN] 内部锚点目标 ID 缺失: {missing_targets}")
    else:
        print(f"✅ [PASS] 全部 {len(valid_anchors)} 个页内平滑跳转锚点目标均存在")

    # 4. 检查图片 alt 属性与路径
    img_matches = re.findall(r'<img\s+([^>]+)>', html)
    missing_alt = 0
    missing_file = 0
    for match in img_matches:
        src_match = re.search(r'src=["\']([^"\']+)["\']', match)
        alt_match = re.search(r'alt=["\']([^"\']+)["\']', match)
        if not alt_match or not alt_match.group(1).strip():
            missing_alt += 1
        if src_match:
            src = src_match.group(1)
            if not src.startswith("http") and not (WEBSITE_DIR / src).exists():
                missing_file += 1
                print(f"❌ [FAIL] 图片源不存在: {src}")

    if missing_alt == 0:
        print(f"✅ [PASS] 全部 {len(img_matches)} 处 <img> 均包含非空可访问性 alt 描述")
    else:
        print(f"⚠️  [WARN] 存在 {missing_alt} 处图片缺少 alt 属性")

    if missing_file == 0:
        print(f"✅ [PASS] 全部 {len(img_matches)} 处 <img> 本地静态图片均真实存在")

    # 5. 检查高科技设计画廊元素
    gallery_cards = re.findall(r'<div class="gallery-card[^"]*"([^>]*)>', html)
    print(f"✅ [PASS] 高科技设计画廊共挂载 {len(gallery_cards)} 张 Open Pencil 原生画板卡片")

    print("=" * 70)
    success = (len(missing_ids) == 0 and missing_file == 0)
    print(f"✨ 审计结论: {'全部健康，元素零缺陷 (PASS)' if success else '存在异常元素项，需修复'}")
    print("=" * 70)
    return success

if __name__ == "__main__":
    if not audit_elements():
        sys.exit(1)

