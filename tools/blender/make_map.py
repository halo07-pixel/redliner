"""Dựng module bản đồ Vô Tận low poly (M45) -> `assets/map/lowpoly/*.glb`.

Mỗi module là một "vỏ" hiển thị cho MỘT hộp va chạm của Maps.endless: mesh nằm gọn trong khối đơn vị 1x1x1 (tâm ở gốc, y từ -0.5 tới 0.5),
lúc chạy được co giãn đúng bằng kích thước hộp va chạm nên hình và va chạm luôn khớp. Mọi chi tiết nằm TRONG hộp (không lấn ra ngoài)
trừ vài phụ kiện nhỏ trên nóc. Vật liệu đặt tên theo vai trò: `mod_wall` (thân), `mod_trim` (viền/khung), `mod_glow` (cửa sổ/vạch sáng);
màu thật do `scripts/endless_modules.gd` tô khi chạy. Ngân sách: tối đa 3000 tam giác mỗi module (Global.LOWPOLY["budget"]["prop"]).
Chạy: `python3 tools/blender/make_map.py` (bpy) hoặc trong Blender. Thư mục ra: REDLINER_MAP_OUT.
"""
import math
import os
import tempfile

import bpy  # phải nạp trước bmesh khi chạy ngoài Blender
import bmesh

OUT_DIR = os.environ.get("REDLINER_MAP_OUT", tempfile.gettempdir())
ROLES = ["mod_wall", "mod_trim", "mod_glow"]
COLORS = {"mod_wall": (0.62, 0.64, 0.7), "mod_trim": (0.28, 0.29, 0.33), "mod_glow": (0.25, 0.85, 1.0)}


def lin(c):
    return [(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]


class Mod:
    """Hình học viết theo toạ độ Godot (x phải, y lên, z về phía người xem) trong khối tham chiếu W x H x D, gốc giữa đáy."""

    def __init__(self, W, H, D):
        self.W, self.H, self.D = W, H, D
        self.bm = bmesh.new()

    def _v(self, x, y, z):
        # chuẩn hoá về khối đơn vị (tâm ở gốc), rồi đổi sang trục Blender (x, -z, y)
        ux, uy, uz = x / self.W, y / self.H - 0.5, z / self.D
        return self.bm.verts.new((ux, -uz, uy))

    def quad(self, p, role):
        vs = [self._v(*q) for q in p]
        f = self.bm.faces.new(vs)
        f.material_index = ROLES.index(role)
        f.smooth = False

    def box(self, x0, x1, y0, y1, z0, z1, role):
        P = lambda x, y, z: (x, y, z)
        a, b, c, d = P(x0, y0, z0), P(x1, y0, z0), P(x1, y0, z1), P(x0, y0, z1)
        e, f, g, h = P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)
        for q in ((a, b, c, d), (e, h, g, f), (a, e, f, b), (d, c, g, h), (a, d, h, e), (b, f, g, c)):
            self.quad(q, role)

    def win(self, face, u, y, w, h, role="mod_glow", out=0.0):
        """Mặt phẳng cửa sổ trên mặt `face` (+z, -z, +x, -x) tại toạ độ ngang u, cao y..y+h, rộng w."""
        W2, D2 = self.W / 2, self.D / 2
        if face == "+z":
            self.quad(((u - w / 2, y, D2 + out), (u + w / 2, y, D2 + out), (u + w / 2, y + h, D2 + out), (u - w / 2, y + h, D2 + out)), role)
        elif face == "-z":
            self.quad(((u + w / 2, y, -D2 - out), (u - w / 2, y, -D2 - out), (u - w / 2, y + h, -D2 - out), (u + w / 2, y + h, -D2 - out)), role)
        elif face == "+x":
            self.quad(((W2 + out, y, u + w / 2), (W2 + out, y, u - w / 2), (W2 + out, y + h, u - w / 2), (W2 + out, y + h, u + w / 2)), role)
        else:
            self.quad(((-W2 - out, y, u - w / 2), (-W2 - out, y, u + w / 2), (-W2 - out, y + h, u + w / 2), (-W2 - out, y + h, u - w / 2)), role)

    def prism(self, cx, cz, r, y0, y1, n, role, rz=None):
        rz = r if rz is None else rz
        ring0 = [(cx + r * math.cos(2 * math.pi * i / n), cz + rz * math.sin(2 * math.pi * i / n)) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            (ax, az), (bx, bz) = ring0[i], ring0[j]
            self.quad(((ax, y0, az), (bx, y0, bz), (bx, y1, bz), (ax, y1, az)), role)
        self.quad([(x, y1, z) for x, z in ring0], role)
        self.quad([(x, y0, z) for x, z in reversed(ring0)], role)

    def export(self, name):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        mats = []
        for r in ROLES:
            m = bpy.data.materials.get(r) or bpy.data.materials.new(r)
            m.use_nodes = True
            b = m.node_tree.nodes["Principled BSDF"]
            b.inputs["Base Color"].default_value = (*lin(COLORS[r]), 1.0)
            b.inputs["Metallic"].default_value = 0.0
            b.inputs["Roughness"].default_value = 0.8
            m.diffuse_color = (*lin(COLORS[r]), 1.0)
            mats.append(m)
        me = bpy.data.meshes.new(name + "Mesh")
        self.bm.to_mesh(me)
        for m in mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        path = os.path.join(OUT_DIR, name + ".glb")
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
            export_materials="EXPORT", export_cameras=False, export_lights=False, export_normals=False,
            export_texcoords=False, export_extras=False, export_animations=False)
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        self.bm.free()
        return {"name": name, "tris": tris, "out": path, "bytes": os.path.getsize(path)}


