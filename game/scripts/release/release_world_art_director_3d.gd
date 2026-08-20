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
const AUTHORED_MACHINE_TOKENS: Array[String] = [
    "bulwark",
    "warden",
    "scrapper",
    "pathfinder",
    "engineer",
]
const AUTHORED_ORGANIC_TOKENS: Array[String] = [
    "veilstalker",
    "razorhound",
    "sporecaster",
    "broodmass",
    "burrower",
    "skitterling",
    "apex",
]
const ORGANIC_MEMBRANE_TOKENS: Array[String] = [
    "membrane",
    "veil",
    "wing",
    "sac",
    "fan",
]

var world: Node3D
var region_director: WorldRegionDirector3D
var settings_service: ReleaseSettingsService3D
var textures: Dictionary = {}
var dressing_root: Node3D
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


func _on_node_added(node: Node) -> void:
    # Actors, outpost upgrades and discovered-region dressing are created
    # throughout a run. Keep the release material pass live instead of
    # leaving late-created meshes on their greybox fallback materials.
    if node == null:
        return
    call_deferred("_texture_subtree_id", node.get_instance_id())


func _load_textures() -> void:
    textures.clear()
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


func _apply_release_art() -> void:
    if world == null or dressing_root == null:
        return
    meshes_textured = 0
    regions_dressed = 0
    _texture_recursive(world)
    _dress_heartforge_district()
    if region_director != null:
        for raw_region_id in region_director.region_data:
            _dress_region(raw_region_id as StringName)
    art_pass_completed.emit(meshes_textured, regions_dressed)


func _texture_recursive(node: Node) -> void:
    if node is MeshInstance3D:
        _texture_mesh(node as MeshInstance3D)
    for child in node.get_children():
        if child == dressing_root:
            continue
        _texture_recursive(child)


func _texture_subtree_id(instance_id: int) -> void:
    var node := instance_from_id(instance_id) as Node
    if node == null or not is_instance_valid(node) or node == dressing_root:
        return
    _texture_recursive(node)


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


func _dress_heartforge_district() -> void:
    var root := _region_root("HeartforgeReleaseDressing", Vector3.ZERO)
    var warm_metal := _textured_material(&"rust", Color("8f5a36"), 0.45, 0.65)
    var dark_metal := _textured_material(&"metal", Color("30383a"), 0.72, 0.48)
    for index in range(6):
        var angle := TAU * float(index) / 6.0
        var position := Vector3(cos(angle) * 11.5, 0.0, sin(angle) * 11.5)
        ModelKit3D.add_box(root, Vector3(2.8, 0.9, 1.2), position + Vector3.UP * 0.45, warm_metal, Vector3(0.0, -angle, 0.0), "ImprovisedBarrier")
        ModelKit3D.add_cylinder(root, 0.08, 2.6, position + Vector3.UP * 1.3, dark_metal, Vector3.ZERO, "CablePost")
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
    for index in range(5):
        ModelKit3D.add_cylinder(root, 0.75 + float(index % 2) * 0.25, 4.0 + float(index) * 0.8, Vector3(-10.0 + float(index) * 5.0, 2.0 + float(index) * 0.4, -4.0 + float(index % 2) * 8.0), metal, Vector3.ZERO, "SubstationTank")
        ModelKit3D.add_cylinder(root, 0.12, 8.0, Vector3(-10.0 + float(index) * 5.0, 4.2, 0.0), rust, Vector3(0.0, 0.0, 1.5708), "GridPipe")


func _dress_tenement(root: Node3D) -> void:
    var brick := _textured_material(&"brick", Color("55443d"), 0.0, 0.88)
    var cloth := ModelKit3D.material(Color("6d514b"), 0.0, 0.92)
    for side in [-1.0, 1.0]:
        for floor_index in range(4):
            var y := 2.5 + float(floor_index) * 2.35
            ModelKit3D.add_box(root, Vector3(9.0, 0.18, 1.2), Vector3(side * 8.5, y, 0.0), brick, Vector3.ZERO, "Balcony")
            for cloth_index in range(5):
                ModelKit3D.add_box(root, Vector3(0.55, 0.75, 0.04), Vector3(side * 7.85, y + 0.15, -2.4 + float(cloth_index) * 1.2), cloth, Vector3(0.0, float(cloth_index) * 0.08, 0.0), "HangingCloth")


func _dress_greenhouse(root: Node3D) -> void:
    var frame := _textured_material(&"metal", Color("405052"), 0.68, 0.4)
    var moss := _textured_material(&"moss", Color("476a49"), 0.0, 0.86)
    var glow := _emissive_material(Color("7ce6b2"), 2.8)
    for index in range(7):
        var x := -12.0 + float(index) * 4.0
        ModelKit3D.add_cylinder(root, 0.08, 7.0, Vector3(x, 3.5, 0.0), frame, Vector3.ZERO, "GlasshouseFrame")
        ModelKit3D.add_sphere(root, 0.8, Vector3(x, 0.7, -4.0 + float(index % 3) * 4.0), moss, Vector3(1.3, 0.8, 1.3), "Overgrowth")
        ModelKit3D.add_sphere(root, 0.16, Vector3(x + 0.8, 1.2, -3.0 + float(index % 4) * 2.2), glow, Vector3.ONE, "MyceliumGlow")


