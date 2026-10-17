#!/usr/bin/env python3
"""Set process/size_limit=1024 on every texture .import whose source exceeds 1024px.
Replicates the 'light edition' texture treatment (V38/V42): 438 big textures -> 1024.
Run from repo root. Prints a summary; writes modified paths to /tmp/limited_imports.txt
"""
import os, re, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
os.chdir(ROOT)

modified = []
checked = 0
for dirpath, _, files in os.walk('.'):
    if '.godot' in dirpath or '.git' in dirpath:
        continue
    for fn in files:
        if not fn.endswith('.import'):
            continue
        ip = os.path.join(dirpath, fn)
        src = ip[:-len('.import')]
        if not os.path.exists(src):
            continue
        # only raster texture imports
        try:
            head = open(ip, encoding='utf-8', errors='replace').read(400)
        except Exception:
            continue
        if 'importer="texture"' not in head:
            continue
        if src.lower().endswith(('.svg', '.svgz')):
            continue
        checked += 1
        try:
            with Image.open(src) as im:
                w, h = im.size
        except Exception as e:
            print(f"SKIP (no dims): {src}: {e}", file=sys.stderr)
            continue
        if max(w, h) <= 1024:
            continue
        txt = open(ip, encoding='utf-8').read()
        if 'process/size_limit=' in txt:
            new = re.sub(r'process/size_limit=\d+', 'process/size_limit=1024', txt)
        else:
            new = txt.replace('[params]', '[params]\nprocess/size_limit=1024', 1)
        if new != txt:
            open(ip, 'w', encoding='utf-8').write(new)
            modified.append(ip)

with open('/tmp/limited_imports.txt', 'w') as f:
    f.write('\n'.join(modified))
print(f"checked={checked} limited={len(modified)}")
