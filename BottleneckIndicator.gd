extends Control
class_name BottleneckIndicator

@export var texture_scale: float = 1.0

var circle_texture: Texture2D
var triangle_texture: Texture2D
var custom_tooltip: PanelContainer = null

# state: -1 = paused, 0 = inactive, 1 = starved, 2 = optimal, 3 = bottleneck
var state: int = 0

const COLOR_GOOD := Color(0, 1, 0)
const COLOR_STARVED := Color(1, 1, 0)
const COLOR_INACTIVE := Color(1, 0, 0)
const COLOR_PAUSED := Color(0.5, 0.5, 0.5)


func _ready() -> void:
    circle_texture = load("res://textures/icons/circle_full.png")
    triangle_texture = load("res://textures/icons/triangle_down_full.png")
    custom_minimum_size = Vector2(16, 16)
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_NONE

    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

    queue_redraw()


func _on_mouse_entered() -> void:
    if custom_tooltip == null:
        custom_tooltip = _create_custom_tooltip()
        get_tree().root.add_child(custom_tooltip)

    custom_tooltip.visible = true
    _update_tooltip_position()


func _on_mouse_exited() -> void:
    if custom_tooltip:
        custom_tooltip.visible = false


func _process(_delta: float) -> void:
    if custom_tooltip and custom_tooltip.visible:
        _update_tooltip_position()


func _update_tooltip_position() -> void:
    if custom_tooltip:
        var mouse_pos := get_global_mouse_position()
        custom_tooltip.global_position = mouse_pos + Vector2(10, 10)


func _create_custom_tooltip() -> PanelContainer:
    var label := Label.new()
    label.text = _get_tooltip_for_state(state)
    label.add_theme_color_override("font_color", Color(0.57, 0.69, 0.90, 1.0))
    label.add_theme_font_size_override("font_size", 16)

    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.133, 0.169, 0.235, 1.0)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.57, 0.69, 0.90, 0.5)
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    panel.add_theme_stylebox_override("panel", style)
    panel.add_child(label)
    panel.visible = false
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    return panel


func set_state(new_state: int) -> void:
    if state != new_state:
        state = new_state
        if custom_tooltip:
            var label = custom_tooltip.get_child(0) as Label
            if label:
                label.text = _get_tooltip_for_state(state)
        queue_redraw()


func _draw() -> void:
    var s := min(size.x, size.y)
    var tex_size := Vector2(s, s) * texture_scale
    var tex_pos := (size - tex_size) / 2.0
    var color := _get_color_for_state(state)

    # optimal uses triangle, scaled up to match circle visual weight
    if state == 2 and triangle_texture:
        var triangle_scale := 1.3
        var tri_size := tex_size * triangle_scale
        var tri_pos := (size - tri_size) / 2.0
        draw_texture_rect(triangle_texture, Rect2(tri_pos, tri_size), false, color)
    elif circle_texture:
        draw_texture_rect(circle_texture, Rect2(tex_pos, tex_size), false, color)


func _get_color_for_state(s: int) -> Color:
    match s:
        -1: return COLOR_PAUSED
        0: return COLOR_INACTIVE
        1: return COLOR_STARVED
        2: return COLOR_GOOD
        3: return COLOR_GOOD
        _: return COLOR_INACTIVE


func _get_tooltip_for_state(s: int) -> String:
    match s:
        -1: return "paused"
        0: return "inactive - no input"
        1: return "starved - input less than processing speed"
        2: return "optimal - input equivalent to processing speed"
        3: return "bottleneck - input exceeds processing speed"
        _: return "unknown"
