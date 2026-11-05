import bpy, os
from mathutils import Vector
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=os.path.join(root,'asset.blend'))
sc=bpy.context.scene; pres=bpy.data.collections['PRESENTATION']
old=bpy.data.objects.get('PRESENT_Studio_Ground'); material=old.data.materials[0]
bpy.data.objects.remove(old,do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.48)); floor=bpy.context.object; floor.name='PRESENT_Studio_Ground'; floor.data.materials.append(material)
for c in list(floor.users_collection): c.objects.unlink(floor)
pres.objects.link(floor)
sc.camera=bpy.data.objects['CAM_Front']; sc.frame_set(1); sc.cycles.samples=24; sc.cycles.device='CPU'; sc.render.threads_mode='FIXED'; sc.render.threads=4
sc.render.resolution_x=sc.render.resolution_y=768; sc.render.resolution_percentage=100; sc.render.filepath=os.path.join(root,'front.png'); bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root,'asset.blend'))
