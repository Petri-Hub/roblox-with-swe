import bpy, math, os
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in bpy.data.materials: bpy.data.materials.remove(d)
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=40; scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
# collections
asset=bpy.data.collections.new('ARCANE BLASTER | asset'); scene.collection.children.link(asset)
studio=bpy.data.collections.new('STUDIO | render only'); scene.collection.children.link(studio)
def move_to(obj, coll=asset):
 for c in list(obj.users_collection): c.objects.unlink(obj)
 coll.objects.link(obj); return obj
def mat(name,color,metal=0,rough=.4,emission=None,power=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 if emission:
  p.inputs['Emission Color'].default_value=(*emission,1); p.inputs['Emission Strength'].default_value=power
 return m
steel=mat('01 | Midnight titanium',(.045,.075,.12),.82,.25)
edge=mat('02 | Brushed pale alloy',(.48,.58,.65),.8,.23)
brass=mat('03 | Antique electrum',(.72,.36,.09),.78,.27)
dark=mat('04 | Grip leather',(.035,.025,.045),.15,.52)
blue=mat('05 | Arc crystal',(.015,.42,.82),.25,.19,(.01,.32,1),2.2)
cyan=mat('06 | Conduit glow',(.02,.65,.78),.25,.2,(.01,.65,1),1.5)
def cube(name,loc,scale,material,bevel=.08):
 bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=move_to(bpy.context.object); o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Machined edge radii','BEVEL'); mod.width=bevel; mod.segments=2
  mod2=o.modifiers.new('Corner normals','WEIGHTED_NORMAL')
 o.data.materials.append(material); return o
def cyl(name,loc,r,depth,material,axis='X',verts=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc); o=move_to(bpy.context.object); o.name=name
 if axis=='X': o.rotation_euler[1]=math.pi/2
 elif axis=='Y': o.rotation_euler[0]=math.pi/2
 o.data.materials.append(material); bevel=o.modifiers.new('Turned rim','BEVEL'); bevel.width=.025; bevel.segments=2; o.modifiers.new('Weighted normals','WEIGHTED_NORMAL'); return o
def ico(name,loc,scale,material,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc); o=move_to(bpy.context.object); o.name=name; o.scale=scale; o.data.materials.append(material); return o
# barrel receiver, axis X
cube('Receiver | forged central chassis',(0,0,0.52),(2.55,.72,.72),steel,.14)
cube('Receiver | top spine',(0,.0,.93),(1.85,.58,.18),edge,.05)
cube('Receiver | lower rail',(0,0,.08),(1.7,.56,.12),brass,.035)
# large shroud and muzzle
cube('Emitter | faceted muzzle shroud',(1.33,0,.55),(1.1,.98,.88),steel,.16)
cyl('Muzzle | outer bezel',(1.93,0,.55),.34,.24,brass,'X',12)
cyl('Muzzle | dark aperture',(2.08,0,.55),.245,.12,dark,'X',12)
cyl('Muzzle | energized bore',(2.15,0,.55),.13,.06,cyan,'X',10)
# crystal projecting above barrel: elongated gem, custom ico stretched
ico('Arc crystal | primary focus',(.45,0,1.28),(.36,.32,.48),blue,1)
# crystal cage brackets
for y in [-.25,.25]:
 cube('Crystal cage | side rail',(.43,y,1.28),(.72,.075,.12),brass,.025)
for x in [.13,.73]:
 cube('Crystal cage | cross clasp',(x,0,1.55),(.11,.62,.08),edge,.025)
# grip angled slightly? grip down and back
cube('Grip | alloy neck',(-.54,0,.03),(.55,.62,.42),brass,.08)
g=cube('Grip | sculpted dark scales',(-.66,0,-.58),(.58,.68,1.03),dark,.16); g.rotation_euler[1]=-.16
cube('Grip | heel cap',(-.61,0,-1.12),(.68,.74,.16),edge,.05)
# side panels / inlays both faces, on y sides
for side in [-1,1]:
 cube('Receiver | side armor',(-.12,side*.385,.48),(1.16,.08,.4),edge,.07)
 cube('Side armor | inset enamel',(-.12,side*.435,.48),(.88,.035,.22),steel,.045)
 # three brass slashes
 for i in range(3):
  p=cube('Side armor | electrum vent',(-.37+i*.23,side*.46,.48),(.07,.025,.16),brass,.018); p.rotation_euler[1]=-.25
 cyl('Power dial | bezel',(-.92,side*.41,.55),.2,.1,brass,'Y',12)
 cyl('Power dial | glass',(-.92,side*.47,.55),.13,.035,cyan,'Y',12)
 # grip rivets
 for z in [-.36,-.68,-.94]: ico('Grip | alloy rivet',(-.68,side*.35,z),(.045,.025,.045),brass,1)
# barrel rails on flanks, venting and bands
for side in [-1,1]:
 cube('Barrel | side conduit',(.57,side*.4,.76),(.94,.07,.1),brass,.03)
 for i in range(4): cube('Barrel | heat vent',(1.0+i*.12,side*.505,.52),(.055,.02,.29),edge,.012)
# under-barrel trigger guard, trigger
# use torus rotated vertical plane XZ (torus default XY, rotate X 90)
bpy.ops.mesh.primitive_torus_add(major_radius=.26,minor_radius=.045,major_segments=12,minor_segments=6,location=(-.2,0,-.19),rotation=(math.pi/2,0,0)); o=move_to(bpy.context.object); o.name='Trigger | open alloy bow'; o.data.materials.append(brass)
cube('Trigger | actuator',(-.19,0,-.28),(.08,.11,.3),edge,.025)
# rear hammer and sight
cube('Rear | sight block',(-1.18,0,.82),(.35,.6,.27),steel,.06)
cube('Rear | sight notch',(-1.18,0,1.0),(.12,.26,.11),brass,.025)
# small fasteners
for x in [-1.05,1.05]:
 for side in [-1,1]: ico('Chassis | flush fastener',(x,side*.4,.17),(.055,.025,.055),brass,1)
# studio floor
floor_mat=mat('Studio | matte slate',(.025,.035,.055),.1,.58)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.27)); floor=move_to(bpy.context.object,studio); floor.name='Studio floor'; floor.data.materials.append(floor_mat)
def aim(o,pt): o.rotation_euler=(Vector(pt)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,color,size,target):
 bpy.ops.object.light_add(type='AREA',location=loc); o=move_to(bpy.context.object,studio); o.name=name; o.data.energy=power; o.data.color=color; o.data.shape='DISK'; o.data.size=size; aim(o,target)
