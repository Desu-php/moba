--!strict
-- War-inspired MOBA layout, not a literal reconstruction of canonical geography.
local Plan = { Version = 3, PartBudget = 1400, Width = 820, Depth = 620, LaneWidth = 28 }
export type Point = { number }
export type Piece = {
	name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number,
	yaw: number, palette: string, shape: string, material: string, solid: boolean, pitch: number?,
}
Plan.Routes = {
	Top = { {-330,-28}, {-300,-84}, {-276,-158}, {-230,-210}, {-156,-218}, {-86,-192}, {0,-204}, {86,-192}, {156,-218}, {230,-210}, {276,-158}, {300,-84}, {330,-28} },
	Mid = { {-330,0}, {-268,0}, {-202,24}, {-124,30}, {-64,8}, {0,0}, {64,-8}, {124,-30}, {202,-24}, {268,0}, {330,0} },
	Bottom = { {-330,28}, {-300,84}, {-276,158}, {-230,210}, {-156,218}, {-86,192}, {0,204}, {86,192}, {156,218}, {230,210}, {276,158}, {300,84}, {330,28} },
} :: { [string]: { Point } }
Plan.Paths = {
	West = { {-156,-218}, {-164,-166}, {-160,-112}, {-144,-52}, {-124,30}, {-146,86}, {-160,144}, {-156,218} },
	East = { {156,-218}, {160,-144}, {146,-86}, {124,-30}, {144,52}, {160,112}, {164,166}, {156,218} },
	North = { {-160,-112}, {-112,-126}, {-52,-112}, {16,-100}, {84,-112}, {160,-144} },
	South = { {-160,144}, {-84,112}, {-16,100}, {52,112}, {112,126}, {160,112} },
} :: { [string]: { Point } }
Plan.Camps = { {-110,-138}, {110,138}, {-110,138}, {110,-138} }
function Plan.Distance(x: number, z: number, route: { Point }): number
	local best=math.huge
	for i=1,#route-1 do
		local a,b=route[i],route[i+1];local dx,dz=b[1]-a[1],b[2]-a[2]
		local t=math.clamp(((x-a[1])*dx+(z-a[2])*dz)/(dx*dx+dz*dz),0,1)
		best=math.min(best,math.sqrt((x-a[1]-dx*t)^2+(z-a[2]-dz*t)^2))
	end
	return best
end
function Plan.Clear(x: number,z: number,radius: number): boolean
	for _,route in Plan.Routes do if Plan.Distance(x,z,route)<Plan.LaneWidth/2+radius+5 then return false end end
	for _,route in Plan.Paths do if Plan.Distance(x,z,route)<10+radius+3 then return false end end
	for _,p in Plan.Camps do if (x-p[1])^2+(z-p[2])^2<(32+radius)^2 then return false end end
	return math.abs(x)<290
