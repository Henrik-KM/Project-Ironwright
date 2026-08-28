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
const AUTHORED_ORGANIC_TINTS: Dictionary = {
    "veilstalker": Color("8b9aa3"),
    "razorhound": Color("a27d68"),
    "sporecaster": Color("98a86b"),
    "broodmass": Color("756879"),
    "burrower": Color("a39277"),
    "skitterling": Color("78a9a9"),
    "apex": Color("875b53"),
    "roofleaper": Color("78aeb7"),
    "glassmoth": Color("78c8c8"),
    "miremaw": Color("9eac78"),
    # Late families use a lower-saturation, mineral-biological palette so the
    # wet shell, living membranes and threat accents separate in the tactical
    # frame instead of reading as bright toy-coloured plates.
    # Keep the shared membrane atlas for vascular breakup, but push the four
    # late terrestrial families into clearly different mineral-biological
    # colour lanes. This is a material-only presentation pass: authored mesh
    # density, sockets, animation and gameplay scale remain unchanged.
    "carrionbell": Color("8e5268"),
    "rootweaver": Color("3f7953"),
    "thornback": Color("ad7f4e"),
    "ashmantle": Color("547b8b"),
}

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
    if region_lod == null:
        return
    if region_lod.has_signal(&"detail_changed"):
        var detail_callback := Callable(self, "_on_region_detail_changed")
        if not region_lod.is_connected(&"detail_changed", detail_callback):
            region_lod.connect(&"detail_changed", detail_callback)
    if region_lod.has_signal(&"region_stream_changed"):
        var stream_callback := Callable(self, "_on_region_stream_changed")
        if not region_lod.is_connected(&"region_stream_changed", stream_callback):
            region_lod.connect(&"region_stream_changed", stream_callback)
    for raw_region_id in region_dressing_roots:
        var region_id := raw_region_id as StringName
        var detail_level := 0
        if region_lod.has_method(&"detail_mode_for"):
            detail_level = int(region_lod.call(&"detail_mode_for", region_id))
        _on_region_detail_changed(region_id, detail_level)
        if region_lod.has_method(&"is_region_streamed"):
            _on_region_stream_changed(region_id, bool(region_lod.call(&"is_region_streamed", region_id)))


func _on_region_detail_changed(region_id: StringName, detail_level: int) -> void:
    var root := region_dressing_roots.get(region_id) as Node3D
    if root == null or not is_instance_valid(root):
        return
    # PersistentRegionGeometry owns the reduced landmark proxy. The release
    # dressing is the close-range authored layer, so it must disappear outside
    # the full-detail radius instead of silently keeping every remote mesh live.
    root.visible = detail_level <= 0


func _on_region_stream_changed(region_id: StringName, streamed_in: bool) -> void:
    var root := region_dressing_roots.get(region_id) as Node3D
    if root == null or not is_instance_valid(root):
        return
    if streamed_in:
        if not _has_region_dressing_content(root):
            _rebuild_region_dressing(region_id, root)
        return
    # The landmark keeps its gameplay state and coarse proxy. Only the
    # release-only close dressing is removed from the active scene tree.
    for child in root.get_children():
        child.free()


func _rebuild_region_dressing(region_id: StringName, root: Node3D) -> void:
    var data := region_director.get_region_data(region_id)
    if data.is_empty():
        return
    var kind := StringName(str(data.get("kind", "urban")))
    _dress_region_contents(kind, root)


func ensure_region_dressing(region_id: StringName) -> Node3D:
    var root := region_dressing_roots.get(region_id) as Node3D
    if root == null or not is_instance_valid(root):
        return null
    if not _has_region_dressing_content(root):
        _rebuild_region_dressing(region_id, root)
    return root


func _has_region_dressing_content(root: Node3D) -> bool:
    for child in root.get_children():
        if child.name != &"ReleaseSecondaryMotion3D":
            return true
    return false


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
        var authored_path := str(mesh_instance.get_path()).to_lower()
        var authored_tint := _organic_family_tint_for_mesh(mesh_instance, authored_path)
        if authored_tint != Color.WHITE:
            # Keep the release normal/texture pass and species palette, but do
            # not flatten an authored creature into one dark colour band. The
            # compact gallery is a real production gate: plates, ribs and
            # spines need to catch the key as structural anatomy, while
            # membranes and vascular details need a separate living lift.
            var detail_name := String(mesh_instance.name).to_lower()
            var structural_detail := _contains_any(detail_name, ["plate", "rib", "ridge", "spine", "hook", "knuckle", "fastener", "bone", "frame", "ray", "cap", "leg", "arm", "talon", "jaw", "tiercrest", "tierdorsal", "tiercrown"])
            if structural_detail:
                # The chitin atlas is intentionally dark and patterned for wet flesh.
                # Applying it to bone, ribs and limbs made every family read as a
                # stack of black manufactured bars. Preserve the family tint and
                # normal material contract for living surfaces, but let structural
                # anatomy use a clean authored albedo so it separates in key light.
                material.albedo_texture = null
                material.normal_enabled = false
                material.normal_texture = null
            material.albedo_color = _organic_detail_tint(mesh_instance, authored_tint, category)
            _tune_organic_surface_finish(material, category, detail_name)
    mesh_instance.material_override = material
    mesh_instance.visibility_range_end = 250.0
    mesh_instance.set_meta(&"release_material_family", category)
    meshes_textured += 1


func _texture_category(mesh_instance: MeshInstance3D) -> StringName:
    var path_text := str(mesh_instance.get_path()).to_lower()
    var name_text := String(mesh_instance.name).to_lower()
    var combined := "%s %s" % [path_text, name_text]
    if mesh_instance.name == "ObservatoryDish":
        # The authored hero reflector carries its own dark blue-violet material.
        # Preserve that surface instead of replacing it with the generic metal atlas.
        return &""
    # The Mechromancer is an authored field kit, not a machine chassis. Its
    # imported materials deliberately separate worn coat, leather, skin,
    # oxidized hardware, visor glass, utility light and the weak sidearm.
    # Preserve those source materials instead of letting the broad machine
    # texture heuristic flatten every player mesh into one metal family.
    if "mechromancer" in combined:
        return &""
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


func _organic_family_tint(path_text: String) -> Color:
    for family_token in AUTHORED_ORGANIC_TOKENS:
        if family_token in path_text:
            return AUTHORED_ORGANIC_TINTS.get(family_token, Color.WHITE)
    return Color.WHITE


func _organic_family_tint_for_mesh(mesh_instance: MeshInstance3D, path_text: String) -> Color:
    var current: Node = mesh_instance
    while current != null:
        if current.has_meta(&"ironwright_organic_family"):
            var family := String(current.get_meta(&"ironwright_organic_family"))
            return AUTHORED_ORGANIC_TINTS.get(family, Color.WHITE)
        current = current.get_parent()
    return _organic_family_tint(path_text)


func _organic_detail_tint(mesh_instance: MeshInstance3D, family_tint: Color, category: StringName) -> Color:
    var detail_name := String(mesh_instance.name).to_lower()
    if category == &"membrane" or _contains_any(detail_name, ["membrane", "fan", "gill", "fin", "wing", "mantle", "spore", "vein"]):
        var authored_path := str(mesh_instance.get_path()).to_lower()
        # Late-family membranes are already broad and layered; a smaller lift
        # keeps them living and translucent without turning the gallery into a
        # row of pale manufactured plates. Early flight membranes retain the
        # stronger lift needed for compact silhouette separation.
        var late_family := _contains_any(authored_path, ["miremaw", "carrionbell", "rootweaver", "thornback", "ashmantle"])
        return family_tint.lightened(0.055 if late_family else 0.16)
    if _contains_any(detail_name, ["plate", "rib", "ridge", "spine", "hook", "knuckle", "fastener", "bone", "frame", "ray", "cap", "leg", "arm", "talon", "jaw", "tiercrest", "tierdorsal", "tiercrown"]):
        return family_tint.darkened(0.16)
    if _contains_any(detail_name, ["eye", "oculus", "resonator", "siphon", "tendon", "tiervascular", "tiersignal"]):
        return family_tint.lightened(0.22)
    return family_tint.darkened(0.06)


