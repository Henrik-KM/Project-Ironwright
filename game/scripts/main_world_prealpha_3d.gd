class_name IronwrightPreAlphaWorld3D
extends IronwrightProductionWorld3D

## Presentation reset informed by direct screenshot review. This layer owns the
## representative Heartforge vertical slice and camera composition while the
## systemic game remains underneath it. This is still a pre-alpha production
## prototype until representative gameplay receives explicit human approval.

const VERTICAL_SLICE_DIRECTOR := preload("res://scripts/presentation/vertical_slice_readable_director_3d.gd")
const VERTICAL_SLICE_ACTOR_ART := preload("res://scripts/presentation/vertical_slice_actor_art_3d.gd")

var _last_map_label_mode: bool = false
var vertical_slice: VerticalSliceDirector3D
var vertical_slice_actor_art: VerticalSliceActorArt3D
var camera_target_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	camera_height = 19.2
	camera_distance = 11.2
	if camera != null:
		camera.fov = 44.0
		camera.near = 0.35
	_set_region_map_emphasis(false)

	vertical_slice = VERTICAL_SLICE_DIRECTOR.new() as VerticalSliceDirector3D
	vertical_slice.name = "VerticalSliceDirector"
	vertical_slice.configure(self, heartforge, player, camera, ecology_director)
	add_child(vertical_slice)

	vertical_slice_actor_art = VERTICAL_SLICE_ACTOR_ART.new() as VerticalSliceActorArt3D
	vertical_slice_actor_art.name = "VerticalSliceActorArt"
	vertical_slice_actor_art.configure(self)
	add_child(vertical_slice_actor_art)

	if hud != null:
		hud.notifications.clear()
		hud.notification_ages.clear()
		hud._refresh_notifications()
		hud.push_notification("HEARTFORGE DISTRICT · KEEP THE BULWARK CLOSE")
	run_state.log_event("Presentation status: pre-alpha production prototype. The Heartforge district is the current representative vertical slice.")
	run_state.log_event("The Heartforge district now uses the representative vertical presentation slice. The remainder of the world inherits this quality only after the slice passes human review.")


func _process(delta: float) -> void:
	super._process(delta)
	if map_mode != _last_map_label_mode:
		_last_map_label_mode = map_mode
		_set_region_map_emphasis(map_mode)


func _update_camera(delta: float) -> void:
	if camera == null or player == null:
		return

	if map_mode:
		var map_target := Vector3(0.0, 0.0, -8.0)
		if region_director != null and region_director.discovered_count() > 1:
			map_target = _discovered_region_centroid()
		var desired_map_position := map_target + Vector3(0.0, 82.0, 10.0)
		camera.global_position = camera.global_position.lerp(desired_map_position, 1.0 - exp(-delta * 4.2))
		camera.look_at(map_target, Vector3.FORWARD)
		return

	var target := player.global_position
	if follow_operation:
		var operation_target := _active_follow_target()
		if operation_target != null:
			target = operation_target.global_position
		else:
			follow_operation = false

	var subject_velocity := player.velocity if not follow_operation else Vector3.ZERO
	subject_velocity.y = 0.0
	camera_target_velocity = camera_target_velocity.lerp(subject_velocity, 1.0 - exp(-delta * 3.2))
	var lead := camera_target_velocity * 0.38
	if lead.length() > 2.5:
		lead = lead.normalized() * 2.5
	target += lead

	var threat_bias := _nearby_threat_camera_bias(target)
	var dynamic_height := camera_height + threat_bias.y
	var dynamic_distance := camera_distance + threat_bias.z
	var desired := target + Vector3(0.0, dynamic_height, dynamic_distance)
	var resolved := _resolve_camera_occlusion(target, desired)
	camera.global_position = camera.global_position.lerp(resolved, 1.0 - exp(-delta * 7.2))
	camera.look_at(target + Vector3.UP * 0.68, Vector3.UP)


func _nearby_threat_camera_bias(target: Vector3) -> Vector3:
	var threat_count := 0
	var nearest := INF
	for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D):
			continue
		var distance := target.distance_to((enemy as Node3D).global_position)
		if distance <= 15.0:
			threat_count += 1
			nearest = minf(nearest, distance)
	if threat_count <= 0:
		return Vector3.ZERO
	var intensity := clampf(float(threat_count) * 0.18 + (1.0 - clampf(nearest / 15.0, 0.0, 1.0)) * 0.45, 0.0, 1.0)
	return Vector3(0.0, intensity * 2.6, intensity * 1.2)


func _active_follow_target() -> Node3D:
	if long_operation_director != null and not long_operation_director.active_operation.is_empty():
		var long_target := long_operation_director.get_follow_target()
		if long_target != null:
			return long_target
	if outpost_director != null and not outpost_director.operation.is_empty():
		var outpost_target := outpost_director.get_follow_target()
		if outpost_target != null:
			return outpost_target
	if autonomy_director != null:
		return autonomy_director.get_follow_target()
	return null


func _resolve_camera_occlusion(target: Vector3, desired: Vector3) -> Vector3:
	var space_state := get_world_3d().direct_space_state
	var target_eye := target + Vector3.UP * 1.1
	var candidates: Array[Vector3] = [
		desired,
		target + Vector3(0.0, camera_height + 5.5, camera_distance * 0.72),
		target + Vector3(0.0, camera_height + 10.0, camera_distance * 0.48),
		target + Vector3(0.0, camera_height + 15.0, camera_distance * 0.22),
	]

	var exclusions: Array[RID] = []
	if player is CollisionObject3D:
		exclusions.append((player as CollisionObject3D).get_rid())
	if heartforge is CollisionObject3D:
		exclusions.append((heartforge as CollisionObject3D).get_rid())

	var last_hit: Dictionary = {}
	for candidate in candidates:
		var query := PhysicsRayQueryParameters3D.create(target_eye, candidate)
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = exclusions
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return candidate
		last_hit = hit

	if not last_hit.is_empty():
		var collision_position: Vector3 = last_hit.get("position", desired)
		var direction := (collision_position - target_eye).normalized()
		var safe_distance := maxf(5.0, target_eye.distance_to(collision_position) - 1.0)
		return target_eye + direction * safe_distance
	return desired


func _set_region_map_emphasis(value: bool) -> void:
	for node in get_tree().get_nodes_in_group(&"world_regions"):
		if is_instance_valid(node) and node.has_method(&"set_map_emphasis"):
			node.call(&"set_map_emphasis", value)


func _discovered_region_centroid() -> Vector3:
	if region_director == null:
		return Vector3.ZERO
	var regions := region_director.discovered_regions()
	if regions.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	var count := 0
	for data in regions:
		var region_id := StringName(str(data.get("id", "")))
		total += region_director.center(region_id)
		count += 1
	return total / float(maxi(1, count))
