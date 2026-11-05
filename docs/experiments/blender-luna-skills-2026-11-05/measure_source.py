"""Run with Blender: measure original mesh polygons for the final GLB's object set."""
import bpy,json,struct,sys
from pathlib import Path
root=Path(__file__).resolve().parent
for folder in [root]+sorted((root/'cases').glob('*')):
 if not (folder/'metrics.json').exists():continue
 out={}
 for v in 'ab':
  name='tower' if folder==root else 'asset';glb=folder/f'run-{v}'/(name+'.glb');raw=glb.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);names={o['name'] for o in g['nodes'] if 'mesh'in o};bpy.ops.wm.open_mainfile(filepath=str(glb.with_suffix('.blend')))
  objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name in names];missing=sorted(names-{o.name for o in objects});assert not missing,(folder,v,missing)
  base=0;polys=0;verts=0;evaltris=0;ngons=0;quads=0;dg=bpy.context.evaluated_depsgraph_get()
  for o in objects:
   o.data.calc_loop_triangles();base+=len(o.data.loop_triangles);polys+=len(o.data.polygons);verts+=len(o.data.vertices);ngons+=sum(len(p.vertices)>4 for p in o.data.polygons);quads+=sum(len(p.vertices)==4 for p in o.data.polygons)
   eo=o.evaluated_get(dg);me=eo.to_mesh();me.calc_loop_triangles();evaltris+=len(me.loop_triangles);eo.to_mesh_clear()
  out[v]={'matched_export_objects':len(objects),'base_polygons':polys,'base_triangles':base,'base_vertices':verts,'base_quad_faces':quads,'base_ngons':ngons,'evaluated_triangles_in_blend':evaltris,'method':'Only original Blender mesh objects named by mesh nodes in the final GLB; excludes studio/catalog items not exported. Base counts before modifiers; evaluated counts after modifiers.'}
 (folder/'source-geometry.json').write_text(json.dumps(out,indent=2));print('SOURCE_GEOMETRY',folder.name,out)
