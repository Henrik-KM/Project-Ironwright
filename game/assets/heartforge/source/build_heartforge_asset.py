"""Build the original high-definition Heartforge primary shell.

The asset owns the permanent machine silhouette and stable presentation
sockets. Progression tiers, adaptation retrofits, damage memory, lighting and
the interaction/collision contract remain runtime systems.
"""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path

SOURCE_DIR = Path(__file__).resolve().parent
ASSET_ROOT = SOURCE_DIR.parents[1]
sys.path.insert(0, str(ASSET_ROOT / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere  # noqa: E402


def build() -> None:
    builder = BufferBuilder()
    dark, iron, cladding, rust, heat, cyan = range(6)
    materials = [
        {"name": "Heartforge foundation", "pbrMetallicRoughness": {"baseColorFactor": [0.035, 0.045, 0.047, 1.0], "metallicFactor": 0.72, "roughnessFactor": 0.56}},
        {"name": "Heartforge iron shell", "pbrMetallicRoughness": {"baseColorFactor": [0.14, 0.18, 0.19, 1.0], "metallicFactor": 0.78, "roughnessFactor": 0.42}},
        {"name": "Heartforge cladding", "pbrMetallicRoughness": {"baseColorFactor": [0.28, 0.34, 0.35, 1.0], "metallicFactor": 0.7, "roughnessFactor": 0.38}},
        {"name": "Heartforge weathered copper", "pbrMetallicRoughness": {"baseColorFactor": [0.36, 0.18, 0.095, 1.0], "metallicFactor": 0.48, "roughnessFactor": 0.66}},
        {"name": "Heartforge thermal core", "pbrMetallicRoughness": {"baseColorFactor": [0.48, 0.16, 0.035, 1.0], "metallicFactor": 0.24, "roughnessFactor": 0.34}, "emissiveFactor": [1.0, 0.18, 0.025]},
        {"name": "Heartforge service cyan", "pbrMetallicRoughness": {"baseColorFactor": [0.035, 0.28, 0.3, 1.0], "metallicFactor": 0.28, "roughnessFactor": 0.24}, "emissiveFactor": [0.1, 0.78, 0.82]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    mesh_ids = {
        "foundation": mesh("Foundation", add_cylinder(builder, 2.55, 0.7, dark, 32)),
        "housing": mesh("CoreHousing", add_cylinder(builder, 1.75, 3.4, iron, 32)),
        "furnace": mesh("FurnaceCore", add_cylinder(builder, 1.1, 2.5, heat, 32)),
        "ring_lower": mesh("LowerRing", add_cylinder(builder, 2.15, 0.22, rust, 32)),
        "ring_upper": mesh("UpperRing", add_cylinder(builder, 2.08, 0.22, rust, 32)),
        "cladding": mesh("CoreCladdingSegment", add_box(builder, (0.34, 2.42, 0.62), cladding)),
        "cladding_cap": mesh("CoreCladdingCap", add_box(builder, (0.38, 0.12, 0.68), rust)),
        "louver_core": mesh("CoreServiceLouverCore", add_box(builder, (0.72, 0.92, 0.1), dark)),
        "louver": mesh("CoreServiceLouver", add_box(builder, (0.12, 0.48, 0.08), cyan)),
        "inspection": mesh("CoreInspectionPort", add_box(builder, (0.56, 0.64, 0.1), dark)),
        "rail": mesh("CoreSignalRail", add_cylinder(builder, 0.08, 1.8, cyan, 28)),
        "collar": mesh("HeartforgeUpperCollar", add_cylinder(builder, 1.48, 0.18, rust, 32)),
        "fin": mesh("HeartforgeFocalRadialFin", add_box(builder, (0.16, 0.58, 0.34), iron)),
        "control": mesh("HeartforgeFocalControlFace", add_box(builder, (1.22, 0.68, 0.12), dark)),
        "lens": mesh("HeartforgeFocalSignalLens", add_uv_sphere(builder, 0.075, cyan, 16, 24)),
        "cable": mesh("HeartforgeFocalCableBranch", add_cylinder(builder, 0.055, 1.1, rust, 24)),
        "stack": mesh("ForgeStack", add_cylinder(builder, 0.36, 2.6, iron, 28)),
        "bench": mesh("ForgeBench", add_box(builder, (3.0, 0.35, 1.8), iron)),
        "plate": mesh("AssemblyPlate", add_box(builder, (2.18, 0.18, 1.06), dark)),
        "plate_glow": mesh("AssemblyPlateGlow", add_box(builder, (1.68, 0.06, 0.72), cyan)),
        "slot": mesh("AssemblyPlateSlot", add_box(builder, (0.1, 0.025, 0.42), dark)),
        "rib": mesh("Rib", add_box(builder, (0.24, 2.1, 0.42), rust)),
    }

    nodes: list[dict] = []

    def node(name: str, mesh_id: int | None = None, translation: tuple[float, float, float] | None = None, children: list[int] | None = None, extras: dict | None = None) -> int:
        value: dict = {"name": name}
        if mesh_id is not None:
            value["mesh"] = mesh_id
        if translation is not None:
            value["translation"] = list(translation)
        if children:
            value["children"] = children
        if extras:
            value["extras"] = extras
        nodes.append(value)
        return len(nodes) - 1

    foundation = node("Foundation", mesh_ids["foundation"], (0.0, 0.35, 0.0), extras={"socket_type": "heartforge_anchor"})
    housing_children = [node("CoreHousingShell", mesh_ids["housing"]), node("FurnaceCore", mesh_ids["furnace"])]
    housing = node("CoreHousing", None, (0.0, 2.0, 0.0), housing_children, {"socket_type": "primary_reactor_shell"})
    node("LowerRing", mesh_ids["ring_lower"], (0.0, 1.0, 0.0))
    node("UpperRing", mesh_ids["ring_upper"], (0.0, 2.9, 0.0))

    cladding_children: list[int] = []
    for segment in range(8):
        # The segment mesh is already centred around its authored panel; the
        # transforms create the octagonal manufactured shell language.
        angle = 2.0 * math.pi * segment / 8.0 + math.pi * 0.125
        position = (math.cos(angle) * 1.7, 2.0, math.sin(angle) * 1.7)
        cladding_children.append(node("CoreCladdingSegment%02d" % segment, mesh_ids["cladding"], position))
        cladding_children.append(node("CoreCladdingCap%02d" % segment, mesh_ids["cladding_cap"], (position[0], position[1] + 1.08, position[2])))
    cladding_children.append(node("CoreServiceLouverCore", mesh_ids["louver_core"], (0.0, 2.12, 1.84)))
    for index in range(4):
        cladding_children.append(node("CoreServiceLouver%02d" % index, mesh_ids["louver"], (-0.27 + index * 0.18, 2.12, 1.91)))
    cladding_children.append(node("CoreInspectionPort", mesh_ids["inspection"], (0.0, 1.12, 1.88)))
    cladding_children.append(node("CoreSignalRailLeft", mesh_ids["rail"], (-1.86, 2.05, 0.0)))
    cladding_children.append(node("CoreSignalRailRight", mesh_ids["rail"], (1.86, 2.05, 0.0)))
    cladding = node("CoreCladdingDetail", None, children=cladding_children, extras={"socket_type": "manufactured_cladding"})

    focal_children = [node("HeartforgeUpperCollar", mesh_ids["collar"], (0.0, 3.78, 0.0))]
    for index in range(8):
        angle = 2.0 * math.pi * index / 8.0 + math.pi * 0.125
        focal_children.append(node("HeartforgeFocalRadialFin%02d" % index, mesh_ids["fin"], (math.cos(angle) * 1.45, 3.78, math.sin(angle) * 1.45)))
    focal_children.append(node("HeartforgeFocalControlFace", mesh_ids["control"], (0.0, 2.7, 1.92), extras={"socket_type": "player_facing_control"}))
    for index in range(3):
        focal_children.append(node("HeartforgeFocalSignalLens%02d" % index, mesh_ids["lens"], (-0.34 + index * 0.34, 2.73, 2.01), extras={"socket_type": "service_signal"}))
    focal_children.append(node("HeartforgeFocalCableBranchLeft", mesh_ids["cable"], (-1.26, 2.66, 1.88)))
    focal_children.append(node("HeartforgeFocalCableBranchRight", mesh_ids["cable"], (1.26, 2.66, 1.88)))
    focal = node("HeartforgeFocalDetail", None, children=focal_children, extras={"socket_type": "reactor_control_layer"})

    west_stack = node("WestStack", mesh_ids["stack"], (-1.85, 1.7, 0.0))
    east_stack = node("EastStack", mesh_ids["stack"], (1.85, 1.7, 0.0))
    bench_children = [node("AssemblyPlate", mesh_ids["plate"], (0.0, 0.24, 0.0)), node("AssemblyPlateGlow", mesh_ids["plate_glow"], (0.0, 0.36, 0.0))]
    for slot in range(3):
        bench_children.append(node("AssemblyPlateSlot%02d" % slot, mesh_ids["slot"], (-0.48 + slot * 0.48, 0.4, 0.0)))
    bench = node("ForgeBench", mesh_ids["bench"], (0.0, 0.48, 3.25), bench_children, {"socket_type": "manual_fabrication_surface"})

    ribs: list[int] = []
    for index in range(8):
        angle = 2.0 * math.pi * index / 8.0
        ribs.append(node("Rib%02d" % index, mesh_ids["rib"], (math.cos(angle) * 2.35, 1.75, math.sin(angle) * 2.35)))
    marker = node("ProductionAssetMarker", None, extras={"asset_id": "heartforge.core.v1", "presentation_only": True})
    root = node("HeartforgeModel", None, children=[foundation, housing, cladding, focal, west_stack, east_stack, bench, *ribs, marker], extras={"ironwright_asset_id": "heartforge.core.v1", "asset_quality": "authored_high_definition", "socket_contract": "heartforge_anchor, primary_reactor_shell, player_facing_control, manual_fabrication_surface"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Heartforge asset builder"},
        "scene": 0,
        "scenes": [{"name": "Heartforge Core", "nodes": [root]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {"ironwright_asset_id": "heartforge.core.v1", "required_nodes": ["HeartforgeModel", "Foundation", "CoreHousing", "FurnaceCore", "LowerRing", "UpperRing", "CoreCladdingDetail", "CoreServiceLouverCore", "CoreInspectionPort", "HeartforgeFocalDetail", "HeartforgeUpperCollar", "HeartforgeFocalControlFace", "HeartforgeFocalRadialFin00", "HeartforgeFocalSignalLens01", "ForgeBench", "AssemblyPlate", "ProductionAssetMarker"]},
    }
    output_path = ASSET_ROOT / "heartforge" / "heartforge.gltf"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output_path} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    build()
