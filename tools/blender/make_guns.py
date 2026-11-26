"""Dựng 4 súng low poly của Redliner (M43) trong Blender và xuất `assets/weapons/lowpoly/<súng>.glb`.

Chạy: `python3 tools/blender/make_guns.py` (module `bpy`, pip install bpy==5.3.0) hoặc dán vào Scripting trong Blender.
Thư mục ra: biến môi trường REDLINER_GUN_OUT (mặc định thư mục tạm). Chuẩn: docs/ASSETS.md ("Chuẩn low poly").

Hình học viết theo hệ toạ độ GODOT (x phải, y lên, -z phía trước = nòng) cho khớp với `viewmodel.gd`; hàm `g()` đổi sang
hệ Blender (Godot (x,y,z) = Blender (x,-z,y)); glTF xuất ngược lại đúng hệ Godot. Gốc = bàn tay cầm. Màu phẳng từ PALETTE.
Phần cử động khi nạp đạn là object riêng đặt tên Mag / Pump / Cap / Bolt, gốc object = trục xoay (viewmodel tìm theo tên).
Empty `muzzle` đánh dấu miệng nòng (viewmodel đặt chớp lửa theo z của nó).
"""
import math
import os
import tempfile

import bpy  # phải nạp trước bmesh khi chạy ngoài Blender
import bmesh
from mathutils import Matrix, Vector

OUT_DIR = os.environ.get("REDLINER_GUN_OUT", tempfile.gettempdir())

# Khớp `Global.PALETTE` (sRGB). Đổi ở đây thì đổi cả visual_data.gd.
PAL = {
    "gun_metal": (0.17, 0.18, 0.21),
    "gun_metal_light": (0.3194, 0.3276, 0.3522),
    "steel_dark": (0.4875, 0.507, 0.546),
    "gold": (0.80, 0.65, 0.25),
    "wood": (0.32, 0.20, 0.10),
    "red": (0.70, 0.15, 0.10),
    "scope_dark": (0.08, 0.08, 0.10),
}
MAT_ORDER = list(PAL.keys())


