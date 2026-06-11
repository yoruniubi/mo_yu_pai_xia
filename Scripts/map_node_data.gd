class_name MapNodeData
extends Resource
## 地图节点配置资源 - 数据驱动，易于扩展

@export_group("节点类型")
@export var node_type: String = "battle"  ## battle/elite/event/shop/rest/treasure/boss
@export var display_name: String = "开会"  ## 职场主题显示名
@export var icon: String = "⚔️"  ## Emoji 图标

@export_group("视觉配置")
@export var fill_color: Color = Color("#FF6B6B")  ## 节点填充色
@export var outline_color: Color = Color("#2D2D2D")  ## 描边颜色
@export var glow_color: Color = Color("#FFD93D")  ## 发光/高亮颜色
@export var node_radius: float = 45.0  ## 节点半径

@export_group("动画配置")
@export var hover_scale: float = 1.25  ## hover 放大倍率
@export var hover_duration: float = 0.15  ## hover 动画时长
@export var pulse_strength: float = 0.08  ## 呼吸脉冲强度
@export var pulse_speed: float = 2.0  ## 呼吸脉冲速度

@export_group("权重与规则")
@export var spawn_weight: float = 1.0  ## 生成权重
@export var min_layer: int = 0  ## 最早出现层数
@export var max_layer: int = 14  ## 最晚出现层数
@export var max_per_map: int = 99  ## 单张地图最大出现次数


## 根据 node_type 返回默认配置
static func get_default_for_type(type: String) -> MapNodeData:
	var data = MapNodeData.new()
	data.node_type = type
	match type:
		"battle":
			data.display_name = "开会"
			data.icon = "⚔️"
			data.fill_color = Color("#FF6B6B")
			data.glow_color = Color("#FF9F9F")
			data.spawn_weight = 3.0
			data.max_layer = 28
		"elite":
			data.display_name = "跨部门会议"
			data.icon = "💀"
			data.fill_color = Color("#845EC2")
			data.glow_color = Color("#B39CD0")
			data.spawn_weight = 2.0
			data.min_layer = 5
			data.max_layer = 28
			data.max_per_map = 4
		"event":
			data.display_name = "职场见闻"
			data.icon = "💬"
			data.fill_color = Color("#4ECDC4")
			data.glow_color = Color("#7EDDD6")
			data.spawn_weight = 2.5
			data.max_layer = 28
		"shop":
			# 只负责强化卡牌效果，删牌
			data.display_name = "茶水间"
			data.icon = "🛒"
			data.fill_color = Color("#FFD93D")
			data.glow_color = Color("#FFE880")
			data.spawn_weight = 1.5
			data.min_layer = 2
			data.max_layer = 28
			data.max_per_map = 3
		"rest":
			# 回20%血，休息节点可以获得随机增益效果，持续到下一次战斗
			data.display_name = "带薪摸鱼"
			data.icon = "😴"
			data.fill_color = Color("#6BCB77")
			data.glow_color = Color("#9FE2A0")
			data.spawn_weight = 1.5
			data.min_layer = 2
			data.max_layer = 28
			data.max_per_map = 3
		"treasure":
			# 奖励节点，可以获得随机卡牌，可以选择获得或是放弃
			data.display_name = "项目奖金"
			data.icon = "💰"
			data.fill_color = Color("#FF8C00")
			data.glow_color = Color("#FFB347")
			data.spawn_weight = 1.2
			data.min_layer = 3
			data.max_layer = 28
			data.max_per_map = 3
		"evolution":
			data.display_name = "职场进化"
			data.icon = "⚡"
			data.fill_color = Color("#9B59B6")
			data.outline_color = Color("#8E44AD")
			data.glow_color = Color("#C39BD3")
			data.node_radius = 48.0
			data.hover_scale = 1.2
			data.pulse_strength = 0.1
			data.spawn_weight = 0.0  # 不参与随机生成
			data.min_layer = 0
			data.max_layer = 29
			data.max_per_map = 1
		"miniboss":
			data.display_name = "部门经理"
			data.icon = "🐗"
			data.fill_color = Color("#E67E22")
			data.outline_color = Color("#D35400")
			data.glow_color = Color("#F39C12")
			data.node_radius = 51.0
			data.hover_scale = 1.18
			data.pulse_strength = 0.11
			data.spawn_weight = 0.0  # 不参与随机生成
			data.min_layer = 14
			data.max_layer = 14
			data.max_per_map = 1
		"boss":
			data.display_name = "年终述职"
			data.icon = "👑"
			data.fill_color = Color("#E74C3C")
			data.glow_color = Color("#FF6B6B")
			data.node_radius = 53.0
			data.hover_scale = 1.15
			data.pulse_strength = 0.12
			data.spawn_weight = 0.0  # boss 不参与随机生成
			data.min_layer = 29
			data.max_layer = 29
			data.max_per_map = 1
	return data