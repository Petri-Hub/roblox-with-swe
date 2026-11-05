import bpy, bmesh, math, os, random
from mathutils import Vector

ROOT=os.path.dirname(os.path.abspath(__file__))
OUT=os.path.join(ROOT,'modules')
random.seed(23)
# Empty scene owned by this deliverable.
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes,bpy.data.curves,bpy.data.materials,bpy.data.cameras,bpy.data.lights):
    for d in list(datablocks):
        if d.users==0: datablocks.remove(d)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0; scene.unit_settings.length_unit='METERS'
for name in ['ASSET_Demo','ASSET_Modules','STUDIO']:
    c=bpy.data.collections.new(name); scene.collection.children.link(c)
COL={c.name:c for c in scene.collection.children}

def mat(name,color,rough=.86,metal=0,emission=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Roughness'].default_value=rough; bs.inputs['Metallic'].default_value=metal
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1); bs.inputs['Emission Strength'].default_value=emission
    return m
MATS=[mat('M_Basalt',(.115,.145,.17)),mat('M_Slate',(.24,.285,.30)),mat('M_Stone',(.37,.39,.36)),mat('M_Limestone',(.56,.48,.34)),mat('M_Iron',(.12,.085,.055),.38,.72),mat('M_Flame',(.95,.24,.035),.35,0,4)]

