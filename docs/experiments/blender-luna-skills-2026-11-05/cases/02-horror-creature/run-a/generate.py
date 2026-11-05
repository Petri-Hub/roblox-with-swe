import bpy, math, os, json
from mathutils import Vector, Quaternion

OUT = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(OUT, 'logs'), exist_ok=True)
# Clean scene deterministically
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in (bpy.data.collections,):
    pass
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=6
scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
scene.render.fps=24; scene.frame_start=1; scene.frame_end=48
scene.view_settings.view_transform='AgX'
scene.render.film_transparent=False
scene.world.color=(0.025,0.035,0.03)
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1

# Collections
asset=bpy.data.collections.new('ASSET_VigiaDoBrejo'); scene.collection.children.link(asset)
studio=bpy.data.collections.new('STUDIO'); scene.collection.children.link(studio)
def move_to(obj, col=asset):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)

def mat(name, color, rough=.7, metallic=0, emission=None, strength=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metallic
    if emission:
        p.inputs['Emission Color'].default_value=(*emission,1); p.inputs['Emission Strength'].default_value=strength
    return m
skin=mat('M_Pele_Lodo',(0.105,.17,.135),.88)
skin2=mat('M_Pele_Sombra',(.055,.09,.075),.92)
bone=mat('M_Placas_Osseas',(.38,.39,.29),.62)
black=mat('M_Abertura',(0.004,.009,.008),.42)
glow=mat('M_Brilho_Breu',(.05,.75,.47),.28,emission=(.05,1,.56),strength=5.0)
claw=mat('M_Unha',(0.12,.16,.13),.43,.12)

# helper ico sphere, scaled/applied dimensions and optionally rotate
def ico(name, loc, scale, material, bone_name, subdivisions=1, rot=(0,0,0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; o.rotation_euler=rot
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material); move_to(o)
    return o

def cone_between(name, a,b,r1,r2,material,bone_name,verts=7):
    a=Vector(a); b=Vector(b); d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length, location=(a+b)/2)
    o=bpy.context.object; o.name=name; o.rotation_mode='QUATERNION'; o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized())
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material); move_to(o); return o

# Skeleton built in correct rest locations, facing -Y, bent forward silhouette
arm_data=bpy.data.armatures.new('RIG_VigiaDoBrejo'); rig=bpy.data.objects.new('RIG_VigiaDoBrejo',arm_data); asset.objects.link(rig)
bpy.context.view_layer.objects.active=rig; rig.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
def eb(name,head,tail,parent=None,connect=False):
    b=arm_data.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=arm_data.edit_bones[parent]; b.use_connect=connect
    return b
eb('root',(0,0,0),(0,0,.18))
eb('pelvis',(0,0,.86),(0,0,1.18),'root')
eb('spine',(0,0,1.08),(0,-.12,1.72),'pelvis')
eb('neck',(0,-.12,1.72),(0,-.20,1.91),'spine')
eb('head',(0,-.20,1.91),(0,-.25,2.25),'neck')
for side,s in [('L',1),('R',-1)]:
    eb('upper_arm.'+side,(s*.30,-.10,1.63),(s*.58,-.17,1.17),'spine')
    eb('forearm.'+side,(s*.58,-.17,1.17),(s*.78,-.28,.70),'upper_arm.'+side,True)
    eb('hand.'+side,(s*.78,-.28,.70),(s*.83,-.31,.51),'forearm.'+side,True)
    eb('thigh.'+side,(s*.16,0,.99),(s*.22,-.01,.58),'pelvis')
    eb('shin.'+side,(s*.22,-.01,.58),(s*.24,-.08,.20),'thigh.'+side,True)
    eb('foot.'+side,(s*.24,-.08,.20),(s*.24,-.34,.12),'shin.'+side,True)
bpy.ops.object.mode_set(mode='OBJECT'); rig.select_set(False)

# Forms: character height ~2.27m, shoulders broad, hunched, oversized skull / maw
objects=[]
def part(o,b):
    o['bone']=b; objects.append((o,b)); return o
