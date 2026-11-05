# Aoda

Original Blender-authored snake for the Sasuke summon. One continuous body,
31 bones, 12,952 triangles, and a 1024 px painted scale atlas. No third-party
mesh or animation is used. `Aoda.blend` contains the editable source and actions.

`create_aoda.py` produces the FBX mesh, Idle / Slither / Bite / Coil actions,
texture and world-space pose samples. Import `Aoda.fbx` in Studio at scale 0.01.
Surface normals must face outward; Blender's two-sided preview can hide errors.

The normalized imported template is `src/shared/AodaRig.rbxm` and preserves skin
binding. Mesh asset: `129245367138974`; texture: `120376351778540`.
`imported.json` records its bind frames with Root at the origin.

Run `export_runtime.py` after regenerating actions. It retargets Blender poses
to the imported bind pose and writes quaternion CFrames into four separate
modules, each below Studio's 200,000-character Source limit. Animation asset
publication is not required. Runtime blends clips on the client and scales
the bite's reach to the server-selected target. Damage is resolved after a
0.22 second windup, with fresh range, line-of-sight and life checks.

Young and adult summons share the mesh at 0.72 / 1.0 scale. The root collider
and combat stats remain independent of the cosmetic skin. `Coil` supports
both enemy constriction and allied guard; interruption returns to idle.

Validation: targeted build/type checks, existing Aoda/Enton live regression,
`tests/aoda-model-runtime.server.luau`, and visual checks in Studio for the
coil, moving spine and open-jaw bite. Runtime tests are temporary server
scripts in Studio Play and are not included in the released place.
