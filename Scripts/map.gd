extends Control
## 爬塔地图主控制器 - Slay the Spire 风格竖屏地图
## 玩家从底部出发，逐层向上选择节点，最终到达 Boss 层

# signal node_selected(node_type: String, layer: int, index: int)

# 常量
const TOTAL_LAYERS := 30         ## 地图总层数（0=起点，14=Boss）
const MIN_NODES := 2             ## 每层最少节点数
const MAX_NODES := 3             ## 每层最多节点数
const LAYER_H := 225.0           ## 层间垂直间距
const MAP_W := 1080.0            ## 地图内容宽度
const PATH_W := 6.0              ## 普通路径宽度
const ACTIVE_PATH_W := 9.0       ## 激活路径宽度
const HEADER_H := 162.0          ## 顶部栏高度
const NODE_LABEL_H := 45.0       ## 节点名称标签高度
const NODE_PAD := 18.0           ## 节点外圈留白
const NODE_ICON_RATIO := 1.25    ## Emoji 图标字号比例

enum NodeState { UNREACHED, REACHABLE, COMPLETED, CURRENT }


# 地图数据
var _map_data: Array = []         # Array of Array of Dictionary
var _connections: Array = []      # Array of Dictionary {fl, fi, tl, ti}
var _current_layer: int = 0
var _current_node_idx: int = -1
var _completed: Dictionary = {}   # "layer_idx" -> true
var _reachable: Dictionary = {}   # "layer_idx" -> true


# 视觉元素
var _node_visuals: Array = []     # Array of Array of Control
var _path_lines: Array = []       # Array of Line2D
var _player_marker: Control = null
var _scroll: ScrollContainer
var _content: Control
var _paths: Node2D
var _nodes: Control
var _ui: Control
var _pulse_t: float = 0.0
var _hovered: Control = null
var _flow_shader: Shader
var _is_navigating: bool = false  # 防止重复点击

## 地图层级对应的游戏关卡号（1-17），0 表示非战斗层
var _layer_to_level: Array = [
	1,  # 0  第一阶段：普通战斗（起点）
	2,  # 1  普通
	3,  # 2  普通
	0,  # 3  事件
	4,  # 4  普通
	5,  # 5  普通/精英
	0,  # 6  商店
	6,  # 7  精英
	7,  # 8  精英
	0,  # 9  休息
	0,  # 10 宝藏
	0,  # 11 事件
	0,  # 12 商店
	0,  # 13 小Boss前休息（固定进化节点）
	8,  # 14 小Boss：部门经理野猪
	10, # 15 第二阶段：普通战斗
	11, # 16 普通
	0,  # 17 事件
	12, # 18 普通
	13, # 19 普通/精英
	0,  # 20 商店
	14, # 21 精英
	15, # 22 精英
	0,  # 23 休息
	16, # 24 精英（战胜后获得第二次进化）
	0,  # 25 宝藏
	0,  # 26 事件
	0,  # 27 商店
	0,  # 28 终Boss前休息（固定）
	17, # 29 终Boss：CEO三头狮
]

var _layer_to_fixed: Array = [
	"",          # 0  普通战斗（起点）
	"",          # 1  
	"",          # 2  
	"",        	 # 3  
	"",          # 4  
	"",          # 5  
	"",      	 # 6  固定商店
	"",          # 7  
	"",          # 8  
	"",      	# 9  
	"",  		# 10 
	"",     	# 11 
	"",      	# 12 
	"evolution", # 13 小Boss前固定进化+休息
	"miniboss",  # 14 小Boss：部门经理野猪
	"",       # 15
	"",       # 16
	"",       # 17
	"",       # 18
	"",       # 19
	"",       # 20
	"",       # 21
	"",       # 22
	"",      # 23 固定休息
	"evolution", # 24 终Boss前固定进化
	"",          # 25
	"",     # 26
	"",      # 27 
	"rest",      # 28 终Boss前固定休息
	"boss",      # 29 终Boss：CEO三头狮
]

# 生命周期
func _ready() -> void:
	var bgm = preload("res://Assets/Music/map_bgm.mp3")
	BgmManager.play_music(bgm)
	_load_shaders()
	_build_ui()
	_generate_map()
	_render_map()
	_update_states()
	_scroll_to_current()


func _process(dt: float) -> void:
	_pulse_t += dt
	_animate_pulse(dt)


func _load_shaders() -> void:
	var p = "res://Assets/Shaders/path_flow.gdshader"
	if FileAccess.file_exists(p):
		_flow_shader = load(p)

