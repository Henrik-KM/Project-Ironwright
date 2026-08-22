class_name ReleaseWorldArtDirector3D
extends Node

signal art_pass_completed(meshes_textured: int, regions_dressed: int)

const TEXTURE_ROOT := "res://assets/release/textures"
const TEXTURE_PATHS: Dictionary = {
    &"asphalt": TEXTURE_ROOT + "/asphalt_wet.png",
    &"brick": TEXTURE_ROOT + "/brick_ruin.png",
    &"chitin": TEXTURE_ROOT + "/chitin.png",
    &"concrete": TEXTURE_ROOT + "/concrete_wet.png",
    &"grime": TEXTURE_ROOT + "/grime_decal.png",
    &"membrane": TEXTURE_ROOT + "/membrane.png",
    &"metal": TEXTURE_ROOT + "/metal_brushed.png",
    &"moss": TEXTURE_ROOT + "/moss_growth.png",
    &"rust": TEXTURE_ROOT + "/rust_panel.png",
}
const NORMAL_TEXTURE_PATHS: Dictionary = {
    &"asphalt": TEXTURE_ROOT + "/asphalt_wet_normal.png",
    &"brick": TEXTURE_ROOT + "/brick_ruin_normal.png",
    &"chitin": TEXTURE_ROOT + "/chitin_normal.png",
    &"concrete": TEXTURE_ROOT + "/concrete_wet_normal.png",
    &"grime": TEXTURE_ROOT + "/grime_decal_normal.png",
    &"membrane": TEXTURE_ROOT + "/membrane_normal.png",
    &"metal": TEXTURE_ROOT + "/metal_brushed_normal.png",
    &"moss": TEXTURE_ROOT + "/moss_growth_normal.png",
    &"rust": TEXTURE_ROOT + "/rust_panel_normal.png",
}
const AUTHORED_MACHINE_TOKENS: Array[String] = [
    "mechromancer",
    "bulwark",
    "warden",
    "scrapper",
    "pathfinder",
    "engineer",
    "relay",
]
const AUTHORED_ORGANIC_TOKENS: Array[String] = [
    "veilstalker",
    "razorhound",
    "sporecaster",
    "broodmass",
    "burrower",
    "skitterling",
    "apex",
    "roofleaper",
    "glassmoth",
    "miremaw",
    "carrionbell",
    "rootweaver",
    "thornback",
    "ashmantle",
]
const ORGANIC_MEMBRANE_TOKENS: Array[String] = [
    "membrane",
    "veil",
    "wing",
    "sac",
    "fan",
    "gill",
    "fin",
    "resonator",
    "mantle",
    "bell",
    "spore",
    "vein",
]

var world: Node3D
var region_director: WorldRegionDirector3D
var settings_service: ReleaseSettingsService3D
var textures: Dictionary = {}
var normal_textures: Dictionary = {}
var dressing_root: Node3D
var region_dressing_roots: Dictionary = {}
var meshes_textured: int = 0
var regions_dressed: int = 0
var load_errors: Array[String] = []


func configure(next_world: Node3D, next_regions: WorldRegionDirector3D, next_settings: ReleaseSettingsService3D) -> void:
    world = next_world
    region_director = next_regions
    settings_service = next_settings


func _ready() -> void:
    add_to_group(&"release_world_art_director")
    get_tree().node_added.connect(_on_node_added)
    _load_textures()
    dressing_root = Node3D.new()
    dressing_root.name = "ReleaseWorldDressing"
    if world == null:
        world = get_parent() as Node3D
    world.add_child.call_deferred(dressing_root)
    call_deferred("_apply_release_art")
    call_deferred("_connect_region_lod")


func _on_node_added(node: Node) -> void:
    # Actors, outpost upgrades and discovered-region dressing are created
    # throughout a run. Keep the release material pass live instead of
    # leaving late-created meshes on their greybox fallback materials.
    if node == null or not (node is MeshInstance3D):
        return
    call_deferred("_texture_subtree_id", node.get_instance_id())


func _load_textures() -> void:
    textures.clear()
    normal_textures.clear()
    load_errors.clear()
    for raw_id in TEXTURE_PATHS:
        var texture_id := raw_id as StringName
        var path := str(TEXTURE_PATHS[texture_id])
        if not ResourceLoader.exists(path):
            load_errors.append("Missing release texture: %s" % path)
            continue
        var texture := load(path) as Texture2D
        if texture != null:
            textures[texture_id] = texture
    for raw_id in NORMAL_TEXTURE_PATHS:
        var texture_id := raw_id as StringName
        var path := str(NORMAL_TEXTURE_PATHS[texture_id])
        if not ResourceLoader.exists(path):
            load_errors.append("Missing release normal texture: %s" % path)
            continue
        var texture := load(path) as Texture2D
        if texture != null:
            normal_textures[texture_id] = texture


func _apply_release_art() -> void:
    if world == null or dressing_root == null:
        return
    meshes_textured = 0
    regions_dressed = 0
    region_dressing_roots.clear()
    _texture_recursive(world)
    _dress_heartforge_district()
    if region_director != null:
        for raw_region_id in region_director.region_data:
            _dress_region(raw_region_id as StringName)
    _connect_region_lod()
    art_pass_completed.emit(meshes_textured, regions_dressed)


func _connect_region_lod() -> void:
    if world == null or not is_instance_valid(world):
        return
    var region_lod := world.get_node_or_null("RegionPresentationLodDirector")
    if region_lod == null or not region_lod.has_signal(&"detail_changed"):
        return
    var callback := Callable(self, "_on_region_detail_changed")
    if not region_lod.is_connected(&"detail_changed", callback):
        region_lod.connect(&"detail_changed", callback)
    for raw_region_id in region_dressing_roots:
        var region_id := raw_region_id as StringName
        var detail_level := 0
        if region_lod.has_method(&"detail_mode_for"):
            detail_level = int(region_lod.call(&"detail_mode_for", region_id))
        _on_region_detail_changed(region_id, detail_level)


func _on_region_detail_changed(region_id: StringName, detail_level: int) -> void:
    var root := region_dressing_roots.get(region_id) as Node3D
    if root == null or not is_instance_valid(root):
        return
    # PersistentRegionGeometry owns the reduced landmark proxy. The release
    # dressing is the close-range authored layer, so it must disappear outside
    # the full-detail radius instead of silently keeping every remote mesh live.
    root.visible = detail_level <= 0


func region_dressing_root(region_id: StringName) -> Node3D:
    return region_dressing_roots.get(region_id) as Node3D


func _texture_recursive(node: Node) -> void:
    if node is MeshInstance3D:
        _texture_mesh(node as MeshInstance3D)
    for child in node.get_children():
        if child == dressing_root:
            continue
        _texture_recursive(child)


func _texture_subtree_id(instance_id: int) -> void:
    var mesh := instance_from_id(instance_id) as MeshInstance3D
    if mesh == null or not is_instance_valid(mesh) or mesh == dressing_root:
        return
    _texture_mesh(mesh)


