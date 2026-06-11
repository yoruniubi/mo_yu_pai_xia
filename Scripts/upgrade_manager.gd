extends Node

# ─────────────────────────────────────────────────────────────────────────────
# MetaProgressManager — 局外升级进度单例
# 在 Project > Project Settings > Autoload 中注册为 "MetaProgressManager"
# ─────────────────────────────────────────────────────────────────────────────

const SAVE_PATH = "user://meta_progress.cfg"

# 内存中的数据
var _points: int = 0          # 当前可用积分
var _levels: Dictionary = {}  # { upgrade_id: current_level }

func _ready() -> void:
	load_data()

# ──────────────────────────────────────────────────────────────────────────────
# 积分操作
# ──────────────────────────────────────────────────────────────────────────────

func get_points() -> int:
	return _points

func add_points(amount: int) -> void:
	_points = max(0, _points + amount)

func spend_points(amount: int) -> bool:
	if _points < amount:
		return false
	_points -= amount
	return true

# ──────────────────────────────────────────────────────────────────────────────
# 升级等级操作
# ──────────────────────────────────────────────────────────────────────────────

func get_level(id: String) -> int:
	return _levels.get(id, 0)

func set_level(id: String, level: int) -> void:
	_levels[id] = level

func has_upgrade(id: String) -> bool:
	return get_level(id) > 0

# 重置单个升级并返还积分
func reset_upgrade(id: String, cost_per_level: int) -> bool:
	var cur_lvl = get_level(id)
	if cur_lvl <= 0:
		return false
	var refund = cur_lvl * cost_per_level
	_points += refund
	_levels.erase(id)
	return true

# ──────────────────────────────────────────────────────────────────────────────
# 存档 / 读档
# ──────────────────────────────────────────────────────────────────────────────

func save() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "points", _points)
	for id in _levels:
		cfg.set_value("levels", id, _levels[id])
	cfg.save(SAVE_PATH)

func load_data() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_points = cfg.get_value("meta", "points", 0)
	if cfg.has_section("levels"):
		for id in cfg.get_section_keys("levels"):
			_levels[id] = cfg.get_value("levels", id, 0)

# ──────────────────────────────────────────────────────────────────────────────
# 调试用：重置所有进度
# ──────────────────────────────────────────────────────────────────────────────

func reset_all() -> void:
	_points = 0
	_levels.clear()
	save()