# ------------------------------------------------------------------ toà nhà (tham chiếu 20 x 20 x 20)
IN = 0.3   # thân lùi vào so với hộp va chạm; phào / cột góc chạm tới mép hộp


def building_base(m):
    W2, D2, H = m.W / 2, m.D / 2, m.H
    m.box(-W2 + IN, W2 - IN, 1.2, H - 0.6, -D2 + IN, D2 - IN, "mod_wall")     # thân
    m.box(-W2, W2, 0.0, 1.2, -D2, D2, "mod_trim")                              # bệ chân
    for sx in (-1, 1):                                                          # cột góc
        for sz in (-1, 1):
            m.box(sx * W2 - (0.9 if sx > 0 else 0), sx * W2 + (0 if sx > 0 else 0.9) , 1.2, H - 0.6,
                  sz * D2 - (0.9 if sz > 0 else 0), sz * D2 + (0 if sz > 0 else 0.9), "mod_trim")
    m.box(-W2, W2, H - 0.6, H, -D2, D2, "mod_trim")                             # phào đỉnh
    # cửa vào (cả 4 mặt): khung tối + ô sáng, nằm trong hộp
    m.box(-1.5, 1.5, 1.2, 3.9, D2 - 0.5, D2 - 0.05, "mod_trim")
    m.box(-1.5, 1.5, 1.2, 3.9, -D2 + 0.05, -D2 + 0.5, "mod_trim")
    m.box(W2 - 0.5, W2 - 0.05, 1.2, 3.9, -1.5, 1.5, "mod_trim")
    m.box(-W2 + 0.05, -W2 + 0.5, 1.2, 3.9, -1.5, 1.5, "mod_trim")
    for face in ("+z", "-z", "+x", "-x"):
        m.win(face, 0.0, 1.2, 2.0, 2.3, "mod_glow", out=0.0)


