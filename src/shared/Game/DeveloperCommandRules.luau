--!strict
local Rules={}
export type Command={name: string, level: number?, enabled: boolean?}
function Rules.parse(raw: any): Command?
 if type(raw)~="string" or #raw>100 then return nil end
 local words={} for word in string.lower(raw):gmatch("%S+") do table.insert(words,word) end
 if words[1]=="/dev" then table.remove(words,1) end
 local name=words[1]
 if name=="level" and #words==2 then
  local n=tonumber(words[2]);if not n or n~=n or n%1~=0 or n<1 or n>30 then return nil end
  return {name=name,level=n}
 elseif name=="nocd" and #words==2 and (words[2]=="on" or words[2]=="off") then return {name=name,enabled=words[2]=="on"}
 elseif #words==1 and (name=="help" or name=="refresh" or name=="learnall" or name=="solo") then return {name=name} end
 return nil
end
return Rules