class Geo:
    def __init__(self): self.v=[]; self.f=[]; self.mi=[]
    def box(self,x0,x1,y0,y1,z0,z1,matidx):
        i=len(self.v); self.v.extend([(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)])
        self.f.extend([(i+a for a in face) for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
        self.mi.extend([matidx]*6)
    def cylinder(self,cx,cy,z0,z1,r,matidx,segments=8,r2=None):
        r2=r if r2 is None else r2; i=len(self.v)
        for z,rr in [(z0,r),(z1,r2)]:
            for k in range(segments):
                a=2*math.pi*k/segments+math.pi/8; self.v.append((cx+rr*math.cos(a),cy+rr*math.sin(a),z))
        for k in range(1,segments-1):
            self.f.append((i,i+k+1,i+k)); self.mi.append(matidx)
            self.f.append((i+segments,i+segments+k,i+segments+k+1)); self.mi.append(matidx)
        for k in range(segments):
            n=(k+1)%segments; self.f.append((i+k,i+n,i+segments+n,i+segments+k)); self.mi.append(matidx)
    def arch(self,cx,cy,zcenter,rin,rout,ystart,yend,segments=12,matidx=2):
        i=len(self.v)
        for y in (ystart,yend):
            for r in (rin,rout):
                for k in range(segments+1):
                    a=math.pi*k/segments; self.v.append((cx+r*math.cos(a),y,zcenter+r*math.sin(a)))
        n=segments+1; # groups: front inner, front outer, back inner, back outer
        # front/back ribbons and radial end walls
        for k in range(segments):
            self.f.append((i+k,i+k+1,i+n+k+1,i+n+k)); self.mi.append(matidx)
            self.f.append((i+2*n+k+1,i+2*n+k,i+3*n+k,i+3*n+k+1)); self.mi.append(matidx)
            self.f.append((i+k,i+2*n+k,i+2*n+k+1,i+k+1)); self.mi.append(matidx)
            self.f.append((i+n+k+1,i+3*n+k+1,i+3*n+k,i+n+k)); self.mi.append(matidx)
        self.f.extend([(i,i+n,i+3*n,i+2*n),(i+segments,i+2*n+segments,i+3*n+segments,i+n+segments)])
        self.mi.extend([matidx,matidx])
    def object(self,name,collection,origin=(0,0,0),bevel=.018):
        mesh=bpy.data.meshes.new(name+'Mesh'); mesh.from_pydata(self.v,[],[tuple(x) for x in self.f]); mesh.update()
        ob=bpy.data.objects.new(name,mesh); collection.objects.link(ob)
        used=sorted(set(self.mi)); remap={old:new for new,old in enumerate(used)}
        for old in used: mesh.materials.append(MATS[old])
        for p,idx in zip(mesh.polygons,self.mi): p.material_index=remap[idx]; p.use_smooth=False
        ob.location=origin
        if bevel:
            mod=ob.modifiers.new('Soft_Chipped_Edges','BEVEL'); mod.width=bevel; mod.segments=1; mod.limit_method='ANGLE'; mod.angle_limit=math.radians(28); mod.harden_normals=True
        return ob

def build_floor(name):
    # Walking surface is Z=0; slab thickness drops below the module datum.
    g=Geo(); g.box(0,4,0,4,-.36,-.08,0)
    # Four large inset-like stone slabs; seams are backed by the solid base.
    for ix in range(2):
      for iy in range(2):
        x0=ix*2+.035; x1=(ix+1)*2-.035; y0=iy*2+.035; y1=(iy+1)*2-.035
        g.box(x0,x1,y0,y1,-.085,0,[1,2,1,2][ix*2+iy])
    return g.object(name,COL['ASSET_Modules'],bevel=.025)

def build_wall(name):
    g=Geo(); g.box(0,4,-.19,.19,0,4,0)
    # Staggered masonry on both sides, overlapping the backing slab so there are no loose stones.
    for side in (-1,1):
      for row in range(7):
        z0=.04+row*.56; z1=min(3.96,z0+.50); x=.0+(0.0 if row%2==0 else -.42)
        while x<4:
          width=1.20 if row%2==0 else 1.05
          a=max(.025,x+.035); b=min(3.975,x+width-.035)
          if b>a: g.box(a,b,side*.155-.045 if side<0 else side*.155,side*.155 if side<0 else side*.155+.045,z0,z1,random.choice([1,2]))
          x+=width
    # cap stones along top, segmented but flush to the core
    for i in range(4):
      g.box(i+.03,i+.97,-.23,.23,3.84,4.02,3)
    return g.object(name,COL['ASSET_Modules'],bevel=.018)

def build_arch(name):
    g=Geo(); g.box(0,.78,-.22,.22,0,2.48,0); g.box(3.22,4,-.22,.22,0,2.48,0)
    # Radial voussoirs form one continuous traversable opening: 2.24 m wide, 3.58 m high.
    g.arch(2,0,2.45,1.12,1.55,-.22,.22,12,3)
    # Stone bases and understated cap accents.
    for x in (.39,3.61):
      g.box(x-.44,x+.44,-.25,.25,.02,.22,3)
      g.box(x-.43,x+.43,-.25,.25,2.30,2.52,2)
    return g.object(name,COL['ASSET_Modules'],bevel=.012)

def build_corner(name):
    g=Geo(); outline=[(-.19,-.19),(4,-.19),(4,.19),(.19,.19),(.19,4),(-.19,4)]; n=len(outline)
    g.v.extend([(x,y,0) for x,y in outline]+[(x,y,4) for x,y in outline])
    for k in range(1,n-1):
      g.f.append((0,k+1,k)); g.mi.append(0)
      g.f.append((n,n+k,n+k+1)); g.mi.append(0)
    for k in range(n):
      q=(k+1)%n; g.f.append((k,q,n+q,n+k)); g.mi.append(0)
    # Masonry relief sits into the continuous L-shaped core, with a small mortar joint.
    for row in range(7):
      z0=.04+row*.56; z1=z0+.50
      for i in range(4):
        offset=0 if row%2==0 else .32
        a=i+offset+.035; b=min(4,i+offset+.94)
        if b>a:
          m=random.choice([1,2]); g.box(a,b,-.205,-.155,z0,z1,m)
          g.box(-.205,-.155,i+.035,i+.965,z0,z1,m)
    for i in range(4):
      g.box((.23 if i==0 else i+.03),i+.97,-.23,.23,3.84,4.02,3)
      g.box(-.23,.23,(.23 if i==0 else i+.03),i+.97,3.84,4.02,3)
    g.box(-.23,.23,-.23,.23,3.84,4.02,3)
    return g.object(name,COL['ASSET_Modules'],bevel=.018)

def build_column(name):
    g=Geo(); g.box(-.42,.42,-.42,.42,0,.30,3); g.cylinder(0,0,.24,3.72,.31,2,8); g.box(-.40,.40,-.40,.40,3.70,4,3)
    for z in (.34,.55,3.48,3.68): g.cylinder(0,0,z,z+.12,.37,3,8)
    # eight subtle recessed vertical facets as dark narrow strips on the shaft
    for k in range(8):
      a=2*math.pi*k/8+math.pi/8; x=.305*math.cos(a); y=.305*math.sin(a)
      g.box(x-.035,x+.035,y-.035,y+.035,.70,3.42,1)
    return g.object(name,COL['ASSET_Modules'],bevel=.018)

def build_torch(name):
    g=Geo(); g.box(-.14,.14,-.12,.12,0,.68,4); g.box(-.28,.28,-.19,.19,.56,.72,4)
    g.cylinder(0,0,.68,.96,.14,4,8,r2=.20); g.cylinder(0,0,.92,1.23,.10,4,8,r2=.12)
    # stylized faceted flame, mounted to bracket, flame tip rises above cup
    g.cylinder(0,0,1.16,1.78,.14,5,6,r2=.005)
    ob=g.object(name,COL['ASSET_Modules'],origin=(0,0,0),bevel=0)
    return ob

builders={'SM_Floor_4m':build_floor,'SM_Wall_4m':build_wall,'SM_Corner_4m':build_corner,'SM_DoorArch_4m':build_arch,'SM_Column_4m':build_column,'SM_Torch':build_torch}
modules={n:fn(n) for n,fn in builders.items()}
# Roblox needs one packed UV layer inside 0–1 even when the palette uses solid colors.
for ob in modules.values():
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.004)
    bpy.ops.object.mode_set(mode='OBJECT'); ob.select_set(False)
# Recalculate each closed shell's winding after custom arch construction.
for ob in modules.values():
    bm=bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(ob.data); bm.free(); ob.data.update()
# Set bottom-centre pivot for free-standing column; floor and wall modules use a lower corner datum.
# Torch's mount point is the origin, allowing direct placement on a wall.
# Demonstration: three floor cells form a right-angle corridor with two open arch thresholds.
D=COL['ASSET_Demo']
def dup(src,name,loc,yaw=0):
    ob=src.copy(); ob.data=src.data.copy(); ob.name=name; ob.data.name=name+'Mesh'; D.objects.link(ob); ob.location=loc; ob.rotation_euler[2]=math.radians(yaw); return ob
# Layout cells; all tile edges meet exactly on 4 m increments.
for j,(x,y) in enumerate([(0,0),(0,4),(4,4)]): dup(modules['SM_Floor_4m'],f'Demo_Floor_{j+1}',(x,y,0))
# Perimeter runs: entry at west, exit at east; open interior edges create a clear L-shaped walking route.
segments=[('SM_Wall_4m',(0,0,0),0,'Demo_Wall_South'),
 ('SM_Wall_4m',(4,0,0),90,'Demo_Wall_East_Lower'),
 ('SM_DoorArch_4m',(0,0,0),90,'Demo_Entry_Arch'),
 ('SM_Wall_4m',(0,8,0),0,'Demo_Wall_North_Upper'),
 ('SM_Wall_4m',(0,4,0),90,'Demo_Wall_West_Upper'),
 ('SM_Wall_4m',(4,8,0),0,'Demo_Wall_North_Turn'),
 ('SM_Wall_4m',(4,4,0),0,'Demo_Wall_South_Turn'),
 ('SM_DoorArch_4m',(8,4,0),90,'Demo_Exit_Arch'),
]
for typ,loc,yaw,n in segments: dup(modules[typ],n,loc,yaw)
# Two wall torches, rotated so their bracket faces into the path.
for i,(x,y,yaw) in enumerate([(2,0.18,0),(4.18,6,90)]): dup(modules['SM_Torch'],f'Demo_Torch_{i+1}',(x,y,1.35),yaw)
# Sample board arranged away from the demonstration in the editable .blend.
for i,(name,ob) in enumerate(modules.items()):
    ob.location=(i*4.6,14,0); ob.hide_render=True
# Scale and naming are applied/kept exact, with no external image dependencies.
# Scene metadata for handoff.
scene['asset_scale']='1 Blender unit = 1 meter; Roblox conversion approx 3.57 studs per meter.'
scene['module_grid_m']=4
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.cycles.samples=24; scene.cycles.use_denoising=True; scene.cycles.denoiser='OPENIMAGEDENOISE'; scene.cycles.max_bounces=5
scene.view_settings.view_transform='AgX'; scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
# Studio backdrop is deliberately outside export collections.
G=Geo(); G.box(-24,26,-18,30,-.10,-.001,0); ground=G.object('Studio_Ground',COL['STUDIO'],bevel=0)
# Ground uses neutral graphite instead of asset palette index 0.
mg=mat('M_Studio_Graphite',(.045,.055,.065),.92); ground.data.materials.clear(); ground.data.materials.append(mg)
world=bpy.data.worlds.new('Studio_World') if not bpy.data.worlds else bpy.data.worlds[0]; scene.world=world; world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.095,.12,.15,1); world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.32