func apply_to_node(node: Node) -> void:
    if node == null or not is_instance_valid(node) or node == dressing_root:
        return
    _texture_recursive(node)


func _texture_mesh(mesh_instance: MeshInstance3D) -> void:
    if mesh_instance.has_meta(&"release_material_family"):
        return
    var category := _texture_category(mesh_instance)
    if category == &"" or not textures.has(category):
        return
    var source_material := mesh_instance.material_override as StandardMaterial3D
    var material := source_material.duplicate(true) as StandardMaterial3D if source_material != null else StandardMaterial3D.new()
    material.albedo_texture = textures[category]
    material.uv1_triplanar = true
    material.uv1_world_triplanar = true
    material.uv1_scale = _uv_scale(category)
    if normal_textures.has(category):
        material.normal_enabled = true
        material.normal_texture = normal_textures[category]
        material.normal_scale = _normal_scale(category)
    if category in [&"asphalt", &"concrete"]:
        material.roughness = 0.62 if category == &"asphalt" else 0.78
    elif category in [&"metal", &"rust"]:
        material.metallic = 0.62 if category == &"metal" else 0.38
        material.roughness = 0.48 if category == &"metal" else 0.72
    elif category in [&"chitin", &"membrane"]:
        material.roughness = 0.58
    mesh_instance.material_override = material
    mesh_instance.visibility_range_end = 250.0
    mesh_instance.set_meta(&"release_material_family", category)
    meshes_textured += 1


func _texture_category(mesh_instance: MeshInstance3D) -> StringName:
    var path_text := str(mesh_instance.get_path()).to_lower()
    var name_text := String(mesh_instance.name).to_lower()
    var combined := "%s %s" % [path_text, name_text]
    # Imported production shells retain their authored family in the node
    # path, while their individual meshes intentionally use neutral names
    # such as TorsoSegment or Fastener. Recognise the family before the
    # procedural naming heuristics so the high-definition assets receive the
    # same triplanar material language as the rest of the release world.
    if _contains_any(combined, AUTHORED_ORGANIC_TOKENS):
        return &"membrane" if _contains_organic_membrane_name(name_text) else &"chitin"
    if _contains_any(combined, AUTHORED_MACHINE_TOKENS):
        return &"metal"
    if "organic" in combined or "torso" in name_text or "carapace" in name_text or "head" in name_text and "mechromancer" not in combined:
        return &"membrane" if ("sac" in name_text or "membrane" in name_text or "wing" in name_text or "bell" in name_text) else &"chitin"
    if "road" in combined or "lanemark" in name_text:
        return &"asphalt"
    if "ground" in combined or "foundation" in name_text or "sidewalk" in name_text:
        return &"concrete"
    if "shell" in name_text or "tower" in name_text or "building" in combined:
        return &"brick"
    if "rubble" in combined or "collapsed" in name_text:
        return &"grime"
    if "armor" in name_text or "chassis" in name_text or "weapon" in name_text or "pole" in name_text:
        return &"metal"
    if "vehicle" in combined or "rust" in name_text or "roofplate" in name_text:
        return &"rust"
    return &""


func _contains_any(text: String, tokens: Array[String]) -> bool:
    for token in tokens:
        if token in text:
            return true
    return false


func _contains_organic_membrane_name(name_text: String) -> bool:
    var detail_name := name_text
    for family_token in AUTHORED_ORGANIC_TOKENS:
        detail_name = detail_name.replace(family_token, "")
    return _contains_any(detail_name, ORGANIC_MEMBRANE_TOKENS)


func _uv_scale(category: StringName) -> Vector3:
    match category:
        &"asphalt":
            return Vector3(0.14, 0.14, 0.14)
        &"brick":
            return Vector3(0.28, 0.28, 0.28)
        &"metal", &"rust":
            return Vector3(0.42, 0.42, 0.42)
        &"chitin", &"membrane":
            return Vector3(0.7, 0.7, 0.7)
        _:
            return Vector3(0.22, 0.22, 0.22)


func _normal_scale(category: StringName) -> float:
    match category:
        &"chitin", &"membrane":
            return 0.78
        &"brick", &"rust", &"moss":
            return 0.62
        &"metal":
            return 0.42
        _:
            return 0.5


func _dress_heartforge_district() -> void:
    var root := _region_root("HeartforgeReleaseDressing", Vector3.ZERO)
    var warm_metal := _textured_material(&"rust", Color("8f5a36"), 0.45, 0.65)
    var dark_metal := _textured_material(&"metal", Color("30383a"), 0.72, 0.48)
    var plate_metal := _textured_material(&"metal", Color("4c5a58"), 0.78, 0.42)
    var beacon_material := _emissive_material(Color("ffbd71"), 3.4)
    var heartforge_detail := Node3D.new()
    heartforge_detail.name = "HighDefinitionHeartforgeDressing"
    root.add_child(heartforge_detail)
    for index in range(6):
        var angle := TAU * float(index) / 6.0
        var position := Vector3(cos(angle) * 11.5, 0.0, sin(angle) * 11.5)
        var barrier := Node3D.new()
        barrier.name = "HeartforgeBarrier%02d" % index
        barrier.position = position + Vector3.UP * 0.45
        barrier.rotation.y = -angle
        heartforge_detail.add_child(barrier)
        ModelKit3D.add_beveled_box(barrier, Vector3(2.8, 0.9, 1.2), Vector3.ZERO, warm_metal, Vector3.ZERO, "ImprovisedBarrier", 0.16)
        ModelKit3D.add_surface_panel(
            barrier,
            Vector3(1.75, 0.42, 0.1),
            Vector3(0.0, 0.08, -0.62),
            dark_metal,
            plate_metal,
            Vector3.ZERO,
            "HeartforgeBarrierService%02d" % index
        )
        for side in [-1.0, 1.0]:
            ModelKit3D.add_cylinder(
                barrier,
                0.055,
                1.85,
                Vector3(side * 0.88, 0.5, 0.0),
                plate_metal,
                Vector3(0.0, 0.0, side * 0.24),
                "HeartforgeBarrierBrace%02d" % index
            )
            ModelKit3D.add_sphere(
                barrier,
                0.09,
                Vector3(side * 0.78, 0.41, -0.66),
                beacon_material,
                Vector3.ONE,
                "HeartforgeBarrierBeacon%02d" % index
            )
        ModelKit3D.add_cylinder(heartforge_detail, 0.08, 2.6, position + Vector3.UP * 1.3, dark_metal, Vector3.ZERO, "CablePost")
        ModelKit3D.add_cylinder(heartforge_detail, 0.11, 0.18, position + Vector3.UP * 2.58, plate_metal, Vector3.ZERO, "CablePostCap")
    for index in range(16):
        var angle := TAU * float(index) / 16.0
        var radius := 7.2 + float(index % 3) * 1.4
        ModelKit3D.add_sphere(root, 0.055, Vector3(cos(angle) * radius, 2.5 + sin(float(index) * 0.7) * 0.35, sin(angle) * radius), _emissive_material(Color("ffbd71"), 4.0), Vector3.ONE, "SanctuaryStringLight")
    regions_dressed += 1


