# Pathfinder authored asset source

`build_pathfinder_asset.py` generates the original `../pathfinder.gltf` runtime
scene from the shared Project Ironwright machine-mesh helpers. Its silhouette
is a survey instrument: asymmetric fins, twin scout optics, protected sensor
pod, tall mast, dish, hub and beacon ring.

Stable nodes include `Chassis`, `ChassisCore`, `ChassisCornerCap`, `Sensor`,
`OpticLens`, `ScoutFin`, `BeaconRing`, `ScoutOptic`, `PathfinderSensorPod`,
`PathfinderMastBraceLeft`, `PathfinderMastCollar`, `PathfinderDishRibLeft`,
`PathfinderSignalCanister`, and `ProductionAssetMarker`. The asset exposes
`Idle`, `Walk`, and `Survey` clips for tooling while deterministic runtime
motion remains owned by the procedural animator.

No third-party runtime asset is used. Route selection, formation screening,
physical travel, reduced-detail simulation, collision and save state remain
unchanged.
