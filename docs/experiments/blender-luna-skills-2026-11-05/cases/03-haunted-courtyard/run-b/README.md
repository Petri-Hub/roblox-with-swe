# Haunted Chapel Courtyard

Small low poly diorama built with Blender 5.2.3. The scene uses a moonlit blue palette and a warm lantern at the entrance. It includes the chapel façade and arched oak door, a flagstone approach, broken iron gate, stone well with timber winch, sparse weeds, and an earth plinth.

## Files

- `asset.blend`: editable scene, with asset and studio objects in separate collections.
- `asset.glb`: selected asset collection only; studio floor, cameras, and lights are excluded. Materials are packed as glTF material values, with no external texture dependencies.
- `generate.py`: complete procedural generator and render/export script.
- `front.png`, `back.png`, `presentation.png`: 768×768 Cycles renders.

## Regenerate

From this directory, run:

```sh
BLENDER_USER_CONFIG="$PWD/cache/config" \
BLENDER_USER_SCRIPTS="$PWD/cache/scripts" \
BLENDER_USER_DATAFILES="$PWD/cache/data" \
/workspace/blender-study/tools/blender-5.2.3-linux-x64/blender --background --python "$PWD/generate.py"
```

Cycles uses CPU rendering, denoising, and four threads. Render and export output paths are derived from the script's directory. The rear view intentionally shows the plain back wall of the chapel; the main modeled detail is on the courtyard-facing side.
