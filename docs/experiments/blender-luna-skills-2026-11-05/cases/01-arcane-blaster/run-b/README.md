# Arcane Blaster

Low-poly hand blaster for a science-fantasy game. The model uses a forged titanium receiver, electrum trim, dark grip scales, a faceted blue arc crystal and a glowing muzzle bore. Both sides carry matching armor details, vents, controls and fasteners.

## Files

- `asset.blend` — renderable Blender scene with studio cameras, lights and floor.
- `asset.glb` — model and materials only; the studio collection is excluded.
- `front.png`, `back.png`, `presentation.png` — 768 × 768 Cycles renders.
- `generate.py` — complete procedural scene and export script.

## Regenerate

Run with Blender 5.2.3 in background mode:

```sh
/path/to/blender -b --python generate.py
```

The script uses Cycles CPU with four threads and writes outputs next to itself. No external textures are needed.
