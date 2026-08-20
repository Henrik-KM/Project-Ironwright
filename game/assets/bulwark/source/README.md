# Bulwark authored asset source

`build_bulwark_asset.py` generates the original `../bulwark.gltf` runtime
scene. The builder is dependency-free so the named-node and animation contract
can be rebuilt on machines without Blender.

The asset is original Project Ironwright art: layered weathered steel, copper
oxide service plates, protected cyan optics, twin defensive weapons, a rear
shield assembly and a raised protection emitter. It uses no third-party runtime
asset and does not change the companion's collision, health, attack, movement,
autonomy or protection rules.

Stable presentation nodes include `Chassis`, `ChassisCore`,
`ChassisCornerCap`, `Sensor`, `OpticLens`, `WeaponMuzzle`,
`BulwarkShieldEmitterSpine`, and `BulwarkShieldEmitter`. The asset exposes
`Idle`, `Walk`, and `Fire` clips for tooling; the runtime procedural animator
continues to provide deterministic gait, recoil and role motion.