func _dress_region(region_id: StringName) -> void:
    var data := region_director.get_region_data(region_id)
    if data.is_empty() or region_id == &"region.heartforge_district":
        return
    var center := region_director.center(region_id)
    var kind := StringName(str(data.get("kind", "urban")))
    var root := _region_root("Release_%s" % String(region_id).replace("region.", "").to_pascal_case(), center)
    region_dressing_roots[region_id] = root
    match kind:
        &"industrial":
            _dress_industrial(root)
        &"tenement":
            _dress_tenement(root)
        &"greenhouse":
            _dress_greenhouse(root)
        &"commercial":
            _dress_market(root)
        &"waterfront":
            _dress_waterfront(root)
        &"rail":
            _dress_rail(root)
        &"nest":
            _dress_nest(root)
        &"observatory":
            _dress_observatory(root)
        &"research":
            _dress_research(root)
        &"endgame":
            _dress_cistern(root)
        _:
            _dress_archive(root)
    regions_dressed += 1


func _region_root(node_name: String, position: Vector3) -> Node3D:
    var root := Node3D.new()
    root.name = node_name
    root.position = position
    dressing_root.add_child(root)
    return root


func _dress_industrial(root: Node3D) -> void:
    var metal := _textured_material(&"metal", Color("394245"), 0.72, 0.46)
    var rust := _textured_material(&"rust", Color("754a31"), 0.38, 0.72)
    var warning := _emissive_material(Color("f0a24c"), 2.8)
    var industrial_detail := Node3D.new()
    industrial_detail.name = "HighDefinitionIndustrialDressing"
    root.add_child(industrial_detail)
    for index in range(5):
        var radius := 0.75 + float(index % 2) * 0.25
        var height := 4.0 + float(index) * 0.8
        var tank := Node3D.new()
        tank.name = "SubstationTank%02d" % index
        tank.position = Vector3(-10.0 + float(index) * 5.0, 2.0 + float(index) * 0.4, -4.0 + float(index % 2) * 8.0)
        industrial_detail.add_child(tank)
        ModelKit3D.add_cylinder(tank, radius, height, Vector3.ZERO, metal, Vector3.ZERO, "TankCore")
        ModelKit3D.add_beveled_box(tank, Vector3(radius * 1.55, 0.18, radius * 1.55), Vector3(0.0, height * 0.5 + 0.08, 0.0), rust, Vector3.ZERO, "TankTopPlate", 0.22)
        ModelKit3D.add_beveled_box(tank, Vector3(radius * 1.4, 0.16, radius * 1.4), Vector3(0.0, -height * 0.5 - 0.06, 0.0), rust, Vector3.ZERO, "TankFootPlate", 0.22)
        ModelKit3D.add_louvered_panel(
            tank,
            Vector3(radius * 1.15, 0.82, 0.12),
            Vector3(0.0, 0.1, radius + 0.03),
            metal,
            rust,
            Vector3.ZERO,
            "TankServiceLouver",
            4
        )
        ModelKit3D.add_cylinder(tank, radius * 0.72, 0.09, Vector3(0.0, height * 0.26, 0.0), rust, Vector3.ZERO, "TankBand")
        ModelKit3D.add_sphere(tank, 0.09, Vector3(radius * 0.72, height * 0.5 + 0.25, 0.0), warning, Vector3.ONE, "TankWarningBeacon")
        ModelKit3D.add_cylinder(industrial_detail, 0.12, 8.0, Vector3(-10.0 + float(index) * 5.0, 4.2, 0.0), rust, Vector3(0.0, 0.0, 1.5708), "GridPipe%02d" % index)
        ModelKit3D.add_cylinder(industrial_detail, 0.19, 0.12, Vector3(-10.0 + float(index) * 5.0, 4.2, -4.0), metal, Vector3(0.0, 0.0, 1.5708), "GridPipeFlange%02d" % index)


func _dress_tenement(root: Node3D) -> void:
    var brick := _textured_material(&"brick", Color("55443d"), 0.0, 0.88)
    var cloth := ModelKit3D.material(Color("6d514b"), 0.0, 0.92)
    var tenement_detail := Node3D.new()
    tenement_detail.name = "HighDefinitionTenementDressing"
    root.add_child(tenement_detail)
    var rail_metal := _textured_material(&"rust", Color("70462f"), 0.4, 0.72)
    var cloth_edge := ModelKit3D.material(Color("9a7065"), 0.0, 0.86)
    for side_index in range(2):
        var side := -1.0 if side_index == 0 else 1.0
        for floor_index in range(4):
            var y := 2.5 + float(floor_index) * 2.35
            var balcony_index := floor_index * 2 + side_index
            var balcony := ModelKit3D.add_beveled_box(tenement_detail, Vector3(9.0, 0.18, 1.2), Vector3(side * 8.5, y, 0.0), brick, Vector3.ZERO, "TenementBalcony%02d" % balcony_index, 0.16)
            for front_back in [-1.0, 1.0]:
                ModelKit3D.add_cylinder(balcony, 0.055, 8.2, Vector3(0.0, 0.66, front_back * 0.5), rail_metal, Vector3(0.0, 0.0, PI * 0.5), "TenementBalconyRail%02d" % balcony_index)
            for post_index in range(3):
                ModelKit3D.add_cylinder(balcony, 0.045, 0.72, Vector3(-3.5 + float(post_index) * 3.5, 0.36, -0.5), rail_metal, Vector3.ZERO, "TenementBalconyPost%02d_%02d" % [balcony_index, post_index])
            ModelKit3D.add_surface_panel(balcony, Vector3(1.4, 0.54, 0.08), Vector3(side * -0.2, 0.48, 0.56), brick, rail_metal, Vector3.ZERO, "TenementBalconyService%02d" % balcony_index)
            ModelKit3D.add_cylinder(balcony, 0.035, 5.0, Vector3(0.0, 0.76, -0.1), rail_metal, Vector3(PI * 0.5, 0.0, 0.0), "TenementClothesline%02d" % balcony_index)
            for cloth_index in range(5):
                ModelKit3D.add_beveled_box(
                    balcony,
                    Vector3(0.55, 0.75, 0.04),
                    Vector3(side * -0.65, 0.54, -2.4 + float(cloth_index) * 1.2),
                    cloth if cloth_index % 2 == 0 else cloth_edge,
                    Vector3(0.0, float(cloth_index) * 0.08, 0.0),
                    "TenementHangingCloth%02d_%02d" % [balcony_index, cloth_index],
                    0.12
                )


