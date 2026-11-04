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

## Additional transformations — 2026-11-04

| Asset | Creator | Integration |
| --- | --- | --- |
| [Naruto (KCM2), 87414494635132](https://create.roblox.com/store/asset/87414494635132) | r_3idx | Visible gold cloak, black markings, limbs and hair/headband; adapted from R6 offsets to the existing R15 body. Clothes 7923921567 / 7923927930. Hidden alternative meshes and imported scripts excluded. |
| [Naruto 6 Paths KCM, 9477586634](https://create.roblox.com/store/asset/9477586634) | lilpumpv5656 | Rikudo hair placement, face 9477576334, clothes 6510073285 / 6510069460. Combined with the cloak geometry above and nine original spherical Truth-Seeking Orbs. |
| [Naruto Kurama Avatar, 7284357669](https://create.roblox.com/store/asset/7284357669) | vrdude243 | Forty fox meshes, including all nine segmented tails and the separately parented right paw. Scaled to 0.075 of the source size; embedded humanoid, scripts, sounds and starter character excluded. |

`NarutoFormVisualData` stores only whitelisted mesh/texture/color/transform data. KCM and Rikudo have one classic visible face; full Kurama hides the humanoid visuals and uses one fox costume. The existing server-owned body collider and gameplay stats are preserved. Fox tail sway/breathing/stride are local cosmetic weld motion, with no hitbox movement. The camera pulls back in fox form, and the portrait frames the fox face. All changes restore when leaving the form. Asset access was validated locally, not in a published universe.