def roof_clutter(m, kind):
    W2, D2, H = m.W / 2, m.D / 2, m.H
    # lan can mái
    m.box(-W2, W2, H, H + 0.5, -D2, -D2 + 0.4, "mod_trim")
    m.box(-W2, W2, H, H + 0.5, D2 - 0.4, D2, "mod_trim")
    m.box(-W2, -W2 + 0.4, H, H + 0.5, -D2 + 0.4, D2 - 0.4, "mod_trim")
    m.box(W2 - 0.4, W2, H, H + 0.5, -D2 + 0.4, D2 - 0.4, "mod_trim")
    # giữ trống tâm (bệ móc 4x4) và góc +x,+z (cột ăng-ten)
    for (x, z, s) in ((-6.0, -6.0, 2.2), (-6.0, 4.0, 2.0), (4.0, -6.5, 1.8)):
        m.box(x - s / 2, x + s / 2, H, H + 1.2, z - s / 2, z + s / 2, "mod_trim")
        m.box(x - s / 2 + 0.2, x + s / 2 - 0.2, H + 1.2, H + 1.4, z - s / 2 + 0.2, z + s / 2 - 0.2, "mod_wall")
        m.prism(x, z, s * 0.32, H + 1.4, H + 1.7, 8, "mod_trim")
    if kind == "block":
        m.prism(-6.0, 7.0, 1.3, H, H + 2.4, 12, "mod_trim")                     # bồn nước
        m.prism(-6.0, 7.0, 1.4, H + 2.4, H + 2.6, 12, "mod_wall")
        for a in range(4):
            ang = a * math.pi / 2 + math.pi / 4
            m.box(-6.0 + 1.1 * math.cos(ang) - 0.12, -6.0 + 1.1 * math.cos(ang) + 0.12, H, H + 1.0, 7.0 + 1.1 * math.sin(ang) - 0.12, 7.0 + 1.1 * math.sin(ang) + 0.12, "mod_trim")
    elif kind == "fins":
        for k in range(3):                                                       # lõi thang
            m.box(-W2 + 1.0 + k * 2.4, -W2 + 2.8 + k * 2.4, H, H + 1.6 + 0.4 * k, 6.0, 8.2, "mod_wall")
    else:
        for k in range(4):                                                       # dàn pin mặt trời nghiêng
            z = -2.0 + k * 1.6
            m.quad(((6.0 - 3.0, H + 0.3, z), (6.0 + 3.0, H + 0.3, z), (6.0 + 3.0, H + 1.0, z + 1.0), (6.0 - 3.0, H + 1.0, z + 1.0)), "mod_glow")
            m.box(6.0 - 3.0, 6.0 + 3.0, H, H + 0.3, z, z + 0.2, "mod_trim")


def sills_and_windows(m, rows, cols, y0, row_h, win_h, win_w, sill=True):
    W2, D2 = m.W / 2, m.D / 2
    for r in range(rows):
        y = y0 + row_h * r
        for face in ("+z", "-z", "+x", "-x"):
            span = m.W if face in ("+z", "-z") else m.D
            for c in range(cols):
                u = -span / 2 + span * (c + 0.5) / cols
                m.win(face, u, y, win_w, win_h, "mod_glow", out=-IN + 0.05)
                if sill:
                    if face in ("+z", "-z"):
                        sz = (D2 - IN - 0.0, D2) if face == "+z" else (-D2, -D2 + IN)
                        m.box(u - win_w / 2 - 0.2, u + win_w / 2 + 0.2, y - 0.25, y, sz[0], sz[1], "mod_trim")
                    else:
                        sx = (W2 - IN, W2) if face == "+x" else (-W2, -W2 + IN)
                        m.box(sx[0], sx[1], y - 0.25, y, u - win_w / 2 - 0.2, u + win_w / 2 + 0.2, "mod_trim")
                    # mi cửa sổ (lintel) mỏng hơn bệ cửa
                    if face in ("+z", "-z"):
                        lz = (D2 - IN * 0.6, D2) if face == "+z" else (-D2, -D2 + IN * 0.6)
                        m.box(u - win_w / 2 - 0.15, u + win_w / 2 + 0.15, y + win_h, y + win_h + 0.2, lz[0], lz[1], "mod_trim")
                    else:
                        lx = (W2 - IN * 0.6, W2) if face == "+x" else (-W2, -W2 + IN * 0.6)
                        m.box(lx[0], lx[1], y + win_h, y + win_h + 0.2, u - win_w / 2 - 0.15, u + win_w / 2 + 0.15, "mod_trim")


def build_block():
    m = Mod(20.0, 20.0, 20.0)
    building_base(m)
    sills_and_windows(m, rows=5, cols=4, y0=2.6, row_h=3.4, win_h=2.0, win_w=2.4)
    roof_clutter(m, "block")
    return m.export("building_block")


