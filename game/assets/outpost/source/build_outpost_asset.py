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
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_cylinder, add_torus, add_uv_sphere  # noqa: E402


def build() -> None:
    builder = BufferBuilder()
    dark, iron, rust, panel, signal, glass, maintenance, shelter_body = range(8)
    materials = [
        {"name": "Outpost foundation", "pbrMetallicRoughness": {"baseColorFactor": [0.035, 0.045, 0.048, 1.0], "metallicFactor": 0.34, "roughnessFactor": 0.8}},
        {"name": "Outpost shelter iron", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.23, 0.24, 1.0], "metallicFactor": 0.68, "roughnessFactor": 0.42}},
        {"name": "Outpost weathered rust", "pbrMetallicRoughness": {"baseColorFactor": [0.38, 0.20, 0.13, 1.0], "metallicFactor": 0.4, "roughnessFactor": 0.68}},
        {"name": "Outpost service ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.24, 0.30, 0.30, 1.0], "metallicFactor": 0.34, "roughnessFactor": 0.62}},
        {"name": "Outpost signal cyan", "pbrMetallicRoughness": {"baseColorFactor": [0.08, 0.55, 0.58, 1.0], "metallicFactor": 0.05, "roughnessFactor": 0.24}, "emissiveFactor": [0.12, 0.72, 0.78]},
        {"name": "Outpost cold glass", "pbrMetallicRoughness": {"baseColorFactor": [0.08, 0.22, 0.25, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.18}, "emissiveFactor": [0.02, 0.12, 0.14]},
        {"name": "Outpost maintenance trim", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.09, 0.08, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.9}},
        {"name": "Outpost shelter body", "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.16, 0.17, 1.0], "metallicFactor": 0.3, "roughnessFactor": 0.82}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        # Keep the shared builder's UV and tangent channels on every authored
        # shelter surface so imported PBR materials retain their relief.
        position, normal, uv, tangent, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent}, "indices": indices, "material": material}]})
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
        "foundation_apron": mesh("FoundationApron", add_cylinder(builder, 3.05, 0.16, dark, 36)),
        "foundation": mesh("Foundation", add_cylinder(builder, 2.65, 0.45, dark, 28)),
        "foundation_inset": mesh("FoundationInset", add_cylinder(builder, 2.38, 0.12, dark, 28)),
        "foundation_collar": mesh("FoundationServiceCollar", add_torus(builder, 2.48, 0.095, maintenance, 48, 10)),
        "shelter_core": mesh("CoreShelterCore", add_beveled_box(builder, (3.7, 2.1, 3.4), shelter_body)),
        "shelter_band": mesh("ShelterMaintenanceBand", add_beveled_box(builder, (3.28, 0.12, 0.16), maintenance)),
        "window_frame": mesh("ShelterWindowFrame", add_beveled_box(builder, (0.1, 0.72, 1.28), panel)),
        "window_mullion": mesh("ShelterWindowMullion", add_beveled_box(builder, (0.12, 0.58, 0.08), rust)),
        "window_glass": mesh("ShelterWindowGlass", add_beveled_box(builder, (0.06, 0.54, 0.92), glass)),
        "service_door": mesh("ShelterServiceDoor", add_beveled_box(builder, (0.1, 1.18, 0.86), panel)),
        "service_latch": mesh("ShelterServiceLatch", add_beveled_box(builder, (0.08, 0.12, 0.38), signal)),
        "roof_core": mesh("RoofPlateCore", add_beveled_box(builder, (4.1, 0.24, 3.8), rust)),
        "roof_ridge": mesh("RoofPlateRidge", add_beveled_box(builder, (2.4, 0.12, 0.18), panel)),
        "canopy_core": mesh("ShelterCanopyCore", add_beveled_box(builder, (2.55, 0.38, 1.55), iron)),
        "canopy_ridge": mesh("ShelterCanopyRidge", add_beveled_box(builder, (1.72, 0.1, 0.18), panel)),
        "canopy_lens": mesh("ShelterCanopyLens", add_beveled_box(builder, (1.18, 0.16, 0.06), signal)),
        "roof_rib": mesh("RoofServiceRib", add_beveled_box(builder, (0.16, 0.18, 3.32), iron)),
        "roof_brace": mesh("RoofServiceBrace", add_beveled_box(builder, (0.2, 0.2, 0.72), rust)),
        "vent_core": mesh("CoreVentCore", add_beveled_box(builder, (2.1, 0.62, 0.12), panel)),
        "vent_louver": mesh("CoreVentLouver", add_beveled_box(builder, (0.12, 0.48, 0.08), iron)),
        "vent_cap": mesh("CoreVentCap", add_beveled_box(builder, (2.26, 0.1, 0.18), rust)),
        "service_core": mesh("CoreServicePanelCore", add_beveled_box(builder, (1.0, 0.6, 0.12), panel)),
        "service_cap": mesh("CoreServicePanelCap", add_beveled_box(builder, (0.7, 0.08, 0.08), signal)),
        "service_rail": mesh("ServiceRail", add_beveled_box(builder, (0.12, 0.12, 1.7), rust)),
        "foundation_anchor": mesh("FoundationAnchor", add_beveled_box(builder, (0.34, 0.16, 0.54), panel)),
        "foundation_latch": mesh("FoundationLatch", add_beveled_box(builder, (0.16, 0.08, 0.24), signal)),
        "status_housing": mesh("StatusBeaconHousing", add_cylinder(builder, 0.18, 0.26, panel, 24)),
        "status_lens": mesh("StatusBeaconLens", add_uv_sphere(builder, 0.24, signal, 16, 24)),
        "corner_cap": mesh("ShelterCornerCap", add_uv_sphere(builder, 0.16, rust, 16, 24)),
        "cable": mesh("ServiceCable", add_cylinder(builder, 0.045, 1.2, rust, 24)),
    }

    nodes: list[dict] = []
    def add(value: dict) -> int:
        nodes.append(value)
        return len(nodes) - 1

    foundation_apron = add(node("FoundationApron", mesh_ids["foundation_apron"], (0.0, 0.08, 0.0), extras={"surface": "foundation_apron"}))
    foundation = add(node("Foundation", mesh_ids["foundation"], (0.0, 0.23, 0.0), extras={"socket_type": "fixed_site_anchor"}))
    foundation_inset = add(node("FoundationInset", mesh_ids["foundation_inset"], (0.0, 0.49, 0.0)))
    foundation_collar = add(node("FoundationServiceCollar", mesh_ids["foundation_collar"], (0.0, 0.53, 0.0), extras={"surface": "foundation_service_collar"}))

    shelter_children = [add(node("CoreShelterCore", mesh_ids["shelter_core"]))]
    for index, position in enumerate(((-1.9, 0.52, -0.0), (1.9, 0.52, -0.0))):
        shelter_children.append(add(node("ShelterWindowFrame%02d" % index, mesh_ids["window_frame"], position)))
        shelter_children.append(add(node("ShelterWindowGlass%02d" % index, mesh_ids["window_glass"], (position[0] * 1.01, position[1], position[2]))))
        shelter_children.append(add(node("ShelterWindowMullion%02d" % index, mesh_ids["window_mullion"], (position[0] * 1.02, position[1], position[2]))))
    shelter_children.append(add(node("ShelterServiceDoor", mesh_ids["service_door"], (-1.91, 1.25, 0.9))))
    shelter_children.append(add(node("ShelterServiceLatch", mesh_ids["service_latch"], (-1.98, 1.25, 0.9))))
    for index, position in enumerate(((-1.6, 0.18, -1.71), (1.6, 0.18, -1.71))):
        shelter_children.append(add(node("ShelterMaintenanceBand%02d" % index, mesh_ids["shelter_band"], position)))
    for index, position in enumerate(((-1.72, 1.02, -1.52), (1.72, 1.02, -1.52), (-1.72, 1.02, 1.52), (1.72, 1.02, 1.52))):
        shelter_children.append(add(node("CoreShelterCornerCap%02d" % index, mesh_ids["corner_cap"], position)))
    shelter = add(node("CoreShelter", None, (0.0, 1.35, 0.0), shelter_children, {"socket_type": "shared_shelter_shell"}))

    roof_children = [
        add(node("RoofPlateCore", mesh_ids["roof_core"])),
        add(node("RoofPlateRidge", mesh_ids["roof_ridge"], (0.0, 0.16, 0.0))),
        # A compact raised canopy breaks the repeated frame silhouette and
        # gives the shelter a legible maintained instrument face at review
        # distance without changing the outpost footprint or sockets.
        add(node("ShelterCanopy", mesh_ids["canopy_core"], (0.0, 0.32, -1.0), extras={"surface": "raised_service_canopy"})),
        add(node("ShelterCanopyRidge", mesh_ids["canopy_ridge"], (0.0, 0.55, -1.0))),
        add(node("ShelterCanopyLens", mesh_ids["canopy_lens"], (0.0, 0.33, -1.78), extras={"surface": "canopy_service_lens"})),
        add(node("ShelterCanopyRearLens", mesh_ids["canopy_lens"], (0.0, 0.33, 1.78), extras={"surface": "canopy_service_lens"})),
    ]
    for index, x in enumerate((-1.35, 0.0, 1.35)):
        roof_children.append(add(node("RoofServiceRib%02d" % index, mesh_ids["roof_rib"], (x, 0.14, 0.0))))
    roof_children.extend([
        add(node("RoofServiceBraceL", mesh_ids["roof_brace"], (-1.58, 0.18, -1.18))),
        add(node("RoofServiceBraceR", mesh_ids["roof_brace"], (1.58, 0.18, -1.18))),
    ])
    roof = add(node("RoofPlate", None, (0.0, 2.48, 0.0), roof_children))
    vent_children = [add(node("CoreVentCore", mesh_ids["vent_core"]))]
    for index in range(5):
        vent_children.append(add(node("CoreVentLouver%02d" % index, mesh_ids["vent_louver"], (-0.78 + index * 0.39, 0.0, -0.01))))
    vent_children.append(add(node("CoreVentCap", mesh_ids["vent_cap"], (0.0, 0.36, 0.0))))
    vent = add(node("CoreVent", None, (0.0, 1.35, -1.72), vent_children, {"socket_type": "service_vent"}))

    service_children = [add(node("CoreServicePanelCore", mesh_ids["service_core"])), add(node("CoreServicePanelCap", mesh_ids["service_cap"], (0.0, 0.26, -0.01)))]
    service_children.extend([
        add(node("ServiceRailTop", mesh_ids["service_rail"], (0.58, 0.0, 0.0))),
        add(node("ServiceRailBottom", mesh_ids["service_rail"], (-0.58, 0.0, 0.0))),
    ])
    service = add(node("CoreServicePanel", None, (-1.95, 1.18, -0.18), service_children))
    status = add(node("StatusBeacon", None, (0.0, 0.0, -1.0), [add(node("StatusBeaconHousing", mesh_ids["status_housing"], (0.0, 2.75, 0.0))), add(node("StatusBeaconLens", mesh_ids["status_lens"], (0.0, 2.97, 0.0)))]))
    add(node("ServiceCableLeft", mesh_ids["cable"], (-1.56, 1.3, -1.74)))
    add(node("ServiceCableRight", mesh_ids["cable"], (1.56, 1.3, -1.74)))
    anchor_nodes: list[int] = []
    for index, position in enumerate(((-2.05, 0.53, -2.08), (2.05, 0.53, -2.08), (-2.05, 0.53, 2.08), (2.05, 0.53, 2.08))):
        anchor_nodes.append(add(node("FoundationAnchor%02d" % index, mesh_ids["foundation_anchor"], position)))
        anchor_nodes.append(add(node("FoundationLatch%02d" % index, mesh_ids["foundation_latch"], (position[0], 0.65, position[2] - 0.28))))
    marker = add(node("ProductionAssetMarker", None, extras={"asset_id": "outpost.shelter.v1", "presentation_only": True}))
    root = add(node("OutpostModel", None, children=[foundation_apron, foundation, foundation_inset, foundation_collar, shelter, roof, vent, service, status, *anchor_nodes, marker], extras={"ironwright_asset_id": "outpost.shelter.v1", "asset_quality": "authored_high_definition", "socket_contract": "fixed_site_anchor, shared_shelter_shell, service_vent, status_beacon, maintenance_hardware"}))

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
        "extras": {"ironwright_asset_id": "outpost.shelter.v1", "asset_quality": "authored_high_definition", "manufactured_surface_profile": "chamfered_high_definition", "required_nodes": ["OutpostModel", "FoundationApron", "Foundation", "FoundationServiceCollar", "CoreShelter", "CoreShelterCore", "RoofPlate", "ShelterCanopy", "ShelterCanopyRidge", "ShelterCanopyLens", "CoreVent", "CoreServicePanel", "StatusBeacon", "ProductionAssetMarker", "ShelterWindowFrame00", "ShelterWindowMullion00", "RoofServiceRib01", "FoundationAnchor00"]},
    }
    output_path = ASSET_ROOT / "outpost" / "outpost.gltf"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output_path} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    build()
