"""Dựng rìu đôi (tinh anh) và dao găm (kẻ lao tới) low poly (M44): `assets/weapons/lowpoly/{axe,dagger}.glb`.

Cùng quy ước với kiếm (`make_sword.py`): mét, gốc giữa chuôi, mũi/đầu rìu hướng +Y của Blender (= -Z của Godot), màu phẳng
theo PALETTE (steel, steel_dark, gold, leather), shading phẳng. Chạy: `python3 tools/blender/make_melee.py` (bpy) hoặc trong Blender.
Thư mục ra: REDLINER_MELEE_OUT.
"""
import math
import os
import tempfile

import bpy  # phải nạp trước bmesh khi chạy ngoài Blender
import bmesh

OUT_DIR = os.environ.get("REDLINER_MELEE_OUT", tempfile.gettempdir())
PAL = {"steel": (0.75, 0.78, 0.84), "steel_dark": (0.4875, 0.507, 0.546), "gold": (0.80, 0.65, 0.25), "leather": (0.28, 0.17, 0.10)}
MAT_ORDER = list(PAL.keys())


def lin(c):
    return [(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]


def make(name, builder):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    mats = {}
    for k in MAT_ORDER:
        m = bpy.data.materials.get("sw_" + k) or bpy.data.materials.new("sw_" + k)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*lin(PAL[k]), 1.0)
        b.inputs["Metallic"].default_value = 0.0
        b.inputs["Roughness"].default_value = 0.6
        m.diffuse_color = (*lin(PAL[k]), 1.0)
        mats[k] = m
    bm = bmesh.new()

    def face(vs, mat):
        f = bm.faces.new(vs)
        f.material_index = MAT_ORDER.index(mat)
        f.smooth = False

    def hexa(pts, mat):
        """Khối lồi 8 đỉnh: 4 điểm mặt sau (z-) rồi 4 điểm mặt trước (z+)."""
        v = [bm.verts.new(p) for p in pts]
        for idx in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)]:
            face([v[i] for i in idx], mat)

    def box(x0, x1, y0, y1, z0, z1, mat):
        hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], mat)

    def prism(y0, y1, r0, r1, n, mat):
        a = [bm.verts.new((r0 * math.cos(2 * math.pi * i / n), y0, r0 * math.sin(2 * math.pi * i / n))) for i in range(n)]
        b = [bm.verts.new((r1 * math.cos(2 * math.pi * i / n), y1, r1 * math.sin(2 * math.pi * i / n))) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            face([a[i], b[i], b[j], a[j]], mat)
        face(list(reversed(a)), mat)
        face(b, mat)

    builder(box, prism, hexa, bm, face)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name + "Mesh")
    bm.to_mesh(me)
    bm.free()
    for k in MAT_ORDER:
        me.materials.append(mats[k])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(OUT_DIR, name.lower() + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
        export_materials="EXPORT", export_cameras=False, export_lights=False, export_normals=False,
        export_texcoords=False, export_extras=False, export_animations=False)
    return {"name": name, "tris": sum(len(p.vertices) - 2 for p in me.polygons), "dims": list(ob.dimensions), "out": path}


def axe(box, prism, hexa, bm, face):
    prism(-0.08, 0.80, 0.018, 0.016, 8, "leather")                     # cán
    prism(-0.10, -0.08, 0.016, 0.024, 8, "gold")                       # đầu cán
    box(-0.03, 0.03, 0.50, 0.58, -0.03, 0.03, "gold")                  # bệ lưỡi
    for s in (-1.0, 1.0):                                              # hai lưỡi: thon dần ra mép, dày 0.016
        hexa([(s * 0.03, 0.52, -0.008), (s * 0.22, 0.45, -0.006), (s * 0.22, 0.85, -0.006), (s * 0.03, 0.78, -0.008),
              (s * 0.03, 0.52, 0.008), (s * 0.22, 0.45, 0.006), (s * 0.22, 0.85, 0.006), (s * 0.03, 0.78, 0.008)], "steel")
    box(-0.012, 0.012, 0.78, 0.82, -0.012, 0.012, "steel_dark")        # mũi nhọn trên đỉnh


def dagger(box, prism, hexa, bm, face):
    prism(-0.07, 0.07, 0.016, 0.016, 8, "leather")                     # chuôi
    prism(-0.10, -0.07, 0.014, 0.02, 8, "gold")                        # đầu chuôi
    box(-0.05, 0.05, 0.07, 0.09, -0.012, 0.012, "gold")                # chắn tay
    r = [(0.0, 0.09, 0.022), (0.007, 0.09, 0.0), (0.0, 0.09, -0.022), (-0.007, 0.09, 0.0)]
    r2 = [(0.0, 0.34, 0.017), (0.005, 0.34, 0.0), (0.0, 0.34, -0.017), (-0.005, 0.34, 0.0)]
    a = [bm.verts.new(p) for p in r]
    b = [bm.verts.new(p) for p in r2]
    tip = bm.verts.new((0.0, 0.43, 0.0))
    for i in range(4):
        j = (i + 1) % 4
        face([a[i], a[j], b[j], b[i]], "steel" if i in (0, 1) else "steel_dark")
        face([b[i], b[j], tip], "steel" if i in (0, 1) else "steel_dark")
    face(list(reversed(a)), "steel_dark")


result = [make("Axe", axe), make("Dagger", dagger)]
if __name__ == "__main__":
    print(result)
