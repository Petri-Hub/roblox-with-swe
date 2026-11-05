import bpy, math, os, random
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(ROOT,'cache'),exist_ok=True)
os.makedirs(os.path.join(ROOT,'logs'),exist_ok=True)
random.seed(12)
# reset
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in bpy.data.collections:
    if d.name!='Collection': bpy.data.collections.remove(d)
scene=bpy.context.scene
asset=bpy.data.collections.get('Collection'); asset.name='HAUNTED COURTYARD | export asset'
# helpers

def mat(name,color,rough=0.8, emission=None):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Roughness'].default_value=rough
 if emission:
  bs.inputs['Emission Color'].default_value=(*emission[0],1); bs.inputs['Emission Strength'].default_value=emission[1]
 return m
stone=mat('Weathered blue-grey limestone',(0.22,.29,.32)); stone2=mat('Pale chipped edges',(.39,.43,.41)); dark=mat('Deep shadow stone',(.075,.105,.12)); roofmat=mat('Moss dark slate',(.09,.16,.18)); roof2=mat('Slate variation',(.13,.22,.23)); wood=mat('Old oak',(.16,.09,.045)); wood2=mat('Oak worn edges',(.32,.20,.095)); iron=mat('Oxidized iron',(.11,.16,.15)); grass=mat('Dead grass',(.31,.29,.14)); grass2=mat('Moss',(.14,.23,.13)); gold=mat('Lantern amber glass',(.95,.42,.09),.35,((1,.24,.045),3)); groundmat=mat('Diorama earth',(.11,.145,.15));
def move_asset(obj):
 for c in list(obj.users_collection): c.objects.unlink(obj)
 asset.objects.link(obj)
def cube(name,loc,scale,material,bev=0):
 bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(material); move_asset(o)
 if bev:
  mod=o.modifiers.new('Soft chipped corners','BEVEL'); mod.width=bev; mod.segments=1
  o.modifiers.new('Weighted stone normals','WEIGHTED_NORMAL')
 return o
def cyl(name,loc,r,depth,material,verts=8,rot=None):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot or (0,0,0)); o=bpy.context.object;o.name=name;o.data.materials.append(material);move_asset(o);return o
def ico(name,loc,scale,material,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material);move_asset(o);return o
def beam(name,a,b,width,material):
 mid=(Vector(a)+Vector(b))/2; d=Vector(b)-Vector(a); o=cube(name,mid,(width,width,d.length),material,width*.1);o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y');return o
# floating-island base & courtyard
cube('Ground | island base',(0,0,-.28),(14,14,.55),groundmat,.16)
# front facade at y=4.15; width 8.4 height 6.4
cube('Chapel nave',(0,4.2,2.65),(8.4,3.0,5.3),stone,.07)
# front wall overlay door surround facade y=2.64
# arched portal square sides and voussoirs; door opening width 2.15 tall 3.45, arch radius ~1.1
cube('Portal left pier',(-1.42,2.60,1.67),(.55,.5,3.35),stone2,.04)
cube('Portal right pier',(1.42,2.60,1.67),(.55,.5,3.35),stone2,.04)
# arch blocks around semicircle
for i in range(9):
 ang=math.pi*i/8
 x=1.08*math.cos(ang); z=3.35+1.08*math.sin(ang)
 ob=cube('Portal arch voussoir',(x,2.60,z),(.42,.48,.42),stone2,.025); ob.rotation_euler[1]=ang-math.pi/2
