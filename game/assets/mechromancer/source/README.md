# Mechromancer authored asset source

`build_mechromancer_asset.py` is the canonical runtime source. It deterministically
builds the paired `../mechromancer.gltf` and `../mechromancer.bin` package plus
the original 1024 px base-colour, tangent-space normal, packed ORM and emissive
maps. Every primitive has UV0 and explicit tangents. Running the builder twice
must produce byte-identical runtime files.

The surface maps deliberately use broad, low-frequency wear that survives
mipmapping at the isometric gameplay distance. The base map has no repeated
diagonal weave, the normal map stays close to normalized +Z with restrained XY
slopes, and per-material normal strength is capped at 0.20. Cloth, leather,
metal, skin and signal lenses remain separated by their authored material
factors and geometry rather than alias-prone micro-patterns.

`mechromancer.blend` and `build_mechromancer_blend.py` remain editable visual
references for future sculpting and skeletal work. They are not the authority
for the current runtime package because Blender export and portrait rendering
are not byte-stable across otherwise identical runs.

The deterministic package preserves:

- asset id `mechromancer.player.v1`;
- the 1.0 source scale and 1.28 runtime presentation scale;
- the unchanged 0.42 m radius / 1.75 m height gameplay capsule;
- `WeakPistol` with direct child socket `PistolMuzzle`;
- face, pack, lamp, comms, coat-tail, field-tool and progression attachment
  nodes;
- the `Idle`, `Walk`, `Fire`, `Work`, `Upgrade` and `Hit` rigid-node clips;
- zero skins, collision shapes, gameplay state or simulation ownership.

The model and all textures are original Project Ironwright art. No third-party
runtime asset is used.
