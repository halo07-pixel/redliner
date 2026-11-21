#!/usr/bin/env python3
"""Ghép các chuỗi ảnh <tên>_<ms>.png trong một thư mục thành một tấm contact sheet cho mỗi chuỗi.
   python3 tools/screenshots/contact_sheet.py docs/screenshots/m19"""
import sys, glob, os, re
from PIL import Image
d = sys.argv[1]
seqs = {}
for f in sorted(glob.glob(os.path.join(d, "*_*.png"))):
    m = re.match(r"(.+)_(\d+)\.png$", os.path.basename(f))
    if m and not m.group(1).endswith("sheet"):
        seqs.setdefault(m.group(1), []).append((int(m.group(2)), f))
for name, items in seqs.items():
    items.sort()
    tiles = [Image.open(f).convert("RGB").resize((426, 240)) for _, f in items]
    cols = min(4, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 426, rows * 240), (20, 20, 20))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * 426, (i // cols) * 240))
    sheet.save(os.path.join(d, "sheet_%s.png" % name))
    print("sheet", name, [ms for ms, _ in items])