func _dress_greenhouse(root: Node3D) -> void:
    var frame := _textured_material(&"metal", Color("405052"), 0.68, 0.4)
    var moss := _textured_material(&"moss", Color("476a49"), 0.0, 0.86)
    var moss_edge := _textured_material(&"moss", Color("6a8b5b"), 0.0, 0.78)
    var glow := _emissive_material(Color("7ce6b2"), 2.8)
    var greenhouse_detail := Node3D.new()
    greenhouse_detail.name = "HighDefinitionGreenhouseDressing"
    root.add_child(greenhouse_detail)
    for index in range(7):
        var x := -12.0 + float(index) * 4.0
        var frame_post := Node3D.new()
        frame_post.name = "GlasshouseFrame%02d" % index
        frame_post.position = Vector3(x, 3.5, 0.0)
        greenhouse_detail.add_child(frame_post)
        ModelKit3D.add_cylinder(frame_post, 0.08, 7.0, Vector3.ZERO, frame, Vector3.ZERO, "FramePost")
        ModelKit3D.add_cylinder(frame_post, 0.055, 8.0, Vector3(0.0, 3.15, 0.0), frame, Vector3(PI * 0.5, 0.0, 0.0), "RoofBeam")
        ModelKit3D.add_cylinder(frame_post, 0.045, 8.0, Vector3(0.0, -3.0, 0.0), frame, Vector3(PI * 0.5, 0.0, 0.0), "BedBeam")
        ModelKit3D.add_beveled_box(frame_post, Vector3(1.15, 0.16, 0.72), Vector3(0.0, 2.45, 0.0), frame, Vector3.ZERO, "ClimateVent", 0.18)
        ModelKit3D.add_organic_plate(
            greenhouse_detail,
            0.8,
            Vector3(x, 0.7, -4.0 + float(index % 3) * 4.0),
            moss,
            moss_edge,
            Vector3(1.3, 0.8, 1.3),
            "GlasshouseOvergrowth%02d" % index
        )
        ModelKit3D.add_sphere(greenhouse_detail, 0.16, Vector3(x + 0.8, 1.2, -3.0 + float(index % 4) * 2.2), glow, Vector3.ONE, "MyceliumGlow%02d" % index)

    var service_layer := Node3D.new()
    service_layer.name = "HighDefinitionGreenhouseServiceLayer"
    greenhouse_detail.add_child(service_layer)
    var service_metal := _textured_material(&"metal", Color("2f3b3c"), 0.62, 0.5)
    var service_rust := _textured_material(&"rust", Color("754936"), 0.38, 0.7)
    var service_concrete := _textured_material(&"concrete", Color("59605d"), 0.0, 0.72)
    var service_cyan := _emissive_material(Color("6fe5dd"), 2.2)
    # A restrained service court gives the Glasshouse a legible civic-climate
    # identity while remaining presentation-only. It is not an operation queue,
    # inventory surface or player-managed production system.
    ModelKit3D.add_beveled_box(
        service_layer,
        Vector3(23.0, 0.18, 1.05),
        Vector3(0.0, 0.18, 5.3),
        service_concrete,
        Vector3.ZERO,
        "GlasshouseServiceWalkway",
        0.18
    )
    for bed_index in range(4):
        var bed_x := -9.0 + float(bed_index) * 6.0
        ModelKit3D.add_beveled_box(
            service_layer,
            Vector3(4.7, 0.24, 0.22),
            Vector3(bed_x, 0.3, -4.05),
            service_rust,
            Vector3.ZERO,
            "GlasshouseServiceBedEdge%02d" % bed_index,
            0.2
        )
        ModelKit3D.add_beveled_box(
            service_layer,
            Vector3(0.22, 0.24, 2.2),
            Vector3(bed_x - 2.15, 0.3, -2.95),
            service_rust,
            Vector3.ZERO,
            "GlasshouseServiceBedBrace%02d" % bed_index,
            0.2
        )
    var tank := Node3D.new()
    tank.name = "GlasshouseIrrigationManifold"
    tank.position = Vector3(10.2, 0.0, 4.0)
    service_layer.add_child(tank)
    ModelKit3D.add_tapered_cylinder(tank, 0.72, 0.86, 2.3, Vector3(0.0, 1.25, 0.0), service_metal, Vector3.ZERO, "GlasshouseServiceTank")
    ModelKit3D.add_tapered_cylinder(tank, 0.48, 0.62, 0.22, Vector3(0.0, 2.52, 0.0), service_rust, Vector3.ZERO, "GlasshouseTankCollar")
    ModelKit3D.add_sphere(tank, 0.13, Vector3(0.0, 1.55, -0.78), service_cyan, Vector3.ONE, "GlasshouseTankSignal")
    ModelKit3D.add_louvered_panel(
        service_layer,
        Vector3(1.75, 1.35, 0.22),
        Vector3(8.35, 1.02, 4.0),
        service_metal,
        service_cyan,
        Vector3.ZERO,
        "GlasshouseClimateConsole",
        4
    )
    ModelKit3D.add_cylinder(service_layer, 0.08, 18.0, Vector3(0.0, 4.35, 2.2), service_metal, Vector3(0.0, 0.0, PI * 0.5), "GlasshouseIrrigationHeader")
    for drop_index in range(5):
        var drop_x := -8.0 + float(drop_index) * 4.0
        ModelKit3D.add_cylinder(service_layer, 0.045, 2.1, Vector3(drop_x, 3.35, 2.2), service_cyan, Vector3.ZERO, "GlasshouseIrrigationDrop%02d" % drop_index)
        ModelKit3D.add_sphere(service_layer, 0.075, Vector3(drop_x, 2.25, 2.2), service_cyan, Vector3.ONE, "GlasshouseIrrigationValve%02d" % drop_index)
    for brace_index in range(3):
        var brace_x := -7.5 + float(brace_index) * 7.5
        ModelKit3D.add_cylinder(service_layer, 0.06, 4.8, Vector3(brace_x, 2.7, -2.6), service_rust, Vector3(0.0, 0.0, 0.34 if brace_index % 2 == 0 else -0.28), "GlasshouseBrokenGlazingBrace%02d" % brace_index)


