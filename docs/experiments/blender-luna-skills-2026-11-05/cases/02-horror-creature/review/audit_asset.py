import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
src,out=map(Path,sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=24
if src.suffix=='.glb':bpy.ops.import_scene.gltf(filepath=str(src))
else:bpy.ops.wm.open_mainfile(filepath=str(src))
scene=bpy.context.scene
helpers={b.custom_shape for o in scene.objects if o.type=='ARMATURE' for b in o.pose.bones if b.custom_shape}
meshes=[o for o in scene.objects if o.type=='MESH' and o not in helpers]
armatures=[o for o in scene.objects if o.type=='ARMATURE']
points=[];triangles=0
for o in meshes:
 dg=bpy.context.evaluated_depsgraph_get();eo=o.evaluated_get(dg);me=eo.to_mesh();me.calc_loop_triangles();triangles+=len(me.loop_triangles)
 points.extend(o.matrix_world@v.co for v in me.vertices)
 eo.to_mesh_clear()
bounds=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)] if points else []
original_frame=scene.frame_current
samples={}
for frame in [1,12,16,24,32,36,48]:
 scene.frame_set(frame);vals=[];dg=bpy.context.evaluated_depsgraph_get()
 for o in meshes:
  eo=o.evaluated_get(dg);me=eo.to_mesh()
  vals.extend(tuple(eo.matrix_world@v.co) for v in me.vertices)
  eo.to_mesh_clear()
 samples[str(frame)]=vals
base=samples['1'];movement={}
for f,vals in samples.items():
 movement[f]=max(((Vector(v)-Vector(b)).length for v,b in zip(vals,base)),default=0) if len(vals)==len(base) else None
scene.frame_set(original_frame)
r={'excluded_importer_custom_shapes':[o.name for o in helpers],'source':str(src),'load_ok':True,'blender':bpy.app.version_string,'mesh_objects':len(meshes),'triangles':triangles,'materials':len(bpy.data.materials),'bounds':bounds,'dimensions':[b-a for a,b in bounds],'armatures':len(armatures),'bones':sum(len(o.data.bones) for o in armatures),'mesh_with_armature_modifier':sum(any(m.type=='ARMATURE' for m in o.modifiers) for o in meshes),'actions':len(bpy.data.actions),'fps':scene.render.fps,'frame_start':scene.frame_start,'frame_end':scene.frame_end,'max_vertex_displacement_from_frame_1':movement,'external_images':[i.filepath for i in bpy.data.images if i.source=='FILE' and not i.packed_file and i.filepath]}
out.write_text(json.dumps(r,indent=2));print('AUDIT_OK',src.name,'tris',triangles,'armatures',r['armatures'],'movement',movement)
