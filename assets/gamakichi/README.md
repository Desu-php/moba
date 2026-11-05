# Gamakichi Blender asset

Locally authored stylized adaptation: orange toad, violet markings, slit eyes,
open indigo vest, broad muzzle and tanto. No downloaded game rip or third-party
scripts. Creator Store candidates 2831683674, 130025922280157, 133034591,
111552783263751 and 12495215401 did not provide a usable animated Gamakichi rig.
The RenderHub Gamakichi listing is an STL print, not an animated game character.

`Gamakichi.blend` is the editable source. `create_gamakichi.py` reproduces it in
Blender 5.2, including the 17,937-triangle skinned mesh and 16-bone skeleton.
`Gamakichi.fbx` is the rest mesh; `Idle.fbx`, `Walk.fbx`, `Attack.fbx`, `Oil.fbx`
are individual animation exports. Attack contact peaks at 0.5 seconds, matching
the server damage point. `preview.png` is the neutral Blender render.

Imported through Studio's 3D importer into the current user's inventory:
mesh `74420010518422`, texture `116162326036621`. The normalized imported
template is `src/shared/GamakichiRig.rbxm`; it includes the skin bind data.
The mesh was normalized to 1/100 of the import size, with Root at the origin.
`imported.json` records its bind frames. The game scales width to 5/7 studs;
visual bones never change collision or damage range.

`export_runtime.py` retargets Blender world poses (`clips.json`, `rig.json`)
to the actual imported bind frames and generates `GamakichiClips.luau`.
The client interpolates those authored bone poses with short blending, rather
than relying on separate published animation permissions. These are editable
Blender actions, not the previous moving Roblox primitive construction.

Visuals and skinning were checked in local Studio. Access to the uploaded mesh
and texture must also be tested when publishing under a different group/owner.
The result is a custom stylized model, not a claim of anime-production fidelity.