func _dress_market(root: Node3D) -> void:
    var concrete := _textured_material(&"concrete", Color("4b4e4d"), 0.0, 0.74)
    var membrane := _textured_material(&"membrane", Color("69223e"), 0.0, 0.66)
    var market_detail := Node3D.new()
    market_detail.name = "HighDefinitionMarketDressing"
    root.add_child(market_detail)
    var market_metal := _textured_material(&"metal", Color("3a4546"), 0.64, 0.48)
    var market_rust := _textured_material(&"rust", Color("795039"), 0.38, 0.72)
    var canopy := _textured_material(&"membrane", Color("542138"), 0.02, 0.68)
    for index in range(9):
        var x := -12.0 + float(index % 3) * 12.0
        var z := -10.0 + float(index / 3) * 9.0
        var stall := ModelKit3D.add_beveled_box(
            market_detail,
            Vector3(5.0, 1.2, 3.0),
            Vector3(x, 0.6, z),
            concrete,
            Vector3.ZERO,
            "MarketStall%02d" % index,
            0.16
        )
        # The commercial identity is a market structure with a readable
        # counter, canopy and display hardware, not a new inventory system.
        ModelKit3D.add_beveled_box(
            stall,
            Vector3(3.7, 0.12, 2.55),
            Vector3(0.0, 1.92, 0.0),
            canopy,
            Vector3(0.0, 0.0, 0.035 * float(index % 2)),
            "MarketCanopy%02d" % index,
            0.18
        )
        ModelKit3D.add_louvered_panel(
            stall,
            Vector3(2.6, 0.62, 0.1),
            Vector3(0.0, 1.0, -1.56),
            market_metal,
            market_rust,
            Vector3.ZERO,
            "MarketCounter%02d" % index,
            3
        )
        for corner in [-1.0, 1.0]:
            for front_back in [-1.0, 1.0]:
                ModelKit3D.add_cylinder(
                    stall,
                    0.055,
                    2.0,
                    Vector3(corner * 1.95, 1.0, front_back * 1.08),
                    market_rust,
                    Vector3.ZERO,
                    "MarketCanopyPost%02d_%02d_%02d" % [index, int(corner), int(front_back)]
                )
        for display_index in range(2):
            ModelKit3D.add_beveled_box(
                stall,
                Vector3(0.9, 0.58, 0.76),
                Vector3(-1.35 + float(display_index) * 2.7, 1.08, 0.36),
                market_rust if display_index == 0 else market_metal,
                Vector3(0.0, 0.05 * float(display_index), 0.0),
                "MarketDisplayCrate%02d_%02d" % [index, display_index],
                0.14
            )
        ModelKit3D.add_membrane_fan(
            stall,
            0.72,
            Vector3(1.4, 1.02, 0.0),
            membrane,
            5,
            "MarketMembraneAwning%02d" % index
        )


func _dress_waterfront(root: Node3D) -> void:
    var concrete := _textured_material(&"concrete", Color("3e4546"), 0.0, 0.68)
    var metal := _textured_material(&"rust", Color("73523b"), 0.42, 0.68)
    var waterworks_detail := Node3D.new()
    waterworks_detail.name = "HighDefinitionWaterworksDressing"
    root.add_child(waterworks_detail)
    var dark_metal := _textured_material(&"metal", Color("253438"), 0.72, 0.42)
    var warning := ModelKit3D.material(Color("5b352a"), 0.24, 0.68, Color("d27a44"), 0.42)
    var signal_material := ModelKit3D.material(Color("174b53"), 0.26, 0.3, Color("60d3d4"), 1.1)
    var channel_water := ModelKit3D.material(Color("0b5463"), 0.34, 0.24, Color("2b929a"), 0.28)
    var channel_foam := ModelKit3D.material(Color("6fa7a1"), 0.08, 0.28, Color("9edbd0"), 0.22)
    var channel_edge := _textured_material(&"concrete", Color("273537"), 0.0, 0.8)
    var waterline := Node3D.new()
    waterline.name = "WaterChannelAssembly"
    waterworks_detail.add_child(waterline)
    for channel_index in range(4):
        var channel_x := -10.5 + float(channel_index) * 7.0
        ModelKit3D.add_beveled_box(
            waterline,
            Vector3(1.55, 0.14, 14.8),
            Vector3(channel_x, 0.32, 0.55),
            channel_water,
            Vector3.ZERO,
            "RiverWaterChannel%02d" % channel_index,
            0.12
        )
        for foam_index in range(3):
            var foam_z := -4.0 + float(foam_index) * 4.15 + float(channel_index % 2) * 0.42
            ModelKit3D.add_beveled_box(
                waterline,
                Vector3(0.78, 0.035, 0.18),
                Vector3(channel_x - 0.08 + float(foam_index % 2) * 0.16, 0.42, foam_z),
                channel_foam,
                Vector3(0.0, 0.0, 0.08 * float(foam_index % 2)),
                "RiverWaterFoam%02d_%02d" % [channel_index, foam_index],
                0.12
            )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(
            waterline,
            Vector3(0.34, 1.15, 15.3),
            Vector3(side * 17.2, 0.82, 0.5),
            channel_edge,
            Vector3.ZERO,
            "RiverWaterRetainingWall%s" % ("L" if side < 0.0 else "R"),
            0.16
        )
    var manifold := Node3D.new()
    manifold.name = "WaterworksPipeManifold"
    waterworks_detail.add_child(manifold)
    for pipe_index in range(3):
        var pipe_x := -5.0 + float(pipe_index) * 5.0
        ModelKit3D.add_cylinder(manifold, 0.24, 5.6, Vector3(pipe_x, 2.75, -6.15), metal, Vector3(0.0, 0.0, PI * 0.5), "WaterHeaderPipe%02d" % pipe_index)
        ModelKit3D.add_cylinder(manifold, 0.34, 0.18, Vector3(pipe_x, 2.75, -8.95), dark_metal, Vector3(PI * 0.5, 0.0, 0.0), "WaterHeaderFlange%02d" % pipe_index)
        ModelKit3D.add_surface_panel(manifold, Vector3(0.9, 0.58, 0.12), Vector3(pipe_x, 3.78, -6.15), dark_metal, signal_material, Vector3.ZERO, "WaterHeaderReadout%02d" % pipe_index)
    var sluice := Node3D.new()
    sluice.name = "WaterworksSluiceAssembly"
    waterworks_detail.add_child(sluice)
    ModelKit3D.add_beveled_box(sluice, Vector3(9.8, 2.4, 0.42), Vector3(0.0, 1.22, 7.25), channel_edge, Vector3.ZERO, "WaterSluiceGate", 0.16)
    for rib_index in range(6):
        var rib_x := -4.0 + float(rib_index) * 1.6
        ModelKit3D.add_cylinder(sluice, 0.09, 2.25, Vector3(rib_x, 1.35, 7.03), metal, Vector3.ZERO, "WaterSluiceRib%02d" % rib_index)
    ModelKit3D.add_surface_panel(sluice, Vector3(1.18, 0.72, 0.12), Vector3(5.0, 1.25, 7.0), dark_metal, warning, Vector3.ZERO, "WaterSluiceControlPanel")
    ModelKit3D.add_sphere(sluice, 0.18, Vector3(5.0, 1.78, 6.96), signal_material, Vector3.ONE, "WaterSluiceSignal")
    for index in range(5):
        var x := -14.0 + float(index) * 7.0
        var walkway := ModelKit3D.add_beveled_box(waterworks_detail, Vector3(4.8, 0.65, 12.0), Vector3(x, 0.33, 0.0), concrete, Vector3.ZERO, "PumpWalkway%02d" % index, 0.14)
        for grate_index in range(3):
            ModelKit3D.add_beveled_box(walkway, Vector3(4.0, 0.08, 0.34), Vector3(0.0, 0.38, -3.8 + float(grate_index) * 3.8), dark_metal, Vector3.ZERO, "PumpWalkwayGrate%02d_%02d" % [index, grate_index], 0.12)
        ModelKit3D.add_cylinder(waterworks_detail, 0.22, 5.5, Vector3(x, 3.2, -4.0), metal, Vector3.ZERO, "PumpGantry%02d" % index)
        ModelKit3D.add_cylinder(waterworks_detail, 0.11, 3.7, Vector3(x, 5.55, -4.0), dark_metal, Vector3(0.0, 0.0, PI * 0.5), "PumpGantryCrossbar%02d" % index)
        ModelKit3D.add_cylinder(waterworks_detail, 0.07, 3.0, Vector3(x - 1.1, 4.2, -4.0), warning, Vector3(0.0, 0.0, -0.48), "PumpGantryBrace%02d" % index)
        var housing := ModelKit3D.add_beveled_box(waterworks_detail, Vector3(2.4, 1.6, 2.4), Vector3(x, 0.8, 5.0), metal, Vector3.ZERO, "PumpHousing%02d" % index, 0.16)
        ModelKit3D.add_louvered_panel(housing, Vector3(1.35, 0.78, 0.1), Vector3(0.0, 0.16, -1.22), dark_metal, warning, Vector3.ZERO, "PumpHousingLouver%02d" % index, 3)
        ModelKit3D.add_surface_panel(housing, Vector3(0.7, 0.56, 0.1), Vector3(0.78, 0.48, 1.22), dark_metal, signal_material, Vector3.ZERO, "PumpControlPanel%02d" % index)
        ModelKit3D.add_cylinder(housing, 0.42, 0.86, Vector3(0.0, 1.28, 0.0), dark_metal, Vector3.ZERO, "PumpRotor%02d" % index)
        ModelKit3D.add_cylinder(housing, 0.18, 0.22, Vector3(0.0, 1.78, 0.0), signal_material, Vector3.ZERO, "PumpRotorCap%02d" % index)
        ModelKit3D.add_cylinder(waterworks_detail, 0.1, 4.2, Vector3(x - 1.0, 1.25, 2.3), metal, Vector3(PI * 0.5, 0.0, 0.0), "PumpDischargePipe%02d" % index)
        ModelKit3D.add_glow_light(waterworks_detail, Vector3(x, 2.25, 5.0), Color("54d9df"), 0.72, 5.0)


