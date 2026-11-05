import bpy, math, os, random
from mathutils import Vector, Matrix
OUT=os.path.dirname(os.path.abspath(__file__))
random.seed(14)
# Clean, deterministic scene
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in bpy.data.collections:
    if d.name != 'Collection': bpy.data.collections.remove(d)
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=28; scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGB'
scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'
scene.world.color=(0.018,0.024,0.045)
scene.render.film_transparent=False
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
# organize asset and presentation components
asset=bpy.data.collections.new('ASSET_HauntedCourtyard'); scene.collection.children.link(asset)
rig=bpy.data.collections.new('PRESENTATION_Rig'); scene.collection.children.link(rig)
def move_to(obj,col):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
def mat(name,color,rough=0.85,metal=0.0, emission=None):
    m=bpy.data.materials.new('M_'+name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return m
stone=mat('Moonlit_Limestone',(0.27,0.30,0.32)); stone2=mat('Weathered_Stone',(0.16,0.19,0.20)); pale=mat('Edge_Chipped_Stone',(0.40,0.39,0.34)); roof=mat('Slate',(0.075,0.105,0.14)); wood=mat('Rotten_Oak',(0.105,0.067,0.038)); wood2=mat('Old_Wood_Highlight',(0.20,0.12,0.055)); iron=mat('Blackened_Iron',(0.045,0.055,0.06),.42,.68); moss=mat('Dead_Moss',(0.11,0.16,0.09)); grass=mat('Withered_Grass',(0.34,0.27,0.12)); water=mat('Well_Shadow',(0.012,0.025,0.04),.25); warm=mat('Lantern_Glass',(1.0,.32,.055),.3,0,2.0)
def cube(name,loc,scale,ma, bevel=0, col=asset):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if ma:o.data.materials.append(ma)
    if bevel:
        mod=o.modifiers.new('Worn_edges','BEVEL'); mod.width=bevel; mod.segments=1
        mod2=o.modifiers.new('Weighted_normals','WEIGHTED_NORMAL')
    move_to(o,col); return o
def cyl(name,loc,r,depth,ma,verts=10,col=asset):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc); o=bpy.context.object; o.name=name
    if ma:o.data.materials.append(ma)
    move_to(o,col); return o
def ico(name,loc,scale,ma,sub=1,col=asset):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc); o=bpy.context.object; o.name=name; o.scale=scale
    if ma:o.data.materials.append(ma)
    move_to(o,col); return o
def beam(name,a,b,r,ma,verts=6):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a+b)/2)
    o=bpy.context.object; o.name=name; o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y')
    if ma:o.data.materials.append(ma)
    move_to(o,asset); return o
def mesh_obj(name,verts,faces,ma):
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(verts,[],faces); me.materials.append(ma); me.update()
    o=bpy.data.objects.new(name,me); asset.objects.link(o); return o
# raised diorama foundation gives convincing grounding and clean presentation edge
cube('Diorama_Base',(0,0,0.0),(10.2,8.4,.42),stone2,.10)
# cracked earth surface patch over base, plus slabs
cube('Courtyard_Earth',(0,-.02,.225),(9.88,8.08,.06),moss,.012)
# chapel facade at rear, 4m wide, doorway 1.25x2.15
# side wall masses
for x in [-1.28,1.28]:
    cube('Chapel_Facade_Wing',(x,2.36,1.48),(1.44,.48,2.52),stone,.045)
    # irregular quoins
    for z in [.48,.94,1.4,1.86,2.32]:
        cube('Corner_Quoin',(x+(-.74 if x<0 else .74),2.08,z),(.28,.23,.34),pale,.035)
# doorway lintel and upper wall
cube('Door_Lintel',(0,2.36,2.62),(1.18,.5,.26),pale,.035)
# gable triangle broad stone face
mesh_obj('Gable_Front',[(-2,2.12,2.72),(2,2.12,2.72),(0,2.12,4.10),(-2,2.56,2.72),(2,2.56,2.72),(0,2.56,4.10)],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],stone)
# portal shadow and slightly open crooked wooden door
cube('Entry_Recess',(0,2.105,1.44),(1.18,.07,2.26),wood,.02)
cube('Door_Leaf',(-.25,2.03,1.40),(.66,.12,2.04),wood2,.025).rotation_euler[1]=math.radians(-8)
for i in range(5):
    x=-.52+i*.135
    beam('Door_Plank',(x,1.955,.40),(x+random.uniform(-.04,.04),1.955,2.38),.025,wood,4)
