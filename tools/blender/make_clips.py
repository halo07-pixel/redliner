"""Dựng thư viện hoạt ảnh cho thân bot low poly (M47) -> `assets/animations/lowpoly/clips.glb`.

15 Empty đặt tên đúng các khớp proxy của `mannequin.gd` (hips > spine > head | shoulder > elbow > hand | hip > knee > ankle) và KEYFRAME thật
trong Blender (rotation_quaternion + dịch hông), mỗi clip là một NLA track cùng tên -> xuất thành một animation glTF. Mở file .blend, sửa
keyframe rồi xuất lại là có clip mới. Tư thế viết theo quy ước Godot (độ, thứ tự Euler YXZ, +x ở hông/vai = đưa chi về phía trước, -x ở
cột sống = cúi tới), đổi sang trục Blender (x, -z, y) khi ghi key.

Clip lặp (tên trùng thư viện CC0 cũ để RigAnimator._pick_clip dùng luôn): Sword_Idle, Pistol_Idle, Crouch_Idle, Walk, Jog_Fwd, Sprint.
Clip một lần: Slash (chém: 0-0.60 lấy đà, 0.60-0.70 chém, 0.70-1.30 thu về), Shoot (giật súng, 0.30 s), Stagger (choáng, 0.90 s, giữ tư thế cuối).
Chạy: `REDLINER_CLIP_OUT=assets/animations/lowpoly python3 tools/blender/make_clips.py` (bpy) hoặc dán vào Blender; REDLINER_CLIP_BLEND=<đường dẫn .blend> để lưu file dựng.
"""
import math
import os
import tempfile

import bpy
from mathutils import Quaternion

OUT_DIR = os.environ.get("REDLINER_CLIP_OUT", tempfile.gettempdir())
BLEND = os.environ.get("REDLINER_CLIP_BLEND", "")
FPS = 30
JOINTS = ["hips", "spine", "head", "shoulder_l", "elbow_l", "hand_l", "shoulder_r", "elbow_r", "hand_r",
          "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r"]
SPEC = {"hips": ("", (0.0, 0.92, 0.0)), "spine": ("hips", (0, 0, 0)), "head": ("spine", (0.0, 0.62, 0.0))}
for _tag, _side in (("l", -1), ("r", 1)):
    SPEC["shoulder_" + _tag] = ("spine", (0.3 * _side, 0.52, 0.0))
    SPEC["elbow_" + _tag] = ("shoulder_" + _tag, (0.0, -0.45, 0.0))
    SPEC["hand_" + _tag] = ("elbow_" + _tag, (0.0, -0.42, 0.0))
    SPEC["hip_" + _tag] = ("hips", (0.13 * _side, -0.05, 0.0))
    SPEC["knee_" + _tag] = ("hip_" + _tag, (0.0, -0.45, 0.0))
    SPEC["ankle_" + _tag] = ("knee_" + _tag, (0.0, -0.38, 0.0))
HIPS_Y0 = 0.92


def g(v):
    return (v[0], -v[2], v[1])


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3.0 - 2.0 * x)


def ease_out(x):
    x = min(max(x, 0.0), 1.0)
    return 1.0 - (1.0 - x) ** 2


def ease_in(x):
    x = min(max(x, 0.0), 1.0)
    return x * x


def lerp(a, b, t):
    return a + (b - a) * t


def euler_q(e):
    """Euler Godot (độ, YXZ: R = Ry*Rx*Rz) -> quaternion Blender."""
    ex, ey, ez = (math.radians(a) for a in e)
    q = Quaternion((0, 1, 0), ey) @ Quaternion((1, 0, 0), ex) @ Quaternion((0, 0, 1), ez)
    return Quaternion((q.w, q.x, -q.z, q.y))


# ------------------------------------------------------------------ tư thế (độ; khớp không nêu = 0; hips_y/hips_z là mét)
def gait(u, leg, knee, lean, arm, bob, twist=8.0, stwist=10.0):
    p = 2.0 * math.pi * u
    s = math.sin(p)
    pose = {
        "hips": (0, -twist * s, 0), "spine": (-lean, stwist * s, 0), "head": (lean * 0.5, -(stwist * s - twist * s), 0),
        "hip_l": (leg * s, 0, 0), "hip_r": (-leg * s, 0, 0),
        "knee_l": (-knee * (0.5 - 0.5 * math.cos(p + 1.0)), 0, 0), "knee_r": (-knee * (0.5 - 0.5 * math.cos(p + 1.0 + math.pi)), 0, 0),
        "ankle_l": (15 * max(0, s) - 20 * max(0, -s), 0, 0), "ankle_r": (15 * max(0, -s) - 20 * max(0, s), 0, 0),
        "shoulder_l": (-arm * s, 0, -5), "shoulder_r": (arm * s, 0, 5),
        "elbow_l": (45 + 15 * math.sin(p + 0.6), 0, 0), "elbow_r": (45 + 15 * math.sin(p + 0.6 + math.pi), 0, 0),
        "hips_y": -bob * (0.5 + 0.5 * math.cos(2 * p)),
    }
    return pose