func _tune_organic_surface_finish(material: StandardMaterial3D, category: StringName, detail_name: String) -> void:
    # The authored shells already carry dense geometry and normal relief. A
    # restrained clearcoat/rim pass gives wet chitin and living membrane a
    # continuous highlight rolloff, so the close review gallery reads as
    # biological material instead of flat colour blocks. Keep the strengths
    # deliberately low: the Heartforge and danger signals must remain the
    # brightest focal accents in the tactical frame.
    var membrane := category == &"membrane"
    material.rim_enabled = true
    material.rim = 0.075 if membrane else 0.105
    material.rim_tint = 0.38 if membrane else 0.28
    material.clearcoat_enabled = true
    material.clearcoat = 0.055 if membrane else (0.12 if _contains_any(detail_name, ["torso", "core", "segment", "shell"]) else 0.08)
    material.clearcoat_roughness = 0.46 if membrane else 0.34
    material.set_meta(&"release_organic_surface_finish", "membrane_rim_clearcoat" if membrane else "chitin_rim_clearcoat")


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
    var string_light_material := _emissive_material(Color("ff8a3b"), 0.78)
    for index in range(16):
        var angle := TAU * float(index) / 16.0
        var radius := 7.2 + float(index % 3) * 1.4
        ModelKit3D.add_sphere(root, 0.055, Vector3(cos(angle) * radius, 2.5 + sin(float(index) * 0.7) * 0.35, sin(angle) * radius), string_light_material, Vector3.ONE, "SanctuaryStringLight")
    regions_dressed += 1


func _dress_region(region_id: StringName) -> void:
    var data := region_director.get_region_data(region_id)
    if data.is_empty() or region_id == &"region.heartforge_district":
        return
    var center := region_director.center(region_id)
    var kind := StringName(str(data.get("kind", "urban")))
    var root := _region_root("Release_%s" % String(region_id).replace("region.", "").to_pascal_case(), center)
    region_dressing_roots[region_id] = root
    regions_dressed += 1
    # Keep the authored high-definition encounter layer bounded during boot.
    # The persistent landmark and coarse proxy remain available for every
    # region; close dressing is rebuilt automatically when the LOD director
    # streams a region into the focus ring.
    if not _is_region_streamed(region_id):
        return
    _dress_region_contents(kind, root)


func _is_region_streamed(region_id: StringName) -> bool:
    if world == null or not is_instance_valid(world):
        return true
    var region_lod := world.get_node_or_null("RegionPresentationLodDirector")
    if region_lod != null and region_lod.has_method(&"is_region_streamed"):
        return bool(region_lod.call(&"is_region_streamed", region_id))
    return true


func _dress_region_contents(kind: StringName, root: Node3D) -> void:
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
    # The tank field needs one unmistakable switchyard face so the district
    # reads as a failed power station rather than a collection of cylinders.
    # Keep the assembly shallow and presentation-only: it adds no power graph,
    # interaction, collision or repair task.
    var switchyard := Node3D.new()
    switchyard.name = "GridSwitchyardFocal"
    industrial_detail.add_child(switchyard)
    var switch_dark := _textured_material(&"metal", Color("202b2f"), 0.78, 0.36)
    var switch_edge := _textured_material(&"rust", Color("8a5638"), 0.42, 0.62)
    var porcelain := _textured_material(&"ceramic", Color("b4b0a3"), 0.16, 0.5)
    var switch_signal := _emissive_material(Color("f0a24c"), 1.7)
    ModelKit3D.add_beveled_box(switchyard, Vector3(4.6, 0.22, 2.4), Vector3(0.0, 0.22, 2.35), switch_dark, Vector3.ZERO, "GridSwitchyardFoundation", 0.12)
    ModelKit3D.add_beveled_box(switchyard, Vector3(3.2, 1.45, 1.1), Vector3(0.0, 1.05, 2.35), metal, Vector3.ZERO, "GridTransformerBody", 0.18)
    ModelKit3D.add_louvered_panel(switchyard, Vector3(1.65, 0.62, 0.1), Vector3(0.0, 1.08, 2.92), switch_dark, switch_edge, Vector3.ZERO, "GridTransformerCoolingPanel", 5)
    ModelKit3D.add_surface_panel(switchyard, Vector3(0.86, 0.5, 0.1), Vector3(1.0, 1.3, 2.94), switch_dark, switch_signal, Vector3.ZERO, "GridTransformerWarningPanel")
    ModelKit3D.add_beveled_box(switchyard, Vector3(4.8, 0.16, 0.18), Vector3(0.0, 3.35, 2.25), switch_edge, Vector3.ZERO, "GridSwitchyardBusRail", 0.06)
    for bushing_index in range(3):
        var bushing_x := -1.2 + float(bushing_index) * 1.2
        ModelKit3D.add_cylinder(switchyard, 0.16, 1.42, Vector3(bushing_x, 4.08, 2.25), porcelain, Vector3.ZERO, "GridSwitchyardBushing%02d" % bushing_index)
        ModelKit3D.add_torus(switchyard, 0.21, 0.045, Vector3(bushing_x, 4.48, 2.25), switch_edge, Vector3.ZERO, "GridSwitchyardBushingCollar%02d" % bushing_index, 16, 6)
        ModelKit3D.add_sphere(switchyard, 0.11, Vector3(bushing_x, 4.86, 2.25), switch_signal, Vector3.ONE, "GridSwitchyardBushingBeacon%02d" % bushing_index)