# UI 骨架
func _build_ui() -> void:
	# 清除旧子节点
	for c in get_children():
		c.queue_free()

	_anchors_full(self)

	# 背景色：沿用项目奶油色 Lofi 基调
	var bg = ColorRect.new()
	bg.color = Color("#F9F1DE")
	bg.z_index = -10
	_anchors_full(bg)
	add_child(bg)

	# UI 覆盖层（顶部栏等）
	_ui = Control.new()
	_ui.name = "UI"
	_ui.mouse_filter = MOUSE_FILTER_IGNORE
	_anchors_full(_ui)
	_ui.z_index = 100
	add_child(_ui)

	_build_header()

	# 滚动容器
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_anchors_full(_scroll)
	_scroll.offset_top = HEADER_H + 12  # 留出顶部栏空间；必须放在 _anchors_full 之后，否则会被重置为 0
	add_child(_scroll)

	# 地图内容
	_content = Control.new()
	_content.custom_minimum_size = Vector2(MAP_W, TOTAL_LAYERS * LAYER_H + 390)
	_scroll.add_child(_content)

	# 路径层
	_paths = Node2D.new()
	_content.add_child(_paths)

	# 节点层
	_nodes = Control.new()
	_nodes.mouse_filter = MOUSE_FILTER_IGNORE
	_anchors_full(_nodes)
	_content.add_child(_nodes)

	# 玩家标记
	_player_marker = _make_marker()
	_content.add_child(_player_marker)


func _build_header() -> void:
	var h = Control.new()
	h.custom_minimum_size = Vector2(0, HEADER_H)
	h.anchor_left = 0.0
	h.anchor_right = 1.0
	h.anchor_top = 0.0
	h.anchor_bottom = 0.0
	h.offset_left = 0
	h.offset_right = 0
	h.offset_top = 0
	h.offset_bottom = HEADER_H
	h.z_index = 101
	_ui.add_child(h)

	# 顶部栏背景：半透明深色卡片，和战斗界面信息条保持一致
	var hbg = PanelContainer.new()
	var hbg_style = StyleBoxFlat.new()
	hbg_style.bg_color = Color("#3D3830CC")
	hbg_style.set_corner_radius_all(0)
	hbg.add_theme_stylebox_override("panel", hbg_style)
	_anchors_full(hbg)
	h.add_child(hbg)

	var sbg = StyleBoxFlat.new()
	sbg.bg_color = Color("#2B292466")
	sbg.set_corner_radius_all(14)
	sbg.border_width_left = 2
	sbg.border_width_top = 2
	sbg.border_width_right = 2
	sbg.border_width_bottom = 2
	sbg.border_color = Color("#F3D7A055")


	var sfg = StyleBoxFlat.new()
	sfg.bg_color = Color("#85C88A")
	sfg.set_corner_radius_all(14)

	var center_margin = MarginContainer.new()
	center_margin.anchor_left = 0.16
	center_margin.anchor_right = 0.84
	center_margin.anchor_top = 0.0
	center_margin.anchor_bottom = 1.0
	center_margin.offset_top = 12
	center_margin.offset_bottom = -15
	h.add_child(center_margin)

	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	center_margin.add_child(stack)

	# HP + 金币 显示（顶部居中）
	var hp_label = Label.new()
	hp_label.name = "HpLabel"
	hp_label.text = "❤️ %d/%d   🪙 %d" % [GameManager.player_hp, GameManager.max_player_hp, GameManager.mo_yu_coins]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 27)
	hp_label.add_theme_color_override("font_color", Color("#9DD6FF"))
	stack.add_child(hp_label)

	var bar = ProgressBar.new()
	bar.name = "ProgressBar"
	bar.min_value = 0
	bar.max_value = TOTAL_LAYERS - 1
	bar.value = clampi(_current_layer, 0, TOTAL_LAYERS - 1)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 42)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", sbg)
	bar.add_theme_stylebox_override("fill", sfg)
	stack.add_child(bar)

	# 进度条文字
	var bl = Label.new()
	bl.text = "💼 离职进度"
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bl.anchor_left = 0
	bl.anchor_right = 1
	bl.anchor_top = 0
	bl.anchor_bottom = 1
	bl.add_theme_color_override("font_color", Color("#F8F1E3"))
	bl.add_theme_font_size_override("font_size", 27)
	bl.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(bl)


	# 返回按钮
	var bb = Button.new()
	bb.text = "↩"
	bb.offset_left = 21
	bb.offset_top = 36
	bb.offset_right = 105
	bb.offset_bottom = 120
	bb.add_theme_font_size_override("font_size", 39)
	_style_header_button(bb)
	bb.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
	h.add_child(bb)

	# 牌库按钮
	var db = Button.new()
	db.text = "🗃️"
	db.anchor_left = 1.0   # ← 加上这行，和 anchor_right 一起锚定到右边
	db.anchor_right = 1.0
	db.offset_left = -105  # 从右边往左 105px（按钮左边缘）
	db.offset_top = 36
	db.offset_right = -21  # 从右边往左 21px（按钮右边缘）
	db.offset_bottom = 120
	db.add_theme_font_size_override("font_size", 36)
	_style_header_button(db)
	db.pressed.connect(func(): GameManager.show_deck_viewer(self))
	h.add_child(db)


func _style_header_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#2F4654")
	normal.set_corner_radius_all(10)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color("#F1D39A55")
	btn.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = Color("#416174")
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = normal.duplicate()
	pressed.bg_color = Color("#20313B")
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color("#F8F1E3"))