def point_at(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
def cam(name,loc,target,lens=52):
    cd=bpy.data.cameras.new(name); ob=bpy.data.objects.new(name,cd); COL['STUDIO'].objects.link(ob); ob.location=loc; point_at(ob,target); cd.lens=lens; scene.camera=ob; return ob
def area(name,loc,target,power,size,color):
    ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size; ld.color=color
    ob=bpy.data.objects.new(name,ld); COL['STUDIO'].objects.link(ob); ob.location=loc; point_at(ob,target); return ob
# Asset bbox covers x=-.2..8.2 y=-.2..8.2 z=0..4.2. Soft three-point setup.
area('Studio_Key',(-4,-5,12),(3,4,1.8),1900,8,(1.0,.82,.65)); area('Studio_Fill',(10,-1,8),(3,4,2),1100,7,(.64,.78,1.0)); area('Studio_Rim',(3,12,11),(3,4,2),2100,6,(1.0,.68,.4))

def render_view(filename,loc,target,lens=52):
    cam('Camera_'+filename,loc,target,lens); scene.render.filepath=os.path.join(ROOT,filename)
    bpy.ops.render.render(write_still=True)
# Three practical inspection views, all square 768 px.
render_view('front.png',(-14,2.2,6.2),(3.5,4,1.9),48)
render_view('back.png',(18,6,6.2),(4,4,1.9),48)
render_view('presentation.png',(12,-11,13),(3.8,4.0,1.8),48)
# Save editable scene with studio and module library intact.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'asset.blend'))
# Export helpers: select only the named asset geometry, excluding all studio objects/cameras/lights.
def export_glb(objects,path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_apply=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    bpy.ops.object.select_all(action='DESELECT')
# Demonstration file.
export_glb(list(D.objects),os.path.join(ROOT,'asset.glb'))
# Each module isolated at origin, preserving the 4 m datum and useful assembly pivot.
for name,ob in modules.items():
    display_location=ob.location.copy(); display_rotation=ob.rotation_euler.copy()
    ob.location=(0,0,0); ob.rotation_euler=(0,0,0)
    export_glb([ob],os.path.join(OUT,name+'.glb'))
    ob.location=display_location; ob.rotation_euler=display_rotation
# Machine-readable mesh summary.
summary=[]
for ob in list(D.objects)+list(modules.values()):
    if ob.type=='MESH':
        summary.append({'name':ob.name,'verts':len(ob.data.vertices),'faces':len(ob.data.polygons),'tris':sum(max(0,len(p.vertices)-2) for p in ob.data.polygons),'dimensions':[round(v,3) for v in ob.dimensions]})
with open(os.path.join(ROOT,'logs','geometry-summary.json'),'w') as f: import json; json.dump(summary,f,indent=2)
print('GENERATED',len(D.objects),'demo objects',len(modules),'modules',summary[:6])
