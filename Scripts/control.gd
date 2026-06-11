extends Control

@onready var visual = $Visual
@export var character_data: CharacterData:
	set(value):
		character_data = value
		if is_node_ready():
			update_ui()

const HOVER_SCALE = Vector2(1.15, 1.15)
const ANIM_SPEED = 0.15
const HOVER_ROTATION = 2.0

# 不再写死，改为动态计算
var hover_pull_up: float = -40.0

func _ready():
	var parent = get_parent().get_parent()
	var sf = parent.scale_factor if "scale_factor" in parent else 1.0
	hover_pull_up = -40.0 * sf

	# 动态设置卡片尺寸
	var card_width  = 320.0 * sf
	var card_height = 495.0 * sf
	custom_minimum_size = Vector2(card_width, card_height)

	# 动态设置字体
	$Visual/InfoContainer/NameLabel.add_theme_font_size_override("font_size", int(26 * sf))
	$Visual/InfoContainer/JobLabel.add_theme_font_size_override("font_size",  int(22 * sf))
	$Visual/InfoContainer/EmojiLabel.add_theme_font_size_override("font_size", int(28 * sf))
	$Visual/InfoContainer/StyleLabel.add_theme_font_size_override("font_size", int(20 * sf))

	# InfoContainer 间距也缩放
	$Visual/InfoContainer.add_theme_constant_override("separation", int(2 * sf))

	update_ui()
	await get_tree().process_frame
	visual.pivot_offset = Vector2(card_width / 2.0, card_height / 2.0)

func update_ui():
	if character_data:
		$Visual/HeroImage.texture = character_data.character_image
		$Visual/InfoContainer/NameLabel.text = character_data.character_name
		$Visual/InfoContainer/JobLabel.text = character_data.job_title + " (" + character_data.race + ")"
		$Visual/InfoContainer/EmojiLabel.text = character_data.core_emojis
		$Visual/InfoContainer/StyleLabel.text = character_data.combo_style

func _on_mouse_entered():
	if not is_inside_tree():
		return
	z_index = 10
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", HOVER_SCALE, ANIM_SPEED)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:y", hover_pull_up, ANIM_SPEED)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "rotation_degrees", HOVER_ROTATION, ANIM_SPEED)
	tween.tween_property(visual, "modulate", Color(1.2, 1.2, 1.2), ANIM_SPEED)

func _on_mouse_exited():
	if not is_inside_tree():
		return
	z_index = 0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ONE, ANIM_SPEED)
	tween.tween_property(visual, "position:y", 0.0, ANIM_SPEED)
	tween.tween_property(visual, "rotation_degrees", 0.0, ANIM_SPEED)
	tween.tween_property(visual, "modulate", Color.WHITE, ANIM_SPEED)

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_inside_tree():
			return
		var tween = create_tween()
		tween.tween_property(visual, "scale", Vector2(0.9, 0.9), 0.05)
		tween.tween_property(visual, "scale", HOVER_SCALE, 0.1)
		get_tree().create_timer(0.1).timeout.connect(select_this_character)

func select_this_character():
	if not is_inside_tree():
		return
	var selection_node = get_parent().get_parent()
	if selection_node and selection_node.has_method("_on_character_selected"):
		selection_node._on_character_selected(character_data)
	else:
		GameManager.start_game(character_data)