func _dress_rail(root: Node3D) -> void:
    var metal := _textured_material(&"metal", Color("354043"), 0.72, 0.48)
    var rust := _textured_material(&"rust", Color("794d32"), 0.38, 0.72)
    var dark_glass := ModelKit3D.material(Color("17282d"), 0.26, 0.3, Color("4eaab0"), 0.28)
    var rail_detail := Node3D.new()
    rail_detail.name = "HighDefinitionRailDressing"
    root.add_child(rail_detail)
    for index in range(6):
        var position := Vector3(-18.0 + float(index) * 7.0, 0.0, -5.0 + float(index % 2) * 10.0)
        var heading := Vector3(0.0, 0.16 * float(index % 3), 0.04 * float(index))
        var carriage_material := metal if index % 2 == 0 else rust
        var carriage := ModelKit3D.add_beveled_box(rail_detail, Vector3(6.0, 2.2, 2.5), position + Vector3.UP * 1.1, carriage_material, heading, "DerailedTram%02d" % index, 0.16)
        # Broken window bands establish the carriage scale and preserve a
        # readable cool/warm contrast under the remote-region lighting pass.
        for window_index in range(3):
            var window_x := -1.9 + float(window_index) * 1.9
            ModelKit3D.add_beveled_box(
                carriage,
                Vector3(1.18, 0.52, 0.07),
                Vector3(window_x, 1.38, -1.27),
                dark_glass if window_index != index % 3 else rust,
                Vector3(0.0, 0.0, 0.02 * float(window_index % 2)),
                "TramWindow%02d_%02d" % [index, window_index],
                0.12
            )
        ModelKit3D.add_surface_panel(
            carriage,
            Vector3(1.35, 0.62, 0.08),
            Vector3(0.0, 0.88, 1.28),
            metal,
            rust,
            Vector3.ZERO,
            "TramServicePanel%02d" % index
        )
        ModelKit3D.add_beveled_box(carriage, Vector3(1.2, 0.22, 0.72), Vector3(0.0, 2.32, 0.0), metal, Vector3.ZERO, "TramRoofVent%02d" % index, 0.18)
        for bogie_index in range(2):
            var bogie_x := -1.65 + float(bogie_index) * 3.3
            ModelKit3D.add_beveled_box(carriage, Vector3(1.1, 0.18, 1.5), Vector3(bogie_x, -0.12, 0.0), rust, Vector3.ZERO, "TramBogiePlate%02d_%02d" % [index, bogie_index], 0.16)
            ModelKit3D.add_cylinder(carriage, 0.22, 1.46, Vector3(bogie_x, -0.28, 0.0), metal, Vector3(0.0, 0.0, PI * 0.5), "TramAxle%02d_%02d" % [index, bogie_index])
        ModelKit3D.add_cylinder(root, 0.05, 8.0, position + Vector3.UP * 5.0, rust, Vector3(0.0, 0.0, 1.5708), "OverheadLine")


func _dress_nest(root: Node3D) -> void:
    var chitin := _textured_material(&"chitin", Color("302028"), 0.05, 0.66)
    var membrane := _textured_material(&"membrane", Color("6d173b"), 0.0, 0.62)
    for index in range(12):
        var angle := TAU * float(index) / 12.0
        var radius := 7.0 + float(index % 4) * 2.5
        ModelKit3D.add_capsule(root, 0.18, 4.5 + float(index % 3), Vector3(cos(angle) * radius, 2.0, sin(angle) * radius), chitin, Vector3(0.0, -angle, 0.35), "NestSpine")
        ModelKit3D.add_sphere(root, 0.7, Vector3(cos(angle) * radius * 0.72, 0.7, sin(angle) * radius * 0.72), membrane, Vector3(1.4, 0.8, 1.4), "BroodSac")


