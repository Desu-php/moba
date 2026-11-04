# Visual asset provenance — 2026-11-04

Free Creator Store results were inserted into ServerStorage for inspection while Play was stopped. Only visual properties were copied into source-controlled data; imported scripts, tools, remotes, motors and gameplay logic are not used. Review copies were removed. User-added Workspace models remain intact.

| Asset | Creator | Used visual data |
| --- | --- | --- |
| [Naruto [R6], 17834725125](https://create.roblox.com/store/asset/17834725125) | enzoking1e | Hair/headband 14775158884 / texture 14775029181; face mesh 17612782429 / texture 17612784933; shirt 6764794671 and pants 3237352364 |
| [Naruto sage mode, 9690367986](https://create.roblox.com/store/asset/9690367986) | Not_Lazerman239 | Cloak 4931745611, sleeves 4931745383, strap 3069267909 / 3069268022, scroll 3106158358 / 3201801543; face decal 9449064416; shirt 7472900840 and pants 7472928447 |
| [Rasenshuriken, 4919925179](https://create.roblox.com/store/asset/4919925179) | Shisui_Uchiha8945 | Wind-blade mesh 678884274 |

Chakra particles were extracted from the already-present `Workspace.Naruto Pack.MoonAnimator2Saves.Rasengan V2.3.Part.Attachment`. The original pack's asset ID/creator was not established. Its texture IDs are 6659325109, 6603835352, 6783047753, 6732830893, 6783865443, 6732711844. No Moon Animator keyframes or scripts were executed/imported. The original pack remains in Workspace.

`CreatorVisualData`, `CreatorVisualFactory`, `ChakraParticleData` and `ChakraParticleVisual` reconstruct whitelisted visual objects. MeshPart visuals use SpecialMesh with authored size/MeshSize scaling, preserving relative offsets. Cloak face decals did not project correctly after conversion and were omitted; the cloak retains its red material. The particle layers use additive blending, bounded rate/size, no travel, and follow the palm/projectile. The golden layer is tinted cyan. They never define damage or explosion radius.

The playable R15 rig, joints and hitboxes are retained. Cosmetic parts cannot collide, query or touch. A physical avatar head remains hidden underneath exactly one visible face: the store face mesh in normal form, or a classic head with the store Sage decal in Sage form. Portraits use a separate fixed bust with an R15 Humanoid for clothing and explicit texture preloading; combat poses and effects are excluded.

Visual loading was checked in the local Studio client, including normal/Sage transition, held Rasenshuriken and its thrown impact. This is not a published-universe permission test. No assets were purchased and no place was published.
