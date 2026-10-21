# Prints what a glTF holds: objects, triangles, sizes, materials. Usage: blender -b -P inspect.py -- file.gltf
import bpy, sys
path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        print("OBJ", o.name, "tris", tris, "dims", tuple(round(x, 3) for x in o.dimensions), "loc", tuple(round(x, 3) for x in o.location), "mats", [m.name for m in o.data.materials])
