import bpy, math, os, sys
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(OUT,'logs'),exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection': bpy.data.collections.remove(c)
root=bpy.context.scene.collection
asset=bpy.data.collections.new('ARCANE_BLASTER_ASSET'); root.children.link(asset)
studio=bpy.data.collections.new('STUDIO_NOT_EXPORTED'); root.children.link(studio)
def link(ob, col=asset):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    col.objects.link(ob); return ob
def mat(name,color,metal=0,rough=.35,emit=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if emit:
        p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emit
    return m
iron=mat('M_Aethersteel',(0.105,.17,.22),.88,.25)
bright=mat('M_EdgeSilver',(.48,.61,.64),.82,.2)
gold=mat('M_Brass',(.72,.36,.08),.78,.27)
black=mat('M_Grip_Leather',(.055,.033,.028),.05,.68)
blue=mat('M_Crystal_Cyan',(.015,.43,.72),.15,.18,2.4)
dark=mat('M_Recess',(.012,.023,.031),.5,.42)
def cube(name,loc,scale,ma,bev=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=link(bpy.context.object); o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(ma)
    if bev:
        b=o.modifiers.new('Machined edge radii','BEVEL'); b.width=bev; b.segments=1; b.limit_method='ANGLE'
        n=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); n.keep_sharp=True
    return o
def cyl(name,loc,r,depth,ma,axis='X',verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc); o=link(bpy.context.object); o.name=name
    if axis=='X': o.rotation_euler[1]=math.pi/2
    elif axis=='Y': o.rotation_euler[0]=math.pi/2
    o.data.materials.append(ma); b=o.modifiers.new('Crisp bevel','BEVEL'); b.width=.018; b.segments=1
    return o
# Broad firearm profile; barrel points right (+X), hand grip below.
cube('Receiver_Main',(.05,0,.05),(1.48,.46,.53),iron,.1)
cube('Receiver_Side_Plate',(.02,-.25,.02),(.9,.035,.30),bright,.045)
cube('Receiver_Inlay',(.02,-.274,.02),(.72,.018,.21),dark,.025)
# Upper rail & frame
cube('Top_Rail',(.10,0,.36),(1.14,.32,.11),gold,.025)
for i in range(6): cube('Rail_Notch_%02d'%i,(-.39+i*.19,0,.432),(.07,.35,.035),bright,.008)
# Barrel stack
cyl('Barrel_Base',(.91,0,.10),.18,.50,bright,verts=12)
cyl('Muzzle_Collar',(1.19,0,.10),.235,.16,gold,verts=10)
cyl('Muzzle_Shroud',(1.39,0,.10),.19,.32,iron,verts=10)
cyl('Muzzle_Rim',(1.57,0,.10),.215,.08,bright,verts=12)
cyl('Muzzle_Bore',(1.617,0,.10),.128,.025,dark,verts=12)
cyl('Bore_Glow',(1.634,0,.10),.062,.012,blue,verts=8)
# crystal emitter above front of receiver: faceted octagonal prism along X
cyl('Emitter_Socket',(.61,0,.48),.16,.22,gold,verts=8)
cyl('Crystal_Cage',(.70,0,.64),.135,.18,dark,verts=8)
cyl('Arcane_Crystal',(.76,0,.67),.105,.30,blue,verts=6)
# grip with rearward rake; separate shaped mesh
verts=[(-.42,-.20,-.22),(-.08,-.20,-.22),(-.22,-.17,-.86),(-.58,-.17,-.86),(-.42,.20,-.22),(-.08,.20,-.22),(-.22,.17,-.86),(-.58,.17,-.86)]
faces=[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
me=bpy.data.meshes.new('GripMesh'); me.from_pydata(verts,[],faces); me.materials.append(black); ob=bpy.data.objects.new('Grip_Leather',me); asset.objects.link(ob)
b=ob.modifiers.new('Soft grip edges','BEVEL'); b.width=.045; b.segments=1
cube('Grip_Butt_Cap',(-.40,0,-.83),(.42,.42,.12),gold,.04)
# grip ribs on visible side
for i in range(5):
    cube('Grip_Rib_%02d'%i,(-.38-i*.025,-.211,-.34-i*.095),(.25,.025,.025),bright,.008)
# trigger guard and trigger
# torus in XZ plane
bpy.ops.mesh.primitive_torus_add(major_radius=.17,minor_radius=.025,major_segments=12,minor_segments=6,location=(-.28,-.28,-.31),rotation=(math.pi/2,0,0)); o=link(bpy.context.object); o.name='Trigger_Guard'; o.data.materials.append(gold)
cube('Trigger',(-.25,-.30,-.32),(.045,.06,.17),bright,.018)
# visible arcane side-cell and screws
cyl('Side_Reactor_Frame',(-.32,-.30,.05),.115,.07,gold,axis='Y',verts=10)
cyl('Side_Reactor_Glass',(-.32,-.345,.05),.078,.025,blue,axis='Y',verts=8)
for x,z in [(-.60,.19),(.63,.19),(-.60,-.10),(.63,-.10)]:
    cyl('Panel_Rivet',(x,-.296,z),.027,.022,bright,axis='Y',verts=8)
# forward fins
for z in [-.08,.24]: cube('Barrel_Vent',(.89,-.205,z),(.30,.045,.035),gold,.01)
# collection ownership metadata
asset['export_intent']='Only this collection belongs in asset.glb'
# Studio floor
floor_mat=mat('Studio_Backdrop',(.028,.043,.060),0,.8)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-1.02)); fl=link(bpy.context.object,studio); fl.name='Studio_Floor'; fl.data.materials.append(floor_mat)
def aim(o,pt): o.rotation_euler=(Vector(pt)-o.location).to_track_quat('-Z','Y').to_euler()
# cameras front/back and 3/4
for name,loc in [('Cam_Front',(0,-6,0)),('Cam_Back',(0,6,0)),('Cam_Presentation',(3.2,-5.6,2.2))]:
    ca=bpy.data.cameras.new(name); cam=bpy.data.objects.new(name,ca); studio.objects.link(cam); cam.location=loc; aim(cam,(.02,0,-.03)); ca.type='ORTHO'; ca.ortho_scale=3.75 if name!='Cam_Presentation' else 4.15; ca.lens=55
