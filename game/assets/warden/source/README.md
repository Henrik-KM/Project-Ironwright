# Warden authored asset source

`build_warden_asset.py` generates the original `../warden.gltf` runtime scene
using the shared Project Ironwright machine-mesh helpers. The model is a
presentation-only guardian shell: broad field-steel armour, a protected
autocannon breech, heat-exchanger louvers, counterweight, sensor mast and
warm/cyan status hardware.

The chassis, internal core and targeting plate use smooth authored ellipsoidal
envelopes so close-camera light rolls across maintained armor instead of
stopping at a repeated box edge.

Stable presentation nodes include Chassis, ChassisCore, ChassisCornerCap,
Sensor, OpticLens, WardenAutocannon, WeaponMuzzle, WardenHeatExchanger,
WardenTargetingFace, WardenOpticShroud, WardenRecoilCollarLeft,
WardenThermalFinRight, WardenBreechClamp, and ProductionAssetMarker. The asset
exposes Idle, Walk, and Fire clips for tooling; deterministic runtime gait and
recoil remain owned by the existing procedural animator.

No third-party runtime asset is used. The guardian's collision, health, damage,
autonomy focus, formation behavior, and save state remain unchanged.
