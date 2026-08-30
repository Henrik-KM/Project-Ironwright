class_name RegionPresentationLodDirector3D
extends Node

## Reduces distant region landmark rendering while preserving every landmark's
## physical identity, pressure state, discovery state and save contract.

signal detail_changed(region_id: StringName, detail_level: int)
signal region_stream_changed(region_id: StringName, streamed_in: bool)

const FULL_RADIUS := 76.0
const REDUCED_RADIUS := 120.0
# Keep the opening resident set to the Heartforge district. Remote authored
# packages are still streamed when the player physically approaches them, but
# the title/opening frame must not synchronously import half the town before it
# can draw. The hysteresis gap prevents thrashing at a district boundary.
const STREAM_IN_RADIUS := 68.0
const STREAM_OUT_RADIUS := 84.0
const PREFETCH_RADIUS := 190.0
const MAX_PREFETCHED_PACKAGES := 2

var region_director: WorldRegionDirector3D
var player: Node3D
var focus_provider: Callable
var detail_modes: Dictionary = {}
var stream_states: Dictionary = {}
var prefetch_order: Array[StringName] = []
var prefetch_enabled: bool = false
var _refresh_clock: float = 0.0


func configure(next_region_director: WorldRegionDirector3D, next_player: Node3D, next_focus_provider: Callable = Callable()) -> void:
    region_director = next_region_director
    player = next_player
    focus_provider = next_focus_provider


func _ready() -> void:
    refresh_now()


func _process(delta: float) -> void:
    _refresh_clock += delta
    if _refresh_clock < 0.45:
        return
    _refresh_clock = 0.0
    refresh_now()


func refresh_now() -> void:
    if region_director == null or player == null:
        return
    var focus := _focus_position()
    for raw_landmark in region_director.landmarks.values():
        var landmark := raw_landmark as RegionLandmark3D
        if landmark == null:
            continue
        var distance := focus.distance_to(landmark.global_position)
        landmark.set_player_proximity(distance)
        # Start with only the focus ring resident. The previous default of
        # true caused every authored district to import during the first
        # frame because the whole town fits inside the old stream-out radius.
        var previous_streamed := bool(stream_states.get(landmark.region_id, false))
        var next_streamed := distance <= STREAM_IN_RADIUS if not previous_streamed else distance <= STREAM_OUT_RADIUS
        stream_states[landmark.region_id] = next_streamed
        landmark.set_streamed_in(next_streamed)
        if previous_streamed != next_streamed:
            region_stream_changed.emit(landmark.region_id, next_streamed)
        var next_level := 0 if distance <= FULL_RADIUS else (1 if distance <= REDUCED_RADIUS else 2)
        var previous := int(detail_modes.get(landmark.region_id, -1))
        if previous == next_level:
            # Re-apply the presentation state because discovery and authored
            # detail layers may attach after the mode was first calculated.
            landmark.set_presentation_detail_level(next_level)
            continue
        detail_modes[landmark.region_id] = next_level
        landmark.set_presentation_detail_level(next_level)
        detail_changed.emit(landmark.region_id, next_level)
    if prefetch_enabled:
        _refresh_prefetch(focus)


func detail_mode_for(region_id: StringName) -> int:
    return int(detail_modes.get(region_id, 0))


func set_prefetch_enabled(value: bool) -> void:
    if prefetch_enabled == value:
        return
    prefetch_enabled = value
    if prefetch_enabled:
        refresh_now()


func is_region_streamed(region_id: StringName) -> bool:
    return bool(stream_states.get(region_id, true))


func set_region_streamed(region_id: StringName, streamed_in: bool) -> void:
    var landmark := region_director.get_landmark(region_id) if region_director != null else null
    if landmark == null:
        return
    var previous_streamed := bool(stream_states.get(region_id, false))
    stream_states[region_id] = streamed_in
    landmark.set_streamed_in(streamed_in)
    if previous_streamed != streamed_in:
        region_stream_changed.emit(region_id, streamed_in)
    if streamed_in:
        prefetch_order.erase(region_id)


func prefetch_region(region_id: StringName) -> bool:
    if region_director == null:
        return false
    var landmark := region_director.get_landmark(region_id) as RegionLandmark3D
    if landmark == null or bool(stream_states.get(region_id, false)):
        return false
    if landmark.prefetch_authored_model() or landmark.authored_model_package_ready() or landmark.authored_model_package_loading():
        prefetch_order.erase(region_id)
        prefetch_order.push_front(region_id)
        _trim_prefetches()
        return true
    return false


func prefetched_region_count() -> int:
    var count := 0
    for region_id in prefetch_order:
        var landmark := region_director.get_landmark(region_id) as RegionLandmark3D if region_director != null else null
        if landmark != null and (landmark.authored_model_package_ready() or landmark.authored_model_package_loading()):
            count += 1
    return count


func _refresh_prefetch(focus: Vector3) -> void:
    var candidates: Array[Dictionary] = []
    for raw_landmark in region_director.landmarks.values():
        var landmark := raw_landmark as RegionLandmark3D
        if landmark == null or landmark.region_kind == &"sanctuary":
            continue
        if bool(stream_states.get(landmark.region_id, false)):
            continue
        var distance := focus.distance_to(landmark.global_position)
        if distance <= PREFETCH_RADIUS:
            candidates.append({"region_id": landmark.region_id, "distance": distance})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a.get("distance", INF)) < float(b.get("distance", INF))
    )
    var desired: Array[StringName] = []
    for candidate in candidates:
        if desired.size() >= MAX_PREFETCHED_PACKAGES:
            break
        var region_id := candidate.get("region_id", &"") as StringName
        if prefetch_region(region_id):
            desired.append(region_id)
    for region_id in prefetch_order.duplicate():
        if region_id in desired:
            continue
        var stale_landmark := region_director.get_landmark(region_id) as RegionLandmark3D
        if stale_landmark != null:
            stale_landmark.release_prefetched_authored_model()
        prefetch_order.erase(region_id)


func _trim_prefetches() -> void:
    while prefetch_order.size() > MAX_PREFETCHED_PACKAGES:
        var stale_id: StringName = prefetch_order.pop_back()
        var stale_landmark := region_director.get_landmark(stale_id) as RegionLandmark3D if region_director != null else null
        if stale_landmark != null:
            stale_landmark.release_prefetched_authored_model()


func streamed_region_count() -> int:
    var count := 0
    for value in stream_states.values():
        if bool(value):
            count += 1
    return count


func _focus_position() -> Vector3:
    if focus_provider.is_valid():
        var value: Variant = focus_provider.call()
        if value is Vector3:
            return value
        if value is Node3D and is_instance_valid(value):
            return (value as Node3D).global_position
    return player.global_position
