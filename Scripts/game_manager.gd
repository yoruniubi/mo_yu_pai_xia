extends Node

# 这个变量用来保存玩家选中的英雄数据
var selected_hero: CharacterData

# 玩家状态持久化
var player_hp: int = 100
var max_player_hp: int = 100
var player_deck: Array = []
var is_tutorial_mode: bool = false

# 关卡管理
var current_level: int = 1
var max_levels: int = 10
var evolution_path: String = "" 
var max_ap: int = 3 # 全局最大 AP

func _ready():
	# 自动适配屏幕拉伸
	get_window().min_size = Vector2i(360, 640)
	if OS.get_name() in ["Windows", "macOS", "Linux"]:
		# PC端默认窗口大小调整或支持全屏快捷键
		DisplayServer.window_set_title("摸鱼牌侠 - PC版")

func _input(event):
	# PC端全屏快捷键 (F11)
	if event is InputEventKey and event.keycode == KEY_F11 and event.pressed:
		var mode = DisplayServer.window_get_mode()
		if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func start_game(hero: CharacterData):
	selected_hero = hero
	player_hp = 100
	max_player_hp = 100
	current_level = 1
	max_ap = 3
	evolution_path = ""
	initialize_deck()
	load_current_level_scene()

func initialize_deck():
	player_deck.clear()
	# 初始牌组：10张卡
	# 3张 ⌨️ (键盘输出)
	for i in range(3):
		player_deck.append(universal_cards[0].duplicate())
	# 2张 💧 (摸鱼喝水) - 回血
	for i in range(2):
		player_deck.append(universal_cards[1].duplicate())
	# 2张 🛡️ (甩锅) - 护盾
	for i in range(2):
		player_deck.append(universal_cards[9].duplicate())
	# 1张 🤡 (小丑自嘲)
	player_deck.append(universal_cards[2].duplicate())
	# 1张 ☕ (午后咖啡)
	player_deck.append(universal_cards[3].duplicate())
	# 1张 💩 (带薪拉屎)
	player_deck.append(universal_cards[4].duplicate())
	
	# 角色特色卡：将英雄卡池中的所有卡牌加入初始牌组
	if selected_hero and selected_hero.card_pool.size() > 0:
		for card in selected_hero.card_pool:
			var hero_card = card.duplicate()
			# 动态更新核心卡描述以匹配最新的护盾/回血逻辑
			if "触手" in hero_card.name:
				hero_card.description = "偷取敌人 5 点耐性值，转化为自身防御。"
			elif "松果" in hero_card.name:
				hero_card.description = "造成 5 伤害，获得 1 个随机 🔥 卡。"
			elif "图表" in hero_card.name:
				hero_card.description = "造成 20 伤害。抽 3 张牌。记录本次伤害。回复 1 AP。"
			elif "简历" in hero_card.name:
				hero_card.description = "反弹本回合受到的第一次伤害。"
			player_deck.append(hero_card)
	else:
		# 兜底：再给一张键盘
		player_deck.append(universal_cards[0].duplicate())

func get_random_reward_cards(count: int = 3) -> Array:
	var rewards = []
	var pool = []
	pool.append_array(universal_cards)
	if selected_hero:
		pool.append_array(selected_hero.card_pool)
	
	for i in range(count):
		rewards.append(pool[randi() % pool.size()].duplicate())
	return rewards

func load_current_level_scene():
	var scene_path = "res://Scenes/battle_scene.tscn"
	
	if is_tutorial_mode and current_level == 1:
		scene_path = "res://Scenes/tutorial_scene.tscn"
	else:
		match current_level:
			3, 5, 7, 9:
				scene_path = "res://Scenes/event_scene.tscn"
			10:
				scene_path = "res://Scenes/boss_stage.tscn"
			_:
				scene_path = "res://Scenes/battle_scene.tscn"
			
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.change_scene_to_file(scene_path)

