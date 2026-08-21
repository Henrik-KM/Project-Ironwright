"""Build the original authored outpost shelter shell.

The imported shell owns only presentation geometry and stable sockets. Outpost
role signatures, tier frames, damage, repair and autonomous operation remain
runtime systems so the asset cannot introduce a new management surface.
"""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path

SOURCE_DIR = Path(__file__).resolve().parent
ASSET_ROOT = SOURCE_DIR.parents[1]
sys.path.insert(0, str(ASSET_ROOT / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere  # noqa: E402


def build() -> None:
    builder = BufferBuilder()
    dark, iron, rust, panel, signal = range(5)
    materials = [
        {"name": "Outpost foundation", "pbrMetallicRoughness": {"baseColorFactor": [0.035, 0.045, 0.048, 1.0], "metallicFactor": 0.72, "roughnessFactor": 0.5}},
        {"name": "Outpost shelter iron", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.23, 0.24, 1.0], "metallicFactor": 0.68, "roughnessFactor": 0.42}},
        {"name": "Outpost weathered rust", "pbrMetallicRoughness": {"baseColorFactor": [0.38, 0.20, 0.13, 1.0], "metallicFactor": 0.4, "roughnessFactor": 0.68}},
        {"name": "Outpost service ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.33, 0.39, 0.39, 1.0], "metallicFactor": 0.58, "roughnessFactor": 0.36}},
        {"name": "Outpost signal cyan", "pbrMetallicRoughness": {"baseColorFactor": [0.08, 0.55, 0.58, 1.0], "metallicFactor": 0.05, "roughnessFactor": 0.24}, "emissiveFactor": [0.12, 0.72, 0.78]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    def node(name: str, mesh_id: int | None = None, translation: tuple[float, float, float] | None = None, children: list[int] | None = None, extras: dict | None = None) -> dict:
        value: dict = {"name": name}
        if mesh_id is not None:
            value["mesh"] = mesh_id
        if translation is not None:
            value["translation"] = list(translation)
        if children:
            value["children"] = children
        if extras:
            value["extras"] = extras
        return value

    mesh_ids = {
        "foundation": mesh("Foundation", add_cylinder(builder, 2.65, 0.45, dark, 28)),
        "foundation_inset": mesh("FoundationInset", add_cylinder(builder, 2.38, 0.12, dark, 28)),
        "shelter_core": mesh("CoreShelterCore", add_box(builder, (3.7, 2.1, 3.4), iron)),
        "roof_core": mesh("RoofPlateCore", add_box(builder, (4.1, 0.24, 3.8), rust)),
        "roof_ridge": mesh("RoofPlateRidge", add_box(builder, (2.4, 0.12, 0.18), panel)),
        "vent_core": mesh("CoreVentCore", add_box(builder, (2.1, 0.62, 0.12), panel)),
        "vent_louver": mesh("CoreVentLouver", add_box(builder, (0.12, 0.48, 0.08), iron)),
        "service_core": mesh("CoreServicePanelCore", add_box(builder, (1.0, 0.6, 0.12), panel)),
        "service_cap": mesh("CoreServicePanelCap", add_box(builder, (0.7, 0.08, 0.08), signal)),
        "status_housing": mesh("StatusBeaconHousing", add_cylinder(builder, 0.18, 0.26, panel, 24)),
        "status_lens": mesh("StatusBeaconLens", add_uv_sphere(builder, 0.24, signal, 16, 24)),
        "corner_cap": mesh("ShelterCornerCap", add_uv_sphere(builder, 0.16, rust, 16, 24)),
        "cable": mesh("ServiceCable", add_cylinder(builder, 0.045, 1.2, rust, 24)),
    }

    nodes: list[dict] = []
    def add(value: dict) -> int:
        nodes.append(value)
        return len(nodes) - 1

    foundation = add(node("Foundation", mesh_ids["foundation"], (0.0, 0.23, 0.0), extras={"socket_type": "fixed_site_anchor"}))
    add(node("FoundationInset", mesh_ids["foundation_inset"], (0.0, 0.49, 0.0)))

    shelter_children = [add(node("CoreShelterCore", mesh_ids["shelter_core"]))]
    for index, position in enumerate(((-1.72, 1.02, -1.52), (1.72, 1.02, -1.52), (-1.72, 1.02, 1.52), (1.72, 1.02, 1.52))):
        shelter_children.append(add(node("CoreShelterCornerCap%02d" % index, mesh_ids["corner_cap"], position)))
    shelter = add(node("CoreShelter", None, (0.0, 1.35, 0.0), shelter_children, {"socket_type": "shared_shelter_shell"}))

    roof = add(node("RoofPlate", None, (0.0, 2.48, 0.0), [add(node("RoofPlateCore", mesh_ids["roof_core"])), add(node("RoofPlateRidge", mesh_ids["roof_ridge"], (0.0, 0.16, 0.0)))]))
    vent_children = [add(node("CoreVentCore", mesh_ids["vent_core"]))]
    for index in range(5):
        vent_children.append(add(node("CoreVentLouver%02d" % index, mesh_ids["vent_louver"], (-0.78 + index * 0.39, 0.0, -0.01))))
    vent = add(node("CoreVent", None, (0.0, 1.35, -1.72), vent_children, {"socket_type": "service_vent"}))

    service = add(node("CoreServicePanel", None, (-1.95, 1.18, -0.18), [add(node("CoreServicePanelCore", mesh_ids["service_core"])), add(node("CoreServicePanelCap", mesh_ids["service_cap"], (0.0, 0.26, -0.01)))]))
    status = add(node("StatusBeacon", None, (0.0, 0.0, -1.0), [add(node("StatusBeaconHousing", mesh_ids["status_housing"], (0.0, 2.75, 0.0))), add(node("StatusBeaconLens", mesh_ids["status_lens"], (0.0, 2.97, 0.0)))]))
    add(node("ServiceCableLeft", mesh_ids["cable"], (-1.56, 1.3, -1.74)))
    add(node("ServiceCableRight", mesh_ids["cable"], (1.56, 1.3, -1.74)))
    marker = add(node("ProductionAssetMarker", None, extras={"asset_id": "outpost.shelter.v1", "presentation_only": True}))
    root = add(node("OutpostModel", None, children=[foundation, shelter, roof, vent, service, status, marker], extras={"ironwright_asset_id": "outpost.shelter.v1", "asset_quality": "authored_high_definition", "socket_contract": "fixed_site_anchor, shared_shelter_shell, service_vent, status_beacon"}))

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Outpost shelter asset builder"},
        "scene": 0,
        "scenes": [{"name": "Autonomous Outpost", "nodes": [root]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {"ironwright_asset_id": "outpost.shelter.v1", "required_nodes": ["OutpostModel", "Foundation", "CoreShelter", "CoreShelterCore", "RoofPlate", "CoreVent", "CoreServicePanel", "StatusBeacon", "ProductionAssetMarker"]},
    }
    output_path = ASSET_ROOT / "outpost" / "outpost.gltf"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output_path} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    build()