end
function Plan.Build(): { Piece }
	local pieces: { Piece }={}
	local function add(name: string,x: number,y: number,z: number,sx: number,sy: number,sz: number,palette: string,shape: string?,yaw: number?,material: string?,solid: boolean?)
		table.insert(pieces,{name=name,x=x,y=y,z=z,sx=sx,sy=sy,sz=sz,palette=palette,shape=shape or "Block",yaw=yaw or 0,material=material or "Slate",solid=solid==true})
	end
	add("BackdropBedrock",0,-19.05,0,1010,40,810,"DarkRock",nil,nil,"Rock")
	local function branch(name: string,x: number,y: number,z: number,bx: number,by: number,bz: number,width: number,palette: string)
		local dx,dy,dz=bx-x,by-y,bz-z;local horizontal=math.sqrt(dx*dx+dz*dz)
		add(name,(x+bx)/2,(y+by)/2,(z+bz)/2,width,math.sqrt(horizontal^2+dy^2),width,palette,"Cylinder",math.deg(math.atan2(dx,dz)),"Wood")
		pieces[#pieces].pitch=math.deg(math.atan2(horizontal,dy))
	end
	local function tree(id: string,x: number,z: number,index: number,inside: boolean?)
		local h=20+index%4*3;local burnt=x>40
		add(id.."Trunk",x,1+h/2,z,3.8,h,3.8,if burnt then "Ash" else "Bark","Cylinder",nil,"Wood",inside)
		if not burnt or index%3~=0 then
			add(id.."Crown",x,h+1,z,18,12,17,if burnt then "DarkLeaf" else "Leaf","Ball",index*17,"Grass")
			add(id.."CrownTip",x+2,h+7,z,12,9,12,if burnt then "DarkLeaf" else "LightLeaf","Ball",nil,"Grass")
		else add(id.."BrokenBranch",x+3,h-3,z,11,2,2,"Ash",nil,32,"Wood") end
	end
	for side=-1,1,2 do
		for i=0,26 do tree("Forest"..side.."_"..i,-390+i*30,side*(327+i%2*14),i) end
		for i=0,15 do
			local x=-410+i*54;local h=35+i%4*13
			add("Ridge"..side.."_"..i,x,h/2-3,side*370,78,h,64,if side<0 then "SandRock" else "Rock","Ball",i%3*13,"Rock")
			add("RidgeCap"..side.."_"..i,x-8,h*.68,side*370,48,h*.55,38,if side<0 then "SandRock" else "Moss","Ball",i%3*13,"Rock")
		end
	end
	-- Jungle islands leave a broad, tested corridor around every road and camp.
	for ix=-8,8 do for iz=-9,9 do
		local x=ix*32+(iz%2)*8;local z=iz*30
		if math.abs(z)>48 and z>-238 and Plan.Clear(x,z,12) then
			tree("Jungle"..ix.."_"..iz,x,z,math.abs(ix*7+iz),true)
			add("FernBed"..ix.."_"..iz,x,1.08,z,17,.1,15,"Moss","Ball",ix*21,"Grass")
			if (ix+iz)%3==0 then add("Outcrop"..ix.."_"..iz,x+3,5,z+3,12,8,10,"Rock","Ball",ix*13,"Rock",true) end
		end
	end end
	-- Traversable scorched battlefield: visual crater rims cannot trap units.
	for i=0,4 do
		local x=-176+i*88;local z=-270+(i%2)*8
		add("CraterFloor"..i,x,1.04,z,56,.08,42,"Scorch","Ball",nil,"Ground")
		for j=0,11 do
			local a=j*math.pi/6
			add("CraterRim"..i.."_"..j,x+math.cos(a)*28,1.7,z+math.sin(a)*21,9,2.5,7,"SandRock","Ball",j*30,"Rock")
		end
	end
	local river: {Point}={{-18,-310},{0,-204},{18,-100},{0,0},{-18,100},{0,204},{18,310}}
	for i=1,#river-1 do
		local a,b=river[i],river[i+1];local dx,dz=b[1]-a[1],b[2]-a[2]
		add("River"..i,(a[1]+b[1])/2,1.055,(a[2]+b[2])/2,21,.08,math.sqrt(dx*dx+dz*dz)+2,"Water",nil,math.deg(math.atan2(dx,dz)),"Glass")
	end
	for _,z in {-204,0,204} do
		add("BridgeDeck"..z,0,1.28,z,42,.08,33,"Bark",nil,nil,"WoodPlanks")
		for side=-1,1,2 do
			add("BridgeEdge"..z.."_"..side,0,1.8,z+side*17.5,43,1,.9,"Rock")
			for _,x in {-21,21} do add("BridgePost"..z.."_"..side.."_"..x,x,3.2,z+side*18,2,4,2,"Rock") end
		end
		for i=-8,8 do add("BridgeBoard"..z.."_"..i,i*2.4,1.35,z,.12,.04,32.8,"Ash",nil,nil,"Wood") end
	end
	-- Allied supply camp, command gates and cloth banners.
	for side=-1,1,2 do
		for i=0,2 do
			local x=-380+i*18;local z=side*(90+i%2*34)
			add("CampTent"..side..i,x,5,z,23,8,22,"Canvas",nil,nil,"Fabric",true)
			add("CampRoof"..side..i,x,11,z,28,5,27,"Roof","Ball",nil,"Fabric")
			add("CampDoor"..side..i,x+11.6,4.2,z,.2,6,7,"DarkRock")
			add("Supplies"..side..i,x+15,3,z+15,5,4,5,"Bark",nil,nil,"WoodPlanks",true)
		end
		add("AllianceGatePost"..side,-392,12,side*23,5,22,5,"Bark",nil,nil,"Wood")
		add("AllianceBanner"..side,-388.9,15,side*23,.3,12,5,"Alliance",nil,nil,"Fabric")
		add("AllianceBannerPlate"..side,-388.6,17,side*23,.2,3,3,"Paper")
	end
	add("AllianceGateLintel",-392,25,0,8,4,55,"Roof",nil,nil,"Wood")
	for i=0,6 do
		local z=-126+i*42
		add("EnemyWall"..i,390,6,z,12,10,29,"DarkRock",nil,i%2*8,"Rock")
		add("EnemyRoot"..i,400,15,z,7,28,8,"Bone","Cylinder",i*11,"Wood")
		add("EnemySeal"..i,383.8,8,z,.3,7,4,"Enemy",nil,nil,"Fabric")
	end
	add("EnemyGateRib",392,32,0,10,6,58,"Ash",nil,nil,"Wood")
	add("DivineTreeTrunk",452,51,0,40,100,42,"Bone","Cylinder",nil,"Wood")
	branch("DivineUpperTrunk",452,82,0,460,133,5,26,"Bone")
	for i=0,9 do
		local a=i*math.pi/5
		local dx,dz=math.cos(a),math.sin(a)
		branch("DivineBark"..i,452+dx*17,10,dz*17,454+dx*14,91,dz*14,7,"Ash")
		branch("DivineRoot"..i,452+dx*15,20,dz*15,452+dx*42,5,dz*42,13,"Bone")
		branch("DivineRootTip"..i,452+dx*42,5,dz*42,452+dx*65,1,dz*65,7,"Bone")
		branch("DivineBranch"..i,452+dx*12,78+i%3*6,dz*12,452+dx*52,115+i%3*6,dz*52,10,"Bone")
		branch("DivineTwig"..i,452+dx*52,115+i%3*6,dz*52,452+dx*68,128+i%3*6,dz*68,5,"Ash")
		add("DivineCrown"..i,452+dx*55,129+i%3*6,dz*55,58,21,42,"DarkLeaf","Ball",-i*36,"Grass")
	end
	add("DivineBud",460,150,5,27,37,27,"Enemy","Ball",nil,"Grass")
	assert(#pieces<=Plan.PartBudget,"Map scenery exceeds part budget")
	return pieces
end
return table.freeze(Plan)
