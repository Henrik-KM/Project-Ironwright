"""Build the original high-definition Observatory Ridge landmark glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, _geometry, add_beveled_box, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "observatory.gltf"


def add_parabolic_dish(
    builder: BufferBuilder,
    radius: float,
    depth: float,
    material: int,
    rings: int = 18,
    sides: int = 64,
) -> tuple[int, int, int, int, int, int]:
    """Build a high-definition open reflector instead of a scaled sphere."""
    positions: list[float] = [0.0, depth, 0.0]
    normals: list[float] = [0.0, 1.0, 0.0]
    indices: list[int] = []
    for ring in range(1, rings + 1):
        radial = ring / rings
        y = depth * (1.0 - radial * radial)
        for side in range(sides):
            angle = math.tau * side / sides
            x = radius * radial * math.cos(angle)
            z = radius * radial * math.sin(angle)
            dy_dx = -2.0 * depth * x / (radius * radius)
            dy_dz = -2.0 * depth * z / (radius * radius)
            normal_length = math.sqrt(dy_dx * dy_dx + 1.0 + dy_dz * dy_dz)
            positions.extend([x, y, z])
            normals.extend([-dy_dx / normal_length, 1.0 / normal_length, -dy_dz / normal_length])
    first_ring = 1
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([0, first_ring + next_side, first_ring + side])
    for ring in range(rings - 1):
        current = 1 + ring * sides
        following = current + sides
        for side in range(sides):
            next_side = (side + 1) % sides
            a = current + side
            b = current + next_side
            c = following + next_side
            d = following + side
            indices.extend([a, b, c, a, c, d])
    return _geometry(builder, positions, normals, indices, material)


def add_torus(
    builder: BufferBuilder,
    major_radius: float,
    minor_radius: float,
    material: int,
    major_segments: int = 64,
    minor_segments: int = 10,
) -> tuple[int, int, int, int, int, int]:
    """Build a smooth service rim that makes the open dish silhouette legible."""
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for major in range(major_segments):
        major_angle = math.tau * major / major_segments
        major_cos = math.cos(major_angle)
        major_sin = math.sin(major_angle)
        for minor in range(minor_segments):
            minor_angle = math.tau * minor / minor_segments
            minor_cos = math.cos(minor_angle)
            minor_sin = math.sin(minor_angle)
            ring_radius = major_radius + minor_radius * minor_cos
            positions.extend([ring_radius * major_cos, minor_radius * minor_sin, ring_radius * major_sin])
            normals.extend([minor_cos * major_cos, minor_sin, minor_cos * major_sin])
    for major in range(major_segments):
        next_major = (major + 1) % major_segments
        for minor in range(minor_segments):
            next_minor = (minor + 1) % minor_segments
            a = major * minor_segments + minor
            b = next_major * minor_segments + minor
            c = next_major * minor_segments + next_minor
            d = major * minor_segments + next_minor
            indices.extend([a, b, c, a, c, d])
    return _geometry(builder, positions, normals, indices, material)


def add_tapered_cylinder(
    builder: BufferBuilder,
    bottom_radius: float,
    top_radius: float,
    height: float,
    material: int,
    sides: int = 32,
) -> tuple[int, int, int, int, int, int]:
    """Build a compact receiver horn with a smooth, high-definition profile."""
    sides = max(sides, 24)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    bottom = len(positions) // 3
    slope = (bottom_radius - top_radius) / max(height, 0.001)
    for y, radius in ((-height * 0.5, bottom_radius), (height * 0.5, top_radius)):
        for side in range(sides):
            angle = math.tau * side / sides
            positions.extend([math.cos(angle) * radius, y, math.sin(angle) * radius])
            normal = [math.cos(angle), slope, math.sin(angle)]
            normal_length = math.sqrt(sum(value * value for value in normal)) or 1.0
            normals.extend(value / normal_length for value in normal)
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([
            bottom + side,
            bottom + next_side,
            bottom + sides + next_side,
            bottom + side,
            bottom + sides + next_side,
            bottom + sides + side,
        ])
    bottom_center = len(positions) // 3
    positions.extend([0.0, -height * 0.5, 0.0])
    normals.extend([0.0, -1.0, 0.0])
    top_center = len(positions) // 3
    positions.extend([0.0, height * 0.5, 0.0])
    normals.extend([0.0, 1.0, 0.0])
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([bottom_center, bottom + next_side, bottom + side])
        indices.extend([top_center, bottom + sides + side, bottom + sides + next_side])
    return _geometry(builder, positions, normals, indices, material)


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Observatory weathered concrete", "pbrMetallicRoughness": {"baseColorFactor": [0.11, 0.15, 0.16, 1.0], "metallicFactor": 0.06, "roughnessFactor": 0.92}},
        {"name": "Observatory dark alloy", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.13, 0.16, 1.0], "metallicFactor": 0.46, "roughnessFactor": 0.58}},
        {"name": "Observatory oxidized trim", "pbrMetallicRoughness": {"baseColorFactor": [0.34, 0.085, 0.02, 1.0], "metallicFactor": 0.26, "roughnessFactor": 0.76}},
        {"name": "Observatory blue-violet dish", "pbrMetallicRoughness": {"baseColorFactor": [0.045, 0.09, 0.18, 1.0], "metallicFactor": 0.14, "roughnessFactor": 0.68}, "emissiveFactor": [0.002, 0.012, 0.028]},
        {"name": "Observatory cyan signal", "pbrMetallicRoughness": {"baseColorFactor": [0.015, 0.12, 0.17, 1.0], "metallicFactor": 0.12, "roughnessFactor": 0.38}, "emissiveFactor": [0.0, 0.12, 0.18]},
        {"name": "Observatory warm console", "pbrMetallicRoughness": {"baseColorFactor": [0.38, 0.10, 0.015, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.52}, "emissiveFactor": [0.22, 0.04, 0.005]},
        {"name": "Observatory ridge signal", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.15, 0.18, 1.0], "metallicFactor": 0.16, "roughnessFactor": 0.42}, "emissiveFactor": [0.0, 0.08, 0.10]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    concrete, alloy, rust, dish, cyan, warm, ridge_signal = range(7)
    mesh_ids = {
        "Platform": mesh("Platform", add_box(builder, (11.0, 0.38, 8.0), concrete)),
        "Control": mesh("Control", add_beveled_box(builder, (2.8, 2.4, 2.5), alloy, 0.16)),
        "ControlCap": mesh("ControlCap", add_beveled_box(builder, (3.1, 0.18, 2.8), rust, 0.05)),
        # Give the reflector a deeper bowl so the exact remote review frame
        # reads the primary instrument as a parabolic survey dish rather than
        # a shallow circular platform.
        "Dish": mesh("Dish", add_parabolic_dish(builder, 3.0, 0.92, dish)),
        "DishRimRing": mesh("DishRimRing", add_torus(builder, 3.0, 0.11, rust)),
        "DishRim": mesh("DishRim", add_beveled_box(builder, (6.5, 0.16, 0.22), rust, 0.045)),
        "DishBrace": mesh("DishBrace", add_beveled_box(builder, (0.16, 3.5, 0.26), alloy, 0.045)),
        # A survey reflector needs a visible azimuth load path. These rounded
        # parts ground the bowl in the service deck instead of leaving it as
        # a floating blue disc held up by thin rods at remote review distance.
        "DishPedestal": mesh("DishPedestal", add_cylinder(builder, 1.18, 1.95, alloy, 32)),
        "DishSupportRing": mesh("DishSupportRing", add_torus(builder, 1.28, 0.14, rust, 48, 12)),
        "DishPivotHousing": mesh("DishPivotHousing", add_uv_sphere(builder, 0.46, alloy, 20, 32)),
        "DishPivotBand": mesh("DishPivotBand", add_torus(builder, 0.48, 0.085, cyan, 40, 10)),
        # The feed arm remains long enough to bridge the bowl to its receiver,
        # but a slimmer authored profile keeps the approach-facing reflector
        # readable instead of turning the arm into a dark centre bar.
        "FeedArm": mesh("FeedArm", add_cylinder(builder, 0.10, 4.6, alloy, 16)),
        "Feed": mesh("Feed", add_uv_sphere(builder, 0.30, cyan, 18, 28)),
        "FeedHorn": mesh("FeedHorn", add_tapered_cylinder(builder, 0.34, 0.14, 0.62, alloy, 48)),
        "FeedHornRim": mesh("FeedHornRim", add_torus(builder, 0.31, 0.055, rust, 40, 10)),
        "FeedHornLens": mesh("FeedHornLens", add_uv_sphere(builder, 0.18, cyan, 18, 28)),
        "Mast": mesh("Mast", add_cylinder(builder, 0.20, 6.0, rust, 20)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.045, 4.5, warm, 10)),
        "Console": mesh("Console", add_beveled_box(builder, (1.1, 0.55, 0.12), warm, 0.03)),
        "Light": mesh("Light", add_uv_sphere(builder, 0.10, warm, 16, 24)),
        "Deck": mesh("Deck", add_beveled_box(builder, (6.8, 0.18, 2.9), alloy, 0.045)),
        "Rail": mesh("Rail", add_cylinder(builder, 0.06, 2.1, rust, 12)),
        "Window": mesh("Window", add_beveled_box(builder, (0.92, 0.72, 0.08), cyan, 0.02)),
        "ServiceCase": mesh("ServiceCase", add_beveled_box(builder, (1.1, 0.72, 0.78), rust, 0.08)),
        # The dish ribs are exposed in the remote review silhouette. Rounded
        # rods keep the same structural span while avoiding a row of flat
        # manufactured bars across the surviving survey apparatus.
        "DishRib": mesh("DishRib", add_cylinder(builder, 0.075, 5.5, rust, 24)),
        "DishActuator": mesh("DishActuator", add_cylinder(builder, 0.22, 0.28, alloy, 20)),
        "FeedCollar": mesh("FeedCollar", add_cylinder(builder, 0.38, 0.16, cyan, 24)),
        "WindowFrame": mesh("ObservatoryWindowFrame", add_beveled_box(builder, (1.14, 0.10, 0.94), alloy, 0.022)),
        "WindowMullion": mesh("ObservatoryWindowMullion", add_beveled_box(builder, (0.08, 0.72, 0.10), alloy, 0.018)),
        "ConsoleFrame": mesh("ObservatoryConsoleFrame", add_beveled_box(builder, (1.38, 0.08, 0.78), alloy, 0.018)),
        "DeckPost": mesh("ObservatoryDeckPost", add_cylinder(builder, 0.07, 1.35, rust, 14)),
        "MastCollar": mesh("ObservatoryMastCollar", add_cylinder(builder, 0.30, 0.16, rust, 24)),
        "CableAnchor": mesh("ObservatoryCableAnchor", add_cylinder(builder, 0.12, 0.14, warm, 16)),
        "SurveyLightHousing": mesh("ObservatorySurveyLightHousing", add_cylinder(builder, 0.12, 0.16, alloy, 16)),
        "RidgePylon": mesh("ObservatoryRidgePylon", add_cylinder(builder, 0.22, 6.2, alloy, 18)),
        "RidgeBeam": mesh("ObservatoryRidgeBeam", add_beveled_box(builder, (10.0, 0.18, 0.18), rust, 0.04)),
        "RidgeSignalPanel": mesh("ObservatoryRidgeSignalPanel", add_beveled_box(builder, (2.8, 1.35, 0.10), ridge_signal, 0.022)),
        "RidgeSignalFrame": mesh("ObservatoryRidgeSignalFrame", add_beveled_box(builder, (3.15, 1.60, 0.12), alloy, 0.028)),
        "RidgeLadder": mesh("ObservatoryRidgeLadder", add_beveled_box(builder, (0.08, 4.8, 0.08), rust, 0.018)),
        "RidgeBrace": mesh("ObservatoryRidgeBrace", add_cylinder(builder, 0.065, 3.8, alloy, 14)),
        "RidgeBeacon": mesh("ObservatoryRidgeBeacon", add_uv_sphere(builder, 0.18, cyan, 16, 24)),
        "RidgeSensor": mesh("ObservatoryRidgeSensor", add_cylinder(builder, 0.10, 0.34, warm, 16)),
    }

    nodes: list[dict] = [{
        "name": "ObservatoryModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "observatory.ridge.v1",
            "asset_quality": "authored_high_definition",
            "manufactured_surface_profile": "chamfered_high_definition",
            "socket_contract": "dish, feed_signal, mast, console, survey_cables",
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

    add_node("ObservatoryPlatform", mesh_ids["Platform"], (0.0, 0.20, 0.0), extras={"surface": "weathered_observatory_apron"})
    add_node("ObservatoryControl", mesh_ids["Control"], (3.6, 1.35, -2.2), extras={"surface": "survey_control_cabin"})
    add_node("ObservatoryControlCap", mesh_ids["ControlCap"], (3.6, 2.62, -2.2))
    add_node("ObservatoryConsole", mesh_ids["Console"], (3.6, 1.46, -3.48), extras={"socket_type": "survey_console"})
    add_node("ObservatoryConsoleLight", mesh_ids["Light"], (3.6, 1.95, -3.53))
    add_node("ObservatoryServiceDeck", mesh_ids["Deck"], (2.2, 0.48, -3.05), extras={"socket_type": "service_deck"})
    for index, (x, z) in enumerate(((-1.0, -4.3), (5.4, -4.3), (-1.0, -1.8), (5.4, -1.8))):
        add_node("ObservatoryDeckPost%d" % index, mesh_ids["DeckPost"], (x, 1.05, z), extras={"surface": "service_deck_post"})
    for index, (x, z) in enumerate(((0.0, -4.2), (4.4, -4.2), (0.0, -1.9), (4.4, -1.9))):
        add_node("ObservatorySurveyRail%d" % index, mesh_ids["Rail"], (x, 1.55, z), extras={"socket_type": "survey_rail"})
    add_node("ObservatoryControlWindow0", mesh_ids["Window"], (3.05, 1.78, -0.93), extras={"socket_type": "control_window"})
    add_node("ObservatoryControlWindow1", mesh_ids["Window"], (4.15, 1.78, -0.93), extras={"socket_type": "control_window"})
    for index, x in enumerate((3.05, 4.15)):
        add_node("ObservatoryControlWindowFrame%d" % index, mesh_ids["WindowFrame"], (x, 1.78, -0.87), extras={"surface": "control_window_frame"})
        add_node("ObservatoryControlWindowMullion%d" % index, mesh_ids["WindowMullion"], (x, 1.78, -0.79), extras={"surface": "control_window_mullion"})
    add_node("ObservatoryFrontConsole", mesh_ids["Console"], (3.6, 1.42, -0.88), extras={"socket_type": "survey_console_front"})
    add_node("ObservatoryFrontConsoleFrame", mesh_ids["ConsoleFrame"], (3.6, 1.42, -0.82), extras={"surface": "front_console_frame"})
    add_node("ObservatoryServiceCase", mesh_ids["ServiceCase"], (0.2, 0.9, -3.2), extras={"socket_type": "survey_service_case"})

    # The authored bowl opens toward the approach camera. The previous
    # positive tilt showed its convex back and made the focal instrument read
    # as a blue platform; the negative tilt exposes the concave reflector,
    # rim and feed assembly without changing the landmark footprint.
    dish_tilt = -math.pi * 0.12
    add_node("ObservatoryDish", mesh_ids["Dish"], (-0.4, 3.05, 1.0), scale=(1.0, 1.0, 0.82), rotation=(dish_tilt, 0.0, 0.0), extras={"socket_type": "dish"})
    add_node("ObservatoryDishRimRing", mesh_ids["DishRimRing"], (-0.4, 3.05, 1.0), scale=(1.0, 1.0, 0.82), rotation=(dish_tilt, 0.0, 0.0), extras={"surface": "dish_rim_service_ring"})
    add_node("ObservatoryDishRim", mesh_ids["DishRim"], (-0.4, 3.15, -1.52), rotation=(0.0, 0.0, 0.0))
    add_node("ObservatoryDishPedestal", mesh_ids["DishPedestal"], (-0.4, 2.05, 1.0), extras={"surface": "dish_azimuth_pedestal"})
    add_node("ObservatoryDishSupportRing", mesh_ids["DishSupportRing"], (-0.4, 1.12, 1.0), extras={"surface": "dish_pedestal_service_ring"})
    add_node("ObservatoryDishPivotHousing", mesh_ids["DishPivotHousing"], (-0.4, 3.02, 1.0), extras={"socket_type": "dish_pivot"})
    add_node("ObservatoryDishPivotBand", mesh_ids["DishPivotBand"], (-0.4, 3.02, 1.0), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "dish_pivot_signal_band"})
    for index, rotation_y in enumerate((0.0, math.pi * 0.33, -math.pi * 0.33)):
        add_node("ObservatoryDishRib%d" % index, mesh_ids["DishRib"], (-0.4, 3.18, 1.0), rotation=(dish_tilt, rotation_y, 0.0), extras={"surface": "dish_structural_rib"})
    add_node("ObservatoryDishBraceL", mesh_ids["DishBrace"], (-2.2, 3.25, 1.0), rotation=(0.0, 0.0, 0.08))
    add_node("ObservatoryDishBraceR", mesh_ids["DishBrace"], (1.4, 3.25, 1.0), rotation=(0.0, 0.0, -0.08))
    add_node("ObservatoryDishActuator", mesh_ids["DishActuator"], (-0.4, 2.14, 1.0), extras={"socket_type": "dish_actuator"})
    # Place the receiver on the near side of the reflector so the instrument
    # reads as a telescope from the authored positive-Z approach frame.
    feed_position = (-0.4, 4.1, 4.55)
    add_node("ObservatoryFeedArm", mesh_ids["FeedArm"], (-0.4, 4.1, 2.25), rotation=(math.pi * 0.5, 0.0, 0.0))
    feed = add_node("ObservatoryFeedSignal", mesh_ids["Feed"], feed_position, extras={"socket_type": "feed_signal"})
    add_node("ObservatoryFeedHorn", mesh_ids["FeedHorn"], (0.0, 0.0, 0.0), rotation=(math.pi * 0.5, 0.0, 0.0), parent=feed, extras={"surface": "feed_receiver_horn"})
    add_node("ObservatoryFeedHornRim", mesh_ids["FeedHornRim"], (0.0, 0.0, 0.31), rotation=(math.pi * 0.5, 0.0, 0.0), parent=feed, extras={"surface": "feed_receiver_rim"})
    add_node("ObservatoryFeedHornLens", mesh_ids["FeedHornLens"], (0.0, 0.0, 0.34), rotation=(math.pi * 0.5, 0.0, 0.0), parent=feed, extras={"surface": "feed_receiver_lens"})
    add_node("ObservatoryFeedCollar", mesh_ids["FeedCollar"], feed_position, rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "feed_signal_collar"})
    add_node("ObservatoryMast", mesh_ids["Mast"], (-4.0, 3.0, 2.2), extras={"socket_type": "mast"})
    add_node("ObservatoryMastLight", mesh_ids["Light"], (-4.0, 6.1, 2.2))
    add_node("ObservatoryMastCollar", mesh_ids["MastCollar"], (-4.0, 5.85, 2.2), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "mast_service_collar"})

    # A survey station needs a horizon silhouette in addition to its dish.
    # Keep the gantry behind the reflector so it frames the instrument rather
    # than cutting across the bowl from the authored approach camera.
    ridge_z = -3.8
    add_node("ObservatoryRidgePylonL", mesh_ids["RidgePylon"], (-4.7, 3.1, ridge_z), extras={"socket_type": "ridge_pylon"})
    add_node("ObservatoryRidgePylonR", mesh_ids["RidgePylon"], (4.7, 3.1, ridge_z), extras={"socket_type": "ridge_pylon"})
    add_node("ObservatoryRidgeBeam", mesh_ids["RidgeBeam"], (0.0, 6.05, ridge_z), rotation=(0.0, 0.0, 0.02), extras={"socket_type": "ridge_beam"})
    add_node("ObservatoryRidgeSignalFrame", mesh_ids["RidgeSignalFrame"], (0.0, 4.95, ridge_z + 0.04), rotation=(0.0, 0.0, -0.03), extras={"surface": "ridge_signal_frame"})
    add_node("ObservatoryRidgeSignalPanel", mesh_ids["RidgeSignalPanel"], (0.0, 4.95, ridge_z + 0.11), rotation=(0.0, 0.0, -0.03), extras={"socket_type": "ridge_signal_panel"})
    add_node("ObservatoryRidgeLadder", mesh_ids["RidgeLadder"], (4.25, 3.0, ridge_z + 0.23), extras={"surface": "ridge_service_ladder"})
    add_node("ObservatoryRidgeBraceL", mesh_ids["RidgeBrace"], (-4.25, 3.65, ridge_z + 0.05), rotation=(0.0, 0.0, 0.22), extras={"surface": "ridge_brace"})
    add_node("ObservatoryRidgeBraceR", mesh_ids["RidgeBrace"], (4.25, 3.65, ridge_z + 0.05), rotation=(0.0, 0.0, -0.22), extras={"surface": "ridge_brace"})
    for index, x in enumerate((-3.2, 0.0, 3.2)):
        add_node("ObservatoryRidgeBeacon%d" % index, mesh_ids["RidgeBeacon"], (x, 6.42, ridge_z + 0.09), extras={"socket_type": "ridge_beacon"})
        add_node("ObservatoryRidgeSensor%d" % index, mesh_ids["RidgeSensor"], (x, 6.62, ridge_z + 0.09), extras={"surface": "ridge_sensor"})

    for index, side in enumerate((-1.0, 1.0)):
        add_node("ObservatoryCable%d" % index, mesh_ids["Cable"], (side * 2.8, 2.65, 2.3), rotation=(0.0, side * 0.28, side * 0.24), extras={"socket_type": "survey_cable"})
        add_node("ObservatoryCableAnchor%d" % index, mesh_ids["CableAnchor"], (side * 2.8, 2.65, 2.3), rotation=(0.0, math.pi * 0.5, 0.0), extras={"surface": "survey_cable_anchor"})
        add_node("ObservatorySurveyLightHousing%d" % index, mesh_ids["SurveyLightHousing"], (side * 4.3, 0.75, -2.5), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "survey_light_housing"})
        add_node("ObservatorySurveyLight%d" % index, mesh_ids["Light"], (side * 4.3, 0.75, -2.5))

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "observatory.ridge.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Observatory Ridge asset builder"},
        "scene": 0,
        "scenes": [{"name": "ObservatoryRidge", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "observatory.ridge.v1",
            "manufactured_surface_profile": "chamfered_high_definition",
            "required_nodes": ["ObservatoryModel", "ObservatoryDish", "ObservatoryDishRimRing", "ObservatoryDishPedestal", "ObservatoryDishSupportRing", "ObservatoryDishPivotHousing", "ObservatoryDishPivotBand", "ObservatoryDishRib0", "ObservatoryDishActuator", "ObservatoryFeedSignal", "ObservatoryFeedCollar", "ObservatoryMast", "ObservatoryMastCollar", "ObservatoryConsole", "ObservatoryFrontConsole", "ObservatoryFrontConsoleFrame", "ObservatoryServiceDeck", "ObservatoryControlWindow0", "ObservatoryControlWindowFrame0", "ObservatoryControlWindowMullion0", "ObservatorySurveyRail0", "ObservatoryCableAnchor0", "ObservatorySurveyLightHousing0", "ObservatoryRidgePylonL", "ObservatoryRidgeBeam", "ObservatoryRidgeSignalPanel", "ObservatoryRidgeLadder", "ObservatoryRidgeBraceL", "ObservatoryRidgeBeacon0", "ObservatoryRidgeSensor0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
