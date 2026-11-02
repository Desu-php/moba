--!strict
-- Eligibility is not implementation readiness. Missing native costs stay absent.
export type Context = { sageReady: boolean, level: number, kcmRank: number, hagoromo: boolean, held: string }
local Catalog = {}
function Catalog.reason(id: string, c: Context): string?
 if id=="ChoOdama" then
  if c.held~="Odama" or not c.sageReady or c.level<16 then return "Eligibility" end
  return "NativeCostUnknown"
 elseif id=="Wakusei" then
  if c.kcmRank<1 or c.kcmRank>2 or (c.held~="Rasengan" and c.held~="Odama") then return "Eligibility" end
  return "NativeCostUnknown"
 elseif id=="RasenRenShuriken" or id=="MagmaRasenshuriken" then
  if c.held~="Rasenshuriken" or (id=="MagmaRasenshuriken" and not c.hagoromo) then return "Eligibility" end
  return "RangedAndMeleeGraphUnverified"
 elseif id=="BijudamaRasenshuriken" or id=="ChoBijudamaRasenshuriken" or id=="ChoBijuuRasenshuriken" or id=="ChakraKnife" then
  if c.kcmRank~=3 or not c.hagoromo then return "Eligibility" end
  return if id=="ChakraKnife" then "RegionPolicyUnknown" else "DownstreamGraphUnverified"
 end
 return "Unsupported"
end
return table.freeze(Catalog)
