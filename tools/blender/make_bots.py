"""Dựng thân low poly của 5 loại bot + Titan (M44): `assets/characters/lowpoly/<loại>.glb`.

Chạy: `python3 tools/blender/make_bots.py` (pip install bpy==5.3.0) hoặc dán vào Scripting trong Blender. Thư mục ra: REDLINER_BOT_OUT.
Chuẩn: docs/ASSETS.md ("Chuẩn low poly").

Thân gồm các KHỐI RỜI gắn vào 15 Empty trùng tên 15 khớp proxy (hips > spine > head | shoulder > elbow > hand | hip > knee > ankle),
vị trí khớp đúng bằng `mannequin.gd` (hình nhân khối) nên `RigAnimator`/IK/hitbox chạy y nguyên, không có xương/skin.
Hình học viết theo toạ độ GODOT (x phải, y lên, -z phía trước), `g()` đổi sang Blender. Số đo theo `Global.RIG` (sao chép dưới đây;
test_m44 kiểm tra khớp). Vật liệu đặt tên theo VAI TRÒ (bd_cloth/bd_pants/bd_dark/bd_skin/bd_glow); màu thật do mannequin_lowpoly.gd
tô theo màu của loại bot khi chạy, nên màu ở đây chỉ để xem trong Blender.
"""
import math
import os
import tempfile

import bpy  # phải nạp trước bmesh khi chạy ngoài Blender
import bmesh
from mathutils import Matrix, Vector

OUT_DIR = os.environ.get("REDLINER_BOT_OUT", tempfile.gettempdir())

# Sao chép `Global.RIG` (visual_data.gd): shoulder / bulk / armor / glow / style.
RIG = {
    "swordsman": {"shoulder": 1.25, "bulk": 1.1, "armor": 1, "glow": False, "style": "ronin"},
    "gunner": {"shoulder": 0.85, "bulk": 0.8, "armor": 0, "glow": False, "style": "ranger"},
    "elite": {"shoulder": 1.4, "bulk": 1.3, "armor": 2, "glow": True, "style": "guard"},
    "rusher": {"shoulder": 0.9, "bulk": 0.85, "armor": 0, "glow": True, "style": "ronin"},
    "bomber": {"shoulder": 1.1, "bulk": 1.25, "armor": 1, "glow": False, "style": "ranger"},
    "titan": {"shoulder": 1.3, "bulk": 1.2, "armor": 0, "glow": False, "style": "titan"},
}
ROLE_COLORS = {  # chỉ để xem trong Blender
    "bd_cloth": (0.85, 0.85, 0.9), "bd_pants": (0.6, 0.6, 0.63), "bd_dark": (0.42, 0.42, 0.45),
    "bd_skin": (0.84, 0.68, 0.57), "bd_glow": (0.95, 0.95, 1.0),
}
ROLES = list(ROLE_COLORS.keys())


