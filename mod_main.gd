extends Node

const MOD_DIR := "Bottlenecks"
const LOG_NAME := "Bottlenecks:Main"

const INDICATOR_SIZE := Vector2(20, 20)
const UPDATE_INTERVAL := 0.5

const BottleneckIndicator = preload("res://mods-unpacked/cogo-Bottlenecks/BottleneckIndicator.gd")

# how the processing capacity of a window is measured
enum Kind {
    PROCESS,  # window has a Process node: capacity = process.rate (speed / goal)
    SPEED,    # capacity = speed_node.count / goal
    RATE,     # capacity = window.rate (burners)
    INSTANT,  # no processing speed, throughput is limited by the slowest input
}

# windows without a Process node, matched by property names
# inputs: ResourceContainer properties consumed per cycle
# inputs_container: node whose children are the inputs
# extra: properties that must also exist (disambiguation)
# speed: ResourceContainer property whose count is the processing speed
# goal: window property dividing the speed (cycles per second)
const LEGACY_RULES := [
    {"inputs": ["file"], "speed": "research_power"},                   # data_lab
    {"inputs": ["file"], "speed": "upload", "goal": "goal"},           # request_uploader
    {"inputs": ["code", "bug_fix"]},                                   # fix_code
    {"inputs": ["input", "augment"]},                                  # optimize_code, comment_code
    {"inputs": ["variable"], "extra": ["array"]},                      # code_array
    {"inputs": ["input1", "input2"]},                                  # variable_combiner
    {"inputs": ["string", "input"]},                                   # code_hashmap
    {"inputs": ["input", "input2"]},                                   # torrent_filter
    {"inputs_container": "requirements", "extra": ["code"]},           # code_file (code_bugfix, code_driver...)
]

var DEBUG_MODE := false
var tracked_windows := {}
var update_timer := 0.0


func _init() -> void:
    ModLoaderLog.info("Initializing Bottlenecks mod", LOG_NAME)


func _ready() -> void:
    ModLoaderLog.info("Bottlenecks mod ready, scanning for windows...", LOG_NAME)
    Signals.window_initialized.connect(_on_window_initialized)
    call_deferred("_scan_for_windows")


func _process(delta: float) -> void:
    update_timer += delta
    if update_timer >= UPDATE_INTERVAL:
        update_timer = 0.0
        _update_all_indicators()


func _on_window_initialized(window: Node) -> void:
    call_deferred("_try_add_indicator", window)


func _try_add_indicator(window: Node) -> void:
    if _is_valid_window(window):
        _add_indicator_to_window(window)


func _scan_for_windows() -> void:
    var root := get_tree().root
    _find_window_nodes(root)
    if DEBUG_MODE:
        ModLoaderLog.debug("Found %d trackable windows" % tracked_windows.size(), LOG_NAME)


func _find_window_nodes(node: Node) -> void:
    if node == null:
        return
    if _is_valid_window(node):
        _add_indicator_to_window(node)
    for child in node.get_children():
        _find_window_nodes(child)


func _is_valid_window(node: Node) -> bool:
    return not _get_rule(node).is_empty()


# returns {"kind": Kind, "inputs": Array, "speed": Node, "goal": float}
# or an empty dictionary when the window has no measurable throughput
func _get_rule(window: Node) -> Dictionary:
    if "paused" not in window:
        return {}

    var process = _get_node_property(window, "process")
    var process_inputs: Array = []
    if process != null and "rate" in process and "resources" in process:
        var resources = process.get("resources")
        if resources is Array:
            process_inputs = resources

    # analyzer, compressor, enhancer, uploader, trainer, debug, torrent downloader, code, server, crafter...
    if not process_inputs.is_empty():
        return {"kind": Kind.PROCESS, "inputs": process_inputs, "speed": process, "goal": 1.0}

    # crafters and burners: materials container + a speed resource or a rate
    var materials := _get_container_children(window, "materials")
    if not materials.is_empty():
        if process != null and "rate" in process:
            return {"kind": Kind.PROCESS, "inputs": materials, "speed": process, "goal": 1.0}
        var speed = _get_node_property(window, "work_speed")
        if speed == null:
            speed = _get_node_property(window, "speed")
        if speed != null:
            return {"kind": Kind.SPEED, "inputs": materials, "speed": speed, "goal": 1.0}
        if "rate" in window:
            return {"kind": Kind.RATE, "inputs": materials, "speed": null, "goal": 1.0}
        return {}

    for rule in LEGACY_RULES:
        var inputs: Array = []
        if rule.has("inputs_container"):
            inputs = _get_container_children(window, rule["inputs_container"])
            if inputs.is_empty():
                continue
        else:
            var missing := false
            for prop_name in rule["inputs"]:
                var input = _get_node_property(window, prop_name)
                if input == null:
                    missing = true
                    break
                inputs.append(input)
            if missing:
                continue

        var extra_missing := false
        for prop_name in rule.get("extra", []):
            if _get_node_property(window, prop_name) == null:
                extra_missing = true
                break
        if extra_missing:
            continue

        if rule.has("speed"):
            var speed = _get_node_property(window, rule["speed"])
            if speed == null:
                continue
            var goal := 1.0
            if rule.has("goal") and rule["goal"] in window:
                goal = float(window.get(rule["goal"]))
            return {"kind": Kind.SPEED, "inputs": inputs, "speed": speed, "goal": goal}

        return {"kind": Kind.INSTANT, "inputs": inputs, "speed": null, "goal": 1.0}

    return {}


