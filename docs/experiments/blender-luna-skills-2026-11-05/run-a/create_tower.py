import bpy, math, os
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
# reset scene
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in bpy.data.collections:
    if d.name != 'Collection': bpy.data.collections.remove(d)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
asset=bpy.data.collections.new('ASSET_Watchtower'); scene.collection.children.link(asset)
pres=bpy.data.collections.new('PRESENTATION'); scene.collection.children.link(pres)
def move_to(o,col=asset):
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o); return o
def mat(name,color,metal=0,rough=.65):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.metallic=metal; m.roughness=rough
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    return m
wood=mat('M_Oak_Warm',(0.29,.105,.035)); wood_light=mat('M_Oak_Sunlit',(.43,.21,.075)); darkwood=mat('M_Oak_Shadow',(.17,.055,.022)); roofmat=mat('M_Slate_Teal',(.035,.19,.22),0,.82); roofedge=mat('M_Slate_Edge',(.06,.28,.30),0,.7); iron=mat('M_Iron_Black',(.055,.07,.075),1,.38); gold=mat('M_Brass',(.58,.31,.075),1,.3); stone=mat('M_Stone',(.27,.29,.28),0,.9)
NAME_COUNTS={}
def unique_name(name):
    n=NAME_COUNTS.get(name,0)+1; NAME_COUNTS[name]=n
    return name if n==1 else f'{name}_{n:02d}'
