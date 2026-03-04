extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
const BASE_RESOLUTION: Vector2i = Vector2i(720, 1280)
const PORTRAIT_ASPECT: float = 9.0 / 16.0
const RESOLUTION_SCALES: Array = [1.00, 0.94, 0.88, 0.82, 0.76, 0.70, 0.64, 0.58, 0.52, 0.46]

var settings: Dictionary = {
	"fullscreen": false,
	"max_fps": 60,
	"master_volume_db": -6.0,
	"bgm_volume_db": -6.0,
	"resolution": BASE_RESOLUTION
}

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		settings["fullscreen"] = cfg.get_value("display", "fullscreen", settings["fullscreen"])
		settings["max_fps"] = int(cfg.get_value("performance", "max_fps", settings["max_fps"]))
		settings["master_volume_db"] = float(cfg.get_value("audio", "master_volume_db", settings["master_volume_db"]))
		settings["bgm_volume_db"] = float(cfg.get_value("audio", "bgm_volume_db", settings["bgm_volume_db"]))
		var saved_res = cfg.get_value("display", "resolution", settings["resolution"])
		if saved_res is Vector2:
			settings["resolution"] = Vector2i(saved_res.x, saved_res.y)
		elif saved_res is Vector2i:
			settings["resolution"] = saved_res
	else:
		if not OS.has_feature("mobile"):
			settings["resolution"] = get_recommended_resolution()
		save_settings()

	_sanitize_display_settings()

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("display", "fullscreen", settings["fullscreen"])
	cfg.set_value("display", "resolution", settings["resolution"])
	cfg.set_value("performance", "max_fps", settings["max_fps"])
	cfg.set_value("audio", "master_volume_db", settings["master_volume_db"])
	cfg.set_value("audio", "bgm_volume_db", settings["bgm_volume_db"])
	cfg.save(SETTINGS_PATH)

func apply_settings() -> void:
	apply_display_settings()
	apply_performance_settings()
	apply_audio_settings()

func apply_display_settings() -> void:
	if OS.has_feature("mobile"):
		return
	var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if not settings["fullscreen"]:
		_sanitize_display_settings()
		DisplayServer.window_set_size(settings["resolution"])
		_center_window(settings["resolution"])

func get_available_resolutions() -> Array:
	if OS.has_feature("mobile"):
		return [BASE_RESOLUTION]

	var screen_idx: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_idx)
	if screen_size.x <= 0 or screen_size.y <= 0:
		return [BASE_RESOLUTION]

	# 保留少量边距，避免窗口贴边或被系统任务栏挤压
	var safe_w: int = int(screen_size.x * 0.96)
	var safe_h: int = int(screen_size.y * 0.96)
	var fit_h: int = min(safe_h, int(float(safe_w) / PORTRAIT_ASPECT))
	fit_h = max(fit_h, 640)

	var result: Array = []
	for s in RESOLUTION_SCALES:
		var h: int = int(fit_h * float(s))
		h = int(floor(h / 2.0) * 2.0)
		var w: int = int(floor((h * PORTRAIT_ASPECT) / 2.0) * 2.0)
		if w < 300 or h < 500:
			continue
		var res: Vector2i = Vector2i(w, h)
		if not result.has(res):
			result.append(res)

	if result.is_empty():
		var fallback_h: int = clamp(fit_h, 640, 1280)
		fallback_h = int(floor(fallback_h / 2.0) * 2.0)
		var fallback_w: int = int(floor((fallback_h * PORTRAIT_ASPECT) / 2.0) * 2.0)
		result.append(Vector2i(fallback_w, fallback_h))

	result.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y)

	return result

func get_recommended_resolution() -> Vector2i:
	var options = get_available_resolutions()
	if options.is_empty():
		return BASE_RESOLUTION
	return options[options.size() - 1]

func _sanitize_display_settings() -> void:
	if OS.has_feature("mobile"):
		settings["resolution"] = BASE_RESOLUTION
		return

	var current: Variant = settings["resolution"]
	if current is Vector2:
		current = Vector2i(current.x, current.y)
	elif current is not Vector2i:
		current = BASE_RESOLUTION

	var current_res: Vector2i = current
	if current_res.x > current_res.y:
		current_res = Vector2i(current_res.y, current_res.x)

	var options = get_available_resolutions()
	if not options.has(current_res):
		current_res = get_recommended_resolution()

	settings["resolution"] = current_res

func _center_window(window_size: Vector2i) -> void:
	var screen_idx: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_idx)
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	var pos: Vector2i = Vector2i(
		int(max((screen_size.x - window_size.x) / 2, 0)),
		int(max((screen_size.y - window_size.y) / 2, 0))
	)
	DisplayServer.window_set_position(pos)

func apply_performance_settings() -> void:
	Engine.max_fps = settings["max_fps"]

func apply_audio_settings() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, settings["master_volume_db"])
	if Engine.has_singleton("BgmManager"):
		BgmManager.set_target_volume_db(settings["bgm_volume_db"])