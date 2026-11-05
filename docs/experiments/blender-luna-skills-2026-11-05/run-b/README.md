# Oak watchtower

A low-poly fantasy watchtower built from splayed oak posts, crossed braces, an open-railed platform, a full-width stair flight and a steep four-sided shingle roof. Warm oak, dark aged timber, blue-green cedar and forged iron separate the main materials. The stair opening aligns with the upper platform, and stone pads ground the four posts.

## Reproduce

Run the included generator with Blender 5.2.3:

```sh
/workspace/blender-study/tools/blender-5.2.3-linux-x64/blender --background --python generate_tower.py
```

The script writes `tower.blend`, `tower.glb`, and the front, back and perspective PNG renders beside itself. Rendering uses Cycles on CPU with four threads.