func _dress_tenement(root: Node3D) -> void:
    var brick := _textured_material(&"brick", Color("55443d"), 0.0, 0.88)
    # The residential laundry should feel sun-faded and inhabited, not like a
    # repeated row of bright pink UI cards. Keep three low-saturation fabric
    # tones so the panels read as distinct cloth without stealing focus from
    # the windows and fire escapes.
    var cloth_variants: Array[StandardMaterial3D] = [
        ModelKit3D.material(Color("383938"), 0.0, 0.94),
        ModelKit3D.material(Color("30484a"), 0.0, 0.94),
        ModelKit3D.material(Color("5b5549"), 0.0, 0.95),
    ]
    var tenement_detail := Node3D.new()
    tenement_detail.name = "HighDefinitionTenementDressing"
    root.add_child(tenement_detail)
    var rail_metal := _textured_material(&"rust", Color("70462f"), 0.4, 0.72)
    for side_index in range(2):
        var side := -1.0 if side_index == 0 else 1.0
        var facade_z := 2.94 if side < 0.0 else 5.34
        for floor_index in range(4):
            var y := 1.25 + float(floor_index) * 2.25
            var balcony_index := floor_index * 2 + side_index
            # The authored blocks sit at x +/-5 with their approach faces at
            # z 2.5 and 4.9. Keep the release dressing on those same faces so
            # balconies read as attached residential infrastructure instead of
            # detached rails floating behind the landmark.
            var balcony := ModelKit3D.add_beveled_box(tenement_detail, Vector3(4.6, 0.18, 0.92), Vector3(side * 5.0, y, facade_z), brick, Vector3.ZERO, "TenementBalcony%02d" % balcony_index, 0.16)
            for front_back in [-1.0, 1.0]:
                ModelKit3D.add_cylinder(balcony, 0.055, 4.1, Vector3(0.0, 0.66, front_back * 0.38), rail_metal, Vector3(0.0, 0.0, PI * 0.5), "TenementBalconyRail%02d" % balcony_index)
            for post_index in range(3):
                ModelKit3D.add_cylinder(balcony, 0.045, 0.72, Vector3(-1.7 + float(post_index) * 1.7, 0.36, 0.38), rail_metal, Vector3.ZERO, "TenementBalconyPost%02d_%02d" % [balcony_index, post_index])
            ModelKit3D.add_surface_panel(balcony, Vector3(1.4, 0.54, 0.08), Vector3(side * -0.2, 0.48, 0.42), brick, rail_metal, Vector3.ZERO, "TenementBalconyService%02d" % balcony_index)
            ModelKit3D.add_cylinder(balcony, 0.035, 5.0, Vector3(0.0, 0.76, -0.1), rail_metal, Vector3(PI * 0.5, 0.0, 0.0), "TenementClothesline%02d" % balcony_index)
            for cloth_index in range(3):
                var cloth_panel := ModelKit3D.add_beveled_box(
                    balcony,
                    Vector3(0.34 + 0.04 * float(cloth_index % 2), 0.50 + 0.06 * float((balcony_index + cloth_index) % 2), 0.04),
                    Vector3(-0.85 + float(cloth_index) * 0.85, 0.42, 0.42),
                    cloth_variants[(balcony_index + cloth_index) % cloth_variants.size()],
                    Vector3(0.0, float(cloth_index) * 0.08, 0.0),
                    "TenementHangingCloth%02d_%02d" % [balcony_index, cloth_index],
                    0.12
                )
                cloth_panel.scale = Vector3(1.0, 1.0, 0.82 + 0.08 * float((balcony_index + cloth_index) % 3))
    # The two residential blocks need one shared human-scale threshold so the
    # district reads as a lived-in court rather than mirrored facade slabs.
    # Keep the entry shallow and presentation-only: it is not a new doorway,
    # collision volume, route or interactable destination.
    var court := Node3D.new()
    court.name = "TenementCourtThreshold"
    tenement_detail.add_child(court)
    var court_brick := _textured_material(&"brick", Color("4f3f3b"), 0.0, 0.9)
    var court_metal := _textured_material(&"metal", Color("2e3a3c"), 0.62, 0.5)
    var court_signal := ModelKit3D.material(Color("1d4d55"), 0.24, 0.34, Color("64c7cf"), 0.28)
    ModelKit3D.add_beveled_box(
        court,
        Vector3(2.55, 3.65, 0.26),
        Vector3(0.0, 2.22, 4.34),
        court_brick,
        Vector3.ZERO,
        "TenementCourtEntry",
        0.16
    )
    ModelKit3D.add_beveled_box(
        court,
        Vector3(3.35, 0.22, 1.32),
        Vector3(0.0, 4.18, 4.62),
        court_metal,
        Vector3(0.0, 0.0, 0.04),
        "TenementCourtCanopy",
        0.12
    )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(
            court,
            0.07,
            2.9,
            Vector3(side * 1.28, 2.0, 4.7),
            court_metal,
            Vector3.ZERO,
            "TenementCourtRail%s" % ("L" if side < 0.0 else "R")
        )
    ModelKit3D.add_surface_panel(
        court,
        Vector3(1.18, 1.54, 0.10),
        Vector3(0.0, 1.72, 4.52),
        court_metal,
        court_signal,
        Vector3.ZERO,
        "TenementCourtServicePanel"
    )
    ModelKit3D.add_beveled_box(
        court,
        Vector3(1.46, 0.12, 0.18),
        Vector3(0.0, 3.32, 4.56),
        court_metal,
        Vector3.ZERO,
        "TenementCourtAddressRail",
        0.05
    )
    ModelKit3D.add_sphere(
        court,
        0.13,
        Vector3(0.0, 4.02, 4.76),
        court_signal,
        Vector3.ONE,
        "TenementCourtLight"
    )