def lin(c):
    return [(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]


def g(v):
    """Godot (x, y, z) -> Blender."""
    return (v[0], -v[2], v[1])


class Part:
    """Một object gắn vào Empty khớp `joint`; hình học cho theo toạ độ Godot CỤC BỘ của khớp đó."""

    def __init__(self, name, joint):
        self.name = name
        self.joint = joint
        self.bm = bmesh.new()

    def _face(self, verts, role):
        f = self.bm.faces.new(verts)
        f.material_index = ROLES.index(role)
        f.smooth = False

    def _v(self, p):
        return self.bm.verts.new(g(p))

    @staticmethod
    def _rot(rot):
        return (Matrix.Rotation(math.radians(rot[2]), 3, "Z") @ Matrix.Rotation(math.radians(rot[1]), 3, "Y")
                @ Matrix.Rotation(math.radians(rot[0]), 3, "X"))

    def box(self, size, center, role, rot=(0.0, 0.0, 0.0), bevel=0.0):
        """Hộp; `bevel` > 0 vát cạnh (thêm tam giác cho bớt vuông)."""
        snap = set(self.bm.faces)
        hx, hy, hz = (s / 2.0 for s in size)
        r = self._rot(rot)
        c = Vector(center)
        pts = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
               (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        v = [self._v(c + r @ Vector(p)) for p in pts]
        for idx in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)]:
            self._face([v[i] for i in idx], role)
        if bevel > 0.0:
            edges = list({e for vv in v for e in vv.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=1, affect="EDGES")
            for f in set(self.bm.faces) - snap:
                f.material_index = ROLES.index(role)
                f.smooth = False

    @staticmethod
    def _smooth_rings(rings, sub):
        """Nội suy Catmull-Rom giữa các tiết diện (y, rx, rz[, ox, oz]) -> thêm `sub` tiết diện mỗi đoạn cho mượt."""
        if sub <= 0 or len(rings) < 3:
            return [tuple(r) + (0.0, 0.0) if len(r) == 3 else tuple(r) for r in rings]
        rr = [list(r) + [0.0, 0.0] if len(r) == 3 else list(r) for r in rings]
        out = []
        for i in range(len(rr) - 1):
            p0 = rr[max(i - 1, 0)]
            p1, p2 = rr[i], rr[i + 1]
            p3 = rr[min(i + 2, len(rr) - 1)]
            for k in range(sub + 1):
                t = k / (sub + 1)
                out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                        + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in range(5)))
        out.append(tuple(rr[-1]))
        return out

    def loft(self, rings, role, n=12, sub=0, rot=(0.0, 0.0, 0.0), at=(0.0, 0.0, 0.0)):
        """Thân tròn nhiều tiết diện: rings = [(y, rx, rz[, ox, oz]), ...]; `sub` > 0 nội suy cho mượt; hai đầu bịt kín."""
        r_m = self._rot(rot)
        rs = []
        for y, rx, rz, ox, oz in self._smooth_rings(rings, sub):
            rs.append([self._v(Vector(at) + r_m @ Vector((ox + rx * math.cos(2 * math.pi * i / n), y, oz + rz * math.sin(2 * math.pi * i / n)))) for i in range(n)])
        for a, b in zip(rs[:-1], rs[1:]):
            for i in range(n):
                j = (i + 1) % n
                self._face([a[i], a[j], b[j], b[i]], role)
        self._face(list(reversed(rs[0])), role)
        self._face(rs[-1], role)

    def cone(self, center, r_bot, height, role, rot=(0.0, 0.0, 0.0), n=6, r_top=0.0):
        """Chóp/gai: đáy bán kính r_bot ở y=0, đỉnh bán kính r_top ở y=height (cục bộ), xoay `rot`, đặt tại `center`."""
        self.loft([(0.0, r_bot, r_bot), (height, r_top, r_top)], role, n=n, rot=rot, at=center)

    def ball(self, center, radius, role, u=8, v=5, scale=(1.0, 1.0, 1.0)):
        """Cầu thấp (khớp, đầu, mũ). `scale` = (x, y, z) theo toạ độ Godot."""
        before = set(self.bm.faces)
        sx, sy, sz = scale
        m = Matrix.Translation(Vector(g(center))) @ Matrix.Diagonal(Vector((sx, sz, sy, 1.0)))   # Godot (x,y,z) -> Blender (x,z..,y)
        bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=radius, matrix=m)
        for f in set(self.bm.faces) - before:
            f.material_index = ROLES.index(role)
            f.smooth = False

    def build(self, mats, joints):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name + "Mesh")
        self.bm.to_mesh(me)
        self.bm.free()
        for k in ROLES:
            me.materials.append(mats[k])
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = joints[self.joint]
        return ob


