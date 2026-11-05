import bpy, math, os, random
from mathutils import Vector

OUT=os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT,exist_ok=True)
random.seed(12)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.materials,):
    pass
# materials
def mat(name,color,metal=0,rough=.7):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    return m
wood=mat('Weathered honey oak',(.27,.125,.045)); woodlight=mat('Cut oak edges',(.43,.24,.095)); wooddark=mat('Deep aged timber',(.16,.072,.028)); roofmat=mat('Slate blue cedar shingles',(.095,.18,.22)); roofalt=mat('Shingle variation',(.13,.24,.27)); iron=mat('Forged iron',(.07,.09,.095),.72,.38); stone=mat('Warm limestone',(.36,.32,.25)); groundmat=mat('Ground',(.11,.15,.13))

def cube(name,loc,scale,material,bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft hewn edges','BEVEL'); mod.width=bevel; mod.segments=1
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    o.data.materials.append(material); return o

def beam(name,a,b,width,depth,material,bevel=.025):
    mid=(Vector(a)+Vector(b))/2; vec=Vector(b)-Vector(a)
    o=cube(name,mid,(width,depth,vec.length),material,bevel)
    o.rotation_mode='QUATERNION'; o.rotation_quaternion=vec.to_track_quat('Z','Y'); return o

def cyl(name,loc,radius,depth,material,verts=8,rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rotation or (0,0,0)); o=bpy.context.object; o.name=name; o.data.materials.append(material)
    bevel=o.modifiers.new('Edge glint','BEVEL'); bevel.width=.018; bevel.segments=1; o.modifiers.new('Normals','WEIGHTED_NORMAL'); return o

# Four splayed oak legs, substantial and braced. Tower platform z=5.6
for sx in (-1,1):
 for sy in (-1,1):
    bottom=(sx*1.65,sy*1.35,.18); top=(sx*1.05,sy*.95,5.55)
    beam('Tapered corner post',bottom,top,.27,.27,woodlight)
    # iron shoe
    beam('Iron foot binding',(sx*1.64,sy*1.34,.24),(sx*1.62,sy*1.32,.68),.31,.31,iron,.018)
    # iron collar below platform
    beam('Iron upper collar',(sx*1.1,sy*.98,5.1),(sx*1.08,sy*.96,5.43),.3,.3,iron,.015)
# X braces on all faces in segments
for sy in (-1,1):
    y=sy*1.14
    for z0,z1,w0,w1 in ((.42,2.8,1.58,1.32),(2.8,5.18,1.32,1.06)):
        beam('Front and back rising brace',(-w0,y,z0),(w1,y,z1),.14,.14,wood)
        beam('Front and back falling brace',(w0,y,z0),(-w1,y,z1),.14,.14,wood)
for sx in (-1,1):
    x=sx*1.40
    for z0,z1,y0,y1 in ((.42,2.8,1.25,1.08),(2.8,5.18,1.08,.91)):
        beam('Side rising brace',(x,-y0,z0),(x,y1,z1),.14,.14,wood)
        beam('Side falling brace',(x,y0,z0),(x,-y1,z1),.14,.14,wood)
# platform girders / deck
for y in (-1,1): cube('Heavy platform crossbeam',(0,y*.93,5.48),(2.45,.22,.28),wooddark)
for x in (-1,1): cube('Heavy platform side beam',(x*1.02,0,5.48),(.22,2.05,.28),wooddark)
for i in range(9):
 x=-.92+i*.23
 cube('Platform oak planking',(x,0,5.66),(.215,1.88,.16),woodlight if i%3==0 else wood,.02)
# banding iron around platform rim
for y in (-1,1): cube('Iron rim strap',(0,y*.98,5.57),(2.22,.055,.1),iron,.01)
for x in (-1,1): cube('Iron rim strap',(x*1.08,0,5.57),(.055,1.9,.1),iron,.01)
# guardrail posts and rails, leave front gap for stair access (front = -Y)
for x in (-.98,0,.98):
 for y in (-.84,.84):
    if y<0 and x==0: continue
    cube('Baluster',(x,y,6.18),(.12,.12,1.02),woodlight,.018)
for x in (-.98,.98):
 cube('Side handrail',(x,0,6.67),(.17,1.88,.17),woodlight)
 cube('Midrail',(x,0,6.12),(.09,1.84,.09),wood)
for y in (.84,):
 cube('Rear handrail',(0,y,6.67),(2.02,.17,.17),woodlight)
 cube('Rear midrail',(0,y,6.12),(1.95,.09,.09),wood)
# Front split rails terminate at stair opening; tapered decorative caps
for x in (-.69,.69):
 cube('Front handrail segment',(x,-.84,6.67),(.62,.17,.17),woodlight)
 cube('Front midrail segment',(x,-.84,6.12),(.60,.09,.09),wood)
# stair flight up the front (toward negative y), width 1.15, from ground to 5.7
N=12
for i in range(N):
 z=.30+i*.445; y=-2.35+i*.12
 cube('Oak stair tread',(0,y,z),(1.15,.32,.14),woodlight,.025)
 # iron tread end nail heads
 for x in (-.48,.48): cyl('Tread iron nail',(x,y-.08,z+.075),.035,.018,iron,8)
# twin stringers
beam('Left stair stringer',(-.61,-2.58,.05),(-.61,-.98,5.52),.16,.20,wooddark)
beam('Right stair stringer',(.61,-2.58,.05),(.61,-.98,5.52),.16,.20,wooddark)
# stair side handrails on slender posts along both sides
for x in (-.72,.72):
 for i in range(0,12,2):
    z=.64+i*.445; y=-2.38+i*.12
    beam('Stair railing post',(x,y,z),(x,y,z+.55),.09,.09,woodlight)
 beam('Stair sloped handrail',(x,-2.4,1.25),(x,-1.05,6.12),.11,.11,woodlight)
# roof supports and carved fascia
for sx in (-1,1):
 for sy in (-1,1):
    beam('Roof kingpost',(sx*.9,sy*.82,6.65),(sx*1.05,sy*.82,7.28),.14,.14,wooddark)
# roof: square pavilion hipped roof built from four thick quadrilateral panels with dark underside
# build roof as mesh panels triangular facets from eaves square to apex-like ridge? hip roof uses top square ridge
# rectangular raised ridge for distinctive silhouette, ends hip to ridge endpoints
zE=7.28; zR=8.55; half=1.62; ridgehalf=.55
# roof plane quads for sides, split into triangles, thickness via solidify
verts=[(-half,-half,zE),(half,-half,zE),(ridgehalf,-ridgehalf,zR),(-ridgehalf,-ridgehalf,zR),
       (half,half,zE),(-half,half,zE),(ridgehalf,ridgehalf,zR),(-ridgehalf,ridgehalf,zR)]
faces=[(0,1,2,3),(1,4,6,2),(4,5,7,6),(5,0,3,7)]
mesh=bpy.data.meshes.new('Four pitched roof planes'); mesh.from_pydata(verts,[],faces); mesh.materials.append(roofmat); mesh.materials.append(roofalt)
roof=bpy.data.objects.new('Steep four-sided shingle roof',mesh); bpy.context.collection.objects.link(roof)
sol=roof.modifiers.new('Roof board thickness','SOLIDIFY'); sol.thickness=.12
bev=roof.modifiers.new('Roof softened edges','BEVEL'); bev.width=.025; bev.segments=1
# broad fascia rails along eaves
for sy in (-1,1): cube('Roof eave fascia',(0,sy*half,zE-.045),(3.35,.18,.25),wooddark)
for sx in (-1,1): cube('Roof eave fascia',(sx*half,0,zE-.045),(.18,3.35,.25),wooddark)
# visible decorative shingle courses as slim strips across each slope, varying along depth on front/back + sides
for side in (-1,1):
 for row in range(1,5):
    t=row/5; y=side*(half*(1-t)+ridgehalf*t); z=zE+(zR-zE)*t+.045
    width=2*(half*(1-t)+ridgehalf*t)
    cube('Shingle course front/back',(0,y,z),(width,.10,.07),roofalt if row%2==0 else roofmat,.012)
 for row in range(1,5):
    t=row/5; x=side*(half*(1-t)+ridgehalf*t); z=zE+(zR-zE)*t+.045
    width=2*(half*(1-t)+ridgehalf*t)
    cube('Shingle course side',(x,0,z),(.10,width,.07),roofalt if row%2 else roofmat,.012)
# ridge cap
cube('Oak ridge cap',(0,0,zR+.04),(1.35,.18,.18),woodlight)
# decorative iron finials
for x in (-.56,.56):
 cyl('Ridge iron spike',(x,0,zR+.20),.045,.35,iron,6)
# front ornamental carved sign board
cube('Watch emblem plaque',(0,-.966,5.98),(.48,.045,.34),wooddark,.035)
# iron diagonal detail on plaque
beam('Plaque diagonal',( -.13,-.997,5.88),(.13,-.997,6.08),.045,.035,iron,.005)
# ground and stones
cube('Display ground',(0,0,-.18),(200,200,.2),groundmat,0)
for x,y in [(-1.7,-1.4),(1.7,-1.4),(-1.7,1.4),(1.7,1.4)]:
 cube('Post footing stone',(x,y,.02),(.52,.48,.22),stone,.05)
# small scattered stones as environment
for i in range(12):
 x=random.uniform(-3.5,3.5); y=random.uniform(-3.5,3.5)
 if abs(x)<2 and -3<y<2: continue
 o=cube('Small ground stone',(x,y,-.055),(.22,.16,.09),stone,.03); o.rotation_euler[2]=random.random()*3
# lighting/world
world=bpy.context.scene.world; world.color=(.08,.08,.08)
world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.25,.30,1); world.node_tree.nodes['Background'].inputs[1].default_value=.45
# render config
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True; scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
# ground plane large cube means horizonless

