import bpy, os, json
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(root,'asset.glb'))
scene=bpy.context.scene
objects=list(bpy.data.objects)
meshes=[o for o in objects if o.type=='MESH']
res={'objects':len(objects),'meshes':len(meshes),'cameras':sum(o.type=='CAMERA' for o in objects),'lights':sum(o.type=='LIGHT' for o in objects),'materials':len(bpy.data.materials),'actions':[a.name for a in bpy.data.actions],'tris':sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),'dimensions':list(max((o.bound_box[i][k] for o in meshes for i in range(8)),default=0) for k in range(0))}
# report aggregate bounds and simple exported animation evidence
from mathutils import Vector
coords=[o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
res['bounds']={axis:[min(v[i] for v in coords),max(v[i] for v in coords)] for i,axis in enumerate('xyz')}
print('GLB_INSPECT',json.dumps(res,sort_keys=True))
