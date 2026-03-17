# EnemyAnimator.gd
extends Control # 如果是 TextureRect 用 Control，Sprite2D 则改用 Node2D

# 记录初始状态，防止动画播完后位置“跑偏”
@onready var original_pos = position
@onready var original_scale = scale

var idle_tween: Tween

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