def build_fins():
    m = Mod(20.0, 20.0, 20.0)
    building_base(m)
    W2, D2, H = m.W / 2, m.D / 2, m.H
    for face in ("+z", "-z", "+x", "-x"):
        span = m.W if face in ("+z", "-z") else m.D
        n = 7
        for c in range(n):
            u = -span / 2 + span * (c + 0.5) / n
            m.win(face, u, 2.4, 1.5, H - 3.6, "mod_glow", out=-IN + 0.05)
            for fl in range(4):                                                  # tấm ốp giữa các tầng trong mỗi nhịp
                yy = 2.4 + (H - 3.6) * (fl + 1) / 5.0
                if face in ("+z", "-z"):
                    z0, z1 = (D2 - IN * 0.7, D2 - 0.05) if face == "+z" else (-D2 + 0.05, -D2 + IN * 0.7)
                    m.box(u - 0.75, u + 0.75, yy - 0.12, yy + 0.12, z0, z1, "mod_trim")
                else:
                    x0, x1 = (W2 - IN * 0.7, W2 - 0.05) if face == "+x" else (-W2 + 0.05, -W2 + IN * 0.7)
                    m.box(x0, x1, yy - 0.12, yy + 0.12, u - 0.75, u + 0.75, "mod_trim")
            if c > 0:
                uf = -span / 2 + span * c / n
                if face in ("+z", "-z"):
                    z0, z1 = (D2 - IN, D2 - 0.02) if face == "+z" else (-D2 + 0.02, -D2 + IN)
                    m.box(uf - 0.22, uf + 0.22, 1.2, H - 0.6, z0, z1, "mod_trim")
                else:
                    x0, x1 = (W2 - IN, W2 - 0.02) if face == "+x" else (-W2 + 0.02, -W2 + IN)
                    m.box(x0, x1, 1.2, H - 0.6, uf - 0.22, uf + 0.22, "mod_trim")
    roof_clutter(m, "fins")
    return m.export("building_fins")


def build_slab():
    m = Mod(20.0, 20.0, 20.0)
    building_base(m)
    W2, D2, H = m.W / 2, m.D / 2, m.H
    for r in range(5):
        y = 2.5 + 3.4 * r
        for face in ("+z", "-z", "+x", "-x"):
            span = m.W if face in ("+z", "-z") else m.D
            m.win(face, 0.0, y, span - 3.0, 1.8, "mod_glow", out=-IN + 0.05)
            for k in range(1, 6):                                                # nan dọc chia ô kính
                u = -(span - 3.0) / 2 + (span - 3.0) * k / 6
                if face in ("+z", "-z"):
                    z0, z1 = (D2 - IN * 0.7, D2 - 0.05) if face == "+z" else (-D2 + 0.05, -D2 + IN * 0.7)
                    m.box(u - 0.08, u + 0.08, y, y + 1.8, z0, z1, "mod_trim")
                else:
                    x0, x1 = (W2 - IN * 0.7, W2 - 0.05) if face == "+x" else (-W2 + 0.05, -W2 + IN * 0.7)
                    m.box(x0, x1, y, y + 1.8, u - 0.08, u + 0.08, "mod_trim")
            if face in ("+z", "-z"):
                z0, z1 = (D2 - 0.6, D2) if face == "+z" else (-D2, -D2 + 0.6)
                m.box(-W2 + 0.9, W2 - 0.9, y + 2.0, y + 2.3, z0, z1, "mod_trim")
            else:
                x0, x1 = (W2 - 0.6, W2) if face == "+x" else (-W2, -W2 + 0.6)
                m.box(x0, x1, y + 2.0, y + 2.3, -D2 + 0.9, D2 - 0.9, "mod_trim")
    roof_clutter(m, "slab")
    return m.export("building_slab")


