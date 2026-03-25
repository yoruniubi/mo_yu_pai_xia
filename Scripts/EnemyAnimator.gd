# EnemyAnimator.gd
extends Control # 如果是 TextureRect 用 Control，Sprite2D 则改用 Node2D

# 记录初始状态，防止动画播完后位置“跑偏”
@onready var original_pos = position
@onready var original_scale = scale

var idle_tween: Tween
var enemy_name: String = ""
var ceo_attack_phase: int = 0

func set_enemy_name(name: String) -> void:
	enemy_name = name

func _ready():
	play_idle()

# --- 1. 常态 (Idle): 呼吸感 ---
func play_idle():
	# 如果有正在播的呼吸动画，先关掉
	if idle_tween: idle_tween.kill()
	
	idle_tween = create_tween().set_loops() # 无限循环
	# 缓慢地上下浮动
	idle_tween.tween_property(self, "position:y", original_pos.y + 10, 2.0).set_trans(Tween.TRANS_SINE)
	idle_tween.tween_property(self, "position:y", original_pos.y, 2.0).set_trans(Tween.TRANS_SINE)
	
	# 同步进行微弱的缩放 (呼吸感)
	idle_tween.parallel().tween_property(self, "scale", original_scale * 1.02, 2.0).set_trans(Tween.TRANS_SINE)
	idle_tween.parallel().tween_property(self, "scale", original_scale, 2.0).set_trans(Tween.TRANS_SINE)

# --- 2. 受击 (Hit): 震动与闪红 ---
func play_hit():
	# 受击是高优先级，先杀掉呼吸动画
	if idle_tween: idle_tween.kill()
	
	var hit_tween = create_tween()
	# 瞬间变色（变红或爆白）
	modulate = Color(2, 0.5, 0.5) # 增加红色分量，数值大于1会产生发光感
	
	# 快速左右剧烈晃动
	for i in range(4):
		var offset = 10 if i % 2 == 0 else -10
		hit_tween.tween_property(self, "position:x", original_pos.x + offset, 0.05)
	
	# 恢复原状
	hit_tween.tween_property(self, "position:x", original_pos.x, 0.05)
	hit_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# 动画播完后回到呼吸状态
	hit_tween.finished.connect(play_idle)

# --- 3. 攻击 (Attack): 俯冲撞击 ---
func play_attack():
	# 普通攻击统一使用通用动作（稳定、清晰）
	_play_default_attack()


func _play_default_attack():
	if idle_tween: idle_tween.kill()
	
	var atk_tween = create_tween()
	# A. 蓄力：微微后退并缩小
	atk_tween.tween_property(self, "position:y", original_pos.y - 30, 0.2).set_trans(Tween.TRANS_QUAD)
	atk_tween.parallel().tween_property(self, "scale", original_scale * 0.9, 0.2)
	
	# B. 冲锋：迅速向玩家（下方）冲去，并放大
	atk_tween.tween_property(self, "position:y", original_pos.y + 100, 0.1).set_trans(Tween.TRANS_EXPO)
	atk_tween.parallel().tween_property(self, "scale", original_scale * 1.1, 0.1)
	
	# C. 回弹：回到原位
	atk_tween.tween_property(self, "position:y", original_pos.y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	atk_tween.parallel().tween_property(self, "scale", original_scale, 0.3)
	
	atk_tween.finished.connect(play_idle)


func _play_persona_attack(is_special: bool) -> bool:
	# 第一阶段：职场萌新
	if "鹦鹉" in enemy_name:
		_play_parrot_attack(is_special)
		return true
	if "刺猬" in enemy_name:
		_play_hedgehog_attack(is_special)
		return true
	if "浣熊" in enemy_name:
		_play_raccoon_attack(is_special)
		return true

	# 第二阶段：深水区
	if "监控猿" in enemy_name or "监控" in enemy_name:
		_play_monkey_attack(is_special)
		return true
	if "树懒" in enemy_name:
		_play_sloth_attack(is_special)
		return true
	if "审计" in enemy_name:
		_play_audit_hound_attack(is_special)
		return true

	# 第三阶段：天花板
	if "毒蛇" in enemy_name:
		_play_viper_attack(is_special)
		return true
	if "蜘蛛" in enemy_name:
		_play_spider_attack(is_special)
		return true
	if "九头蛇" in enemy_name:
		_play_hydra_attack(is_special)
		return true

	# 终章
	if "CEO" in enemy_name:
		_play_ceo_attack(is_special)
		return true

	return false


func _play_parrot_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var sweep = 18 if is_special else 12
	var loops = 4 if is_special else 3
	t.tween_property(self, "modulate", Color(0.9, 1.5, 0.9), 0.08)
	for i in range(loops):
		var dir = 1 if i % 2 == 0 else -1
		t.tween_property(self, "position:x", original_pos.x + dir * sweep, 0.06)
		t.parallel().tween_property(self, "rotation_degrees", dir * 6.0, 0.06)
	t.tween_property(self, "position:x", original_pos.x, 0.08)
	t.parallel().tween_property(self, "rotation_degrees", 0.0, 0.08)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.12)
	t.finished.connect(play_idle)