def idle(u, gun):
    p = 2.0 * math.pi * u
    pose = {
        "spine": (1.4 * math.sin(p), 0, 0), "hips": (0, 0, 2.2 * math.sin(p)),
        "hip_l": (2.5 * math.sin(p), 0, 0), "hip_r": (-2.5 * math.sin(p), 0, 0), "head": (-0.8 * math.sin(p), 0, 0),
        "shoulder_l": (0, 0, -4 + 0.8 * math.sin(p)), "shoulder_r": (0, 0, 4 - 0.8 * math.sin(p)),
        "knee_l": (-3 - 1.5 * math.sin(p), 0, 0), "knee_r": (-3 + 1.5 * math.sin(p), 0, 0),
    }
    if gun:
        pose["shoulder_r"] = (-65, 0, 6)
        pose["elbow_r"] = (80, 0, 0)
        pose["shoulder_l"] = (-55, 0, -8)
        pose["elbow_l"] = (75, 0, 0)
    else:
        pose["shoulder_r"] = (-15, 0, 6)
        pose["elbow_r"] = (60 + 3 * math.sin(p), 0, 0)
    return pose


def crouch(u):
    p = 2.0 * math.pi * u
    return {"hips_y": -0.3, "spine": (-18 + math.sin(p), 0, 0), "hip_l": (60, 0, 0), "hip_r": (60, 0, 0), "knee_l": (-105, 0, 0),
            "knee_r": (-105, 0, 0), "ankle_l": (28, 0, 0), "ankle_r": (28, 0, 0), "head": (14, 0, 0),
            "shoulder_l": (-30, 0, -6), "shoulder_r": (-30, 0, 6), "elbow_l": (70, 0, 0), "elbow_r": (70, 0, 0)}


def slash(t):
    W, A, R = 0.6, 0.1, 0.6
    if t < W:        # lấy đà: hơi chùng xuống rồi giơ kiếm, xoắn thân
        k = ease_out(t / W)
        dip = math.sin(math.pi * min(t / 0.12, 1.0)) * 0.5 * (1.0 - ease(t / 0.2))
        return {"shoulder_r": (lerp(-15, 150, k) - 10 * dip, 0, 0), "elbow_r": (lerp(60, 80, k), 0, 0),
                "spine": (lerp(0, 8, k), lerp(0, 28, k), 0), "head": (-4 * k, -10 * k, 0),
                "hips_y": -0.1 * k, "hip_l": (22 * k, 0, 0), "knee_l": (-30 * k, 0, 0), "knee_r": (-22 * k, 0, 0),
                "shoulder_l": (-10 * k, 0, -15 * k)}
    if t < W + A:    # chém
        k = ease_in((t - W) / A)
        return {"shoulder_r": (lerp(150, -20, k), 0, 0), "elbow_r": (lerp(80, 20, k), 0, 0),
                "spine": (lerp(8, -20, k), lerp(28, -38, k), 0), "head": (lerp(-4, 6, k), lerp(-10, 14, k), 0),
                "hips_y": lerp(-0.1, -0.05, k), "hips_z": -0.25 * k, "hip_l": (lerp(22, 45, k), 0, 0),
                "knee_l": (lerp(-30, -20, k), 0, 0), "knee_r": (lerp(-22, -10, k), 0, 0), "shoulder_l": (lerp(-10, 10, k), 0, lerp(-15, -30, k))}
    k = ease((t - W - A) / R)
    over = math.sin(math.pi * min((t - W - A) / R * 1.6, 1.0)) * (1.0 - k)
    return {"shoulder_r": (lerp(-20, -15, k) - 16 * over, 0, 0), "elbow_r": (lerp(20, 60, k) - 10 * over, 0, 0),
            "spine": (lerp(-20, 0, k), lerp(-38, 0, k), 0), "head": (lerp(6, 0, k), lerp(14, 0, k), 0),
            "hips_y": lerp(-0.05, 0.0, k), "hips_z": -0.25 * (1.0 - k), "hip_l": (lerp(45, 0, k), 0, 0),
            "knee_l": (lerp(-20, 0, k), 0, 0), "knee_r": (lerp(-10, 0, k), 0, 0), "shoulder_l": (lerp(10, 0, k), 0, lerp(-30, 0, k))}


