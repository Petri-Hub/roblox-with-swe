"""Surface-intersection samples, not continuous collision/physics certification."""
import bpy,json,sys
from pathlib import Path
from mathutils.bvhtree import BVHTree
src,selection,out=map(Path,sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=24;bpy.ops.import_scene.gltf(filepath=str(src))
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

sel=json.loads(selection.read_text())
for name in sel['moving']+sel['obstacles']:assert name in bpy.data.objects,name
hits=[]
def tree(o,dg):
 eo=o.evaluated_get(dg);m=eo.to_mesh();verts=[tuple(eo.matrix_world@v.co) for v in m.vertices];faces=[tuple(p.vertices) for p in m.polygons];t=BVHTree.FromPolygons(verts,faces,all_triangles=False,epsilon=0.0);eo.to_mesh_clear();return t
for frame in range(1,49):
 bpy.context.scene.frame_set(frame);dg=bpy.context.evaluated_depsgraph_get();cache={name:tree(bpy.data.objects[name],dg) for name in sel['moving']+sel['obstacles']}
 for a in sel['moving']:
  for b in sel['obstacles']:
   overlap=cache[a].overlap(cache[b])
   if overlap:hits.append({'frame':frame,'moving':a,'obstacle':b,'triangle_surface_pairs':len(overlap)})
r={'activated_single_clip_objects':activation,'method':'world-space evaluated mesh BVH surface overlap, frames 1..48, epsilon 0; touching/coplanarity can be flagged; containment and motion between frames not certified','selection':sel,'frames_sampled':48,'overlaps':hits,'overlap_records':len(hits)}
out.write_text(json.dumps(r,indent=2));print('BVH_SWEEP',len(hits),'records')
