"""Dựng thanh kiếm low poly của Redliner (M42) trong Blender và xuất `assets/weapons/lowpoly/sword.glb`.

Chạy trong Blender (Scripting > Run Script) hoặc qua MCP. Tham số đổi ở đầu file. Chuẩn xem docs/ASSETS.md ("Chuẩn low poly"):
mét, gốc ở GIỮA chuôi, mũi kiếm hướng +Y của Blender (= -Z của Godot, tức là hướng "phía trước" của viewmodel),
bề rộng lưỡi theo Z, bề dày theo X, màu phẳng (không texture), shading phẳng, 4 vật liệu theo `PALETTE` (visual_data.gd).
"""
import math
import os
import tempfile

import bmesh
import bpy

OUT_PATH = os.environ.get("REDLINER_SWORD_OUT", os.path.join(tempfile.gettempdir(), "redliner_sword.glb"))

# Khớp `Global.PALETTE` (sRGB). Đổi ở đây thì đổi cả visual_data.gd.
PAL = {
    "steel": (0.75, 0.78, 0.84),
    "steel_dark": (0.4875, 0.507, 0.546),
    "gold": (0.80, 0.65, 0.25),
    "leather": (0.28, 0.17, 0.10),
}
MAT_ORDER = ["steel", "steel_dark", "gold", "leather"]


def lin(c):
    return [(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c]


for o in list(bpy.data.objects):
    if o.name in ("Sword", "Cube"):
        bpy.data.objects.remove(o, do_unlink=True)

mats = {}
for name in MAT_ORDER:
    m = bpy.data.materials.new("sw_" + name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(PAL[name]), 1.0)
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Roughness"].default_value = 0.6
    m.diffuse_color = (*lin(PAL[name]), 1.0)
    mats[name] = m

bm = bmesh.new()


def add_face(verts, mat):
    f = bm.faces.new(verts)
    f.material_index = MAT_ORDER.index(mat)
    f.smooth = False
    return f


def ring(y, hw, ht):
    # tiết diện thoi: X = bề dày, Z = bề rộng, Y = dọc lưỡi
    return [bm.verts.new(v) for v in [(0, y, hw), (ht, y, 0), (0, y, -hw), (-ht, y, 0)]]


# LƯỠI: gốc y=0.13 -> mũi y=1.06
rings = [ring(0.13, 0.030, 0.010), ring(0.80, 0.027, 0.008), ring(0.97, 0.020, 0.006)]
tip = bm.verts.new((0, 1.06, 0.0))
for a, b in zip(rings[:-1], rings[1:]):
    for i in range(4):
        j = (i + 1) % 4
        add_face([a[i], a[j], b[j], b[i]], "steel" if i in (0, 1) else "steel_dark")
for i in range(4):
    j = (i + 1) % 4
    add_face([rings[-1][i], rings[-1][j], tip], "steel" if i in (0, 1) else "steel_dark")
add_face(list(reversed(rings[0])), "steel_dark")


def box(x0, x1, y0, y1, z0, z1, mat):
    v = [bm.verts.new(p) for p in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]]
    for idx in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)]:
        add_face([v[i] for i in idx], mat)


def prism(y0, y1, r0, r1, n, mat):
    a = [bm.verts.new((r0 * math.cos(2 * math.pi * i / n), y0, r0 * math.sin(2 * math.pi * i / n))) for i in range(n)]
    b = [bm.verts.new((r1 * math.cos(2 * math.pi * i / n), y1, r1 * math.sin(2 * math.pi * i / n))) for i in range(n)]
    for i in range(n):
        j = (i + 1) % n
        add_face([a[i], b[i], b[j], a[j]], mat)
    add_face(list(reversed(a)), mat)
    add_face(b, mat)


box(-0.07, 0.07, 0.10, 0.13, -0.015, 0.015, "gold")   # chắn tay
prism(-0.10, 0.10, 0.018, 0.018, 8, "leather")        # chuôi
prism(-0.13, -0.10, 0.015, 0.024, 8, "gold")          # đầu chuôi

bm.normal_update()
me = bpy.data.meshes.new("SwordMesh")
bm.to_mesh(me)
bm.free()
for k in MAT_ORDER:
    me.materials.append(mats[k])
ob = bpy.data.objects.new("Sword", me)
bpy.context.scene.collection.objects.link(ob)

bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(
    filepath=OUT_PATH, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
    export_materials="EXPORT", export_cameras=False, export_lights=False, export_normals=False,
    export_texcoords=False, export_extras=False, export_animations=False)

result = {"tris": sum(len(p.vertices) - 2 for p in me.polygons), "out": OUT_PATH, "dims": list(ob.dimensions)}
