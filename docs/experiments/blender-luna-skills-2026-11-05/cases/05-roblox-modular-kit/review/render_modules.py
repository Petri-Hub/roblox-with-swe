"""Neutral inspection renders from final module GLBs. Does not save/change any asset."""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
folder,out=map(Path,sys.argv[sys.argv.index('--')+1:]);out.mkdir(parents=True,exist_ok=True)
records=[]
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for path in sorted(folder.glob('*.glb')):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path))
 points=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
 lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)]);center=(lo+hi)/2;extent=max(hi-lo);extent=max(extent,.5)
 original_meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for o in original_meshes:o.data.calc_loop_triangles()
 original_info={'triangles':sum(len(o.data.loop_triangles) for o in original_meshes),'mesh_objects':len(original_meshes),'mesh_origins':{o.name:list(o.matrix_world.translation) for o in original_meshes},'bounds':[[lo[i],hi[i]] for i in range(3)],'materials':len(bpy.data.materials)}
 scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Inspection world');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.20,.24,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
 bpy.ops.mesh.primitive_plane_add(size=extent*12,location=(center.x,center.y,lo.z-.015));floor=bpy.context.object
 mat=bpy.data.materials.new('Inspection gray');mat.diffuse_color=(.13,.15,.18,1);mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.13,.15,.18,1);floor.data.materials.append(mat)
 for suffix,delta,power in [('key',(2,-3,4),700),('fill',(-3,-1,2),350),('rim',(1,3,3),500)]:
  bpy.ops.object.light_add(type='AREA',location=center+Vector(delta)*extent);light=bpy.context.object;light.name='Inspection '+suffix;light.data.energy=power*extent*extent;light.data.shape='DISK';light.data.size=extent*3;aim(light,center)
 bpy.ops.object.camera_add(location=center+Vector((1.2,-1.8,1.15))*extent);camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=extent*1.7;aim(camera,center);scene.camera=camera
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8;scene.cycles.use_denoising=True;scene.render.threads_mode='FIXED';scene.render.threads=2;scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';dest=out/(path.stem+'.png');scene.render.filepath=str(dest);bpy.ops.render.render(write_still=True)
 records.append({**original_info,'load_ok':True,'source':str(path),'render':str(dest),'dimensions':list(hi-lo),'method':'same relative orthographic camera, neutral world and 3 area lights; original materials; no asset saved'})
(out/'render-manifest.json').write_text(json.dumps(records,indent=2));print('INSPECTION_MODULE_RENDERS',len(records))