func advance_level():
	current_level += 1
	# 每 3 关自动提升一点最大 AP，作为基本成长（或者在 EventScene 中选择）
	if current_level == 4 or current_level == 8:
		max_ap += 1
		
	if current_level > max_levels:
		current_level = 1
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			tree.change_scene_to_file("res://Scenes/main_menu.tscn")
	else:
		load_current_level_scene()

# 敌人数据 definition
var enemies_data = {
	1: {
		"name": "传声鹦鹉",
		"image": "res://Assets/Images/parrot.png",
		"hp": 50,
		"intent": "意图：准备复制你的下一张牌"
	},
	2: {
		"name": "闹钟刺猬",
		"image": "res://Assets/Images/hedgehog.png",
		"hp": 60,
		"intent": "意图：高频连击准备中"
	},
	4: {
		"name": "项目组长监控猿",
		"image": "res://Assets/Images/kingkong.png",
		"hp": 120,
		"intent": "意图：锁定你的 Emoji 槽位"
	},
	6: {
		"name": "会议树懒",
		"image": "res://Assets/Images/Sloth.png",
		"hp": 150,
		"intent": "意图：塞入垃圾文件卡"
	},
	8: {
		"name": "画饼蜘蛛",
		"image": "res://Assets/Images/spider.png",
		"hp": 200,
		"intent": "意图：编织虚假目标"
	},
	10: {
		"name": "三头狮 CEO",
		"image": "res://Assets/Images/Boss.png",
		"hp": 500,
		"intent": "意图：释放【KPI 考核】"
	}
}

func get_current_enemy():
	if enemies_data.has(current_level):
		return enemies_data[current_level]
	# 默认敌人
	return {
		"name": "职场小怪",
		"image": "res://Assets/Images/parrot.png",
		"hp": 40 + current_level * 10,
		"intent": "意图：让你加班"
	}

