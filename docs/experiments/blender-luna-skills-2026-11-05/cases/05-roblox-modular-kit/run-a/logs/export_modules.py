import bpy, os
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=os.path.join(root,'asset.blend'))
for name in ['SM_Floor_4m','SM_Wall_4m','SM_Corner_4m','SM_DoorArch_4m','SM_Column_4m','SM_Torch']:
    ob=bpy.data.objects[name]; ob.location=(0,0,0); ob.rotation_euler=(0,0,0); ob.scale=(1,1,1)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(root,'modules',name+'.glb'),export_format='GLB',use_selection=True,export_apply=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    print('EXPORTED_MODULE_AT_ORIGIN',name)