func _dress_observatory(root: Node3D) -> void:
    var metal := _textured_material(&"metal", Color("3b474b"), 0.68, 0.42)
    var observatory_detail := Node3D.new()
    observatory_detail.name = "HighDefinitionObservatoryDressing"
    root.add_child(observatory_detail)
    var dark_metal := _textured_material(&"metal", Color("202d31"), 0.78, 0.34)
    var rust := _textured_material(&"rust", Color("754a32"), 0.38, 0.7)
    var signal_material := ModelKit3D.material(Color("1e5964"), 0.26, 0.26, Color("73d9e8"), 1.3)
    ModelKit3D.add_cylinder(observatory_detail, 3.2, 2.0, Vector3(0.0, 1.0, 0.0), metal, Vector3.ZERO, "ObservatoryBase")
    ModelKit3D.add_beveled_box(observatory_detail, Vector3(5.8, 0.22, 4.8), Vector3(0.0, 0.16, 0.0), dark_metal, Vector3.ZERO, "ObservatoryServiceDeck", 0.18)
    ModelKit3D.add_surface_panel(observatory_detail, Vector3(1.25, 0.68, 0.1), Vector3(0.0, 0.9, -3.1), dark_metal, signal_material, Vector3.ZERO, "ObservatoryAccessPanel")
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(observatory_detail, 0.1, 3.8, Vector3(side * 2.45, 1.75, 0.0), rust, Vector3(0.0, 0.0, side * 0.42), "ObservatoryTripodBrace")
    ModelKit3D.add_sphere(observatory_detail, 3.6, Vector3(0.0, 4.3, 0.0), metal, Vector3(1.0, 0.26, 1.0), "ObservatoryDish")
    for rib_index in range(8):
        var rib_angle := TAU * float(rib_index) / 8.0
        ModelKit3D.add_capsule(
            observatory_detail,
            0.08,
            5.8,
            Vector3(cos(rib_angle) * 2.75, 4.3 + sin(rib_angle) * 0.48, sin(rib_angle) * 2.75),
            rust,
            Vector3(0.0, -rib_angle, 0.18 * cos(rib_angle)),
            "ObservatoryDishRib%02d" % rib_index
        )
    ModelKit3D.add_cylinder(observatory_detail, 0.18, 5.0, Vector3(0.0, 6.0, 0.0), metal, Vector3(0.4, 0.0, 0.0), "DishFeed")
    ModelKit3D.add_cylinder(observatory_detail, 0.28, 0.34, Vector3(0.0, 8.32, 0.0), signal_material, Vector3.ZERO, "DishReceiverLens")
    ModelKit3D.add_beveled_box(observatory_detail, Vector3(0.82, 0.14, 0.82), Vector3(0.0, 3.62, 0.0), rust, Vector3.ZERO, "ObservatoryDishHub", 0.18)


func _dress_research(root: Node3D) -> void:
    var concrete := _textured_material(&"concrete", Color("3f4243"), 0.0, 0.7)
    var metal := _textured_material(&"metal", Color("3c4749"), 0.65, 0.42)
    var glow := _emissive_material(Color("6bc9d0"), 2.6)
    var research_detail := Node3D.new()
    research_detail.name = "HighDefinitionResearchDressing"
    root.add_child(research_detail)
    var dark_metal := _textured_material(&"metal", Color("202c30"), 0.78, 0.34)
    var warning := _textured_material(&"rust", Color("70412e"), 0.38, 0.68)
    var glass := ModelKit3D.material(Color("1c5660"), 0.26, 0.24, Color("6be1e6"), 1.2)
    for index in range(8):
        var angle := TAU * float(index) / 8.0
        var console := ModelKit3D.add_beveled_box(
            research_detail,
            Vector3(3.2, 2.0, 1.4),
            Vector3(cos(angle) * 10.0, 1.0, sin(angle) * 10.0),
            concrete,
            Vector3(0.0, -angle, 0.0),
            "LabConsole%02d" % index,
            0.16
        )
        # The research identity is a containment workstation with readable
        # ports and instrument panels, not a new simulated laboratory job.
        ModelKit3D.add_surface_panel(
            console,
            Vector3(1.8, 0.72, 0.1),
            Vector3(0.0, 0.68, -0.72),
            dark_metal,
            glow,
            Vector3.ZERO,
            "LabDisplay%02d" % index
        )
        ModelKit3D.add_louvered_panel(
            console,
            Vector3(1.3, 0.82, 0.12),
            Vector3(0.0, -0.18, 0.72),
            dark_metal,
            warning,
            Vector3.ZERO,
            "LabCoolingLouver%02d" % index,
            3
        )
        ModelKit3D.add_surface_panel(
            console,
            Vector3(0.74, 0.56, 0.1),
            Vector3(1.18, 0.42, 0.72),
            metal,
            warning,
            Vector3.ZERO,
            "LabSamplePort%02d" % index
        )
        var vessel_position := Vector3(cos(angle) * 6.0, 1.7, sin(angle) * 6.0)
        ModelKit3D.add_tapered_cylinder(
            research_detail,
            0.2,
            0.27,
            3.4,
            vessel_position,
            metal,
            Vector3.ZERO,
            "LabContainmentVessel%02d" % index
        )
        ModelKit3D.add_cylinder(
            research_detail,
            0.09,
            2.6,
            vessel_position + Vector3.UP * 0.05,
            glass,
            Vector3.ZERO,
            "LabContainmentCore%02d" % index
        )
        ModelKit3D.add_beveled_box(
            research_detail,
            Vector3(0.68, 0.12, 0.68),
            vessel_position + Vector3.UP * 1.78,
            warning,
            Vector3.ZERO,
            "LabContainmentCap%02d" % index,
            0.18
        )


