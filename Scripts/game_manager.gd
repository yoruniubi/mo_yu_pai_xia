extends Node

# 这个变量用来保存玩家选中的英雄数据
var selected_hero: CharacterData

# 玩家状态持久化
var player_hp: int = 100
var max_player_hp: int = 100
var player_deck: Array = []

# 关卡管理
var current_level: int = 1
var max_levels: int = 10
var evolution_path: String = "" 
var max_ap: int = 3 # 全局最大 AP

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
	# 3张 💧 (摸鱼喝水)
	for i in range(3):
		player_deck.append(universal_cards[1].duplicate())
	# 1张 🤡 (小丑自嘲)
	player_deck.append(universal_cards[2].duplicate())
	# 1张 ☕ (午后咖啡)
	player_deck.append(universal_cards[3].duplicate())
	# 1张 💩 (带薪拉屎)
	player_deck.append(universal_cards[4].duplicate())
	
	# 1张 角色核心卡
	if selected_hero and selected_hero.card_pool.size() > 0:
		# 通常最后一张是核心卡
		player_deck.append(selected_hero.card_pool[-1].duplicate())
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
	"🏃💧💩": {"name": "带薪健身", "parts": ["🏃", "💧", "💩"], "effect": "回复 10 HP，本场战斗 HP 上限 +5", "logic": "paid_gym"}
}

var character_combos = {
	"博姆 (Boomtail)": {
		"🔥⌨️": {"name": "愤怒的键盘侠", "parts": ["🔥", "⌨️"], "effect": "本回合所有键盘伤害变为 3 倍", "logic": "angry_keyboard"},
		"🔥💣🧨": {"name": "核能爆破", "parts": ["🔥", "💣", "🧨"], "effect": "造成 30 点伤害，火大层数翻三倍", "logic": "nuclear_bomb"},
		"⌨️⌨️🔥": {"name": "加班狂魔", "parts": ["⌨️", "⌨️", "🔥"], "effect": "造成 25 点无视防御伤害", "logic": "overtime_demon"}
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
		}
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
		}
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
		}
	}
}

# 通用基础卡池
var universal_cards: Array = [
	{"name": "键盘输出", "emoji": "⌨️", "cost": 1, "description": "造成 5 点伤害", "type": "attack", "value": 5},
	{"name": "摸鱼喝水", "emoji": "💧", "cost": 1, "description": "获得 5 点防御 (减压)", "type": "defense", "value": 5},
	{"name": "小丑自嘲", "emoji": "🤡", "cost": 1, "description": "造成 3 点伤害，抽 1 张牌", "type": "attack_draw", "value": 3},
	{"name": "午后咖啡", "emoji": "☕", "cost": 0, "description": "获得 1 点摸鱼力 (AP) 并抽一张牌", "type": "buff_ap_draw", "value": 1},
	{"name": "带薪拉屎", "emoji": "💩", "cost": 1, "description": "随机替换基础卡并抽一张", "type": "special_poop"},
	{"name": "工位补觉", "emoji": "💤", "cost": 1, "description": "回复 5 HP，抽 1 张牌", "type": "heal_draw", "value": 5},
	{"name": "老板画饼", "emoji": "🍞", "cost": 1, "description": "获得 5 点防御，抽 1 张牌", "type": "defense_draw", "value": 5},
	{"name": "极限跃动", "emoji": "🏃", "cost": 1, "description": "抽 1 张牌，用于【带薪健身】连招", "type": "draw_only", "value": 1},
	{"name": "灵光一闪", "emoji": "💡", "cost": 1, "description": "抽 2 张牌", "type": "draw_only", "value": 2},
	{"name": "甩锅", "emoji": "🛡️", "cost": 1, "description": "获得 4 点防御并造成 4 点伤害", "type": "defense_attack", "value": 4}
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
