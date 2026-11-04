--!strict
-- Battlefield-scale chakra avatar. This is a Roblox scale, not a claimed canon height.
return table.freeze({
 Scale=4,Lift=5.0,
 BodySize=table.freeze({X=10,Y=6,Z=13}),
 BodyOffset=table.freeze({X=0,Y=3,Z=0}),BodyRadius=6.5,
 -- Ewar attack range 150 Warcraft units, measured beyond the large body.
 AttackReach=150/16+6.5,
 CameraHeight=18,CameraDistance=76,
 HitPhase=.8/1.7,
 SwipeStart=.28,SwipeEnd=.64,
})