func _play_hedgehog_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	# 刺猬改为“地面翻滚突刺”而非大角度旋转，避免 pivot 导致的飞天
	var dash = 72 if is_special else 56
	var hop = 12 if is_special else 8
	t.tween_property(self, "scale", original_scale * Vector2(0.9, 0.84), 0.10)
	t.parallel().tween_property(self, "position:y", original_pos.y + hop, 0.10)
	t.parallel().tween_property(self, "rotation_degrees", -6.0, 0.10)
	t.tween_property(self, "position:x", original_pos.x + dash, 0.08).set_trans(Tween.TRANS_EXPO)
	t.parallel().tween_property(self, "rotation_degrees", 8.0, 0.08)
	t.tween_property(self, "position:x", original_pos.x - dash * 0.45, 0.08).set_trans(Tween.TRANS_EXPO)
	t.parallel().tween_property(self, "rotation_degrees", -7.0, 0.08)
	t.tween_property(self, "position", original_pos, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", original_scale, 0.24)
	t.parallel().tween_property(self, "rotation_degrees", 0.0, 0.24)
	t.finished.connect(play_idle)


func _play_raccoon_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var swipe = 90 if is_special else 65
	t.tween_property(self, "rotation_degrees", -12.0, 0.10)
	t.parallel().tween_property(self, "scale", original_scale * 0.94, 0.10)
	t.parallel().tween_property(self, "modulate", Color(1.4, 1.25, 0.8), 0.10)
	t.tween_property(self, "position:x", original_pos.x + swipe, 0.07).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(self, "rotation_degrees", 12.0, 0.07)
	t.tween_property(self, "position:x", original_pos.x - swipe * 0.8, 0.07).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(self, "rotation_degrees", -10.0, 0.07)
	t.tween_property(self, "position", original_pos, 0.2).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "rotation_degrees", 0.0, 0.2)
	t.parallel().tween_property(self, "scale", original_scale, 0.2)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.2)
	t.finished.connect(play_idle)


func _play_monkey_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var drop = 120 if is_special else 90
	t.tween_property(self, "position:y", original_pos.y - 55, 0.14).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(self, "scale", original_scale * 1.06, 0.14)
	t.parallel().tween_property(self, "modulate", Color(1.8, 1.8, 2.2), 0.14)
	t.tween_property(self, "position:y", original_pos.y + drop, 0.1).set_trans(Tween.TRANS_EXPO)
	t.parallel().tween_property(self, "scale", original_scale * 0.95, 0.1)
	t.tween_property(self, "position:y", original_pos.y, 0.26).set_trans(Tween.TRANS_BOUNCE)
	t.parallel().tween_property(self, "scale", original_scale, 0.26)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.26)
	t.finished.connect(play_idle)


func _play_sloth_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var lift = 18 if is_special else 12
	var smash = 85 if is_special else 65
	t.tween_property(self, "position:y", original_pos.y - lift, 0.34).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "scale", original_scale * 1.05, 0.34)
	t.parallel().tween_property(self, "modulate", Color(1.15, 1.15, 1.25), 0.34)
	t.tween_property(self, "position:y", original_pos.y + smash, 0.12).set_trans(Tween.TRANS_QUINT)
	t.parallel().tween_property(self, "rotation_degrees", 8.0, 0.12)
	t.tween_property(self, "position", original_pos, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation_degrees", 0.0, 0.30)
	t.parallel().tween_property(self, "scale", original_scale, 0.30)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.30)
	t.finished.connect(play_idle)


