"""Sparse point-path ray checks; not an avatar/collision or navigation certification."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
src,config,out=map(Path,sys.argv[sys.argv.index('--')+1:]);bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(src));scene=bpy.context.scene;dg=bpy.context.evaluated_depsgraph_get();results=[]
for item in json.loads(config.read_text())['segments']:
 a,b=Vector(item['from']),Vector(item['to']);delta=b-a;length=delta.length
 hit,point,normal,face,obj,matrix=scene.ray_cast(dg,a,delta.normalized(),distance=length)
 results.append({**item,'hit':hit,'object':obj.name if obj else None,'distance':(point-a).length if hit else None,'point':list(point) if hit else None})
section=[]
zplane=1.5
for ob in scene.objects:
 if ob.type!='MESH':continue
 eo=ob.evaluated_get(dg);me=eo.to_mesh();me.calc_loop_triangles();verts=[eo.matrix_world@v.co for v in me.vertices]
 for tri in me.loop_triangles:
  vs=[verts[i] for i in tri.vertices];intersections=[]
  for a,b in [(vs[0],vs[1]),(vs[1],vs[2]),(vs[2],vs[0])]:
   da,db=a.z-zplane,b.z-zplane
   if da*db<0 or abs(da)<1e-7 or abs(db)<1e-7:
    if abs(a.z-b.z)<1e-9:continue
    t=(zplane-a.z)/(b.z-a.z)
    if -1e-7<=t<=1+1e-7:
     q=a+(b-a)*t
     if not any((q-p).length<1e-6 for p in intersections):intersections.append(q)
  if len(intersections)==2:section.append({'object':ob.name,'xy':[[p.x,p.y] for p in intersections]})
 eo.to_mesh_clear()
r={'method':'straight horizontal ray segments at z=1.5 units through selected route centers; no avatar volume, collision settings, floor support or navmesh tested','source':str(src),'section_z':zplane,'mesh_cross_section':section,'segments':results}
out.write_text(json.dumps(r,indent=2));print('ROUTES',[(i['label'],i['hit'],i['object']) for i in results])