# 地图生成
func _generate_map() -> void:
	_map_data.clear()
	_connections.clear()
	_reachable.clear()

	# 同一局游戏中，地图只生成一次。
	# 之后从战斗/商店/休息/宝藏/事件返回地图时，直接复用 GameManager 中保存的节点与连线，
	# 避免重新随机导致地图布局、路径或节点类型变化。
	if GameManager.map_has_generated and not GameManager.map_data.is_empty():
		_map_data = GameManager.map_data
		_connections = GameManager.map_connections
		_current_layer = clampi(GameManager.map_current_layer, 0, TOTAL_LAYERS - 1)
		_current_node_idx = GameManager.map_current_node_idx
		if _current_node_idx < 0 or _current_node_idx >= _map_data[_current_layer].size():
			_current_node_idx = _calc_current_node_idx(_current_layer)

		_completed.clear()
		for layer_key in GameManager.map_completed_layers:
			_completed[layer_key] = true
		_calc_reachable()
		return

	# 使用固定种子确保每次加载地图时随机节点一致
	if GameManager.map_seed != 0:
		seed(GameManager.map_seed)
	else:
		GameManager.map_seed = randi()
		seed(GameManager.map_seed)

	# 根据当前游戏进度确定玩家所在层
	_current_layer = _calc_start_layer()

	# 逐层生成节点
	for l in range(TOTAL_LAYERS):
		_map_data.append(_gen_layer(l))

	_current_node_idx = _calc_current_node_idx(_current_layer)

	# 从 GameManager 恢复已完成的层记录
	_completed.clear()
	for layer_key in GameManager.map_completed_layers:
		_completed[layer_key] = true

	# 标记已通过的层为已完成（当前层之前的非当前节点）
	for i in range(_current_layer):
		var key = "%d_%d" % [i, _calc_current_node_idx(i)]
		if not _completed.has(key):
			_completed[key] = true

	_gen_connections()
	_ensure_connected()
	_calc_reachable()
	_save_map_runtime_state()
	GameManager.map_has_generated = true


func _save_map_runtime_state() -> void:
	GameManager.map_data = _map_data
	GameManager.map_connections = _connections
	GameManager.map_current_layer = _current_layer
	GameManager.map_current_node_idx = _current_node_idx
	GameManager.map_completed_layers.clear()
	for k in _completed.keys():
		GameManager.map_completed_layers[k] = true

# func _layer_to_level(layer: int) -> int:
# 	# Implementation for mapping layer to level
# 	pass

## 根据 GameManager.current_level 推算玩家应在的地图层
func _calc_start_layer() -> int:
	# 若战斗后触发了事件，地图应停在“事件层之前”，让玩家点击事件节点。
	# 例如：第 3 关结束后 current_level 已变为 4，但 pending_event_id=pantry，
	# 此时玩家实际完成的是第 3 关所在 layer 2，下一步应到 layer 3 茶水间。
	var pending_event = GameManager.pending_event_id
	if pending_event == "" and GameManager.pending_random_event_id != "":
		pending_event = GameManager.pending_random_event_id
	if pending_event != "":
		# 在 _layer_to_event 中查找该具体事件 ID 对应的层
		# 例如 "pantry" → layer 3, "team_building" → layer 11
		var fixed_event_layer = _layer_to_fixed.find(pending_event)
		if fixed_event_layer >= 0:
			return max(0, fixed_event_layer - 1)
		# 随机事件没有固定地图层，默认发生在上一场战斗之后
		var previous_level_layer = _layer_to_level.find(max(1, GameManager.current_level - 1))
		if previous_level_layer >= 0:
			return previous_level_layer

	var lvl = GameManager.current_level
	if lvl <= 0:
		return 0
	# 从 _layer_to_level 反查
	for i in range(_layer_to_level.size()):
		if _layer_to_level[i] == lvl:
			# current_level 表示“下一场要进入的战斗关”，因此地图当前位置
			# 应该是该战斗层的上一层；否则会跳过下一层节点。
			return max(0, i - 1)
	# 默认在第0层
	return 0


func _calc_current_node_idx(layer: int) -> int:
	# 当前项目还没有持久化“玩家选择过的具体路线”。为了避免玩家在回到地图后
	# 从同一层的所有节点继续分叉，这里稳定地把历史路线压到中间/唯一节点。
	# 这样固定事件层之后只会沿该事件节点的真实出边前进，不会点到其他分支。
	if layer < 0 or layer >= _map_data.size():
		return 0
	var count = _map_data[layer].size()
	if count <= 1:
		return 0
	return int(floor(float(count - 1) * 0.5))


func _gen_layer(l: int) -> Array:
	# 最后一层：Boss（固定）
	if l == TOTAL_LAYERS - 1:
		return [_make_entry(MapNodeData.get_default_for_type("boss"), l, 0)]
 
	# 第0层：唯一起始战斗节点
	if l == 0:
		return [_make_entry(MapNodeData.get_default_for_type("battle"), l, 0)]
 
	# 固定节点层（商店/休息/宝藏/事件/进化/小Boss/终Boss）
	var fixed_type = _layer_to_fixed[l]
	if fixed_type != "":
		return [_make_entry(MapNodeData.get_default_for_type(fixed_type), l, 0)]
 
	# 普通随机层
	var n = randi_range(MIN_NODES, MAX_NODES)
	var type_counts = {}
	# 收集上一层的节点类型，避免相邻两层出现相同节点类型
	var prev1_types = []  # 上一层
	if l >= 1 and _map_data.size() > l - 1:
		for prev_entry in _map_data[l - 1]:
			prev1_types.append(prev_entry.data.node_type)
	
	var nodes = []
	for i in range(n):
		var t = _pick_type(l, type_counts, prev1_types)
		type_counts[t] = type_counts.get(t, 0) + 1
		
		# 更新 prev1_types，确保同一层内也不会有重复类型
		# 例如：避免一层里出现 [财富, 财富] 或 [商店, 商店]
		if t not in prev1_types:
			prev1_types.append(t)
		
		nodes.append(_make_entry(MapNodeData.get_default_for_type(t), l, i))
	
	return nodes