def camera(name,loc,target,lens=55):
 bpy.ops.object.camera_add(location=loc); o=move_to(bpy.context.object,studio); o.name=name; o.data.lens=lens; aim(o,target); return o
area('Key | large cool softbox',(0,-5,6),850,(.72,.84,1),5,(0,0,0))
area('Rim | warm strip',(2,3,4),1000,(1,.48,.2),4,(0,0,.2))
area('Fill | front',(4,-3,1),450,(.15,.55,1),3,(0,0,.2))
area('Grip bounce',(-4,-2,1),350,(.75,.3,1),3,(-.5,0,-.4))
scene.world.color=(.025,.03,.05)
scene.view_settings.view_transform='AgX'
# cameras aim at center; orthographic-like telephoto perspective
front=camera('Camera | front',(.15,-8,.45),(.15,0,.2),58)
back=camera('Camera | reverse',(.15,8,.45),(.15,0,.2),58)
pres=camera('Camera | hero',(4.6,-7,4.1),(.1,0,.15),55)
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
def render(cam,filename):
 scene.camera=cam; scene.render.filepath=os.path.join(OUT,filename); bpy.ops.render.render(write_still=True)
render(front,'front.png'); render(back,'back.png'); render(pres,'presentation.png')
# export only asset collection meshes, selected; GLB will contain model/materials only
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects:
 if o.type=='MESH': o.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in asset.objects if o.type=='MESH')
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'asset.glb'),export_format='GLB',use_selection=True,export_apply=True)
# save full renderable scene
scene.camera=pres
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'asset.blend'))
print('DELIVERABLES',OUT)
