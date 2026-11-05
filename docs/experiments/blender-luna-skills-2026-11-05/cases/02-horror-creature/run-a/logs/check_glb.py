import bpy, json, os
p=os.path.abspath('asset.glb')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=p)
objs=list(bpy.context.scene.objects)
res={'objects':len(objs),'meshes':sum(o.type=='MESH' for o in objs),'armatures':sum(o.type=='ARMATURE' for o in objs),'materials':len(bpy.data.materials),'actions':[{'name':a.name,'frame_range':list(a.frame_range)} for a in bpy.data.actions], 'cameras':sum(o.type=='CAMERA' for o in objs), 'lights':sum(o.type=='LIGHT' for o in objs), 'names':[o.name for o in objs],'dimensions':{o.name:list(o.dimensions) for o in objs if o.type=='ARMATURE'}}
open('logs/glb-check.json','w').write(json.dumps(res,indent=2))
print('GLB_CHECK',json.dumps(res))