def style_parts(kind, rig, sw, b):
    """Trang phục/phụ kiện riêng từng loại, trả về list Part."""
    out = []
    style = rig["style"]
    if style == "ronin":
        p = Part("Hair", "head")
        p.loft([(0.16, 0.14, 0.154), (0.2, 0.133, 0.148, 0, 0.012), (0.245, 0.105, 0.118, 0, 0.018), (0.285, 0.05, 0.055, 0, 0.014)], "bd_dark", 16, 2)
        p.ball((0, 0.3, 0.03), 0.045, "bd_dark", 10, 6)                                          # búi tóc
        p.box((0.07, 0.22, 0.06), (0, 0.1, 0.155), "bd_dark", (14, 0, 0), 0.008)                 # đuôi tóc
        p.loft([(0.162, 0.145, 0.158), (0.205, 0.145, 0.158)], "bd_cloth", 16)                    # băng đầu
        p.box((0.045, 0.2, 0.025), (0.035, 0.07, 0.178), "bd_cloth", (10, 0, 8), 0.004)           # đuôi băng
        p.box((0.045, 0.16, 0.025), (-0.03, 0.08, 0.178), "bd_cloth", (8, 0, -6), 0.004)
        out.append(p)
        p = Part("Kimono", "spine")
        p.box((0.06, 0.3, 0.03), (0.07, 0.5, -0.158 * b), "bd_dark", (0, 0, -25), 0.006)         # cổ áo chữ V
        p.box((0.06, 0.3, 0.03), (-0.07, 0.5, -0.158 * b), "bd_dark", (0, 0, 25), 0.006)
        p.loft([(-0.1, 0.235 * sw, 0.145 * b), (0.0, 0.225 * sw, 0.14 * b), (0.1, 0.205 * sw, 0.128 * b)], "bd_dark", 16, 1)   # obi
        p.box((0.1, 0.58, 0.03), (0, 0.33, -0.17 * b), "bd_dark", (0, 0, 28), 0.008)             # dây chéo
        p.box((0.075, 0.075, 0.045), (0, 0.0, -0.158 * b), "bd_glow", (0, 0, 0), 0.01)           # khoá obi
        for k in range(3):
            p.box((0.012, 0.05, 0.012), (0.03 * (k - 1), -0.01, -0.185 * b), "bd_dark", (0, 0, 0), 0.002)
        out.append(p)
        p = Part("Hakama", "hips")
        p.loft([(0.0, 0.2 * sw, 0.14 * b), (-0.15, 0.215 * sw, 0.15 * b), (-0.36, 0.23 * sw, 0.16 * b), (-0.5, 0.235 * sw, 0.165 * b)], "bd_cloth", 16, 2)
        p.box((0.12, 0.46, 0.035), (0, -0.28, -0.162 * b), "bd_pants", (0, 0, 0), 0.008)         # tà trước
        out.append(p)
        for tag, side in (("l", -1), ("r", 1)):
            p = Part("Sleeve_" + tag, "elbow_" + tag)
            p.loft([(-0.05, 0.065 * b, 0.065 * b), (-0.22, 0.095 * b, 0.1 * b), (-0.4, 0.115 * b, 0.12 * b)], "bd_cloth", 12, 2)     # tay áo rộng
            p.loft([(-0.38, 0.118 * b, 0.123 * b), (-0.42, 0.118 * b, 0.123 * b)], "bd_dark", 12)
            out.append(p)
        if kind == "rusher":
            p = Part("Scarf", "spine")
            p.loft([(0.56, 0.1, 0.1), (0.62, 0.11, 0.11)], "bd_glow", 14, 1)
            p.box((0.1, 0.5, 0.03), (0.05, 0.38, 0.14 * b), "bd_glow", (-8, 0, 10), 0.006)
            p.box((0.09, 0.4, 0.03), (-0.05, 0.4, 0.15 * b), "bd_glow", (-5, 0, -8), 0.006)
            out.append(p)
    elif style == "ranger":
        p = Part("Hood", "head")
        p.loft([(0.0, 0.075, 0.09, 0, 0.03), (0.07, 0.155, 0.175, 0, 0.04), (0.15, 0.175, 0.19, 0, 0.045), (0.23, 0.145, 0.165, 0, 0.04), (0.295, 0.07, 0.09, 0, 0.03)], "bd_dark", 16, 2)
        for ex in (-1.0, 1.0):
            p.ball((0.06 * ex, 0.15, -0.14), 0.04, "bd_glow", 10, 6, (1.0, 1.0, 0.7))             # kính
            p.loft([(0.0, 0.048, 0.048), (0.03, 0.05, 0.05)], "bd_dark", 10, 0, (-90, 0, 0), (0.06 * ex, 0.15, -0.13))
        p.box((0.2, 0.02, 0.02), (0, 0.15, -0.135), "bd_dark", (0, 0, 0), 0.003)
        p.box((0.05, 0.16, 0.045), (0, 0.03, 0.17), "bd_dark", (-18, 0, 0), 0.008)               # đuôi mũ
        out.append(p)
        p = Part("Vest", "spine")
        p.loft([(0.16, 0.2 * sw, 0.135 * b), (0.28, 0.225 * sw, 0.15 * b), (0.42, 0.268 * sw, 0.168 * b), (0.54, 0.28 * sw, 0.148 * b)], "bd_dark", 16, 2)   # áo giáp mỏng
        for k in range(3):                                                                         # túi đạn trước ngực
            p.box((0.06, 0.08, 0.04), (0.075 * (k - 1) * sw, 0.3, -0.19 * b), "bd_pants", (0, 0, 0), 0.008)
        p.box((0.1, 0.5, 0.03), (0, 0.33, -0.2 * b), "bd_pants", (0, 0, -30), 0.008)            # dây đạn
        for k in range(5):
            p.box((0.026, 0.055, 0.03), (0.046 * (k - 2) * math.cos(math.radians(30)), 0.33 + 0.046 * (k - 2) * math.sin(math.radians(30)), -0.222 * b), "bd_glow", (0, 0, -30), 0.004)
        p.box((0.22 * sw, 0.3, 0.1), (0, 0.34, 0.21 * b), "bd_dark", (0, 0, 0), 0.018)          # ba lô
        p.box((0.16 * sw, 0.1, 0.06), (0, 0.5, 0.2 * b), "bd_pants", (0, 0, 0), 0.012)
        if kind == "bomber":
            p.loft([(0.0, 0.05, 0.05), (0.14, 0.052, 0.052)], "bd_glow", 10, 1, (0, 0, 90), (-0.06, 0.62, 0.12 * b))   # bình gas
            p.loft([(0.0, 0.05, 0.05), (0.14, 0.052, 0.052)], "bd_glow", 10, 1, (0, 0, 90), (0.06, 0.62, 0.12 * b))
        out.append(p)
        p = Part("Belt", "hips")
        for ox in (-1.0, 1.0):
            p.box((0.115, 0.13, 0.09), (0.22 * sw * ox, -0.07, -0.1 * b), "bd_dark", (0, 0, 0), 0.014)
            p.box((0.12, 0.03, 0.095), (0.22 * sw * ox, -0.015, -0.1 * b), "bd_pants", (0, 0, 0), 0.008)
        p.loft([(-0.045, 0.2 * sw, 0.13 * b), (0.035, 0.2 * sw, 0.13 * b)], "bd_dark", 16)
        if kind == "bomber":
            for k in range(6):                                                                     # dây lựu đạn
                p.ball((0.07 * (k - 2.5) * sw, -0.03 - 0.01 * abs(k - 2.5), -0.15 * b), 0.032, "bd_glow", 8, 5)
        out.append(p)
        for tag in ("l", "r"):
            p = Part("KneePad_" + tag, "knee_" + tag)
            p.ball((0, 0, -0.07), 0.08, "bd_dark", 10, 6, (1.0, 1.0, 0.7))
            out.append(p)
        if kind == "bomber":
            p = Part("Mask", "head")
            p.loft([(0.0, 0.06, 0.06), (0.07, 0.07, 0.07)], "bd_dark", 12, 1, (-90, 0, 0), (0, 0.08, -0.15))   # lọc khí
            p.box((0.18, 0.1, 0.05), (0, 0.09, -0.14), "bd_dark", (0, 0, 0), 0.015)
            out.append(p)
    elif style == "guard":
        p = Part("Helm", "head")
        p.loft([(0.0, 0.105, 0.115), (0.06, 0.155, 0.17), (0.14, 0.168, 0.182), (0.22, 0.152, 0.165), (0.29, 0.09, 0.1), (0.315, 0.04, 0.045)], "bd_dark", 16, 2)
        p.box((0.2, 0.035, 0.03), (0, 0.15, -0.165), "bd_glow", (0, 0, 0), 0.006)
        p.box((0.05, 0.12, 0.28), (0, 0.325, 0.0), "bd_dark", (0, 0, 0), 0.012)                  # mào
        for k in range(5):                                                                         # chùm lông mào
            p.box((0.03, 0.06 + 0.01 * k, 0.03), (0, 0.38 + 0.01 * k, 0.1 - 0.05 * k), "bd_glow", (20 + 5 * k, 0, 0), 0.004)
        for ex in (-1.0, 1.0):
            p.box((0.045, 0.14, 0.07), (0.155 * ex, 0.06, -0.02), "bd_dark", (0, 0, 8 * ex), 0.008)   # tấm che má
        out.append(p)
        p = Part("Plate", "spine")
        for k, (y0, w) in enumerate([(0.2, 0.0), (0.3, 0.01), (0.4, 0.015), (0.5, 0.01)]):         # giáp ngực chia đoạn
            p.loft([(y0, (0.26 + w) * sw, 0.19 * b), (y0 + 0.085, (0.27 + w) * sw, 0.195 * b)], "bd_dark", 16)
        p.box((0.12, 0.2, 0.03), (0, 0.38, -0.215 * b), "bd_glow", (0, 0, 0), 0.01)               # huy hiệu
        p.box((0.3 * sw, 0.5, 0.05), (0, 0.15, 0.22 * b), "bd_dark", (4, 0, 0), 0.02)              # áo choàng
        p.box((0.34 * sw, 0.8, 0.03), (0, -0.25, 0.25 * b), "bd_pants", (6, 0, 0), 0.01)           # tà áo choàng
        out.append(p)
        p = Part("Tassets", "hips")
        for k in range(-2, 3):
            p.box((0.085, 0.22, 0.04), (0.092 * k * sw, -0.17, -0.14 * b), "bd_dark", (0, 0, 0), 0.01)
        p.loft([(-0.045, 0.21 * sw, 0.135 * b), (0.04, 0.21 * sw, 0.135 * b)], "bd_dark", 16)
        out.append(p)
        for tag, side in (("l", -1), ("r", 1)):
            p = Part("Lames_" + tag, "shoulder_" + tag)
            for k in range(3):
                p.box((0.26 - 0.02 * k, 0.045, 0.26 - 0.02 * k), (0.04 * side, 0.12 - 0.045 * k, 0), "bd_dark", (0, 0, 10 * side), 0.012)
            out.append(p)
            p = Part("Greave_" + tag, "knee_" + tag)
            p.loft([(-0.04, 0.095, 0.1, 0, -0.02), (-0.2, 0.09, 0.098, 0, -0.02), (-0.36, 0.075, 0.08, 0, -0.015)], "bd_dark", 12, 2)
            p.ball((0, 0, -0.07), 0.085, "bd_dark", 10, 6, (1.0, 1.0, 0.7))
            out.append(p)
            p = Part("Vambrace_" + tag, "elbow_" + tag)
            p.loft([(-0.06, 0.075, 0.075), (-0.2, 0.07, 0.07), (-0.38, 0.056, 0.056)], "bd_dark", 12, 2)
            p.ball((0, 0, -0.02), 0.07, "bd_dark", 10, 6, (1.0, 1.0, 0.8))
            out.append(p)
    elif style == "titan":
        p = Part("Helm", "head")
        p.loft([(0.0, 0.105, 0.115), (0.06, 0.16, 0.175), (0.14, 0.172, 0.185), (0.22, 0.155, 0.168), (0.29, 0.085, 0.095), (0.31, 0.03, 0.035)], "bd_dark", 16, 2)
        p.box((0.24, 0.045, 0.03), (0, 0.15, -0.168), "bd_glow", (0, 0, 0), 0.008)
        for ox in (-1.0, 1.0):                                                                     # sừng cong 3 đốt
            p.cone((0.14 * ox, 0.24, 0), 0.05, 0.2, "bd_dark", (0, 0, -22 * ox), 8, 0.035)
            p.cone((0.205 * ox, 0.42, 0), 0.035, 0.16, "bd_dark", (0, 0, -46 * ox), 8, 0.022)
            p.cone((0.31 * ox, 0.545, 0), 0.022, 0.14, "bd_dark", (0, 0, -70 * ox), 8, 0.0)
        p.box((0.07, 0.1, 0.12), (0, 0.33, -0.08), "bd_dark", (-20, 0, 0), 0.01)
        out.append(p)
        p = Part("Plate", "spine")
        p.loft([(0.22, 0.285 * sw, 0.18 * b), (0.32, 0.305 * sw, 0.19 * b), (0.44, 0.31 * sw, 0.188 * b), (0.56, 0.275 * sw, 0.158 * b)], "bd_dark", 16, 2)
        for k in range(4):                                                                         # xương sườn giáp
            p.box((0.2 * sw, 0.025, 0.035), (0, 0.27 + 0.075 * k, -0.2 * b), "bd_pants", (0, 0, 0), 0.006)
        p.box((0.1, 0.36, 0.03), (0, 0.4, -0.215 * b), "bd_glow", (0, 0, 0), 0.008)
        p.box((0.22 * sw, 0.34, 0.12), (0, 0.38, 0.2 * b), "bd_dark", (0, 0, 0), 0.02)
        for k in range(5):                                                                         # gai lưng
            p.cone((0.07 * (k - 2) * sw, 0.5 - 0.03 * abs(k - 2), 0.27 * b), 0.035, 0.12, "bd_dark", (80, 0, 0), 6)
        out.append(p)
        p = Part("Skirt", "hips")
        for k in range(-3, 4):
            p.box((0.1, 0.34 - 0.03 * abs(k), 0.04), (0.098 * k, -0.23, -0.145 * b), "bd_dark", (0, 0, 0), 0.008)
        for k in range(-2, 3):
            p.box((0.1, 0.3, 0.04), (0.11 * k, -0.2, 0.145 * b), "bd_dark", (0, 0, 0), 0.008)
        p.loft([(-0.05, 0.31 * sw, 0.145 * b), (0.05, 0.31 * sw, 0.145 * b)], "bd_dark", 16)
        p.box((0.12, 0.12, 0.05), (0, 0.0, -0.16 * b), "bd_glow", (0, 0, 0), 0.012)             # khoá đai
        out.append(p)
        for tag, side in (("l", -1), ("r", 1)):
            p = Part("Pauldron_" + tag, "shoulder_" + tag)
            p.ball((0.05 * side, 0.07, 0), 0.2, "bd_dark", 12, 6, (1.0, 0.65, 1.0))
            for k in range(4):
                a = math.radians(-60 + 40 * k)
                p.cone((0.05 * side + 0.17 * math.cos(a) * side * 0.4, 0.14 + 0.1 * math.sin(a), 0.15 * math.cos(a) * -0.2 + 0.05 * (k - 1.5)), 0.04, 0.16, "bd_dark", (0, 0, -35 * side + 10 * k), 6)
            out.append(p)
            p = Part("Gauntlet_" + tag, "elbow_" + tag)
            p.loft([(-0.1, 0.085 * b, 0.085 * b), (-0.25, 0.078 * b, 0.078 * b), (-0.4, 0.066 * b, 0.066 * b)], "bd_dark", 12, 2)
            for k in range(3):
                p.cone((0.0, -0.18 - 0.08 * k, -0.09 * b), 0.025, 0.07, "bd_dark", (-90, 0, 0), 5)
            out.append(p)
            p = Part("Greave_" + tag, "knee_" + tag)
            p.ball((0, 0, -0.085), 0.11, "bd_dark", 10, 6, (1.0, 1.0, 0.7))
            p.cone((0, 0, -0.16), 0.04, 0.1, "bd_dark", (-90, 0, 0), 6)
            out.append(p)
    return out


