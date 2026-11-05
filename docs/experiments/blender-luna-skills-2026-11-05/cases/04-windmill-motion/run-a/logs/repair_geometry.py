import bpy, os
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=os.path.join(root,'asset.blend'))
for n in ['SM_Window_Frame','SM_Window_Frame.001']:
    bpy.data.objects[n].location.y=-.72
for n in ['SM_Window_Glass','SM_Window_Glass.001']:
    bpy.data.objects[n].location.y=-.78
for n in ['SM_Door_Plank','SM_Door_Plank.001','SM_Door_Plank.002','SM_Door_Plank.003']:
    bpy.data.objects[n].location.y=-1.04
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root,'asset.blend'))
asset=bpy.data.collections['ASSET_Windmill_Island']
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects:o.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['ANIM_Rotor_Hub']
bpy.ops.export_scene.gltf(filepath=os.path.join(root,'asset.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=True,export_force_sampling=True,export_nla_strips=False,export_cameras=False,export_lights=False)
