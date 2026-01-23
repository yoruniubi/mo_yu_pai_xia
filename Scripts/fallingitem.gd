extends Sprite2D

# --- 属性设置 (可以在检查器里微调) ---
@export var min_speed: float = 50.0
@export var max_energy_speed: float = 80.0 # 摸鱼速度，不要太快

# --- 内部变量 ---
var speed: float = 0.0
var rot_speed: float = 0.0
var sway_speed: float = 0.0
var sway_amount: float = 0.0
var time_passed: float = 0.0
var initial_x: float = 0.0
var area: Area2D

func _ready():
	# 1. 基础初始化
	initial_x = position.x
	randomize_item()
	
	# 2. 动态添加碰撞区 (用于物体间排斥)
	setup_collision()
	
	# 3. [关键修复]：只有第一次启动时，随机分配它们在屏幕上的高度
	# 这样有的在最上面，有的在中间，有的快掉下去了
	var screen_height = get_viewport_rect().size.y
	position.y = randf_range(0, screen_height) 
	
	# 4. 随机一个起始时间，让左右晃动的节奏也不一样
	time_passed = randf_range(0, 100)

func setup_collision():
	area = Area2D.new()
	add_child(area)
	
	# 设置碰撞层：只在第 11 层（掉落物层）进行检测
	area.collision_layer = 1 << 10 # Layer 11
	area.collision_mask = 1 << 10  # 只检测 Layer 11
	area.input_pickable = false    # 鼠标穿透
	
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	
	if texture:
		var size = texture.get_size()
		circle.radius = (size.x + size.y) / 4.0 * 0.6 # 碰撞区稍微小一点，显得更自然
	else:
		circle.radius = 30.0
		
	collision.shape = circle
	area.add_child(collision)

func randomize_item():
	# 1. 随机速度
	speed = randf_range(min_speed, max_energy_speed)
	
	# 2. 随机旋转速度 (让它慢慢转)
	rot_speed = randf_range(-0.5, 0.5)
	
	# 3. 随机晃动参数 (Sway)
	sway_speed = randf_range(1.0, 2.0)   # 晃得快慢
	sway_amount = randf_range(10.0, 30.0) # 晃得宽窄
	
	# 6. 记录基准位置
	initial_x = randf_range(0, get_viewport_rect().size.x)
	position.x = initial_x
	position.y = -100 # 放在屏幕上方看不见的地方

func _process(delta):
	time_passed += delta
	
	# --- 0. 碰撞排斥逻辑 ---
	if area:
		var overlaps = area.get_overlapping_areas()
		for other_area in overlaps:
			var other_item = other_area.get_parent()
			if other_item and other_item != self:
				# 计算排斥方向
				var diff = position.x - other_item.position.x
				if abs(diff) < 1.0: diff = randf_range(-1.0, 1.0) # 防止重合
				
				# 稍微推开一点 initial_x，这样它们就不会一直叠在一起
				var push_force = 20.0 * delta * sign(diff)
				initial_x += push_force
	
	# --- 1. 核心逻辑：正弦波左右晃动 ---
	# 使用 sin 函数让 position.x 在初始值左右来回摆动
	position.x = initial_x + sin(time_passed * sway_speed) * sway_amount
	
	# --- 2. 垂直下滑 ---
	position.y += speed * delta
	
	# --- 3. 随机自转 ---
	rotation += rot_speed * delta
	
	# --- 4. 越界重置 ---
	if position.y > get_viewport_rect().size.y + 100:
		randomize_item()