# a child node exposing count/production (ResourceContainer) or rate (Process)
func _get_node_property(node: Node, prop_name: String):
    if prop_name in node:
        var prop = node.get(prop_name)
        if prop != null and prop is Node:
            if "count" in prop or "production" in prop or "rate" in prop:
                return prop
    return null


func _get_container_children(node: Node, container_name: String) -> Array:
    if container_name in node:
        var container = node.get(container_name)
        if container != null and container is Node:
            return container.get_children()
    return []


func _add_indicator_to_window(window: Node) -> void:
    if window in tracked_windows:
        return

    var container := _find_title_container(window)
    if container == null:
        if DEBUG_MODE:
            ModLoaderLog.debug("No TitleContainer found in window: %s" % window.name, LOG_NAME)
        return

    var margin := MarginContainer.new()
    margin.name = "BottleneckMargin"
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_left", 12)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var indicator := BottleneckIndicator.new()
    indicator.name = "BottleneckIndicator"
    indicator.size_flags_horizontal = Control.SIZE_SHRINK_END
    indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    indicator.custom_minimum_size = INDICATOR_SIZE

    margin.add_child(indicator)
    container.add_child(margin)
    tracked_windows[window] = indicator

    if DEBUG_MODE:
        ModLoaderLog.debug("Added indicator to window: %s" % window.name, LOG_NAME)


func _find_title_container(window: Node) -> Node:
    var title_container = window.get_node_or_null("TitlePanel/TitleContainer")
    if title_container != null:
        return title_container
    # fallback: look for any hboxcontainer in titlepanel
    var title_panel = window.get_node_or_null("TitlePanel")
    if title_panel != null:
        for child in title_panel.get_children():
            if child is HBoxContainer:
                return child
    return null


func _update_all_indicators() -> void:
    var windows_to_remove := []

    for window in tracked_windows:
        if not is_instance_valid(window):
            windows_to_remove.append(window)
            continue

        var indicator = tracked_windows[window]
        if not is_instance_valid(indicator):
            windows_to_remove.append(window)
            continue

        var state := _calculate_bottleneck_state(window)
        indicator.set_state(state)

    for window in windows_to_remove:
        tracked_windows.erase(window)


func _calculate_bottleneck_state(window: Node) -> int:
    # state: -1 = paused, 0 = inactive, 1 = starved, 2 = optimal, 3 = bottleneck

    if "paused" in window and window.get("paused"):
        return -1

    var rule := _get_rule(window)
    if rule.is_empty():
        return 0

    # cycles per second the inputs can sustain, limited by the slowest input
    var input_rate := INF
    for input in rule["inputs"]:
        if not is_instance_valid(input):
            continue
        input_rate = minf(input_rate, _get_production(input) / _get_required(input))
    if input_rate == INF or input_rate <= 0.0:
        return 0

    # cycles per second the window can process
    var processing_capacity := 0.0
    match rule["kind"]:
        Kind.PROCESS:
            processing_capacity = float(rule["speed"].get("rate"))
        Kind.SPEED:
            var goal: float = rule["goal"]
            if goal > 0:
                processing_capacity = _get_count(rule["speed"]) / goal
        Kind.RATE:
            processing_capacity = float(window.get("rate"))
        Kind.INSTANT:
            for input in rule["inputs"]:
                if not is_instance_valid(input):
                    continue
                processing_capacity = maxf(processing_capacity, _get_production(input) / _get_required(input))

    if processing_capacity <= 0.0:
        return 3
    if is_equal_approx(input_rate, processing_capacity):
        return 2
    if input_rate < processing_capacity:
        return 1
    return 3


func _get_count(node) -> float:
    if node == null:
        return 0.0
    if "count" in node:
        return float(node.get("count"))
    return 0.0


func _get_production(node) -> float:
    if node == null:
        return 0.0
    if "production" in node:
        return float(node.get("production"))
    return 0.0


func _get_required(node) -> float:
    if node == null:
        return 1.0
    if "required" in node:
        var req = node.get("required")
        if req > 0:
            return float(req)
    return 1.0
