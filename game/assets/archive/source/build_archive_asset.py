"""Build the original high-definition North Ruins civic archive landmark glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "archive.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Archive pale stone", "pbrMetallicRoughness": {"baseColorFactor": [0.018, 0.024, 0.030, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.94}},
        {"name": "Archive civic brick", "pbrMetallicRoughness": {"baseColorFactor": [0.038, 0.010, 0.007, 1.0], "metallicFactor": 0.02, "roughnessFactor": 0.94}},
        {"name": "Archive iron", "pbrMetallicRoughness": {"baseColorFactor": [0.018, 0.030, 0.035, 1.0], "metallicFactor": 0.50, "roughnessFactor": 0.58}},
        {"name": "Archive amber", "pbrMetallicRoughness": {"baseColorFactor": [0.48, 0.16, 0.03, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.46}, "emissiveFactor": [0.58, 0.08, 0.008]},
        {"name": "Archive cold glass", "alphaMode": "BLEND", "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [0.012, 0.07, 0.09, 0.18], "metallicFactor": 0.04, "roughnessFactor": 0.42}, "emissiveFactor": [0.0, 0.015, 0.02]},
        {"name": "Archive organic creep", "pbrMetallicRoughness": {"baseColorFactor": [0.10, 0.015, 0.05, 1.0], "metallicFactor": 0.01, "roughnessFactor": 0.88}, "emissiveFactor": [0.12, 0.0, 0.025]},
        {"name": "Archive paper stacks", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.11, 0.06, 1.0], "metallicFactor": 0.01, "roughnessFactor": 0.96}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    stone, brick, iron, amber, glass, organic, paper = range(7)
    mesh_ids = {
        "Floor": mesh("ArchiveFloor", add_box(builder, (18.0, 0.16, 14.0), stone)),
        "Facade": mesh("ArchiveFacade", add_beveled_box(builder, (12.0, 5.6, 0.42), stone, 0.12)),
        "BrickWing": mesh("ArchiveBrickWing", add_beveled_box(builder, (4.4, 4.2, 4.4), brick, 0.16)),
        "Door": mesh("ArchiveVaultDoor", add_cylinder(builder, 1.65, 0.24, iron, 32)),
        "DoorRing": mesh("ArchiveVaultRing", add_cylinder(builder, 2.0, 0.16, amber, 32)),
        "Step": mesh("ArchiveStep", add_beveled_box(builder, (4.4, 0.28, 1.0), stone, 0.055)),
        "Shelf": mesh("ArchiveShelf", add_beveled_box(builder, (2.8, 2.5, 0.24), iron, 0.045)),
        "Paper": mesh("ArchivePaperStack", add_box(builder, (1.9, 0.32, 0.85), paper)),
        "BeaconMast": mesh("ArchiveBeaconMast", add_cylinder(builder, 0.13, 6.0, iron, 16)),
        "Beacon": mesh("ArchiveBeacon", add_uv_sphere(builder, 0.26, amber, 18, 28)),
        "Window": mesh("ArchiveWindow", add_beveled_box(builder, (2.4, 1.55, 0.08), glass, 0.018)),
        "Creep": mesh("ArchiveOrganicCreep", add_uv_sphere(builder, 0.46, organic, 18, 28)),
        "Cable": mesh("ArchiveCable", add_cylinder(builder, 0.045, 4.8, amber, 10)),
        "Marker": mesh("ArchiveMarker", add_box(builder, (0.7, 0.08, 0.7), amber)),
        "WindowFrame": mesh("ArchiveWindowFrame", add_beveled_box(builder, (2.72, 0.10, 1.84), iron, 0.022)),
        "WindowMullion": mesh("ArchiveWindowMullion", add_beveled_box(builder, (0.10, 1.62, 0.12), iron, 0.018)),
        "DoorJamb": mesh("ArchiveDoorJamb", add_beveled_box(builder, (0.24, 3.45, 0.34), stone, 0.035)),
        "DoorLintel": mesh("ArchiveDoorLintel", add_beveled_box(builder, (4.75, 0.24, 0.34), stone, 0.035)),
        "ShelfDivider": mesh("ArchiveShelfDivider", add_beveled_box(builder, (0.12, 2.42, 0.38), iron, 0.018)),
        "ShelfRail": mesh("ArchiveShelfRail", add_beveled_box(builder, (2.52, 0.08, 0.08), amber, 0.018)),
        "BeaconBrace": mesh("ArchiveBeaconBrace", add_box(builder, (0.12, 1.42, 0.12), iron)),
        "BeaconCollar": mesh("ArchiveBeaconCollar", add_cylinder(builder, 0.36, 0.16, amber, 24)),
        "Plaque": mesh("ArchivePlaque", add_beveled_box(builder, (3.0, 0.58, 0.08), amber, 0.018)),
        "FacadeCornice": mesh("ArchiveFacadeCornice", add_beveled_box(builder, (12.4, 0.24, 0.58), stone, 0.055)),
        "FacadePilaster": mesh("ArchiveFacadePilaster", add_beveled_box(builder, (0.34, 4.85, 0.54), stone, 0.045)),
        "VaultInset": mesh("ArchiveVaultInset", add_beveled_box(builder, (5.25, 4.02, 0.16), iron, 0.055)),
        "CreepTendril": mesh("ArchiveCreepTendril", add_cylinder(builder, 0.045, 0.78, organic, 14)),
    }

    nodes: list[dict] = [{
        "name": "ArchiveModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "archive.north_ruins.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "civic_facade, vault_door, archive_stacks, roof_beacon, organic_creep",
        },
    }]

    def add_node(
        name: str,
        mesh_id: int | None = None,
        translation: Sequence[float] = (0.0, 0.0, 0.0),
        rotation: Sequence[float] = (0.0, 0.0, 0.0),
        scale: Sequence[float] | None = None,
        extras: dict | None = None,
        parent: int = 0,
    ) -> int:
        entry: dict = {"name": name, "translation": list(translation)}
        if mesh_id is not None:
            entry["mesh"] = mesh_id
        if rotation != (0.0, 0.0, 0.0):
            entry["rotation"] = quat(rotation)
        if scale is not None:
            entry["scale"] = list(scale)
        if extras:
            entry["extras"] = extras
        nodes.append(entry)
        nodes[parent].setdefault("children", []).append(len(nodes) - 1)
        return len(nodes) - 1

    add_node("ArchiveFloor", mesh_ids["Floor"], (0.0, 0.08, 0.0), extras={"socket_type": "archive_floor"})
    add_node("ArchiveCivicFacade", mesh_ids["Facade"], (0.0, 2.8, 1.7), extras={"socket_type": "civic_facade"})
    add_node("ArchiveFacadeCornice", mesh_ids["FacadeCornice"], (0.0, 5.56, 2.0), extras={"surface": "civic_facade_cornice"})
    add_node("ArchiveFacadePilasterL", mesh_ids["FacadePilaster"], (-5.48, 2.82, 2.0), extras={"surface": "civic_facade_pilaster"})
    add_node("ArchiveFacadePilasterR", mesh_ids["FacadePilaster"], (5.48, 2.82, 2.0), extras={"surface": "civic_facade_pilaster"})
    add_node("ArchiveBrickWingL", mesh_ids["BrickWing"], (-7.0, 2.1, -2.5))
    add_node("ArchiveBrickWingR", mesh_ids["BrickWing"], (7.0, 2.1, -2.5), rotation=(0.0, 0.04, 0.0))
    add_node("ArchiveFacadeWindowL", mesh_ids["Window"], (-3.2, 3.0, 2.0), extras={"socket_type": "civic_window"})
    add_node("ArchiveFacadeWindowR", mesh_ids["Window"], (3.2, 3.0, 2.0), extras={"socket_type": "civic_window"})
    for side, x in (("L", -3.2), ("R", 3.2)):
        add_node("ArchiveWindowFrame%s" % side, mesh_ids["WindowFrame"], (x, 3.0, 2.02), extras={"surface": "civic_window_frame"})
        add_node("ArchiveWindowMullion%s" % side, mesh_ids["WindowMullion"], (x, 3.0, 2.03), extras={"surface": "civic_window_mullion"})
    add_node("ArchiveVaultInset", mesh_ids["VaultInset"], (0.0, 2.15, 1.99), extras={"surface": "vault_door_inset"})
    add_node("ArchiveVaultDoorJambL", mesh_ids["DoorJamb"], (-2.28, 2.15, 2.02), extras={"surface": "vault_door_jamb"})
    add_node("ArchiveVaultDoorJambR", mesh_ids["DoorJamb"], (2.28, 2.15, 2.02), extras={"surface": "vault_door_jamb"})
    add_node("ArchiveVaultDoorLintel", mesh_ids["DoorLintel"], (0.0, 3.86, 2.02), extras={"surface": "vault_door_lintel"})
    add_node("ArchiveVaultDoor", mesh_ids["Door"], (0.0, 2.15, 2.04), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "vault_door"})
    add_node("ArchiveVaultDoorRing", mesh_ids["DoorRing"], (0.0, 2.15, 2.07), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "vault_door_ring"})
    add_node("ArchiveCivicPlaque", mesh_ids["Plaque"], (0.0, 4.48, 2.01), extras={"socket_type": "archive_plaque"})
    add_node("ArchiveVaultSteps", mesh_ids["Step"], (0.0, 0.18, 0.2), extras={"socket_type": "vault_steps"})
    for side, x in enumerate((-4.9, 4.9)):
        shelf = add_node("ArchiveStack%d" % side, mesh_ids["Shelf"], (x, 1.35, -3.2), extras={"socket_type": "archive_stack"})
        for index in range(3):
            add_node("ArchivePaperStack%d_%d" % (side, index), mesh_ids["Paper"], (0.0, -0.88 + float(index) * 0.72, 0.0), parent=shelf)
        for divider_index, divider_x in enumerate((-0.94, 0.0, 0.94)):
            add_node("ArchiveShelfDivider%d_%d" % (side, divider_index), mesh_ids["ShelfDivider"], (divider_x, 0.0, 0.0), parent=shelf, extras={"surface": "archive_shelf_divider"})
        add_node("ArchiveShelfRail%d" % side, mesh_ids["ShelfRail"], (0.0, 0.12, 0.0), parent=shelf, extras={"surface": "archive_shelf_rail"})
    add_node("ArchiveRoofBeacon", mesh_ids["BeaconMast"], (0.0, 5.8, 2.4), extras={"socket_type": "roof_beacon"})
    add_node("ArchiveRoofBeaconLight", mesh_ids["Beacon"], (0.0, 8.85, 2.4), extras={"socket_type": "beacon_light"})
    add_node("ArchiveBeaconCollar", mesh_ids["BeaconCollar"], (0.0, 8.48, 2.4), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "beacon_service_collar"})
    add_node("ArchiveBeaconBraceL", mesh_ids["BeaconBrace"], (-0.42, 7.2, 2.4), extras={"surface": "beacon_brace"})
    add_node("ArchiveBeaconBraceR", mesh_ids["BeaconBrace"], (0.42, 7.2, 2.4), extras={"surface": "beacon_brace"})
    add_node("ArchiveBeaconCable", mesh_ids["Cable"], (0.0, 4.0, 2.4), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "beacon_cable"})
    for index, (x, z, scale) in enumerate(((-7.0, 4.8, (1.2, 0.72, 1.0)), (6.6, -4.8, (0.9, 0.64, 1.25)))):
        add_node("ArchiveOrganicCreep%d" % index, mesh_ids["Creep"], (x, 0.46, z), scale=scale, extras={"socket_type": "organic_creep"})
        for tendril_index, tendril_x in enumerate((-0.22, 0.16)):
            add_node("ArchiveOrganicTendril%d_%d" % (index, tendril_index), mesh_ids["CreepTendril"], (x + tendril_x, 0.82, z), rotation=(0.0, 0.0, -0.26 + float(tendril_index) * 0.42), extras={"surface": "organic_tendril"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "archive.north_ruins.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original North Ruins archive asset builder"},
        "scene": 0,
        "scenes": [{"name": "Archive", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "archive.north_ruins.v1",
            "required_nodes": ["ArchiveModel", "ArchiveCivicFacade", "ArchiveFacadeCornice", "ArchiveFacadePilasterL", "ArchiveVaultInset", "ArchiveFacadeWindowL", "ArchiveWindowFrameL", "ArchiveWindowMullionL", "ArchiveVaultDoor", "ArchiveVaultDoorJambL", "ArchiveVaultDoorLintel", "ArchiveCivicPlaque", "ArchiveRoofBeacon", "ArchiveBeaconCollar", "ArchiveBeaconBraceL", "ArchiveStack0", "ArchiveShelfDivider0_0", "ArchiveShelfRail0", "ArchiveOrganicCreep0", "ArchiveOrganicTendril0_0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
