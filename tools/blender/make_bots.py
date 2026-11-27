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

    def box(self, size, center, role, rot=(0.0, 0.0, 0.0), bevel=0.0):
        """Hộp; `bevel` > 0 vát cạnh (thêm tam giác cho bớt vuông)."""
        snap = set(self.bm.faces)
        hx, hy, hz = (s / 2.0 for s in size)
        r = (Matrix.Rotation(math.radians(rot[2]), 3, "Z") @ Matrix.Rotation(math.radians(rot[1]), 3, "Y")
             @ Matrix.Rotation(math.radians(rot[0]), 3, "X"))
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

    def loft(self, rings, role, n=12):
        """Thân tròn nhiều tiết diện: rings = [(y, rx, rz[, ox, oz]), ...] từ trên xuống hoặc dưới lên; hai đầu bịt kín."""
        rs = []
        for r in rings:
            y, rx, rz = r[0], r[1], r[2]
            ox, oz = (r[3], r[4]) if len(r) >= 5 else (0.0, 0.0)
            rs.append([self._v((ox + rx * math.cos(2 * math.pi * i / n), y, oz + rz * math.sin(2 * math.pi * i / n))) for i in range(n)])
        for a, b in zip(rs[:-1], rs[1:]):
            for i in range(n):
                j = (i + 1) % n
                self._face([a[i], a[j], b[j], b[i]], role)
        self._face(list(reversed(rs[0])), role)
        self._face(rs[-1], role)

    def prism_y(self, center, r_top, r_bot, height, role, n=8):
        """Lăng trụ n cạnh dọc trục Y (tay, chân), có thể thon."""
        cx, cy, cz = center
        top = [self._v((cx + r_top * math.cos(2 * math.pi * i / n), cy + height / 2, cz + r_top * math.sin(2 * math.pi * i / n))) for i in range(n)]
        bot = [self._v((cx + r_bot * math.cos(2 * math.pi * i / n), cy - height / 2, cz + r_bot * math.sin(2 * math.pi * i / n))) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            self._face([bot[i], top[i], top[j], bot[j]], role)
        self._face(list(reversed(bot)), role)
        self._face(top, role)

    def ball(self, center, radius, role, u=8, v=5, squash=1.0):
        """Cầu thấp (khớp, đầu, mũ). Dựng bằng bmesh.ops rồi gán vật liệu cho mặt mới."""
        before = set(self.bm.faces)
        m = Matrix.Translation(Vector(g(center))) @ Matrix.Scale(squash, 4, Vector((0, 0, 1)))
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
    """Chi tiết theo loại (nâng chi tiết so với `mannequin.gd::_style_details`), trả về list Part."""
    out = []
    style = rig["style"]
    if style == "ronin":
        p = Part("Hair", "head")
        p.loft([(0.17, 0.138, 0.152, 0, 0.0), (0.21, 0.13, 0.144, 0, 0.012), (0.25, 0.098, 0.11, 0, 0.016), (0.285, 0.045, 0.05, 0, 0.012)], "bd_dark")
        p.box((0.06, 0.2, 0.05), (0, 0.12, 0.15), "bd_dark", (12, 0, 0), 0.006)        # đuôi tóc buộc
        p.loft([(0.165, 0.142, 0.156), (0.205, 0.142, 0.156)], "bd_cloth")             # băng đầu
        p.box((0.04, 0.16, 0.03), (0.03, 0.09, 0.17), "bd_cloth", (8, 0, 6), 0.004)    # đuôi băng
        out.append(p)
        p = Part("Sash", "spine")
        p.box((0.1, 0.56, 0.03), (0, 0.34, -0.155 * b), "bd_dark", (0, 0, 28), 0.006)
        p.box((0.06, 0.06, 0.04), (0, 0.04, -0.14 * b), "bd_glow", (0, 0, 0), 0.008)   # khoá đai
        out.append(p)
        p = Part("Tabard", "hips")
        p.box((0.11, 0.42, 0.04), (0, -0.25, -0.13 * b), "bd_cloth", (0, 0, 0), 0.008)
        p.box((0.11, 0.3, 0.04), (0.17 * sw, -0.2, -0.1 * b), "bd_cloth", (0, 0, 8), 0.008)
        p.box((0.11, 0.3, 0.04), (-0.17 * sw, -0.2, -0.1 * b), "bd_cloth", (0, 0, -8), 0.008)
        out.append(p)
    elif style == "ranger":
        p = Part("Hood", "head")
        p.loft([(0.0, 0.07, 0.085, 0, 0.03), (0.07, 0.15, 0.17, 0, 0.04), (0.15, 0.17, 0.185, 0, 0.045), (0.23, 0.14, 0.16, 0, 0.04), (0.295, 0.07, 0.09, 0, 0.03)], "bd_dark", 12)
        p.box((0.22, 0.05, 0.03), (0, 0.15, -0.14), "bd_glow", (0, 0, 0), 0.006)       # kính
        p.box((0.05, 0.14, 0.04), (0, 0.03, 0.17), "bd_dark", (-18, 0, 0), 0.006)      # đuôi mũ
        out.append(p)
        p = Part("Gear", "spine")
        p.box((0.09, 0.54, 0.03), (0, 0.33, -0.155 * b), "bd_dark", (0, 0, -30), 0.006)
        for k in range(4):                                                              # viên đạn dọc dây
            p.box((0.025, 0.05, 0.03), (-0.0 + 0.045 * (k - 1.5) * math.cos(math.radians(30)), 0.33 - 0.045 * (k - 1.5) * math.sin(math.radians(30)) * -1.0, -0.175 * b), "bd_glow", (0, 0, -30), 0.004)
        p.box((0.2 * sw, 0.26, 0.09), (0, 0.34, 0.2 * b), "bd_dark", (0, 0, 0), 0.015)  # ba lô
        out.append(p)
        p = Part("Pouches", "hips")
        for ox in (-1.0, 1.0):
            p.box((0.11, 0.12, 0.085), (0.22 * sw * ox, -0.07, -0.1 * b), "bd_dark", (0, 0, 0), 0.012)
            p.box((0.115, 0.03, 0.09), (0.22 * sw * ox, -0.015, -0.1 * b), "bd_dark", (0, 0, 0), 0.006)
        out.append(p)
    elif style == "guard":
        p = Part("Helm", "head")
        p.loft([(0.0, 0.1, 0.11), (0.06, 0.15, 0.165), (0.14, 0.165, 0.178), (0.22, 0.15, 0.162), (0.29, 0.09, 0.1), (0.315, 0.04, 0.045)], "bd_dark", 12)
        p.box((0.2, 0.035, 0.03), (0, 0.15, -0.16), "bd_glow", (0, 0, 0), 0.006)       # khe nhìn
        p.box((0.045, 0.1, 0.26), (0, 0.32, 0.0), "bd_dark", (0, 0, 0), 0.01)          # mào
        p.box((0.04, 0.12, 0.05), (0.15, 0.06, 0.0), "bd_dark", (0, 0, 8), 0.006)      # tấm che má
        p.box((0.04, 0.12, 0.05), (-0.15, 0.06, 0.0), "bd_dark", (0, 0, -8), 0.006)
        out.append(p)
        for tag in ("l", "r"):
            p = Part("ShinGuard_" + tag, "knee_" + tag)
            p.box((0.15, 0.22, 0.15), (0, -0.2, -0.03), "bd_dark", (0, 0, 0), 0.015)
            p.ball((0, 0, -0.07), 0.075, "bd_dark", 8, 5)                               # nắp gối
            out.append(p)
            p = Part("ForeGuard_" + tag, "elbow_" + tag)
            p.box((0.12, 0.22, 0.12), (0, -0.2, 0), "bd_dark", (0, 0, 0), 0.015)
            out.append(p)
    elif style == "titan":
        p = Part("Helm", "head")
        p.loft([(0.0, 0.1, 0.11), (0.06, 0.155, 0.17), (0.14, 0.17, 0.182), (0.22, 0.15, 0.162), (0.29, 0.08, 0.09), (0.31, 0.03, 0.035)], "bd_dark", 12)
        p.box((0.22, 0.04, 0.03), (0, 0.15, -0.16), "bd_glow", (0, 0, 0), 0.006)
        for ox in (-1.0, 1.0):                                                          # sừng cong 2 đốt
            p.box((0.06, 0.16, 0.06), (0.15 * ox, 0.27, 0.0), "bd_dark", (0, 0, -20 * ox), 0.008)
            p.box((0.045, 0.14, 0.045), (0.2 * ox, 0.4, 0.0), "bd_dark", (0, 0, -42 * ox), 0.006)
        out.append(p)
        p = Part("Plate", "spine")
        p.loft([(0.26, 0.285 * sw, 0.17 * b), (0.36, 0.3 * sw, 0.18 * b), (0.46, 0.3 * sw, 0.175 * b), (0.56, 0.27 * sw, 0.15 * b)], "bd_dark", 12)
        p.box((0.1, 0.34, 0.03), (0, 0.4, -0.19 * b), "bd_glow", (0, 0, 0), 0.006)   # vạch sáng giữa ngực
        p.box((0.2 * sw, 0.3, 0.1), (0, 0.38, 0.19 * b), "bd_dark", (0, 0, 0), 0.015)  # giáp lưng
        out.append(p)
        p = Part("Skirt", "hips")
        for k in range(-2, 3):
            p.box((0.11, 0.32 - 0.03 * abs(k), 0.04), (0.105 * k, -0.22, -0.14 * b), "bd_dark", (0, 0, 0), 0.008)
        p.box((0.3 * sw, 0.05, 0.28 * b), (0, 0.0, 0), "bd_dark", (0, 0, 0), 0.008)    # đai to
        out.append(p)
        for tag, side in (("l", -1), ("r", 1)):
            p = Part("Pauldron_" + tag, "shoulder_" + tag)
            p.ball((0.05 * side, 0.07, 0), 0.19, "bd_dark", 10, 5, 0.65)               # vai to
            for k in range(3):                                                           # gai vai
                p.box((0.03, 0.09, 0.03), (0.05 * side + 0.07 * side * (k - 1) * 0.6, 0.2 - 0.02 * abs(k - 1), 0.07 * (k - 1)), "bd_dark", (0, 0, -15 * side), 0.004)
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
    p = Part("Torso", "spine")
    p.loft([(-0.02, 0.2 * sw, 0.12 * b), (0.04, 0.2 * sw, 0.125 * b), (0.16, 0.185 * sw, 0.115 * b), (0.28, 0.21 * sw, 0.13 * b),
            (0.42, 0.255 * sw, 0.15 * b), (0.54, 0.27 * sw, 0.135 * b), (0.6, 0.13 * sw, 0.09 * b)], "bd_cloth", 12)
    p.loft([(-0.04, 0.215 * sw, 0.13 * b), (0.04, 0.215 * sw, 0.13 * b)], "bd_dark", 12)               # đai
    p.loft([(0.58, 0.06, 0.06), (0.68, 0.05, 0.05)], "bd_skin", 10)                                      # cổ
    p.box((0.12, 0.03, 0.05), (0, 0.57, -0.03), "bd_dark", (-20, 0, 0), 0.005)                           # cổ áo
    if rig["armor"] >= 2:
        p.loft([(0.24, 0.285 * sw, 0.19 * b), (0.34, 0.3 * sw, 0.2 * b), (0.46, 0.3 * sw, 0.2 * b), (0.56, 0.27 * sw, 0.165 * b)], "bd_dark", 12)   # giáp ngực
    if rig["glow"]:
        p.box((0.1, 0.5, 0.02), (0, 0.3, -0.2 * b), "bd_glow", (0, 0, 0), 0.004)                         # vạch sáng
    parts.append(p)
    p = Part("Pelvis", "hips")
    p.loft([(0.04, 0.18 * sw, 0.12 * b), (-0.06, 0.19 * sw, 0.125 * b), (-0.16, 0.165 * sw, 0.115 * b)], "bd_pants", 12)
    parts.append(p)
    p = Part("Head", "head")
    p.loft([(0.0, 0.05, 0.06, 0, -0.01), (0.04, 0.095, 0.11, 0, -0.005), (0.08, 0.12, 0.135), (0.13, 0.13, 0.145), (0.18, 0.125, 0.138),
            (0.225, 0.1, 0.11), (0.255, 0.055, 0.06), (0.268, 0.02, 0.022)], "bd_skin", 12)
    p.box((0.03, 0.05, 0.045), (0, 0.115, -0.152), "bd_skin", (-10, 0, 0), 0.004)                         # mũi
    for ex in (-1.0, 1.0):
        p.box((0.034, 0.022, 0.014), (0.052 * ex, 0.15, -0.135), "bd_dark", (0, 0, 0), 0.003)            # mắt
        p.box((0.05, 0.012, 0.014), (0.055 * ex, 0.178, -0.135), "bd_dark", (0, 0, -6 * ex), 0.002)      # lông mày
        p.box((0.02, 0.06, 0.035), (0.14 * ex, 0.125, 0.0), "bd_skin", (0, 0, 0), 0.004)                # tai
    p.box((0.07, 0.014, 0.014), (0, 0.075, -0.135), "bd_dark", (0, 0, 0), 0.002)                         # miệng
    parts.append(p)
    for tag, side in (("l", -1), ("r", 1)):
        inner = -side
        p = Part("Arm_" + tag, "shoulder_" + tag)
        p.ball((0, 0, 0), 0.09 * b, "bd_cloth", 10, 6)                                                    # vai
        p.loft([(0.02, 0.078 * b, 0.078 * b), (-0.1, 0.076 * b, 0.076 * b), (-0.25, 0.066 * b, 0.066 * b), (-0.45, 0.054 * b, 0.054 * b)], "bd_cloth", 10)
        if rig["armor"] >= 1:
            pad = 0.2 if rig["armor"] == 1 else 0.3
            p.box((pad, 0.08, pad), (0.02 * side, 0.06, 0), "bd_dark", (0, 0, 8 * side), 0.012)           # giáp vai
        parts.append(p)
        p = Part("Forearm_" + tag, "elbow_" + tag)
        p.ball((0, 0, 0), 0.058 * b, "bd_cloth", 10, 5)                                                   # khuỷu
        p.loft([(0.0, 0.058 * b, 0.058 * b), (-0.15, 0.056 * b, 0.056 * b), (-0.3, 0.047 * b, 0.047 * b), (-0.4, 0.04 * b, 0.04 * b)], "bd_cloth", 10)
        p.loft([(-0.34, 0.052 * b, 0.052 * b), (-0.41, 0.052 * b, 0.052 * b)], "bd_dark", 10)             # cổ tay áo
        parts.append(p)
        p = Part("Hand_" + tag, "hand_" + tag)
        p.box((0.08, 0.09, 0.045), (0, -0.045, 0), "bd_skin", (0, 0, 0), 0.008)                           # lòng bàn tay
        for k in range(4):                                                                                 # 4 ngón
            p.box((0.017, 0.07, 0.024), (-0.0285 + 0.019 * k, -0.125, 0), "bd_skin", (0, 0, 0), 0.003)
        p.box((0.022, 0.055, 0.026), (inner * 0.05, -0.07, -0.015), "bd_skin", (0, 0, inner * 25), 0.003)  # ngón cái
        parts.append(p)
        p = Part("Thigh_" + tag, "hip_" + tag)
        p.loft([(0.02, 0.112 * b, 0.112 * b), (-0.12, 0.116 * b, 0.116 * b), (-0.28, 0.1 * b, 0.1 * b), (-0.45, 0.082 * b, 0.082 * b)], "bd_pants", 10)
        parts.append(p)
        p = Part("Shin_" + tag, "knee_" + tag)
        p.ball((0, 0, 0), 0.085 * b, "bd_pants", 10, 5)                                                   # đầu gối
        p.loft([(0.0, 0.08 * b, 0.08 * b), (-0.12, 0.076 * b, 0.078 * b), (-0.28, 0.062 * b, 0.064 * b), (-0.38, 0.052 * b, 0.052 * b)], "bd_pants", 10)
        parts.append(p)
        p = Part("Boot_" + tag, "ankle_" + tag)
        p.box((0.13, 0.03, 0.29), (0, -0.025, -0.06), "bd_dark", (0, 0, 0), 0.008)                         # đế
        p.box((0.115, 0.06, 0.2), (0, 0.02, -0.105), "bd_dark", (0, 0, 0), 0.012)                          # mũi giày
        p.box((0.11, 0.1, 0.11), (0, 0.04, 0.025), "bd_dark", (0, 0, 0), 0.012)                            # gót + cổ
        p.box((0.125, 0.05, 0.125), (0, 0.095, 0.02), "bd_dark", (0, 0, 0), 0.01)                          # cổ giày
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