func _play_audit_hound_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var zoom = 1.22 if is_special else 1.15
	t.tween_property(self, "position:y", original_pos.y - 20, 0.12)
	t.parallel().tween_property(self, "modulate", Color(1.0, 1.45, 1.1), 0.12)
	t.tween_property(self, "scale", original_scale * zoom, 0.1).set_trans(Tween.TRANS_EXPO)
	t.parallel().tween_property(self, "position:y", original_pos.y + 75, 0.1).set_trans(Tween.TRANS_EXPO)
	for i in range(2):
		var dir = 1 if i % 2 == 0 else -1
		t.tween_property(self, "position:x", original_pos.x + dir * 16, 0.05)
	t.tween_property(self, "position", original_pos, 0.26).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "scale", original_scale, 0.26)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.26)
	t.finished.connect(play_idle)


func _play_viper_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var amp = 65 if is_special else 48
	t.tween_property(self, "rotation_degrees", -10.0, 0.08)
	t.parallel().tween_property(self, "modulate", Color(1.55, 0.8, 1.7), 0.08)
	t.tween_property(self, "position", original_pos + Vector2(amp, -16), 0.08).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "rotation_degrees", 11.0, 0.08)
	t.tween_property(self, "position", original_pos + Vector2(-amp, 12), 0.08).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "rotation_degrees", -9.0, 0.08)
	t.tween_property(self, "position", original_pos + Vector2(amp * 0.75, 20), 0.08).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "rotation_degrees", 8.0, 0.08)
	t.tween_property(self, "position", original_pos, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation_degrees", 0.0, 0.24)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.24)
	t.finished.connect(play_idle)


func _play_spider_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var jitter = 22 if is_special else 14
	t.tween_property(self, "scale", original_scale * 0.92, 0.09)
	t.parallel().tween_property(self, "modulate", Color(2.1, 1.7, 0.8), 0.09)
	for i in range(4):
		var dir = 1 if i % 2 == 0 else -1
		t.tween_property(self, "position:x", original_pos.x + dir * jitter, 0.045)
	t.tween_property(self, "position:y", original_pos.y + (90 if is_special else 70), 0.08).set_trans(Tween.TRANS_EXPO)
	t.parallel().tween_property(self, "scale", original_scale * 1.08, 0.08)
	t.tween_property(self, "position", original_pos, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", original_scale, 0.28)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.28)
	t.finished.connect(play_idle)


func _play_hydra_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var thrust = 72 if is_special else 56
	t.tween_property(self, "modulate", Color(1.2, 1.4, 2.0), 0.08)
	for i in range(3):
		var dir = 1 if i % 2 == 0 else -1
		t.tween_property(self, "position", original_pos + Vector2(dir * thrust, 18 + i * 6), 0.07).set_trans(Tween.TRANS_CUBIC)
		t.parallel().tween_property(self, "rotation_degrees", dir * 7.0, 0.07)
	t.tween_property(self, "position", original_pos, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation_degrees", 0.0, 0.25)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.25)
	t.finished.connect(play_idle)


func _play_ceo_attack(is_special: bool):
	if idle_tween: idle_tween.kill()
	var t = create_tween()
	var phase = ceo_attack_phase % 3
	ceo_attack_phase += 1

	if phase == 0:
		# 狮态：威压下砸
		t.tween_property(self, "modulate", Color(2.0, 0.9, 0.9), 0.1)
		t.tween_property(self, "position:y", original_pos.y + (110 if is_special else 90), 0.1).set_trans(Tween.TRANS_EXPO)
	elif phase == 1:
		# 羊态：温和但连续推压
		t.tween_property(self, "modulate", Color(1.9, 1.9, 1.9), 0.1)
		for i in range(2):
			var dir = 1 if i % 2 == 0 else -1
			t.tween_property(self, "position:x", original_pos.x + dir * 34, 0.07)
	else:
		# 蛇态：阴冷突刺
		t.tween_property(self, "modulate", Color(1.3, 0.8, 2.0), 0.1)
		t.tween_property(self, "position", original_pos + Vector2(60, 30), 0.08).set_trans(Tween.TRANS_EXPO)
		t.parallel().tween_property(self, "rotation_degrees", 10.0, 0.08)

	t.tween_property(self, "position", original_pos, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation_degrees", 0.0, 0.30)
	t.parallel().tween_property(self, "scale", original_scale, 0.30)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.30)
	t.finished.connect(play_idle)

# --- 4. 蓄力 (Charge): 发光膨胀预警 ---
func play_charge():
	if idle_tween: idle_tween.kill()
	
	var charge_tween = create_tween()
	# 膨胀 + 向上漂移
	charge_tween.tween_property(self, "scale", original_scale * 1.25, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge_tween.parallel().tween_property(self, "position:y", original_pos.y - 20, 0.4)
	# 开始橙黄发光
	charge_tween.parallel().tween_property(self, "modulate", Color(2.0, 1.4, 0.3), 0.4)
	# 维持蓄力感：轻微上下震颤
	for i in range(3):
		charge_tween.tween_property(self, "position:y", original_pos.y - 20 + 6, 0.12)
		charge_tween.tween_property(self, "position:y", original_pos.y - 20 - 6, 0.12)
	# 收缩准备爆发
	charge_tween.tween_property(self, "scale", original_scale * 1.05, 0.15).set_trans(Tween.TRANS_QUAD)
	charge_tween.parallel().tween_property(self, "modulate", Color(1.8, 1.0, 0.2), 0.15)
	# 回到呼吸状态，但保持轻微黄色（提示「已蓄力」）
	charge_tween.finished.connect(func():
		modulate = Color(1.6, 1.2, 0.5)
		play_idle()
	)

# --- 5. 特殊技能 (Special): 横向扑击 + 颜色闪烁 ---
func play_special():
	# 仅在“技能”触发时使用敌人专属动作；没有专属则回退通用特效
	if _play_persona_attack(true):
		return

	_play_default_special()


func _play_default_special():
	if idle_tween: idle_tween.kill()
	
	var sp_tween = create_tween()
	# 旋转一圈 + 缩小蓄力
	sp_tween.tween_property(self, "rotation_degrees", -20, 0.15).set_trans(Tween.TRANS_QUAD)
	sp_tween.parallel().tween_property(self, "scale", original_scale * 0.85, 0.15)
	sp_tween.parallel().tween_property(self, "modulate", Color(0.4, 0.8, 2.5), 0.15)
	# 爆冲向左（向玩家侧）
	sp_tween.tween_property(self, "position:x", original_pos.x + 80, 0.08).set_trans(Tween.TRANS_EXPO)
	sp_tween.parallel().tween_property(self, "scale", original_scale * 1.3, 0.08)
	sp_tween.parallel().tween_property(self, "modulate", Color(2.0, 2.0, 2.0), 0.08) # 白色爆闪
	# 弹回
	sp_tween.tween_property(self, "position:x", original_pos.x, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	sp_tween.parallel().tween_property(self, "rotation_degrees", 0, 0.35)
	sp_tween.parallel().tween_property(self, "scale", original_scale, 0.35)
	sp_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.35)
	
	sp_tween.finished.connect(play_idle)

# --- 6. 狂暴 (Enrage): 高速抖动 + 深红染色 ---
func play_enrage():
	if idle_tween: idle_tween.kill()
	
	var er_tween = create_tween()
	# 变红
	er_tween.tween_property(self, "modulate", Color(2.5, 0.3, 0.3), 0.2)
	er_tween.parallel().tween_property(self, "scale", original_scale * 1.2, 0.2)
	# 高频左右抖动（愤怒感）
	for i in range(6):
		var offset = 14 if i % 2 == 0 else -14
		er_tween.tween_property(self, "position:x", original_pos.x + offset, 0.05)
	# 归位
	er_tween.tween_property(self, "position:x", original_pos.x, 0.05)
	er_tween.parallel().tween_property(self, "scale", original_scale * 1.15, 0.1)
	# 保持深红 idle 提示已狂暴
	er_tween.finished.connect(func():
		modulate = Color(1.8, 0.5, 0.5)
		play_idle()
	)