def shoot(t):
    p = min(t / 0.30, 1.0)
    kick = (1.0 - p) ** 2
    return {"shoulder_r": (70 + 12 * kick, 0, 0), "elbow_r": (10 + 20 * kick, 0, 0), "spine": (7 * kick, 0, 0),
            "head": (-3 * kick, 0, 0), "shoulder_l": (60 + 8 * kick, 0, -10), "elbow_l": (30 + 10 * kick, 0, 0), "hips_z": 0.03 * kick}


def stagger(t):
    kb = math.exp(-t * 9.0)
    ease_in_ = ease(t / 0.15)
    return {"spine": (-24 * ease_in_, 0, math.sin(t * 9.0) * 5.0 * ease_in_ * math.exp(-t * 0.8)),
            "head": (-28 * ease_in_, 0, math.sin(t * 7.0) * 6.0 * ease_in_ * math.exp(-t * 0.8)),
            "shoulder_l": (8, 0, -6), "shoulder_r": (8 + 100 * kb, 0, 6), "elbow_r": (10 + 50 * kb, 0, 0),
            "hips_z": 0.1 * kb, "hips_y": -0.05 * ease_in_, "knee_l": (-16 * ease_in_, 0, 0), "knee_r": (-16 * ease_in_, 0, 0)}


# (tên, độ dài s, lặp, hàm tư thế theo t)
CLIPS = [
    ("Sword_Idle", 2.4, True, lambda t: idle(t / 2.4, False)),
    ("Pistol_Idle", 2.4, True, lambda t: idle(t / 2.4, True)),
    ("Crouch_Idle", 2.4, True, lambda t: crouch(t / 2.4)),
    ("Walk", 1.0, True, lambda t: gait(t / 1.0, 24.0, 40.0, 2.0, 20.0, 0.025)),
    ("Jog_Fwd", 0.7, True, lambda t: gait(t / 0.7, 40.0, 70.0, 8.0, 40.0, 0.04)),
    ("Sprint", 0.5, True, lambda t: gait(t / 0.5, 52.0, 95.0, 16.0, 60.0, 0.055, 10.0, 12.0)),
    ("Slash", 1.3, False, slash),
    ("Shoot", 0.30, False, shoot),
    ("Stagger", 0.90, False, stagger),
]


def build():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    scene = bpy.context.scene
    scene.render.fps = FPS
    joints = {}
    for name in JOINTS:
        parent, pos = SPEC[name]
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 0.05
        scene.collection.objects.link(e)
        if parent:
            e.parent = joints[parent]
        e.location = g(pos)
        e.rotation_mode = "QUATERNION"
        joints[name] = e
    report = []
    for name, length, loop, fn in CLIPS:
        n = int(round(length * FPS))
        for jn, e in joints.items():
            ad = e.animation_data or e.animation_data_create()
            act = bpy.data.actions.new("%s|%s" % (name, jn))
            ad.action = act
            for f in range(n + 1):
                t = (f % n if loop else f) / FPS if not (loop and f == n) else 0.0
                pose = fn(t)
                e.rotation_quaternion = euler_q(pose.get(jn, (0, 0, 0)))
                e.keyframe_insert("rotation_quaternion", frame=f)
                if jn == "hips":
                    e.location = g((0.0, HIPS_Y0 + pose.get("hips_y", 0.0), pose.get("hips_z", 0.0)))
                    e.keyframe_insert("location", frame=f)
            tr = ad.nla_tracks.new()
            tr.name = name
            tr.strips.new(name, 0, act)
            ad.action = None
        report.append({"clip": name, "frames": n + 1, "loop": loop})
    return joints, report


def main():
    joints, report = build()
    bpy.ops.object.select_all(action="DESELECT")
    for e in joints.values():
        e.select_set(True)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "clips.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_nla_strips=True, export_optimize_animation_size=False, export_optimize_animation_keep_anim_object=True, export_extras=False)
    if BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    return {"out": path, "bytes": os.path.getsize(path), "clips": report}


if __name__ == "__main__":
    print(main())
