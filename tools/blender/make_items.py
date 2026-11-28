"""Dựng 3 vật nhặt low poly (M46): `assets/items/lowpoly/{health,ammo,stamina}.glb`.

Mét, gốc ở tâm vật (cao ~0.5 m, nằm gọn trong hình cầu bán kính 0.4), shading phẳng. Vật liệu theo vai trò: `it_body` (thân tối) và
`it_glow` (phần sáng): màu thật của `it_glow` lấy từ `Global.PICKUPS["kinds"][kind]["color"]` lúc chạy (scripts/pickup.gd).
Ngân sách: tối đa 3000 tam giác mỗi vật (Global.LOWPOLY["budget"]["prop"]). Chạy: `python3 tools/blender/make_items.py` (bpy)
hoặc trong Blender. Thư mục ra: REDLINER_ITEM_OUT.
"""
import math
import os
import tempfile

import bpy  # phải nạp trước bmesh khi chạy ngoài Blender
import bmesh

OUT_DIR = os.environ.get("REDLINER_ITEM_OUT", tempfile.gettempdir())
ROLES = ["it_body", "it_glow"]
COLORS = {"it_body": (0.2, 0.21, 0.25), "it_glow": (1.0, 1.0, 1.0)}


def lin(c):
    return [(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]


class Item:
    def __init__(self):
        self.bm = bmesh.new()

    def _v(self, p):
        return self.bm.verts.new((p[0], -p[2], p[1]))   # Godot (x,y,z) -> Blender (x,-z,y)

    def poly(self, pts, role):
        f = self.bm.faces.new([self._v(p) for p in pts])
        f.material_index = ROLES.index(role)
        f.smooth = False

    def box(self, x0, x1, y0, y1, z0, z1, role):
        a, b, c, d = (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)
        e, f, g, h = (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)
        for q in ((a, b, c, d), (e, h, g, f), (a, e, f, b), (d, c, g, h), (a, d, h, e), (b, f, g, c)):
            self.poly(q, role)

    def prism(self, cx, cz, r, y0, y1, n, role, r_top=None):
        rt = r if r_top is None else r_top
        lo = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
        hi = [(cx + rt * math.cos(2 * math.pi * i / n), cz + rt * math.sin(2 * math.pi * i / n)) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            self.poly(((lo[i][0], y0, lo[i][1]), (lo[j][0], y0, lo[j][1]), (hi[j][0], y1, hi[j][1]), (hi[i][0], y1, hi[i][1])), role)
        self.poly([(x, y1, z) for x, z in hi], role)
        self.poly([(x, y0, z) for x, z in reversed(lo)], role)

    def cone(self, cx, cz, r, y0, y1, n, role):
        ring = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            self.poly(((ring[i][0], y0, ring[i][1]), (ring[j][0], y0, ring[j][1]), (cx, y1, cz)), role)
        self.poly([(x, y0, z) for x, z in reversed(ring)], role)

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
        return {"name": name, "tris": tris, "bytes": os.path.getsize(path)}


def build_health():
    """Hộp cứu thương: đế bát giác tối + chữ thập sáng nổi hai mặt + bốn đinh tán."""
    it = Item()
    it.prism(0, 0, 0.24, -0.1, 0.1, 8, "it_body")
    it.prism(0, 0, 0.27, -0.12, -0.1, 8, "it_body")
    for sz in (-1, 1):
        zf = 0.1 if sz > 0 else -0.1
        z0, z1 = (zf, zf + 0.06) if sz > 0 else (zf - 0.06, zf)
        it.box(-0.2, 0.2, -0.05, 0.05, z0, z1, "it_glow")
        it.box(-0.05, 0.05, -0.2, 0.2, z0, z1, "it_glow")
    for k in range(8):
        a = k * math.pi / 4
        x, z = 0.255 * math.cos(a), 0.255 * math.sin(a)
        it.box(x - 0.025, x + 0.025, 0.1, 0.14, z - 0.025, z + 0.025, "it_glow")
    return it.export("health")


def build_ammo():
    """Bó 3 viên đạn dựng đứng trên đế: thân sáng, đầu nhọn, vành tối."""
    it = Item()
    it.box(-0.26, 0.26, -0.24, -0.18, -0.2, 0.2, "it_body")
    for (x, z, h) in ((-0.12, 0.0, 0.34), (0.12, 0.0, 0.34), (0.0, 0.0, 0.42)):
        it.prism(x, z, 0.075, -0.18, -0.18 + h, 8, "it_glow")
        it.prism(x, z, 0.085, -0.18, -0.1, 8, "it_body")
        it.cone(x, z, 0.075, -0.18 + h, -0.18 + h + 0.12, 8, "it_glow")
    it.box(-0.26, 0.26, -0.1, -0.06, -0.12, 0.12, "it_body")
    return it.export("ammo")


def build_stamina():
    """Viên ngọc hai chóp bát giác sáng, kẹp vòng khung tối."""
    it = Item()
    it.cone(0, 0, 0.2, 0.0, 0.26, 8, "it_glow")
    ring = [(0.2 * math.cos(2 * math.pi * i / 8), 0.2 * math.sin(2 * math.pi * i / 8)) for i in range(8)]
    for i in range(8):                                   # chóp dưới (đỉnh hướng xuống)
        j = (i + 1) % 8
        it.poly(((ring[j][0], 0.0, ring[j][1]), (ring[i][0], 0.0, ring[i][1]), (0, -0.26, 0)), "it_glow")
    for i in range(8):                                   # khung quanh xích đạo
        a = 2 * math.pi * i / 8
        x, z = 0.27 * math.cos(a), 0.27 * math.sin(a)
        it.box(x - 0.045, x + 0.045, -0.03, 0.03, z - 0.045, z + 0.045, "it_body")
    return it.export("stamina")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for fn in (build_health, build_ammo, build_stamina):
        print(fn())
