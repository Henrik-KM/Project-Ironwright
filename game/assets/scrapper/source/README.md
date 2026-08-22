# Scrapper authored asset source

`build_scrapper_asset.py` generates the original `../scrapper.gltf` runtime
scene from the shared Project Ironwright machine-mesh helpers. The silhouette
is a visibly useful salvage machine: deep cargo hopper, strap and lip, paired
dismantler arms, magnetic claws, intake head, salvage drum and protected sensor.

Stable nodes include `Chassis`, `ChassisCore`, `ChassisCornerCap`, `Sensor`,
`OpticLens`, `CargoBin`, `DismantlerTool`, `SalvageDrum`, `ScrapperIntake`,
`ScrapperHopperRim`, `ScrapperDismantlerCollarLeft`, `ScrapperMagnetCoilRight`,
`ScrapperCuttingGuard`, and `ProductionAssetMarker`. The asset exposes `Idle`,
`Walk`, and `Work` clips for tooling while deterministic runtime motion remains
owned by the procedural animator.

No third-party runtime asset is used. Salvage targeting, Scrap extraction,
movement, collision, formation behavior, and autonomous work remain unchanged.
