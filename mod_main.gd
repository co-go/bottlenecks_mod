extends Node

const MOD_DIR := "Bottlenecks"
const LOG_NAME := "Bottlenecks:Main"

const INDICATOR_SIZE := Vector2(20, 20)
const UPDATE_INTERVAL := 0.5

const BottleneckIndicator = preload("res://mods-unpacked/cogo-Bottlenecks/BottleneckIndicator.gd")

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
    # file + clock (analyzer, enhancer, compressor, packager, etc)
    if _has_property(node, "file") and _has_property(node, "clock"):
        return true
    # file + research_power (data_lab)
    if _has_property(node, "file") and _has_property(node, "research_power"):
        return true
    # text + clock (compiler)
    if _has_property(node, "text") and _has_property(node, "clock"):
        return true
    # file + upload (uploader)
    if _has_property(node, "file") and _has_property(node, "upload"):
        return true
    # file + gpu (trainer)
    if _has_property(node, "file") and _has_property(node, "gpu"):
        return true
    # code + bug_fix (fix_code)
    if _has_property(node, "code") and _has_property(node, "bug_fix"):
        return true
    # code + optimization (optimize_code)
    if _has_property(node, "code") and _has_property(node, "optimization"):
        return true
    # materials + speed (crafter, metal_press, polymerizer)
    if _has_container(node, "materials") and "speed" in node:
        return true
    # variable + array (code_array)
    if _has_property(node, "variable") and _has_property(node, "array"):
        return true
    # code + code_speed (debug)
    if _has_property(node, "code") and _has_property(node, "code_speed"):
        return true
    # input1 + input2 (variable_combiner)
    if _has_property(node, "input1") and _has_property(node, "input2"):
        return true
    # code_speed + result (generic code windows)
    if _has_property(node, "code_speed") and _has_property(node, "result"):
        return true
    # requirements container + code (code_file)
    if _has_container(node, "requirements") and _has_property(node, "code"):
        return true
    # oil + refined_oil (oil_refiner)
    if _has_property(node, "oil") and _has_property(node, "refined_oil"):
        return true
    # torrent_downloader (torrent + download)
    if _has_property(node, "torrent") and _has_property(node, "download"):
        return true
    # redownloader (file + download + output)
    if _has_property(node, "file") and _has_property(node, "download") and _has_property(node, "output"):
        return true
    # torrent_filter (input + input2 + download)
    if _has_property(node, "input") and _has_property(node, "input2") and _has_property(node, "download"):
        return true
    # code_hashmap (string + input, dual input instant processor)
    if _has_property(node, "string") and _has_property(node, "input") and _has_property(node, "output"):
        return true
    # remasterer (game + program + video + clock)
    if _has_property(node, "game") and _has_property(node, "program") and _has_property(node, "video") and _has_property(node, "clock"):
        return true
    # splicer (video + clock with dual outputs: image + sound)
    if _has_property(node, "video") and _has_property(node, "clock") and _has_property(node, "image") and _has_property(node, "sound"):
        return true
    # frame_generator (video + image + clock)
    if _has_property(node, "video") and _has_property(node, "image") and _has_property(node, "clock"):
        return true
    return false


func _has_property(node: Node, prop_name: String) -> bool:
    if prop_name in node:
        var prop = node.get(prop_name)
        if prop != null and prop is Node:
            return "count" in prop or "production" in prop
    return false