def lin(c):
    return [(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]


def g(v):
    """Godot (x, y, z) -> Blender."""
    return (v[0], -v[2], v[1])


class Part:
    """Một object Blender: gốc tại `origin` (toạ độ Godot), hình học cho theo toạ độ Godot TUYỆT ĐỐI."""

    def __init__(self, name, origin=(0.0, 0.0, 0.0)):
        self.name = name
        self.origin = Vector(origin)
        self.bm = bmesh.new()

    def _face(self, verts, mat):
        f = self.bm.faces.new(verts)
        f.material_index = MAT_ORDER.index(mat)
        f.smooth = False

    def _v(self, p):
        return self.bm.verts.new(g(Vector(p) - self.origin))

    def box(self, size, center, mat, rot_x=0.0):
        """Hộp `size` (x,y,z) tâm `center`, xoay quanh trục X của Godot `rot_x` độ quanh tâm."""
        hx, hy, hz = (s / 2.0 for s in size)
        rot = Matrix.Rotation(math.radians(rot_x), 3, "X")
        c = Vector(center)
        pts = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
               (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        v = [self._v(c + rot @ Vector(p)) for p in pts]
        # Godot: z âm = trước. Mặt ngoài theo chiều ngược kim đồng hồ nhìn từ ngoài.
        for idx in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)]:
            self._face([v[i] for i in idx], mat)

    def prism_z(self, r, z0, z1, center_xy, mat, n=8):
        """Lăng trụ n cạnh dọc trục Z (nòng, ống ngắm), z0 < z1."""
        cx, cy = center_xy
        a = [self._v((cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n), z0)) for i in range(n)]
        b = [self._v((cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n), z1)) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            self._face([a[i], a[j], b[j], b[i]], mat)
        self._face(list(reversed(a)), mat)
        self._face(b, mat)

    def build(self, mats):
        me = bpy.data.meshes.new(self.name + "Mesh")
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for k in MAT_ORDER:
            me.materials.append(mats[k])
        ob = bpy.data.objects.new(self.name, me)
        ob.location = g(self.origin)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def make_gun(name, builder, muzzle):
    """Dựng một súng, xuất `<OUT_DIR>/<name>.glb`. Trả về {tris, size...}."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    mats = {}
    for k in MAT_ORDER:
        m = bpy.data.materials.get("gn_" + k) or bpy.data.materials.new("gn_" + k)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*lin(PAL[k]), 1.0)
        b.inputs["Metallic"].default_value = 0.0
        b.inputs["Roughness"].default_value = 0.6
        m.diffuse_color = (*lin(PAL[k]), 1.0)
        mats[k] = m
    parts = builder()
    objs = [p.build(mats) for p in parts]
    em = bpy.data.objects.new("muzzle", None)
    em.empty_display_type = "ARROWS"
    em.location = g(muzzle)
    bpy.context.scene.collection.objects.link(em)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs + [em]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
        export_materials="EXPORT", export_cameras=False, export_lights=False, export_normals=False,
        export_texcoords=False, export_extras=False, export_animations=False)
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    return {"name": name, "tris": tris, "out": path}


def pistol():
    body = Part("Pistol")
    body.box((0.05, 0.04, 0.2), (0, 0, -0.08), "gun_metal")                      # khung
    body.box((0.056, 0.05, 0.27), (0, 0.045, -0.1), "gun_metal_light")           # thân trượt
    body.prism_z(0.014, -0.32, -0.23, (0, 0.048), "gun_metal")                   # nòng
    body.box((0.018, 0.016, 0.02), (0, 0.078, -0.2), "gun_metal")                # đầu ruồi
    body.box((0.048, 0.11, 0.055), (0, -0.065, 0.02), "gun_metal", 12.0)         # báng
    body.box((0.016, 0.03, 0.07), (0, -0.035, -0.045), "gun_metal")              # bao cò
    body.box((0.058, 0.012, 0.2), (0, 0.074, -0.1), "steel_dark")                # rãnh trượt
    body.box((0.012, 0.014, 0.05), (0, 0.076, 0.0), "gun_metal")                 # khe ngắm sau
    body.box((0.052, 0.02, 0.05), (0, -0.01, -0.17), "gold")                     # vòng khoá nòng
    for z in (-0.005, 0.015, 0.035):                                              # khía trượt
        body.box((0.06, 0.036, 0.007), (0, 0.045, z), "steel_dark")
    body.box((0.012, 0.025, 0.02), (0, 0.06, 0.045), "gun_metal")                # búa
    body.box((0.03, 0.012, 0.03), (0, -0.015, -0.06), "gun_metal")               # cò
    body.box((0.052, 0.012, 0.06), (0, 0.025, -0.255), "steel_dark")             # mũi trượt
    mag = Part("Mag")
    mag.box((0.04, 0.05, 0.045), (0, -0.135, 0.03), "steel_dark", 12.0)          # băng đạn thò dưới báng
    return [body, mag]


def shotgun():
    body = Part("Shotgun")
    body.prism_z(0.015, -0.55, -0.05, (-0.02, 0.05), "gun_metal")                # nòng trái
    body.prism_z(0.015, -0.55, -0.05, (0.02, 0.05), "gun_metal")                 # nòng phải
    body.box((0.09, 0.05, 0.12), (0, 0.02, -0.02), "gun_metal_light")            # thân
    body.box((0.012, 0.012, 0.46), (0, 0.074, -0.3), "gun_metal_light")          # thanh ngắm giữa
    body.box((0.016, 0.016, 0.016), (0, 0.086, -0.52), "gold")                   # đầu ruồi
    body.box((0.05, 0.11, 0.06), (0, -0.065, 0.04), "wood", 12.0)                # báng
    body.box((0.03, 0.03, 0.05), (0, -0.01, -0.07), "gun_metal")                 # bao cò
    body.box((0.07, 0.03, 0.02), (0, 0.05, -0.3), "steel_dark")                  # đai nòng giữa
    body.box((0.07, 0.03, 0.02), (0, 0.05, -0.5), "steel_dark")                  # đai nòng đầu
    body.box((0.03, 0.02, 0.04), (0, 0.04, 0.06), "gun_metal")                   # chốt báng
    body.box((0.012, 0.03, 0.03), (0, -0.04, -0.03), "gun_metal")                # cò
    pump = Part("Pump")
    pump.box((0.05, 0.035, 0.22), (0, 0.01, -0.2), "wood")                       # ốp tay (trượt khi lên đạn)
    pump.box((0.056, 0.012, 0.03), (0, 0.01, -0.1), "steel_dark")                # vòng ốp tay
    return [body, pump]


def launcher():
    body = Part("Launcher")
    body.prism_z(0.06, -0.495, 0.055, (0, 0.07), "gun_metal_light")              # ống phóng
    body.box((0.12, 0.016, 0.1), (0, 0.134, -0.3), "steel_dark")                 # giá đỡ băng đạn
    body.box((0.016, 0.1, 0.016), (0, 0.02, -0.12), "gun_metal")                 # tay cầm trước
    body.box((0.05, 0.1, 0.05), (0, -0.04, 0.02), "gun_metal", 12.0)             # báng
    body.box((0.03, 0.04, 0.1), (0, 0.15, -0.1), "gun_metal")                    # ngắm
    body.box((0.03, 0.03, 0.05), (0, 0.0, -0.05), "gun_metal")                   # bao cò
    for z in (-0.4, -0.25, -0.1):                                                 # đai ống
        body.prism_z(0.066, z, z + 0.03, (0, 0.07), "steel_dark")
    cap = Part("Cap", (0.0, 0.07, -0.5))
    cap.prism_z(0.068, -0.53, -0.47, (0, 0.07), "red")                           # nắp miệng ống (mở khi nạp)
    return [body, cap]


def sniper():
    body = Part("Sniper")
    body.prism_z(0.015, -0.775, -0.025, (0, 0.05), "gun_metal")                  # nòng dài
    body.box((0.06, 0.06, 0.3), (0, 0.02, -0.02), "gun_metal_light")             # thân
    body.prism_z(0.028, -0.21, 0.01, (0, 0.11), "scope_dark")                    # ống ngắm
    body.box((0.03, 0.04, 0.03), (0, 0.075, -0.05), "gun_metal")                 # chân ngắm
    body.box((0.04, 0.012, 0.18), (0, 0.052, -0.1), "gun_metal_light")           # thanh ray
    body.box((0.012, 0.012, 0.1), (0, 0.0, -0.78), "steel_dark")                 # chân hãm nòng
    body.box((0.05, 0.11, 0.06), (0, -0.065, 0.06), "gun_metal", 12.0)           # báng
    body.box((0.03, 0.03, 0.05), (0, -0.015, -0.06), "gun_metal")                # bao cò
    body.prism_z(0.034, -0.215, -0.19, (0, 0.11), "gun_metal")                   # vành ống ngắm trước
    body.prism_z(0.034, -0.02, 0.01, (0, 0.11), "gun_metal")                     # vành ống ngắm sau
    bolt = Part("Bolt", (0.04, 0.035, 0.0))
    bolt.box((0.012, 0.012, 0.05), (0.04, 0.035, 0.0), "gold")                   # khoá nòng
    bolt.box((0.03, 0.012, 0.012), (0.055, 0.035, 0.02), "gold")                 # tay kéo
    return [body, bolt]


GUNS = {
    "pistol": (pistol, (0.0, 0.048, -0.36)),
    "shotgun": (shotgun, (0.0, 0.05, -0.6)),
    "launcher": (launcher, (0.0, 0.07, -0.58)),
    "sniper": (sniper, (0.0, 0.05, -0.82)),
}

result = [make_gun(k, fn, mz) for k, (fn, mz) in GUNS.items()]
if __name__ == "__main__":
    print(result)
