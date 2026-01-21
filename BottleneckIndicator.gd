extends Control
class_name BottleneckIndicator

@export var texture_scale: float = 1.0

var circle_texture: Texture2D
var triangle_texture: Texture2D

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
    queue_redraw()


func set_state(new_state: int) -> void:
    if state != new_state:
        state = new_state
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
