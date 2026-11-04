--!strict
local R={Speed=70,Range=110,Windup=.35,Duration=3.5,ImpactDelay=.5,Interval=.04,Radius=300,MaxRadius=500}
function R.allowed(rank:number,sage:boolean,variant:string,phase:string,now:number,ready:number,expires:number):boolean
 return rank>=3 and sage and variant=="Rasenshuriken" and phase=="Holding" and now>=ready and now<expires
end
function R.finite(x:number):boolean return x==x and math.abs(x)<1e7 end
-- war3map.j: A013 sets scale120/radius300; shared trigger increments scale2/radius5
-- BEFORE enumeration, until scale200 (40 ticks). All radii here are Warcraft units.
function R.radiusForTick(tick:number):number return 300+5*math.clamp(tick,0,40) end
function R.radius(elapsed:number):number
 if elapsed<0 or elapsed>=R.Duration then return 0 end
 return R.radiusForTick(math.floor((elapsed+1e-5)/R.Interval)+1)
end
function R.pulse(strength:number):number return math.floor((600+4*math.floor(strength))/87) end
return table.freeze(R)
