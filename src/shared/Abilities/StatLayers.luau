--!strict
-- Owned additive layers compose over current permanent stats; never snapshot/restore them.
export type Modifier={health: number,armor: number,attack: number,speed: number}
export type Layers={[string]: Modifier}
local L={}
function L.sum(layers: Layers): Modifier
 local result={health=0,armor=0,attack=0,speed=0}
 for _,m in layers do result.health+=m.health; result.armor+=m.armor; result.attack+=m.attack; result.speed+=m.speed end
 return result
end
function L.set(layers: Layers,key: string,modifier: Modifier?)
 if modifier then
  for _,v in {modifier.health,modifier.armor,modifier.attack,modifier.speed} do assert(v==v and math.abs(v)<math.huge,"Invalid stat modifier") end
  layers[key]={health=modifier.health,armor=modifier.armor,attack=modifier.attack,speed=modifier.speed}
 else layers[key]=nil end
end
return L