# ------------------------------------------------------------------ cột (tham chiếu 2.5 x 15 x 2.5)
def build_pillar():
    m = Mod(2.5, 15.0, 2.5)
    H = m.H
    m.box(-1.25, 1.25, 0.0, 0.5, -1.25, 1.25, "mod_trim")                        # chân
    m.box(-1.0, 1.0, 0.5, 0.9, -1.0, 1.0, "mod_wall")
    m.prism(0, 0, 1.0, 0.9, H - 1.0, 12, "mod_wall")                             # thân tròn 12 cạnh (nằm trong hộp)
    for y in (3.0, 7.5, 12.0):                                                   # vòng gờ
        m.prism(0, 0, 1.15, y, y + 0.25, 12, "mod_trim")
    for k in range(4):                                                           # dải sáng dọc
        a = k * math.pi / 2
        m.box(1.0 * math.cos(a) * 0.98 - 0.08 - 0.0 * math.sin(a), 1.0 * math.cos(a) * 0.98 + 0.08, 1.4, H - 1.8,
              1.0 * math.sin(a) * 0.98 - 0.08, 1.0 * math.sin(a) * 0.98 + 0.08, "mod_glow")
    m.box(-1.0, 1.0, H - 1.0, H - 0.5, -1.0, 1.0, "mod_wall")                    # đài cột
    m.box(-1.25, 1.25, H - 0.5, H, -1.25, 1.25, "mod_trim")
    return m.export("pillar")


# ------------------------------------------------------------------ bệ sân khấu (tham chiếu 16 x 2 x 16)
def build_stage():
    m = Mod(16.0, 2.0, 16.0)
    W2 = 8.0
    m.box(-W2, W2, 0.0, 0.25, -W2, W2, "mod_trim")                               # chân
    m.box(-W2 + 0.2, W2 - 0.2, 0.25, 1.7, -W2 + 0.2, W2 - 0.2, "mod_wall")       # thân
    m.box(-W2, W2, 1.7, 2.0, -W2, W2, "mod_trim")                                # mặt bệ
    for sx in (-1, 1):
        for sz in (-1, 1):                                                       # cột góc
            m.box(sx * W2 - (0.5 if sx > 0 else 0), sx * W2 + (0 if sx > 0 else 0.5), 0.25, 1.7,
                  sz * W2 - (0.5 if sz > 0 else 0), sz * W2 + (0 if sz > 0 else 0.5), "mod_trim")
    for k in range(7):                                                           # khe thông gió + vạch sáng bên sườn
        u = -W2 + 1.4 + k * 1.85
        m.win("+z", u, 0.55, 1.1, 0.7, "mod_glow", out=-0.18)
        m.win("-z", u, 0.55, 1.1, 0.7, "mod_glow", out=-0.18)
        m.win("+x", u, 0.55, 1.1, 0.7, "mod_glow", out=-0.18)
        m.win("-x", u, 0.55, 1.1, 0.7, "mod_glow", out=-0.18)
    for k in range(4):                                                           # mũi tên chỉ hướng trên mặt (mỏng, sát mặt bệ)
        a = k * math.pi / 2
        cx, cz = 5.2 * math.cos(a), 5.2 * math.sin(a)
        m.quad(((cx - 0.9, 2.01, cz - 0.9), (cx + 0.9, 2.01, cz - 0.9), (cx + 0.9, 2.01, cz + 0.9), (cx - 0.9, 2.01, cz + 0.9)), "mod_glow")
    return m.export("stage")


# ------------------------------------------------------------------ bức che thấp (tham chiếu 8 x 1.4 x 0.8)
def build_cover():
    m = Mod(8.0, 1.4, 0.8)
    m.box(-4.0, 4.0, 0.0, 0.2, -0.4, 0.4, "mod_trim")
    m.box(-3.9, 3.9, 0.2, 1.15, -0.35, 0.35, "mod_wall")
    m.box(-4.0, 4.0, 1.15, 1.4, -0.4, 0.4, "mod_trim")
    for sx in (-1, 1):
        m.box(sx * 4.0 - (0.4 if sx > 0 else 0), sx * 4.0 + (0 if sx > 0 else 0.4), 0.2, 1.15, -0.4, 0.4, "mod_trim")
    for k in range(5):
        u = -3.0 + 1.5 * k
        m.win("+z", u, 0.45, 0.8, 0.35, "mod_glow", out=0.0)
        m.win("-z", u, 0.45, 0.8, 0.35, "mod_glow", out=0.0)
    return m.export("cover")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for fn in (build_block, build_fins, build_slab, build_pillar, build_stage, build_cover):
        print(fn())
