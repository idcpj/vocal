#!/usr/bin/env python3
"""
Render and export artboards from vocal.pen into high-resolution PNG images
for the Vocal official website.
"""

import json
import os
import subprocess
import sys
import tempfile

def format_padding(pad):
    if not pad:
        return "0"
    if isinstance(pad, (int, float)):
        return f"{pad}px"
    if isinstance(pad, list):
        if len(pad) == 2:
            return f"{pad[0]}px {pad[1]}px"
        if len(pad) == 4:
            return f"{pad[0]}px {pad[1]}px {pad[2]}px {pad[3]}px"
    return "0"

def format_radius(r):
    if not r:
        return "0"
    if isinstance(r, (int, float)):
        return f"{r}px"
    if isinstance(r, list):
        return " ".join(f"{x}px" for x in r)
    return "0"

def node_to_html(node):
    ntype = node.get("type", "frame")
    nid = node.get("id", "")
    nname = node.get("name", "")
    
    style = []
    
    # Dimensions
    w = node.get("width")
    if w == "fill_container":
        style.append("width: 100%;")
    elif w == "hug_contents":
        style.append("width: fit-content;")
    elif isinstance(w, (int, float)):
        style.append(f"width: {w}px;")
        
    h = node.get("height")
    if h == "fill_container":
        style.append("height: 100%;")
    elif h == "hug_contents":
        style.append("height: fit-content;")
    elif isinstance(h, (int, float)):
        style.append(f"height: {h}px;")

    # Fill
    fill = node.get("fill")
    if fill:
        style.append(f"background: {fill};")
        
    # Corner Radius
    cr = node.get("cornerRadius")
    if cr:
        style.append(f"border-radius: {format_radius(cr)};")
        
    # Border
    border = node.get("border")
    if border and isinstance(border, dict):
        bcolor = border.get("color", "transparent")
        bwidth = border.get("width", 1)
        style.append(f"border: {bwidth}px solid {bcolor};")
        
    # Padding
    pad = node.get("padding")
    if pad:
        style.append(f"padding: {format_padding(pad)};")
        
    # Clip
    if node.get("clip"):
        style.append("overflow: hidden;")

    # Layout (Flex)
    layout = node.get("layout")
    if layout:
        style.append("display: flex;")
        if layout == "vertical":
            style.append("flex-direction: column;")
        else:
            style.append("flex-direction: row;")
            
        gap = node.get("gap")
        if gap is not None:
            style.append(f"gap: {gap}px;")
            
        jc = node.get("justifyContent")
        if jc:
            jc_map = {
                "space_between": "space-between",
                "center": "center",
                "flex_start": "flex-start",
                "flex_end": "flex-end"
            }
            style.append(f"justify-content: {jc_map.get(jc, jc)};")
            
        ai = node.get("alignItems")
        if ai:
            ai_map = {
                "center": "center",
                "flex_start": "flex-start",
                "flex_end": "flex-end"
            }
            style.append(f"align-items: {ai_map.get(ai, ai)};")

    style_str = " ".join(style)

    if ntype == "frame":
        children_html = "".join(node_to_html(c) for c in node.get("children", []))
        return f'<div class="node-frame" id="{nid}" style="{style_str}">{children_html}</div>'

    elif ntype == "text":
        content = node.get("content", "")
        ff = node.get("fontFamily", "Inter")
        fs = node.get("fontSize", 14)
        fw = node.get("fontWeight", 400)
        t_fill = node.get("fill", "#FFFFFF")
        text_style = f"font-family: '{ff}', sans-serif; font-size: {fs}px; font-weight: {fw}; color: {t_fill}; line-height: 1.4; {style_str}"
        return f'<div class="node-text" id="{nid}" style="{text_style}">{content}</div>'

    elif ntype == "rectangle":
        return f'<div class="node-rect" id="{nid}" style="{style_str}"></div>'

    elif ntype == "ellipse":
        style.append("border-radius: 50%;")
        style_str = " ".join(style)
        return f'<div class="node-ellipse" id="{nid}" style="{style_str}"></div>'

    elif ntype == "icon":
        icon_name = node.get("icon", "circle")
        icon_fill = node.get("fill", "currentColor")
        iw = node.get("width", 16)
        ih = node.get("height", 16)
        return f'<i data-lucide="{icon_name}" style="width: {iw}px; height: {ih}px; color: {icon_fill}; display: inline-block; flex-shrink: 0;"></i>'

    return ""

def generate_artboard_html(artboard):
    content_html = node_to_html(artboard)
    w = artboard.get("width", 393)
    h = artboard.get("height", 852)
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <script src="https://unpkg.com/lucide@latest"></script>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      background: transparent;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      font-family: 'Inter', sans-serif;
      -webkit-font-smoothing: antialiased;
    }}
    #artboard-root {{
      width: {w}px;
      height: {h}px;
      position: relative;
    }}
  </style>
</head>
<body>
  <div id="artboard-root">
    {content_html}
  </div>
  <script>
    lucide.createIcons();
  </script>
</body>
</html>
"""

def main():
    pen_path = "vocal.pen"
    with open(pen_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    artboards = {}
    for c in data.get("children", []):
        cid = c.get("id")
        artboards[cid] = c

    # Target artboards to export
    targets = [
        ("iphone_normal", "website/images/vocal_mobile_app.png"),
        ("iphone_listening", "website/images/vocal_mobile_listening.png"),
        ("iphone_with_history", "website/images/vocal_mobile_history.png"),
        ("w36OZ", "website/images/vocal_mac_host.png"),
        ("gisP3", "website/images/vocal_pin_pairing.png"),
    ]

    chrome_bin = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

    for art_id, out_rel in targets:
        if art_id not in artboards:
            print(f"Skipping {art_id}, not found in vocal.pen")
            continue

        art = artboards[art_id]
        w = art.get("width", 393)
        h = art.get("height", 852)

        html_content = generate_artboard_html(art)
        
        with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as tf:
            tf.write(html_content)
            temp_html_path = tf.name

        out_path = os.path.abspath(out_rel)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)

        cmd = [
            chrome_bin,
            "--headless",
            "--hide-scrollbars",
            f"--window-size={w},{h}",
            "--force-device-scale-factor=2",
            "--default-background-color=00000000",
            f"--screenshot={out_path}",
            f"file://{temp_html_path}"
        ]

        print(f"Exporting {art_id} -> {out_rel} ({w}x{h})...")
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if os.path.exists(out_path):
            size = os.path.getsize(out_path)
            print(f"  Success: {out_rel} ({size} bytes)")
        else:
            print(f"  Failed: {res.stderr.decode('utf-8')[:200]}")

        try:
            os.remove(temp_html_path)
        except:
            pass

    print("All exports complete!")

if __name__ == "__main__":
    main()