func _make_entry(d: MapNodeData, l: int, i: int) -> Dictionary:
	return {
		"data": d,
		"layer": l,
		"index": i,
		"state": NodeState.UNREACHED,
		"pos": Vector2.ZERO
	}


func _pick_type(l: int, tc: Dictionary, prev_types: Array = []) -> String:
	## 两级筛选：
	##   主池 - 排除同层已有 + 上一层重复（硬约束）
	##   兜底池 - 仅排除同层已有（当主池为空时使用）
	var main_pool = []
	var fallback_pool = []
	var types = ["battle", "elite", "event", "shop", "rest", "treasure"]

	for t in types:
		var c = MapNodeData.get_default_for_type(t)
		
		# 基础条件：在允许的层级范围内
		if l < c.min_layer or l > c.max_layer:
			continue
		
		# 基础条件：未超过地图最大数量限制
		if tc.get(t, 0) >= c.max_per_map:
			continue
		
		# 硬约束：同层不重复（避免同一层出现两个相同类型）
		if tc.get(t, 0) > 0:
			continue
		
		var entry = {"type": t, "w": c.spawn_weight}
		
		# 兜底池：满足所有硬约束的类型
		fallback_pool.append(entry)
		
		# 主池：额外排除上一层已有的类型（避免连续两层相同）
		if t in prev_types:
			continue
		main_pool.append(entry)

	var pool = main_pool
	if pool.is_empty():
		pool = fallback_pool
	if pool.is_empty():
		return "battle"

	var total_weight = 0.0
	for p in pool:
		total_weight += p.w

	var r = randf() * total_weight
	var cumulative = 0.0
	for p in pool:
		cumulative += p.w
		if r <= cumulative:
			return p.type

	return pool[-1].type


# 连线生成
func _gen_connections() -> void:
	_connections.clear()

	for l in range(TOTAL_LAYERS - 1):
		var cur = _map_data[l]
		var nxt = _map_data[l + 1]
		if cur.is_empty() or nxt.is_empty():
			continue

		# 记录每个节点已连出的线数，防止过多
		var from_count = {}  # fi -> 连出数
		var to_count = {}    # ti -> 连入数

		# 从当前层每个节点连1-2条线到下一层
		for i in range(cur.size()):
			var num_connections = 1 if randf() < 0.6 else 2
			num_connections = mini(num_connections, nxt.size())
			var targets = _nearby(i, cur.size(), nxt.size(), num_connections)
			for t in targets:
				_add_conn(l, i, l + 1, t, from_count, to_count)

		# 确保下一层每个节点至少有一条入线
		for j in range(nxt.size()):
			if not to_count.has(j) or to_count[j] == 0:
				var best_from = _nearest(j, nxt.size(), cur.size())
				_add_conn(l, best_from, l + 1, j, from_count, to_count)


func _nearby(ci: int, cc: int, nc: int, num: int) -> Array:
	"""找到当前节点 ci 附近的下一层节点"""
	var res = []
	var center_ratio = float(ci) / max(cc - 1, 1)

	# 按距离排序候选节点
	var cands = range(nc)
	cands.sort_custom(func(a, b):
		return abs(float(a) / max(nc - 1, 1) - center_ratio) < \
			   abs(float(b) / max(nc - 1, 1) - center_ratio)
	)

	for i in range(mini(num, cands.size())):
		if i == 0 or randf() < 0.7:
			res.append(cands[i])
		else:
			# 30% 概率选一个非最近的节点，增加路线多样性
			var remaining = []
			for c in cands:
				if c not in res:
					remaining.append(c)
			if remaining.size() > 0:
				res.append(remaining[randi() % remaining.size()])
			else:
				res.append(cands[i])
	return res


func _nearest(ti: int, tc: int, sc: int) -> int:
	"""找到下一层节点 ti 在当前层最近的节点"""
	var target_ratio = float(ti) / max(tc - 1, 1)
	var best_idx = 0
	var best_dist = 999.0

	for i in range(sc):
		var d = abs(float(i) / max(sc - 1, 1) - target_ratio)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _add_conn(fl: int, fi: int, tl: int, ti: int, from_count: Dictionary, to_count: Dictionary) -> void:
	# 避免重复连线
	for c in _connections:
		if c.fl == fl and c.fi == fi and c.tl == tl and c.ti == ti:
			return

	_connections.append({"fl": fl, "fi": fi, "tl": tl, "ti": ti})

	if not from_count.has(fi):
		from_count[fi] = 0
	from_count[fi] += 1

	if not to_count.has(ti):
		to_count[ti] = 0
	to_count[ti] += 1


