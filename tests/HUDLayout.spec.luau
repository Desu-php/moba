--!strict
local Layout=require("../src/client/Controllers/HUDLayout")
local count=0
local function check(ok: boolean,message: string) assert(ok,message); count+=1 end
for _,viewport in {{1280,720},{1920,1080},{2560,1080},{3440,1440},{1366,768}} do
 local w,h=viewport[1],viewport[2]; local s=Layout.scale(w,h)
 check((Layout.RikudoPanelY+45)*s < -40,"temporary techniques clear the unscaled message rows")
 check(Layout.RikudoTooltipY+134 < Layout.RikudoPanelY,"technique tooltip clears temporary buttons")
 check(Layout.ConsoleWidth*s<w-32,"console fits viewport")
 check(Layout.TopWidth*s<w-240,"roster clears corner core controls")
 check(math.abs(Layout.ConsoleHeight*s/h-164/1080)<.0001,"console uses stable height ratio")
 check(math.abs(60*s/h-60/1080)<.0001,"primary icons retain height ratio")
 local left=(w-Layout.ConsoleWidth*s)/2
 check(left>0 and left+Layout.ConsoleWidth*s<w,"console centered within viewport")
end
check(Layout.scale(2560,1080)==Layout.scale(1920,1080),"ultrawide does not stretch HUD")
local boxes={}
for i=1,8 do
 local x,y,size=Layout.skill(i)
 check(x>=240 and x+size<=696 and y+size<=124,"skills fit above health bar")
 for _,b in boxes do check(x>=b[1]+b[3] or b[1]>=x+size or y>=b[2]+b[3] or b[2]>=y+size,"skills do not overlap") end
 table.insert(boxes,{x,y,size})
end
for i=1,6 do local x,y=Layout.item(i); check(x>=704 and x+58<=900 and y+48<=128,"inventory fits dedicated area") end
print("HUD layout PASS: "..count.." checks")