cube('Door_Crossbar',(-.23,1.93,1.1),(.58,.07,.12),wood,.015).rotation_euler[1]=math.radians(-8)
# door stone jambs/arch blocks make distinctive entrance
for side in [-1,1]:
    x=side*.68
    for z in [.46,.82,1.18,1.54,1.90,2.24]:
        cube('Portal_Ashlar',(x,2.02,z),(.25,.34,.31),pale if z in [.46,1.90] else stone2,.03)
# roof planes behind gable: two sloping dark slate surfaces
for side in [-1,1]:
    o=cube('Broken_Slate_Roof',(side*.94,2.58,3.28),(2.25,1.3,.16),roof,.03); o.rotation_euler[1]=side*math.radians(34)
# roof broken exposed rafters
for x in [-1.75,-1.2,-.6,.6,1.2,1.75]:
    beam('Exposed_Rafter',(x,2.02,2.85),(x*.35,2.02,4.0),.045,wood,5)
# stone path broadens foreground, slightly staggered slabs
for row in range(8):
    y=-3.55+row*.62
    width=1.12+(.22 if row<2 else 0)
    for j in range(2):
        x=(-.29 if j==0 else .29)+random.uniform(-.07,.07)
        cube('Pilgrim_Path_Slab',(x,y,.30),(width/2-.035,.52,.12),pale if (row+j)%4==0 else stone,.045).rotation_euler[2]=random.uniform(-.055,.055)
# scattered cracked paving either side
for x,y in [(-1.05,-2.7),(1.1,-2.25),(-1.25,-.9),(1.32,.1),(-.95,1.45)]:
    cube('Broken_Paving',(x,y,.28),(.64,.42,.09),stone2,.04).rotation_euler[2]=random.uniform(-.25,.25)
# low stone retaining edging to lead eye
for side in [-1,1]:
    for i in range(4):
        cube('Path_Edge_Ruin',(side*(.93+random.uniform(0,.12)),-2.9+i*.66,.42),(.35,.44,.34),stone2,.045).rotation_euler[2]=random.uniform(-.1,.1)
# well in left midground: masonry ring and dark water
cyl('Well_Bowl',(-2.75,-.15,.50),.72,.50,stone2,12)
cyl('Well_Rim',(-2.75,-.15,.79),.78,.12,pale,12)
cyl('Well_Water',(-2.75,-.15,.77),.60,.025,water,12)
# support pillars + crooked roof beam
for x in [-3.34,-2.16]: cube('Well_Post',(x,-.15,1.42),(.14,.16,1.28),wood,.025)
beam('Well_Crossbeam',(-3.47,-.15,2.08),(-2.03,-.15,2.25),.07,wood2,6)
beam('Well_Handle',(-3.12,-.16,1.12),(-2.58,-.16,1.12),.035,iron,6)
beam('Well_Rope',(-2.78,-.15,2.10),(-2.78,-.15,.85),.018,wood2,5)
# broken iron gate frames both sides of path, with one fallen rail
for side in [-1,1]:
    x=side*1.74; y=-1.55
    cube('Gate_Post',(x,y,.82),(.28,.3,1.2),stone,.05)
    # iron uprights uneven, top tips
    for k in range(3):
        xx=x+side*(.22+k*.24)
        h=1.25-random.random()*.35
        beam('Gate_Spike',(xx,y,.34),(xx,y,h),.035,iron,5)
        if k%2==0: beam('Spear_Tip',(xx,y,h),(xx,y,h+.16),.024,iron,5)
    beam('Gate_Rail',(x,y,.68),(x+side*.70,y,.71),.045,iron,6)
# fallen broken bar on ground by right post
beam('Fallen_Gate_Rail',(1.84,-1.74,.37),(2.55,-1.35,.40),.038,iron,5)
# sparse dead trees and scrub, angular low poly silhouette
for tx,ty,h in [(-4.0,1.25,2.1),(3.95,.65,2.45),(3.7,-2.7,1.65)]:
    beam('Dead_Tree_Trunk',(tx,ty,.28),(tx+random.uniform(-.2,.2),ty,h),.095,wood,5)
    for n in range(3):
        z=.8+n*.36; tipx=tx+random.uniform(-.7,.7); tipy=ty+random.uniform(-.18,.18)
        beam('Dead_Branch',(tx,ty,z),(tipx,tipy,z+random.uniform(.35,.7)),.04,wood2,4)
