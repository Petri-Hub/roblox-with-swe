import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
src,out=map(Path,sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=24
if src.suffix=='.glb':bpy.ops.import_scene.gltf(filepath=str(src))
else:bpy.ops.wm.open_mainfile(filepath=str(src))
# glTF can stash one clip per animated object and activate only the first globally.
# Activate each object's sole exported clip, keeping NLA muted to avoid double evaluation.
activation=[]
for ob in bpy.data.objects:
 ad=ob.animation_data
 if not ad: continue
 strips=[s for t in ad.nla_tracks for s in t.strips if s.action]
 unique={s.action.name:s for s in strips}
 if len(unique)==1:
  strip=next(iter(unique.values()));ad.action=strip.action
  slot=getattr(strip,'action_slot',None)
  if slot is not None: ad.action_slot=slot
  elif len(strip.action.slots)==1: ad.action_slot=strip.action.slots[0]
  for track in ad.nla_tracks:track.mute=True
  activation.append({'object':ob.name,'action':strip.action.name,'frame_range':list(strip.action.frame_range)})

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
spans=[]
for frame in [1,12,16,24,32,36,48,49]:
 scene.frame_set(frame);vals=[];dg=bpy.context.evaluated_depsgraph_get()
 for o in meshes:
  eo=o.evaluated_get(dg);me=eo.to_mesh()
  start_index=len(vals)
  vals.extend(tuple(eo.matrix_world@v.co) for v in me.vertices)
  if frame==1:spans.append((o.name,start_index,len(vals)))
  eo.to_mesh_clear()
 samples[str(frame)]=vals
base=samples['1'];movement={}
for f,vals in samples.items():
 movement[f]=max(((Vector(v)-Vector(b)).length for v,b in zip(vals,base)),default=0) if len(vals)==len(base) else None
object_motion={}
for name,start,end in spans:
 object_motion[name]=max(((Vector(vals[i])-Vector(base[i])).length for vals in samples.values() if len(vals)==len(base) for i in range(start,end)),default=0)
scene.frame_set(original_frame)
r={'excluded_importer_custom_shapes':[o.name for o in helpers],'animation_playback_setup':'each object with a sole imported clip activated explicitly; NLA muted to avoid double evaluation','activated_single_clip_objects':activation,'source':str(src),'load_ok':True,'blender':bpy.app.version_string,'mesh_objects':len(meshes),'triangles':triangles,'materials':len(bpy.data.materials),'bounds':bounds,'dimensions':[b-a for a,b in bounds],'armatures':len(armatures),'bones':sum(len(o.data.bones) for o in armatures),'mesh_with_armature_modifier':sum(any(m.type=='ARMATURE' for m in o.modifiers) for o in meshes),'actions':len(bpy.data.actions),'fps':scene.render.fps,'frame_start':scene.frame_start,'frame_end':scene.frame_end,'max_vertex_displacement_from_frame_1':movement,'object_max_displacement_sampled':object_motion,'external_images':[i.filepath for i in bpy.data.images if i.source=='FILE' and not i.packed_file and i.filepath]}
out.write_text(json.dumps(r,indent=2));print('AUDIT_OK',src.name,'tris',triangles,'armatures',r['armatures'],'movement',movement)
