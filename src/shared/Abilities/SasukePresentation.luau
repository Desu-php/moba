--!strict
-- Presentation timings are independent of cooldowns and never authorize damage.
local P={}
P.Casts={Amaterasu=.55,AmaterasuWall=.55,Enton=.6,EntonMagatama=1,EntonPull=2.8,Extinguish=.4,
 SasukeFireball=4,PhoenixFlowers=4,KirinPrepare=.9,KirinBoost=.7,Kirin=2.5,
 Sharingan=.35,Mangekyo=.45,SusanooRibs=.6,Susanoo=.9,CompleteSusanoo=3,
 ChidoriSenbon=.45,ChidoriEiso=1.25,ChidoriNagashi=.6,ChidoriKatana=.5,
 SasukeGenjutsu=.55,Amenotejikara=.35,ChibakuTensei=3,ChibakuMove=.5,ChibakuDrop=.9,Aoda=.7,Garuda=.6} :: {[string]:number}
function P.radius(id:string,sourceRadius:number):number
 -- The expanding fire front reaches its full reference radius.
 return sourceRadius
end
function P.susanooSwing(phase:number,contact:number):number
 if phase<0 or phase>=1 then return 0 end
 local t=if phase<=contact then phase/math.max(.01,contact) else 1-(phase-contact)/math.max(.01,1-contact)
 return math.sin(math.clamp(t,0,1)*math.pi/2)
end
function P.flameRadius(radius:number,index:number,count:number):number
 return math.max(0,radius-.7)*math.sqrt(index/(count+1))
end
return P
