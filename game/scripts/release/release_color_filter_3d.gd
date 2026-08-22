class_name ReleaseColorFilter3D
extends CanvasLayer

## Applies the selected colour-vision correction to the rendered world while
## leaving the high-contrast, localized menu layer above it untouched.
##
## This is intentionally a presentation-only layer. It does not recolour
## simulation data or alter the authored material sources, so screenshots,
## saves and gameplay remain deterministic across accessibility choices.

const FILTER_LAYER := 18
const SUPPORTED_MODES: Array[StringName] = [&"off", &"deuteranopia", &"protanopia", &"tritanopia"]

var settings_service: ReleaseSettingsService3D
var filter_rect: ColorRect
var filter_material: ShaderMaterial


func configure(next_settings: ReleaseSettingsService3D) -> void:
    settings_service = next_settings


func _ready() -> void:
    layer = FILTER_LAYER
    process_mode = Node.PROCESS_MODE_ALWAYS
    name = "ReleaseColorFilter"
    filter_rect = ColorRect.new()
    filter_rect.name = "ColorVisionCorrection"
    filter_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    filter_rect.color = Color.WHITE
    filter_material = ShaderMaterial.new()
    filter_material.shader = _build_shader()
    filter_rect.material = filter_material
    add_child(filter_rect)
    if settings_service != null:
        settings_service.settings_changed.connect(_on_settings_changed)
    _apply_current_mode()


func current_mode() -> StringName:
    if settings_service == null:
        return &"off"
    var raw := StringName(str(settings_service.get_value(&"colorblind_mode", "off")))
    return raw if SUPPORTED_MODES.has(raw) else &"off"


func is_active() -> bool:
    return current_mode() != &"off"


func _on_settings_changed(_next_settings: Dictionary) -> void:
    _apply_current_mode()


func _apply_current_mode() -> void:
    if filter_rect == null or filter_material == null:
        return
    var mode := current_mode()
    filter_rect.visible = mode != &"off"
    filter_material.set_shader_parameter("mode", _mode_index(mode))


func _mode_index(mode: StringName) -> int:
    match mode:
        &"deuteranopia": return 1
        &"protanopia": return 2
        &"tritanopia": return 3
    return 0


func _build_shader() -> Shader:
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform int mode = 0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

vec3 apply_matrix(vec3 color, mat3 matrix_value) {
    return clamp(matrix_value * color, vec3(0.0), vec3(1.0));
}

void fragment() {
    vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
    vec3 corrected = source.rgb;
    if (mode == 1) {
        // Deuteranopia: preserve luminance while separating red/green cues.
        corrected = apply_matrix(source.rgb, mat3(
            vec3(0.367, 0.861, -0.228),
            vec3(0.280, 0.673,  0.047),
            vec3(-0.012, 0.043,  0.969)
        ));
    } else if (mode == 2) {
        // Protanopia: keep the blue/yellow channel relationship stable.
        corrected = apply_matrix(source.rgb, mat3(
            vec3(0.152, 1.053, -0.205),
            vec3(0.115, 0.786,  0.099),
            vec3(-0.004, -0.048, 1.052)
        ));
    } else if (mode == 3) {
        // Tritanopia: preserve red/green separation while lifting blue cues.
        corrected = apply_matrix(source.rgb, mat3(
            vec3(1.256, -0.077, -0.179),
            vec3(-0.078, 0.931,  0.147),
            vec3(0.005, 0.691, 0.304)
        ));
    }
    COLOR = vec4(corrected, source.a);
}
"""
    return shader
