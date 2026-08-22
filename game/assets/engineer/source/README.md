# Engineer authored asset source

`build_engineer_asset.py` generates the original `../engineer.gltf` runtime
scene from the shared Project Ironwright machine-mesh helpers. The silhouette
communicates construction work through a material cradle, piston joints,
welder and assembly arms, tool heads, forge coil and warm work glows.

Stable nodes include `Chassis`, `ChassisCore`, `ChassisCornerCap`, `Sensor`,
`OpticLens`, `MaterialCradle`, `PistonJoint`, `WelderArm`, `ToolHead`,
`ForgeCoil`, `EngineerCradleLatch`, `EngineerForgeGuard`,
`EngineerToolCollarLeft`, `EngineerCableSpoolRight`,
`EngineerWeldingShieldLeft`, `EngineerClampJawRight`, and
`ProductionAssetMarker`. The asset exposes `Idle`, `Walk`, and `Work` clips for
tooling while deterministic runtime motion remains owned by the procedural
animator.

No third-party runtime asset is used. Construction authorization, physical
travel, assembly behavior, collision and save state remain unchanged.