# 连招系统定义
var universal_combos = {
	"🤡🤡": {"name": "小丑竟是我自己", "parts": ["🤡", "🤡"], "effect": "伤害等同于已损失压力的 50%", "logic": "clown_self"},
	"💩☕💤": {"name": "终极摸鱼", "parts": ["💩", "☕", "💤"], "effect": "恢复满 HP 且跳过老板回合", "logic": "ultimate_slack"},
	"☕💩💧": {"name": "摸鱼三件套", "parts": ["☕", "💩", "💧"], "effect": "抽 2 张牌，摸鱼力 +1", "logic": "slack_trio"},
	"🤡💩🤡": {"name": "职场老油条", "parts": ["🤡", "💩", "🤡"], "effect": "获得 2 回合减损闪避", "logic": "office_slicker"},
	"🏃💧💩": {"name": "带薪健身", "parts": ["🏃", "💧", "💩"], "effect": "回复 10 HP，本场战斗 HP 上限 +5", "logic": "paid_gym"},
	"👍👍": {"name": "优秀员工", "parts": ["👍", "👍"], "effect": "获得 20 点护盾并回复 1 AP", "logic": "excellent_employee"},
	"💩💩": {"name": "拉屎大师", "parts": ["💩", "💩"], "effect": "使敌人中毒层数翻倍", "logic": "poop_master"},
	"⌨️⌨️⌨️": {"name": "疯狂输出", "parts": ["⌨️", "⌨️", "⌨️"], "effect": "造成 35 点爆发伤害", "logic": "crazy_output"},
	"📑📑": {"name": "深度复盘", "parts": ["📑", "📑"], "effect": "触发本回合所有已打出卡牌的效果各一次", "logic": "deep_review"},
	"💡💡": {"name": "头脑风暴", "parts": ["💡", "💡"], "effect": "抽 3 张牌并回复 1 AP", "logic": "brainstorm"},
	"🏃🏃": {"name": "职场幻影", "parts": ["🏃", "🏃"], "effect": "获得 2 回合闪避", "logic": "office_phantom"},
	"☕☕": {"name": "咖啡因过载", "parts": ["☕", "☕"], "effect": "获得 2 AP，抽 2 张牌，扣 5 HP", "logic": "caffeine_overload"},
	"💻⌨️": {"name": "远程输出", "parts": ["💻", "⌨️"], "effect": "造成 15 伤害，抽 1 张牌", "logic": "remote_output"},
	"💩💩💩": {"name": "拉屎之神", "parts": ["💩", "💩", "💩"], "effect": "中毒层数翻 3 倍", "logic": "poop_god"},
	"📁📑": {"name": "归档整理", "parts": ["📁", "📑"], "effect": "获得 15 护盾并抽 1 张牌", "logic": "file_archive"},
	"🖱️🖱️🖱️": {"name": "连点器", "parts": ["🖱️", "🖱️", "🖱️"], "effect": "造成 20 点伤害", "logic": "auto_clicker"},
	"💼👍": {"name": "带薪面试", "parts": ["💼", "👍"], "effect": "获得 10 护盾并抽 2 张牌", "logic": "paid_interview"},
	"📧📧": {"name": "全员抄送", "parts": ["📧", "📧"], "effect": "抽 2 张牌并造成 12 伤害", "logic": "cc_everyone"},
	"🧘💤": {"name": "心理假", "parts": ["🧘", "💤"], "effect": "回复 25 HP 并回复 1 AP", "logic": "mental_health"},
	"💰💼": {"name": "风险投资", "parts": ["💰", "💼"], "effect": "获得 2 AP 并抽 2 张牌", "logic": "venture_capital"},
	"📄⌨️": {"name": "撰写报告", "parts": ["📄", "⌨️"], "effect": "造成 18 伤害并获得 8 护盾", "logic": "write_report"},
	"⌨️🔌": {"name": "全线崩溃", "parts": ["⌨️", "🔌"], "effect": "造成 60 伤害，下回合 AP 减半", "logic": "system_crash"},
	"💤🧘💧": {"name": "带薪长假", "parts": ["💤", "🧘", "💧"], "effect": "回复 40 HP，下回合抽牌 +3", "logic": "long_vacation"},
	"👍📊📈": {"name": "职场精英", "parts": ["👍", "📊", "📈"], "effect": "获得 20 护盾，下一次伤害翻倍", "logic": "office_elite"},
	"🔌💻": {"name": "断网了", "parts": ["🔌", "💻"], "effect": "老板下回合发呆，抽 2 张牌", "logic": "no_internet"}
}

var character_combos = {
	"博姆 (Boomtail)": {
		"🔥⌨️": {"name": "愤怒的键盘侠", "parts": ["🔥", "⌨️"], "effect": "本回合所有键盘伤害变为 3 倍", "logic": "angry_keyboard"},
		"🔥💣🧨": {"name": "核能爆破", "parts": ["🔥", "💣", "🧨"], "effect": "造成 30 点伤害，火大层数翻三倍", "logic": "nuclear_bomb"},
		"⌨️⌨️🔥": {"name": "加班狂魔", "parts": ["⌨️", "⌨️", "🔥"], "effect": "造成 25 点无视防御伤害", "logic": "overtime_demon"},
		"🔥🌋": {"name": "火山爆发", "parts": ["🔥", "🌋"], "effect": "消耗所有火大，每层造成 15 伤害", "logic": "volcano_eruption"}
	},
	"墨里 (Inkwell)": {
		"💩🌊": {
			"name": "浑水摸鱼",
			"parts": ["💩", "🌊"],
			"effect": "获得 15 点防御，且下回合多抽 2 张牌",
			"logic": "muddy_water"
		},
		"🐙💨": {
			"name": "墨雾逃生",
			"parts": ["🐙", "💨"],
			"effect": "本回合无敌，且移除所有垃圾卡",
			"logic": "ink_escape"
		},
		"🌊🌀": {"name": "深海漩涡", "parts": ["🌊", "🌀"], "effect": "老板连续 2 回合无法行动", "logic": "deep_sea_vortex"}
	},
	"莱奥 (Leo)": {
		"📊📈🍞": {
			"name": "画大饼",
			"parts": ["📊", "📈", "🍞"],
			"effect": "获得 3 层虚假希望（抵消致死伤害）",
			"logic": "big_bread"
		},
		"📊📈📊": {
			"name": "循环报表",
			"parts": ["📊", "📈", "📊"],
			"effect": "重复释放本回合打出的所有数据卡效果",
			"logic": "loop_report"
		},
		"📊📑": {"name": "季度审计", "parts": ["📊", "📑"], "effect": "立即结算并爆发所有记录数值的 2 倍", "logic": "quarterly_audit"}
	},
	"苏珊 (Susan)": {
		"❌📋": {
			"name": "流程繁琐",
			"parts": ["❌", "📋"],
			"effect": "老板下 2 回合无法行动",
			"logic": "red_tape"
		},
		"⏳📋": {
			"name": "带薪休假",
			"parts": ["⏳", "📋"],
			"effect": "回复 20 HP，且下回合 AP +2",
			"logic": "paid_leave"
		},
		"❌🚫": {"name": "一票否决", "parts": ["❌", "🚫"], "effect": "永久降低老板 10 点攻击力", "logic": "veto_power"}
	}
}

