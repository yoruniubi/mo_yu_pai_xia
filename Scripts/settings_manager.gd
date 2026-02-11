extends Node

const SETTINGS_PATH := "user://settings.cfg"

var settings := {
	"fullscreen": false,
	"max_fps": 60,
	"master_volume_db": -6.0,
	"bgm_volume_db": -6.0,
	"resolution": Vector2i(720, 1280)
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
		save_settings()

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
		DisplayServer.window_set_size(settings["resolution"])

func apply_performance_settings() -> void:
	Engine.max_fps = settings["max_fps"]

func apply_audio_settings() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, settings["master_volume_db"])
	if Engine.has_singleton("BgmManager"):
		BgmManager.set_target_volume_db(settings["bgm_volume_db"])