func _ensure_connected() -> void:
	"""确保所有层都可达（BFS 验证 + 补线）"""
	var visited = {0: true}
	var queue = [0]

	while queue.size() > 0:
		var l = queue.pop_front()
		for c in _connections:
			if c.fl == l and not visited.has(c.tl):
				visited[c.tl] = true
				queue.append(c.tl)

	# 对未连通的层补一条线
	for l in range(TOTAL_LAYERS - 1):
		if not visited.has(l + 1) and _map_data[l].size() > 0 and _map_data[l + 1].size() > 0:
			_connections.append({"fl": l, "fi": 0, "tl": l + 1, "ti": 0})
			visited[l + 1] = true


# 可达性计算
func _calc_reachable() -> void:
	_reachable.clear()

	# 如果还没开始，第0层所有节点可达
	if _current_layer < 0:
		for i in range(_map_data[0].size()):
			_reachable["0_%d" % i] = true
		return

	# 已通关，无可达节点
	if _current_layer >= TOTAL_LAYERS:
		return

	# 下一层节点可达：只能从“当前所在节点”的出边继续，而不是当前层所有节点的出边。
	var next_layer = _current_layer + 1
	if next_layer < TOTAL_LAYERS:
		for c in _connections:
			if c.fl == _current_layer and c.fi == _current_node_idx:
				_reachable["%d_%d" % [next_layer, c.ti]] = true

		# 兜底：如果没有可达节点，只开放下一层中间节点，避免无依据开放整层分支。
		if _reachable.is_empty():
			var fallback_idx = _calc_current_node_idx(next_layer)
			_reachable["%d_%d" % [next_layer, fallback_idx]] = true

# 渲染
func _render_map() -> void:
	_node_visuals.clear()
	_path_lines.clear()

	for c in _paths.get_children():
		c.queue_free()
	for c in _nodes.get_children():
		c.queue_free()

	_calc_positions()
	_render_paths()
	_render_nodes()
	_update_marker()


func _calc_positions() -> void:
	var w = _content.size.x
	if w < 100:
		w = MAP_W

	for l in range(TOTAL_LAYERS):
		var nodes = _map_data[l]
		var count = nodes.size()
		for i in range(count):
			# Y 轴：从下到上，底部是第0层，顶部是 Boss
			var y = (TOTAL_LAYERS - 1 - l) * LAYER_H + 100
			var spacing = w / (count + 1)
			var x = spacing * (i + 1)
			nodes[i].pos = Vector2(x, y)


func _render_paths() -> void:
	for c in _connections:
		var from_node = _map_data[c.fl][c.fi]
		var to_node = _map_data[c.tl][c.ti]

		# 所有路径都提前显示；当前可走路径高亮，已走过路径保持较亮，其余路径灰色弱显示。
		var key_from = "%d_%d" % [c.fl, c.fi]
		var key_to = "%d_%d" % [c.tl, c.ti]
		var is_active = _reachable.has(key_to) and (_completed.has(key_from) or c.fl == _current_layer)
		var is_completed_path = _completed.has(key_from) and (_completed.has(key_to) or (c.tl == _current_layer and c.ti == _current_node_idx))

		# 连线从圆圈边缘出发，避免线条穿过 Emoji 图标
		var from_radius: float = from_node.data.node_radius
		var to_radius: float = to_node.data.node_radius
		var dir = (to_node.pos - from_node.pos).normalized()
		var sp = from_node.pos + dir * (from_radius + 9.0)
		var ep = to_node.pos - dir * (to_radius + 9.0)

		var line = Line2D.new()
		line.width = ACTIVE_PATH_W if is_active else PATH_W
		if is_active:
			line.default_color = Color("#4FA463")
		elif is_completed_path:
			line.default_color = Color("#7FB88B")
		else:
			line.default_color = Color("#9A928666")
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = -1

		# 贝塞尔曲线路径：控制点优先沿垂直方向推进，再给一点水平偏移。
		# 旧版控制点沿直线方向延伸，四点几乎共线，曲线看起来容易“不正常/像没渲染”。
		var dist = sp.distance_to(ep)
		var vertical_step = (ep.y - sp.y) * 0.48
		var horizontal_bend = clampf(ep.x - sp.x, -180.0, 180.0) * 0.18
		var cp1 = sp + Vector2(horizontal_bend, vertical_step)
		var cp2 = ep - Vector2(horizontal_bend, vertical_step)
		line.points = PackedVector2Array(_bezier(sp, cp1, cp2, ep, max(18, int(dist / 28.0))))

		if _flow_shader and is_active:
			var mat = ShaderMaterial.new()
			mat.shader = _flow_shader
			mat.set_shader_parameter("is_active_path", true)
			mat.set_shader_parameter("flow_color", Vector4(0.31, 0.64, 0.39, 1.0))
			line.material = mat

		_paths.add_child(line)
		_path_lines.append(line)


func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, segments: int) -> Array:
	var pts = []
	for i in range(segments + 1):
		var t = float(i) / segments
		var u = 1.0 - t
		pts.append(u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3)
	return pts


func _render_nodes() -> void:
	for l in range(TOTAL_LAYERS):
		var layer_visuals = []
		for i in range(_map_data[l].size()):
			var v = _make_visual(_map_data[l][i])
			_nodes.add_child(v)
			layer_visuals.append(v)
		_node_visuals.append(layer_visuals)