func _dress_cistern(root: Node3D) -> void:
    var concrete := _textured_material(&"concrete", Color("30383a"), 0.0, 0.68)
    var membrane := _textured_material(&"membrane", Color("631431"), 0.0, 0.58)
    var metal := _textured_material(&"metal", Color("263437"), 0.74, 0.4)
    var rust := _textured_material(&"rust", Color("72432f"), 0.42, 0.7)
    var glow := _emissive_material(Color("d33f67"), 3.2)
    var cool_signal := ModelKit3D.material(Color("17464b"), 0.28, 0.3, Color("61dfe0"), 1.5)
    ModelKit3D.add_cylinder(root, 18.0, 0.8, Vector3(0.0, 0.4, 0.0), concrete, Vector3.ZERO, "CisternBasin")
    for index in range(14):
        var angle := TAU * float(index) / 14.0
        var radius := 8.0 + float(index % 3) * 3.4
        ModelKit3D.add_capsule(root, 0.28, 6.0 + float(index % 4), Vector3(cos(angle) * radius, 2.5, sin(angle) * radius), membrane, Vector3(0.0, -angle, 0.55), "RootPylon")
        ModelKit3D.add_sphere(root, 0.12, Vector3(cos(angle) * radius * 0.72, 3.1, sin(angle) * radius * 0.72), glow, Vector3.ONE, "RootSignal")

    # The basin is the late-game approach landmark. Add one bounded municipal
    # service layer so it reads as a buried pumping installation overtaken by
    # the living relay, rather than a circular arena with repeated pylons.
    var depth_detail := Node3D.new()
    depth_detail.name = "HighDefinitionCisternDressing"
    root.add_child(depth_detail)
    ModelKit3D.add_cylinder(depth_detail, 12.8, 0.18, Vector3(0.0, 0.86, 0.0), metal, Vector3.ZERO, "CisternServiceRing")
    ModelKit3D.add_cylinder(depth_detail, 10.6, 0.1, Vector3(0.0, 0.97, 0.0), cool_signal, Vector3.ZERO, "CisternSignalRing")
    var control := Node3D.new()
    control.name = "CisternControlWalkway"
    depth_detail.add_child(control)
    ModelKit3D.add_beveled_box(control, Vector3(7.8, 0.22, 1.5), Vector3(0.0, 1.22, -8.6), concrete, Vector3.ZERO, "CisternControlDeck", 0.16)
    for index in range(5):
        ModelKit3D.add_beveled_box(control, Vector3(1.12, 0.06, 1.1), Vector3(-2.8 + float(index) * 1.4, 1.37, -8.6), metal, Vector3.ZERO, "CisternDeckGrate%02d" % index, 0.08)
    ModelKit3D.add_surface_panel(control, Vector3(1.8, 0.9, 0.1), Vector3(0.0, 1.86, -8.02), metal, cool_signal, Vector3.ZERO, "CisternProtocolPanel")
    ModelKit3D.add_beveled_box(control, Vector3(2.6, 0.12, 0.12), Vector3(0.0, 2.34, -8.0), rust, Vector3.ZERO, "CisternPanelHeader", 0.06)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(control, 0.08, 1.8, Vector3(side * 3.3, 2.0, -8.0), rust, Vector3.ZERO, "CisternPanelBrace%s" % ("L" if side < 0.0 else "R"))
    var pump_housing := ModelKit3D.add_beveled_box(depth_detail, Vector3(4.6, 2.2, 2.8), Vector3(0.0, 1.45, 8.4), concrete, Vector3.ZERO, "CisternPumpHousing", 0.22)
    ModelKit3D.add_louvered_panel(pump_housing, Vector3(2.3, 0.92, 0.1), Vector3(0.0, 0.6, -1.46), metal, rust, Vector3.ZERO, "CisternPumpLouver", 5)
    ModelKit3D.add_surface_panel(pump_housing, Vector3(0.95, 0.62, 0.1), Vector3(1.25, 1.05, -1.48), metal, cool_signal, Vector3.ZERO, "CisternPumpReadout")
    for index in range(3):
        var pipe_x := -1.35 + float(index) * 1.35
        ModelKit3D.add_cylinder(depth_detail, 0.16, 4.6, Vector3(pipe_x, 3.05, 5.7), metal, Vector3(PI * 0.5, 0.0, 0.0), "CisternHeaderPipe%02d" % index)
        ModelKit3D.add_cylinder(depth_detail, 0.22, 0.12, Vector3(pipe_x, 3.05, 3.38), rust, Vector3(PI * 0.5, 0.0, 0.0), "CisternHeaderFlange%02d" % index)
    for index in range(6):
        var angle := TAU * float(index) / 6.0 + PI / 6.0
        var radius := 9.5
        var position := Vector3(cos(angle) * radius, 1.4, sin(angle) * radius)
        ModelKit3D.add_beveled_box(depth_detail, Vector3(1.8, 0.16, 0.72), position, rust, Vector3(0.0, -angle, 0.0), "CisternRootAnchor%02d" % index, 0.1)
        ModelKit3D.add_sphere(depth_detail, 0.14, position + Vector3.UP * 0.18, glow, Vector3.ONE, "CisternAnchorPulse%02d" % index)


func _dress_archive(root: Node3D) -> void:
    var brick := _textured_material(&"brick", Color("504840"), 0.0, 0.82)
    var grime := _textured_material(&"grime", Color("4b443c"), 0.0, 0.88)
    var archive_detail := Node3D.new()
    archive_detail.name = "HighDefinitionArchiveDressing"
    root.add_child(archive_detail)
    var glass := ModelKit3D.material(Color("1b2c31"), 0.2, 0.34, Color("6dbac0"), 0.24)
    var service_metal := _textured_material(&"metal", Color("3d4546"), 0.64, 0.5)
    var paper := _textured_material(&"concrete", Color("6d6253"), 0.0, 0.92)
    for index in range(6):
        var height := 5.0 + float(index % 3) * 2.0
        var position := Vector3(-12.0 + float(index) * 4.8, 2.5, -3.0 + float(index % 2) * 6.0)
        var rotation := Vector3(0.0, 0.08 * float(index), 0.0)
        var fragment_material := brick if index % 2 == 0 else grime
        var fragment := ModelKit3D.add_beveled_box(
            archive_detail,
            Vector3(4.0, height, 3.2),
            position,
            fragment_material,
            rotation,
            "ArchiveFragment%02d" % index,
            0.16
        )
        # Archive identity is carried by readable records bays and service
        # hardware, not by a new interaction or simulated inventory system.
        for bay_index in range(2):
            var bay_x := -1.05 + float(bay_index) * 2.1
            ModelKit3D.add_beveled_box(
                fragment,
                Vector3(1.42, minf(1.35, height * 0.22), 0.08),
                Vector3(bay_x, height * 0.1, -1.63),
                glass if bay_index != index % 2 else paper,
                Vector3.ZERO,
                "ArchiveWindow%02d_%02d" % [index, bay_index],
                0.1
            )
        ModelKit3D.add_louvered_panel(
            fragment,
            Vector3(1.2, 1.05, 0.12),
            Vector3(0.0, -0.62, 1.63),
            service_metal,
            paper,
            Vector3.ZERO,
            "ArchiveRecordsShutter%02d" % index,
            4
        )
        ModelKit3D.add_beveled_box(
            fragment,
            Vector3(2.75, 0.16, 1.86),
            Vector3(0.0, height * 0.5 + 0.06, 0.0),
            grime,
            Vector3(0.0, 0.0, 0.02 * float(index % 2)),
            "ArchiveRoofSlab%02d" % index,
            0.18
        )
        ModelKit3D.add_surface_panel(
            fragment,
            Vector3(0.9, 0.62, 0.1),
            Vector3(1.28, 0.78, 1.66),
            service_metal,
            paper,
            Vector3.ZERO,
            "ArchiveServiceRiser%02d" % index
        )
        for rail_index in range(2):
            ModelKit3D.add_cylinder(
                fragment,
                0.045,
                1.45,
                Vector3(-1.35 + float(rail_index) * 2.7, 1.12, 1.66),
                service_metal,
                Vector3(PI * 0.5, 0.0, 0.0),
                "ArchiveFilingRail%02d_%02d" % [index, rail_index]
            )


func _textured_material(texture_id: StringName, tint: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var material := ModelKit3D.material(tint, metallic, roughness)
    var texture: Texture2D = textures.get(texture_id, null)
    if texture != null:
        material.albedo_texture = texture
        material.uv1_triplanar = true
        material.uv1_world_triplanar = true
        material.uv1_scale = _uv_scale(texture_id)
    return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
    return ModelKit3D.material(color.darkened(0.65), 0.0, 0.38, color, energy)
