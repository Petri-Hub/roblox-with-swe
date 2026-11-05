#!/usr/bin/env python3
"""Independent GLB counts, separating geometry definitions from scene instances."""
from pathlib import Path
import json,struct
ROOT=Path(__file__).resolve().parent
folders=[ROOT]+sorted((ROOT/'cases').glob('*'))
for folder in folders:
 if not (folder/'metrics.json').exists():continue
 metrics=json.loads((folder/'metrics.json').read_text());out={}
 for v in 'ab':
  path=folder/f'run-{v}'/('tower.glb' if folder==ROOT else 'asset.glb')
  raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);tri=[];verts=[]
  for mesh in g.get('meshes',[]):
   positions={p['attributes']['POSITION'] for p in mesh['primitives']}
   verts.append(sum(g['accessors'][i]['count'] for i in positions))
   assert all(p.get('mode',4)==4 for p in mesh['primitives']), 'Non-triangle primitive requires separate counting'
   tri.append(sum(g['accessors'][p['indices']]['count']//3 if 'indices'in p else g['accessors'][p['attributes']['POSITION']]['count']//3 for p in mesh['primitives']))
  nodes=[o for o in g.get('nodes',[]) if 'mesh'in o]
  d={'mesh_definitions':len(tri),'mesh_instances':len(nodes),'triangles_in_mesh_definitions':sum(tri),'triangles_instantiated':sum(tri[o['mesh']] for o in nodes),'position_vertices_in_mesh_definitions':sum(verts),'position_vertices_instantiated':sum(verts[o['mesh']] for o in nodes),'animation_clips':len(g.get('animations',[])),'skins':len(g.get('skins',[])),'vertex_count_definition':'Sum of unique POSITION accessors within each mesh definition, then multiplied by scene nodes using that mesh; UV/normal seams can duplicate vertices. Not welded original Blender vertex counts.'}
  assert d['triangles_instantiated']==metrics[v]['triangles'],(path,d['triangles_instantiated'],metrics[v]['triangles'])
  assert len(nodes)==metrics[v]['mesh_objects'],(path,'mesh instances mismatch')
  assert len(g.get('materials',[]))==metrics[v]['materials'],(path,'material count mismatch')
  out[v]=d;metrics[v]['geometry_export']=d
 (folder/'geometry.json').write_text(json.dumps(out,indent=2));(folder/'metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2))
 print(folder.name, 'A/B triangles',out['a']['triangles_instantiated'],out['b']['triangles_instantiated'],'vertices',out['a']['position_vertices_instantiated'],out['b']['position_vertices_instantiated'])