func _has_container(node: Node, container_name: String) -> bool:
    if container_name in node:
        var container = node.get(container_name)
        if container != null and container is Node:
            return container.get_child_count() > 0
    return false


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

    var input_rate := 0.0
    var processing_capacity := 0.0

    # file + clock
    if _has_property(window, "file") and _has_property(window, "clock"):
        var file_node = window.get("file")
        var clock_node = window.get("clock")
        var goal: float = window.get("goal") if "goal" in window else 1.0
        var required: float = _get_required(file_node)
        input_rate = _get_production(file_node) / required
        if goal > 0:
            processing_capacity = _get_count(clock_node) / goal

    # file + research_power
    elif _has_property(window, "file") and _has_property(window, "research_power"):
        var file_node = window.get("file")
        var research_node = window.get("research_power")
        input_rate = _get_production(file_node)
        processing_capacity = _get_count(research_node)

    # text + clock
    elif _has_property(window, "text") and _has_property(window, "clock"):
        var text_node = window.get("text")
        var clock_node = window.get("clock")
        var goal: float = window.get("goal") if "goal" in window else 1.0
        var required: float = _get_required(text_node)
        if required > 0:
            input_rate = _get_production(text_node) / required
        if goal > 0:
            processing_capacity = _get_count(clock_node) / goal

    # file + upload
    elif _has_property(window, "file") and _has_property(window, "upload"):
        var file_node = window.get("file")
        var upload_node = window.get("upload")
        var goal: float = window.get("goal") if "goal" in window else 1.0
        input_rate = _get_production(file_node)
        if goal > 0:
            processing_capacity = _get_count(upload_node) / goal

    # file + gpu
    elif _has_property(window, "file") and _has_property(window, "gpu"):
        var file_node = window.get("file")
        var gpu_node = window.get("gpu")
        var goal: float = window.get("goal") if "goal" in window else 1.0
        var required: float = _get_required(file_node)
        input_rate = _get_production(file_node) / required
        if goal > 0:
            processing_capacity = _get_count(gpu_node) / goal

    # code + bug_fix (two inputs)
    elif _has_property(window, "code") and _has_property(window, "bug_fix"):
        var code_node = window.get("code")
        var bug_fix_node = window.get("bug_fix")
        var code_prod := _get_production(code_node)
        var bug_fix_prod := _get_production(bug_fix_node)
        input_rate = minf(code_prod, bug_fix_prod)
        processing_capacity = maxf(code_prod, bug_fix_prod)

    # code + optimization (two inputs)
    elif _has_property(window, "code") and _has_property(window, "optimization"):
        var code_node = window.get("code")
        var opt_node = window.get("optimization")
        var code_prod := _get_production(code_node)
        var opt_prod := _get_production(opt_node)
        input_rate = minf(code_prod, opt_prod)
        processing_capacity = maxf(code_prod, opt_prod)

    # materials + speed (crafter)
    elif _has_container(window, "materials") and "speed" in window:
        var materials_container = window.get("materials")
        var speed: float = window.get("speed") if "speed" in window else 0.0
        var goal: float = window.get("goal") if "goal" in window else 1.0
        var product_node = window.get("product") if "product" in window else null
        var actual_output := _get_production(product_node) if product_node else 0.0
        var max_output := speed / goal if goal > 0 else 0.0

        var has_buffered_input := false
        for material in materials_container.get_children():
            if _get_count(material) >= _get_required(material):
                has_buffered_input = true
                break

        if max_output <= 0:
            return 0
        elif actual_output >= max_output * 0.99 and has_buffered_input:
            return 3
        elif actual_output >= max_output * 0.99:
            return 2
        else:
            return 1

    # variable + array
    elif _has_property(window, "variable") and _has_property(window, "array"):
        var variable_node = window.get("variable")
        var required: float = _get_required(variable_node)
        input_rate = _get_production(variable_node) / required if required > 0 else 0.0
        processing_capacity = input_rate

    # code + code_speed
    elif _has_property(window, "code") and _has_property(window, "code_speed"):
        var code_node = window.get("code")
        var code_speed_node = window.get("code_speed")
        var goal: float = window.get("goal") if "goal" in window else 1.0
        input_rate = _get_production(code_node)
        if goal > 0:
            processing_capacity = _get_count(code_speed_node) / goal

    # input1 + input2 (two inputs)
    elif _has_property(window, "input1") and _has_property(window, "input2"):
        var input1_node = window.get("input1")
        var input2_node = window.get("input2")
        var input1_prod := _get_production(input1_node)
        var input2_prod := _get_production(input2_node)
        input_rate = minf(input1_prod, input2_prod)
        processing_capacity = maxf(input1_prod, input2_prod)

    # code_speed + result
    elif _has_property(window, "code_speed") and _has_property(window, "result"):
        var code_speed_node = window.get("code_speed")
        var goal: float = window.get("goal") if "goal" in window else 1.0
        if goal > 0:
            processing_capacity = _get_count(code_speed_node) / goal
        input_rate = processing_capacity

    # requirements + code
    elif _has_container(window, "requirements") and _has_property(window, "code"):
        var requirements_container = window.get("requirements")
        var code_node = window.get("code")
        var min_prod := INF
        for req in requirements_container.get_children():
            var prod := _get_production(req)
            if prod < min_prod:
                min_prod = prod
        input_rate = min_prod if min_prod != INF else 0.0
        processing_capacity = _get_production(code_node) if _get_production(code_node) > 0 else input_rate

    # oil + refined_oil (oil_refiner)
    elif _has_property(window, "oil") and _has_property(window, "refined_oil"):
        var oil_node = window.get("oil")
        var speed: float = window.get("speed") if "speed" in window else 0.0
        var required: float = _get_required(oil_node)
        input_rate = _get_production(oil_node) / required if required > 0 else 0.0
        processing_capacity = speed

    # download windows (torrent_downloader, redownloader)
    elif (_has_property(window, "torrent") and _has_property(window, "download")) or \
         (_has_property(window, "file") and _has_property(window, "download") and _has_property(window, "output")):
        var download_node = window.get("download")
        var goal: float = window.get("goal") if "goal" in window else 1.0

        # use torrent input if available, otherwise file (redownloader)
        var input_node = window.get("torrent") if _has_property(window, "torrent") else window.get("file")
        input_rate = _get_production(input_node)
        if goal > 0:
            processing_capacity = _get_count(download_node) / goal

    # torrent_filter (input + input2 + download)
    elif _has_property(window, "input") and _has_property(window, "input2") and _has_property(window, "download"):
        var input1_node = window.get("input")
        var input2_node = window.get("input2")
        var download_node = window.get("download")
        var goal: float = window.get("goal") if "goal" in window else 1.0

        # input rate is limited by the slower of the two inputs
        var input1_prod := _get_production(input1_node)
        var input2_prod := _get_production(input2_node)
        input_rate = minf(input1_prod, input2_prod)

        # processing capacity is download speed / goal
        if goal > 0:
            processing_capacity = _get_count(download_node) / goal

    # code_hashmap (string + input, instant dual input processor)
    elif _has_property(window, "string") and _has_property(window, "input") and _has_property(window, "output"):
        var string_node = window.get("string")
        var input_node = window.get("input")

        # normalize by required amounts
        var string_required := _get_required(string_node)
        var input_required := _get_required(input_node)
        var string_prod := _get_production(string_node) / string_required if string_required > 0 else 0.0
        var input_prod := _get_production(input_node) / input_required if input_required > 0 else 0.0

        # for dual-input processors: slower input is bottleneck, faster is capacity
        input_rate = minf(string_prod, input_prod)
        processing_capacity = maxf(string_prod, input_prod)

    # remasterer (game + program + video + clock)
    elif _has_property(window, "game") and _has_property(window, "program") and _has_property(window, "video") and _has_property(window, "clock"):
        var game_node = window.get("game")
        var program_node = window.get("program")
        var video_node = window.get("video")
        var clock_node = window.get("clock")
        var goal: float = window.get("goal") if "goal" in window else 1.0

        # input rate is the minimum of all 3 inputs (normalized by required)
        var game_prod := _get_production(game_node)
        var program_required := _get_required(program_node)
        var video_required := _get_required(video_node)
        var program_prod := _get_production(program_node) / program_required if program_required > 0 else 0.0
        var video_prod := _get_production(video_node) / video_required if video_required > 0 else 0.0

        input_rate = minf(game_prod, minf(program_prod, video_prod))

        # processing capacity is clock speed / goal
        if goal > 0:
            processing_capacity = _get_count(clock_node) / goal

    # splicer (video + clock, dual output: image + sound)
    elif _has_property(window, "video") and _has_property(window, "clock") and _has_property(window, "image") and _has_property(window, "sound"):
        var video_node = window.get("video")
        var clock_node = window.get("clock")
        var goal: float = window.get("goal") if "goal" in window else 1.0

        # input is just video production
        input_rate = _get_production(video_node)

        # processing capacity is clock speed / goal
        if goal > 0:
            processing_capacity = _get_count(clock_node) / goal

    # frame_generator (video + image + clock)
    elif _has_property(window, "video") and _has_property(window, "image") and _has_property(window, "clock"):
        var video_node = window.get("video")
        var image_node = window.get("image")
        var clock_node = window.get("clock")
        var goal: float = window.get("goal") if "goal" in window else 1.0

        # input rate is minimum of video and image (normalized by required)
        var video_prod := _get_production(video_node)
        var image_required := _get_required(image_node)
        var image_prod := _get_production(image_node) / image_required if image_required > 0 else 0.0

        input_rate = minf(video_prod, image_prod)

        # processing capacity is clock speed / goal
        if goal > 0:
            processing_capacity = _get_count(clock_node) / goal

    else:
        return 0

    if input_rate <= 0.0:
        return 0
    if processing_capacity <= 0.0:
        return 3

    var ratio := input_rate / processing_capacity
    if ratio < 1.0:
        return 1
    elif ratio > 1.0:
        return 3
    else:
        return 2


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
