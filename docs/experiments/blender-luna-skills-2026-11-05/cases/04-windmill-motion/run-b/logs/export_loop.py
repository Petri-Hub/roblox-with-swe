import bpy, os
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
asset=bpy.data.collections['WINDMILL_ASSET']
bpy.ops.object.select_all(action='DESELECT')
for obj in asset.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in asset.objects if o.type=='EMPTY' and o.name=='Rotor assembly')
bpy.ops.export_scene.gltf(filepath=os.path.join(root,'asset.glb'), export_format='GLB', use_selection=True, export_animations=True, export_frame_range=False, export_force_sampling=True, export_materials='EXPORT', export_cameras=False, export_lights=False)
print('EXPORTED_FULL_CYCLE',root)