func _make_visual(e: Dictionary) -> Control:
	var d: MapNodeData = e.data
	var p: Vector2 = e.pos
	var r: float = d.node_radius
	var pad := NODE_PAD
	var outer_radius := r + 9.0
	var box_w := (r + pad) * 2.0
	var box_h := box_w + NODE_LABEL_H
	var center := Vector2(r + pad, r + pad)

	var ct = Control.new()
	ct.name = "N_%d_%d" % [e.layer, e.index]
	ct.position = p - center
	ct.custom_minimum_size = Vector2(box_w, box_h)
	ct.size = Vector2(box_w, box_h)
	ct.pivot_offset = center
	ct.mouse_filter = MOUSE_FILTER_STOP
	ct.mouse_entered.connect(_on_hover.bind(ct, true))
	ct.mouse_exited.connect(_on_hover.bind(ct, false))

	# 存储元数据
	ct.set_meta("layer", e.layer)
	ct.set_meta("index", e.index)
	ct.set_meta("node_type", d.node_type)
	ct.set_meta("nd", d)
	ct.set_meta("br", r)

	# 子节点顺序：0=outline, 1=fill, 2=highlight, 3=icon, 4=name, 5=check, 6=pulse
	# 视觉目标：外层圆圈包裹 Emoji，节点中心与路径坐标完全一致。
	ct.add_child(_circle(outer_radius, d.outline_color, center))       # 0: outline
	ct.add_child(_circle(r, d.fill_color, center))                     # 1: fill
	ct.add_child(_circle(r * 0.32, Color("#FFFFFF66"), center + Vector2(-r * 0.22, -r * 0.26)))  # 2: highlight

	# Emoji 图标
	var ic = Label.new()
	ic.text = d.icon
	ic.mouse_filter = MOUSE_FILTER_IGNORE
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ic.position = center - Vector2(r, r)
	ic.size = Vector2(r * 2.0, r * 2.0)
	ic.add_theme_font_size_override("font_size", int(r * NODE_ICON_RATIO))
	ic.add_theme_color_override("font_color", Color("#2F2B26"))
	ct.add_child(ic)  # 3: icon

	# 节点名称
	var nl = Label.new()
	nl.text = d.display_name
	nl.mouse_filter = MOUSE_FILTER_IGNORE
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.position = Vector2(-12, center.y + r + 3)
	nl.size = Vector2(box_w + 24, NODE_LABEL_H)
	nl.add_theme_font_size_override("font_size", 24)
	nl.add_theme_color_override("font_color", Color("#5B5145"))
	nl.add_theme_color_override("font_shadow_color", Color("#FFF8E8AA"))
	nl.add_theme_constant_override("shadow_offset_x", 1)
	nl.add_theme_constant_override("shadow_offset_y", 1)
	ct.add_child(nl)  # 4: name

	# 完成标记 ✓
	var ck = Label.new()
	ck.text = "✓"
	ck.mouse_filter = MOUSE_FILTER_IGNORE
	ck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ck.position = center + Vector2(r * 0.25, -r * 0.95)
	ck.size = Vector2(r, r)
	ck.add_theme_font_size_override("font_size", int(r * 0.7))
	ck.add_theme_color_override("font_color", Color("#4FA463"))
	ck.add_theme_color_override("font_shadow_color", Color("#FFFFFF"))
	ck.add_theme_constant_override("shadow_offset_x", 1)
	ck.add_theme_constant_override("shadow_offset_y", 1)
	ck.visible = false
	ck.name = "Check"
	ct.add_child(ck)  # 5: check

	# 脉冲光环
	var pr = _circle(r + 15, Color(d.glow_color, 0.0), center)
	pr.name = "Pulse"
	pr.visible = false
	ct.add_child(pr)  # 6: pulse

	# 连接输入信号
	ct.gui_input.connect(_on_node_input.bind(ct))

	return ct


func _circle(radius: float, col: Color, pos: Vector2) -> PanelContainer:
	var s = radius * 2
	var p = PanelContainer.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(s, s)
	p.size = Vector2(s, s)
	# pos 表示圆心坐标。旧实现把 pos 当左上角，导致节点整体偏移。
	p.position = pos - Vector2(radius, radius)
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color("#FFFFFF55")
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_marker() -> Control:
	var m = Control.new()
	m.name = "Marker"
	m.z_index = 50
	m.mouse_filter = MOUSE_FILTER_IGNORE
	var marker_center := Vector2(48, 48)
	var marker_size := Vector2(96, 96)
	m.custom_minimum_size = marker_size
	m.size = marker_size

	# 外圈光晕
	m.add_child(_circle(48, Color("#FFD93D44"), marker_center))
	# 内圈
	m.add_child(_circle(28, Color("#FFD93D"), marker_center))

	# 玩家角色头像（使用选中角色的 character_image，与 battle_scene 中 hero_sprite 一致）
	var portrait = TextureRect.new()
	var tex: Texture2D = null
	if GameManager.selected_hero and GameManager.selected_hero.character_image:
		tex = GameManager.selected_hero.character_image
	if tex:
		portrait.texture = tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.size = Vector2(92, 92)
		portrait.position = marker_center - portrait.size * 0.5
		portrait.mouse_filter = MOUSE_FILTER_IGNORE
		m.add_child(portrait)
	else:
		# 回退到 emoji 图标
		var ic = Label.new()
		var emoji = "🐟"
		if GameManager.selected_hero and GameManager.selected_hero.core_emojis != "":
			emoji = GameManager.selected_hero.core_emojis
		ic.text = emoji
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ic.size = marker_size
		ic.add_theme_font_size_override("font_size", 42)
		m.add_child(ic)

	m.visible = false
	return m


