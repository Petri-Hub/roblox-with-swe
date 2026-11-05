import bpy, math, os
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(OUT,'cache'),exist_ok=True)
os.makedirs(os.path.join(OUT,'logs'),exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=8
scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
scene.world.color=(0.018,0.025,0.03)
# materials
def mat(name,color,metal=0,rough=.65,emission=None,strength=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
 if emission:
  bs.inputs['Emission Color'].default_value=(*emission,1); bs.inputs['Emission Strength'].default_value=strength
 return m
skin=mat('Marsh hide | peat and lichen',(0.105,.19,.145),0,.83)
bone=mat('Keratin plates | desaturated ivory',(.42,.48,.35),.05,.48)
glow=mat('Bog light | cyan phosphor',(.01,.55,.47),.05,.25,(.03,.9,.72),4)
dark=mat('Mouth cavity | deep teal',(.003,.025,.026),0,.4)
# armature
bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0)); arm=bpy.context.object; arm.name='Vigia_Rig'; arm.data.name='Vigia_Skeleton'
base=arm.data.edit_bones[0]; base.name='root'; base.head=(0,0,0); base.tail=(0,0,.7)
def bone_add(name,head,tail,parent,connect=False):
 b=arm.data.edit_bones.new(name); b.head=head;b.tail=tail;b.parent=arm.data.edit_bones.get(parent);b.use_connect=connect; return b
bone_add('pelvis',(0,0,.72),(0,0,1.28),'root')
bone_add('spine',(0,0,1.28),(0,-.10,2.25),'pelvis',True)
bone_add('neck',(0,-.10,2.25),(0,-.19,2.72),'spine',True)
bone_add('head',(0,-.19,2.72),(0,-.23,3.25),'neck',True)
for side,s in [('L',-1),('R',1)]:
 bone_add('upper_arm.'+side,(s*.35,-.02,2.10),(s*.83,-.03,1.75),'spine')
 bone_add('forearm.'+side,(s*.83,-.03,1.75),(s*1.21,-.17,1.06),'upper_arm.'+side,True)
 bone_add('hand.'+side,(s*1.21,-.17,1.06),(s*1.35,-.30,.66),'forearm.'+side,True)
 bone_add('thigh.'+side,(s*.18,0,.95),(s*.24,-.01,.52),'pelvis')
 bone_add('shin.'+side,(s*.24,-.01,.52),(s*.27,-.06,.13),'thigh.'+side,True)
 bone_add('foot.'+side,(s*.27,-.06,.13),(s*.27,-.43,.08),'shin.'+side,True)
bpy.ops.object.mode_set(mode='OBJECT')
# create ellipsoid mesh with low-ish UV sphere and assign single bone group
def ell(name,loc,scale,material,bone_name,rot=None,seg=12,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc)
 ob=bpy.context.object; ob.name=name; ob.scale=scale
 if rot: ob.rotation_euler=rot
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 ob.data.materials.append(material)
 vg=ob.vertex_groups.new(name=bone_name); vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
 mod=ob.modifiers.new('Skeleton deformation','ARMATURE'); mod.object=arm
 return ob

def rod(name,a,b,radius,material,bone_name):
 a,b=Vector(a),Vector(b); vec=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=radius, radius2=radius*.82, depth=vec.length, location=(a+b)/2)
 ob=bpy.context.object; ob.name=name; ob.rotation_euler=vec.to_track_quat('Z','Y').to_euler(); ob.data.materials.append(material)
 vg=ob.vertex_groups.new(name=bone_name); vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
 mod=ob.modifiers.new('Skeleton deformation','ARMATURE'); mod.object=arm
 return ob
# body masses
ell('Thorax',(0,-.04,1.92),(.40,.34,.70),skin,'spine')
ell('Shoulder mantle',(0,.0,2.17),(.53,.34,.29),bone,'spine')
ell('Hunched back ridge',(0,.28,2.08),(.29,.17,.62),skin,'spine',rot=(.15,0,0))
ell('Pelvis',(0,.01,1.00),(.30,.29,.35),skin,'pelvis')
ell('Neck',(0,-.14,2.46),(.20,.19,.42),skin,'neck',rot=(.14,0,0))
ell('Skull',(0,-.24,2.89),(.31,.28,.39),skin,'head')
# glowing gaping vertical aperture and rim; forward is -Y
ell('Aperture shadow',(0,-.493,2.85),(.205,.025,.265),dark,'head',seg=12,rings=8)
ell('Inner glow',(0,-.519,2.84),(.133,.018,.19),glow,'head',seg=10,rings=6)
# rim brow and jaw plates
ell('Crown plate',(0,-.36,3.18),(.31,.19,.13),bone,'head')
ell('Jaw plate',(0,-.39,2.56),(.25,.17,.12),bone,'head')
# limb segmented anatomy
for side,s in [('L',-1),('R',1)]:
 ell('Upper arm '+side,(s*.61,-.035,1.93),(.23,.24,.48),skin,'upper_arm.'+side,rot=(0,s*.75,0))
 rod('Continuous upper limb '+side,(s*.37,-.06,2.16),(s*.85,-.07,1.69),.145,skin,'upper_arm.'+side)
 ell('Elbow '+side,(s*.84,-.045,1.70),(.19,.20,.20),bone,'forearm.'+side)
 ell('Long forearm '+side,(s*1.04,-.105,1.39),(.18,.19,.43),skin,'forearm.'+side,rot=(0,s*.48,0))
 rod('Continuous forearm '+side,(s*.85,-.07,1.69),(s*1.24,-.17,.98),.12,skin,'forearm.'+side)
 ell('Forearm carapace '+side,(s*1.04,-.22,1.44),(.15,.045,.31),bone,'forearm.'+side,rot=(0,s*.48,0),seg=8,rings=5)
 ell('Palm '+side,(s*1.27,-.22,.91),(.19,.14,.22),skin,'hand.'+side)
 # long tapered fingers as ellipsoids
 for i in range(3):
  x=s*(1.17+i*.13); z=.70-(.04 if i==1 else 0)
  ell('Finger%d %s'%(i,side),(x,-.25,z),(.055,.07,.20 if i==1 else .16),bone,'hand.'+side,rot=(0,s*.15,0),seg=8,rings=5)
 ell('Thigh '+side,(s*.21,-.01,.72),(.22,.23,.33),skin,'thigh.'+side)
 ell('Knee '+side,(s*.24,-.04,.49),(.18,.20,.17),bone,'shin.'+side)
 ell('Shin '+side,(s*.25,-.04,.30),(.16,.18,.28),skin,'shin.'+side)
 ell('Broad foot '+side,(s*.27,-.24,.105),(.25,.43,.13),skin,'foot.'+side,seg=10,rings=6)
 # toe ridge plates
 for i in range(3): ell('Toe plate%d %s'%(i,side),(s*(.15+.12*i),-.48,.15),(.07,.18,.055),bone,'foot.'+side,seg=8,rings=5)
