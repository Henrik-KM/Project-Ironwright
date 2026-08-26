class_name RegionPresentationLodDirector3D
extends Node

## Reduces distant region landmark rendering while preserving every landmark's
## physical identity, pressure state, discovery state and save contract.

signal detail_changed(region_id: StringName, detail_level: int)
signal region_stream_changed(region_id: StringName, streamed_in: bool)

const FULL_RADIUS := 76.0
const REDUCED_RADIUS := 152.0
const STREAM_IN_RADIUS := 214.0
const STREAM_OUT_RADIUS := 252.0

var region_director: WorldRegionDirector3D
var player: Node3D
var focus_provider: Callable
var detail_modes: Dictionary = {}
var stream_states: Dictionary = {}
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
        var previous_streamed := bool(stream_states.get(landmark.region_id, true))
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


func detail_mode_for(region_id: StringName) -> int:
    return int(detail_modes.get(region_id, 0))


func is_region_streamed(region_id: StringName) -> bool:
    return bool(stream_states.get(region_id, true))


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