# tufts of dry grass, stones and moss clumps
for x,y in [(-4,-3.2),(-3.7,-2.2),(4,-1.5),(3.6,1.9),(-3.7,2.3),(2.7,-3.2),(-1.7,.8),(1.8,1.1)]:
    for k in range(4):
        a=k*math.tau/4+random.random()*.25; L=random.uniform(.18,.42)
        beam('Dead_Grass',(x,y,.29),(x+math.cos(a)*L,y+math.sin(a)*L,.29+L),.025,grass,3)
    o=ico('Mossy_Rubble',(x+random.uniform(-.12,.12),y,.35),(.18,.13,.09),moss,1); o.data.transform(Matrix.Diagonal((*o.scale,1))); o.scale=(1,1,1)
# lantern mounted near entrance, with hook + emissive glass
beam('Lantern_Bracket',(.93,2.16,2.16),(1.13,2.03,2.08),.035,iron,6)
cube('Lantern_Case',(1.13,2.03,1.91),(.25,.20,.40),iron,.025)
# lantern luminous inset
cube('Lantern_Glow',(1.13,1.93,1.93),(.13,.018,.24),warm,.003)
# Raise the complete diorama so its plinth bottom rests at z=0.
for ob in asset.objects: ob.location.z += .21
# UV unwrap the sole hand-built facade mesh for robust interchange.
gable=bpy.data.objects['Gable_Front']; bpy.ops.object.select_all(action='DESELECT'); gable.select_set(True); bpy.context.view_layer.objects.active=gable
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(island_margin=.02); bpy.ops.object.mode_set(mode='OBJECT')
# Studio ground and rig are deliberately outside ASSET collection
studio=mat('Studio_Backdrop',(0.012,.018,.03))
cube('Studio_Ground',(0,0,-.06),(200,200,.12),studio,0,col=rig)
def point_at(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,target,power,color,size):
    ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.color=color; ld.shape='DISK'; ld.size=size
    ob=bpy.data.objects.new(name,ld); rig.objects.link(ob); ob.location=loc; point_at(ob,target); return ob
# cool moonlit key and faint fill
ld=bpy.data.lights.new('Moonlight','SUN'); ld.energy=1.0; ld.color=(.49,.62,1.0); ld.angle=math.radians(9)
sun=bpy.data.objects.new('Moonlight',ld); rig.objects.link(sun); sun.rotation_euler=(math.radians(28),math.radians(-25),math.radians(-24))
area('Cool_Sky_Fill',(1,-5,7),(0,0,1),700,(.28,.39,.72),7)
# warm practical at the door
ld=bpy.data.lights.new('Door_Lantern_Light','POINT'); ld.energy=110; ld.color=(1.0,.34,.09); ld.shadow_soft_size=.48
lamp=bpy.data.objects.new('Door_Lantern_Light',ld); rig.objects.link(lamp); lamp.location=(1.08,1.82,1.95)
area('Blue_Rim',(-5,3,5),(0,0,1.5),850,(.24,.40,.82),5)
world=bpy.data.worlds.new('Night_World'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs['Color'].default_value=(.009,.014,.032,1); world.node_tree.nodes['Background'].inputs['Strength'].default_value=.18; scene.world=world
# camera helpers
cams={}
def camera(name,loc,target,lens=52):
    cd=bpy.data.cameras.new(name); ob=bpy.data.objects.new(name,cd); rig.objects.link(ob); ob.location=loc; cd.lens=lens; point_at(ob,target); cd.clip_end=300; cams[name]=ob; return ob
front=camera('Camera_Front',(0,-15.7,7.2),(0,-.05,1.48),52)
back=camera('Camera_Back',(0,14.6,7.2),(0,.05,1.38),52)
pres=camera('Camera_Presentation',(12,-15,10.5),(0,0,1.35),52)
# save and renders
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects:o.select_set(True)
bpy.context.view_layer.objects.active=asset.objects[0]
blend=os.path.join(OUT,'asset.blend'); bpy.ops.wm.save_as_mainfile(filepath=blend)
for name,cam in [('front',front),('back',back),('presentation',pres)]:
    scene.camera=cam; scene.render.filepath=os.path.join(OUT,name+'.png'); bpy.ops.render.render(write_still=True)
# Export selected asset meshes only; lighting/cameras/studio stay out.
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects:o.select_set(True)
bpy.context.view_layer.objects.active=asset.objects[0]
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'asset.glb'),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False)
print('DELIVERY',blend, len(asset.objects), 'asset meshes; export selected asset collection only')