def build_kind(kind):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    rig = RIG[kind]
    sw, b = rig["shoulder"], rig["bulk"]
    mats = {}
    for role in ROLES:
        m = bpy.data.materials.get(role) or bpy.data.materials.new(role)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*lin(ROLE_COLORS[role]), 1.0)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.8
        m.diffuse_color = (*lin(ROLE_COLORS[role]), 1.0)
        mats[role] = m

    # ---- 15 Empty khớp: [cha, vị trí cục bộ] (Godot) ----
    spec = {"hips": ("", (0.0, 0.92, 0.0)), "spine": ("hips", (0, 0, 0)), "head": ("spine", (0.0, 0.62, 0.0))}
    for tag, side in (("l", -1), ("r", 1)):
        spec["shoulder_" + tag] = ("spine", (0.3 * sw * side, 0.52, 0.0))
        spec["elbow_" + tag] = ("shoulder_" + tag, (0.0, -0.45, 0.0))
        spec["hand_" + tag] = ("elbow_" + tag, (0.0, -0.42, 0.0))
        spec["hip_" + tag] = ("hips", (0.13 * side, -0.05, 0.0))
        spec["knee_" + tag] = ("hip_" + tag, (0.0, -0.45, 0.0))
        spec["ankle_" + tag] = ("knee_" + tag, (0.0, -0.38, 0.0))
    joints = {}
    for name, (parent, pos) in spec.items():          # thứ tự khai báo: cha luôn đứng trước con
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 0.05
        bpy.context.scene.collection.objects.link(e)
        if parent:
            e.parent = joints[parent]
        e.location = g(pos)
        joints[name] = e

    parts = []
    # ---- Thân: ngực nở phía trước, eo thon, vai, cổ, xương đòn ----
    p = Part("Torso", "spine")
    p.loft([(-0.03, 0.2 * sw, 0.12 * b, 0, 0.0), (0.05, 0.198 * sw, 0.124 * b, 0, 0.0), (0.16, 0.18 * sw, 0.112 * b, 0, 0.005),
            (0.28, 0.205 * sw, 0.13 * b, 0, -0.008), (0.4, 0.248 * sw, 0.15 * b, 0, -0.015), (0.5, 0.268 * sw, 0.14 * b, 0, -0.006),
            (0.57, 0.2 * sw, 0.1 * b, 0, 0.0), (0.61, 0.09, 0.075)], "bd_cloth", 16, 2)
    p.loft([(-0.045, 0.218 * sw, 0.134 * b), (0.045, 0.218 * sw, 0.134 * b)], "bd_dark", 16, 1)                                       # đai
    p.box((0.05, 0.045, 0.04), (0, 0.0, -0.143 * b), "bd_glow", (0, 0, 0), 0.008)                                                    # khoá đai
    p.loft([(0.57, 0.065, 0.065), (0.62, 0.058, 0.058), (0.7, 0.052, 0.054, 0, -0.004)], "bd_skin", 12, 1)                           # cổ
    p.box((0.13, 0.035, 0.06), (0, 0.585, -0.035), "bd_dark", (-22, 0, 0), 0.006)                                                    # cổ áo trước
    p.box((0.13, 0.04, 0.05), (0, 0.6, 0.045), "bd_dark", (20, 0, 0), 0.006)                                                         # cổ áo sau
    if rig["armor"] >= 2:
        p.loft([(0.24, 0.285 * sw, 0.19 * b), (0.34, 0.3 * sw, 0.2 * b), (0.46, 0.3 * sw, 0.2 * b), (0.56, 0.27 * sw, 0.165 * b)], "bd_dark", 16, 2)
    if rig["glow"]:
        p.box((0.1, 0.5, 0.02), (0, 0.3, -0.21 * b), "bd_glow", (0, 0, 0), 0.004)
    parts.append(p)
    p = Part("Pelvis", "hips")
    p.loft([(0.05, 0.18 * sw, 0.12 * b), (-0.02, 0.19 * sw, 0.126 * b), (-0.1, 0.19 * sw, 0.13 * b, 0, 0.01), (-0.17, 0.168 * sw, 0.115 * b)], "bd_pants", 16, 2)
    parts.append(p)
    # ---- Đầu: sọ, hàm, mũi, mắt, tai ----
    p = Part("Head", "head")
    p.loft([(0.0, 0.052, 0.062, 0, -0.012), (0.03, 0.085, 0.1, 0, -0.008), (0.065, 0.113, 0.13, 0, -0.004), (0.11, 0.128, 0.143),
            (0.16, 0.13, 0.146), (0.205, 0.113, 0.128), (0.245, 0.08, 0.09), (0.268, 0.04, 0.045), (0.276, 0.015, 0.017)], "bd_skin", 16, 2)
    p.box((0.034, 0.06, 0.05), (0, 0.11, -0.157), "bd_skin", (-12, 0, 0), 0.006)                                                      # sống mũi
    p.box((0.05, 0.022, 0.04), (0, 0.082, -0.155), "bd_skin", (0, 0, 0), 0.005)                                                       # chóp mũi
    p.box((0.1, 0.03, 0.025), (0, 0.045, -0.13), "bd_skin", (-10, 0, 0), 0.005)                                                       # cằm
    for ex in (-1.0, 1.0):
        p.ball((0.052 * ex, 0.15, -0.13), 0.022, "bd_glow", 8, 5, (1.2, 0.8, 0.6))                                                    # tròng trắng
        p.ball((0.052 * ex, 0.15, -0.141), 0.011, "bd_dark", 6, 4)                                                                    # đồng tử
        p.box((0.058, 0.013, 0.016), (0.056 * ex, 0.182, -0.135), "bd_dark", (0, 0, -7 * ex), 0.003)                                  # lông mày
        p.box((0.022, 0.065, 0.04), (0.138 * ex, 0.125, 0.0), "bd_skin", (0, 0, 0), 0.006)                                            # tai
    p.box((0.075, 0.014, 0.014), (0, 0.068, -0.138), "bd_dark", (0, 0, 0), 0.002)                                                     # miệng
    parts.append(p)
    for tag, side in (("l", -1), ("r", 1)):
        inner = -side
        # ---- Tay: vai, bắp tay, khuỷu, cẳng tay thon, cổ tay áo ----
        p = Part("Arm_" + tag, "shoulder_" + tag)
        p.ball((0, 0, 0), 0.092 * b, "bd_cloth", 12, 7)
        p.loft([(0.03, 0.08 * b, 0.08 * b), (-0.08, 0.082 * b, 0.084 * b), (-0.2, 0.072 * b, 0.072 * b), (-0.33, 0.062 * b, 0.062 * b), (-0.45, 0.055 * b, 0.055 * b)], "bd_cloth", 12, 2)
        if rig["armor"] >= 1:
            pad = 0.2 if rig["armor"] == 1 else 0.3
            p.box((pad, 0.08, pad), (0.02 * side, 0.065, 0), "bd_dark", (0, 0, 8 * side), 0.014)
        parts.append(p)
        p = Part("Forearm_" + tag, "elbow_" + tag)
        p.ball((0, 0, 0), 0.06 * b, "bd_cloth", 12, 6)
        p.loft([(0.0, 0.058 * b, 0.058 * b), (-0.1, 0.06 * b, 0.06 * b, 0, -0.004), (-0.22, 0.05 * b, 0.05 * b), (-0.33, 0.042 * b, 0.042 * b), (-0.4, 0.038 * b, 0.038 * b)], "bd_cloth", 12, 2)
        p.loft([(-0.35, 0.05 * b, 0.05 * b), (-0.41, 0.05 * b, 0.05 * b)], "bd_dark", 12)
        parts.append(p)
        # ---- Bàn tay: lòng bàn tay, 4 ngón 2 đốt, ngón cái 2 đốt ----
        p = Part("Hand_" + tag, "hand_" + tag)
        p.box((0.08, 0.09, 0.045), (0, -0.045, 0), "bd_skin", (0, 0, 0), 0.01)
        p.box((0.085, 0.02, 0.05), (0, -0.01, 0), "bd_skin", (0, 0, 0), 0.006)
        for k in range(4):
            fx = -0.0285 + 0.019 * k
            ln = 0.042 + 0.006 * (1 if k in (1, 2) else 0)
            p.box((0.0175, ln, 0.024), (fx, -0.09 - ln / 2, 0), "bd_skin", (0, 0, 0), 0.003)
            p.box((0.016, 0.03, 0.022), (fx, -0.09 - ln - 0.012, 0.004), "bd_skin", (10, 0, 0), 0.003)
        p.box((0.024, 0.04, 0.028), (inner * 0.05, -0.065, -0.016), "bd_skin", (0, 0, inner * 25), 0.004)
        p.box((0.022, 0.032, 0.026), (inner * 0.066, -0.098, -0.02), "bd_skin", (0, 0, inner * 35), 0.003)
        parts.append(p)
        # ---- Chân: đùi, gối, ống chân, giày ----
        p = Part("Thigh_" + tag, "hip_" + tag)
        p.loft([(0.03, 0.108 * b, 0.11 * b), (-0.08, 0.118 * b, 0.12 * b), (-0.2, 0.112 * b, 0.112 * b), (-0.33, 0.094 * b, 0.092 * b), (-0.45, 0.082 * b, 0.082 * b)], "bd_pants", 14, 2)
        parts.append(p)
        p = Part("Shin_" + tag, "knee_" + tag)
        p.ball((0, 0, 0), 0.086 * b, "bd_pants", 12, 6)
        p.loft([(0.0, 0.08 * b, 0.08 * b), (-0.08, 0.078 * b, 0.082 * b, 0, 0.006), (-0.2, 0.065 * b, 0.07 * b, 0, 0.006), (-0.3, 0.054 * b, 0.056 * b), (-0.37, 0.05 * b, 0.05 * b), (-0.39, 0.062 * b, 0.062 * b)], "bd_pants", 14, 2)
        parts.append(p)
        p = Part("Boot_" + tag, "ankle_" + tag)
        p.box((0.135, 0.03, 0.3), (0, -0.025, -0.06), "bd_dark", (0, 0, 0), 0.01)                        # đế
        p.box((0.12, 0.022, 0.1), (0, -0.045, -0.15), "bd_dark", (0, 0, 0), 0.006)                       # gót/mũi đế dày
        p.box((0.118, 0.06, 0.2), (0, 0.02, -0.105), "bd_dark", (0, 0, 0), 0.015)                        # mũi giày
        p.ball((0, 0.03, -0.2), 0.058, "bd_dark", 10, 5, (1.0, 0.8, 1.0))                                # mũi tròn
        p.box((0.112, 0.1, 0.11), (0, 0.04, 0.025), "bd_dark", (0, 0, 0), 0.014)                         # gót + cổ
        p.loft([(0.03, 0.062, 0.066, 0, 0.018), (0.11, 0.066, 0.07, 0, 0.018), (0.145, 0.07, 0.074, 0, 0.018)], "bd_dark", 14, 1)   # cổ giày
        for k in range(3):                                                                               # dây giày
            p.box((0.08, 0.008, 0.012), (0, 0.065 - 0.0, -0.1 - 0.03 * k), "bd_pants", (0, 0, 0), 0.002)
        parts.append(p)
    parts += style_parts(kind, rig, sw, b)

    objs = [pt.build(mats, joints) for pt in parts]
    bpy.ops.object.select_all(action="DESELECT")
    for o in list(joints.values()) + objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(OUT_DIR, kind + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
        export_materials="EXPORT", export_cameras=False, export_lights=False, export_normals=False,
        export_texcoords=False, export_extras=False, export_animations=False)
    tris = sum(len(q.vertices) - 2 for o in objs for q in o.data.polygons)
    return {"kind": kind, "tris": tris, "parts": len(objs), "out": path}


result = [build_kind(k) for k in RIG]
if __name__ == "__main__":
    print(result)
