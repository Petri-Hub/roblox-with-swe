import json, pathlib, struct
root=pathlib.Path(__file__).resolve().parent.parent
def glb(path):
    b=path.read_bytes(); magic,ver,size=struct.unpack_from('<4sII',b,0); assert magic==b'glTF' and ver==2 and size==len(b)
    n,kind=struct.unpack_from('<II',b,12); assert kind==0x4E4F534A
    d=json.loads(b[20:20+n].decode('utf8').rstrip('\0 ')); nodes=d.get('nodes',[])
    return {'file':str(path.relative_to(root)),'bytes':len(b),'nodes':len(nodes),'mesh_nodes':sum('mesh' in x for x in nodes),'materials':len(d.get('materials',[])),'images':len(d.get('images',[])),'camera_nodes':sum('camera' in x for x in nodes),'light_nodes':sum('KHR_lights_punctual' in x.get('extensions',{}) for x in nodes),'nonzero_node_transforms':[x['name'] for x in nodes if x.get('translation') or x.get('rotation') or x.get('scale')]}
files=[root/'asset.glb',*sorted((root/'modules').glob('*.glb'))]
models=[glb(p) for p in files]
assert len(models)==7 and models[0]['nodes']==13 and models[0]['images']==0 and models[0]['camera_nodes']==0 and models[0]['light_nodes']==0
assert all(m['nodes']==1 and not m['nonzero_node_transforms'] and m['images']==0 for m in models[1:])
pngs={n:struct.unpack('>II', (root/n).read_bytes()[16:24]) for n in ('front.png','back.png','presentation.png')}
assert all(x==(768,768) for x in pngs.values())
assert (root/'asset.blend').stat().st_size>0
summary=json.loads((root/'logs/geometry-summary.json').read_text())
triangles=sum(x['tris'] for x in summary if x['name'].startswith('Demo_'))
result={'ok':True,'asset_blend_bytes':(root/'asset.blend').stat().st_size,'glbs':models,'pngs':pngs,'demo_triangles':triangles,'demo_mesh_objects':sum(x['name'].startswith('Demo_') for x in summary)}
print(json.dumps(result,indent=2))
