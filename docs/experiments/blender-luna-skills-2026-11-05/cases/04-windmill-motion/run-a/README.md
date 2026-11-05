# Windmill island

Stylized low-poly windmill and rocky grass-topped island built in Blender 5.2.3. The model includes a tapered tower, terracotta roof, front door and windows, a four-blade rotor, rear picket fencing, and three animated grass clumps. Materials are authored with Principled BSDF base colors and roughness; there are no external image or HDRI dependencies.

## Files

- `asset.blend` — editable Blender scene. The `ASSET_Windmill_Island` collection contains export geometry and animation. `PRESENTATION` contains the studio floor, cameras, and lights.
- `asset.glb` — selected asset collection only, with rotor and grass actions; presentation objects are excluded.
- `generate.py` — reproducible scene, still render, and GLB generation script. Runs with Blender 5.2.3 in background mode and Cycles CPU (4 threads).
- `front.png`, `back.png`, `presentation.png` — 768 × 768 construction views.
- `motion-01.png`, `motion-16.png`, `motion-32.png` — 768 × 768 samples of the animated presentation camera.

## Animation

The scene is set to 24 fps. The loop spans frames 1–48 (two seconds), with frame 49 repeating the frame-1 pose to close the interpolation seam; omit that duplicate when playing the loop in a runtime. `Windmill_Rotor_Loop` rotates the four blades one full revolution, and three `Grass_Sway_Loop_*` actions sway the vegetation.

## Rebuild

From this directory, run:

```sh
BLENDER_USER_CONFIG="$PWD/cache/config" \
BLENDER_USER_SCRIPTS="$PWD/cache/scripts" \
BLENDER_USER_DATAFILES="$PWD/cache/data" \
/path/to/blender-5.2.3/blender -b --factory-startup --python-exit-code 1 --python generate.py
```

`logs/` contains the Blender generation, export, visual review, and mesh-QA results. The final asset-QA render profile passed with zero errors. Its remaining warnings are the intentional contact between window panes and their trim, and the island's underside at z = -0.26 m because the deliverable is a floating diorama.