# 通用基础卡池
var universal_cards: Array = [
	{"name": "键盘输出", "emoji": "⌨️", "cost": 1, "description": "造成 5 点伤害", "type": "attack", "value": 5},
	{"name": "摸鱼喝水", "emoji": "💧", "cost": 1, "description": "回复 5 点压力 (HP)", "type": "heal", "value": 5},
	{"name": "小丑自嘲", "emoji": "🤡", "cost": 1, "description": "造成 3 点伤害，抽 1 张牌", "type": "attack_draw", "value": 3},
	{"name": "午后咖啡", "emoji": "☕", "cost": 0, "description": "获得 1 点摸鱼力 (AP) 并抽一张牌", "type": "buff_ap_draw", "value": 1},
	{"name": "带薪拉屎", "emoji": "💩", "cost": 1, "description": "施加 3 层中毒并抽 1 张牌", "type": "special_poop"},
	{"name": "工位补觉", "emoji": "💤", "cost": 1, "description": "回复 8 HP，抽 1 张牌", "type": "heal_draw", "value": 8},
	{"name": "老板画饼", "emoji": "🍞", "cost": 1, "description": "获得 6 点护盾，抽 1 张牌", "type": "shield_draw", "value": 6},
	{"name": "极限跃动", "emoji": "🏃", "cost": 1, "description": "获得 1 回合闪避并抽 1 张牌", "type": "evasion_draw", "value": 1},
	{"name": "灵光一闪", "emoji": "💡", "cost": 1, "description": "抽 2 张牌", "type": "draw_only", "value": 2},
	{"name": "甩锅", "emoji": "🛡️", "cost": 1, "description": "获得 5 点护盾并造成 3 点伤害", "type": "shield_attack", "value": 5},
	{"name": "老板的赞赏", "emoji": "👍", "cost": 1, "description": "获得 10 点护盾", "type": "shield", "value": 10},
	{"name": "周报汇总", "emoji": "📑", "cost": 1, "description": "造成 8 点伤害，若本回合打出过 ⌨️ 则伤害翻倍", "type": "attack_conditional_keyboard", "value": 8},
	{"name": "团队协作", "emoji": "🤝", "cost": 1, "description": "抽 2 张牌", "type": "draw_only", "value": 2},
	{"name": "充电宝", "emoji": "🔋", "cost": 1, "description": "下回合额外获得 2 点摸鱼力", "type": "next_turn_ap", "value": 2},
	{"name": "业绩下滑", "emoji": "📉", "cost": 1, "description": "使敌人进入易伤状态 (受到伤害+5)", "type": "debuff_def", "value": 5},
	{"name": "接个电话", "emoji": "📞", "cost": 1, "description": "获得 1 回合闪避，下回合抽牌 -1", "type": "evade_penalty_draw", "value": 1},
	{"name": "加班餐", "emoji": "🥪", "cost": 1, "description": "回复 12 HP", "type": "heal", "value": 12},
	{"name": "远程办公", "emoji": "💻", "cost": 1, "description": "造成 8 伤害，抽 1 张牌", "type": "attack_draw", "value": 8},
	{"name": "日程表", "emoji": "📅", "cost": 1, "description": "抽 1 张牌，若它是 Emoji 卡则其消耗变为 0", "type": "draw_discount", "value": 1},
	{"name": "文件夹", "emoji": "📁", "cost": 1, "description": "获得 5 护盾，若下一张是 📑 则护盾+10", "type": "shield_folder", "value": 5},
	{"name": "扩音器", "emoji": "📣", "cost": 1, "description": "使你的下一次攻击伤害翻倍", "type": "buff_next_attack", "value": 2},
	{"name": "修复Bug", "emoji": "🛠️", "cost": 1, "description": "回复 5 HP，移除手牌中 1 张垃圾卡", "type": "heal_remove_junk", "value": 5},
	{"name": "公文包", "emoji": "💼", "cost": 1, "description": "随机获得 1 张当前英雄的专属卡", "type": "draw_hero_card", "value": 1},
	{"name": "鼠标点击", "emoji": "🖱️", "cost": 0, "description": "造成 2 点伤害", "type": "attack", "value": 2},
	{"name": "邮件确认", "emoji": "📧", "cost": 1, "description": "造成 5 伤害并抽牌。若抽到 ⌨️ 则追加 10 伤害", "type": "attack_draw_email", "value": 5},
	{"name": "公司大楼", "emoji": "🏢", "cost": 1, "description": "获得等于手牌数 x 2 的护盾", "type": "shield_hand", "value": 2},
	{"name": "冥想", "emoji": "🧘", "cost": 1, "description": "回复 5 HP，下回合摸鱼力 +1", "type": "heal_ap_next", "value": 5},
	{"name": "发工资", "emoji": "💰", "cost": 1, "description": "下回合摸鱼力 +3", "type": "ap_investment", "value": 3},
	{"name": "打印文件", "emoji": "📄", "cost": 1, "description": "获得 4 护盾，并将一张 📑 放入弃牌堆", "type": "shield_generate_review", "value": 4},
	{"name": "团建干杯", "emoji": "🥂", "cost": 1, "description": "本回合所有手牌消耗 -1 (最低为 0)", "type": "cost_reduction", "value": 1},
	{"name": "存档", "emoji": "💾", "cost": 1, "description": "本回合结束时不弃掉手牌", "type": "save_hand"},
	{"name": "拔电源", "emoji": "🔌", "cost": 2, "description": "造成 40 伤害，立即结束回合", "type": "pull_plug", "value": 40},
	{"name": "摸鱼洗手", "emoji": "🧼", "cost": 1, "description": "移除自身所有负面状态", "type": "clean_status"},
	{"name": "快递到了", "emoji": "📦", "cost": 1, "description": "随机获得 2 张通用卡", "type": "delivery_cards", "value": 2},
	{"name": "裁员名单", "emoji": "📉", "cost": 2, "description": "消耗所有护盾，每点护盾造成 2 倍伤害", "type": "layoff_list", "value": 2}
]