def aim(obj,pt): obj.rotation_euler=(Vector(pt)-obj.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,size,color,pt=(0,0,4)):
 bpy.ops.object.light_add(type='AREA',location=loc); o=bpy.context.object; o.name=name; o.data.energy=power; o.data.shape='DISK'; o.data.size=size; o.data.color=color; aim(o,pt)
area('Large warm key',(-8,-10,14),1800,8,(1,.78,.57))
area('Cool fill',(7,-3,9),1100,7,(.58,.75,1))
area('Back rim',(3,8,12),2200,6,(1,.64,.38))
# save file camera setup

def camera(name,loc,target,ortho):
 bpy.ops.object.camera_add(location=loc); c=bpy.context.object; c.name=name; c.data.type='ORTHO'; c.data.ortho_scale=ortho; aim(c,target); return c
scene.camera=camera('Presentation Camera',(10,-14,11),(0,-.05,4.2),12.5)
# set transparent? output simple studio
# render views
for name,loc,target,scale in [
 ('tower-perspective.png',(10,-14,11),(0,-.05,4.2),12.5),
 ('tower-front.png',(0,-18,7.2),(0,-.10,4.2),12.3),
 ('tower-back.png',(0,18,7.2),(0,.0,4.2),12.3)]:
    scene.camera=camera('Camera '+name,loc,target,scale)
    scene.render.filepath=os.path.join(OUT,name)
    bpy.ops.render.render(write_still=True)
# active presentation camera, save blend
scene.camera=bpy.data.objects.get('Camera tower-perspective.png')
# select tower geometry only, hide lights/cameras in viewport via deselect all
bpy.ops.object.select_all(action='DESELECT')
# Export only the playable structure and its stone footings. Studio ground and
# scatter stones stay in the render scene but are excluded from the game asset.
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH' and obj.name != 'Display ground' and not obj.name.startswith('Small ground stone'):
        obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'tower.glb'), export_format='GLB', use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'tower.blend'))
