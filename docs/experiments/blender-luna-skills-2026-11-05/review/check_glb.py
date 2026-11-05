import bpy,json,sys
from pathlib import Path
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args[0])
meshes=[o for o in bpy.data.objects if o.type=='MESH']
points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
dims=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
result={'glb_import_ok':True,'mesh_objects':len(meshes),'triangles':sum(len(o.data.loop_triangles) for o in meshes),'dimensions_m':dims,'materials':len(bpy.data.materials)}
# calculate explicitly after import
for o in meshes:o.data.calc_loop_triangles()
result['triangles']=sum(len(o.data.loop_triangles) for o in meshes)
Path(args[1]).write_text(json.dumps(result,indent=2));print(result)