func _update_marker() -> void:
	if _current_layer < 0 or _current_layer >= TOTAL_LAYERS:
		_player_marker.visible = false
		return

	_player_marker.visible = true
	var target_pos = Vector2.ZERO

	if _current_node_idx >= 0 and _current_node_idx < _map_data[_current_layer].size():
		target_pos = _map_data[_current_layer][_current_node_idx].pos
	elif _map_data[_current_layer].size() > 0:
		target_pos = _map_data[_current_layer][0].pos
	else:
		_player_marker.visible = false
		return

	_player_marker.position = target_pos - _player_marker.size * 0.5

# 状态更新
func _update_states() -> void:
	for l in range(TOTAL_LAYERS):
		for i in range(_map_data[l].size()):
			var key = "%d_%d" % [l, i]
			var e = _map_data[l][i]
			var st: NodeState

			if _completed.has(key):
				st = NodeState.COMPLETED
			elif l == _current_layer and _current_node_idx == i:
				st = NodeState.CURRENT
			elif _reachable.has(key):
				st = NodeState.REACHABLE
			else:
				st = NodeState.UNREACHED

			e.state = st
			_apply_state(l, i, st)

	# 更新顶部栏显示
	var hp_label = _ui.find_child("HpLabel", true, false)
	if hp_label:
		hp_label.text = "❤️ %d/%d   🪙 %d" % [GameManager.player_hp, GameManager.max_player_hp, GameManager.mo_yu_coins]

	var progress_bar = _ui.find_child("ProgressBar", true, false)
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.value = clampi(_current_layer, 0, TOTAL_LAYERS - 1)


func _apply_state(l: int, i: int, st: NodeState) -> void:
	if l >= _node_visuals.size() or i >= _node_visuals[l].size():
		return

	var v: Control = _node_visuals[l][i]
	var d: MapNodeData = v.get_meta("nd")

	# 子节点索引：0=outline, 1=fill, 5=check, 6=pulse
	var outline = v.get_child(0)
	var fill = v.get_child(1)
	var ck = v.get_node("Check")
	var pr = v.get_node("Pulse")

	match st:
		NodeState.UNREACHED:
			_set_circle_color(fill, Color("#D0D0D0"))
			_set_circle_color(outline, Color("#A0A0A0"))
			ck.visible = false
			pr.visible = false
			v.modulate = Color(1, 1, 1, 0.5)
			v.mouse_filter = MOUSE_FILTER_IGNORE

		NodeState.REACHABLE:
			_set_circle_color(fill, d.fill_color)
			_set_circle_color(outline, d.outline_color)
			ck.visible = false
			pr.visible = true
			v.modulate = Color(1, 1, 1, 1)
			v.mouse_filter = MOUSE_FILTER_STOP

		NodeState.COMPLETED:
			_set_circle_color(fill, Color("#B8B8B8"))
			_set_circle_color(outline, Color("#909090"))
			ck.visible = true
			pr.visible = false
			v.modulate = Color(1, 1, 1, 0.6)
			v.mouse_filter = MOUSE_FILTER_IGNORE

		NodeState.CURRENT:
			_set_circle_color(fill, d.glow_color)
			_set_circle_color(outline, d.outline_color)
			ck.visible = false
			pr.visible = true
			v.modulate = Color(1, 1, 1, 1)
			v.mouse_filter = MOUSE_FILTER_IGNORE


func _set_circle_color(node: Node, col: Color) -> void:
	if node is PanelContainer:
		var sb = node.get_theme_stylebox("panel").duplicate()
		sb.bg_color = col
		node.add_theme_stylebox_override("panel", sb)


# 动画
func _animate_pulse(_dt: float) -> void:
	for l in range(TOTAL_LAYERS):
		for i in range(_map_data[l].size()):
			if _map_data[l][i].state != NodeState.REACHABLE:
				continue
			if l >= _node_visuals.size() or i >= _node_visuals[l].size():
				continue

			var v = _node_visuals[l][i]
			var d: MapNodeData = v.get_meta("nd")
			var pr = v.get_node("Pulse")

			if pr is PanelContainer:
				var alpha = (sin(_pulse_t * d.pulse_speed) + 1.0) / 2.0 * 0.4
				_set_circle_color(pr, Color(d.glow_color, alpha))

# 交互
func _on_node_input(ev: InputEvent, node: Control) -> void:
	var l: int = node.get_meta("layer")
	var i: int = node.get_meta("index")
	var key = "%d_%d" % [l, i]

	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _reachable.has(key):
			_on_click(node, l, i)


