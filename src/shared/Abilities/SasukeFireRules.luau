--!strict
-- Naruto Legend FIX20.3: Katon_Act runs every .04 s; Phoenix fires every fifth tick.
local F={Tick=.04,Duration=4,Warmup=1,ManaPerSecond=25,MinimumMana=10,
 PhoenixInterval=.2,PhoenixCount=20,PhoenixSpread=25,CloseDistance=300,
 BurnDuration=10,ControlDuration=4,CoatingDuration=20}
function F.radius(age:number):number return 300+200*math.clamp(age/.5,0,1) end
function F.front(age:number):number return math.min(786,150+550*math.max(0,age)) end
function F.phoenixDamage(rank:number,agility:number,distance:number):number
 -- Keep the tooltip's AGI scaling; do not reproduce JASS's R2I(.2) bug.
 return (30+10*rank+.2*agility)*(if distance<F.CloseDistance then .4 else 1)
end
function F.phoenixDue(age:number):number return math.clamp(math.floor((age+1e-6)/F.PhoenixInterval),0,F.PhoenixCount) end
function F.inBreath(along:number,side:number):boolean
 for _,circle in {{100,100},{300,300},{675,450}} do
  if (along-circle[1])^2+side^2<=circle[2]^2 then return true end
 end
 return false
end
return F
