# ============================================================
# BLENDER -> UNREAL FBX EXPORT (GENERIC)
# ============================================================
# HOW TO USE:
#   1. Click on the target collection in the outliner
#   2. Edit export_dir and base_name below
#   3. Open this file in Blender Text Editor -> Alt+P to run
#
# WHAT IT DOES:
#   - Finds every mesh with a SOCKET_*.### child
#   - Strips .### during export so Unreal gets clean names
#   - Exports each as: <base_name>_<meshname>.fbx
#   - Everything else -> <base_name>.fbx
# ============================================================

import bpy, os, re

# === CONFIG ===
export_dir = r"C:\backyard\Blender"
base_name = "modular_sentry_gun_parts"
# === END CONFIG ===


def do_export(filepath, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = [o for o in objects if o.type == "MESH"][0]
    bpy.ops.export_scene.fbx(
        filepath=filepath, use_selection=True, global_scale=1.0,
        apply_scale_options="FBX_SCALE_NONE", axis_forward="-Y", axis_up="Z",
        apply_unit_scale=True, bake_space_transform=True,
        object_types={"MESH", "EMPTY"}, use_mesh_modifiers=True,
        mesh_smooth_type="FACE", use_tspace=True,
        embed_textures=False, path_mode="AUTO",
    )


def run_export():
    os.makedirs(export_dir, exist_ok=True)
    col = bpy.context.collection
    if col is None or col == bpy.context.scene.collection:
        print("ERROR: Select a collection in the outliner first.")
        return

    print("Exporting collection: " + col.name)

    meshes_with_sockets = {}
    meshes_without_sockets = []

    for obj in col.objects:
        if obj.type != "MESH":
            continue
        sockets = [o for o in col.objects
                    if o.type == "EMPTY" and o.name.startswith("SOCKET_") and o.parent == obj]
        if sockets:
            meshes_with_sockets[obj] = sockets
        else:
            meshes_without_sockets.append(obj)

    # Base file (no sockets)
    if meshes_without_sockets:
        orig_locs = {o.name: o.location.copy() for o in meshes_without_sockets}
        for o in meshes_without_sockets:
            o.location = (0, 0, 0)
        fp = os.path.join(export_dir, base_name + ".fbx")
        do_export(fp, meshes_without_sockets)
        for o in meshes_without_sockets:
            o.location = orig_locs[o.name]
        print("  BASE: " + base_name + ".fbx (" + str(len(meshes_without_sockets)) + " meshes)")

    # Per-mesh files (with sockets, clean names)
    for mesh, sockets in meshes_with_sockets.items():
        all_sockets = [o for o in bpy.data.objects if o.name.startswith("SOCKET_")]
        other = [s for s in all_sockets if s not in sockets]
        stashed = {s: s.name for s in other}
        for s in other:
            s.name = "__STASH_" + str(id(s))

        orig_names = {s: s.name for s in sockets}
        for s in sockets:
            s.name = re.sub(r"\.\d{3}$", "", s.name)

        orig_loc = mesh.location.copy()
        mesh.location = (0, 0, 0)

        fp = os.path.join(export_dir, base_name + "_" + mesh.name + ".fbx")
        do_export(fp, [mesh] + sockets)
        exported_names = [s.name for s in sockets]

        mesh.location = orig_loc
        for s, name in orig_names.items():
            s.name = name
        for s, name in stashed.items():
            s.name = name

        print("  MESH: " + base_name + "_" + mesh.name + ".fbx | sockets: " + str(exported_names))

    total = (1 if meshes_without_sockets else 0) + len(meshes_with_sockets)
    print("Done! " + str(total) + " files -> " + export_dir)


run_export()