part(ico('Body_Ribcage',(0,-.08,1.43),(.39,.32,.48),skin,'spine',2,(.10,0,0)),'spine')
part(ico('Pelvis',(0,.015,1.03),(.29,.27,.25),skin2,'pelvis',1),'pelvis')
part(ico('Hump',(0,.17,1.57),(.35,.25,.38),skin2,'spine',1,(-.18,0,0)),'spine')
part(ico('Skull',(0,-.20,2.04),(.31,.28,.36),skin,'head',2,(.12,0,0)),'head')
# dark vertical facial aperture and inner light. Face points -Y
part(ico('Maul_Opening',(0,-.456,2.01),(.17,.028,.24),black,'head',2,(-.08,0,0)),'head')
part(ico('Inner_Glow',(0,-.482,2.01),(.105,.018,.18),glow,'head',2),'head')
# brow / crown bone flanges
for s,side in [(1,'L'),(-1,'R')]:
    part(cone_between('Crown_Spike.'+side,(s*.11,-.18,2.26),(s*.22,-.20,2.51),.105,.008,bone,'head',6),'head')
    part(ico('Brow_Plate.'+side,(s*.13,-.39,2.20),(.17,.11,.09),bone,'head',1,(0,s*.08,-s*.08)),'head')
    # shoulder armor plates and ribs
    part(ico('Shoulder_Plate.'+side,(s*.37,-.10,1.66),(.23,.27,.19),bone,'spine',1,(0,s*.12,-s*.14)),'spine')
    part(cone_between('Collar_Rib.'+side,(s*.06,-.35,1.62),(s*.34,-.34,1.52),.047,.014,bone,'spine',6),'spine')
    # arms tapered upper/lower taper, joints, hands, long hooked fingers
    part(cone_between('UpperArm.'+side,(s*.36,-.11,1.58),(s*.58,-.16,1.18),.145,.108,skin,'upper_arm.'+side,8),'upper_arm.'+side)
    part(ico('Elbow.'+side,(s*.58,-.16,1.18),(.115,.11,.13),skin2,'forearm.'+side,1),'forearm.'+side)
    part(cone_between('Forearm.'+side,(s*.59,-.16,1.14),(s*.79,-.26,.70),.115,.07,skin,'forearm.'+side,8),'forearm.'+side)
    part(ico('WristBone.'+side,(s*.79,-.26,.70),(.105,.09,.11),bone,'hand.'+side,1),'hand.'+side)
    part(ico('Palm.'+side,(s*.82,-.29,.59),(.11,.095,.15),skin2,'hand.'+side,1),'hand.'+side)
    for j in range(3):
        x=s*(.76+j*.06); z=.55-(.035 if j==1 else 0)
        part(cone_between('Finger'+str(j)+'.'+side,(x,-.31,z),(x+s*.025,-.35,z-.19),.035,.014,skin,'hand.'+side,6),'hand.'+side)
        part(cone_between('Claw'+str(j)+'.'+side,(x+s*.025,-.35,z-.19),(x+s*.045,-.38,z-.265),.018,.001,claw,'hand.'+side,5),'hand.'+side)
    # narrow legs / visible knee plates / giant feet
    part(cone_between('Thigh.'+side,(s*.15,.01,.97),(s*.22,-.01,.59),.14,.105,skin,'thigh.'+side,8),'thigh.'+side)
    part(ico('Knee.'+side,(s*.22,-.06,.57),(.12,.13,.13),bone,'shin.'+side,1),'shin.'+side)
    part(cone_between('Shin.'+side,(s*.22,-.01,.57),(s*.24,-.10,.20),.105,.075,skin2,'shin.'+side,7),'shin.'+side)
    part(ico('Foot.'+side,(s*.24,-.29,.12),(.19,.38,.13),skin,'foot.'+side,1,(-.04,0,0)),'foot.'+side)
    for j in range(3):
        x=s*.24+(j-1)*.095
        part(cone_between('ToeClaw'+str(j)+'.'+side,(x,-.48,.11),(x,-.59,.075),.045,.004,claw,'foot.'+side,5),'foot.'+side)
# rib ridges and dorsal spines
for i,z in enumerate([1.47,1.34,1.21]):
    for s,side in [(1,'L'),(-1,'R')]:
        part(cone_between('Rib'+str(i)+'.'+side,(s*.08,-.355,z+.035),(s*.29,-.29,z-.035),.033,.006,bone,'spine',6),'spine')
for i,z in enumerate([1.35,1.52,1.69]):
    part(cone_between('Dorsal_Spine'+str(i),(0,.29,z),(0,.49,z+.10),.075,.002,bone,'spine',6),'spine')

# assign each part fully to its controlling bone. Object origins maintained in world-space; armature modifier uses pose transforms.
for ob,bn in objects:
    vg=ob.vertex_groups.new(name=bn); vg.add(list(range(len(ob.data.vertices))),1.0,'REPLACE')
    mod=ob.modifiers.new('Skin_Rig','ARMATURE'); mod.object=rig
    ob.parent=rig
    ob.matrix_parent_inverse=rig.matrix_world.inverted()