func _dress_greenhouse(root: Node3D) -> void:
    var frame := _textured_material(&"metal", Color("405052"), 0.68, 0.4)
    var moss := _textured_material(&"moss", Color("476a49"), 0.0, 0.86)
    var moss_edge := _textured_material(&"moss", Color("6a8b5b"), 0.0, 0.78)
    # Keep the living cultivation cues luminous without blooming into white
    # review spots that erase the glass, frame and growth-bed hierarchy.
    var glow := _emissive_material(Color("54c99a"), 0.32)
    # The authored Glasshouse shell already has the correct frame, growth beds
    # and service sockets. Give the release dressing a readable climate volume
    # as well: thin cold-glass bays and a split roof canopy catch the blue-hour
    # key without turning the structure into an opaque box. This remains a
    # bounded presentation layer; it adds no collision, routing or simulation.
    var cold_glass := StandardMaterial3D.new()
    cold_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    cold_glass.albedo_color = Color(0.10, 0.30, 0.32, 0.09)
    cold_glass.metallic = 0.12
    cold_glass.roughness = 0.22
    cold_glass.emission_enabled = true
    cold_glass.emission = Color("4fa9a6")
    cold_glass.emission_energy_multiplier = 0.04
    cold_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
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

    # Restore the missing sense of enclosure at the compact tactical scale.
    # Alternating front/rear bays preserve sightlines into the living beds,
    # while the split roof panes give the climate frame a roofline and depth.
    for bay in range(6):
        var bay_x := -10.0 + float(bay) * 4.0
        ModelKit3D.add_beveled_box(
            greenhouse_detail,
            Vector3(3.72, 5.2, 0.055),
            Vector3(bay_x, 3.18, -5.28),
            cold_glass,
            Vector3.ZERO,
            "GlasshouseFacadePane%02d" % bay,
            0.16
        )
        ModelKit3D.add_beveled_box(
            greenhouse_detail,
            Vector3(3.72, 5.2, 0.055),
            Vector3(bay_x, 3.18, 5.28),
            cold_glass,
            Vector3(0.0, PI, 0.0),
            "GlasshouseFacadePaneRear%02d" % bay,
            0.16
        )
        ModelKit3D.add_beveled_box(
            greenhouse_detail,
            Vector3(3.72, 0.055, 5.02),
            Vector3(bay_x, 6.28, -2.55),
            cold_glass,
            Vector3(0.10, 0.0, 0.0),
            "GlasshouseRoofPaneFront%02d" % bay,
            0.16
        )
        ModelKit3D.add_beveled_box(
            greenhouse_detail,
            Vector3(3.72, 0.055, 5.02),
            Vector3(bay_x, 6.28, 2.55),
            cold_glass,
            Vector3(-0.10, 0.0, 0.0),
            "GlasshouseRoofPaneRear%02d" % bay,
            0.16
        )

    var service_layer := Node3D.new()
    service_layer.name = "HighDefinitionGreenhouseServiceLayer"
    greenhouse_detail.add_child(service_layer)
    var service_metal := _textured_material(&"metal", Color("2f3b3c"), 0.62, 0.5)
    var service_rust := _textured_material(&"rust", Color("754936"), 0.38, 0.7)
    var service_concrete := _textured_material(&"concrete", Color("59605d"), 0.0, 0.72)
    var service_cyan := _emissive_material(Color("6fe5dd"), 0.48)
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
    var canopy_variants: Array[StandardMaterial3D] = [
        _textured_material(&"membrane", Color("542138"), 0.02, 0.68),
        _textured_material(&"membrane", Color("612640"), 0.02, 0.7),
        _textured_material(&"membrane", Color("4a263d"), 0.02, 0.66),
    ]
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
        # The market roof is cloth stretched over a surviving frame, not a
        # repeated rectangular slab. Five overlapping panels create a shallow
        # deterministic sag, visible edge hems and a broken-up highlight while
        # remaining a bounded presentation-only assembly.
        var canopy_root := Node3D.new()
        canopy_root.name = "MarketCanopy%02d" % index
        stall.add_child(canopy_root)
        var canopy_material := canopy_variants[index % canopy_variants.size()]
        var canopy_y: Array[float] = [1.98, 1.91, 1.87, 1.91, 1.98]
        for panel_index in range(canopy_y.size()):
            var panel_fraction := float(panel_index) / float(canopy_y.size() - 1)
            var panel_x := lerpf(-1.48, 1.48, panel_fraction)
            var panel := ModelKit3D.add_beveled_box(
                canopy_root,
                Vector3(0.78, 0.2 + (0.04 if panel_index == 2 else 0.0), 2.42),
                Vector3(panel_x, canopy_y[panel_index], 0.0),
                canopy_material,
                Vector3(0.0, 0.0, (panel_fraction - 0.5) * 0.055),
                ("MarketCanopy%02d" % index) if panel_index == 0 else "MarketCanopyVolume%02d_%02d" % [index, panel_index],
                0.2
            )
            panel.set_meta(&"market_canopy_panel", true)
        for front_back in [-1.0, 1.0]:
            ModelKit3D.add_beveled_box(
                canopy_root,
                Vector3(3.62, 0.1, 0.14),
                Vector3(0.0, 1.82, front_back * 1.2),
                market_rust,
                Vector3(0.0, 0.0, 0.025 * float(index % 2)),
                "MarketCanopyHem%02d_%02d" % [index, int(front_back)],
                0.22
            )
        for rib_index in range(3):
            var rib_x := -1.28 + float(rib_index) * 1.28
            var rib_y := 1.91 if rib_index == 1 else 1.97
            ModelKit3D.add_cylinder(
                canopy_root,
                0.045,
                2.38,
                Vector3(rib_x, rib_y + 0.07, 0.0),
                market_metal,
                Vector3(PI * 0.5, 0.0, 0.0),
                "MarketCanopyRib%02d_%02d" % [index, rib_index]
            )
        for side in [-1.0, 1.0]:
            ModelKit3D.add_sphere(
                canopy_root,
                0.085,
                Vector3(side * 1.52, 1.84, -1.23),
                market_rust,
                Vector3.ONE,
                "MarketCanopyTie%02d_%02d" % [index, int(side)]
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
    # The repeated stalls need one shared exchange marker so the district
    # reads as a flooded market rather than nine disconnected kiosks. Keep it
    # as a shallow presentation-only structure: it adds no inventory, vendor,
    # collision or interaction state.
    var exchange := Node3D.new()
    exchange.name = "MarketExchangeFocal"
    market_detail.add_child(exchange)
    var exchange_body := _textured_material(&"concrete", Color("555354"), 0.0, 0.72)
    var exchange_edge := _textured_material(&"rust", Color("9a5b3a"), 0.36, 0.7)
    var exchange_signal := _emissive_material(Color("f0b46a"), 1.0)
    var flood_signal := _emissive_material(Color("5fd7d6"), 0.55)
    ModelKit3D.add_beveled_box(exchange, Vector3(4.2, 0.18, 2.2), Vector3(0.0, 0.25, 3.5), exchange_body, Vector3.ZERO, "MarketExchangeFoundation", 0.12)
    ModelKit3D.add_beveled_box(exchange, Vector3(3.25, 0.85, 1.55), Vector3(0.0, 0.72, 3.5), exchange_body, Vector3.ZERO, "MarketExchangeCounter", 0.16)
    ModelKit3D.add_beveled_box(exchange, Vector3(3.65, 0.12, 1.85), Vector3(0.0, 2.18, 3.5), exchange_edge, Vector3.ZERO, "MarketExchangeCanopy", 0.12)
    for post_x in [-1.55, 1.55]:
        ModelKit3D.add_cylinder(exchange, 0.07, 2.8, Vector3(post_x, 1.45, 3.5), exchange_edge, Vector3.ZERO, "MarketExchangePost%s" % ("L" if post_x < 0.0 else "R"))
    ModelKit3D.add_surface_panel(exchange, Vector3(2.1, 0.9, 0.1), Vector3(0.0, 3.05, 2.58), exchange_body, exchange_signal, Vector3.ZERO, "MarketExchangeSign")
    ModelKit3D.add_beveled_box(exchange, Vector3(3.7, 0.08, 0.12), Vector3(0.0, 0.5, 2.38), flood_signal, Vector3.ZERO, "MarketExchangeFloodline", 0.04)
    ModelKit3D.add_sphere(exchange, 0.12, Vector3(0.0, 3.72, 3.5), exchange_signal, Vector3.ONE, "MarketExchangeBeacon")


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
    # The sluice is a foreground identity cue, but its broad face must not
    # erase the authored pump and manifold behind it in the release view.
    ModelKit3D.add_beveled_box(sluice, Vector3(5.2, 0.55, 0.42), Vector3(0.0, 0.34, 7.25), channel_edge, Vector3.ZERO, "WaterSluiceGate", 0.16)
    for rib_index in range(4):
        var rib_x := -2.4 + float(rib_index) * 1.6
        ModelKit3D.add_cylinder(sluice, 0.09, 0.62, Vector3(rib_x, 0.42, 7.03), metal, Vector3.ZERO, "WaterSluiceRib%02d" % rib_index)
    ModelKit3D.add_surface_panel(sluice, Vector3(0.95, 0.48, 0.12), Vector3(2.05, 0.42, 7.0), dark_metal, warning, Vector3.ZERO, "WaterSluiceControlPanel")
    ModelKit3D.add_sphere(sluice, 0.18, Vector3(2.05, 0.78, 6.96), signal_material, Vector3.ONE, "WaterSluiceSignal")
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
    # The repeated pumps need one clear control-station focal point so the
    # district reads as a functioning waterworks rather than a field of
    # disconnected machinery. Keep this shallow and presentation-only: it
    # adds no pump simulation, interaction, collision or maintenance task.
    var pump_station := Node3D.new()
    pump_station.name = "WaterworksPumpStationFocal"
    waterworks_detail.add_child(pump_station)
    # Use the open service deck at camera-right so the station remains legible
    # beside the central manifold instead of disappearing behind it.
    pump_station.position = Vector3(7.0, 0.0, 0.0)
    var station_body := _textured_material(&"metal", Color("344346"), 0.68, 0.46)
    var station_edge := _textured_material(&"rust", Color("8c5638"), 0.38, 0.68)
    var station_signal := _emissive_material(Color("5fd7d6"), 1.35)
    ModelKit3D.add_beveled_box(pump_station, Vector3(4.8, 0.2, 2.2), Vector3(0.0, 0.26, -2.2), station_body, Vector3.ZERO, "WaterworksStationFoundation", 0.12)
    ModelKit3D.add_beveled_box(pump_station, Vector3(3.8, 2.4, 1.5), Vector3(0.0, 1.48, -2.2), station_body, Vector3.ZERO, "WaterworksStationBody", 0.18)
    ModelKit3D.add_louvered_panel(pump_station, Vector3(1.8, 0.9, 0.1), Vector3(-0.72, 1.5, -1.42), dark_metal, station_edge, Vector3.ZERO, "WaterworksStationCoolingPanel", 5)
    ModelKit3D.add_surface_panel(pump_station, Vector3(0.78, 0.62, 0.1), Vector3(1.05, 1.7, -1.41), dark_metal, station_signal, Vector3.ZERO, "WaterworksStationControlPanel")
    ModelKit3D.add_beveled_box(pump_station, Vector3(4.4, 0.18, 1.8), Vector3(0.0, 2.78, -2.2), station_edge, Vector3.ZERO, "WaterworksStationRoof", 0.1)
    for stack_index in range(3):
        var stack_x := -1.25 + float(stack_index) * 1.25
        ModelKit3D.add_cylinder(pump_station, 0.16, 1.45, Vector3(stack_x, 3.58, -2.2), dark_metal, Vector3.ZERO, "WaterworksStationStack%02d" % stack_index)
        ModelKit3D.add_sphere(pump_station, 0.14, Vector3(stack_x, 4.38, -2.2), station_signal, Vector3.ONE, "WaterworksStationBeacon%02d" % stack_index)
    ModelKit3D.add_cylinder(pump_station, 0.1, 3.8, Vector3(0.0, 4.18, -2.2), station_edge, Vector3(0.0, 0.0, PI * 0.5), "WaterworksStationHeader")


func _dress_rail(root: Node3D) -> void:
    var metal := _textured_material(&"metal", Color("46575b"), 0.72, 0.48)
    var rust := _textured_material(&"rust", Color("8d5738"), 0.38, 0.72)
    var dark_glass := ModelKit3D.material(Color("17282d"), 0.26, 0.3, Color("4eaab0"), 0.28)
    var rail_detail := Node3D.new()
    rail_detail.name = "HighDefinitionRailDressing"
    root.add_child(rail_detail)
    # The authored Tram Graveyard shell owns the focal pair of carriages. Keep
    # this release layer as a sparse background wreck field. Keep the wrecks
    # lower and darker than the authored pair so they support the carriage,
    # pit and overhead-service hierarchy instead of becoming orange slabs.
    for index in range(4):
        var position := Vector3(-15.0 + float(index) * 10.0, 0.0, -7.0 + float(index % 2) * 14.0)
        var heading := Vector3(0.0, 0.16 * float(index % 3), 0.04 * float(index))
        var carriage_material := metal
        var carriage := ModelKit3D.add_beveled_box(rail_detail, Vector3(4.6, 1.18, 1.85), position + Vector3.UP * 0.72, carriage_material, heading, "DerailedTram%02d" % index, 0.16)
        var roof_material := rust if index % 3 == 0 else metal
        ModelKit3D.add_beveled_box(carriage, Vector3(4.86, 0.16, 2.02), Vector3(0.0, 1.38, 0.0), roof_material, Vector3.ZERO, "TramRoofPlate%02d" % index, 0.08)
        # Broken window bands establish carriage scale while the paired sides
        # keep the wreck readable from either bounded review approach.
        for window_index in range(3):
            var window_x := -1.9 + float(window_index) * 1.9
            var window_material := dark_glass if window_index != index % 3 else rust
            for side in [-1.0, 1.0]:
                var window_name := "TramWindow%02d_%02d" % [index, window_index] if side < 0.0 else "TramWindow%02d_%02d_Front" % [index, window_index]
                ModelKit3D.add_beveled_box(
                    carriage,
                    Vector3(1.02, 0.42, 0.07),
                    Vector3(window_x * 0.88, 0.86, side * 0.96),
                    window_material,
                    Vector3(0.0, 0.0, 0.02 * float(window_index % 2)),
                    window_name,
                    0.12
                )
        for side in [-1.0, 1.0]:
            ModelKit3D.add_beveled_box(carriage, Vector3(4.0, 0.09, 0.09), Vector3(0.0, 0.62, side * 0.99), rust, Vector3.ZERO, "TramBeltRail%02d_%s" % [index, "Front" if side > 0.0 else "Rear"])
        ModelKit3D.add_beveled_box(carriage, Vector3(1.1, 0.72, 0.08), Vector3(0.0, 0.76, 0.99), dark_glass, Vector3.ZERO, "TramDoor%02d" % index, 0.05)
        ModelKit3D.add_surface_panel(
            carriage,
            Vector3(1.20, 0.52, 0.08),
            Vector3(0.0, 0.58, 1.02),
            metal,
            rust,
            Vector3.ZERO,
            "TramServicePanel%02d" % index
        )
        ModelKit3D.add_beveled_box(carriage, Vector3(1.1, 0.18, 0.62), Vector3(0.0, 1.54, 0.0), metal, Vector3.ZERO, "TramRoofVent%02d" % index, 0.16)
        for bogie_index in range(2):
            var bogie_x := -1.4 + float(bogie_index) * 2.8
            ModelKit3D.add_beveled_box(carriage, Vector3(0.95, 0.16, 1.25), Vector3(bogie_x, -0.03, 0.0), rust, Vector3.ZERO, "TramBogiePlate%02d_%02d" % [index, bogie_index], 0.14)
            ModelKit3D.add_cylinder(carriage, 0.18, 1.28, Vector3(bogie_x, -0.16, 0.0), metal, Vector3(0.0, 0.0, PI * 0.5), "TramAxle%02d_%02d" % [index, bogie_index])
        ModelKit3D.add_cylinder(root, 0.05, 8.0, position + Vector3.UP * 5.0, rust, Vector3(0.0, 0.0, 1.5708), "OverheadLine")


func _dress_nest(root: Node3D) -> void:
    var chitin := _textured_material(&"chitin", Color("302028"), 0.05, 0.66)
    # Keep the Cathedral's biological takeover deep and vascular. The earlier
    # hot-magenta membrane lift overpowered the brick nave and read as an
    # emissive placeholder at the compact exact-review distance.
    var membrane := _textured_material(&"membrane", Color("2d202d"), 0.0, 0.84)
    # The Cathedral Quarter needs a civic silhouette before its biological
    # takeover reads as a deliberate contrast. Keep the facade shallow and
    # front-facing so the authored nave remains visible without adding a solid
    # collision shell, route blocker or second landmark simulation.
    var cathedral_facade := Node3D.new()
    cathedral_facade.name = "CathedralReleaseFacade"
    root.add_child(cathedral_facade)
    var brick := _textured_material(&"brick", Color("70453b"), 0.0, 0.78)
    var brick_dark := _textured_material(&"brick", Color("3c2a2b"), 0.08, 0.86)
    var stained_glass := ModelKit3D.material(Color("312c4b"), 0.18, 0.28, Color("c653a8"), 0.55)
    # Release gallery cameras approach the landmark from positive Z. Keep the
    # civic layer on the near face and slightly forward of the authored nest
    # frame so the nave reads before the biological shell.
    var facade_z := 7.6
    var nave := ModelKit3D.add_beveled_box(
        cathedral_facade,
        Vector3(6.4, 3.6, 0.78),
        Vector3(0.0, 1.85, facade_z),
        brick,
        Vector3.ZERO,
        "CathedralReleaseNave",
        0.2
    )
    # A shallow front gable restores the civic silhouette at exact review
    # distance. Keep it as dressing rather than a solid building volume so it
    # cannot create a route blocker or a second simulation landmark.
    ModelKit3D.add_beveled_box(
        cathedral_facade,
        Vector3(3.8, 0.18, 0.24),
        Vector3(-1.6, 4.58, facade_z + 0.08),
        brick_dark,
        Vector3(0.0, 0.0, 0.52),
        "CathedralReleaseGableL",
        0.14
    )
    ModelKit3D.add_beveled_box(
        cathedral_facade,
        Vector3(3.8, 0.18, 0.24),
        Vector3(1.6, 4.58, facade_z + 0.08),
        brick_dark,
        Vector3(0.0, 0.0, -0.52),
        "CathedralReleaseGableR",
        0.14
    )
    ModelKit3D.add_beveled_box(
        cathedral_facade,
        Vector3(0.14, 0.9, 0.16),
        Vector3(0.0, 5.12, facade_z + 0.15),
        brick_dark,
        Vector3.ZERO,
        "CathedralReleaseGableCrossV",
        0.12
    )
    ModelKit3D.add_beveled_box(
        cathedral_facade,
        Vector3(0.52, 0.14, 0.16),
        Vector3(0.0, 5.22, facade_z + 0.15),
        brick_dark,
        Vector3.ZERO,
        "CathedralReleaseGableCrossH",
        0.12
    )
    ModelKit3D.add_beveled_box(
        nave,
        Vector3(1.28, 2.0, 0.12),
        Vector3(0.0, -0.55, 0.46),
        brick_dark,
        Vector3.ZERO,
        "CathedralReleaseDoor",
        0.12
    )
    for side in [-1.0, 1.0]:
        var tower := ModelKit3D.add_beveled_box(
            cathedral_facade,
            Vector3(1.7, 6.2, 1.5),
            Vector3(side * 4.15, 3.1, facade_z - 0.18),
            brick,
            Vector3(0.0, 0.0, side * 0.015),
            "CathedralReleaseTower%s" % ("L" if side < 0.0 else "R"),
            0.2
        )
        ModelKit3D.add_beveled_box(
            tower,
            Vector3(1.98, 0.24, 1.78),
            Vector3(0.0, 3.18, 0.0),
            brick_dark,
            Vector3.ZERO,
            "CathedralReleaseTowerCap%s" % ("L" if side < 0.0 else "R"),
            0.14
        )
        for slit_index in range(2):
            ModelKit3D.add_surface_panel(
                tower,
                Vector3(0.28, 1.15, 0.08),
                Vector3(0.0, 1.2 + float(slit_index) * 1.55, -0.8),
                brick_dark,
                stained_glass,
                Vector3.ZERO,
                "CathedralReleaseTowerSlit%s%d" % ["L" if side < 0.0 else "R", slit_index]
            )
    ModelKit3D.add_cylinder(
        cathedral_facade,
        1.08,
        0.16,
        Vector3(0.0, 3.25, facade_z + 0.48),
        brick_dark,
        Vector3(PI * 0.5, 0.0, 0.0),
        "CathedralReleaseRoseFrame"
    )
    ModelKit3D.add_cylinder(
        cathedral_facade,
        0.78,
        0.18,
        Vector3(0.0, 3.25, facade_z + 0.58),
        stained_glass,
        Vector3(PI * 0.5, 0.0, 0.0),
        "CathedralReleaseRoseGlass"
    )
    ModelKit3D.add_torus(
        cathedral_facade,
        0.91,
        0.09,
        Vector3(0.0, 3.25, facade_z + 0.73),
        brick_dark,
        Vector3(PI * 0.5, 0.0, 0.0),
        "CathedralReleaseRoseRim",
        48,
        8
    )
    for spoke_index in range(8):
        var spoke_angle := TAU * float(spoke_index) / 8.0
        ModelKit3D.add_cylinder(
            cathedral_facade,
            0.045,
            1.7,
            Vector3(cos(spoke_angle) * 0.34, 3.25 + sin(spoke_angle) * 0.34, facade_z + 0.76),
            brick_dark,
            Vector3(PI * 0.5, 0.0, spoke_angle),
            "CathedralReleaseRoseSpoke%02d" % spoke_index
        )
    # The rose window alone disappears into the roof clutter at remote review
    # distance. Add a restrained organ-like choir crown above the nave so the
    # quarter reads as a civic worship space before its brood takeover. Keep
    # this as shallow presentation dressing: it adds no collision, routing,
    # interaction or encounter state.
    var choir_metal := _textured_material(&"metal", Color("55403d"), 0.5, 0.5)
    var choir_dark := _textured_material(&"metal", Color("282d31"), 0.72, 0.38)
    var choir_signal := ModelKit3D.material(Color("3d2850"), 0.2, 0.3, Color("bd67d1"), 0.62)
    ModelKit3D.add_beveled_box(
        cathedral_facade,
        Vector3(4.7, 0.18, 0.18),
        Vector3(0.0, 5.28, facade_z + 0.9),
        choir_dark,
        Vector3.ZERO,
        "CathedralChoirCrownRail",
        0.08
    )
    var choir_heights := [1.2, 1.8, 2.35, 2.8, 2.35, 1.8, 1.2]
    for pipe_index in range(choir_heights.size()):
        var pipe_height := float(choir_heights[pipe_index])
        var pipe_x := -1.8 + float(pipe_index) * 0.6
        ModelKit3D.add_cylinder(
            cathedral_facade,
            0.095,
            pipe_height,
            Vector3(pipe_x, 5.28 + pipe_height * 0.5, facade_z + 0.92),
            choir_metal,
            Vector3.ZERO,
            "CathedralChoirPipe%02d" % pipe_index
        )
        ModelKit3D.add_torus(
            cathedral_facade,
            0.12,
            0.035,
            Vector3(pipe_x, 5.28, facade_z + 0.92),
            choir_signal,
            Vector3.ZERO,
            "CathedralChoirCollar%02d" % pipe_index,
            16,
            6
        )
    ModelKit3D.add_sphere(
        cathedral_facade,
        0.22,
        Vector3(0.0, 5.62, facade_z + 1.0),
        choir_signal,
        Vector3.ONE,
        "CathedralChoirSignal"
    )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(
            cathedral_facade,
            Vector3(0.42, 2.8, 0.42),
            Vector3(side * 2.75, 2.0, facade_z + 0.52),
            brick_dark,
            Vector3(0.0, 0.0, side * 0.12),
            "CathedralReleaseButtress%s" % ("L" if side < 0.0 else "R"),
            0.12
        )
    for index in range(12):
        var angle := TAU * float(index) / 12.0
        var radius := 7.0 + float(index % 4) * 2.5
        ModelKit3D.add_capsule(root, 0.18, 4.5 + float(index % 3), Vector3(cos(angle) * radius, 2.0, sin(angle) * radius), chitin, Vector3(0.0, -angle, 0.35), "NestSpine")
        ModelKit3D.add_organic_plate(
            root,
            0.7,
            Vector3(cos(angle) * radius * 0.72, 0.7, sin(angle) * radius * 0.72),
            membrane,
            chitin,
            Vector3(1.4, 0.8, 1.4),
            "BroodSac%02d" % index
        )
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
    # The authored Observatory asset owns the primary reflector surface. Do
    # not add the former scaled-sphere proxy here: at remote review distance
    # it reads as a pale duplicate crescent beneath the real parabolic dish.
    for rib_index in range(4):
        var rib_angle := TAU * float(rib_index) / 4.0
        ModelKit3D.add_capsule(
            observatory_detail,
            0.08,
            3.4,
            Vector3(cos(rib_angle) * 2.55, 3.75 + sin(rib_angle) * 0.28, sin(rib_angle) * 2.55),
            rust,
            Vector3(0.0, -rib_angle, 0.18 * cos(rib_angle)),
            "ObservatoryDishRib%02d" % rib_index
        )
    # A raised inner aperture ring gives the deep reflector a second readable
    # contour at remote distance. It follows the authored bowl tilt and is
    # presentation dressing only: no collision, routing or simulation state.
    ModelKit3D.add_torus(
        observatory_detail,
        2.18,
        0.075,
        Vector3(-0.4, 3.58, 0.92),
        rust,
        Vector3(PI * 0.12, 0.0, 0.0),
        "ObservatoryDishApertureRing",
        48,
        8
    )
    ModelKit3D.add_cylinder(observatory_detail, 0.18, 5.0, Vector3(0.0, 6.0, 0.0), metal, Vector3(0.4, 0.0, 0.0), "DishFeed")
    ModelKit3D.add_cylinder(observatory_detail, 0.28, 0.34, Vector3(0.0, 8.32, 0.0), signal_material, Vector3.ZERO, "DishReceiverLens")
    ModelKit3D.add_beveled_box(observatory_detail, Vector3(0.82, 0.14, 0.82), Vector3(0.0, 3.62, 0.0), rust, Vector3.ZERO, "ObservatoryDishHub", 0.18)

    # The primary dish needs a surrounding instrument silhouette at remote
    # review distance. Keep this as release dressing: it frames the receiver
    # and gives the survey deck a small operator-facing control identity
    # without adding collision, routing or a second simulation system.
    var array_frame := Node3D.new()
    array_frame.name = "ObservatoryArrayFrame"
    observatory_detail.add_child(array_frame)
    var frame_dark := _textured_material(&"metal", Color("1b2b30"), 0.8, 0.32)
    var frame_edge := _textured_material(&"rust", Color("9a5d3a"), 0.42, 0.6)
    # Keep the release array as a rear horizon frame. The reflector is the
    # landmark's focal instrument; foreground pylons and crossbars turn it
    # into a blocked blue disc at the authored approach angle.
    var array_rear_z := -3.8
    for pylon_index in range(4):
        var pylon_x := -4.0 if pylon_index % 2 == 0 else 4.0
        var pylon_z := array_rear_z + float(pylon_index % 2) * 1.4
        ModelKit3D.add_cylinder(
            array_frame,
            0.15,
            6.2,
            Vector3(pylon_x, 3.25, pylon_z),
            frame_dark,
            Vector3(0.0, 0.0, 0.16 if pylon_index % 2 == 0 else -0.16),
            "ObservatoryArrayPylon%02d" % pylon_index
        )
        ModelKit3D.add_sphere(
            array_frame,
            0.16,
            Vector3(pylon_x, 6.45, pylon_z),
            signal_material,
            Vector3.ONE,
            "ObservatoryArrayBeacon%02d" % pylon_index
        )
    for crossbar_index in range(2):
        var crossbar_z := array_rear_z + float(crossbar_index) * 1.4
        ModelKit3D.add_cylinder(
            array_frame,
            0.1,
            8.25,
            Vector3(0.0, 6.02, crossbar_z),
            frame_edge,
            Vector3(0.0, 0.0, PI * 0.5),
            "ObservatoryArrayCrossbar%02d" % crossbar_index
        )
    var control_pod := ModelKit3D.add_beveled_box(
        array_frame,
        Vector3(1.9, 1.25, 1.45),
        Vector3(-2.15, 1.0, array_rear_z - 0.45),
        frame_dark,
        Vector3.ZERO,
        "ObservatoryArrayControlPod",
        0.16
    )
    ModelKit3D.add_surface_panel(
        control_pod,
        Vector3(1.16, 0.56, 0.08),
        Vector3(0.0, 0.2, -0.76),
        frame_dark,
        signal_material,
        Vector3.ZERO,
        "ObservatoryArrayControlReadout"
    )
    var approach_control_pod := ModelKit3D.add_beveled_box(
        array_frame,
        Vector3(1.9, 1.25, 1.45),
        Vector3(2.15, 1.0, array_rear_z + 1.45),
        frame_dark,
        Vector3.ZERO,
        "ObservatoryArrayApproachControlPod",
        0.16
    )
    ModelKit3D.add_surface_panel(
        approach_control_pod,
        Vector3(1.16, 0.56, 0.08),
        Vector3(0.0, 0.2, 0.76),
        frame_dark,
        signal_material,
        Vector3(0.0, PI, 0.0),
        "ObservatoryArrayApproachControlReadout"
    )
    ModelKit3D.add_cylinder(
        array_frame,
        0.07,
        2.8,
        Vector3(3.55, 6.8, array_rear_z),
        frame_edge,
        Vector3(0.0, 0.0, 0.18),
        "ObservatoryArrayRelayMast"
    )
    ModelKit3D.add_surface_panel(
        array_frame,
        Vector3(1.25, 0.48, 0.08),
        Vector3(1.25, 0.52, array_rear_z - 0.72),
        frame_dark,
        signal_material,
        Vector3.ZERO,
        "ObservatoryArrayStatusPanel"
    )

    # The recovered migration record needs a physical interpretation in the
    # survey station, not only a HUD line. Keep the witness on the edge of the
    # service deck so it enriches the approach without competing with the
    # reflector. It is presentation-only: the archive director remains the
    # authority for discovery and the map does not create a new interaction.
    var migration_witness := Node3D.new()
    migration_witness.name = "ObservatoryMigrationWitness"
    observatory_detail.add_child(migration_witness)
    var witness_frame := _textured_material(&"metal", Color("172429"), 0.82, 0.34)
    var witness_edge := _textured_material(&"rust", Color("8e5636"), 0.42, 0.62)
    var witness_plate := ModelKit3D.material(Color("102a31"), 0.28, 0.3, Color("4aaeb9"), 0.24)
    var migration_cyan := ModelKit3D.material(Color("1c5660"), 0.22, 0.28, Color("76e0e8"), 0.82)
    var migration_amber := ModelKit3D.material(Color("6d4b2d"), 0.3, 0.48, Color("e0aa62"), 0.64)
    var migration_violet := ModelKit3D.material(Color("40345f"), 0.3, 0.42, Color("a38ce8"), 0.58)
    var witness_position := Vector3(3.05, 1.38, 1.78)
    ModelKit3D.add_beveled_box(
        migration_witness,
        Vector3(2.85, 1.82, 0.18),
        witness_position,
        witness_frame,
        Vector3(0.0, -0.12, 0.0),
        "ObservatoryMigrationWitnessFrame",
        0.16
    )
    ModelKit3D.add_surface_panel(
        migration_witness,
        Vector3(2.36, 1.32, 0.1),
        witness_position + Vector3(0.0, 0.0, 0.12),
        witness_plate,
        migration_cyan,
        Vector3(0.0, PI - 0.12, 0.0),
        "ObservatoryMigrationMapPlate"
    )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(
            migration_witness,
            0.085,
            1.1,
            witness_position + Vector3(side * 0.98, -0.94, 0.0),
            witness_edge,
            Vector3.ZERO,
            "ObservatoryMigrationWitnessLeg%s" % ("L" if side < 0.0 else "R")
        )
    var trace_materials: Array[Material] = [migration_cyan, migration_amber, migration_violet]
    for trace_index in range(3):
        var trace_material: Material = trace_materials[trace_index]
        var trace_y := witness_position.y + 0.22 - float(trace_index) * 0.32
        var trace_x := witness_position.x - 0.42 + float(trace_index) * 0.16
        ModelKit3D.add_beveled_box(
            migration_witness,
            Vector3(1.45 - float(trace_index) * 0.16, 0.055, 0.045),
            Vector3(trace_x, trace_y, witness_position.z + 0.205),
            trace_material,
            Vector3(0.0, 0.0, -0.08 + float(trace_index) * 0.13),
            "ObservatoryMigrationTrace%02d" % trace_index,
            0.025
        )
        ModelKit3D.add_sphere(
            migration_witness,
            0.105,
            Vector3(witness_position.x + 0.72 - float(trace_index) * 0.18, trace_y, witness_position.z + 0.22),
            trace_material,
            Vector3(1.2, 0.8, 0.42),
            "ObservatoryMigrationNode%02d" % trace_index
        )
    ModelKit3D.add_cylinder(
        migration_witness,
        0.06,
        0.88,
        witness_position + Vector3(-1.02, 0.2, 0.24),
        witness_edge,
        Vector3(0.0, 0.0, PI * 0.5),
        "ObservatoryMigrationCalibrationBar"
    )
    ModelKit3D.add_cylinder(
        migration_witness,
        0.055,
        1.25,
        witness_position + Vector3(0.0, 1.06, 0.0),
        witness_edge,
        Vector3(0.0, 0.0, PI * 0.5),
        "ObservatoryMigrationWitnessCanopy"
    )
    ModelKit3D.add_sphere(
        migration_witness,
        0.14,
        witness_position + Vector3(-1.16, 0.2, 0.26),
        migration_amber,
        Vector3.ONE,
        "ObservatoryMigrationCalibrationLens"
    )


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
    # The broad basin is a presentation anchor, not a light-catching white
    # card. Keep its wet concrete readable beneath the late landmark hardware
    # while leaving the more exposed control deck and pump housing on the
    # brighter service material.
    var basin_concrete := ModelKit3D.material(Color("10191b"), 0.0, 0.9)
    var membrane := _textured_material(&"membrane", Color("631431"), 0.0, 0.58)
    var metal := _textured_material(&"metal", Color("263437"), 0.74, 0.4)
    var rust := _textured_material(&"rust", Color("72432f"), 0.42, 0.7)
    var glow := _emissive_material(Color("d33f67"), 3.2)
    var cool_signal := ModelKit3D.material(Color("17464b"), 0.28, 0.3, Color("61dfe0"), 1.5)
    var service_ring_material := ModelKit3D.material(Color("1b2b2e"), 0.46, 0.56)
    var signal_ring_material := ModelKit3D.material(Color("0d3036"), 0.28, 0.42, Color("2d9ba4"), 0.34)
    ModelKit3D.add_cylinder(root, 18.0, 0.8, Vector3(0.0, 0.4, 0.0), basin_concrete, Vector3.ZERO, "CisternBasin")
    # The authored Root Cistern glTF owns the six signal pylons and their
    # grounded relay hardware. Do not add a second generic pylon ring here:
    # fourteen repeated capsules obscure the capstone and read as a forest of
    # stakes in both the exact review page and the close release camera.

    # The basin is the late-game approach landmark. Add one bounded municipal
    # service layer so it reads as a buried pumping installation overtaken by
    # the living relay, rather than a circular arena with repeated pylons.
    var depth_detail := Node3D.new()
    depth_detail.name = "HighDefinitionCisternDressing"
    root.add_child(depth_detail)
    ModelKit3D.add_cylinder(depth_detail, 12.8, 0.18, Vector3(0.0, 0.86, 0.0), service_ring_material, Vector3.ZERO, "CisternServiceRing")
    ModelKit3D.add_cylinder(depth_detail, 10.6, 0.1, Vector3(0.0, 0.97, 0.0), signal_ring_material, Vector3.ZERO, "CisternSignalRing")
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
    var brick := _textured_material(&"brick", Color("5c5048"), 0.0, 0.82)
    var grime := _textured_material(&"grime", Color("363b3a"), 0.0, 0.88)
    var archive_detail := Node3D.new()
    archive_detail.name = "HighDefinitionArchiveDressing"
    root.add_child(archive_detail)
    var glass := ModelKit3D.material(Color("18333a"), 0.2, 0.38, Color("6dbac0"), 0.12)
    var service_metal := _textured_material(&"metal", Color("3d4546"), 0.64, 0.5)
    var paper := _textured_material(&"concrete", Color("6d6253"), 0.0, 0.92)
    # The remote review camera sees the archive fragments as a generic roofline
    # unless one civic threshold survives in the foreground. Keep this as a
    # bounded presentation dressing: it gives the region a records identity
    # without adding a new door, inventory, or simulated destination.
    var gateway := Node3D.new()
    gateway.name = "ArchiveGateway"
    archive_detail.add_child(gateway)
    var gateway_stone := _textured_material(&"brick", Color("6a5149"), 0.0, 0.84)
    var gateway_edge := _textured_material(&"stone", Color("4d5655"), 0.42, 0.58)
    var gateway_panel := ModelKit3D.material(Color("17383d"), 0.22, 0.36, Color("6ec8c7"), 0.18)
    ModelKit3D.add_beveled_box(
        gateway,
        Vector3(5.8, 0.28, 0.92),
        Vector3(-1.6, 0.34, 4.62),
        gateway_edge,
        Vector3(0.0, 0.0, 0.02),
        "ArchiveGatewayFoundation",
        0.12
    )
    ModelKit3D.add_beveled_box(
        gateway,
        Vector3(5.5, 4.15, 0.34),
        Vector3(-1.6, 2.34, 4.72),
        gateway_stone,
        Vector3.ZERO,
        "ArchiveGatewayShell",
        0.18
    )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(
            gateway,
            Vector3(0.38, 3.85, 0.56),
            Vector3(-1.6 + side * 2.28, 2.18, 4.92),
            gateway_edge,
            Vector3(0.0, 0.0, side * 0.015),
            "ArchiveGatewayPilaster%s" % ("L" if side < 0.0 else "R"),
            0.08
        )
    ModelKit3D.add_beveled_box(
        gateway,
        Vector3(5.9, 0.24, 0.62),
        Vector3(-1.6, 4.48, 4.92),
        gateway_edge,
        Vector3(0.0, 0.0, 0.015),
        "ArchiveGatewayHeader",
        0.10
    )
    ModelKit3D.add_surface_panel(
        gateway,
        Vector3(2.45, 1.72, 0.12),
        Vector3(-1.6, 2.35, 4.96),
        service_metal,
        gateway_panel,
        Vector3.ZERO,
        "ArchiveGatewayIndex"
    )
    for rail_index in range(3):
        ModelKit3D.add_beveled_box(
            gateway,
            Vector3(1.72, 0.08, 0.10),
            Vector3(-1.6, 1.92 + float(rail_index) * 0.42, 4.99),
            gateway_edge,
            Vector3.ZERO,
            "ArchiveGatewayIndexRail%d" % rail_index,
            0.03
        )
    ModelKit3D.add_sphere(gateway, 0.18, Vector3(-1.6, 4.78, 4.96), gateway_panel, Vector3.ONE, "ArchiveGatewayBeacon")
    for index in range(6):
        var height := 5.0 + float(index % 3) * 2.0
        var position := Vector3(-12.0 + float(index) * 4.8, 2.5, -3.0 + float(index % 2) * 6.0)
        var rotation := Vector3(0.0, 0.08 * float(index), 0.0)
        var fragment_material := brick if index % 2 == 0 else grime
        var fragment := ModelKit3D.add_beveled_box(
            archive_detail,
            Vector3(3.7, height, 2.9),
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
            ModelKit3D.add_beveled_box(
                fragment,
                Vector3(1.42, minf(1.35, height * 0.22), 0.08),
                Vector3(bay_x, height * 0.1, 1.48),
                glass if bay_index != (index + 1) % 2 else paper,
                Vector3.ZERO,
                "ArchiveWindowFront%02d_%02d" % [index, bay_index],
                0.1
            )
            ModelKit3D.add_beveled_box(
                fragment,
                Vector3(0.10, minf(1.42, height * 0.24), 0.12),
                Vector3(bay_x - 0.78, height * 0.1, 1.52),
                service_metal,
                Vector3.ZERO,
                "ArchiveWindowMullion%02d_%02d" % [index, bay_index],
                0.05
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
        ModelKit3D.add_beveled_box(
            fragment,
            Vector3(3.25, 0.12, 2.35),
            Vector3(0.0, height * 0.5 + 0.20, 0.0),
            brick,
            Vector3(0.0, 0.0, 0.02 * float(index % 2)),
            "ArchiveStackCap%02d" % index,
            0.12
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
