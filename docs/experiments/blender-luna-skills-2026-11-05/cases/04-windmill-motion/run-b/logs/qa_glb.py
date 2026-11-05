import bpy, os, json
for obj in list(bpy.context.scene.objects): bpy.data.objects.remove(obj, do_unlink=True)
path=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','asset.glb'))
bpy.ops.import_scene.gltf(filepath=path)
objs=list(bpy.context.scene.objects)
meshes=[o for o in objs if o.type=='MESH']
cam=[o for o in objs if o.type=='CAMERA']; lights=[o for o in objs if o.type=='LIGHT']
animated=[]
for o in objs:
    if o.animation_data and (o.animation_data.action or len(o.animation_data.nla_tracks)):
        animated.append({'name':o.name,'action':o.animation_data.action.name if o.animation_data.action else None,'tracks':len(o.animation_data.nla_tracks)})
with open(path,'rb') as f: raw=f.read()
import struct
n=struct.unpack_from('<I',raw,12)[0]; gltf=json.loads(raw[20:20+n])
lengths=[]
for animation in gltf.get('animations',[]):
    sampler=animation['samplers'][0]; accessor=gltf['accessors'][sampler['input']]
    lengths.append((animation['name'],accessor['max'][0]-accessor['min'][0]))
print('QA_GLB',json.dumps({'objects':len(objs),'meshes':len(meshes),'cameras':len(cam),'lights':len(lights),'animated_objects':animated,'animation_durations_seconds':lengths},sort_keys=True))
assert meshes and not cam and not lights
assert len(animated)>=4
assert len(lengths)==4 and all(abs(duration-2.0)<1e-5 for _,duration in lengths)
