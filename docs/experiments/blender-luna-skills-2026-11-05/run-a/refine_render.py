import bpy, os
root=os.path.dirname(os.path.abspath(__file__))
scene=bpy.context.scene
floor=bpy.data.objects.get('Studio_Ground')
floor.dimensions=(2000,2000,.12)
bpy.ops.object.select_all(action='DESELECT'); floor.select_set(True); bpy.context.view_layer.objects.active=floor
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
# name mesh data for clean exports
for ob in bpy.data.objects:
 if ob.type=='MESH' and ob.data:
  ob.data.name=ob.name+'_Mesh'
# asset remains at origin; selected export only
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root,'tower.blend'))
asset=bpy.data.collections.get('ASSET_Watchtower')
bpy.ops.object.select_all(action='DESELECT')
for ob in asset.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=next(iter(asset.objects))
bpy.ops.export_scene.gltf(filepath=os.path.join(root,'tower.glb'),export_format='GLB',use_selection=True,export_apply=True)
for cam,filename in zip([bpy.data.objects.get(x) for x in ['Cam_Front','Cam_Back','Cam_Presentation']],['front.png','back.png','presentation.png']):
 scene.camera=cam; scene.render.filepath=os.path.join(root,filename); bpy.ops.render.render(write_still=True)