# inset dark opening + oak double door
cube('Dark doorway',(0,2.86,1.92),(2.05,.16,3.83),dark,.03)
cube('Double oak door',(0,2.72,1.73),(1.8,.17,3.35),wood,.035)
for x in [-.45,-.15,.15,.45]: cube('Door vertical plank',(x,2.61,1.75),(.055,.035,3.22),wood2,.01)
cube('Door cross brace',(-.03,2.58,.67),(1.65,.10,.12),wood2,.02)
# handle
ico('Iron door ring',(.65,2.49,1.6),(.09,.06,.09),iron,2)
# gable triangular mesh
verts=[(-4.2,2.7,5.3),(4.2,2.7,5.3),(0,2.7,8.1),(-4.2,5.7,5.3),(4.2,5.7,5.3),(0,5.7,8.1)]
faces=[(0,1,2),(3,5,4),(0,3,4,1),(0,2,5,3),(1,4,5,2)]
me=bpy.data.meshes.new('Gable mesh');me.from_pydata(verts,[],faces);me.materials.append(stone);o=bpy.data.objects.new('Chapel gable',me);asset.objects.link(o)
# roof slopes panels
for side in [-1,1]:
 a=(-4.6,3.95,5.25); b=(0,3.95,8.3); c=(0,6.0,8.3); d=(-4.6,6,5.25)
 if side==1: a,b,c,d=(0,3.95,8.3),(4.6,3.95,5.25),(4.6,6,5.25),(0,6,8.3)
 me=bpy.data.meshes.new('Slate roof plane');me.from_pydata([a,b,c,d],[],[(0,1,2,3)]);me.materials.append(roofmat);o=bpy.data.objects.new('Steep slate roof',me);asset.objects.link(o); sol=o.modifiers.new('Roof thickness','SOLIDIFY');sol.thickness=.18
# roof tile accents sit directly on both sloping front roof faces
for side in [-1,1]:
 for row in range(4):
  t=(row+.6)/4.6
  for col in range(3):
   along=(col-1)*.72
   if side<0: x=-4.15*(1-t)+along
   else: x=4.15*(1-t)+along
   z=5.38+t*2.72
   if abs(x)>4.35: continue
   y=3.78
   o=cube('Loose slate tile',(x,y,z),(1.12,.12,.46),roof2 if (row+col)%3 else dark,.025)
   o.rotation_euler[1]=(-.58 if side<0 else .58)
# buttresses
for x in [-3.65,3.65]:
 for y in [2.85,5.45]:
  cube('Chapel buttress',(x,y,2.0),(.48,.55,4.0),stone2,.06)
# narrow windows in facade
for x in [-2.7,2.7]:
 cube('Gothic window recess',(x,2.58,3.7),(.52,.12,1.55),dark,.14)
 cube('Window mullion',(x,2.48,3.7),(.075,.08,1.42),stone2,.02)
 cube('Window crossbar',(x,2.48,3.7),(.42,.08,.07),stone2,.02)
# stepping path centered from foreground to door, irregular slabs
for row in range(7):
 y=-5.35+row*1.13
 for off in [-.62,.62]:
  x=off+random.uniform(-.12,.12); w=random.uniform(.82,1.0)
  o=cube('Worn path flagstone',(x,y,.035),(w,.82,.16),stone2 if random.random()<.3 else stone,.055);o.rotation_euler[2]=random.uniform(-.12,.12)
# broken iron gate on front left/right, flanking route
for side in [-1,1]:
 x=side*5.45
 cyl('Gate stone post',(x,-4.7,.86),.32,1.7,stone2,6)
 ico('Post cap',(x,-4.7,1.8),(.39,.39,.28),stone2,1)
 # broken bars toward inner gap
 for j in range(4):
  xx=side*(4.0+j*.42)
  h=random.uniform(1.15,1.8)
  beam('Bent iron gate picket',(xx,-4.68,.15),(xx,-4.68,h),.065,iron)
  if j%2==0: beam('Spear point',(xx,-4.68,h),(xx+side*.12,-4.68,h+.28),.07,iron)
 beam('Gate lower rail',(side*3.8,-4.68,.48),(side*5.2,-4.68,.50),.10,iron)
 beam('Broken sagging rail',(side*3.9,-4.68,1.25),(side*5.05,-4.68,1.0),.10,iron)
# well left mid courtyard
cyl('Well footing',( -3.55,-.55,.18),1.02,.32,stone2,10)
# ring of masonry blocks around hollow
for i in range(10):
 a=2*math.pi*i/10
 x=-3.55+.84*math.cos(a); y=-.55+.84*math.sin(a)
 o=cube('Well rim block',(x,y,.64),(.58,.38,.72),stone if i%3 else stone2,.04);o.rotation_euler[2]=a
