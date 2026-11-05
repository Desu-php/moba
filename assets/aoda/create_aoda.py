"""Original continuous, UV-painted snake mesh and editable Blender bone actions."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix
OUT=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.fps=30
parts=[]
colors=[(.18,.30,.43,1),(.55,.65,.57,1),(.012,.018,.025,1),(.40,.68,.12,1),(.90,.86,.64,1),(.23,.055,.075,1),(.55,.15,.20,1),(.9,.96,.84,1)]
materials=[]
for i,col in enumerate(colors):
 m=bpy.data.materials.new('Palette'+str(i));m.diffuse_color=col;materials.append(m)
def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def mesh_obj(name,verts,faces,mat=0,rigid=''):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 o=bpy.data.objects.new(name,me);scene.collection.objects.link(o);me.materials.append(materials[mat])
 o['rigid']=rigid;parts.append(o)
 for p in me.polygons:p.use_smooth=True
 return o
def ell(name,loc,scale,mat,rigid):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale;active(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 o.data.materials.append(materials[mat]);o['rigid']=rigid;parts.append(o)
 for p in o.data.polygons:p.use_smooth=True
 return o
def tube(name,points,radii,mat,rigid,sides=10):
 v=[];f=[]
 for i,point in enumerate(points):
  p=Vector(point);direction=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
  direction.normalize();a=direction.cross(Vector((0,1,0)))
  if a.length<.01:a=direction.cross(Vector((1,0,0)))
  a.normalize();b=direction.cross(a)
  for j in range(sides):
   theta=j*math.tau/sides;v.append(p+radii[i]*(a*math.cos(theta)+b*math.sin(theta)))
 for i in range(len(points)-1):
  for j in range(sides):
   n=i*sides+j;k=i*sides+(j+1)%sides;f.append((n,k,k+sides,n+sides))
 f.append(tuple(range(sides-1,-1,-1)));f.append(tuple((len(points)-1)*sides+j for j in range(sides)))
 return mesh_obj(name,v,f,mat,rigid)

# One connected surface from the wedge-shaped muzzle through neck to the pointed tail.
profiles=[(-3.6,.06,.15,1.23),(-3.45,.72,.34,1.35),(-3.1,1.08,.48,1.5),(-2.5,1.42,.60,1.6),(-1.7,1.64,.67,1.65),(-.8,1.39,.64,1.5),(0,1.05,.84,1.25)]
for i in range(1,97):
 y=i/4;t=y/24;r=1.12*(1-t**1.9)**.75+.035
 profiles.append((y,r,r*.83,max(.16,r*.85)))
verts=[];faces=[];sides=28
for y,rx,rz,z in profiles:
 for j in range(sides):
  a=j*math.tau/sides;x=math.sin(a)*rx;zz=z+math.cos(a)*rz
  if y<-.6:zz+=.10*math.sin(a)**2*math.exp(-((y+1.8)/.7)**2)
  verts.append((x,y,zz))
for i in range(len(profiles)-1):
 for j in range(sides):
  n=i*sides+j;k=i*sides+(j+1)%sides;faces.append((n,n+sides,k+sides,k))
faces.append(tuple(range(sides-1,-1,-1)));faces.append(tuple((len(profiles)-1)*sides+j for j in range(sides)))
body=mesh_obj('Aoda_ContinuousSkin',verts,faces);uv=body.data.uv_layers.new(name='UVMap')
for p in body.data.polygons:
 for li in p.loop_indices:
  index=body.data.loops[li].vertex_index;ring,j=divmod(index,sides)
  u=j/sides
  js=[body.data.loops[k].vertex_index%sides for k in p.loop_indices]
  if max(js)-min(js)>sides/2 and j==0:u=1
  uv.data[li].uv=(u,.16+.83*(profiles[ring][0]+3.6)/27.6)
body['body_uv']=True
# Lower jaw, mouth lining, curved fangs, inset eyes and nostril pits.
ell('LowerJaw',(0,-1.85,.91),(1.36,1.64,.25),1,'Jaw')
ell('DarkMouth',(0,-1.9,1.12),(1.26,1.49,.07),5,'Jaw')
for side in [-1,1]:
 # Eye sits into cheek, with a raised anatomical brow, not a floating sphere.
 ell('EyeSocket',(side*1.35,-1.95,1.92),(.085,.40,.28),2,'Head')
 ell('JadeIris',(side*1.42,-1.97,1.94),(.055,.28,.21),3,'Head')
 ell('SlitPupil',(side*1.47,-2.01,1.94),(.018,.04,.185),2,'Head')
 ell('EyeGlint',(side*1.485,-2.1,2.04),(.008,.035,.035),7,'Head')
 tube('Brow',[(side*1.15,-2.4,1.98),(side*1.35,-2.08,2.10),(side*1.36,-1.73,2.12),(side*1.23,-1.48,2.08)],[.07,.09,.09,.05],0,'Head')
 ell('Nostril',(side*.73,-3.18,1.65),(.10,.055,.065),2,'Head')
 tube('MouthSeam',[(side*.18,-3.45,1.12),(side*.8,-3.22,1.12),(side*1.24,-2.7,1.11),(side*1.49,-1.88,1.13),(side*1.17,-.6,1.18)],[.035]*5,2,'Head')
 tube('UpperFang',[(side*.9,-2.8,1.18),(side*.91,-2.88,.85),(side*.85,-2.96,.49),(side*.76,-3.06,.34)],[.15,.13,.075,.005],4,'LeftFang' if side<0 else 'RightFang',12)
 for j in range(4):
  y=-1.1-j*.34;x=side*(1.10+math.sin(j/4*math.pi)*.1)
  tube('SmallTooth',[(x,y,1.15),(x*.97,y-.06,1.38)],[.07,.005],4,'Jaw',8)
tube('TongueStem',[(0,-2.6,1.19),(0,-3.4,1.18),(0,-4.05,1.12)],[.055,.055,.035],6,'Tongue',8)
for side in [-1,1]:tube('ForkedTongue',[(0,-4.05,1.12),(side*.23,-4.55,1.15)],[.035,.003],6,'Tongue',8)

# 25 spine stations blend the entire tube; independent children allow smooth coil poses.
bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0));rig=bpy.context.object;rig.name='AodaRig'
eb=rig.data.edit_bones;eb.remove(eb[0]);bones={}
def bone(name,head,tail,parent='Root'):
 b=eb.new(name);b.head=head;b.tail=tail
 if parent:b.parent=eb[parent]
 bones[name]=(Vector(head),Vector(tail))
bone('Root',(0,0,0),(0,0,1),None)
for i in range(25):bone('Spine%02d'%i,(0,i,1.0),(0,i+1,1.0))
bone('Head',(0,0,1.0),(0,1,1.0))
bone('Jaw',(0,-.35,1.05),(0,-1.35,1.05),'Head')
bone('Tongue',(0,-2.6,1.19),(0,-1.6,1.19),'Head')
for side,name in [(-1,'LeftFang'),(1,'RightFang')]:bone(name,(side*.9,-2.8,1.18),(side*.9,-1.8,1.18),'Head')
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
 for name in bones:o.vertex_groups.new(name=name)
 for v in o.data.vertices:
  rigid=o.get('rigid','')
  if rigid:o.vertex_groups[rigid].add([v.index],1,'REPLACE')
  else:
   y=v.co.y
   if y<-.1:o.vertex_groups['Head'].add([v.index],1,'REPLACE')
   else:
    q=max(0,min(24,y));a=int(q);b=min(24,a+1);t=q-a
    o.vertex_groups['Spine%02d'%a].add([v.index],1-t,'REPLACE')
    if b!=a:o.vertex_groups['Spine%02d'%b].add([v.index],t,'REPLACE')
 if not o.get('body_uv'):
  uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
  idx=materials.index(o.data.materials[0])
  for p in o.data.polygons:
   for li in p.loop_indices:uv.data[li].uv=((idx+.5)/8,.06)
active(body)
for o in parts:o.select_set(True)
bpy.ops.object.join();mesh=body;mesh.name='AodaSkin';mesh.parent=rig
# Roblox culls backfaces; orient every closed surface outward before export.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
mod=mesh.modifiers.new('Continuous serpent skin','ARMATURE');mod.object=rig

# Painted scale atlas: staggered diamond scales, dorsal variation and broad ventral scutes.
N=1024;image=bpy.data.images.new('AodaScales',width=N,height=N,alpha=False)
pixels=[]
for y in range(N):
 v=y/(N-1)
 for x in range(N):
  u=x/(N-1)
  if v<.14:col=colors[min(7,int(u*8))]
  else:
   row=(v-.16)/.83*115;iy=math.floor(row);fy=row-iy
   colx=u*32+(iy%2)*.5;ix=math.floor(colx);fx=colx-ix
   curve=.12+.76*(1-(2*fx-1)**2)
   groove=max(0,1-abs(fy-curve)/.055)
   lift=(1-.28*groove)*(.94+.06*math.sin(fy*math.pi))
   variation=math.sin(ix*12.3+iy*7.7)*.012
   if .34<u<.66:
    shade=.80+.18*math.sin(fy*math.pi);col=(.52*shade,.61*shade,.55*shade,1)
   else:
    col=((.16+variation)*lift,(.29+variation)*lift,(.43+variation)*lift,1)
  pixels.extend(col)
image.pixels.foreach_set(pixels);image.filepath_raw=str(OUT/'AodaScales.png');image.file_format='PNG';image.save()
mat=bpy.data.materials.new('AodaPaint');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.58
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
mesh.data.materials.clear();mesh.data.materials.append(mat)
for p in mesh.data.polygons:p.material_index=0
mesh.data.calc_loop_triangles();print('TRIANGLES',len(mesh.data.loop_triangles),flush=True)

clips={}
def frame_at(pos,tangent):
 y=Vector(tangent).normalized();x=y.cross(Vector((0,0,1))).normalized();z=x.cross(y)
 return Matrix(((x.x,y.x,z.x,pos[0]),(x.y,y.y,z.y,pos[1]),(x.z,y.z,z.z,pos[2]),(0,0,0,1)))
def path(y,t,kind):
 taper=1-math.exp(-max(0,y)/3)
 amp=.9 if kind=='Slither' else .38
 x=amp*math.sin(y*.48-t*math.tau)*taper
 z=1.0+.14*math.cos(t*math.tau)*math.exp(-max(0,y)/4)
 if kind=='Bite':
  q=t*.8;strike=math.sin(min(1,q/.22)*math.pi/2) if q<=.22 else math.cos(min(1,(q-.22)/.58)*math.pi/2)**2
  y-=8*strike*math.exp(-max(0,y)/5);z+=1.1*strike*math.exp(-max(0,y)/3)
 return Vector((x,y,z))
def coil(y,t):
 a=y/3.5
 return Vector((3.1*math.sin(a),-3.1*math.cos(a),3.2-y*.10+.06*math.sin(t*math.tau)))
def pose(t,kind):
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
 fn=coil if kind=='Coil' else lambda y,t:path(y,t,kind)
 for i in range(25):
  pos=fn(i,t);tangent=fn(i+.05,t)-fn(i-.05,t)
  rig.pose.bones['Spine%02d'%i].matrix=frame_at(pos,tangent)
 rig.pose.bones['Head'].matrix=frame_at(fn(0,t),fn(.05,t)-fn(-.05,t))
 jaw=rig.pose.bones['Jaw'];jaw.rotation_mode='XYZ'
 if kind=='Bite':
  q=t*.8;jaw.rotation_euler.x=.85*math.sin(min(1,q/.22)*math.pi/2) if q<.22 else .85*max(0,1-(q-.22)/.16)
 else:jaw.rotation_euler.x=.025+.025*math.sin(t*math.tau)
 jaw.rotation_euler.x *= -1
 for name in ['LeftFang','RightFang']:
  fang=rig.pose.bones[name];fang.rotation_mode='XYZ';fang.rotation_euler.x=1.25*(1-min(1,abs(jaw.rotation_euler.x)/.6))
 tongue=rig.pose.bones['Tongue'];tongue.scale=(1,1,1)
 tongue.location.y= .8 if kind=='Bite' else .9-.8*max(0,math.sin(t*math.tau*2))**6
 bpy.context.view_layer.update()
def make_clip(name,frames):
 rig.animation_data_create();act=bpy.data.actions.new(name);act.use_fake_user=True;rig.animation_data.action=act
 clips[name]={'duration':frames/30,'frames':[]}
 for f in range(frames+1):
  pose(f/frames,name)
  for p in rig.pose.bones:
   p.rotation_mode='QUATERNION';p.keyframe_insert('rotation_quaternion',frame=f+1);p.keyframe_insert('location',frame=f+1);p.keyframe_insert('scale',frame=f+1)
  clips[name]['frames'].append({p.name:[round(p.matrix[i][j],6) for i in range(3) for j in range(4)] for p in rig.pose.bones})
 scene.frame_start=1;scene.frame_end=frames+1
 active(mesh);rig.select_set(True)
 bpy.ops.export_scene.fbx(filepath=str(OUT/(name+'.fbx')),use_selection=True,object_types={'MESH','ARMATURE'},add_leaf_bones=False,axis_forward='-Z',axis_up='Y',bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,path_mode='COPY',embed_textures=True)
 return act
actions=[make_clip('Idle',60),make_clip('Slither',42),make_clip('Bite',24),make_clip('Coil',60)]
rig.animation_data.action=None
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update();active(mesh);rig.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'Aoda.fbx'),use_selection=True,object_types={'MESH','ARMATURE'},add_leaf_bones=False,axis_forward='-Z',axis_up='Y',bake_anim=False,path_mode='COPY',embed_textures=True)
(OUT/'clips.json').write_text(json.dumps(clips,separators=(',',':')))
(OUT/'rig.json').write_text(json.dumps({n:{'rest':[round(rig.data.bones[n].matrix_local[i][j],6) for i in range(3) for j in range(4)]} for n in bones},indent=2))

def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
pose(.1,'Coil')
bpy.ops.object.camera_add(location=(13,-18,13));cam=bpy.context.object;aim(cam,(0,0,1.3));cam.data.type='ORTHO';cam.data.ortho_scale=12.8;scene.camera=cam
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.06,.085,.12,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for pos,power,size in [((3,-8,12),1800,8),((-7,-1,7),1600,7),((2,7,10),2200,6)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;aim(o,(0,0,2))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.2));floor=bpy.context.object;floor.name='PreviewFloor'
fm=bpy.data.materials.new('Backdrop');fm.diffuse_color=(.07,.09,.12,1);floor.data.materials.append(fm)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Aoda.blend'))
scene.render.filepath=str(OUT/'preview.png');bpy.ops.render.render(write_still=True)
print('AODA_READY',flush=True)