# additional rib-like plates on torso
for z in [1.65,1.83,2.01]:
 for s in [-1,1]: ell('Rib plate',(s*.25,-.31,z),(.17,.06,.075),bone,'spine',rot=(0,s*.25,0),seg=8,rings=5)
# pose animation subtle
scene.frame_start=1;scene.frame_end=48;scene.render.fps=24
pb=arm.pose.bones
for name in pb.keys(): pb[name].rotation_mode='XYZ'
for f in [1,13,25,37,49]:
 scene.frame_set(min(f,48))
 phase=2*math.pi*(f-1)/48
 pb['spine'].rotation_euler[0]=.035*math.sin(phase)
 pb['neck'].rotation_euler[0]=.025*math.sin(phase+.6)
 pb['head'].rotation_euler[1]=.035*math.sin(phase+.4)
 for side,sgn in [('L',-1),('R',1)]:
  pb['upper_arm.'+side].rotation_euler[1]=sgn*(.025+.025*math.sin(phase+.2))
  pb['forearm.'+side].rotation_euler[0]=.02*math.sin(phase+sgn*.3)
 for b in pb:
  b.keyframe_insert(data_path='rotation_euler',frame=min(f,48),group=b.name)
# looping action modifiers
if arm.animation_data and arm.animation_data.action and hasattr(arm.animation_data.action, 'fcurves'):
 for fc in arm.animation_data.action.fcurves:
  fc.modifiers.new('CYCLES')
# stage: floor, cameras, lights
floor_mat=mat('Stage | matte charcoal',(.025,.04,.045),.1,.65)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.035)); floor=bpy.context.object;floor.name='STUDIO_Floor'; floor.data.materials.append(floor_mat)
def aim(obj,pt): obj.rotation_euler=(Vector(pt)-obj.location).to_track_quat('-Z','Y').to_euler()
def camera(name,loc,target,ortho=4.05):
 bpy.ops.object.camera_add(location=loc); c=bpy.context.object;c.name=name;c.data.type='ORTHO';c.data.ortho_scale=ortho;aim(c,target);return c
def area(name,loc,power,color,size,target):
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.name=name;l.data.energy=power;l.data.color=color;l.data.shape='DISK';l.data.size=size;aim(l,target)
area('Key softbox',(-3.5,-4.5,5),520,(.67,.86,1),4,(0,0,1.5));area('Warm fill',(4,-2,3.2),360,(1,.56,.32),3,(0,0,1.5));area('Bog rim',(0,2.6,3.6),700,(.12,.8,.68),2.5,(0,0,1.7))
front=camera('CAM_Front',(0,-8,1.85),(0,0,1.62)); back=camera('CAM_Back',(0,8,1.85),(0,0,1.62)); # back looks toward front
presentation=camera('CAM_Presentation',(4.4,-6.5,3.3),(0,0,1.62),4.15)
# render routine
scene.view_settings.view_transform='AgX'
def render(name,cam,frame):
 scene.camera=cam;scene.frame_set(frame);scene.render.filepath=os.path.join(OUT,name);bpy.ops.render.render(write_still=True)
render('front.png',front,1);render('back.png',back,1);render('presentation.png',presentation,1)
render('pose-01.png',presentation,1);render('pose-24.png',presentation,24);render('pose-48.png',presentation,48)
# save native scene
scene.camera=presentation;scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'asset.blend'))
# export asset mesh and rig only (no studio)
bpy.ops.object.select_all(action='DESELECT')
for ob in bpy.context.scene.objects:
 if ob.type in {'MESH','ARMATURE'} and ob not in {floor}:
  ob.select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'asset.glb'),export_format='GLB',use_selection=True,export_animations=True,export_frame_range=True,export_force_sampling=True,export_nla_strips=False,export_yup=True)
print('DONE: generated blend, glb, 6 renders')
