import bpy, json, sys
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:]
p=Path(args[0]); bpy.ops.wm.open_mainfile(filepath=str(p))
meshes=[]
for obj in bpy.data.objects:
 if obj.type!='MESH': continue
 mesh=obj.data
 mesh.calc_loop_triangles()
 edges={}
 for face in mesh.polygons:
  for key in face.edge_keys:
   key=tuple(sorted(key)); edges[key]=edges.get(key,0)+1
 meshes.append({'name':obj.name,'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),'materials':len(mesh.materials),'uv_layers':len(mesh.uv_layers),'boundary_edges':sum(v==1 for v in edges.values()),'nonmanifold_edges':sum(v>2 for v in edges.values()),'dimensions':list(obj.dimensions)})
result={'file':str(p),'blender':bpy.app.version_string,'objects':len(bpy.data.objects),'mesh_objects':len(meshes),'triangles_base_mesh':sum(m['triangles'] for m in meshes),'vertices':sum(m['vertices'] for m in meshes),'materials':len(bpy.data.materials),'external_images':[i.filepath for i in bpy.data.images if i.source=='FILE' and not i.packed_file and i.filepath],'meshes':meshes}
Path(args[1]).write_text(json.dumps(result,indent=2))
print('INSPECTION_OK',len(meshes),result['triangles_base_mesh'])