def cube(name,loc,scale,material,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=move_to(bpy.context.object); o.name=unique_name(name); o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if material:o.data.materials.append(material)
    if bevel:
        mod=o.modifiers.new('Edge_softening','BEVEL'); mod.width=bevel; mod.segments=1
        mod2=o.modifiers.new('Weighted_normals','WEIGHTED_NORMAL')
    return o
def beam(name,a,b,width,depth,material):
    a,b=Vector(a),Vector(b); v=b-a
    o=cube(name,(a+b)/2,(width,depth,v.length),material,.025)
    o.rotation_mode='QUATERNION'; o.rotation_quaternion=v.to_track_quat('Z','Y'); return o
# footings, splayed legs + cross bracing
for x in [-1.25,1.25]:
 for y in [-1.15,1.15]:
    cube('Stone_Foot',(x,y,.18),(.68,.68,.36),stone,.08)
    beam('Main_Pylon',(x*1.18,y*1.18,.35),(x*.78,y*.78,5.15),.29,.29,wood)
# lower and upper cross beams
for z,half in [(1.35,1.12),(3.05,.96),(4.85,.82)]:
 for y in [-half,half]: cube('Crossbeam_FrontBack',(0,y,z),(2*half,.24,.24),wood_light,.035)
 for x in [-half,half]: cube('Crossbeam_Side',(x,0,z),(.24,2*half,.24),wood,.035)
# diagonal braces on all sides
for y in [-1.1,1.1]:
 for side in [-1,1]:
  beam('Knee_Brace',(side*.78,y,2.0),(side*.25,y,3.0),.16,.16,wood_light)
for x in [-1.1,1.1]:
 for side in [-1,1]:
  beam('Knee_Brace',(x,side*.78,2.0),(x,side*.25,3.0),.16,.16,wood_light)
# platform deck 4.9 height, planks
for i in range(8): cube('Platform_Plank',(-.84+i*.24,0,5.04),(.22,1.78,.18),wood_light,.018)
# trim band
for y in [-.92,.92]: cube('Platform_Rim',(0,y,5.17),(2.05,.14,.18),darkwood,.02)
for x in [-.99,.99]: cube('Platform_Rim',(x,0,5.17),(.14,1.9,.18),darkwood,.02)
# guardrail posts and rails, openings at front for ladder
for x in [-.92,-.55,.55,.92]:
 for y in [-.84,.84]: cube('Rail_Post',(x,y,5.85),(.13,.13,1.25),wood,.025)
for y in [-.84,.84]:
 for z in [5.48,6.15]: cube('Guard_Rail',(0,y,z),(1.95,.12,.13),wood_light,.025)
for x in [-.92,.92]:
 for z in [5.48,6.15]: cube('Guard_Rail',(x,0,z),(.12,1.7,.13),wood_light,.025)
# decorative iron post caps
for x in [-.92,-.55,.55,.92]:
 for y in [-.84,.84]: cube('Post_Cap',(x,y,6.5),(.16,.16,.08),iron,.025)
# ladder on front y=-1.12, rising to deck
for x in [-.43,.43]: beam('Ladder_Rail',(x,-1.27,.2),(x,-1.27,5.12),.11,.12,wood)
for i in range(16):
 z=.45+i*.29; cube('Ladder_Rung',(0,-1.27,z),(.95,.12,.09),wood_light,.02)
# roof structure gabled, apex y-axis cross section. posts + ridge
for y in [-1.22,1.22]:
 beam('Roof_Rafter_L',(-1.42,y,6.85),(0,y,8.15),.17,.18,darkwood)
 beam('Roof_Rafter_R',(0,y,8.15),(1.42,y,6.85),.17,.18,darkwood)
beam('Ridge_Beam',(0,-1.35,8.17),(0,1.35,8.17),.17,.17,wood_light)
# roof panels as rotated cubes along slope, broad covering overhang
for y in [i*.32-.96 for i in range(7)]:
 for side in [-1,1]:
  a=(0,y,8.14); b=(side*1.62,y,6.66)
  beam('Roof_Shingle_Panel',a,b,.30,.11,roofmat)
# facia edges and trim
for side in [-1,1]:
 beam('Roof_Fascia',(side*1.62,-1.13,6.67),(side*1.62,1.13,6.67),.14,.18,roofedge)
# metal straps at joints, bolt studs
for x in [-1.14,1.14]:
 for y in [-1.12,1.12]:
  cube('Iron_Strap',(x,y,1.35),(.34,.035,.16),iron,.015)
  cube('Iron_Rivet',(x,y-.022,1.35),(.07,.025,.07),gold,.005)
# pennant on ridge top end
beam('Finial_Pole',(0,1.18,8.1),(0,1.18,8.8),.055,.055,iron)
# triangular pennant mesh
mesh=bpy.data.meshes.new('PennantMesh'); mesh.from_pydata([(0,1.18,8.77),(0,1.18,8.42),(.48,1.18,8.65)],[],[(0,1,2)]); mesh.materials.append(gold)
uv=mesh.uv_layers.new(name='UVMap')
for loop,uvco in zip(mesh.loops,[(0.0,0.0),(1.0,0.0),(0.5,1.0)]): uv.data[loop.index].uv=uvco
ob=bpy.data.objects.new('Brass_Pennant',mesh); asset.objects.link(ob)
# presentation ground, cameras, lighting
floor=cube('Studio_Ground',(0,0,-.08),(2000,2000,.12),mat('M_Backdrop',(.055,.075,.085),0,.9),0); move_to(floor,pres)
backdrop_bsdf=next(n for n in floor.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
backdrop_bsdf.inputs['Emission Color'].default_value=(.055,.075,.085,1)
backdrop_bsdf.inputs['Emission Strength'].default_value=.08
def aim(o,pt): o.rotation_euler=(Vector(pt)-o.location).to_track_quat('-Z','Y').to_euler()
def camera(name,loc,target,lens=55):
 d=bpy.data.cameras.new(name); o=bpy.data.objects.new(name,d); pres.objects.link(o); o.location=loc; aim(o,target); d.lens=lens; return o
cams=[]
cams.append(camera('Cam_Front',(10,-24,8),(0,0,4.3),58))
cams.append(camera('Cam_Back',(-10,24,8),(0,0,4.3),58))
cams.append(camera('Cam_Presentation',(13,-17,12),(0,0,4.1),52))
for name,loc,power,size,color in [('Key',(-8,-10,14),1800,7,(1,.78,.55)),('Fill',(9,-3,9),1100,8,(.58,.75,1)),('Rim',(2,8,12),2200,6,(1,.48,.2))]:
 d=bpy.data.lights.new(name,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color; o=bpy.data.objects.new(name,d); pres.objects.link(o); o.location=loc; aim(o,(0,0,4))
world=bpy.data.worlds.new('World_Studio') if not bpy.data.worlds else bpy.data.worlds[0]; scene.world=world; world.use_nodes=True; world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.12,.16,.2,1); world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.35
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=16; scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'
# hide ground for export, asset collection clean
scene.camera=cams[2]
# stable mesh datablock names for clean glTF exports
for ob in bpy.data.objects:
    if ob.type=='MESH' and ob.data: ob.data.name=ob.name+'_Mesh'
# select asset meshes; save blend
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'tower.blend'))
# export only tower geometry (no backdrop/cameras/lights)
for o in bpy.context.selected_objects:o.select_set(False)
for o in asset.objects:o.select_set(True)
bpy.context.view_layer.objects.active=next(iter(asset.objects))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'tower.glb'),export_format='GLB',use_selection=True,export_apply=True)
# render views
for cam,filename in zip(cams,['front.png','back.png','presentation.png']):
 scene.camera=cam; scene.render.filepath=os.path.join(ROOT,filename); bpy.ops.render.render(write_still=True)
print('DELIVERY',len(asset.objects),sum(len(o.data.polygons) for o in asset.objects if o.type=='MESH'),tuple(round(v,3) for v in (min(o.bound_box[i][2] + o.location.z for o in asset.objects if o.type=='MESH' for i in range(8)),max(o.bound_box[i][2] + o.location.z for o in asset.objects if o.type=='MESH' for i in range(8)))))
