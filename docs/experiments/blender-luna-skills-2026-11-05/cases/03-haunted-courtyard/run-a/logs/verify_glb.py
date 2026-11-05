import bpy; bpy.ops.wm.read_factory_settings(use_empty=True)
import bpy, os, json
p=os.path.abspath('asset.glb')
r=bpy.ops.import_scene.gltf(filepath=p)
objs=list(bpy.context.scene.objects)
meshes=[o for o in objs if o.type=='MESH']
print('GLB_VERIFY',json.dumps({'operator':str(r),'objects':len(objs),'meshes':len(meshes),'non_mesh':[o.type for o in objs if o.type!='MESH'],'materials':len(bpy.data.materials),'images':len(bpy.data.images),'actions':len(bpy.data.actions),'file_bytes':os.path.getsize(p)}))