# 垃圾卡/诅咒卡定义
var junk_cards = {
	"meeting": {
		"name": "无意义早会",
		"emoji": "📢",
		"cost": 1,
		"description": "打出无效果。不打出则每回合扣 2HP。",
		"type": "junk_meeting",
		"value": 2
	},
	"kpi": {
		"name": "KPI 考核",
		"emoji": "📉",
		"cost": 99, # 无法打出
		"description": "无法打出。在手牌中时，所有 Combo 卡消耗 +1 AP。",
		"type": "junk_kpi"
	},
	"goal": {
		"name": "虚假目标",
		"emoji": "🕸️",
		"cost": 1,
		"description": "打出后本回合摸鱼力 -1。不打出则下回合抽牌 -1。",
		"type": "junk_goal"
	}
}

# 进化分支定义
var evolution_data = {
	"博姆 (Boomtail)": {
		"7": {
			"A": {"name": "焦土流", "description": "强化 🔥 效果，火大层数翻倍更快", "card": {"name": "烈焰喷射", "emoji": "🔥", "cost": 1, "type": "buff_fire", "value": 3, "description": "目标火大层数变为 3 倍"}},
			"B": {"name": "爆破流", "description": "强化 💣 效果，炸弹基础伤害更高", "card": {"name": "重型松果", "emoji": "💣", "cost": 2, "type": "attack_bomb", "value": 20, "description": "造成 20 伤害。每层火大额外+5"}}
		},
		"8": {
			"A": {"name": "红莲地狱", "description": "终极火系爆发", "card": {"name": "大过滤器", "emoji": "☀️", "cost": 3, "type": "ultimate_fire_filter", "value": 2, "description": "消灭非火手牌，每张使本回合火伤翻倍"}}
		}
	},
	"墨里 (Inkwell)": {
		"7": {
			"A": {"name": "恐惧流", "description": "强化 🐙 效果，大幅降低敌人攻击", "card": {"name": "深渊恐惧", "emoji": "🐙", "cost": 1, "type": "debuff_atk", "value": 10, "description": "降低老板 10 点攻击力"}},
			"B": {"name": "墨汁流", "description": "强化 🌊 效果，防御与反击并重", "card": {"name": "浓缩墨汁", "emoji": "🌊", "cost": 1, "type": "defense_ink", "value": 15, "description": "获得 15 防御。若触发过 💩，防御变为 3 倍"}}
		},
		"8": {
			"A": {"name": "深海意志", "description": "终极防御反击", "card": {"name": "归于虚无", "emoji": "🌀", "cost": 3, "type": "ultimate_void", "value": 20, "description": "削减老板 20% 耐性上限并回复等量压力"}}
		}
	},
	"莱奥 (Leo)": {
		"7": {
			"A": {"name": "PPT流", "description": "强化 📊 记录效果，数值翻倍", "card": {"name": "精美PPT", "emoji": "📊", "cost": 2, "type": "record_data", "value": 2, "description": "记录上一张牌伤害的 2 倍"}},
			"B": {"name": "资源流", "description": "强化 📈 释放效果，消耗降低", "card": {"name": "资源整合", "emoji": "📈", "cost": 2, "type": "release_data", "value": 2, "description": "释放 📊 记录的数值，消耗 2AP"}}
		},
		"8": {
			"A": {"name": "全宇宙愿景", "description": "终极数据爆发", "card": {"name": "降维打击", "emoji": "🪐", "cost": 3, "type": "ultimate_vision", "value": 0, "description": "爆发所有记录数值，本回合所有卡牌 0 消耗"}}
		}
	},
	"苏珊 (Susan)": {
		"7": {
			"A": {"name": "禁令流", "description": "强化 ❌ 封印效果", "card": {"name": "绝对禁令", "emoji": "❌", "cost": 2, "type": "cancel_intent", "value": 2, "description": "消除老板意图，且下回合老板也发呆"}},
			"B": {"name": "待岗流", "description": "强化 ⏳ 防御效果", "card": {"name": "长期待岗", "emoji": "⏳", "cost": 1, "type": "wait_defense", "value": 40, "description": "下回合不行动，获得 40 点超高防御"}}
		},
		"8": {
			"A": {"name": "行业黑名单", "description": "终极规则裁决", "card": {"name": "终极裁决", "emoji": "🚫", "cost": 3, "type": "ultimate_blacklist", "value": 2, "description": "永久封印老板意图，每回合造成其攻击力 2 倍的伤害"}}
		}
	}
}