func _on_click(node: Control, l: int, i: int) -> void:
	if _is_navigating:
		return  # 防止重复点击

	var d: MapNodeData = node.get_meta("nd")

	# 点击动画
	var tw = create_tween()
	tw.tween_property(node, "scale", Vector2(0.85, 0.85), 0.08)
	tw.tween_property(node, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.15)

	await get_tree().create_timer(0.3).timeout

	# 更新状态
	_current_layer = l
	_current_node_idx = i
	_completed["%d_%d" % [l, i]] = true

	# 导航到对应场景
	_navigate(d.node_type, l)


func _on_hover(node: Control, entering: bool) -> void:
	if not is_instance_valid(node):
		return
	var l: int = node.get_meta("layer")
	var i: int = node.get_meta("index")
	var key = "%d_%d" % [l, i]
	if not _reachable.has(key):
		entering = false

	if entering and _hovered != node:
		if _hovered and is_instance_valid(_hovered):
			_tween_scale(_hovered, 1.0)
		_hovered = node
		var d: MapNodeData = node.get_meta("nd")
		_tween_scale(node, d.hover_scale)
	elif not entering and _hovered == node:
		_tween_scale(node, 1.0)
		_hovered = null


func _tween_scale(node: Control, s: float) -> void:
	if not is_instance_valid(node):
		return
	var d: MapNodeData = node.get_meta("nd") if node.has_meta("nd") else null
	var dur = d.hover_duration if d else 0.15
	create_tween().tween_property(node, "scale", Vector2(s, s), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 导航逻辑
func _navigate(nt: String, l: int) -> void:
	_is_navigating = true
 
	# 设置游戏关卡号
	var game_level = _layer_to_level[l] if l < _layer_to_level.size() else 0
	if game_level > 0:
		GameManager.current_level = game_level

	# 无论进入战斗/事件/商店/休息/宝藏，都先保存当前地图状态。
	# 这样从任意场景返回地图时，seed、节点、连线、当前所在节点和已完成节点都不会丢失。
	_save_map_runtime_state()
 
	match nt:
		"battle", "elite":
			GameManager.pending_event_id = ""
			GameManager.pending_random_event_id = ""
			GameManager.load_current_level_scene()
 
		"miniboss":
			# 小Boss：部门经理野猪（层14对应关卡8）
			GameManager.current_level = 8
			GameManager.pending_event_id = ""
			GameManager.pending_random_event_id = ""
			get_tree().change_scene_to_file("res://Scenes/boss_stage.tscn")
 
		"boss":
			# 终Boss：CEO三头狮（层29对应关卡17）
			GameManager.current_level = 17
			GameManager.pending_event_id = ""
			GameManager.pending_random_event_id = ""
			get_tree().change_scene_to_file("res://Scenes/boss_stage.tscn")
 
		"evolution":
			# 进化节点：战胜小Boss后在层13显示进化选择界面，完成后自动推进到小Boss层
			# 这里直接进入进化选择
			get_tree().change_scene_to_file("res://Scenes/upgrade_menu.tscn")
 
		"event":
			# 没有固定事件就触发随机事件
			if GameManager.pending_event_id == "":
				GameManager.pending_random_event_id = GameManager._get_random_event_id()
			else:
				GameManager.pending_random_event_id = ""
			GameManager.load_current_level_scene()
 
		"shop", "rest", "treasure":
			# 非战斗节点：记录当前层已完成，并推进 current_level 到下一个战斗关卡
			# 这样 _calc_start_layer() 回到地图时会指向正确的下一层
			var layer_key = "%d_%d" % [l, _current_node_idx]
			GameManager.map_completed_layers[layer_key] = true
			# 找到下一层对应的战斗关卡号并推进 current_level
			if l + 1 < TOTAL_LAYERS:
				var next_battle = _layer_to_level[l + 1]
				# 如果下一层也是非战斗层，继续往前找直到找到战斗层
				if next_battle == 0:
					for look in range(l + 2, TOTAL_LAYERS):
						if _layer_to_level[look] > 0:
							next_battle = _layer_to_level[look]
							break
				if next_battle > 0 and next_battle > GameManager.current_level:
					GameManager.current_level = next_battle
			match nt:
				"shop":
					get_tree().change_scene_to_file("res://Scenes/shop.tscn")
				"rest":
					get_tree().change_scene_to_file("res://Scenes/rest.tscn")
				"treasure":
					get_tree().change_scene_to_file("res://Scenes/treasure.tscn")

# 滚动定位
func _scroll_to_current() -> void:
	await get_tree().process_frame
	if not _scroll or not _content:
		return

	var target_y = 0.0
	if _current_layer >= 0 and _current_layer < TOTAL_LAYERS and _map_data[_current_layer].size() > 0:
		target_y = _map_data[_current_layer][0].pos.y - _scroll.size.y / 2.0

	target_y = clampf(target_y, 0.0, max(0.0, _content.size.y - _scroll.size.y))
	create_tween().tween_property(_scroll, "scroll_vertical", target_y, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# 工具函数
func _anchors_full(n: Control) -> void:
	n.anchor_left = 0
	n.anchor_right = 1
	n.anchor_top = 0
	n.anchor_bottom = 1
	n.offset_left = 0
	n.offset_right = 0
	n.offset_top = 0
	n.offset_bottom = 0