# broad area lights
for name,loc,power,size,color in [('Key',(-3,-4,4),650,4,(.74,.86,1)),('Fill',(3,-2,1),460,3,(.28,.72,1)),('Rim',(1,3,3),850,3,(1,.48,.19))]:
    ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size; ld.color=color; lo=bpy.data.objects.new(name,ld); studio.objects.link(lo); lo.location=loc; aim(lo,(0,0,0))
world=bpy.data.worlds.new('Studio_World'); bpy.context.scene.world=world; world.use_nodes=True; world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.06,.09,.14,1); world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.35
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=24; sc.cycles.use_denoising=True
sc.render.threads_mode='FIXED'; sc.render.threads=4
sc.render.resolution_x=768; sc.render.resolution_y=768; sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG'; sc.render.image_settings.color_mode='RGBA'
sc.view_settings.view_transform='AgX'; sc.render.film_transparent=False
# Save editable file with camera and studio
blend=os.path.join(OUT,'asset.blend'); bpy.ops.wm.save_as_mainfile(filepath=blend)
# render requested viewpoints
fl.hide_render=True
for name,file in [('Cam_Front','front.png'),('Cam_Back','back.png'),('Cam_Presentation','presentation.png')]:
    if name=='Cam_Presentation': fl.hide_render=False
    sc.camera=bpy.data.objects[name]; sc.render.filepath=os.path.join(OUT,file); bpy.ops.render.render(write_still=True)
# export only asset collection objects
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects: o.select_set(True)
bpy.context.view_layer.objects.active=asset.objects[0]
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'asset.glb'), export_format='GLB', use_selection=True, export_cameras=False, export_lights=False, export_materials='EXPORT')
print('DELIVERY',len(asset.objects),sum(len(p.vertices) for o in asset.objects if o.type=='MESH' for p in [o.data]),'objects')
