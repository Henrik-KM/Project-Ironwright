class_name RegionPresentationLodDirector3D
extends Node

## Reduces distant region landmark rendering while preserving every landmark's
## physical identity, pressure state, discovery state and save contract.

signal detail_changed(region_id: StringName, detail_level: int)

const FULL_RADIUS := 76.0
const REDUCED_RADIUS := 152.0

var region_director: WorldRegionDirector3D
var player: Node3D
var detail_modes: Dictionary = {}
var _refresh_clock: float = 0.0


func configure(next_region_director: WorldRegionDirector3D, next_player: Node3D) -> void:
    region_director = next_region_director
    player = next_player


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
    for raw_landmark in region_director.landmarks.values():
        var landmark := raw_landmark as RegionLandmark3D
        if landmark == null:
            continue
        var distance := player.global_position.distance_to(landmark.global_position)
        landmark.set_player_proximity(distance)
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
