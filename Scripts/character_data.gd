extends Resource
class_name CharacterData # 这一行让它变成一个可以被创建的资源类型

@export var character_name: String = "" # 名字
@export var job_title: String = "" # 职位
@export var race: String = "" # 种族
@export var character_image: Texture2D # 立绘
@export var core_emojis: String = "" # 核心 Emoji
@export var combo_style: String = "" # 玩法流派
@export var description: String = "" # 描述
@export var card_pool: Array[Dictionary] = [] # 专属卡池