# Bone display / action
rig.show_in_front=True; rig.data.display_type='OCTAHEDRAL'
rig.animation_data_create(); act=bpy.data.actions.new('VigiaDoBrejo_Idle'); rig.animation_data.action=act
for p in rig.pose.bones: p.rotation_mode='XYZ'
# Gentle breath and drift, exact looping endpoints (frames 1 and 49), clip 1..48
for f in (1,13,25,37,49):
    phase=2*math.pi*(f-1)/48
    scene.frame_set(f)
    for n,amp,axis in [('spine',.022,0),('neck',.035,1),('head',.028,0),('upper_arm.L',.018,1),('upper_arm.R',.018,1),('forearm.L',.025,0),('forearm.R',.025,0)]:
        pb=rig.pose.bones[n]; val=amp*math.sin(phase + (0.7 if 'R' in n else 0))
        pb.rotation_euler[axis]=val
        pb.keyframe_insert(data_path='rotation_euler',frame=f,group=n)
# enforce smooth cycle by using samples and set linear interpolation
if act:
    for slot in getattr(act,'slots',[]): pass
    # ensure curves interpolation on current action via legacy accessor fallback
    try:
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for kp in fc.keyframe_points: kp.interpolation='BEZIER'; kp.handle_left_type='AUTO_CLAMPED'; kp.handle_right_type='AUTO_CLAMPED'
    except Exception: pass
scene.frame_set(1)

# Studio backdrop outside export collection
mat_floor=mat('M_Studio',(0.018,.026,.023),.82)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.02)); floor=bpy.context.object; floor.name='Studio_Ground'; floor.data.materials.append(mat_floor); move_to(floor,studio)

def aim(obj, point): obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,color,size):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.color=color; data.shape='DISK'; data.size=size
    o=bpy.data.objects.new(name,data); studio.objects.link(o); o.location=loc; aim(o,(0,0,1.2)); return o
area('Key_Softbox',(-3,-4,4),500,(.70,.88,.80),3)
area('Fill_Softbox',(3,-2,2.8),260,(.42,.68,.72),2.5)
area('Rim_Swamp',(1,2.8,3.3),700,(.28,.95,.60),2.2)
area('Front_Bounce',(0,-3,1.1),80,(.56,.78,.70),2)

def camera(name,loc,target,lens=62):
    data=bpy.data.cameras.new(name); o=bpy.data.objects.new(name,data); studio.objects.link(o); o.location=loc; aim(o,target); data.lens=lens; data.clip_end=100; return o
cams={
 'front':camera('Camera_Front',(0,-6.5,1.43),(0,-.02,1.25),58),
 'back':camera('Camera_Back',(0,6.5,1.43),(0,0,1.25),58),
 'presentation':camera('Camera_Presentation',(3.5,-5.6,2.25),(0,-.02,1.25),62),
}
# ground catches only contact and shadows; world background dark teal
world=scene.world or bpy.data.worlds.new('World'); scene.world=world; world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.018,.026,.023,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.24
scene.render.image_settings.color_mode='RGBA'; scene.render.resolution_percentage=100
scene.cycles.samples=6; scene.cycles.use_denoising=True

# Save scene before render
scene.camera=cams['presentation']; scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'asset.blend'))
# Render deliverables
for name,c in cams.items():
    scene.camera=c; scene.frame_set(1); scene.render.filepath=os.path.join(OUT,name+'.png')
    bpy.ops.render.render(write_still=True)
for f in (1,24,48):
    scene.frame_set(f); scene.camera=cams['presentation']; scene.render.filepath=os.path.join(OUT,'pose-%02d.png'%f)
    bpy.ops.render.render(write_still=True)
# Export only asset collection; ground, lights, cameras excluded by selection.
bpy.ops.object.select_all(action='DESELECT')
for ob in asset.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=rig
scene.frame_set(1)
res=bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'asset.glb'), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_range=True, export_skins=True, export_morph=False, export_materials='EXPORT')
with open(os.path.join(OUT,'logs','generation.json'),'w') as f:
    json.dump({'export_operator':str(res),'asset_objects':len(asset.objects),'meshes':sum(o.type=='MESH' for o in asset.objects),'tris':sum(len(p.vertices)-2 for o in asset.objects if o.type=='MESH' for p in o.data.polygons),'action':act.name,'frame_range':[scene.frame_start,scene.frame_end]},f,indent=2)
# Save final frame state and studio camera
scene.camera=cams['presentation']; scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'asset.blend'))
print('BUILD_DONE',json.dumps({'objects':len(asset.objects),'tris':sum(len(p.vertices)-2 for o in asset.objects if o.type=='MESH' for p in o.data.polygons),'action':act.name,'outputs':os.listdir(OUT)}))