cyl('Dark water in well',(-3.55,-.55,.60),.55,.05,dark,12)
for x in [-4.25,-2.85]: cube('Well timber upright',(x,-.55,1.75),(.14,.16,2.35),wood,.02)
beam('Well crossbeam',(-4.28,-.55,2.8),(-2.82,-.55,2.8),.16,wood2)
cyl('Well spindle',(-3.55,-.55,2.72),.11,1.35,wood2,8,rot=(0,math.pi/2,0))
beam('Well crank',(-2.84,-.55,2.7),(-2.72,-.55,2.05),.10,iron)
# rope and bucket
beam('Well rope',(-3.55,-.55,2.66),(-3.55,-.55,.9),.035,wood2)
cyl('Old bucket',(-3.55,-.55,.88),.2,.32,wood,8)
# sparse dead weeds & stones
for i in range(26):
 x=random.uniform(-6.1,6.1);y=random.uniform(-5.8,2.2)
 if abs(x)<1.7 and y<2.6: continue
 if (x+3.55)**2+(y+.55)**2<1.45**2: continue
 for k in range(random.choice([2,3])):
  dx=random.uniform(-.16,.16);dy=random.uniform(-.16,.16);h=random.uniform(.24,.65)
  beam('Dry grass blade',(x,y,.02),(x+dx,y+dy,h),.045,grass if k%2 else grass2)
# lantern near door, bracket on right
beam('Lantern wall bracket',(1.86,2.47,3.0),(2.28,2.47,3.0),.09,iron)
beam('Lantern hanging loop',(2.28,2.47,3.0),(2.28,2.47,2.72),.055,iron)
cube('Lantern glowing core',(2.28,2.47,2.48),(.32,.28,.45),gold,.035)
for dx in [-.19,.19]:
 for dy in [-.16,.16]: beam('Lantern iron cage',(2.28+dx,2.47+dy,2.24),(2.28+dx,2.47+dy,2.72),.035,iron)
cube('Lantern cap',(2.28,2.47,2.76),(.48,.40,.09),iron,.025)
# moss clumps at base facade
for x in [-3.2,-2.6,2.9,3.5]: ico('Moss on masonry',(x,2.5,.32),(.38,.20,.16),grass2,1)
# studio collection with ground, lights, cameras
studio=bpy.data.collections.new('STUDIO | cameras lighting floor');scene.collection.children.link(studio)
def link_studio(o):
 for c in list(o.users_collection): c.objects.unlink(o)
 studio.objects.link(o)
def aim(o,target): o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,color,size,target):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size;aim(o,target);link_studio(o)
area('Moonlight key',(-7,-5,12),1700,(.43,.63,1),8,(0,1,2))
area('Cold rim',(5,5,10),2300,(.36,.53,1),7,(0,1,3))
area('Soft front fill',(1,-10,6),650,(.68,.75,1),8,(0,0,2))
bpy.ops.object.light_add(type='POINT',location=(2.28,2.0,2.5));o=bpy.context.object;o.name='Lantern practical';o.data.energy=65;o.data.color=(1,.30,.065);o.data.shadow_soft_size=1.0;link_studio(o)
# floor under island, studio
cube('Studio ground',(0,0,-.75),(200,200,.3),mat('Studio seamless',(.025,.035,.043)),.0);link_studio(bpy.context.object)
def camera(name,loc,target,lens=52):
 bpy.ops.object.camera_add(location=loc);o=bpy.context.object;o.name=name;o.data.lens=lens;aim(o,target);link_studio(o);return o
cams=[camera('Front view',(11,-22,11),(0,.3,3.0),52),camera('Back view',(-10,19,10),(0,.4,3.0),52),camera('Presentation',(12,-17,11),(0,.1,3.0),55)]
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.world.color=(.025,.035,.06);scene.view_settings.view_transform='AgX'
# transparent false, dark world
for cam,name in zip(cams,['front.png','back.png','presentation.png']):
 scene.camera=cam;scene.render.filepath=os.path.join(ROOT,name);bpy.ops.render.render(write_still=True)
# select export asset only and export GLB
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects:o.select_set(True)
bpy.context.view_layer.objects.active=next(iter(asset.objects))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'asset.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'asset.glb'),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False)
print('DONE',len(asset.objects))