func _dress_market(root: Node3D) -> void:
    var concrete := _textured_material(&"concrete", Color("4b4e4d"), 0.0, 0.74)
    var membrane := _textured_material(&"membrane", Color("69223e"), 0.0, 0.66)
    for index in range(9):
        var x := -12.0 + float(index % 3) * 12.0
        var z := -10.0 + float(index / 3) * 9.0
        ModelKit3D.add_box(root, Vector3(5.0, 1.2, 3.0), Vector3(x, 0.6, z), concrete, Vector3.ZERO, "MarketStall")
        ModelKit3D.add_sphere(root, 0.75, Vector3(x + 1.4, 1.0, z), membrane, Vector3(1.2, 0.7, 1.8), "MarketMembrane")


func _dress_waterfront(root: Node3D) -> void:
    var concrete := _textured_material(&"concrete", Color("3e4546"), 0.0, 0.68)
    var metal := _textured_material(&"rust", Color("73523b"), 0.42, 0.68)
    for index in range(5):
        var x := -14.0 + float(index) * 7.0
        ModelKit3D.add_box(root, Vector3(4.8, 0.65, 12.0), Vector3(x, 0.33, 0.0), concrete, Vector3.ZERO, "PumpWalkway")
        ModelKit3D.add_cylinder(root, 0.22, 5.5, Vector3(x, 3.2, -4.0), metal, Vector3.ZERO, "PumpGantry")
        ModelKit3D.add_box(root, Vector3(2.4, 1.6, 2.4), Vector3(x, 0.8, 5.0), metal, Vector3.ZERO, "PumpHousing")


func _dress_rail(root: Node3D) -> void:
    var metal := _textured_material(&"metal", Color("354043"), 0.72, 0.48)
    var rust := _textured_material(&"rust", Color("794d32"), 0.38, 0.72)
    for index in range(6):
        var position := Vector3(-18.0 + float(index) * 7.0, 0.0, -5.0 + float(index % 2) * 10.0)
        ModelKit3D.add_box(root, Vector3(6.0, 2.2, 2.5), position + Vector3.UP * 1.1, metal if index % 2 == 0 else rust, Vector3(0.0, 0.16 * float(index % 3), 0.04 * float(index)), "DerailedTram")
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
    ModelKit3D.add_cylinder(root, 3.2, 2.0, Vector3(0.0, 1.0, 0.0), metal, Vector3.ZERO, "ObservatoryBase")
    ModelKit3D.add_sphere(root, 3.6, Vector3(0.0, 4.3, 0.0), metal, Vector3(1.0, 0.26, 1.0), "ObservatoryDish")
    ModelKit3D.add_cylinder(root, 0.18, 5.0, Vector3(0.0, 6.0, 0.0), metal, Vector3(0.4, 0.0, 0.0), "DishFeed")


func _dress_research(root: Node3D) -> void:
    var concrete := _textured_material(&"concrete", Color("3f4243"), 0.0, 0.7)
    var metal := _textured_material(&"metal", Color("3c4749"), 0.65, 0.42)
    var glow := _emissive_material(Color("6bc9d0"), 2.6)
    for index in range(8):
        var angle := TAU * float(index) / 8.0
        ModelKit3D.add_box(root, Vector3(3.2, 2.0, 1.4), Vector3(cos(angle) * 10.0, 1.0, sin(angle) * 10.0), concrete, Vector3(0.0, -angle, 0.0), "LabConsole")
        ModelKit3D.add_box(root, Vector3(1.8, 0.08, 0.8), Vector3(cos(angle) * 9.2, 1.4, sin(angle) * 9.2), glow, Vector3(0.0, -angle, 0.0), "LabDisplay")
        ModelKit3D.add_cylinder(root, 0.2, 3.4, Vector3(cos(angle) * 6.0, 1.7, sin(angle) * 6.0), metal, Vector3.ZERO, "LabCylinder")


func _dress_cistern(root: Node3D) -> void:
    var concrete := _textured_material(&"concrete", Color("30383a"), 0.0, 0.68)
    var membrane := _textured_material(&"membrane", Color("631431"), 0.0, 0.58)
    var glow := _emissive_material(Color("d33f67"), 3.2)
    ModelKit3D.add_cylinder(root, 18.0, 0.8, Vector3(0.0, 0.4, 0.0), concrete, Vector3.ZERO, "CisternBasin")
    for index in range(14):
        var angle := TAU * float(index) / 14.0
        var radius := 8.0 + float(index % 3) * 3.4
        ModelKit3D.add_capsule(root, 0.28, 6.0 + float(index % 4), Vector3(cos(angle) * radius, 2.5, sin(angle) * radius), membrane, Vector3(0.0, -angle, 0.55), "RootPylon")
        ModelKit3D.add_sphere(root, 0.12, Vector3(cos(angle) * radius * 0.72, 3.1, sin(angle) * radius * 0.72), glow, Vector3.ONE, "RootSignal")


func _dress_archive(root: Node3D) -> void:
    var brick := _textured_material(&"brick", Color("504840"), 0.0, 0.82)
    var grime := _textured_material(&"grime", Color("4b443c"), 0.0, 0.88)
    for index in range(6):
        ModelKit3D.add_box(root, Vector3(4.0, 5.0 + float(index % 3) * 2.0, 3.2), Vector3(-12.0 + float(index) * 4.8, 2.5, -3.0 + float(index % 2) * 6.0), brick if index % 2 == 0 else grime, Vector3(0.0, 0.08 * float(index), 0.0), "ArchiveFragment")


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
